import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/vendor.dart';
import 'services/distance_service.dart';
import 'services/location_service.dart';
import 'services/vendor_service.dart';
import 'widgets/vendor_bottom_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DistanceApp());
}

Color _colorWithOpacity(Color color, double opacity) {
  final double clamped = opacity.clamp(0.0, 1.0).toDouble();
  final int alpha = (clamped * 255).round();
  return color.withAlpha(alpha);
}

class DistanceApp extends StatelessWidget {
  const DistanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vendor Distance Explorer',
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,
        useMaterial3: true,
        textTheme: Typography.englishLike2021.apply(
          bodyColor: const Color(0xFF1F2933),
          displayColor: const Color(0xFF101828),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final VendorService _vendorService = VendorService();
  final DistanceService _distanceService = DistanceService();
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  final LatLng _fallbackLocation = const LatLng(17.3850, 78.4867); // Hyderabad

  LatLng? _userLocation;
  List<Vendor> _vendors = <Vendor>[];
  Vendor? _selectedVendor;
  bool _isLoading = true;
  bool _isDistanceLoading = false;
  String? _errorMessage;

  StreamSubscription<MapEvent>? _mapSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
    _mapSubscription = _mapController.mapEventStream.listen((event) {
      if (event is MapEventMoveEnd && _selectedVendor == null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _mapSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final position = await _locationService.determinePosition();
      final userLocation = position ?? _fallbackLocation;
      final vendors = await _vendorService.fetchVendors();

      setState(() {
        _userLocation = userLocation;
        _vendors = vendors;
      });

      await _updateVendorDistances(userLocation);
      _moveCamera(userLocation, zoom: 6.5);
    } on Exception catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateVendorDistances(LatLng origin) async {
    if (!mounted) return;
    setState(() {
      _isDistanceLoading = true;
    });

    final List<Vendor> enriched = <Vendor>[];
    for (final vendor in _vendors) {
      final info = await _distanceService.fetchDistance(
        origin: origin,
        destination: LatLng(vendor.latitude, vendor.longitude),
      );
      enriched.add(
        vendor.copyWith(
          distanceText: info?.distanceText,
          durationText: info?.durationText,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _vendors = enriched;
      _isDistanceLoading = false;
    });
  }

  void _moveCamera(LatLng position, {double zoom = 9}) {
    _mapController.move(position, zoom);
  }

  void _handleLongPress(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _userLocation = latLng;
      _selectedVendor = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Anchor moved to ${latLng.latitude.toStringAsFixed(4)}, '
          '${latLng.longitude.toStringAsFixed(4)}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    unawaited(_updateVendorDistances(latLng));
  }

  Future<void> _showVendorDetails(Vendor vendor) async {
    if (_userLocation == null) return;
    setState(() => _selectedVendor = vendor);

    final Uri? url = await showModalBottomSheet<Uri>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return VendorBottomSheet(
          vendor: vendor,
          userLocation: _userLocation!,
        );
      },
    );

    if (url != null) {
      final success = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Google Maps.'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _selectedVendor = null);
    }
  }

  Widget _buildMap() {
    final theme = Theme.of(context);
    final userMarker = _userLocation;

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: userMarker ?? _fallbackLocation,
          initialZoom: 6.5,
          onLongPress: _handleLongPress,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.distance_app',
            retinaMode: MediaQuery.of(context).devicePixelRatio > 2,
          ),
          if (userMarker != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: userMarker,
                  width: 80,
                  height: 80,
                  child: _MapPin(
                    color: theme.colorScheme.primary,
                    icon: Icons.person_pin_circle_rounded,
                    label: 'You',
                  ),
                ),
              ],
            ),
          MarkerLayer(
            markers: _vendors.map((vendor) {
              final vendorPoint = LatLng(vendor.latitude, vendor.longitude);
              final isSelected = vendor.id == _selectedVendor?.id;
              return Marker(
                point: vendorPoint,
                width: 160,
                height: 120,
                child: _VendorMarker(
                  vendor: vendor,
                  isSelected: isSelected,
                  onTap: () => _showVendorDetails(vendor),
                  isDistanceLoading: _isDistanceLoading,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final userLocation = _userLocation;
    final theme = Theme.of(context);
    final formatter = NumberFormat('##0.0000');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: _colorWithOpacity(theme.colorScheme.shadow, 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.explore_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vendor Distance Explorer',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hold the map to reposition your start point and get live distance & ETA insights.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (userLocation != null)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _colorWithOpacity(theme.colorScheme.primary, 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.my_location_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current anchor',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lat ${formatter.format(userLocation.latitude)}, '
                            'Lng ${formatter.format(userLocation.longitude)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (_isDistanceLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _initialize,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        if (isWide) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      AspectRatio(
                        aspectRatio: 1.3,
                        child: _buildMap(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 4,
                  child: _buildVendorList(isWide: true),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, innerConstraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  AspectRatio(
                    aspectRatio: 0.9,
                    child: _buildMap(),
                  ),
                  const SizedBox(height: 24),
                  _buildVendorList(isWide: false),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVendorList({required bool isWide}) {
    final theme = Theme.of(context);
    if (_vendors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _colorWithOpacity(theme.colorScheme.shadow, 0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'No vendors available',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try refreshing or adjusting your location pin.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _initialize,
              child: const Text('Reload data'),
            ),
          ],
        ),
      );
    }

    final listView = ListView.separated(
      shrinkWrap: true,
      physics: isWide ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
      itemCount: _vendors.length,
      itemBuilder: (context, index) {
        final vendor = _vendors[index];
        final isSelected = vendor.id == _selectedVendor?.id;
        return _VendorCard(
          vendor: vendor,
          isSelected: isSelected,
          onTap: () {
            _moveCamera(LatLng(vendor.latitude, vendor.longitude), zoom: 10.5);
            _showVendorDetails(vendor);
          },
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 14),
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _colorWithOpacity(theme.colorScheme.shadow, 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Nearby vendors',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  if (_userLocation != null) {
                    _moveCamera(_userLocation!, zoom: 7.5);
                  }
                },
                icon: const Icon(Icons.center_focus_strong_rounded),
                tooltip: 'Recenter on my pin',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isWide)
            Expanded(child: listView)
          else
            listView,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildBody(),
        ),
        floatingActionButton: _userLocation == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _moveCamera(_userLocation!, zoom: 9.5),
                icon: const Icon(Icons.my_location),
                label: const Text('My pin'),
              ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.color,
    required this.icon,
    required this.label,
    this.isSelected = false,
  });

  final Color color;
  final IconData icon;
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _colorWithOpacity(color, 0.25),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 6),
              SizedBox(
                width: 90,
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        CustomPaint(
          size: const Size(14, 10),
          painter: _TrianglePainter(color),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _colorWithOpacity(color, 0.8);
    final ui.Path path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) => oldDelegate.color != color;
}

class _VendorMarker extends StatelessWidget {
  const _VendorMarker({
    required this.vendor,
    required this.isSelected,
    required this.onTap,
    required this.isDistanceLoading,
  });

  final Vendor vendor;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDistanceLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortDistance = vendor.distanceText?.split(' ').take(2).join(' ');
    final shortDuration = vendor.durationText?.split(' ').take(2).join(' ');

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 250),
        scale: isSelected ? 1.05 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (vendor.distanceText != null && vendor.durationText != null)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: isDistanceLoading ? 0.4 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _colorWithOpacity(Colors.black, 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shortDistance ?? vendor.distanceText!,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shortDuration ?? vendor.durationText!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            _MapPin(
              color: theme.colorScheme.error,
              icon: Icons.storefront_rounded,
              label: vendor.name,
              isSelected: isSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.vendor,
    required this.onTap,
    this.isSelected = false,
  });

  final Vendor vendor;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : _colorWithOpacity(theme.colorScheme.outlineVariant, 0.2),
            width: 1.4,
          ),
          color: isSelected
              ? _colorWithOpacity(theme.colorScheme.primary, 0.08)
              : theme.colorScheme.surface,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _colorWithOpacity(theme.colorScheme.primary, 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.store_mall_directory_rounded,
                      color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        vendor.address.isEmpty
                            ? 'No address provided'
                            : vendor.address,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Badge(
                  icon: Icons.route_outlined,
                  label: vendor.distanceText ?? 'Distance unavailable',
                ),
                _Badge(
                  icon: Icons.watch_later_outlined,
                  label: vendor.durationText ?? 'ETA unavailable',
                ),
                if (vendor.city.isNotEmpty)
                  _Badge(
                    icon: Icons.location_city,
                    label: vendor.city,
                  ),
                if (vendor.state.isNotEmpty)
                  _Badge(
                    icon: Icons.public,
                    label: vendor.state,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _colorWithOpacity(theme.colorScheme.secondaryContainer, 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.secondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
