import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class MediaService {
  MediaService._();
  static final MediaService instance = MediaService._();

  // Emulador Android usa 10.0.2.2 para acessar o host
  static const String _baseUrl = 'http://10.0.2.2:3001';

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  /// Envia uma imagem (arquivo) para o backend, que salvará no S3 (LocalStack).
  /// Retorna: { "key": "...", "url": "..." }
  Future<Map<String, String>> uploadPhoto(File file) async {
    final req = http.MultipartRequest('POST', _uri('/upload'));

    // Envia o arquivo como multipart
    final fileName = p.basename(file.path);
    req.files.add(await http.MultipartFile.fromPath('file', file.path, filename: fileName));

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Upload falhou: ${resp.statusCode} ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return {
      'key': (data['key'] ?? '').toString(),
      'url': (data['url'] ?? '').toString(),
    };
  }
}
