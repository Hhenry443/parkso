import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart' as geo;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const String accessToken =
      "pk.eyJ1IjoiaGhlbnJ5NDQzIiwiYSI6ImNtYWduM2c0dzAydHgyaXNnZGc4cGRsejUifQ.PgHjAohNcSOClqxrxlyBKg";
  MapboxOptions.setAccessToken(accessToken);

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

// CarPark model class
class CarPark {
  final String id;
  final String name;
  final Position location;
  final String? address;
  final double? hourlyRate;
  final int? totalSpaces;
  final int? availableSpaces;
  final List<String> features;
  final String? phoneNumber;
  final String? website;
  final Map<String, String>? openingHours;

  CarPark({
    required this.id,
    required this.name,
    required this.location,
    this.address,
    this.hourlyRate,
    this.totalSpaces,
    this.availableSpaces,
    this.features = const [],
    this.phoneNumber,
    this.website,
    this.openingHours,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': {'lng': location.lng, 'lat': location.lat},
      'address': address,
      'hourlyRate': hourlyRate,
      'totalSpaces': totalSpaces,
      'availableSpaces': availableSpaces,
      'features': features,
      'phoneNumber': phoneNumber,
      'website': website,
      'openingHours': openingHours,
    };
  }

  factory CarPark.fromJson(Map<String, dynamic> json) {
    return CarPark(
      id: json['id'],
      name: json['name'],
      location: Position(json['location']['lng'], json['location']['lat']),
      address: json['address'],
      hourlyRate: json['hourlyRate']?.toDouble(),
      totalSpaces: json['totalSpaces'],
      availableSpaces: json['availableSpaces'],
      features: List<String>.from(json['features'] ?? []),
      phoneNumber: json['phoneNumber'],
      website: json['website'],
      openingHours:
          json['openingHours'] != null
              ? Map<String, String>.from(json['openingHours'])
              : null,
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapboxMap _mapboxMap;
  PointAnnotationManager? _annotationManager;

  final TextEditingController _searchController = TextEditingController();

  // Adding debounce variables to avoid too many API requests
  Timer? _debounce;
  static const _debounceDuration = Duration(milliseconds: 500);

  // Updated car parks data with ID system
  final Map<String, CarPark> carParksData = {
    // Norwich car parks
    'norwich_castle_quarter': CarPark(
      id: 'norwich_castle_quarter',
      name: 'Castle Quarter Car Park',
      location: Position(1.297496, 52.628061),
      address: 'Castle Quarter, Norwich NR1 3DD',
      hourlyRate: 2.50,
      totalSpaces: 250,
      availableSpaces: 45,
      features: ['Covered', 'CCTV', 'Disabled Access', 'Electric Charging'],
      phoneNumber: '01420 123456',
      website: 'https://parkso.uk/castlequater',
      openingHours: {
        'monday': '7:00-22:00',
        'tuesday': '7:00-22:00',
        'wednesday': '7:00-22:00',
        'thursday': '7:00-22:00',
        'friday': '7:00-23:00',
        'saturday': '7:00-23:00',
        'sunday': '9:00-20:00',
      },
    ),
    'norwich_rose_lane': CarPark(
      id: 'norwich_rose_lane',
      name: 'Rose Lane Car Park',
      location: Position(1.302698, 52.627647),
      address: 'Rose Lane, Norwich NR1 1BY',
      hourlyRate: 2.20,
      totalSpaces: 180,
      availableSpaces: 23,
      features: ['Multi-storey', 'CCTV', 'Disabled Access'],
      phoneNumber: '01603 789012',
    ),
    'norwich_st_andrews': CarPark(
      id: 'norwich_st_andrews',
      name: 'St Andrews Car Park',
      location: Position(1.293287, 52.631191),
      address: 'St Andrews Street, Norwich NR2 4TP',
      hourlyRate: 2.80,
      totalSpaces: 320,
      availableSpaces: 67,
      features: [
        '24/7',
        'Security Patrol',
        'Disabled Access',
        'Electric Charging',
      ],
    ),
    'norwich_chantry_place': CarPark(
      id: 'norwich_chantry_place',
      name: 'Chantry Place Car Park',
      location: Position(1.292653, 52.625049),
      address: 'Chantry Place, Norwich NR2 1SZ',
      hourlyRate: 3.00,
      totalSpaces: 400,
      availableSpaces: 89,
      features: ['Shopping Centre', 'Covered', 'CCTV', 'Disabled Access'],
    ),
    'norwich_john_lewis': CarPark(
      id: 'norwich_john_lewis',
      name: 'John Lewis Car Park',
      location: Position(1.292366, 52.624612),
      address: 'John Lewis, Norwich NR2 1SH',
      hourlyRate: 3.20,
      totalSpaces: 150,
      availableSpaces: 12,
      features: ['Shopping Centre', 'Covered', 'CCTV'],
    ),
    'norwich_riverside': CarPark(
      id: 'norwich_riverside',
      name: 'Riverside Car Park',
      location: Position(1.306254, 52.626735),
      address: 'Riverside Road, Norwich NR1 1WX',
      hourlyRate: 1.80,
      totalSpaces: 200,
      availableSpaces: 78,
      features: ['Outdoor', 'CCTV', 'Disabled Access'],
    ),
    'norwich_monastery_court': CarPark(
      id: 'norwich_monastery_court',
      name: 'Monastery Court Car Park',
      location: Position(1.295973, 52.628824),
      address: 'Monastery Court, Norwich NR1 1UU',
      hourlyRate: 2.40,
      totalSpaces: 180,
      availableSpaces: 34,
      features: ['Multi-storey', 'CCTV', 'Disabled Access'],
    ),
    'norwich_westwick_street': CarPark(
      id: 'norwich_westwick_street',
      name: 'Westwick Street Car Park',
      location: Position(1.285235, 52.630462),
      address: 'Westwick Street, Norwich NR2 4SU',
      hourlyRate: 2.10,
      totalSpaces: 120,
      availableSpaces: 56,
      features: ['Outdoor', 'CCTV'],
    ),
    'norwich_st_giles': CarPark(
      id: 'norwich_st_giles',
      name: 'St Giles Multi-Storey Car Park',
      location: Position(1.289601, 52.629182),
      address: 'St Giles Street, Norwich NR2 1LL',
      hourlyRate: 2.70,
      totalSpaces: 300,
      availableSpaces: 91,
      features: ['Multi-storey', 'CCTV', 'Disabled Access', '24/7'],
    ),

    // London car parks
    'london_leicester_square': CarPark(
      id: 'london_leicester_square',
      name: 'Q-Park Leicester Square',
      location: Position(-0.129893, 51.510754),
      address: 'Leicester Square, London WC2H 7NA',
      hourlyRate: 8.50,
      totalSpaces: 350,
      availableSpaces: 12,
      features: [
        'Central Location',
        'CCTV',
        'Electric Charging',
        'Valet Service',
      ],
      phoneNumber: '020 7123 4567',
      website: 'https://q-park.co.uk/leicester-square',
      openingHours: {
        'monday': '24/7',
        'tuesday': '24/7',
        'wednesday': '24/7',
        'thursday': '24/7',
        'friday': '24/7',
        'saturday': '24/7',
        'sunday': '24/7',
      },
    ),
    'london_victoria': CarPark(
      id: 'london_victoria',
      name: 'NCP Car Park London Victoria',
      location: Position(-0.144981, 51.494871),
      address: 'Victoria Street, London SW1E 5ND',
      hourlyRate: 7.20,
      totalSpaces: 280,
      availableSpaces: 34,
      features: ['Transport Links', 'CCTV', 'Disabled Access'],
    ),
    'london_brewer_street': CarPark(
      id: 'london_brewer_street',
      name: 'NCP London Brewer Street',
      location: Position(-0.134760, 51.512500),
      address: 'Brewer Street, London W1F 0LA',
      hourlyRate: 9.00,
      totalSpaces: 150,
      availableSpaces: 8,
      features: ['Central Location', 'CCTV', 'Electric Charging'],
    ),
    'london_marble_arch': CarPark(
      id: 'london_marble_arch',
      name: 'Euro Car Parks – Marble Arch',
      location: Position(-0.160096, 51.514443),
      address: 'Oxford Street, London W1H 5YR',
      hourlyRate: 10.50,
      totalSpaces: 200,
      availableSpaces: 15,
      features: ['Premium Location', 'CCTV', 'Valet Service'],
    ),
    'london_tower_bridge': CarPark(
      id: 'london_tower_bridge',
      name: 'JustPark – Tower Bridge',
      location: Position(-0.075356, 51.505456),
      address: 'Tower Bridge Road, London SE1 2UP',
      hourlyRate: 6.80,
      totalSpaces: 100,
      availableSpaces: 22,
      features: ['Historic Location', 'CCTV', 'Disabled Access'],
    ),
    'london_oxford_street': CarPark(
      id: 'london_oxford_street',
      name: 'ALCOA Car Park – Oxford Street',
      location: Position(-0.147425, 51.515263),
      address: 'Oxford Street, London W1D 1BS',
      hourlyRate: 11.20,
      totalSpaces: 180,
      availableSpaces: 3,
      features: ['Shopping District', 'CCTV', 'Electric Charging'],
    ),
    'london_park_lane': CarPark(
      id: 'london_park_lane',
      name: 'Q-Park Park Lane',
      location: Position(-0.159970, 51.508191),
      address: 'Park Lane, London W1K 1BE',
      hourlyRate: 12.00,
      totalSpaces: 250,
      availableSpaces: 7,
      features: [
        'Premium Location',
        'CCTV',
        'Valet Service',
        'Electric Charging',
      ],
    ),
  };

  // Selected Car Park
  Map<String, dynamic>? _selectedCarPark;

  // Track current view mode (map or list)
  bool _showMapView = true;

  // Store search results for places
  List<Map<String, dynamic>> _searchResults = [];
  // Store filtered car parks separately
  List<Map<String, dynamic>> _nearbyCarParks = [];

  final String _mapboxAccessToken =
      "pk.eyJ1IjoiaGhlbnJ5NDQzIiwiYSI6ImNtYWduM2c0dzAydHgyaXNnZGc4cGRsejUifQ.PgHjAohNcSOClqxrxlyBKg";

  // Session token for Search Box API
  String? _searchSessionToken;

  // Helper methods for the ID system
  List<String> get carParkIds => carParksData.keys.toList();

  // Helper method to get car park by ID
  CarPark? getCarParkById(String id) {
    return carParksData[id];
  }

  Color _getAvailabilityColor(int availableSpaces) {
    if (availableSpaces > 50) return Colors.green;
    if (availableSpaces > 20) return Colors.orange;
    return Colors.red;
  }

  @override
  void initState() async {
    super.initState();
    // Generate a new session token
    _generateSearchSessionToken();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Generate a new session token for the Mapbox Search Box API
  void _generateSearchSessionToken() {
    _searchSessionToken = DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<bool> _requestLocationPermission() async {
    print('=== Starting geolocator permission check ===');

    // Check if location services are enabled first
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    print('Location services enabled: $serviceEnabled');

    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location services are disabled. Please enable them in Settings.',
          ),
        ),
      );
      return false;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    print('Current geolocator permission: $permission');

    if (permission == geo.LocationPermission.denied) {
      print('Permission denied, requesting with geolocator...');
      permission = await geo.Geolocator.requestPermission();
      print('Permission after geolocator request: $permission');

      if (permission == geo.LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission denied. Please enable it in Settings to find nearby car parks.',
            ),
          ),
        );
        return false;
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      print('Permission permanently denied');
      _showPermissionDialog();
      return false;
    }

