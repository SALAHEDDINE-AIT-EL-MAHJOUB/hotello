class TourService {
  String? id;
  String title;
  String imageUrl;
  String subtitle; // e.g., price, short blurb
  String description;
  String? category; // Optional: e.g., "Excursion", "City Tour"

  TourService({
    this.id,
    required this.title,
    required this.imageUrl,
    required this.subtitle,
    required this.description,
    this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'subtitle': subtitle,
      'description': description,
      'category': category,
    };
  }

  factory TourService.fromJson(Map<dynamic, dynamic> json, String id) {
    return TourService(
      id: id,
      title: json['title'] ?? 'N/A',
      imageUrl: json['imageUrl'] ?? '',
      subtitle: json['subtitle'] ?? '',
      description: json['description'] ?? '',
      category: json['category'],
    );
  }
}