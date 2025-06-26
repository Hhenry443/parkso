import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/car_park.dart';
import '../data/car_park_data.dart';
import 'payment_screen.dart';
import '../services/auth_service.dart';

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

  // Variables for the form
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _regPlateController = TextEditingController();
  bool _isAlreadyParked = false;
  DateTime? _arrivalDateTime;
  DateTime? _departureDateTime;

  @override
  void initState() {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location services are disabled. Please enable them in Settings.',
            ),
          ),
        );
      }
      return false;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    print('Current geolocator permission: $permission');

    if (permission == geo.LocationPermission.denied) {
      print('Permission denied, requesting with geolocator...');
      permission = await geo.Geolocator.requestPermission();
      print('Permission after geolocator request: $permission');

      if (permission == geo.LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission denied. Please enable it in Settings to find nearby car parks.',
              ),
            ),
          );
        }
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

  // Corrected POST implementation
  Future<Map<String, dynamic>?> sendBookingRequest(
    String registration,
    DateTime? arrival,
    DateTime? departure,
    String carParkUrl, // The ID for the car park, e.g., "springway"
  ) async {
    // 1. Validate that we have the required date/time information
    if (arrival == null || departure == null) {
      print('Error: Arrival or Departure date is missing.');
      return null;
    }

    // 2. Define the API endpoint for the POST request
    final url = Uri.https('parkso.uk', '/api/quote/springway');

    // 3. Create the MultipartRequest for a POST request
    var request = http.MultipartRequest('POST', url);

    // 4. Format dates and times into the required string formats
    final DateFormat dateFormatter = DateFormat('yyyy-M-d');
    final DateFormat timeFormatter = DateFormat('HH:mm:ss');

    // 5. Add all the required data to the 'fields' map for the formdata body % Get the shared prefs
    final prefs = await SharedPreferences.getInstance();
    final stripeId = prefs.getString('userStripeId');

    if (stripeId == null) {
      print(
        'Error: Stripe ID not found. User might not be logged in correctly.',
      );
      return null;
    }

    request.fields.addAll({
      'registration': registration,
      'startDate': dateFormatter.format(arrival),
      'startTime': timeFormatter.format(arrival),
      'endDate': dateFormatter.format(departure),
      'endTime': timeFormatter.format(departure),
      'url': 'springway', // Always set to springway for now
      'stripe_id': stripeId,
    });

    print('Sending POST request to $url with fields: ${request.fields}');

    // 6. Send the request and handle the streamed response
    try {
      var streamedResponse = await request.send();

      // Read the response from the stream
      var responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        print('API Response: $responseBody');
        if (responseBody.isNotEmpty) {
          return jsonDecode(responseBody);
        } else {
          print('Warning: API returned 200 OK but with an empty body.');
          return null;
        }
      } else {
        print('API Error: Status Code ${streamedResponse.statusCode}');
        print('Error Body: $responseBody');
        return null;
      }
    } catch (e) {
      print('An exception occurred while sending the POST request: $e');
      return null;
    }
  }

  // Method to show detailed car park information
  void _showCarParkDetails(CarPark carPark, {double? finalDistance}) async {
    // Show a loading dialog if it takes too long for some reason.
    // TO;DO Make the distance check quicker, i think this is where its hanging up
    showDialog(
      context: context,
      barrierDismissible:
          false, // User cannot dismiss the dialog by tapping outside
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.blue, strokeWidth: 5),
        );
      },
    );

    try {
      final currentLocation = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      final userPosition = Position(
        currentLocation.longitude,
        currentLocation.latitude,
      );

      finalDistance ??= calculateDistance(userPosition, carPark.location);

      // Dismiss the loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show the modal bottom sheet with the car park details
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
                    const Icon(
                      Icons.local_parking,
                      color: Colors.blue,
                      size: 28,
                    ),
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
                    if (finalDistance != null) ...[
                      Expanded(
                        child: _buildInfoCard(
                          'Distance',
                          '${(finalDistance / 1000).toStringAsFixed(2)} km',
                          Icons.directions_walk,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
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
                        Icons.event_available,
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
                            entry.key[0].toUpperCase() + entry.key.substring(1),
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
                          // TODO Add navigation logic here
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.event_available),
                        label: const Text('Book'),
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _showMapView = true;
                          });
                          _showBookingForm(carPark);
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
    } catch (e) {
      // In case of an error, make sure to dismiss the loading dialog
      if (mounted) {
        Navigator.pop(context);
      }
      // Optionally, show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching car park details: $e')),
      );
    }
  }

  //

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to get current location: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
    // Get the user from the AuthService
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    return Scaffold(
      appBar: AppBar(
        // Dynamically set the title based on login state
        title: Text(
          user != null ? 'Welcome, ${user.name}' : 'Parkso Car Park Lookup',
        ),
        // Add the actions list for the logout button
        actions: [
          if (authService.isLoggedIn) // Only show button if logged in
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () {
                // Call the logout method from the AuthService
                Provider.of<AuthService>(context, listen: false).logout();
              },
            ),
        ],
      ),
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
                            color: Colors.black.withOpacity(0.2),
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
                                              color: Colors.black.withOpacity(
                                                0.1,
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
                                              color: Colors.black.withOpacity(
                                                0.1,
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
                  // Always keep the map in the widget tree to keep markers (avoid refresh bug)
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
                              onPressed: () => _showCarParkDetails(carPark),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.event_available, size: 16),
                              label: const Text('Book'),
                              // New logic for the "View on Map" button's onPressed
                              onPressed: () {
                                // Show the details of the car park
                                _showBookingForm(carPark);
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

  void _showBookingForm(CarPark carPark) {
    // Reset state when the form is opened
    _regPlateController.clear();
    _isAlreadyParked = false;
    _arrivalDateTime = null;
    _departureDateTime = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Use StatefulBuilder to manage the state within the modal
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Helper function to pick date and time
            Future<DateTime?> _pickDateTime(DateTime initialDate) async {
              final date = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date == null) return null;

              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(initialDate),
              );
              if (time == null) return null;

              return DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Book a Space at ${carPark.name}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              carPark.address ?? 'No address provided',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const Divider(height: 40),

                            // --- NEW BOOKING FORM ---

                            // 1. Registration Plate Input
                            TextFormField(
                              controller: _regPlateController,
                              decoration: const InputDecoration(
                                labelText: 'Car Registration Plate',
                                hintText: 'e.g., AB12 CDE',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your registration plate.';
                                }
                                // Basic UK registration plate format check
                                final regExp = RegExp(
                                  r'^[A-Z]{2}[0-9]{2}\s?[A-Z]{3}$',
                                  caseSensitive: false,
                                );
                                if (!regExp.hasMatch(value)) {
                                  return 'Please enter a valid UK registration plate.';
                                }
                                return null;
                              },
                              inputFormatters: [UpperCaseTextFormatter()],
                            ),
                            const SizedBox(height: 20),

                            // 2. "Already Parked?" Toggle
                            SwitchListTile(
                              title: const Text('Are you already parked?'),
                              value: _isAlreadyParked,
                              onChanged: (bool value) {
                                setModalState(() {
                                  _isAlreadyParked = value;
                                  // Reset dates when toggling
                                  _arrivalDateTime = null;
                                  _departureDateTime = null;
                                });
                              },
                            ),
                            const SizedBox(height: 10),

                            // 3. Conditional Date/Time Pickers
                            if (_isAlreadyParked) ...[
                              // Departure Time
                              ListTile(
                                leading: const Icon(Icons.departure_board),
                                title: const Text('When are you leaving?'),
                                subtitle: Text(
                                  _departureDateTime == null
                                      ? 'Select a date and time'
                                      : '${_departureDateTime!.toLocal()}'
                                          .split('.')[0],
                                ),
                                onTap: () async {
                                  final picked = await _pickDateTime(
                                    DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      _departureDateTime = picked;
                                    });
                                  }
                                },
                              ),
                            ] else ...[
                              // Arrival Time
                              ListTile(
                                leading: const Icon(Icons.directions_car),
                                title: const Text('When will you arrive?'),
                                subtitle: Text(
                                  _arrivalDateTime == null
                                      ? 'Select a date and time'
                                      : '${_arrivalDateTime!.toLocal()}'.split(
                                        '.',
                                      )[0],
                                ),
                                onTap: () async {
                                  final picked = await _pickDateTime(
                                    DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      _arrivalDateTime = picked;
                                    });
                                  }
                                },
                              ),
                              // Departure Time (for future parking)
                              ListTile(
                                leading: const Icon(Icons.departure_board),
                                title: const Text('When will you leave?'),
                                subtitle: Text(
                                  _departureDateTime == null
                                      ? 'Select a date and time'
                                      : '${_departureDateTime!.toLocal()}'
                                          .split('.')[0],
                                ),
                                onTap: () async {
                                  final initialDate =
                                      _arrivalDateTime ?? DateTime.now();
                                  final picked = await _pickDateTime(
                                    initialDate.add(const Duration(hours: 1)),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      _departureDateTime = picked;
                                    });
                                  }
                                },
                              ),
                            ],

                            // --- END OF FORM ---
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                // Inside the ElevatedButton's onPressed in _showBookingForm
                                onPressed: () async {
                                  if (_formKey.currentState!.validate()) {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder:
                                          (BuildContext context) =>
                                              const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                    );

                                    final apiResponse = await sendBookingRequest(
                                      _regPlateController.text
                                          .toUpperCase(), // 1st argument: registration
                                      _arrivalDateTime, // 2nd argument: arrival
                                      _departureDateTime, // 3rd argument: departure
                                      carPark
                                          .id, // 4th argument: carParkUrl (using the id)
                                    );

                                    // Dismiss the loading indicator
                                    Navigator.pop(context);

                                    // FINAL, CORRECTED LOGIC
                                    if (apiResponse != null &&
                                        apiResponse['data'] is Map &&
                                        apiResponse['data']['clientSecret'] !=
                                            null &&
                                        apiResponse['data']['price'] != null) {
                                      final data = apiResponse['data'];
                                      final String clientSecret =
                                          data['clientSecret'];
                                      final double totalPrice =
                                          (data['price'] as num).toDouble();

                                      // Dismiss the booking form itself
                                      Navigator.of(context).pop();

                                      // Push the native PaymentScreen
                                      if (mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => PaymentScreen(
                                                  stripeClientSecret:
                                                      clientSecret,
                                                  totalPrice: totalPrice,
                                                ),
                                          ),
                                        );
                                      }
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Could not create booking. Please try again.',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Proceed to Payment',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
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

              // Call the new method to show the booking form from the bottom.
              _showCarParkDetails(carPark);

              return; // Stop checking other car parks.
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

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
