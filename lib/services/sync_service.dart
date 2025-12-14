import 'dart:convert';
import 'dart:io';

import '../models/task.dart';
import 'api_service.dart';
import 'media_service.dart';
import 'database_service.dart';

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  final _api = ApiService.instance;
  final _db = DatabaseService.instance;
  final _media = MediaService.instance;

  /// Processa todos os itens pendentes na tabela sync_queue,
  /// aplicando a política Last-Write-Wins.
  Future<void> syncAll() async {
    final items = await _db.getPendingSyncItems();
    for (final row in items) {
      final queueId = row['id'] as int;
      final operation = row['operation'] as String;
      final payload =
      jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      final localTask = Task.fromMap(payload);

      try {
        switch (operation) {
          case 'create':
            await _handleCreate(localTask);
            break;
          case 'update':
            await _handleUpdate(localTask);
            break;
          case 'delete':
            await _handleDelete(localTask);
            break;
        }
        await _db.markSyncItemProcessed(queueId);
      } catch (_) {
        // Se der erro, não marca como processed → tenta novamente depois.
      }
    }
  }

  Future<void> _handleCreate(Task localTask) async {
  Task toSend = localTask;

  // Se tem foto local e ainda não tem URL, tenta subir primeiro.
  if (toSend.photoPath != null && (toSend.photoUrl == null || toSend.photoUrl!.isEmpty)) {
    try {
      final file = File(toSend.photoPath!);
      if (await file.exists()) {
        final res = await _media.uploadPhoto(file);
        toSend = toSend.copyWith(photoUrl: res['url']);
        // salva localmente a URL antes de enviar para a API
        await _db.update(toSend);
      }
    } catch (_) {
      // Se o upload falhar, mantém na fila para tentar depois.
      rethrow;
    }
  }

  final remote = await _api.createTask(toSend);

  // IMPORTANTÍSSIMO: json-server retorna um id diferente do SQLite.
  // Mantemos o id local para atualizar o registro correto no banco local.
  final syncedLocal = remote.copyWith(
    id: localTask.id,
    photoPath: localTask.photoPath, // mantém caminho local
    isSynced: true,
  );

  await _db.update(syncedLocal);
}


  Future<void> _handleUpdate(Task localTask) async {
    if (localTask.id == null) return;

    Task toSend = localTask;

    // Se tem foto local e ainda não tem URL, tenta subir antes do UPDATE.
    if (toSend.photoPath != null && (toSend.photoUrl == null || toSend.photoUrl!.isEmpty)) {
      final file = File(toSend.photoPath!);
      if (await file.exists()) {
        final res = await _media.uploadPhoto(file);
        toSend = toSend.copyWith(photoUrl: res['url']);
        await _db.update(toSend);
      }
    }

    print('SYNC UPDATE → localTask: ${localTask.toMap()}');

    final remote = await _api.fetchTaskById(localTask.id!);
    print('SYNC UPDATE → remote: ${remote?.toMap()}');

    if (remote == null) {
      print('SYNC UPDATE → REMOTE NULL, criando no servidor');
      final created = await _api.createTask(toSend);
      final synced = created.copyWith(id: localTask.id, photoPath: localTask.photoPath, isSynced: true);
      print('SYNC UPDATE → salvando created+synced: ${synced.toMap()}');
      await _db.update(synced);
      return;
    }

    print('SYNC UPDATE → comparando datas: remote=${remote.updatedAt} local=${localTask.updatedAt}');

    if (remote.updatedAt.isAfter(localTask.updatedAt)) {
      print('SYNC UPDATE → SERVIDOR VENCE');
      final win = remote.copyWith(photoPath: localTask.photoPath, isSynced: true);
      print('SYNC UPDATE → salvando win(remote+synced): ${win.toMap()}');
      await _db.update(win);
    } else {
      print('SYNC UPDATE → APP VENCE');
      final updatedRemote = await _api.updateTask(toSend);
      final win = updatedRemote.copyWith(isSynced: true);
      print('SYNC UPDATE → salvando win(app+synced): ${win.toMap()}');
      await _db.update(win);
    }
  }

  Future<void> _handleDelete(Task localTask) async {
    if (localTask.id == null) return;
    await _api.deleteTask(localTask.id!);
    // Local já foi deletada no momento da ação.
  }
}
