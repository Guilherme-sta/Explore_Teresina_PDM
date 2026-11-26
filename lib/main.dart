import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Explore Teresina - Teste',
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        )
      ),
      home: const AuthGate(),
    );
  }
}

class UserDataService {
  UserDataService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> get _userDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Usuário não autenticado');
    return _db.collection('users').doc(uid);
  }

  Future<void> saveProfile() {
    final user = _auth.currentUser!;
    return _userDoc.set({
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addFavorite(String spotId, String name) {
    return _userDoc.collection('favorites').doc(spotId).set({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFavorite(String spotId) {
    return _userDoc.collection('favorites').doc(spotId).delete();
  }

  Stream<List<Map<String, dynamic>>> watchFavorites() {
    return _userDoc
        .collection('favorites')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return MapPage(key: ValueKey(snapshot.data!.uid), user: snapshot.data!);
        }
        return const LoginPage();
      },
    );
  }
}

String _mensagemErro(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'E-mail inválido.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'E-mail ou senha incorretos.';
    case 'email-already-in-use':
      return 'Este e-mail já está cadastrado.';
    case 'weak-password':
      return 'Senha fraca: use pelo menos 6 caracteres.';
    case 'network-request-failed':
      return 'Sem conexão com a internet.';
    case 'too-many-requests':
      return 'Muitas tentativas. Tente novamente mais tarde.';
    default:
      return 'Erro: ${e.message ?? e.code}';
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _mostrarMensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _executar(Future<void> Function() acao) async {
    setState(() => _carregando = true);
    try {
      await acao();
    } on FirebaseAuthException catch (e) {
      _mostrarMensagem(_mensagemErro(e));
    } catch (e) {
      _mostrarMensagem('Não foi possível concluir: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _entrar() => _executar(() async {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _senhaController.text,
        );
      });

  Future<void> _cadastrar() => _executar(() async {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _senhaController.text,
        );
      });

  Future<void> _recuperarSenha() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _mostrarMensagem('Digite seu e-mail para recuperar a senha.');
      return;
    }
    await _executar(() async {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _mostrarMensagem('Link de recuperação enviado para $email.');
    });
  }

  Future<void> _entrarComGoogle() => _executar(() async {
        await FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider());
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.explore,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Explore Teresina',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _senhaController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _carregando ? null : _entrar,
                    child: _carregando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _carregando ? null : _cadastrar,
                    child: const Text('Criar conta'),
                  ),
                  TextButton(
                    onPressed: _carregando ? null : _recuperarSenha,
                    child: const Text('Esqueci minha senha'),
                  ),
                  const Divider(height: 32),
                  OutlinedButton.icon(
                    onPressed: _carregando ? null : _entrarComGoogle,
                    icon: const Icon(Icons.login),
                    label: const Text('Entrar com Google'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Local {
  const _Local(this.id, this.nome, this.posicao);
  final String id;
  final String nome;
  final LatLng posicao;
}

const _locaisTeste = <_Local>[
  _Local('teresina', 'Teresina (centro)', LatLng(-5.0892, -42.8019)),
];

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.user});

  final User user;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _centro = LatLng(-5.0892, -42.8019);

  final _dados = UserDataService();
  GoogleMapController? _controller;
  StreamSubscription<List<Map<String, dynamic>>>? _favoritosSub;
  Set<String> _favoritos = {};
  bool _localizacaoLiberada = false;

  @override
  void initState() {
    super.initState();
    _dados.saveProfile().catchError((Object e) {
      _mostrarMensagem('Não foi possível salvar o perfil: $e');
    });
    _favoritosSub = _dados.watchFavorites().listen(
      (lista) {
        if (!mounted) return;
        setState(() => _favoritos = lista.map((f) => f['id'] as String).toSet());
      },
      onError: (Object e) => _mostrarMensagem('Erro ao carregar favoritos: $e'),
    );
  }

  @override
  void dispose() {
    _favoritosSub?.cancel();
    super.dispose();
  }

  void _mostrarMensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _alternarFavorito(_Local local) async {
    try {
      if (_favoritos.contains(local.id)) {
        await _dados.removeFavorite(local.id);
        _mostrarMensagem('Removido dos favoritos.');
      } else {
        await _dados.addFavorite(local.id, local.nome);
        _mostrarMensagem('Adicionado aos favoritos.');
      }
    } catch (e) {
      _mostrarMensagem('Não foi possível atualizar o favorito: $e');
    }
  }

  Set<Marker> get _marcadores => {
        for (final local in _locaisTeste)
          Marker(
            markerId: MarkerId(local.id),
            position: local.posicao,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _favoritos.contains(local.id)
                  ? BitmapDescriptor.hueRose
                  : BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: local.nome,
              snippet: _favoritos.contains(local.id)
                  ? 'Favorito · toque para remover'
                  : 'Toque para favoritar',
              onTap: () => _alternarFavorito(local),
            ),
          ),
      };

  Future<void> _irParaMinhaLocalizacao() async {
    try {
      final gpsAtivo = await Geolocator.isLocationServiceEnabled();
      if (!gpsAtivo) {
        _mostrarMensagem('Ative o GPS do aparelho.');
        return;
      }

      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }
      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        _mostrarMensagem('Permissão de localização negada.');
        return;
      }

      final posicao = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _localizacaoLiberada = true);
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(posicao.latitude, posicao.longitude),
          15,
        ),
      );
    } catch (e) {
      _mostrarMensagem('Não foi possível obter a localização: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nome = widget.user.displayName ?? widget.user.email ?? 'Usuário';

    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, $nome', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Favoritos',
            icon: const Icon(Icons.favorite),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesPage()),
            ),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(target: _centro, zoom: 12),
        markers: _marcadores,
        myLocationEnabled: _localizacaoLiberada,
        myLocationButtonEnabled: false,
        onMapCreated: (controller) => _controller = controller,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Minha localização',
        onPressed: _irParaMinhaLocalizacao,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dados = UserDataService();
    return Scaffold(
      appBar: AppBar(title: const Text('Meus favoritos')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: dados.watchFavorites(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar favoritos.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final itens = snapshot.data!;
          if (itens.isEmpty) {
            return const Center(child: Text('Nenhum favorito ainda.'));
          }
          return ListView(
            children: [
              for (final f in itens)
                ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.redAccent),
                  title: Text(f['name'] as String? ?? ''),
                  trailing: IconButton(
                    tooltip: 'Remover',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => dados.removeFavorite(f['id'] as String),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}