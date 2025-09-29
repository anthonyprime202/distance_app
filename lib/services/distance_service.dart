import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class DistanceInfo {
  const DistanceInfo({
    required this.distanceText,
    required this.durationText,
  });

  final String distanceText;
  final String durationText;
}

class DistanceService {
  DistanceService({http.Client? client}) : _client = client ?? http.Client();

  static const String _baseUrl =
      'https://script.google.com/macros/s/AKfycbzDApNHkK-OLiXHZTkxl7RcDh_J3frdUuOuXlX-l2iVZt2HMoFXr4KjZ5bJl2lSsu6HuA/exec';

  final http.Client _client;

  Future<DistanceInfo?> fetchDistance({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: <String, String>{
      'lon1': origin.longitude.toStringAsFixed(6),
      'lat1': origin.latitude.toStringAsFixed(6),
      'lon2': destination.longitude.toStringAsFixed(6),
      'lat2': destination.latitude.toStringAsFixed(6),
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      return null;
    }

    final Map<String, dynamic> json = jsonDecode(response.body) as Map<String, dynamic>;
    if ((json['status'] as String?)?.toLowerCase() != 'sucess') {
      return null;
    }

    final distance = (json['distance'] as String?)?.trim();
    final duration = (json['duration'] as String?)?.trim();
    if (distance == null || duration == null) {
      return null;
    }

    return DistanceInfo(distanceText: distance, durationText: duration);
  }
}
