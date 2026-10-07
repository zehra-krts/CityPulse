import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  bool _isAdmin = false;

  User? get user => _user;
  bool get isAdmin => _isAdmin;
  bool get isLoggedIn => _user != null;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _checkAdminStatus();
      notifyListeners();
    });
  }

  void _checkAdminStatus() {
    if (_user != null) {
      // Admin e-posta adreslerini kontrol et
      _isAdmin = _user!.email == 'admin@example.com';
    } else {
      _isAdmin = false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
