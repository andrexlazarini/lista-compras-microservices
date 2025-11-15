import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';

class SensorService {
  static final SensorService instance = SensorService._init();
  SensorService._init();

  StreamSubscription<AccelerometerEvent>? _sub;
  Function()? _onShake;
  static const double _shakeThreshold = 15.0;
  static const Duration _cooldown = Duration(milliseconds: 500);
  DateTime? _last;

  bool _active = false;
  bool get isActive => _active;

  void startShakeDetection(Function() onShake) {
    if (_active) return;
    _onShake = onShake;
    _active = true;
    _sub = accelerometerEvents.listen(_detect);
  }

  void _detect(AccelerometerEvent e) async {
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < _cooldown) return;

    final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (mag > _shakeThreshold) {
      _last = now;
      try {
        if (await Vibration.hasVibrator() == true) {
          await Vibration.vibrate(duration: 100);
        }
      } catch (_) {}
      _onShake?.call();
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _onShake = null;
    _active = false;
  }
}
