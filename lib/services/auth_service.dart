import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Represents the user's data after a successful login.
class AppUser {
  final String id_account;
  final String name;
  final String stripe_id;

  AppUser({
    required this.id_account,
    required this.name,
    required this.stripe_id,
  });
}

// This service will manage the user's authentication state.
class AuthService extends ChangeNotifier {
  AppUser? _user;
  AppUser? get user => _user;

  bool get isLoggedIn => _user != null;

  // --- FAKE API CALL ---
  // In real app, this would make an HTTP request.
  Future<AppUser?> _fakeApiLogin(String username, String password) async {
    // Simulate a network delay.
    await Future.delayed(const Duration(seconds: 2));

    // For this example, any username/password is accepted.
    // In a real app, you would check for a 200 OK status code.
    if (username.isNotEmpty && password.isNotEmpty) {
      // Return fake user data.
      return AppUser(
        id_account: "1",
        name: "Henry",
        stripe_id: "cus_Rzs2woOxyayOBV",
      );
    } else {
      // Return null if login "fails".
      return null;
    }
  }

  // --- PUBLIC METHODS ---

  Future<bool> login(String username, String password) async {
    final user = await _fakeApiLogin(username, password);

    if (user != null) {
      _user = user;

      // Save user session to device storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userAccountId', user.name);
      await prefs.setString('userName', user.name);
      await prefs.setString('userStripeId', user.stripe_id);

      notifyListeners(); // Notify widgets that the user has changed.
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _user = null;

    // Clear user session from device storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userAccountId');
    await prefs.remove('userName');
    await prefs.remove('userStripeId');

    notifyListeners();
  }

  // Method to check for a logged-in user when the app starts.
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userAccountId') ||
        !prefs.containsKey('userName') ||
        !prefs.containsKey('userStripeId')) {
      return;
    }

    final savedAccountId = prefs.getString('userAccountId')!;
    final savedName = prefs.getString('userName')!;
    final savedStripeId = prefs.getString('userStripeId')!;

    _user = AppUser(
      id_account: savedAccountId,
      name: savedName,
      stripe_id: savedStripeId,
    );
    notifyListeners();
  }
}
