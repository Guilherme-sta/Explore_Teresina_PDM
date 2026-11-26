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
      title: 'Explore Teresina',
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
          return MapPage(user: snapshot.data!);
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

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.user});

  final User user;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _teresina = LatLng(-5.0892, -42.8019);

  GoogleMapController? _controller;
  final Set<Marker> _marcadores = {
    const Marker(
      markerId: MarkerId('teresina'),
      position: _teresina,
      infoWindow: InfoWindow(
        title: 'Teresina',
        snippet: 'Marcador de teste (posição ilustrativa)',
      ),
    ),
  };
  bool _localizacaoLiberada = false;

  void _mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _irParaMinhaLocalizacao() async {
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
  }

  @override
  Widget build(BuildContext context) {
    final nome = widget.user.displayName ?? widget.user.email ?? 'Usuário';

    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, $nome', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(target: _teresina, zoom: 12),
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