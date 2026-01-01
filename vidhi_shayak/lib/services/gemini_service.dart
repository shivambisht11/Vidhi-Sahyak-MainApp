import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  final String apiKey =
      "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";

  Future<String> sendMessage(String message, String category) async {
    final url = Uri.parse("https://openrouter.ai/api/v1/chat/completions");
    final headers = {
      "Authorization": "Bearer $apiKey",
      "Content-Type": "application/json",
      "HTTP-Referer": "https://vidhishayak.com", // Site URL for rankings
      "X-Title": "Vidhi Shayak", // Site title for rankings
    };

    String systemPrompt = "";
    switch (category) {
      case 'lawyer':
      case 'legal':
      case 'I need a lawyer':
      case 'I need legal guidance':
        systemPrompt =
            "You are a professional LAW expert. Only answer law-related queries.\n"
            "IMPORTANT: Users may use abbreviations or incomplete words (e.g., 'ip' for 'IPC', 'sec' for 'Section').\n"
            "ALWAYS interpret ambiguous terms in a LEGAL context first (e.g., treat 'ip 302' as 'IPC Section 302').\n"
            "If the query is clearly non-legal even after interpretation, reply: ⚠ Sorry, I can only answer legal queries.";
        break;
      case 'study':
      case 'I need a study companion':
        systemPrompt =
            "You are a helpful Study Assistant. Explain concepts in simple words with examples. Never give legal advice.";
        break;
      case 'other':
      case 'Other':
        systemPrompt =
            "You are a helpful assistant. Reply casually and keep answers short.";
        break;
      default:
        systemPrompt = "You are a helpful AI Assistant.";
    }

    final body = jsonEncode({
      "model":
          "nvidia/nemotron-3-nano-30b-a3b:free", // Updated to Nvidia Nemotron
      "messages": [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": message},
      ],
      "reasoning": {"enabled": true},
    });

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount <= maxRetries) {
      try {
        final response = await http.post(url, headers: headers, body: body);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data["choices"][0]["message"]["content"] ??
              "⚠ Unexpected response format.";
        } else if (response.statusCode == 429) {
          // Rate Limit Hit
          if (retryCount == maxRetries) {
            return "⚠ Server is currently busy (High Traffic). Please try again in 5-10 seconds.";
          }
          // Exponential backoff: 1s, 2s, 4s...
          final waitConfig = Duration(seconds: 1 * (1 << retryCount));
          await Future.delayed(waitConfig);
          retryCount++;
        } else {
          return "⚠ Request failed (Code: ${response.statusCode}): ${response.body}";
        }
      } catch (e) {
        return "⚠ Network error: $e";
      }
    }
    return "⚠ Request failed due to repeated rate limits.";
  }
}
