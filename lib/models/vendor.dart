class Vendor {
  final int id;
  final String name;
  final String city;
  final String state;
  final String address;
  final double latitude;
  final double longitude;
  final String? distanceText;
  final String? durationText;

  const Vendor({
    required this.id,
    required this.name,
    required this.city,
    required this.state,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.distanceText,
    this.durationText,
  });

  Vendor copyWith({
    String? distanceText,
    String? durationText,
  }) {
    return Vendor(
      id: id,
      name: name,
      city: city,
      state: state,
      address: address,
      latitude: latitude,
      longitude: longitude,
      distanceText: distanceText ?? this.distanceText,
      durationText: durationText ?? this.durationText,
    );
  }

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['S. No.'] is int
          ? json['S. No.'] as int
          : int.tryParse(json['S. No.'].toString()) ?? 0,
      name: (json['Vendor Name'] as String?)?.trim() ?? 'Unknown Vendor',
      city: (json['City'] as String?)?.trim() ?? '',
      state: (json['State'] as String?)?.trim() ?? '',
      address: (json['Address'] as String?)?.trim() ?? '',
      latitude: _toDouble(json['Latitude']),
      longitude: _toDouble(json['Longitude']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
