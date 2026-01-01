class LegalUpdate {
  final int id;
  final String courtName;
  final String category;
  final String title;
  final DateTime? publishedDate;
  final String sourceUrl;
  final String type;
  final String contentSummary;

  LegalUpdate({
    required this.id,
    required this.courtName,
    required this.category,
    required this.title,
    this.publishedDate,
    required this.sourceUrl,
    required this.type,
    required this.contentSummary,
  });

  factory LegalUpdate.fromJson(Map<String, dynamic> json) {
    return LegalUpdate(
      id: json['id'] ?? 0,
      courtName: json['court_name'] ?? '',
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      publishedDate: json['published_date'] != null
          ? DateTime.tryParse(json['published_date'])
          : null,
      sourceUrl: json['source_url'] ?? '',
      type: json['type'] ?? '',
      contentSummary: json['content_summary'] ?? '',
    );
  }
}
