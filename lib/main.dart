import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'screens/map_screen.dart';

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
    return MaterialApp(
      title: 'Parkso',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: const MapScreen(),
    );
  }
}
