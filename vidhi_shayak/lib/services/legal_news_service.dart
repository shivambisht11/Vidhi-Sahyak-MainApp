import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/legal_update_model.dart';

class LegalNewsService {
  final String _baseUrl =
      "https://vidhisahayak2004.pythonanywhere.com/api/v1/updates/";
  final String _apiKey = "samBisht-key-123";

  Future<List<LegalUpdate>> fetchLegalUpdates({
    required bool isSupremeCourt,
  }) async {
    try {
      // Build query parameters
      String queryParams;
      if (isSupremeCourt) {
        // Fetch updates filtered by court name "Supreme Court"
        queryParams = "?court_name=Supreme%20Court";
      } else {
        // Fetch "hiring" type updates for the other tab
        queryParams = "?type=hiring";
      }

      final url = Uri.parse("$_baseUrl$queryParams");
      debugPrint("Fetching: $url");

      final response = await http.get(url, headers: {"X-API-KEY": _apiKey});

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => LegalUpdate.fromJson(json)).toList();
      } else {
        debugPrint("API Error: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint("Error fetching updates: $e");
      return [];
    }
  }
}
