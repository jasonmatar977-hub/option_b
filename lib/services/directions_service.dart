import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../widgets/app_map.dart';
import 'google_places_service.dart';

class RouteEstimate {
  const RouteEstimate({
    required this.distanceText,
    required this.durationText,
    required this.distanceKm,
    required this.routePoints,
    this.isFallback = false,
  });

  final String distanceText;
  final String durationText;
  final double distanceKm;
  final List<DemoMapPoint> routePoints;
  final bool isFallback;
}

class DirectionsService {
  const DirectionsService({this.apiKey = kGoogleMapsApiKey});

  final String apiKey;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  Future<RouteEstimate> route({
    required DemoMapPoint pickup,
    required DemoMapPoint destination,
  }) async {
    if (!isConfigured) {
      throw const DirectionsException('Google Directions key missing.');
    }

    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${pickup.latitude},${pickup.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'key': apiKey,
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw const DirectionsException('Directions unavailable.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] != 'OK') {
      throw DirectionsException(
        body['error_message'] as String? ?? 'Directions unavailable.',
      );
    }

    final routes = body['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      throw const DirectionsException('No route found.');
    }

    final route = routes.first as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>? ?? const [];
    if (legs.isEmpty) {
      throw const DirectionsException('No route leg found.');
    }

    final leg = legs.first as Map<String, dynamic>;
    final distance = leg['distance'] as Map<String, dynamic>;
    final duration = leg['duration'] as Map<String, dynamic>;
    final encoded =
        (route['overview_polyline'] as Map<String, dynamic>?)?['points']
            as String?;

    return RouteEstimate(
      distanceText: distance['text'] as String? ?? 'Estimate unavailable',
      durationText: duration['text'] as String? ?? 'Estimate unavailable',
      distanceKm: ((distance['value'] as num? ?? 0).toDouble() / 1000)
          .clamp(0.1, 999)
          .toDouble(),
      routePoints: encoded == null
          ? [pickup, destination]
          : _decodePolyline(encoded),
    );
  }

  RouteEstimate fallback({
    required DemoMapPoint pickup,
    required DemoMapPoint destination,
  }) {
    final km = _haversineKm(pickup, destination).clamp(1.0, 45.0).toDouble();
    final minutes = (km * 3.2 + 5).round();
    return RouteEstimate(
      distanceText: '${km.toStringAsFixed(1)} km',
      durationText: '$minutes mins',
      distanceKm: km,
      routePoints: [pickup, destination],
      isFallback: true,
    );
  }

  static List<DemoMapPoint> _decodePolyline(String encoded) {
    final points = <DemoMapPoint>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(DemoMapPoint(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  static double _haversineKm(DemoMapPoint a, DemoMapPoint b) {
    const earthKm = 6371.0;
    final dLat = _degreesToRadians(b.latitude - a.latitude);
    final dLng = _degreesToRadians(b.longitude - a.longitude);
    final lat1 = _degreesToRadians(a.latitude);
    final lat2 = _degreesToRadians(b.latitude);
    final h = _sin2(dLat / 2) + _sin2(dLng / 2) * _cos(lat1) * _cos(lat2);
    return earthKm * 2 * _atan2(_sqrt(h), _sqrt(1 - h));
  }

  static double _degreesToRadians(double degrees) =>
      degrees * 0.017453292519943295;
}

double _sin2(double value) {
  final s = _sin(value);
  return s * s;
}

double _sin(double value) => _Math.sin(value);
double _cos(double value) => _Math.cos(value);
double _sqrt(double value) => _Math.sqrt(value);
double _atan2(double y, double x) => _Math.atan2(y, x);

class _Math {
  static double sin(double value) => math.sin(value);
  static double cos(double value) => math.cos(value);
  static double sqrt(double value) => math.sqrt(value);
  static double atan2(double y, double x) => math.atan2(y, x);
}

class DirectionsException implements Exception {
  const DirectionsException(this.message);

  final String message;

  @override
  String toString() => message;
}
