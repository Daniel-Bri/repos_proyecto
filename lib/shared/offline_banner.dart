import 'package:flutter/material.dart';
import 'package:taller_movil/services/offline_queue_service.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OfflineQueueService(),
      builder: (context, _) {
        final svc = OfflineQueueService();
        final online = svc.isOnline;
        final pendientes = svc.pendientes;
        final sincronizando = svc.isSincronizando;

        // Sin nada que mostrar
        if (online && pendientes == 0) return const SizedBox.shrink();

        // Sin conexión
        if (!online) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFFEF3C7),
            child: Row(
              children: [
                const Icon(Icons.cloud_off, size: 16, color: Color(0xFF92400E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pendientes > 0
                        ? 'Sin conexión — $pendientes acción${pendientes > 1 ? 'es' : ''} pendiente${pendientes > 1 ? 's' : ''}'
                        : 'Sin conexión a internet',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          );
        }

        // Online con pendientes — sincronizando o esperando
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFFEFF6FF),
          child: Row(
            children: [
              sincronizando
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF1D4ED8)),
                    )
                  : const Icon(Icons.sync, size: 16, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sincronizando
                      ? 'Sincronizando $pendientes acción${pendientes > 1 ? 'es' : ''}…'
                      : '$pendientes acción${pendientes > 1 ? 'es' : ''} pendiente${pendientes > 1 ? 's' : ''} — esperando red…',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
