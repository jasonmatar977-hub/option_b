import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../widgets/app_map.dart';

const String kGoogleMapsApiKey = String.fromEnvironment(
  'OPTION_B_GOOGLE_MAPS_API_KEY',
);

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.description,
    this.localPoint,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;
  final String description;
  final DemoMapPoint? localPoint;

  bool get isLocal => localPoint != null;
}

class PlaceDetails {
  const PlaceDetails({
    required this.name,
    required this.address,
    required this.point,
  });

  final String name;
  final String address;
  final DemoMapPoint point;
}

class GooglePlacesService {
  const GooglePlacesService({this.apiKey = kGoogleMapsApiKey});

  final String apiKey;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  List<PlaceSuggestion> localSuggestions(String input) {
    final query = input.trim().toLowerCase();
    if (query.length < 2) {
      return const [];
    }
    return _localLebanonPlaces
        .where((place) => place.mainText.toLowerCase().startsWith(query))
        .take(6)
        .toList();
  }

  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    final trimmed = input.trim();
    if (!isConfigured || trimmed.length < 2) {
      return const [];
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {'input': trimmed, 'key': apiKey},
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw const PlacesException('Autocomplete unavailable.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String? ?? 'UNKNOWN';
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      throw PlacesException(
        body['error_message'] as String? ?? 'Autocomplete unavailable.',
      );
    }

    final predictions = body['predictions'] as List<dynamic>? ?? const [];
    return predictions
        .map((raw) {
          final item = raw as Map<String, dynamic>;
          final formatting =
              item['structured_formatting'] as Map<String, dynamic>? ??
              const {};
          return PlaceSuggestion(
            placeId: item['place_id'] as String? ?? '',
            mainText:
                formatting['main_text'] as String? ??
                item['description'] as String? ??
                'Place',
            secondaryText: formatting['secondary_text'] as String? ?? '',
            description: item['description'] as String? ?? '',
          );
        })
        .where((item) => item.placeId.isNotEmpty)
        .toList();
  }

