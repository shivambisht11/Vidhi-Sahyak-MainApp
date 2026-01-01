import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:avatar_glow/avatar_glow.dart';
import '../services/gemini_service.dart';
import '../services/chat_service.dart';
import '../l10n/app_localizations.dart'; // Import
import 'dart:io';
import 'package:audioplayers/audioplayers.dart'; // Import AudioPlayers
import '../services/eleven_labs_service.dart'; // Import ElevenLabsService
import 'dart:async'; // Import Timer

class VoiceChatScreen extends StatefulWidget {
  final String category;
  const VoiceChatScreen({super.key, required this.category});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

enum VoiceState { languageSelection, listening, processing, speaking, idle }

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with TickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  late AudioPlayer _audioPlayer; // AudioPlayer instance
  final GeminiService _gemini = GeminiService();

  // 🔹 VoiceChunk Class for Parallel Pre-fetching
  // (Defined inside State or as separate class? Let's use internal simple class or just Map)
  // Defining simple class at bottom of file is cleaner, but let's use a class here to avoid file clutter
  // actually dart allows classes at file level.

  VoiceState _state = VoiceState.idle; // Start directly in idle/init
  String _selectedLocale = 'en-US';
  String _displayText = "";
  bool _isDisposed = false;
  bool _isPaused = false;
  int _retryCount = 0;

  String? _currentSpeakingSentence; // Highlight state
  int _currentWordIndex = 0; // New: Word tracking
  Timer? _wordHighlightTimer; // New: Timer
  final ScrollController _scrollController = ScrollController();
  late AnimationController _breathingController;

  // New Voice Selection State
  List<Map<dynamic, dynamic>> _availableVoices = [];
  Map<dynamic, dynamic>? _currentVoice;

