import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../controllers/auth_controller.dart';
import '../controllers/places_controller.dart';
import '../models/tourist_spot.dart';
import '../services/places_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.user});
  final User user;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    PlacesService().saveProfile(widget.user).catchError((Object _) {});
    _pages = [
      ExplorePage(onOpenMap: () => setState(() => _tab = 1)),
      const PlacesMapPage(),
      const FavoritesPage(),
      ProfilePage(user: widget.user),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Início',
          ),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Mapa'),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            label: 'Salvos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, required this.onOpenMap});
  final VoidCallback onOpenMap;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _places = PlacesController();
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text.trim()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName?.split(' ').first ?? 'viajante');
    return SafeArea(
      child: StreamBuilder<List<TouristSpot>>(
        stream: _places.places,
        builder: (context, placeSnapshot) {
          return StreamBuilder<Set<String>>(
            stream: _places.favoriteIds,
            builder: (context, favoriteSnapshot) {
              if (placeSnapshot.hasError || favoriteSnapshot.hasError) {
                return const _StatusMessage(
                  icon: Icons.cloud_off,
                  message: 'Não foi possível carregar os lugares.',
                );
              }
              if (!placeSnapshot.hasData || !favoriteSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = placeSnapshot.data!;
              final favorites = favoriteSnapshot.data!;
              final filtered = all.where((spot) {
                return spot.name.toLowerCase().contains(_query.toLowerCase()) ||
                    spot.category.toLowerCase().contains(_query.toLowerCase());
              }).toList();
              final featured = filtered.where((spot) => spot.featured).toList();
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'EXPLORE TERESINA',
                                    style: TextStyle(
                                      color: Color(0xFF176B5B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Olá, $name 👋',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CircleAvatar(
                              backgroundColor: const Color(0xFFE0EEE9),
                              foregroundImage: user?.photoURL == null
                                  ? null
                                  : NetworkImage(user!.photoURL!),
                              child: user?.photoURL == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Color(0xFF176B5B),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _search,
                          decoration: InputDecoration(
                            hintText: 'Buscar um lugar ou categoria',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _NearbyBanner(onTap: widget.onOpenMap),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Descubra a cidade',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${filtered.length} lugares',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (all.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 36),
                            child: _StatusMessage(
                              icon: Icons.place_outlined,
                              message: 'Nenhum local cadastrado no catálogo.',
                            ),
                          ),
                        if (featured.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Em destaque',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final spot in featured)
                            PlaceCard(
                              spot: spot,
                              favorite: favorites.contains(spot.id),
                              onFavorite: () =>
                                  _places.toggleFavorite(spot, favorites),
                            ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          featured.isEmpty
                              ? 'Lugares próximos'
                              : 'Todos os locais',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final spot in filtered)
                          PlaceCard(
                            spot: spot,
                            favorite: favorites.contains(spot.id),
                            onFavorite: () =>
                                _places.toggleFavorite(spot, favorites),
                          ),
                      ]),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _NearbyBanner extends StatelessWidget {
  const _NearbyBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF176B5B),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perto de você',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Explore os pontos no mapa',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.near_me_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.spot,
    required this.favorite,
    required this.onFavorite,
  });

  final TouristSpot spot;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SpotDetailsPage(spot: spot, favorite: favorite),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _SpotArtwork(spot: spot, height: 86, width: 92),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.category.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF176B5B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spot.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      spot.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: favorite ? 'Remover dos salvos' : 'Salvar local',
                onPressed: onFavorite,
                icon: Icon(
                  favorite ? Icons.favorite : Icons.favorite_border,
                  color: favorite ? Colors.redAccent : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotArtwork extends StatelessWidget {
  const _SpotArtwork({
    required this.spot,
    required this.height,
    required this.width,
  });
  final TouristSpot spot;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final image = spot.imageUrl;
    if (image != null && image.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          image,
          height: height,
          width: width,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFFB9DDD0), Color(0xFFEDF4EF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        _categoryIcon(spot.category),
        size: 34,
        color: const Color(0xFF176B5B),
      ),
    );
  }
}

IconData _categoryIcon(String category) {
  final value = category.toLowerCase();
  if (value.contains('natureza')) return Icons.park_outlined;
  if (value.contains('lazer')) return Icons.directions_walk;
  if (value.contains('hist')) return Icons.museum_outlined;
  if (value.contains('cultura')) return Icons.theater_comedy_outlined;
  if (value.contains('artesanato')) return Icons.brush_outlined;
  return Icons.location_city_outlined;
}

class PlacesMapPage extends StatefulWidget {
  const PlacesMapPage({super.key});

  @override
  State<PlacesMapPage> createState() => _PlacesMapPageState();
}

class _PlacesMapPageState extends State<PlacesMapPage> {
  final _places = PlacesController();
  GoogleMapController? _map;
  Set<String> _favorites = {};
  bool _locationEnabled = false;
  static const _center = LatLng(-5.0892, -42.8019);

  Future<void> _showLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _message('Ative o GPS do aparelho para ver sua posição.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _message('Permissão de localização não liberada.');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _locationEnabled = true);
      await _map?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          14,
        ),
      );
    } catch (_) {
      _message('Não foi possível acessar sua localização.');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<TouristSpot>>(
        stream: _places.places,
        builder: (context, placeSnapshot) => StreamBuilder<Set<String>>(
          stream: _places.favoriteIds,
          builder: (context, favoriteSnapshot) {
            _favorites = favoriteSnapshot.data ?? {};
            final spots = placeSnapshot.data ?? [];
            final markers = <Marker>{
              for (final spot in spots)
                if (spot.position != null)
                  Marker(
                    markerId: MarkerId(spot.id),
                    position: spot.position!,
                    infoWindow: InfoWindow(
                      title: spot.name,
                      snippet: '${spot.category} · toque para ver informações',
                      onTap: () => _openSpot(spot),
                    ),
                    onTap: () => _openSpot(spot),
                  ),
            };
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Explore no mapa',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('Toque em um marcador para ver o local'),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Minha localização',
                        onPressed: _showLocation,
                        icon: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: _center,
                        zoom: 11.5,
                      ),
                      markers: markers,
                      myLocationEnabled: _locationEnabled,
                      myLocationButtonEnabled: false,
                      onMapCreated: (controller) => _map = controller,
                    ),
                  ),
                ),
                if (placeSnapshot.hasData)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      '${markers.length} pontos no mapa',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openSpot(TouristSpot spot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SpotDetailsPage(spot: spot, favorite: _favorites.contains(spot.id)),
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final places = PlacesController();
    return SafeArea(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: places.favorites,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _StatusMessage(
              icon: Icons.cloud_off,
              message: 'Erro ao carregar os locais salvos.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          return CustomScrollView(
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seus lugares',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('Locais que você guardou para visitar.'),
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _StatusMessage(
                    icon: Icons.favorite_border,
                    message: 'Seus locais salvos vão aparecer aqui.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final spot = TouristSpot(
                        id: item['id'] as String,
                        name: item['name'] as String? ?? 'Local turístico',
                        category: item['category'] as String? ?? 'Teresina',
                        address: item['address'] as String? ?? 'Teresina - PI',
                        description: item['description'] as String? ?? '',
                        imageUrl: item['imageUrl'] as String?,
                        position:
                            item['latitude'] is num && item['longitude'] is num
                            ? LatLng(
                                (item['latitude'] as num).toDouble(),
                                (item['longitude'] as num).toDouble(),
                              )
                            : null,
                      );
                      return PlaceCard(
                        spot: spot,
                        favorite: true,
                        onFavorite: () => PlacesService()
                            .toggleFavorite(spot, true)
                            .catchError((Object _) {}),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Perfil',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    foregroundImage: user.photoURL == null
                        ? null
                        : NetworkImage(user.photoURL!),
                    child: user.photoURL == null
                        ? const Icon(Icons.person, size: 38)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.displayName ?? 'Pessoa visitante',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? '',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline, color: Color(0xFF176B5B)),
                  title: Text('Sobre o Explore Teresina'),
                  subtitle: Text('Um guia para conhecer os pontos da cidade.'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sair da conta'),
                  onTap: () => AuthController().signOut(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SpotDetailsPage extends StatefulWidget {
  const SpotDetailsPage({
    super.key,
    required this.spot,
    required this.favorite,
  });
  final TouristSpot spot;
  final bool favorite;

  @override
  State<SpotDetailsPage> createState() => _SpotDetailsPageState();
}

class _SpotDetailsPageState extends State<SpotDetailsPage> {
  final _places = PlacesController();
  late bool _favorite = widget.favorite;

  Future<void> _toggleFavorite() async {
    try {
      await _places.toggleFavorite(widget.spot, {
        _favorite ? widget.spot.id : '',
      });
      if (mounted) setState(() => _favorite = !_favorite);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar este local.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do local')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _SpotArtwork(spot: spot, height: 220, width: double.infinity),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.category.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF176B5B),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      spot.name,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: _favorite ? 'Remover dos salvos' : 'Salvar local',
                onPressed: _toggleFavorite,
                icon: Icon(
                  _favorite ? Icons.favorite : Icons.favorite_border,
                  color: _favorite ? Colors.redAccent : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Sobre este lugar',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            spot.description.isEmpty
                ? 'Conheça este ponto de Teresina e aproveite a visita.'
                : spot.description,
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.location_on_outlined,
                color: Color(0xFF176B5B),
              ),
              title: const Text('Endereço'),
              subtitle: Text(spot.address),
            ),
          ),
          if (spot.position != null) ...[
            const SizedBox(height: 14),
            Card(
              child: SizedBox(
                height: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: spot.position!,
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: MarkerId(spot.id),
                        position: spot.position!,
                        infoWindow: InfoWindow(title: spot.name),
                      ),
                    },
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    liteModeEnabled: true,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: Colors.grey[500]),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