    bool isGranted =
        permission == geo.LocationPermission.whileInUse ||
        permission == geo.LocationPermission.always;
    print('Geolocator permission granted: $isGranted');
    print('=== End geolocator permission check ===');

    return isGranted;
  }

  // Method to show detailed car park information
  void _showCarParkDetails(CarPark carPark, double distance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  const Icon(Icons.local_parking, color: Colors.blue, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          carPark.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (carPark.address != null)
                          Text(
                            carPark.address!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Quick info cards
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      'Distance',
                      '${(distance / 1000).toStringAsFixed(2)} km',
                      Icons.directions_walk,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      'Rate',
                      carPark.hourlyRate != null
                          ? '£${carPark.hourlyRate!.toStringAsFixed(2)}/hr'
                          : 'N/A',
                      Icons.monetization_on,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      'Available',
                      carPark.availableSpaces != null
                          ? '${carPark.availableSpaces} spaces'
                          : 'N/A',
                      Icons.local_parking,
                      _getAvailabilityColor(carPark.availableSpaces ?? 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Features
              if (carPark.features.isNotEmpty) ...[
                const Text(
                  'Features',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      carPark.features.map((feature) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            feature,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 20),
              ],

              // Opening hours
              if (carPark.openingHours != null) ...[
                const Text(
                  'Opening Hours',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...carPark.openingHours!.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(entry.value),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
              ],

              // Contact info
              if (carPark.phoneNumber != null || carPark.website != null) ...[
                const Text(
                  'Contact',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (carPark.phoneNumber != null)
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16),
                      const SizedBox(width: 8),
                      Text(carPark.phoneNumber!),
                    ],
                  ),
                if (carPark.website != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.language, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          carPark.website!,
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
              ],

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.directions),
                      label: const Text('Get Directions'),
                      onPressed: () {
                        Navigator.pop(context);
                        // Add your navigation logic here
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('View on Map'),
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _showMapView = true;
                        });
                        _goToLocation(carPark.location);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Access Required'),
          content: const Text(
            'This app needs location access to find nearby car parks. Please enable location permission in your device Settings.\n\nGo to: Settings → Privacy & Security → Location Services → Parkso',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                // Use geolocator's method to open settings
                geo.Geolocator.openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  double calculateDistance(Position pos1, Position pos2) {
    const earthRadius = 6371000;
    final lat1 = pos1.lat * pi / 180;
    final lon1 = pos1.lng * pi / 180;
    final lat2 = pos2.lat * pi / 180;
    final lon2 = pos2.lng * pi / 180;

    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Function to search for places using Mapbox Search Box API
  Future<void> searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // Get the current location for better search results
    geo.Position? currentPosition;
    try {
      final permission = await Permission.locationWhenInUse.status;
      if (permission.isGranted) {
        currentPosition = await geo.Geolocator.getCurrentPosition();
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }

    // Build proximity parameter if location is available
    String proximityParam = '';
    if (currentPosition != null) {
      proximityParam =
          '&proximity=${currentPosition.longitude},${currentPosition.latitude}';
    }

    // Search Box API endpoint
    final url =
        'https://api.mapbox.com/search/searchbox/v1/suggest?q=${Uri.encodeComponent(query)}'
        '&access_token=$_mapboxAccessToken'
        '&session_token=$_searchSessionToken'
        '$proximityParam'
        '&language=en'
        '&types=city,neighborhood,street,postcode'
        '&limit=5';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['suggestions'] != null) {
          // Process the suggestions
          final List<Map<String, dynamic>> suggestions = [];

          for (final suggestion in data['suggestions']) {
            // Skip suggestions without mapbox_id
            if (suggestion['mapbox_id'] == null) continue;

            suggestions.add({
              'name': suggestion['name'],
              'description':
                  suggestion['full_address'] ?? suggestion['place_formatted'],
              'mapbox_id': suggestion['mapbox_id'],
            });
          }

          setState(() {
            _searchResults = suggestions;
          });
        }
      }
    } catch (e) {
      debugPrint('Search Box API error: $e');
    }
  }

  // Function to retrieve details for a selected suggestion using the retrieve endpoint
  Future<void> getPlaceDetails(String mapboxId) async {
    final url =
        'https://api.mapbox.com/search/searchbox/v1/retrieve/$mapboxId'
        '?access_token=$_mapboxAccessToken'
        '&session_token=$_searchSessionToken';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final feature = data['features'][0];

        if (feature != null && feature['geometry'] != null) {
          final coordinates = feature['geometry']['coordinates'];
          final location = Position(
            coordinates[0], // longitude
            coordinates[1], // latitude
          );

          final name = feature['properties']['name'] ?? 'Selected Location';
          final fullAddress =
              feature['properties']['full_address'] ??
              feature['properties']['place_formatted'] ??
              name;

          // Find car parks near this location
          _searchController.text = fullAddress;
          findCarParksNearLocation(location);

          // Generate a new session token for the next search session
          _generateSearchSessionToken();
        }
      }
    } catch (e) {
      debugPrint('Retrieve API error: $e');
    }
  }

  // Function to find car parks near a selected location
  void findCarParksNearLocation(Position location) {
    final List<Map<String, dynamic>> carParksWithDistance =
        carParkIds.map((id) {
          final carPark = carParksData[id]!;
          final distance = calculateDistance(location, carPark.location);
          return {
            'id': id, // Include the ID in the result
            'carPark': carPark, // Include the full CarPark object
            'distance': distance,
          };
        }).toList();

    carParksWithDistance.sort((a, b) => a['distance'].compareTo(b['distance']));
    final top5 = carParksWithDistance.take(5).toList();

    setState(() {
      _nearbyCarParks = top5;
      _searchResults = [];
    });

    // Move map to selected location
    _mapboxMap.flyTo(
      CameraOptions(center: Point(coordinates: location), zoom: 15),
      MapAnimationOptions(duration: 2000, startDelay: 0),
    );

    // Add markers for nearby car parks
    _addCarParkMarkers(top5);
  }

  Future<void> _addCarParkMarkers(
    List<Map<String, dynamic>> carParksToShow,
  ) async {
    // Clear existing annotations
    await _annotationManager?.deleteAll();

    // Get marker image
    final ByteData bytes = await rootBundle.load('assets/car-solid.png');
    final Uint8List locationMarker = bytes.buffer.asUint8List();

    // Add markers for each car park
    for (final carParkData in carParksToShow) {
      final carPark = carParkData['carPark'] as CarPark;
      final annotationOptions = PointAnnotationOptions(
        geometry: Point(coordinates: carPark.location),
        image: locationMarker,
        iconSize: 0.10,
      );
      await _annotationManager!.create(annotationOptions);
    }
  }

  Future<void> findNearbyCarParks() async {
    print('=== findNearbyCarParks called ===');

    final hasPermission = await _requestLocationPermission();

    if (!hasPermission) {
      print('No location permission granted');
      return;
    }

    try {
      print('Getting current position...');
      final currentLocation = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      print(
        'Current location: ${currentLocation.latitude}, ${currentLocation.longitude}',
      );

      final userPos = Position(
        currentLocation.longitude,
        currentLocation.latitude,
      );

      findCarParksNearLocation(userPos);
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to get current location: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _goToLocation(Position position) {
    _mapboxMap.flyTo(
      CameraOptions(center: Point(coordinates: position), zoom: 15),
      MapAnimationOptions(duration: 2000, startDelay: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formatDistance(num? meters) {
      if (meters == null) return 'Distance unknown';
      if (meters >= 1000) {
        return '${(meters / 1000).toStringAsFixed(1)} km away';
      } else {
        return '${meters.round()} m away';
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Parkso Car Park Lookup')),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar section
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search Locations',
                            labelStyle: const TextStyle(
                              color: Colors.blueAccent,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 16.0,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Colors.grey,
                                width: 2.0,
                              ),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2.5,
                              ),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          onChanged: (value) {
                            // Add debounce to avoid too many API calls
                            if (_debounce?.isActive ?? false) {
                              _debounce?.cancel();
                            }
                            _debounce = Timer(_debounceDuration, () {
                              searchPlaces(value);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.my_location),
                        tooltip: 'Find Nearby Car Parks',
                        onPressed: findNearbyCarParks,
                      ),
                    ],
                  ),

                  // Search results dropdown
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final place = _searchResults[index];
                          return ListTile(
                            title: Text(place['name']),
                            subtitle: Text(
                              place['description'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            leading: const Icon(Icons.location_on),
                            onTap: () {
                              // When a place is selected, get details and find nearby car parks
                              getPlaceDetails(place['mapbox_id']);
                              FocusScope.of(context).unfocus();
                            },
                          );
                        },
                      ),
                    ),

                  // View toggle buttons
                  if (_nearbyCarParks.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        color: Colors.grey[200],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showMapView = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  color:
                                      _showMapView
                                          ? Colors.white
                                          : Colors.transparent,
                                  boxShadow:
                                      _showMapView
                                          ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                          : null,
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'Map',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showMapView = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  color:
                                      !_showMapView
                                          ? Colors.white
                                          : Colors.transparent,
                                  boxShadow:
                                      !_showMapView
                                          ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                          : null,
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'List',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Main content area - Map or List view
            Expanded(
              child: Stack(
                children: [
                  // Always keep the map in the widget tree
                  MapWidget(
                    key: const ValueKey('MapboxMapWidget'),
                    cameraOptions: CameraOptions(
                      center: Point(coordinates: Position(1.2979, 52.6293)),
                      zoom: 15,
                      pitch: 0,
                    ),
                    onMapCreated: _onMapCreated,
                  ),

                  // Show list view as an overlay when not in map view
                  if (!_showMapView)
                    Container(color: Colors.white, child: _buildListView()),

                  if (_selectedCarPark != null)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedCarPark!['name'] ?? 'Car Park',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedCarPark!['address'] ??
                                    'No address available',
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                formatDistance(_selectedCarPark!['distance']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() => _selectedCarPark = null);
                                    },
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // List view for car parks
  Widget _buildListView() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _searchController.text.isNotEmpty
              ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Car Parks near ${_searchController.text}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              : const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Car Parks near selected location',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
          Expanded(
            child: ListView.builder(
              itemCount: _nearbyCarParks.length,
              itemBuilder: (context, index) {
                final carParkData = _nearbyCarParks[index];
                final carPark = carParkData['carPark'] as CarPark;
                final distance = carParkData['distance'] as double;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with name and availability
                        Row(
                          children: [
                            const Icon(Icons.local_parking, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    carPark.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (carPark.address != null)
                                    Text(
                                      carPark.address!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Availability indicator
                            if (carPark.availableSpaces != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getAvailabilityColor(
                                    carPark.availableSpaces!,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${carPark.availableSpaces} spaces',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Distance and rate info
                        Row(
                          children: [
                            Icon(
                              Icons.directions_walk,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(distance / 1000).toStringAsFixed(2)} km away',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (carPark.hourlyRate != null) ...[
                              Icon(
                                Icons.monetization_on,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '£${carPark.hourlyRate!.toStringAsFixed(2)}/hr',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Features
                        if (carPark.features.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children:
                                carPark.features.take(3).map((feature) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      feature,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.info_outline, size: 16),
                              label: const Text('Details'),
                              onPressed:
                                  () => _showCarParkDetails(carPark, distance),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.directions),
                              label: const Text('View on Map'),
                              onPressed: () {
                                setState(() {
                                  _showMapView = true;
                                });
                                _goToLocation(carPark.location);
                                setState(() {
                                  _selectedCarPark = {
                                    'id': carPark.id,
                                    'name': carPark.name,
                                    'address': carPark.address,
                                    'distance': distance,
                                    'hourlyRate': carPark.hourlyRate,
                                    'availableSpaces': carPark.availableSpaces,
                                    'features': carPark.features,
                                  };
                                });
                                _addCarParkMarkers(_nearbyCarParks);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Use the improved permission method
    final hasPermission = await _requestLocationPermission();
    if (hasPermission) {
      try {
        final currentLocation = await geo.Geolocator.getCurrentPosition();
        final userPos = Position(
          currentLocation.longitude,
          currentLocation.latitude,
        );

        // Go to the user's position on map load
        _goToLocation(userPos);
      } catch (e) {
        print('Error getting initial location: $e');
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        _annotationManager =
            await _mapboxMap.annotations.createPointAnnotationManager();

        _setupLocationTracking();

        // If there are already nearby car parks found, add their markers
        if (_nearbyCarParks.isNotEmpty) {
          _addCarParkMarkers(_nearbyCarParks);
        }

        // add tap functionality
        var tapInteraction = TapInteraction.onMap((context) async {
          final tapLat = context.point.coordinates.lat;
          final tapLng = context.point.coordinates.lng;

          // Check if the tap is on any car park
          const double tapThreshold = 0.0002;

          for (final carParkData in _nearbyCarParks) {
            final carPark = carParkData['carPark'] as CarPark;
            final carParkLat = carPark.location.lat;
            final carParkLng = carPark.location.lng;

            final distanceLat = (carParkLat - tapLat).abs();
            final distanceLng = (carParkLng - tapLng).abs();

            if (distanceLat < tapThreshold && distanceLng < tapThreshold) {
              print("Tapped on car park: ${carPark.name} (ID: ${carPark.id})");

              // Now you have access to all the car park data
              setState(() {
                _selectedCarPark = {
                  'id': carPark.id,
                  'name': carPark.name,
                  'address': carPark.address,
                  'distance': carParkData['distance'],
                  'hourlyRate': carPark.hourlyRate,
                  'totalSpaces': carPark.totalSpaces,
                  'availableSpaces': carPark.availableSpaces,
                  'features': carPark.features,
                  'phoneNumber': carPark.phoneNumber,
                  'website': carPark.website,
                  'openingHours': carPark.openingHours,
                };
              });
              return;
            }
          }

          // If no car park was tapped, continue as normal
          final ByteData bytes = await rootBundle.load(
            'assets/location-dot-solid.png',
          );
          final Uint8List markerImage = bytes.buffer.asUint8List();

          findCarParksNearLocation(Position(tapLng, tapLat));

          final annotationOptions = PointAnnotationOptions(
            geometry: Point(coordinates: Position(tapLng, tapLat)),
            image: markerImage,
            iconSize: 0.20,
          );
          await _annotationManager!.create(annotationOptions);
        });

        mapboxMap.addInteraction(tapInteraction);
      } catch (e, stack) {
        debugPrint('Error setting up map: $e\n$stack');
      }
    });
  }

  // Function to ensure that the user has allowed their location to be tracked.
  Future<void> _setupLocationTracking() async {
    final hasPermission = await _requestLocationPermission();

    if (hasPermission) {
      try {
        await _mapboxMap.location.updateSettings(
          LocationComponentSettings(enabled: true),
        );
      } catch (e) {
        debugPrint("Location setup error: $e");
      }
    }
  }
}
