import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';

class CenterandFixTheViewIncidents {
  /// Safely builds a payload injection map to prevent type compiling exceptions
  /// inside the MapLibre engine while resolving symbol markers dynamically.
  static Map<String, dynamic> getFixedSymbolLayout() {
    return {
      "icon-image": ["get", "icon"],
      "icon-size": [
        "case",
        ["boolean", ["get", "isSelected"], false],
        1.8,
        1.0
      ],
      "icon-anchor": "bottom", // Pin drop baseline fix
      "icon-allow-overlap": true,
      "icon-ignore-placement": true,
    };
  }

  static Future<void> focusCameraOnIncident({
    required MapLibreMapController controller,
    required double latitude,
    required double longitude,
    double targetZoom = 15.5,
  }) async {
    final incidentTarget = LatLng(latitude, longitude);

    // This dynamically forces MapLibre to calculate the exact geometric center
    // of the remaining visual workspace, keeping markers, circles, and lines clustered together.
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(incidentTarget, targetZoom),
      duration: const Duration(milliseconds: 500),
    );

    // Apply exact visual padding offsets to frame the element cluster safely
    // Parameters: left, top, right, bottom (in physical screen pixels)
    await controller.moveCamera(
      CameraUpdate.padding(
        left: 0.0,
        top: 110.0,    // Clears the custom location search bar depth
        right: 0.0,
        bottom: 410.0, // Clears the entire top curve of the Report Info Card
      ),
    );
  }

// ... keep your getSafeUserPositionFallback method below intact
}

  static Future<Position> getSafeUserPositionFallback() async {
    try {
      bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) return _getDefaultBulacanFallback();

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return _getDefaultBulacanFallback();
      }
      if (permission == LocationPermission.deniedForever) return _getDefaultBulacanFallback();

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
    } catch (_) {
      return _getDefaultBulacanFallback();
    }
  }

  static Position _getDefaultBulacanFallback() {
    return Position(
      latitude: 14.7925,
      longitude: 120.8970,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }
}