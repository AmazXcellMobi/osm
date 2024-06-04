// ignore_for_file: prefer_const_constructors, deprecated_member_use, unused_element, avoid_unnecessary_containers, use_build_context_synchronously, prefer_const_literals_to_create_immutables, prefer_final_fields, library_private_types_in_public_api

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  TextEditingController _searchController = TextEditingController();
  List<LatLng> routePoints = [];
  MapController mapController = MapController();
  LatLng userLocation = LatLng(0, 0);
  double userDirection = 0.0;
  double distanceToDestination = 0.0;
  double estimatedTimeToDestination = 0.0;
  double userSpeed = 0.0;
  double userSpeedAccuracy = 0.0;
  String searchQuery = '';
  final int _speedSampleSize = 10;
  List<double> _recentSpeeds = [];

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        userLocation = LatLng(position.latitude, position.longitude);
        userDirection = position.heading;
        _addSpeed(position.speed * 2.23694);
        userSpeedAccuracy = position.speedAccuracy * 2.23694;

        if (routePoints.isNotEmpty) {
          LatLng destination = routePoints.last;
          distanceToDestination = _calculateDistance(userLocation, destination);
          estimatedTimeToDestination =
              _calculateEstimatedTime(distanceToDestination);
        }
      });
    });
  }

  void _addSpeed(double speed) {
    if (_recentSpeeds.length == _speedSampleSize) {
      _recentSpeeds.removeAt(0);
    }
    _recentSpeeds.add(speed);
    userSpeed = _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;
  }

  Future<void> _searchLocation() async {
    String query = _searchController.text;
    List<Location> locations = await locationFromAddress(query);
    if (locations.isNotEmpty) {
      Location firstResult = locations.first;
      mapController.move(
        LatLng(firstResult.latitude, firstResult.longitude),
        13.0,
      );
    }
  }

  Future<void> fetchRoute(LatLng destination) async {
    final url = 'http://router.project-osrm.org/route/v1/driving/'
        '${userLocation.longitude},${userLocation.latitude};'
        '${destination.longitude},${destination.latitude}?geometries=geojson';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final coordinates = data['routes'][0]['geometry']['coordinates'];
      List<LatLng> newRoutePoints = coordinates.map<LatLng>((coord) {
        return LatLng(coord[1], coord[0]);
      }).toList();

      bool? startRide = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Start Ride'),
            content: Text(
                'Do you want to start the ride to the selected destination?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text('Start Ride'),
              ),
            ],
          );
        },
      );

      if (startRide == true) {
        setState(() {
          routePoints = newRoutePoints;
        });
      }
    } else {
      throw Exception('Failed to load route');
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371.0;
    double lat1 = point1.latitude * (pi / 180);
    double lon1 = point1.longitude * (pi / 180);
    double lat2 = point2.latitude * (pi / 180);
    double lon2 = point2.longitude * (pi / 180);
    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _calculateEstimatedTime(double distanceInKm) {
    double averageSpeedKmph = 30.0;
    return distanceInKm / averageSpeedKmph;
  }

  List<Color> _generateGradientColors(int length) {
    List<Color> colors = [];
    for (int i = 0; i < length; i++) {
      double ratio = i / (length - 1);
      colors.add(Color.lerp(Colors.blue, Colors.green, ratio)!);
    }
    return colors;
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hoursPart = duration.inHours > 0
        ? "${duration.inHours} hour${duration.inHours > 1 ? 's' : ''} "
        : "";
    String minutesPart = "${duration.inMinutes.remainder(60)} min";

    if (duration.inHours == 0) {
      return minutesPart;
    } else {
      return "$hoursPart$minutesPart";
    }
  }

  void _onTapMap(LatLng tappedLatLng) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(
        tappedLatLng.latitude, tappedLatLng.longitude);
    if (placemarks.isNotEmpty) {
      Placemark placemark = placemarks.first;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Location Info'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Name: ${placemark.name ?? 'N/A'}'),
                Text('Street: ${placemark.street ?? 'N/A'}'),
                Text('Locality: ${placemark.locality ?? 'N/A'}'),
                Text('Sublocality: ${placemark.subLocality ?? 'N/A'}'),
                Text('Postal Code: ${placemark.postalCode ?? 'N/A'}'),
                Text(
                    'Administrative Area: ${placemark.administrativeArea ?? 'N/A'}'),
                Text(
                    'Sub-administrative Area: ${placemark.subAdministrativeArea ?? 'N/A'}'),
                Text('Country: ${placemark.country ?? 'N/A'}'),
                Text('ISO Country Code: ${placemark.isoCountryCode ?? 'N/A'}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String estimatedTime = '';
    if (distanceToDestination != 0.0) {
      int estimatedHours = estimatedTimeToDestination.floor();
      int remainingMinutes =
          ((estimatedTimeToDestination - estimatedHours) * 60).round();
      Duration remainingTime =
          Duration(hours: estimatedHours, minutes: remainingMinutes);
      estimatedTime = formatDuration(remainingTime);
    }
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search Location',
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              vertical: 10.0,
              horizontal: 15.0,
            ),
            suffixIcon: IconButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                _searchLocation();
              },
              icon: Icon(Icons.location_searching_rounded),
              color: Colors.grey[600],
            ),
          ),
        ),
      ),
      body: FlutterMap(
        options: MapOptions(
          center: LatLng(31.5497, 74.3436),
          zoom: 13.0,
          onTap: (tapPosition, point) {
            fetchRoute(point);
          },
        ),
        mapController: mapController,
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c'],
          ),
          if (routePoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 8.0,
                  gradientColors: _generateGradientColors(routePoints.length),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              Marker(
                width: 200.0,
                height: 200.0,
                point: userLocation,
                child: GestureDetector(
                  onTap: () {
                    _onTapMap(userLocation);
                  },
                  child: Container(
                    child: Icon(
                      Icons.location_on,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              mapController.move(userLocation, 13.0);
            },
            child: Icon(Icons.my_location),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              mapController.rotate(-90.0);
            },
            child: Icon(Icons.rotate_left),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              mapController.rotate(90.0);
            },
            child: Icon(Icons.rotate_right),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              mapController.move(mapController.center, mapController.zoom + 1);
            },
            child: Icon(Icons.zoom_in),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              mapController.move(mapController.center, mapController.zoom - 1);
            },
            child: Icon(Icons.zoom_out),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              LatLng destination = LatLng(31.5209207, 74.3073764);
              fetchRoute(destination);
            },
            child: Icon(Icons.home),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        height: 120,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Current Direction: ${userDirection.toStringAsFixed(2)}'),
                Text(
                    'Distance: ${distanceToDestination.toStringAsFixed(2)} km'),
                Text('Estimated Time: $estimatedTime'),
                Text(
                    'Speed: ${userSpeed.toStringAsFixed(2)} mph (±${userSpeedAccuracy.toStringAsFixed(2)} mph)'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
