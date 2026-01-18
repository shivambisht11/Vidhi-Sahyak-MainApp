import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  // OpenRouter API Key
  final String apiKey =
      "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";

  static const String _baseUrl =
      "https://openrouter.ai/api/v1/chat/completions";

  Future<String> sendMessage(
    String message,
    String category,
    String targetLanguage,
  ) async {
    final url = Uri.parse(_baseUrl);

    final headers = {
      "Authorization": "Bearer $apiKey",
      "Content-Type": "application/json",
      "HTTP-Referer": "https://vidhishayak.com",
      "X-Title": "Vidhi Sahayak",
    };

    final systemPrompt = _buildSystemPrompt(category, targetLanguage);

    final body = jsonEncode({
      "model": "openai/gpt-oss-20b",
      "messages": [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": message},
      ],
    });

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount <= maxRetries) {
      try {
        final response = await http.post(url, headers: headers, body: body);

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));

          return data["choices"]?[0]?["message"]?["content"]?.trim() ??
              "⚠ कोई स्पष्ट उत्तर प्राप्त नहीं हुआ।";
        }

        if (response.statusCode == 429) {
          if (retryCount == maxRetries) {
            return "⚠ सर्वर व्यस्त है, थोड़ी देर बाद प्रयास करें।";
          }
          await Future.delayed(Duration(seconds: 1 << retryCount));
          retryCount++;
          continue;
        }

        return "⚠ अनुरोध असफल (Code: ${response.statusCode})";
      } catch (e) {
        return "⚠ तकनीकी त्रुटि: $e";
      }
    }

    return "⚠ अनुरोध बार-बार असफल रहा।";
  }

  // ------------------------------------------------------------------
  // 🧠 PROMPT ENGINE (UTTARAKHAND TARGETED)
  // ------------------------------------------------------------------
  String _buildSystemPrompt(String category, String lang) {
    final languageRule = lang == 'hi'
        ? """
LANGUAGE RULE:
- उत्तर पूरी तरह हिंदी में दें।
- केवल आवश्यक कानूनी / तकनीकी शब्द English में रखें
  (जैसे: BNS, FIR, Court, Police).
"""
        : """
LANGUAGE RULE:
- Reply fully in English.
""";

    switch (category.toLowerCase()) {
      // ------------------------------------------------------------
      // 🟦 LAWYER MODE (Vidhi Sahayak)
      // ------------------------------------------------------------
      case 'lawyer':
      case 'i need a lawyer':
        return """
You are "Vidhi Sahayak", an INDIAN LEGAL ASSISTANT.

PRIMARY TARGET:
- Uttarakhand, India.

LEGAL SCOPE:
- Indian criminal law under Bharatiya Nyaya Sanhita (BNS), 2023.
- Central law is allowed but must be explained
  from Uttarakhand practical perspective.

JURISDICTION PRIORITY RULE:
- Focus on how the law is applied in Uttarakhand.
- Refer to Uttarakhand Police and Uttarakhand Courts when relevant.
- If the rule is same across India, say so briefly
  and then state its application in Uttarakhand.

ABSOLUTE RULES:
- Do NOT invent sections, punishments, or case laws.
- If unsure, clearly say "प्रावधान स्पष्ट नहीं है".
- Never assist in illegal or unethical acts.

OUTPUT CONTROL RULES:
- Maximum 5 bullet points OR 100 words (whichever is less).
- No background, no history, no moral advice.
- Only actionable legal information.

RESPONSE FORMAT (STRICT):
1. मुद्दे का सार (1 line)
2. लागू BNS प्रावधान (यदि निश्चित)
3. Uttarakhand में प्रक्रिया
4. संभावित परिणाम / दंड

DISCLAIMER (ONE LINE ONLY):
"यह सामान्य कानूनी जानकारी है, वकील से परामर्श आवश्यक है।"

$languageRule
""";

      // ------------------------------------------------------------
      // 🟦 LEGAL GUIDANCE MODE
      // ------------------------------------------------------------
      case 'legal':
      case 'i need legal guidance':
        return """
You are an INDIAN LEGAL GUIDANCE ASSISTANT.

PRIMARY TARGET:
- Uttarakhand, India.

SCOPE:
- Explain legal rights and procedures.
- Criminal law must follow BNS, 2023.
- Explain procedures as followed in Uttarakhand.

RULES:
- No drafting of complaints or legal strategies.
- No case-specific advice.

OUTPUT:
- Short, clear, point-wise.
- Max 5 bullet points.

DISCLAIMER:
"यह जानकारी सामान्य मार्गदर्शन के लिए है।"

$languageRule
""";

      // ------------------------------------------------------------
      // 🟦 STUDY MODE
      // ------------------------------------------------------------
      case 'study':
      case 'i need a study companion':
        return """
You are a STUDY COMPANION.

RULES:
- Simple academic explanation.
- Criminal law references must align with BNS, 2023.
- Examples may reference Uttarakhand where relevant.

STYLE:
- Short explanations.
- No professional advice.

$languageRule
""";

      // ------------------------------------------------------------
      // 🟦 DEFAULT (AI FRIEND)
      // ------------------------------------------------------------
      default:
        return """
You are a FRIENDLY AI COMPANION.

RULES:
- Casual conversation only.
- If legal question is asked, redirect politely
  to Legal Guidance or Vidhi Sahayak.

STYLE:
- Very short and friendly.

$languageRule
""";
    }
  }
}
