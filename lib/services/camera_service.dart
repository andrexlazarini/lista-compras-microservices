import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../screens/camera_screen.dart';

class CameraService {
  static final CameraService instance = CameraService._init();
  CameraService._init();

  List<CameraDescription>? _cameras;

  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
    } catch (_) {
      _cameras = [];
    }
  }

  bool get hasCameras => _cameras != null && _cameras!.isNotEmpty;

  Future<bool> _ensurePermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final req = await Permission.camera.request();
    return req.isGranted;
  }

  Future<String?> takePicture(BuildContext context) async {
    if (!await _ensurePermission()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de câmera negada'), backgroundColor: Colors.red),
        );
      }
      return null;
    }

    if (!hasCameras) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma câmera disponível'), backgroundColor: Colors.red),
        );
      }
      return null;
    }

    final camera = _cameras!.first;
    final controller = CameraController(camera, ResolutionPreset.high, enableAudio: false);
    try {
      await controller.initialize();
      if (!context.mounted) return null;
      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(controller: controller),
          fullscreenDialog: true,
        ),
      );
      return imagePath;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir câmera: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    } finally {
      controller.dispose();
    }
  }

  Future<String> savePicture(XFile image) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final fileName = 'task_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File(p.join(dir.path, fileName));
    return (await File(image.path).copy(dest.path)).path;
  }

  Future<bool> deletePhoto(String photoPath) async {
    try {
      final f = File(photoPath);
      if (await f.exists()) {
        await f.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
