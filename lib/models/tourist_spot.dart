import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TouristSpot {
  const TouristSpot({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.address,
    this.imageUrl,
    this.position,
    this.featured = false,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final String address;
  final String? imageUrl;
  final LatLng? position;
  final bool featured;

  factory TouristSpot.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final location = data['location'];
    LatLng? position;
    if (location is GeoPoint) {
      position = LatLng(location.latitude, location.longitude);
    } else if (location is Map &&
        location['latitude'] is num &&
        location['longitude'] is num) {
      position = LatLng(
        (location['latitude'] as num).toDouble(),
        (location['longitude'] as num).toDouble(),
      );
    } else if (data['latitude'] is num && data['longitude'] is num) {
      position = LatLng(
        (data['latitude'] as num).toDouble(),
        (data['longitude'] as num).toDouble(),
      );
    }
    return TouristSpot(
      id: document.id,
      name: data['name'] as String? ?? 'Local turístico',
      category:
          data['category'] as String? ??
          data['categoryName'] as String? ??
          data['categoryId'] as String? ??
          'Ponto turístico',
      description: data['description'] as String? ?? '',
      address: data['address'] as String? ?? 'Teresina, PI',
      imageUrl:
          data['imageUrl'] as String? ??
          data['image'] as String? ??
          data['imageAsset'] as String?,
      position: position,
      featured: data['isFeatured'] as bool? ?? false,
    );
  }
}
