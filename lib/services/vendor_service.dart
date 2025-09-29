import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/vendor.dart';

class VendorService {
  VendorService({http.Client? client}) : _client = client ?? http.Client();

  static const String _baseUrl =
      'https://script.google.com/macros/s/AKfycbzDApNHkK-OLiXHZTkxl7RcDh_J3frdUuOuXlX-l2iVZt2HMoFXr4KjZ5bJl2lSsu6HuA/exec';

  final http.Client _client;

  Future<List<Vendor>> fetchVendors() async {
    final response = await _client.get(Uri.parse(_baseUrl));

    if (response.statusCode != 200) {
      throw Exception('Failed to load vendors: ${response.statusCode}');
    }

    final List<dynamic> jsonList = jsonDecode(response.body) as List<dynamic>;
    return jsonList.map((dynamic item) {
      return Vendor.fromJson(item as Map<String, dynamic>);
    }).where((vendor) => vendor.latitude != 0 && vendor.longitude != 0).toList();
  }
}
