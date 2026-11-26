import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';

class AuthController {
  final AuthService _service = AuthService();

  Stream<User?> get userChanges => _service.userChanges;
  User? get currentUser => _service.currentUser;

  Future<void> initializeGoogle() => _service.initializeGoogle();
  Future<void> signIn(String email, String password) =>
      _service.signIn(email, password);
  Future<void> register(String email, String password) =>
      _service.register(email, password);
  Future<void> resetPassword(String email) => _service.resetPassword(email);
  Future<void> signInWithGoogle() => _service.signInWithGoogle();
  Future<void> signOut() => _service.signOut();
}
