import '../models/tourist_spot.dart';
import '../services/places_service.dart';

class PlacesController {
  final PlacesService _service = PlacesService();

  Stream<List<TouristSpot>> get places => _service.watchPlaces();
  Stream<Set<String>> get favoriteIds => _service.watchFavoriteIds();
  Stream<List<Map<String, dynamic>>> get favorites => _service.watchFavorites();

  Future<void> toggleFavorite(TouristSpot spot, Set<String> favorites) {
    return _service.toggleFavorite(spot, favorites.contains(spot.id));
  }
}
