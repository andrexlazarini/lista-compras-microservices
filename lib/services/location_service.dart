import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static final LocationService instance = LocationService._init();
  LocationService._init();

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return false;
    }
    if (perm == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<Position?> getCurrentLocation() async {
    if (!await _ensurePermission()) return null;
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<String?> getAddressFromCoordinates(double lat, double lon) async {
    try {
      final places = await placemarkFromCoordinates(lat, lon);
      if (places.isNotEmpty) {
        final p = places.first;
        final parts = [p.street, p.subLocality, p.locality, p.administrativeArea]
            .where((x) => x != null && x.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) return parts.take(3).join(', ');
      }
    } catch (_) {}
    return null;
  }

  String formatCoordinates(double lat, double lon) =>
      '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
}
