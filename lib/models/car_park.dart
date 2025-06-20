import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// The CarPark model class represents the structure of a single car park's data.
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

  // Converts a CarPark instance into a JSON map.
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

  // Creates a CarPark instance from a JSON map.
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
