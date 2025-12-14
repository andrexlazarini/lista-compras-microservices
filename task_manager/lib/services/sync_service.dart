import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/task.dart';
import 'api_service.dart';
import 'database_service.dart';

/// Serviço responsável por sincronizar a base local com o servidor
/// utilizando a política Last-Write-Wins (LWW).
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _db = DatabaseService.instance;
  final _api = ApiService.instance;

  /// Retorna true se existe alguma conectividade de rede.
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Sincroniza tudo:
  /// 1) Processa a fila sync_queue (operações feitas offline).
  /// 2) Faz um GET geral no servidor e aplica LWW para garantir consistência.
  Future<void> syncAll() async {
    final online = await isOnline();
    if (!online) return;

    // 1) Processa fila
    final queueItems = await _db.getPendingSyncItems();
    for (final item in queueItems) {
      final int queueId = item['id'] as int;
      final String operation = item['operation'] as String;
      final String payload = item['payload'] as String;
      final Map<String, dynamic> payloadMap =
          jsonDecode(payload) as Map<String, dynamic>;
      final Task localTask = Task.fromMap(payloadMap);

      try {
        if (operation == 'delete') {
          if (localTask.id != null) {
            await _api.deleteTask(localTask.id!);
          }
          await _db.delete(localTask.id);
        } else {
          // create ou update: aplica LWW em relação ao servidor
          Task? remote;
          if (localTask.id != null) {
            remote = await _api.fetchTaskById(localTask.id!);
          }

          if (remote == null) {
            // Não existe no servidor -> sobe local
            final Task synced = await _api.upsertTask(localTask);
            await _db.update(synced.copyWith(isSynced: true));
          } else {
            // Já existe no servidor: LWW
            if (remote.updatedAt.isAfter(localTask.updatedAt)) {
              // Servidor ganhou -> sobrescreve local
              await _db.update(remote.copyWith(isSynced: true));
            } else {
              // Local ganhou -> sobe pro servidor
              final Task synced =
                  await _api.upsertTask(localTask.copyWith(isSynced: true));
              await _db.update(synced.copyWith(isSynced: true));
            }
          }
        }

        await _db.markSyncItemProcessed(queueId);
      } catch (_) {
        // Se der erro de rede, simplesmente paramos e na próxima
        // tentativa de sync será processado novamente.
        break;
      }
    }

    // 2) GET geral para pegar qualquer alteração feita diretamente no servidor
    try {
      final remoteTasks = await _api.fetchAllTasks();
      final localTasks = await _db.readAll();
      final localById = {for (final t in localTasks) t.id: t};

      for (final remote in remoteTasks) {
        final local = remote.id != null ? localById[remote.id] : null;
        if (local == null) {
          // Não existe local -> cria
          await _db.create(remote.copyWith(isSynced: true));
        } else {
          if (remote.updatedAt.isAfter(local.updatedAt)) {
            // Versão do servidor é mais nova -> substitui local
            await _db.update(remote.copyWith(isSynced: true));
          } else if (local.updatedAt.isAfter(remote.updatedAt)) {
            // Versão local é mais nova mas não está sincronizada -> sobe local
            if (!local.isSynced) {
              final synced =
                  await _api.upsertTask(local.copyWith(isSynced: true));
              await _db.update(synced.copyWith(isSynced: true));
            }
          }
        }
      }
    } catch (_) {
      // Silencia erros aqui; na demo basta mostrar que em condições normais
      // a sincronização acontece.
    }
  }
}
