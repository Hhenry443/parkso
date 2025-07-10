import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'screens/auth_wrapper.dart';

void main() async {
  // Ensure that Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Stripe publishable key
  Stripe.publishableKey =
      'pk_test_wGQVF7QeuldBJrMPt10D2esF'; // <-- REPLACE WITH CHRIS KEY

  // Set Mapbox access token
  const String accessToken =
      "pk.eyJ1IjoiaGhlbnJ5NDQzIiwiYSI6ImNtYWduM2c0dzAydHgyaXNnZGc4cGRsejUifQ.PgHjAohNcSOClqxrxlyBKg";
  MapboxOptions.setAccessToken(accessToken);

  // Run the application.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The ChangeNotifierProvider makes the AuthService available to all child widgets.
    return ChangeNotifierProvider(
      create: (context) => AuthService(),
      child: MaterialApp(
        title: 'Parkso',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        debugShowCheckedModeBanner: false, // Kept from your old MaterialApp
        home: const AppStartupScreen(),
      ),
    );
  }
}

// This screen handles the initial check for a logged-in user.
class AppStartupScreen extends StatefulWidget {
  const AppStartupScreen({super.key});

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> {
  @override
  void initState() {
    super.initState();
    // Attempt to log the user in automatically when the app starts.
    Provider.of<AuthService>(context, listen: false).tryAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    return const AuthWrapper();
  }
}
