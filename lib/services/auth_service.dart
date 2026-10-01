import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // Getter en vez de campo: si Firebase aún no está inicializado (p. ej. en
  // tests que no llaman a Firebase.initializeApp), el error ocurre recién al
  // usar _auth, no al construir el singleton.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get userStream => _auth.authStateChanges();

  /// uid de la bodega actual (el usuario autenticado), o null si no hay
  /// sesión activa o si Firebase no está disponible todavía. A diferencia de
  /// [currentUser], nunca lanza: lo usan los repositorios para estampar
  /// bodega_id sin tener que manejar la excepción ellos mismos.
  String? get currentUid {
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Future<UserCredential> register(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.updateDisplayName(name);
    return cred;
  }

  Future<UserCredential> login(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
