import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'screens/map_screen.dart';

void main() {
  // Ensure that Flutter bindings are initialized.
  WidgetsFlutterBinding.ensureInitialized();

  // Mapbox access token.
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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}
