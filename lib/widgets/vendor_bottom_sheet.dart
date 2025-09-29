import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/vendor.dart';

class VendorBottomSheet extends StatelessWidget {
  const VendorBottomSheet({
    super.key,
    required this.vendor,
    required this.userLocation,
  });

  final Vendor vendor;
  final LatLng userLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha((0.08 * 255).round()),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
            ),
            Text(
              vendor.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_city_outlined,
              label: 'Address',
              value: vendor.address.isEmpty
                  ? 'No address available'
                  : vendor.address,
            ),
            if (vendor.distanceText != null || vendor.durationText != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (vendor.distanceText != null)
                      _ChipInfo(
                        icon: Icons.route_rounded,
                        label: 'Distance',
                        value: vendor.distanceText!,
                        color: theme.colorScheme.primary,
                      ),
                    if (vendor.durationText != null)
                      _ChipInfo(
                        icon: Icons.timer_outlined,
                        label: 'ETA',
                        value: vendor.durationText!,
                        color: theme.colorScheme.secondary,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                final Uri url = Uri.parse(
                  'https://www.google.com/maps/dir/?api=1&origin='
                  '${userLocation.latitude},${userLocation.longitude}&destination='
                  '${vendor.latitude},${vendor.longitude}&travelmode=driving',
                );
                Navigator.of(context).pop(url);
              },
              icon: const Icon(Icons.directions_rounded),
              label: const Text('Navigate with Google Maps'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChipInfo extends StatelessWidget {
  const _ChipInfo({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha((0.4 * 255).round())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
