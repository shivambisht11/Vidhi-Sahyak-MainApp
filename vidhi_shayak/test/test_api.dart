// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final apiKey =
      "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";
  final url = Uri.parse("https://openrouter.ai/api/v1/chat/completions");
  final headers = {
    "Authorization": "Bearer $apiKey",
    "Content-Type": "application/json",
  };

  final body = jsonEncode({
    "model": "openai/gpt-oss-20b:free",
    "messages": [
      {"role": "user", "content": "Hello"},
    ],
  });

  print("Testing API...");
  try {
    final response = await http.post(url, headers: headers, body: body);
    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");
  } catch (e) {
    print("Error: $e");
  }
}
