import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Stream status login (untuk AuthWrapper) ────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── 1. Login Email & Password ──────────────────────────────────────────────
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("LoginError [${e.code}]: ${e.message}");
      rethrow; // lempar kembali agar UI bisa tampilkan pesan spesifik
    }
  }

  // ── 2. Register Email & Password ───────────────────────────────────────────
  Future<User?> registerWithEmail(
      String email, String password, String name) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await user.reload();
        user = _auth.currentUser;
      }
      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint("RegisterError [${e.code}]: ${e.message}");
      rethrow;
    }
  }

  // ── 3. Google Sign In ──────────────────────────────────────────────────────
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancel

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("GoogleSignInError [${e.code}]: ${e.message}");
      rethrow;
    } catch (e) {
      debugPrint("GoogleSignInError (general): $e");
      rethrow;
    }
  }

  // ── 4. Logout ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Helper: Terjemahkan kode error Firebase ke pesan Indonesia ────────────
  static String translateError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Email tidak terdaftar.';
      case 'wrong-password':
        return 'Password salah. Coba lagi.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun ini telah dinonaktifkan.';
      case 'email-already-in-use':
        return 'Email sudah digunakan akun lain.';
      case 'weak-password':
        return 'Password terlalu lemah (min. 6 karakter).';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'invalid-credential':
        return 'Email atau password salah.';
      default:
        return 'Terjadi kesalahan. Silakan coba lagi.';
    }
  }
}