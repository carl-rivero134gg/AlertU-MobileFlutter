import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart'; // 🎯 Added: For passing clean LatLng coordinates
import 'package:alertu_flutter/camera_page.dart';
import 'package:alertu_flutter/choose_another.dart'; // 🎯 Added: Import your refactored ChooseAnotherPage

class IsThisYourLocation extends StatelessWidget {
  final double latitude;
  final double longitude;

  const IsThisYourLocation({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dynamic Theme Color Palette
    final primaryColor = isDark ? theme.colorScheme.primary : const Color(0xFF0D47A1);
    final sheetBg = isDark ? theme.colorScheme.surfaceContainer : const Color(0xFFF8F6F6);
    final textMain = isDark ? theme.colorScheme.onSurface : const Color(0xFF0F172A);
    final textMuted = isDark ? theme.colorScheme.onSurfaceVariant : const Color(0xFF64748B);
    final dragHandleColor = isDark ? theme.colorScheme.outline.withOpacity(0.4) : const Color(0xFFCBD5E1);

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.8),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(dragHandleColor),
            const SizedBox(height: 24),
            Icon(Icons.location_on, size: 64, color: primaryColor),
            const SizedBox(height: 16),
            Text(
              "Is this your location?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Meycauayan, Central Luzon, Philippines",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: textMain.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 32),
            _buildButtons(context, primaryColor, isDark),
            const SizedBox(height: 24),
            Text(
              'Your precise location helps emergency responders locate you quickly.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle(Color handleColor) => Container(
    width: 48,
    height: 6,
    decoration: BoxDecoration(
      color: handleColor,
      borderRadius: BorderRadius.circular(9999),
    ),
  );

  Widget _buildButtons(BuildContext context, Color primaryColor, bool isDark) {
    final outlinedBorderColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    final secondaryTextColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CameraPage(
                    latitude: latitude,
                    longitude: longitude,
                  ),
                ),
              );
            },
            child: const Text("Yes, this is my location", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: outlinedBorderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              // 🎯 1. Close the current location modal view
              Navigator.pop(context);

              // 🎯 2. Route directly to your updated MapLibre manual picker page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChooseAnotherPage(
                    initialLocation: LatLng(latitude, longitude),
                    onLocationConfirmed: (newLocation) {
                      debugPrint("Manual selection locked on MapLibre map: ${newLocation.latitude}, ${newLocation.longitude}");
                    },
                  ),
                ),
              );
            },
            child: Text(
              "No, choose another location",
              style: TextStyle(color: secondaryTextColor),
            ),
          ),
        ),
      ],
    );
  }
}