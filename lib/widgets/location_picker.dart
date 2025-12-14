import 'package:flutter/material.dart';
import '../services/location_service.dart';

class LocationPicker extends StatefulWidget {
  final Function(double lat, double lon, String? address) onLocationSelected;
  const LocationPicker({super.key, required this.onLocationSelected});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  bool _loading = false;

  Future<void> _getCurrent() async {
    setState(() => _loading = true);
    final pos = await LocationService.instance.getCurrentLocation();
    if (pos != null) {
      final addr = await LocationService.instance.getAddressFromCoordinates(pos.latitude, pos.longitude);
      widget.onLocationSelected(pos.latitude, pos.longitude, addr);
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível obter localização'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Selecionar Localização', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _loading ? null : _getCurrent,
          icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.my_location),
          label: Text(_loading ? 'Obtendo...' : 'Usar localização atual'),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}
