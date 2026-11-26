import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/tourist_spot.dart';

const _locaisDemonstracao = <TouristSpot>[
  TouristSpot(
    id: 'encontro-dos-rios',
    name: 'Parque Ambiental Encontro dos Rios',
    category: 'Natureza',
    description: 'Área de visitação no encontro dos rios Poti e Parnaíba.',
    address: 'Bairro Poti Velho, Teresina - PI',
    position: LatLng(-5.03525, -42.83917),
    featured: true,
  ),
  TouristSpot(
    id: 'ponte-estaiada',
    name: 'Ponte Estaiada',
    category: 'Ponto turístico',
    description: 'Cartão-postal de Teresina sobre o rio Poti.',
    address: 'Av. Padre Humberto Pietrogrande, Teresina - PI',
    position: LatLng(-5.07019, -42.80294),
    featured: true,
  ),
  TouristSpot(
    id: 'parque-potycabana',
    name: 'Parque Potycabana',
    category: 'Lazer',
    description: 'Parque urbano para atividades ao ar livre e convivência.',
    address: 'Av. Raul Lopes, Teresina - PI',
    position: LatLng(-5.08467, -42.79213),
  ),
  TouristSpot(
    id: 'museu-do-piaui',
    name: 'Museu do Piauí',
    category: 'História e cultura',
    description:
        'Museu dedicado à preservação da história e da cultura piauiense.',
    address: 'Rua Areolino de Abreu, Centro, Teresina - PI',
    position: LatLng(-5.08974, -42.81760),
  ),
  TouristSpot(
    id: 'theatro-quatro-de-setembro',
    name: 'Theatro 4 de Setembro',
    category: 'Cultura',
    description: 'Espaço tradicional de apresentações artísticas em Teresina.',
    address: 'Praça Pedro II, Centro, Teresina - PI',
    position: LatLng(-5.09192, -42.81329),
    featured: true,
  ),
  TouristSpot(
    id: 'central-artesanato',
    name: 'Central de Artesanato Mestre Dezinho',
    category: 'Artesanato',
    description: 'Espaço de valorização do artesanato e da produção local.',
    address: 'Praça Pedro II, Centro, Teresina - PI',
    position: LatLng(-5.09264, -42.81249),
  ),
];

class PlacesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<TouristSpot>> watchPlaces() {
    return _db.collection('tourist_spots').snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return _locaisDemonstracao;
      return snapshot.docs
          .where((document) => document.data()['isActive'] != false)
          .map(TouristSpot.fromDocument)
          .where((spot) => spot.name.isNotEmpty)
          .toList();
    });
  }

  CollectionReference<Map<String, dynamic>> get _favorites {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Usuário não autenticado');
    return _db.collection('users').doc(user.uid).collection('favorites');
  }

  Stream<Set<String>> watchFavoriteIds() {
    return _favorites.snapshots().map(
      (snapshot) => snapshot.docs.map((document) => document.id).toSet(),
    );
  }

  Future<void> toggleFavorite(TouristSpot spot, bool alreadyFavorite) async {
    final document = _favorites.doc(spot.id);
    if (alreadyFavorite) {
      await document.delete();
    } else {
      await document.set({
        'name': spot.name,
        'category': spot.category,
        'address': spot.address,
        'description': spot.description,
        'imageUrl': spot.imageUrl,
        'latitude': spot.position?.latitude,
        'longitude': spot.position?.longitude,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> saveProfile(User user) {
    return _db.collection('users').doc(user.uid).set({
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> watchFavorites() {
    return _favorites.snapshots().map(
      (snapshot) => snapshot.docs
          .map((document) => {'id': document.id, ...document.data()})
          .toList(),
    );
  }
}
