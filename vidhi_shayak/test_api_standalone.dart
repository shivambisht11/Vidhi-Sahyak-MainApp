import 'dart:convert';
import 'package:http/http.dart' as http;

// Mock model
class LegalUpdate {
  final int id;
  final String title;

  LegalUpdate({required this.id, required this.title});

  factory LegalUpdate.fromJson(Map<String, dynamic> json) {
    return LegalUpdate(id: json['id'] as int, title: json['title'] as String);
  }
}

// Standalone Service logic
class LegalNewsService {
  final String _baseUrl =
      "https://vidhisahayak2004.pythonanywhere.com/api/v1/updates/";
  final String _apiKey = "samBisht-key-123";

  Future<void> fetchLegalUpdates({required bool isSupremeCourt}) async {
    try {
      String queryParams;
      if (isSupremeCourt) {
        queryParams = "?court_name=Supreme%20Court";
      } else {
        queryParams = "?type=hiring";
      }

      final url = Uri.parse("$_baseUrl$queryParams");
      print("Fetching: $url");

      final response = await http.get(url, headers: {"X-API-KEY": _apiKey});

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print("Success! Fetched ${data.length} updates.");
        if (data.isNotEmpty) {
          print("First item: ${data[0]['title']}");
        }
      } else {
        print("API Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error fetching updates: $e");
    }
  }
}

void main() async {
  print("Starting Standalone API Test...");
  final service = LegalNewsService();

  print("\n--- Testing Supreme Court Updates ---");
  await service.fetchLegalUpdates(isSupremeCourt: true);

  print("\n--- Testing Hiring/High Court Updates ---");
  await service.fetchLegalUpdates(isSupremeCourt: false);
}
