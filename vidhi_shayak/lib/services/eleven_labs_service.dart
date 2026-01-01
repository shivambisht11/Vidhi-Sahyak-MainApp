import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ElevenLabsService {
  // ⚠️ REPLACE THIS WITH YOUR API KEY
  static const String apiKey =
      'sk_8e7778e9674cdb11c13319db1dc9cea4412c29c1ecccfc3b';

  // Voice ID for "George" (British, Warm, Professional) - or any other you prefer
  static const String voiceId = 'JBFqnCBsd6RMkjVDRZzb';

  static Future<File?> streamAudio(String text) async {
    const String url = 'https://api.elevenlabs.io/v1/text-to-speech/$voiceId';
    int retryCount = 0;
    const int maxRetries = 2; // Reduced for speed since paid key is reliable

    while (retryCount < maxRetries) {
      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: {
                'xi-api-key': apiKey.trim(),
                'Content-Type': 'application/json',
                'Accept': 'audio/mpeg',
              },
              body: jsonEncode({
                "text": text,
                "model_id":
                    "eleven_multilingual_v2", // Best for mixed Hindi/English
                "voice_settings": {
                  "stability": 0.5,
                  "similarity_boost": 0.8,
                  "style": 0.5,
                  "use_speaker_boost": true,
                },
              }),
            )
            .timeout(const Duration(seconds: 10)); // Reduced timeout

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final dir = await getTemporaryDirectory();
          final file = File(
            '${dir.path}/response_${DateTime.now().millisecondsSinceEpoch}.mp3',
          );
          await file.writeAsBytes(bytes);
          return file;
        } else {
          // print('ElevenLabs Error Body: ${response.body}'); // 🔍 DEBUGGING
          // If 401/402, do NOT retry.
          if (response.statusCode == 401 || response.statusCode == 402) {
            throw Exception(
              'Auth/Quota Error: ${response.statusCode} - ${response.body}',
            );
          }
          print('Attempt ${retryCount + 1} failed: ${response.statusCode}');
        }
      } catch (e) {
        print('Attempt ${retryCount + 1} exception: $e');
        if (retryCount == maxRetries - 1) rethrow; // Throw on last attempt
      }

      retryCount++;
      await Future.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getSubscriptionDetails() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.elevenlabs.io/v1/user/subscription'),
        headers: {'xi-api-key': apiKey.trim()},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Subscription Error: ${response.statusCode} ${response.body}");
        return null;
      }
    } catch (e) {
      print("Subscription Exception: $e");
      return null;
    }
  }
}
