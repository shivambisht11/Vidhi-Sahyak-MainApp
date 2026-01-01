import 'package:flutter/material.dart';
import 'lib/services/legal_news_service.dart';
import 'lib/models/legal_update_model.dart';

void main() async {
  print("Starting API Test...");
  final service = LegalNewsService();

  print("\n--- Testing Supreme Court Updates ---");
  var scUpdates = await service.fetchLegalUpdates(isSupremeCourt: true);
  if (scUpdates.isNotEmpty) {
    print("Success! Fetched ${scUpdates.length} Supreme Court updates.");
    print("First update: ${scUpdates.first.title}");
  } else {
    print("Warning: No Supreme Court updates returned (or API failed).");
  }

  print("\n--- Testing Hiring/High Court Updates ---");
  var hiringUpdates = await service.fetchLegalUpdates(isSupremeCourt: false);
  if (hiringUpdates.isNotEmpty) {
    print("Success! Fetched ${hiringUpdates.length} Hiring updates.");
    print("First update: ${hiringUpdates.first.title}");
  } else {
    print("Warning: No Hiring updates returned (or API failed).");
  }
}
