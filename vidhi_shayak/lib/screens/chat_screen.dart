import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/gemini_service.dart';
import '../services/chat_service.dart';
import '../widgets/chat_bubble.dart';
import '../models/message_model.dart';
import '../core/app_theme.dart';
import 'voice_chat_screen.dart';

import '../l10n/app_localizations.dart';
import 'language_selection_screen.dart';
import 'login_screen.dart';
import '../main.dart'; // To access global themeNotifier
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class ChatScreen extends StatefulWidget {
  final String selectedCategory;
  // Optional: Open a specific existing session
  final String? initialSessionId;

  const ChatScreen({
    super.key,
    required this.selectedCategory,
    this.initialSessionId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GeminiService _gemini = GeminiService();
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  bool _stopRequested = false;
  User? _user;
  String? _currentSessionId;
  List<MessageModel> messages = [];
  StreamSubscription? _messagesSubscription;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize with current user, but also listen for changes
    _user = _auth.currentUser;

    // Listen to Auth State Changes to update UI automatically (Drawer, etc.)
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _user = user;
        });
        // If user just logged in and we have no session, maybe we want to subscribe?
        // Or if they logged out, clear things.
        if (user == null) {
          setState(() {
            _currentSessionId = null;
            messages = [];
          });
        }
      }
    });

    if (widget.initialSessionId != null) {
      _currentSessionId = widget.initialSessionId;
      _subscribeToMessages();
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _authSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToMessages() {
    if (_currentSessionId == null) return;

    _messagesSubscription?.cancel();
    _messagesSubscription = _chatService.getMessages(_currentSessionId!).listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          messages = snapshot.docs
              .map(
                (doc) => MessageModel(
                  text: doc['text'],
                  isUser: doc['isUser'] ?? false,
                ),
              )
              .toList();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      },
    );
  }

  void _startNewChat() {
    setState(() {
      _currentSessionId = null;
      messages = [];
    });
    Navigator.pop(context);
  }

  void _loadSession(String sessionId) {
    if (_currentSessionId == sessionId) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _currentSessionId = sessionId;
      messages = [];
    });
    _subscribeToMessages();
    Navigator.pop(context);
  }

  Future<void> _deleteSession(String sessionId) async {
    try {
      await _chatService.deleteSession(sessionId);
      if (_currentSessionId == sessionId) {
        _startNewChat();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error deleting chat: $e")));
      }
    }
  }

  void _stopGeneration() {
    setState(() {
      _stopRequested = true;
      _loading = false;
    });
  }

  void _scrollToBottom({
    Duration duration = const Duration(milliseconds: 300),
  }) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: duration,
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to save chats.")),
      );
    }

    _controller.clear();

    setState(() {
      messages.add(MessageModel(text: text, isUser: true));
      _loading = true;
      _stopRequested = false;
    });
    _scrollToBottom();

    // Calcluate estimated words (simple space split)
    final wordCount = text.trim().split(RegExp(r'\s+')).length;

    try {
      if (_user != null) {
        // 1. Check Usage Limits
        try {
          final errorMsg = await _chatService.checkUsage('text', wordCount);
          if (errorMsg != null) {
            setState(() => _loading = false);
            _showLimitDialog(errorMsg);
            return;
          }
        } catch (e) {
          debugPrint("Usage check failed: $e");
          // Fail open: continue if check fails
        }

        if (_currentSessionId == null) {
          try {
            _currentSessionId = await _chatService.createNewSession(
              widget.selectedCategory,
              text,
            );
            _subscribeToMessages();
          } catch (e) {
            debugPrint("Session creation failed: $e");
          }
        }

        if (_currentSessionId != null) {
          try {
            await _chatService.sendMessage(
              sessionId: _currentSessionId!,
              text: text,
              isUser: true,
            );
          } catch (e) {
            debugPrint("Message save failed: $e");
          }

          // Increment usage for user message
          try {
            await _chatService.incrementUsage('text', wordCount);
          } catch (e) {
            debugPrint("Usage increment failed: $e");
          }
        }
      }

      if (_stopRequested) return;
      if (!mounted) return;

      final targetLanguage = Localizations.localeOf(context).languageCode;
      final reply = await _gemini.sendMessage(
        text,
        widget.selectedCategory,
        targetLanguage,
      );

      if (_stopRequested) return;

      // Calculate reply words
      final replyWords = reply.trim().split(RegExp(r'\s+')).length;

      // 1. Animate locally for ALL users (Typewriter effect)
      await _addAiMessageLocal(reply);

      setState(() => _loading = false);

      // 2. Save to Firestore (if logged in)
      if (_user != null && _currentSessionId != null) {
        try {
          await _chatService.sendMessage(
            sessionId: _currentSessionId!,
            text: reply,
            isUser: false,
          );

          // Increment usage for AI message
          await _chatService.incrementUsage('text', replyWords);
        } catch (e) {
          debugPrint("AI message save failed: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to save message history: $e")),
            );
          }
        }
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        if (!e.toString().contains("permission-denied")) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  Future<void> _addAiMessageLocal(String fullText) async {
    String temp = "";
    for (int i = 0; i < fullText.length; i++) {
      if (_stopRequested) break;
      temp += fullText[i];
      if (messages.isNotEmpty && !messages.last.isUser) {
        setState(() {
          messages[messages.length - 1] = MessageModel(
            text: temp,
            isUser: false,
          );
        });
      } else {
        setState(() {
          messages.add(MessageModel(text: temp, isUser: false));
        });
      }

      // Add delay for typewriter effect
      await Future.delayed(const Duration(milliseconds: 30));

      // Auto-scroll logic (keep scrolling to bottom while typing)
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  void _showLimitDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Limit Reached"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  String _getCategoryTitle(BuildContext context, String category) {
    final l10n = AppLocalizations.of(context)!;
    switch (category) {
      case 'study':
        return l10n.lblStudy;
      case 'lawyer':
        return l10n.lblLawyer;
      case 'legal':
        return l10n.lblLegal;
      case 'other':
        return l10n.lblOther;
      default:
        return category;
    }
  }

  Future<void> _showCategoryDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final categories = [
      {'id': 'study', 'label': l10n.catStudy, 'icon': Icons.school_rounded},
      {'id': 'lawyer', 'label': l10n.catLawyer, 'icon': Icons.gavel_rounded},
      {'id': 'legal', 'label': l10n.catLegal, 'icon': Icons.balance_rounded},
      {'id': 'other', 'label': l10n.catOther, 'icon': Icons.more_horiz_rounded},
    ];

    await showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          l10n.categoryTitle,
        ), // Or a specific string like "Change Category"
        children: categories.map((cat) {
          return SimpleDialogOption(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              if (cat['id'] == widget.selectedCategory) return;

              // Save and Navigate
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString("user_category", cat['id'] as String);

              if (!mounted) return;

              // Navigate to Home with new category
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      HomeScreen(selectedCategory: cat['id'] as String),
                ),
              );
            },
            child: Row(
              children: [
                Icon(
                  cat['icon'] as IconData,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cat['label'] as String,
                    style: const TextStyle(fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (cat['id'] == widget.selectedCategory) ...[
                  const SizedBox(width: 8), // Small gap before checkmark
                  const Icon(
                    Icons.check_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: _buildDrawer(),
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          title: Text(
            _getCategoryTitle(context, widget.selectedCategory),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: _showCategoryDialog,
              tooltip: "Change Category",
            ),
            const SizedBox(width: 8),
          ],
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: messages.isEmpty && _currentSessionId == null
                    ? Center(
                        child: Text(
                          "Start a new conversation!",
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) =>
                            ChatBubble(message: messages[index]),
                      ),
              ),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),

              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                style: Theme.of(context).textTheme.bodyLarge,
                enabled: !_loading, // Disable input while loading
                decoration: InputDecoration(
                  hintText: _loading
                      ? "AI is typing..."
                      : AppLocalizations.of(context)!.chatTypeMessage,
                  hintStyle: Theme.of(context).textTheme.bodyMedium,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: IconButton(
              icon: Icon(
                Icons.mic_rounded,
                color: Theme.of(context).primaryColor,
              ),
              onPressed: _loading
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VoiceChatScreen(
                            category: widget.selectedCategory,
                          ),
                        ),
                      );
                    },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: _loading
                ? IconButton(
                    icon: const Icon(Icons.stop_rounded, color: Colors.white),
                    onPressed: _stopGeneration,
                  )
                : IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: sendMessage,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return FractionallySizedBox(
      widthFactor: 0.85, // Slightly wider for better layout
      child: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 1. User Profile Header with Gradient
            Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: _user != null
                  ? Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          backgroundImage: _user!.photoURL != null
                              ? NetworkImage(_user!.photoURL!)
                              : null,
                          child: _user!.photoURL == null
                              ? Text(
                                  _user!.displayName
                                          ?.substring(0, 1)
                                          .toUpperCase() ??
                                      "U",
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _user!.displayName ?? "User",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _user!.email ?? "",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person, color: Colors.grey),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Welcome Guest",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Tap to Login",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // 2. New Chat Button (Prominent)
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _startNewChat,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    "New Chat",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Chat History Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              child: Row(
                children: [
                  Text(
                    "Recent Chats",
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 4. Chat History List
            Expanded(
              child: _user == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 48,
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Login to view history",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: _chatService.getChatSessions(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text(
                              "Error loading chats",
                              style: TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        // Build List
                        final docs = snapshot.data!.docs;
                        // Sort logic...
                        // Re-implement sort to be safe
                        docs.sort((a, b) {
                          final dA = a.data() as Map<String, dynamic>;
                          final dB = b.data() as Map<String, dynamic>;
                          final tA = dA['updatedAt'] as Timestamp?;
                          final tB = dB['updatedAt'] as Timestamp?;
                          if (tA == null || tB == null) return 0;
                          return tB.compareTo(tA);
                        });

                        if (docs.isEmpty) {
                          return Center(
                            child: Text(
                              "No chat history",
                              style: TextStyle(
                                color: Theme.of(context).disabledColor,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final data =
                                docs[index].data() as Map<String, dynamic>;
                            final id = docs[index].id;
                            final title = data['title'] ?? "Untitled Chat";
                            final isActive = id == _currentSessionId;

                            return Dismissible(
                              key: Key(id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) => _deleteSession(id),
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Delete Chat?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Theme.of(
                                          context,
                                        ).primaryColor.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 20,
                                    color: isActive
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).iconTheme.color
                                              ?.withValues(alpha: 0.7),
                                  ),
                                  title: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isActive
                                          ? Theme.of(context).primaryColor
                                          : Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.color, // FIX: Dynamic Color
                                    ),
                                  ),
                                  onTap: () => _loadSession(id),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),

            const Divider(height: 1),

            // 5. Bottom Actions Area
            Container(
              color: Theme.of(context).cardColor.withValues(alpha: 0.5),
              child: Column(
                children: [
                  // Dark Mode
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, currentMode, _) {
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            currentMode == ThemeMode.dark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            size: 20,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        title: Text(
                          "Dark Mode",
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: currentMode == ThemeMode.dark,
                            activeColor: Theme.of(context).primaryColor,
                            onChanged: (val) {
                              themeNotifier.value = val
                                  ? ThemeMode.dark
                                  : ThemeMode.light;
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  // Change Category
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.category_rounded,
                        size: 20,
                        color: Colors.blue,
                      ),
                    ),
                    title: const Text(
                      "Change Category",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: _showCategoryDialog,
                  ),

                  // Language
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.language_rounded,
                        size: 20,
                        color: Colors.orange,
                      ),
                    ),
                    title: Text(
                      AppLocalizations.of(context)!.changeLanguage,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context); // close drawer first
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LanguageSelectionScreen(),
                        ),
                      );
                    },
                  ),

                  // Logout
                  if (_user != null)
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          size: 20,
                          color: Colors.red,
                        ),
                      ),
                      title: const Text(
                        "Logout",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () async {
                        await _authService.signOut();
                        setState(() {
                          _user = null;
                          _currentSessionId = null;
                          messages.clear();
                        });
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    ),

                  const SizedBox(height: 20), // Bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
