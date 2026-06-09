import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/emergencia_service.dart';
import 'package:taller_movil/services/pago_stripe_service.dart';
import 'package:taller_movil/services/api_helper.dart';
import 'package:taller_movil/services/offline_queue_service.dart';

/// CU20 – Cliente realiza el pago de una cotización aceptada.
/// Puede navegar con arguments: cotizacion_id (int) para pre-seleccionar.
class RealizarPagoPage extends StatefulWidget {
  const RealizarPagoPage({super.key});

  @override
  State<RealizarPagoPage> createState() => _RealizarPagoPageState();
}

class _RealizarPagoPageState extends State<RealizarPagoPage> {
  final _svc        = EmergenciaService();
  final _stripeSvc  = PagoStripeService();

  List<Map<String, dynamic>> _cotizaciones = [];
  bool _loading = true;
  bool _pagando = false;
  String _error = '';
  Map<String, dynamic>? _pagoRealizado;

  int? _cotizacionIdArg;
  int? _cotizacionSeleccionada;
  String _metodo = 'efectivo';

  static const _metodos = ['efectivo', 'tarjeta'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) _cotizacionIdArg = args;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final data = await _svc.listarMisCotizaciones();
      if (!mounted) return;
      // Solo cotizaciones aceptadas cuyo servicio ya fue finalizado
      final pendientes = data.where((c) =>
          c['estado'] == 'aceptada' &&
          c['estado_asignacion'] == 'finalizado').toList();
      setState(() {
        _cotizaciones = pendientes;
        _loading = false;
        if (_cotizacionIdArg != null) {
          final match = pendientes.where((c) => c['id'] == _cotizacionIdArg).isNotEmpty;
          if (match) _cotizacionSeleccionada = _cotizacionIdArg;
        }
      });
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _pagar() async {
    if (_cotizacionSeleccionada == null) return;

    final offlineSvc = OfflineQueueService();
    if (!offlineSvc.isOnline) {
      if (_metodo == 'tarjeta') {
        setState(() { _error = 'El pago con tarjeta requiere conexión a internet.'; });
        return;
      }
      // Efectivo se puede encolar
      await offlineSvc.encolar(
        '/api/pagos/pagos', 'POST',
        {'cotizacion_id': _cotizacionSeleccionada!, 'metodo': 'efectivo'},
        'Pago en efectivo',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF92400E),
        duration: Duration(seconds: 5),
        content: Text('Sin conexión — el pago en efectivo se registrará al reconectarse.'),
      ));
      return;
    }

    if (_metodo == 'tarjeta') {
      await _pagarConTarjeta();
    } else {
      await _pagarEfectivo();
    }
  }

  Future<void> _pagarEfectivo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar pago en efectivo'),
        content: Text('¿Confirmar pago en efectivo de la cotización #$_cotizacionSeleccionada?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() { _pagando = true; _error = ''; });
    try {
      final result = await _svc.realizarPago(
        cotizacionId: _cotizacionSeleccionada!,
        metodo: 'efectivo',
      );
      if (!mounted) return;
      setState(() { _pagoRealizado = result; _pagando = false; });
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) { Navigator.pushReplacementNamed(context, '/login'); return; }
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _pagando = false; });
    }
  }

  Future<void> _pagarConTarjeta() async {
    setState(() { _pagando = true; _error = ''; });
    try {
      final intent          = await _stripeSvc.crearIntent(_cotizacionSeleccionada!);
      final clientSecret    = intent['client_secret'] as String;
      final paymentIntentId = intent['payment_intent_id'] as String;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'RutaSegura',
          style: ThemeMode.light,
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      final result = await _stripeSvc.confirmarPago(_cotizacionSeleccionada!, paymentIntentId);
      if (!mounted) return;
      setState(() { _pagoRealizado = result; _pagando = false; });

    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() { _pagando = false; _error = e.error.localizedMessage ?? 'Pago cancelado o fallido'; });
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) { Navigator.pushReplacementNamed(context, '/login'); return; }
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _pagando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Realizar Pago', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _pagoRealizado != null ? _buildSuccess() : _buildContent(),
      ),
    );
  }

  Widget _buildSuccess() {
    final pago = _pagoRealizado!;
    final monto = (pago['monto'] as num?)?.toStringAsFixed(2) ?? '?';
    final pagoId = pago['id']?.toString() ?? '?';
    return Column(children: [
      const SizedBox(height: 40),
      const Icon(Icons.check_circle_outline, size: 72, color: AppColors.success),
      const SizedBox(height: 16),
      Text('¡Pago realizado!',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('Recibo #$pagoId  ·  Bs. $monto',
          style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text('Método: $_metodo',
          style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)), textAlign: TextAlign.center),
      const SizedBox(height: 40),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/solicitudes/estado'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('Ver mis solicitudes'),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
          child: const Text('Ir al inicio'),
        ),
      ),
    ]);
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.primary)));

    if (_error.isNotEmpty) return Column(children: [
      _ErrorBox(_error),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
    ]);

    if (_cotizaciones.isEmpty) return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(children: [
          SizedBox(height: 40),
          Icon(Icons.receipt_long_outlined, size: 56, color: Color(0xFFD1D5DB)),
          SizedBox(height: 16),
          Text('No hay pagos pendientes.',
              style: TextStyle(color: Color(0xFF374151), fontSize: 15, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          SizedBox(height: 8),
          Text(
            'El pago se habilita una vez que el técnico marca el servicio como finalizado.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );

    final cot = _cotizacionSeleccionada != null
        ? _cotizaciones.firstWhere((c) => c['id'] == _cotizacionSeleccionada, orElse: () => _cotizaciones.first)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de cotización
        const Text('Cotización a pagar:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 10),
        ..._cotizaciones.map((c) {
          final selected = _cotizacionSeleccionada == c['id'];
          final monto = (c['monto_estimado'] as num?)?.toStringAsFixed(2) ?? '?';
          return GestureDetector(
            onTap: () => setState(() => _cotizacionSeleccionada = c['id'] as int),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withValues(alpha: 0.07) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE5E7EB), width: selected ? 2 : 1),
              ),
              child: Row(children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? AppColors.primary : const Color(0xFF9CA3AF), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Cotización #${c['id']}',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                          color: selected ? AppColors.primary : AppColors.text)),
                  Text('Bs. $monto  ·  ${c['estado'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ])),
              ]),
            ),
          );
        }),

        // Detalle de items
        if (cot != null) ...[
          const SizedBox(height: 8),
          _ItemsCard(cot),
        ],

        const SizedBox(height: 20),
        const Text('Método de pago:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 10),
        Row(children: _metodos.map((m) {
          final sel = _metodo == m;
          return Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _metodo = m),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? AppColors.primary : const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  m[0].toUpperCase() + m.substring(1),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : AppColors.text),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ));
        }).toList()),

        if (_error.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ErrorBox(_error),
        ],

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_pagando || _cotizacionSeleccionada == null) ? null : _pagar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: _pagando
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    _cotizacionSeleccionada != null
                        ? 'Pagar Bs. ${(_cotizaciones.firstWhere((c) => c['id'] == _cotizacionSeleccionada, orElse: () => {})['monto_estimado'] as num?)?.toStringAsFixed(2) ?? '?'}'
                        : 'Selecciona una cotización',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard(this.cot);
  final Map<String, dynamic> cot;

  @override
  Widget build(BuildContext context) {
    List<dynamic> items = [];
    try {
      final raw = cot['detalle'];
      if (raw is String && raw.isNotEmpty) items = jsonDecode(raw) as List;
      else if (raw is List) items = raw;
    } catch (_) {}

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Detalle:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 8),
          ...items.map((item) {
            final desc = item['descripcion'] ?? '';
            final qty  = item['cantidad'] ?? 1;
            final pu   = (item['precio_unitario'] as num?)?.toDouble() ?? 0.0;
            final total = qty * pu;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text('$desc (x$qty)', style: const TextStyle(fontSize: 12, color: Color(0xFF374151)))),
                Text('Bs. ${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
              ]),
            );
          }),
          const Divider(height: 16),
          Row(children: [
            const Expanded(child: Text('Total:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text))),
            Text(
              'Bs. ${(cot['monto_estimado'] as num?)?.toStringAsFixed(2) ?? '?'}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.msg);
  final String msg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Text(msg, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
  );
}