  @override
  void dispose() {
    _isDisposed = true;
    _speech.stop();
    _speech.cancel();
    _flutterTts.stop();
    _audioPlayer.dispose(); // Dispose AudioPlayer
    _breathingController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _audioPlayer = AudioPlayer(); // Initialize AudioPlayer
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _breathingController.repeat(reverse: true);

    // Defer initialization to access context for locale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocaleAndVoice();
    });
  }

  void _initializeLocaleAndVoice() {
    // Check if mounted before using context
    if (!mounted) return;
    final appLocale = Localizations.localeOf(context);
    setState(() {
      _selectedLocale = appLocale.languageCode == 'hi' ? 'hi-IN' : 'en-US';
      _displayText = AppLocalizations.of(context)!.voiceTapSpeak;
    });
    _initVoiceFeatures();
  }

  Future<void> _initVoiceFeatures() async {
    // ... (keep audio optimizations) ...
    double rate = Platform.isAndroid ? 0.3 : 0.5;
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);

    if (Platform.isIOS) {
      // ... (keep iOS audio session config) ...
      try {
        await _flutterTts
            .setIosAudioCategory(IosTextToSpeechAudioCategory.playAndRecord, [
              IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
              IosTextToSpeechAudioCategoryOptions.allowBluetooth,
              IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
              IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            ]);
      } catch (e) {
        debugPrint("Error setting audio category: $e");
      }
    }

    // Voice Selection Logic (simplified for brevity, logic remains same)
    // ... (Voice selection code) ...

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _state = VoiceState.speaking);
    });

    _flutterTts.setPauseHandler(() {
      if (mounted) setState(() => _isPaused = true);
    });

    _flutterTts.setContinueHandler(() {
      if (mounted) setState(() => _isPaused = false);
    });

    await _flutterTts.setLanguage(_selectedLocale);
    await _selectBestVoice(); // 🔹 Select best quality voice

    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _state = VoiceState.idle);
    });

    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        setState(() {
          _displayText = AppLocalizations.of(context)!.voiceMicPerm;
          _state = VoiceState.idle;
        });
      }
      return;
    }

    bool available = await _speech.initialize(
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
          // ...
        }
      },
      onError: (val) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          setState(() {
            if (val.errorMsg == "error_network" && _retryCount < 1) {
              _retryCount++;
              _displayText = l10n.voiceReconnecting;
              _initVoiceFeatures();
              return;
            }

            if (val.errorMsg == "error_network") {
              _displayText = l10n.voiceNetError;
            } else if (val.errorMsg == "error_no_match") {
              _displayText = l10n.voiceNoMatch;
            } else if (val.errorMsg == "error_listen_failed" &&
                _retryCount < 3) {
              _retryCount++;
              _displayText = "${l10n.voiceRecovering} ($_retryCount)";
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted && !_isDisposed && _state == VoiceState.idle) {
                  _startListening();
                }
              });
              return;
            } else if (val.errorMsg == "error_speech_timeout") {
              _displayText = l10n.voiceTapSpeak;
            } else {
              _displayText = "Error: ${val.errorMsg}";
            }
            _state = VoiceState.idle;
          });
        }
      },
    );

    if (available && mounted) {
      final role = _getCategoryRole(context);
      // Localized greeting
      final l10n = AppLocalizations.of(context)!;
      final greeting = _selectedLocale == 'hi-IN'
          ? "नमस्ते, मैं आपका $role हूँ। मैं आपकी कैसे मदद कर सकता हूँ?" // Fixed Hindi grammar
          : "Hello, I am your $role. How can I help you today?";
      // We could also put greeting in ARB but it has dynamic variables.
      // For now, keeping the logic here is okay or use args in ARB.

      await _speak(greeting);
    } else {
      if (mounted) {
        setState(() => _displayText = "Speech recognition check failed.");
      }
    }
  }

  // ... (Methods _startListening, _processInput, _speak, _processSpeakQueue stay mostly same but use l10n strings if any) ...

  void _startListening() async {
    if (_isDisposed) return;
    final l10n = AppLocalizations.of(context)!;
    await _flutterTts.stop();
    await _audioPlayer.stop(); // Stop audio player
    await _speech.cancel();
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _state = VoiceState.listening;
      _displayText = l10n.voiceListening;
    });

    await _speech.listen(
      onResult: (val) {
        if (_state != VoiceState.listening) return;
        setState(() => _displayText = val.recognizedWords);
        if (val.finalResult) {
          _processInput(val.recognizedWords);
        }
      },
      localeId: _selectedLocale,
      listenFor: const Duration(seconds: 30),
      pauseFor: Duration(seconds: Platform.isAndroid ? 5 : 3),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
    _retryCount = 0;
  }

  Future<void> _processInput(String text) async {
    final l10n = AppLocalizations.of(context)!;
    if (_state == VoiceState.processing) return;
    if (text.isEmpty || text == l10n.voiceListening) {
      _speech.stop();
      setState(() {
        _state = VoiceState.idle;
        _displayText = l10n.voiceNoMatch;
      });
      return;
    }

    // Calcluate estimated words
    final wordCount = text.trim().split(RegExp(r'\s+')).length;

    // 1. Check Limits (Voice)
    // We need ChatService instance here. Ideally modify State to hold it.
    final ChatService chatService = ChatService();
    // Assuming context is available and user is logged in (VoiceChat might be accessible without login? Check initState)
    // If user is not logged in, we might skip or block. Let's assume login required generally or skip if null.

    final errorMsg = await chatService.checkUsage('voice', wordCount);
    if (errorMsg != null) {
      _speech.stop();
      setState(() {
        _state = VoiceState.idle;
        _displayText = errorMsg;
      });
      await _speak("Daily limit reached. Please try again tomorrow.");
      return;
    }

    _speech.stop();
    setState(() {
      _state = VoiceState.processing;
      _displayText = l10n.voiceThinking;
      _currentSpeakingSentence = null;
    });

    final role = _getCategoryRole(context);
    final languageInstruction = _selectedLocale == 'hi-IN'
        ? " (Reply in Hindi. act as $role. Speak naturally...)"
        : " (Reply in English. act as $role. Speak naturally...)";

    final reply = await _gemini.sendMessage(
      text + languageInstruction,
      widget.category,
    );

    // Increment usage for User Input
    try {
      await chatService.incrementUsage('voice', wordCount);
    } catch (e) {
      debugPrint("Voice usage increment failed: $e");
    }

    // Calculate AI reply usage
    final replyWords = reply.trim().split(RegExp(r'\s+')).length;
    try {
      await chatService.incrementUsage('voice', replyWords);
    } catch (e) {
      debugPrint("Voice usage increment (AI) failed: $e");
    }

    if (!_isDisposed) {
      await _speak(reply);
    }
  }

  // Queue for sentence-by-sentence playback - Now stores VoiceChunk
  final List<VoiceChunk> _speakQueue = [];
  bool _isSpeakingQueue = false;

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;

    // Clear queue of chunks
    _speakQueue.clear();
    await _flutterTts.stop();
    await _audioPlayer.stop(); // Stop audio player

    setState(() {
      _state = VoiceState.speaking;
      _displayText = text;
      _currentSpeakingSentence = null;
      _currentWordIndex = 0;
      _isPaused = false;
    });

    // Scroll to top
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // 🛑 Check for Errors - Do NOT speak them
    final lowerText = text.toLowerCase();
    if (lowerText.contains("server is busy") ||
        lowerText.contains(
          "server is currently busy",
        ) || // Fixed: Added exact match
        lowerText.contains("high traffic") ||
        lowerText.contains("internal error") ||
        lowerText.contains("network error") ||
        lowerText.contains("429") ||
        lowerText.contains("too many requests") ||
        lowerText.contains("upstream error") ||
        text.contains("⚠")) {
      // Catch-all for our service errors
      // Just show the text (already done via setState above) and return.
      // Reset state to avoid "speaking" forever.
      debugPrint("Skipping TTS for Error Message: $text");
      setState(() => _state = VoiceState.idle);
      // Maybe auto-restart listening after a short delay?
      // Or just let user tap. Let's let user tap or auto-listen.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isDisposed && _state == VoiceState.idle) {
          _startListening();
        }
      });
      return;
    }

    // 1. Clean Text
    String cleanText = _cleanTextForTTS(text);

    // 2. Split into sentences for natural pausing
    final sentences = cleanText.split(RegExp(r'(?<=[.!?])\s+|\n+'));
    List<String> validSentences = sentences
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // 3. 🚀 Parallel Pre-fetching: Start ALL downloads immediately
    for (String sentence in validSentences) {
      // Create chunk with Future
      _speakQueue.add(
        VoiceChunk(
          text: sentence,
          // Start download NOW
          // Note: ElevenLabsService.streamAudio handles concurrency?
          // Service just makes HTTP call. It's fine to fire parallel.
          audioAttempt: ElevenLabsService.streamAudio(sentence),
        ),
      );
    }

    // 4. Start processing queue (playing first ready chunk)
    if (!_isSpeakingQueue) {
      await _audioPlayer.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.allowBluetooth,
            },
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.assistant,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      _processSpeakQueue();
    }
  }

  Future<void> _processSpeakQueue() async {
    if (_speakQueue.isEmpty) {
      _isSpeakingQueue = false;
      if (mounted && !_isDisposed && !_isPaused) {
        setState(() => _isPaused = false); // Ensure unpaused
        _startListening();
      }
      return;
    }

    _isSpeakingQueue = true;
    VoiceChunk chunk = _speakQueue.removeAt(0); // Take first chunk
    String sentence = chunk.text;

    // 🔹 Try ElevenLabs (Await the pre-started Future)
    File? audioFile;
    if (mounted) setState(() => _currentSpeakingSentence = sentence);

    try {
      // 🚀 Await the Future that started in _speak()
      audioFile = await chunk.audioAttempt;
    } catch (e) {
      // ... existing error handler
      debugPrint("ElevenLabs Error: $e");
      if (mounted) {
        // simplified error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Voice Error"),
            duration: Duration(seconds: 1),
          ),
        );
      }
      _isSpeakingQueue = false;
      if (mounted) {
        setState(() => _state = VoiceState.listening);
        _startListening();
      }
      return;
    }

    if (audioFile != null && await audioFile.exists()) {
      // ... existing playback logic
      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(audioFile.path));

        // 🔹 Estimate Word Duration & Start Highlighting
        final totalDuration = await _audioPlayer.getDuration();
        final words = sentence.trim().split(RegExp(r'\s+'));

        if (totalDuration != null && words.isNotEmpty) {
          _wordHighlightTimer?.cancel();
          _wordHighlightTimer = Timer.periodic(
            const Duration(milliseconds: 50),
            (timer) async {
              if (_isPaused || !_isSpeakingQueue) return;
              final position = await _audioPlayer.getCurrentPosition();
              if (position == null) return;
              double progress =
                  position.inMilliseconds / totalDuration.inMilliseconds;
              if (progress > 1.0) progress = 1.0;
              int newIndex = (progress * words.length).floor();
              if (newIndex >= words.length) newIndex = words.length - 1;
              if (newIndex != _currentWordIndex && mounted) {
                setState(() => _currentWordIndex = newIndex);
              }
            },
          );
        }

        await _audioPlayer.onPlayerComplete.first;
        _wordHighlightTimer?.cancel();
      } catch (e) {
        debugPrint("AudioPlayer Error: $e");
        _wordHighlightTimer?.cancel();
      }
    }

    // 🔹 Artificial "Brain" Pause
    await Future.delayed(const Duration(milliseconds: 50));

    if (mounted && !_isDisposed && !_isPaused) {
      if (mounted) setState(() => _currentWordIndex = 0);
      _processSpeakQueue();
    } else {
      _isSpeakingQueue = false;
      _wordHighlightTimer?.cancel();
      if (mounted) setState(() => _currentSpeakingSentence = null);
    }
  }

  String _cleanTextForTTS(String text) {
    // Remove markdown bold/italic but keep the words
    var clean = text.replaceAll(RegExp(r'[\*\_]'), '');

    // Remove markdown links [Link](url) -> Link
    clean = clean.replaceAllMapped(
      RegExp(r'\[(.*?)\]\(.*?\)'),
      (match) => match.group(1) ?? '',
    );

    // Replace breaks with pauses
    clean = clean.replaceAll('\n', '. ');

    // Remove complex chars but KEEP punctuation responsible for intonation
    // Removed removal of dashes as they might be used for pauses
    // clean = clean.replaceAll(RegExp(r'[-—\/\\>#]'), ' ');

    // Remove dashes and underscores
    clean = clean.replaceAll(RegExp(r'[-—_]'), ' ');

    // Only remove characters that are definitely non-verbal noise
    clean = clean.replaceAll(RegExp(r'[#`~]'), '');

    // Collapse multiple spaces
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');

    return clean.trim();
  }

  String _getStatusForUI() {
    final l10n = AppLocalizations.of(context)!;
    switch (_state) {
      case VoiceState.languageSelection:
        return l10n
            .voiceSelectLang; // Though we removed this state's initial usage
      case VoiceState.listening:
        return l10n.voiceListening;
      case VoiceState.processing:
        return l10n.voiceProcessing;
      case VoiceState.speaking:
        return l10n.voiceSpeaking;
      case VoiceState.idle:
        return l10n.voiceTapSpeak;
    }
  }

  String _getButtonText() {
    final l10n = AppLocalizations.of(context)!;
    if (_displayText.contains("permission")) return l10n.voiceOpenSettings;
    if (_state == VoiceState.listening) return l10n.voiceTapFinish;
    if (_displayText.startsWith("Network Error")) return l10n.voiceRetry;
    if (_displayText == l10n.voiceInit)
      return l10n.voiceInit.toUpperCase(); // Or new key
    return l10n.voiceTapSpeak.toUpperCase();
  }

  // ... (build method updates) ...

  @override
  Widget build(BuildContext context) {
    // Dynamic status color
    Color statusColor;
    switch (_state) {
      case VoiceState.languageSelection:
        statusColor = Colors.blueAccent;
        break;
      case VoiceState.listening:
        statusColor = Colors.redAccent;
        break;
      case VoiceState.processing:
        statusColor = Colors.blueAccent;
        break;
      case VoiceState.speaking:
        statusColor = Colors.greenAccent;
        break;
      case VoiceState.idle:
        statusColor = Colors.grey;
        break;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Dynamic
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_voice_rounded,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            onPressed: _showVoiceSelection,
            tooltip: "Change Voice",
          ),
          const SizedBox(width: 8),
        ],
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: Theme.of(context).textTheme.bodyLarge?.color, // Dynamic
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E) // Darker mix for dark mode
                  : Colors.blue.shade50.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // 🔹 Dynamic Orb Integration
            Center(
              child: AnimatedBuilder(
                animation: _breathingController,
                builder: (context, child) {
                  return AvatarGlow(
                    animate: _state != VoiceState.idle,
                    glowColor: statusColor,
                    endRadius: _state == VoiceState.speaking ? 140.0 : 120.0,
                    duration: const Duration(milliseconds: 2000),
                    repeat: true,
                    showTwoGlows: true,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.3),
                            blurRadius: 20 + (10 * _breathingController.value),
                            spreadRadius: 5 + (5 * _breathingController.value),
                          ),
                        ],
                      ),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.8),
                              statusColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(
                          _state == VoiceState.listening
                              ? Icons.mic_rounded
                              : _state == VoiceState.speaking
                              ? Icons.graphic_eq_rounded
                              : Icons.smart_toy_rounded,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),

            Text(
              _getStatusForUI(),
              style: TextStyle(
                color: statusColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),

            const Spacer(flex: 1),

            // 🔹 Text Area
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Using a simple RichText parser for basic markdown
                      _RichTextDisplay(
                        text: _displayText,
                        highlightText: _currentSpeakingSentence,
                        highlightWordIndex: _currentWordIndex, // NEW
                      ),
                      const SizedBox(height: 40), // Bottom padding
                    ],
                  ),
                ),
              ),
            ),

            // 🔹 Control Button Area (Floating at bottom of text area)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.only(bottom: 30, top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Play/Pause Button - Only show when speaking or paused
                  if (_state == VoiceState.speaking || _isPaused)
                    Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: FloatingActionButton(
                        onPressed: () async {
                          if (_isPaused) {
                            setState(() => _isPaused = false);
                            await _audioPlayer.resume();
                            // If queue has items but processing stopped, restart it
                            // FIX: Only restart if _isSpeakingQueue is FALSE (meaning the loop died)
                            // If _isSpeakingQueue is TRUE, it means it's just paused at 'await completion'
                            // But we aren't using `await completion` inside a loop that checks invalid state?
                            // Actually, onPlayerComplete.first blocks. If we pause, player pauses.
                            // The await doesn't return until completion.
                            // So we just Resume player. The code flows.
                            // BUT if paused between sentences (during delay), loop might exit?
                            // No, `_processSpeakQueue` checks `if (!_isPaused)` before recursing.
                            // SO if we paused during delay, the recursion DIED.
                            // We need to restart it.

                            // Check if audio is playing?
                            // final state = _audioPlayer.state;

                            if (_speakQueue.isNotEmpty && !_isSpeakingQueue) {
                              _processSpeakQueue();
                            }
                          } else {
                            setState(() => _isPaused = true);
                            await _audioPlayer.pause();
                            await _flutterTts.pause();
                          }
                        },
                        backgroundColor: Theme.of(context).cardColor,
                        elevation: 4,
                        child: Icon(
                          _isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          color: statusColor,
                          size: 32,
                        ),
                      ),
                    ),

                  SizedBox(
                    height: 60,
                    width: 200,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_displayText.contains("permission")) {
                          _openSettings();
                          return;
                        }
                        if (_state == VoiceState.listening) {
                          _speech.stop();
                          // If user Manually stops, force process what we have
                          if (_displayText != "Listening..." &&
                              _displayText.isNotEmpty &&
                              !_displayText.startsWith("Network Error")) {
                            _processInput(_displayText);
                          } else if (_displayText.startsWith("Network Error")) {
                            // Retry logic
                            setState(() => _displayText = "Initializing...");
                            _initVoiceFeatures();
                          } else {
                            // User stopped but said nothing
                            setState(() {
                              _state = VoiceState.idle;
                              _displayText = "Tap to Speak";
                            });
                          }
                        } else {
                          // _displayText = "Listening..."; // Managed by listener
                          _startListening();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: statusColor.withValues(alpha: 0.1),
                        foregroundColor: statusColor,
                        shape: const StadiumBorder(),
                        side: BorderSide(
                          color: statusColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getButtonText(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16, // Increased from 14
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  // 🔹 Select best available voice (Enhanced/Premium)
  Future<void> _selectBestVoice() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices == null || voices is! List) return;

      // Convert to list of maps for easier handling
      final List<Map<dynamic, dynamic>> voiceList = voices
          .cast<Map<dynamic, dynamic>>();

      // Filter by current locale
      final validVoices = voiceList.where((v) {
        return v["locale"].toString().startsWith(_selectedLocale) ||
            v["locale"].toString() == _selectedLocale.split('-')[0];
      }).toList();

      setState(() {
        _availableVoices = validVoices;
      });

      if (validVoices.isEmpty) return;

      // If we already have a selected voice, don't change it automatically
      if (_currentVoice != null) {
        await _flutterTts.setVoice({
          "name": _currentVoice!["name"],
          "locale": _currentVoice!["locale"],
        });
        return;
      }

      // Priority keywords for better quality
      Map<dynamic, dynamic>? bestVoice;
      for (var voice in validVoices) {
        final name = voice["name"].toString().toLowerCase();
        if (name.contains("enhanced") ||
            name.contains("premium") ||
            name.contains("high") ||
            name.contains("siri") || // iOS specific high quality
            name.contains("network")) {
          // Prioritize network voices usually
          bestVoice = voice;
          break; // Found a good one
        }
      }

      // Fallback to first valid voice if no premium found
      bestVoice ??= validVoices.first;

      if (bestVoice != null) {
        setState(() => _currentVoice = bestVoice);
        await _flutterTts.setVoice({
          "name": bestVoice["name"],
          "locale": bestVoice["locale"],
        });
        debugPrint("Selected Voice: ${bestVoice["name"]}");
      }
    } catch (e) {
      debugPrint("Error selecting voice: $e");
    }
  }

  void _showVoiceSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select Voice",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 10),
              if (_availableVoices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("No voices found for this language."),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _availableVoices.length,
                    itemBuilder: (context, index) {
                      final voice = _availableVoices[index];
                      final isSelected =
                          _currentVoice?["name"] == voice["name"];
                      return ListTile(
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected ? Colors.blueAccent : Colors.grey,
                        ),
                        title: Text(
                          voice["name"],
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          onPressed: () async {
                            // Preview
                            await _flutterTts.stop();
                            await _flutterTts.setVoice({
                              "name": voice["name"],
                              "locale": voice["locale"],
                            });
                            await _flutterTts.speak(
                              "Hello, I am your assistant.",
                            );
                            // Revert to current if needed, or just leave it set for preview
                          },
                        ),
                        onTap: () async {
                          setState(() => _currentVoice = voice);
                          await _flutterTts.setVoice({
                            "name": voice["name"],
                            "locale": voice["locale"],
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _getCategoryRole(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.category) {
      case 'study':
      case 'I need a study companion':
        return l10n.lblStudy;
      case 'lawyer':
      case 'I need a lawyer':
        return l10n.lblLawyer;
      case 'legal':
      case 'I need legal guidance':
        return l10n.lblLegal;
      case 'other':
      case 'Other':
        return l10n.lblOther;
      default:
        return widget.category; // Fallback
    }
  }
}

// 🔹 Helper Class for Parallel Pre-fetching
class VoiceChunk {
  final String text;
  final Future<File?> audioAttempt;

  VoiceChunk({required this.text, required this.audioAttempt});
}

// 🔹 Custom Simple Helper for Bold Text Rendering
class _RichTextDisplay extends StatelessWidget {
  final String text;
  final String? highlightText;
  final int highlightWordIndex; // NEW

  const _RichTextDisplay({
    required this.text,
    this.highlightText,
    this.highlightWordIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (highlightText == null || highlightText!.isEmpty) {
      return Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 20,
          height: 1.5,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    int index = text.indexOf(highlightText!);
    if (index == -1) {
      // Fallback
      return Text(text, textAlign: TextAlign.center);
    }

    final List<TextSpan> spans = [];

    // 1. Text Before Sentence
    if (index > 0) {
      spans.add(
        TextSpan(
          text: text.substring(0, index),
          style: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyLarge?.color?.withValues(alpha: 0.5), // Dimmed
            fontSize: 20,
            height: 1.5,
          ),
        ),
      );
    }

    // 2. The Sentence (Word by Word)
    String sentence = highlightText!;
    List<String> displayWords = sentence.split(' ');

    for (int i = 0; i < displayWords.length; i++) {
      bool isSpoken = i <= highlightWordIndex;
      spans.add(
        TextSpan(
          text: "${displayWords[i]}${i < displayWords.length - 1 ? " " : ""}",
          style: TextStyle(
            color: isSpoken
                ? Colors.blueAccent
                : Theme.of(
                    context,
                  ).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
            fontWeight: isSpoken ? FontWeight.bold : FontWeight.w400,
            fontSize: 22,
            height: 1.5,
          ),
        ),
      );
    }

    // 3. Text After Sentence
    if (index + highlightText!.length < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(index + highlightText!.length),
          style: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyLarge?.color?.withValues(alpha: 0.5), // Dimmed
            fontSize: 20,
            height: 1.5,
          ),
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }
}
