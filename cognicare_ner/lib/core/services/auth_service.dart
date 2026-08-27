import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around [FirebaseAuth] for CogniCare NER's three roles.
///
/// Auth strategy per the platform architecture (§11 role-based access):
///   * Patient devices  -> anonymous auth (the patient never types credentials).
///   * Caregiver devices -> email / password.
///   * Doctor dashboard  -> email / password.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// The currently signed-in user, or `null` if signed out.
  User? get currentUser => _auth.currentUser;

  /// Emits on every sign-in / sign-out so the UI can react to auth changes.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Patient devices sign in silently with an anonymous account.
  Future<UserCredential> signInAnonymously() {
    return _auth.signInAnonymously();
  }

  /// Caregiver / doctor sign-in with email + password.
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Registers a new caregiver (email + password) account.
  ///
  /// Doctors are provisioned the same way; the name reflects the primary
  /// self-service flow (caregivers onboard themselves, doctors are typically
  /// invited).
  Future<UserCredential> registerCaregiver(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Signs the current user out.
  Future<void> signOut() => _auth.signOut();
}
