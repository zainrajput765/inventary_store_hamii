import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService extends ChangeNotifier {
  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  // 1. Cloud Login (Email/Password)
  Future<bool> login(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      _isAdmin = true; // Cloud login is always Admin
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // 2. NEW: PIN Login (Connects to Firebase silently for Sync)
  Future<bool> loginAnonymously(bool asAdmin) async {
    try {
      // Try to connect to Firebase so Sync works
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      // If offline, ignore error and proceed locally.
      // Sync will start automatically when internet returns.
      debugPrint("Offline Login: $e");
    }

    _isAdmin = asAdmin; // Set Admin rights based on which PIN was used
    notifyListeners();
    return true;
  }

  void logout() {
    FirebaseAuth.instance.signOut();
    _isAdmin = false;
    notifyListeners();
  }
}