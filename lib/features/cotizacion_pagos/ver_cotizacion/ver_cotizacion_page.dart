import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/emergencia_service.dart';
import 'package:taller_movil/services/api_helper.dart';
import 'package:taller_movil/services/offline_queue_service.dart';
import 'package:taller_movil/shared/app_drawer.dart';

class VerCotizacionPage extends StatefulWidget {
  const VerCotizacionPage({super.key});

  @override
  State<VerCotizacionPage> createState() => _VerCotizacionPageState();
}

class _VerCotizacionPageState extends State<VerCotizacionPage> {
  final _svc = EmergenciaService();
  List<Map<String, dynamic>> _cotizaciones = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final data = await _svc.listarMisCotizaciones();
      if (!mounted) return;
      setState(() { _cotizaciones = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _responder(int cotizacionId, String estado) async {
    final offlineSvc = OfflineQueueService();
    if (!offlineSvc.isOnline) {
      await offlineSvc.encolar(
        '/api/pagos/cotizaciones/$cotizacionId/estado',
        'PATCH',
        {'estado': estado},
        estado == 'aceptada' ? 'Aceptar cotización' : 'Rechazar cotización',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: estado == 'aceptada' ? AppColors.success : AppColors.danger,
          content: Text(
            estado == 'aceptada'
                ? 'Sin conexión — se aceptará al reconectarse.'
                : 'Sin conexión — se rechazará al reconectarse.',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ));
      }
      return;
    }

    try {
      await _svc.responderCotizacion(cotizacionId: cotizacionId, estado: estado);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: estado == 'aceptada' ? AppColors.success : AppColors.danger,
        content: Text(
          estado == 'aceptada' ? 'Cotización aceptada' : 'Cotización rechazada',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ));
      _cargar();
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(e.toString().replaceFirst('Exception: ', '')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Mis Cotizaciones', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      drawer: const AppDrawer(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    if (_error.isNotEmpty) return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
        const SizedBox(height: 12),
        Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ]),
    ));

    if (_cotizaciones.isEmpty) return const Center(child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFFD1D5DB)),
        SizedBox(height: 16),
        Text('No tienes cotizaciones aún', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
        SizedBox(height: 8),
        Text('Cuando un taller envíe una cotización por tu emergencia, aparecerá aquí.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
      ]),
    ));

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _cotizaciones.length,
        itemBuilder: (_, i) => _CotizacionCard(
          cot: _cotizaciones[i],
          onAceptar: () => _responder(_cotizaciones[i]['id'] as int, 'aceptada'),
          onRechazar: () => _responder(_cotizaciones[i]['id'] as int, 'rechazada'),
          onPagar: () => Navigator.pushNamed(context, '/pagos/realizar',
              arguments: _cotizaciones[i]['id'] as int),
        ),
      ),
    );
  }
}

class _CotizacionCard extends StatelessWidget {
  const _CotizacionCard({
    required this.cot,
    required this.onAceptar,
    required this.onRechazar,
    required this.onPagar,
  });

  final Map<String, dynamic> cot;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;
  final VoidCallback onPagar;

  Color get _estadoColor {
    switch (cot['estado']) {
      case 'aceptada': return AppColors.success;
      case 'rechazada': return AppColors.danger;
      case 'pagada': return AppColors.primary;
      default: return const Color(0xFFF59E0B);
    }
  }

  String get _estadoLabel {
    switch (cot['estado']) {
      case 'pendiente': return 'Pendiente';
      case 'aceptada': return 'Aceptada';
      case 'rechazada': return 'Rechazada';
      case 'pagada': return 'Pagada';
      default: return cot['estado'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final monto = (cot['monto_estimado'] as num?)?.toStringAsFixed(2) ?? '?';
    final estado = cot['estado'] as String? ?? '';

    List<dynamic> items = [];
    try {
      final raw = cot['detalle'];
      if (raw is String && raw.isNotEmpty) items = jsonDecode(raw) as List;
      else if (raw is List) items = raw;
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Cotización #${cot['id']}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _estadoColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_estadoLabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _estadoColor)),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Taller info (CU39 + CU43)
              if (cot['taller_nombre'] != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.store_outlined, size: 15, color: Color(0xFF6B7280)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(cot['taller_nombre'] as String,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text))),
                    if (cot['taller_rating'] != null)
                      Text(
                        '${'★' * ((cot['taller_rating'] as num).round())}${'☆' * (5 - (cot['taller_rating'] as num).round())} ${(cot['taller_rating'] as num).toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Tiempo estimado reparación
              if (cot['tiempo_estimado_horas'] != null) ...[
                _InfoRow(
                  icon: Icons.build_outlined,
                  label: 'Tiempo estimado de reparación: ${cot['tiempo_estimado_horas']}h',
                ),
              ],

              // Incidente
              if (cot['incidente_id'] != null)
                _InfoRow(icon: Icons.warning_amber_outlined, label: 'Incidente #${cot['incidente_id']}'),

              // Items del detalle
              if (items.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Detalle:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 6),
                ...items.map((item) {
                  final desc = item['descripcion'] ?? '';
                  final qty  = item['cantidad'] ?? 1;
                  final pu   = (item['precio_unitario'] as num?)?.toDouble() ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      const Icon(Icons.circle, size: 6, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('$desc (x$qty)', style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
                      Text('Bs. ${(qty * pu).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                    ]),
                  );
                }),
                const Divider(height: 16),
              ],

              // Monto total
              Row(children: [
                const Expanded(child: Text('Total:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text))),
                Text('Bs. $monto', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ]),

              // Acciones según estado
              if (estado == 'pendiente') ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: onRechazar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    child: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.w700)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: onAceptar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.w700)),
                  )),
                ]),
              ],

              if (estado == 'aceptada') ...[
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: onPagar,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Pagar ahora', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                )),
              ],

              if (estado == 'pagada')
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Row(children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 18),
                    SizedBox(width: 6),
                    Text('Pago completado', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, size: 15, color: const Color(0xFF6B7280)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
    ]),
  );
}