  Future<PlaceDetails> details(String placeId) async {
    if (!isConfigured) {
      throw const PlacesException('Google Places key missing.');
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'name,formatted_address,geometry',
        'key': apiKey,
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw const PlacesException('Place details unavailable.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] != 'OK') {
      throw PlacesException(
        body['error_message'] as String? ?? 'Place details unavailable.',
      );
    }

    final result = body['result'] as Map<String, dynamic>;
    final geometry = result['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;
    return PlaceDetails(
      name: result['name'] as String? ?? 'Selected destination',
      address: result['formatted_address'] as String? ?? '',
      point: DemoMapPoint(
        (location['lat'] as num).toDouble(),
        (location['lng'] as num).toDouble(),
      ),
    );
  }
}

const List<PlaceSuggestion> _localLebanonPlaces = [
  PlaceSuggestion(
    placeId: 'local-zalka',
    mainText: 'Zalka',
    secondaryText: 'Metn, Lebanon',
    description: 'Zalka, Lebanon',
    localPoint: DemoMapPoint(33.9049, 35.5784),
  ),
  PlaceSuggestion(
    placeId: 'local-zouk-mikael',
    mainText: 'Zouk Mikael',
    secondaryText: 'Keserwan, Lebanon',
    description: 'Zouk Mikael, Lebanon',
    localPoint: DemoMapPoint(33.9704, 35.6167),
  ),
  PlaceSuggestion(
    placeId: 'local-zouk-mosbeh',
    mainText: 'Zouk Mosbeh',
    secondaryText: 'Keserwan, Lebanon',
    description: 'Zouk Mosbeh, Lebanon',
    localPoint: DemoMapPoint(33.9447, 35.6218),
  ),
  PlaceSuggestion(
    placeId: 'local-zahle',
    mainText: 'Zahle',
    secondaryText: 'Beqaa, Lebanon',
    description: 'Zahle, Lebanon',
    localPoint: DemoMapPoint(33.8463, 35.9020),
  ),
  PlaceSuggestion(
    placeId: 'local-beirut',
    mainText: 'Beirut',
    secondaryText: 'Lebanon',
    description: 'Beirut, Lebanon',
    localPoint: DemoMapPoint(33.8938, 35.5018),
  ),
  PlaceSuggestion(
    placeId: 'local-jounieh',
    mainText: 'Jounieh',
    secondaryText: 'Keserwan, Lebanon',
    description: 'Jounieh, Lebanon',
    localPoint: DemoMapPoint(33.9808, 35.6178),
  ),
  PlaceSuggestion(
    placeId: 'local-antelias',
    mainText: 'Antelias',
    secondaryText: 'Metn, Lebanon',
    description: 'Antelias, Lebanon',
    localPoint: DemoMapPoint(33.9184, 35.5887),
  ),
  PlaceSuggestion(
    placeId: 'local-dbayeh',
    mainText: 'Dbayeh',
    secondaryText: 'Metn, Lebanon',
    description: 'Dbayeh, Lebanon',
    localPoint: DemoMapPoint(33.9302, 35.5903),
  ),
  PlaceSuggestion(
    placeId: 'local-jal-el-dib',
    mainText: 'Jal El Dib',
    secondaryText: 'Metn, Lebanon',
    description: 'Jal El Dib, Lebanon',
    localPoint: DemoMapPoint(33.9090, 35.5802),
  ),
  PlaceSuggestion(
    placeId: 'local-dora',
    mainText: 'Dora',
    secondaryText: 'Metn, Lebanon',
    description: 'Dora, Lebanon',
    localPoint: DemoMapPoint(33.8933, 35.5424),
  ),
  PlaceSuggestion(
    placeId: 'local-hamra',
    mainText: 'Hamra',
    secondaryText: 'Beirut, Lebanon',
    description: 'Hamra, Lebanon',
    localPoint: DemoMapPoint(33.8968, 35.4825),
  ),
  PlaceSuggestion(
    placeId: 'local-achrafieh',
    mainText: 'Achrafieh',
    secondaryText: 'Beirut, Lebanon',
    description: 'Achrafieh, Lebanon',
    localPoint: DemoMapPoint(33.8875, 35.5207),
  ),
  PlaceSuggestion(
    placeId: 'local-hazmieh',
    mainText: 'Hazmieh',
    secondaryText: 'Baabda, Lebanon',
    description: 'Hazmieh, Lebanon',
    localPoint: DemoMapPoint(33.8547, 35.5406),
  ),
  PlaceSuggestion(
    placeId: 'local-baabda',
    mainText: 'Baabda',
    secondaryText: 'Lebanon',
    description: 'Baabda, Lebanon',
    localPoint: DemoMapPoint(33.8339, 35.5442),
  ),
  PlaceSuggestion(
    placeId: 'local-byblos',
    mainText: 'Byblos',
    secondaryText: 'Jbeil, Lebanon',
    description: 'Byblos, Lebanon',
    localPoint: DemoMapPoint(34.1230, 35.6519),
  ),
  PlaceSuggestion(
    placeId: 'local-tripoli',
    mainText: 'Tripoli',
    secondaryText: 'North Lebanon',
    description: 'Tripoli, Lebanon',
    localPoint: DemoMapPoint(34.4367, 35.8497),
  ),
  PlaceSuggestion(
    placeId: 'local-faraya',
    mainText: 'Faraya',
    secondaryText: 'Keserwan, Lebanon',
    description: 'Faraya, Lebanon',
    localPoint: DemoMapPoint(34.0164, 35.8265),
  ),
  PlaceSuggestion(
    placeId: 'local-hrajel',
    mainText: 'Hrajel',
    secondaryText: 'Keserwan, Lebanon',
    description: 'Hrajel, Lebanon',
    localPoint: DemoMapPoint(34.0172, 35.7928),
  ),
  PlaceSuggestion(
    placeId: 'local-kaslik',
    mainText: 'Kaslik',
    secondaryText: 'Keserwan, Lebanon',
    description: 'Kaslik, Lebanon',
    localPoint: DemoMapPoint(33.9839, 35.6179),
  ),
  PlaceSuggestion(
    placeId: 'local-sarba',
    mainText: 'Sarba',
    secondaryText: 'Keserwan, Lebanon',
    description: 'Sarba, Lebanon',
    localPoint: DemoMapPoint(33.9930, 35.6321),
  ),
];

class PlacesException implements Exception {
  const PlacesException(this.message);

  final String message;

  @override
  String toString() => message;
}
