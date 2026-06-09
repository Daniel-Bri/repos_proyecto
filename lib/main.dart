import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/auth_service.dart';
// ignore: unused_import
import 'package:taller_movil/services/notificacion_service.dart';
import 'package:taller_movil/shared/acceso_denegado_page.dart';

// Acceso y Registro
import 'package:taller_movil/features/acceso_registro/iniciar_sesion/iniciar_sesion_page.dart';
import 'package:taller_movil/features/acceso_registro/registrarse/registrarse_page.dart';
import 'package:taller_movil/features/acceso_registro/cambiar_contrasena/cambiar_contrasena_page.dart';
import 'package:taller_movil/features/acceso_registro/recuperar_contrasena/recuperar_contrasena_page.dart';
import 'package:taller_movil/features/acceso_registro/registrar_vehiculo/registrar_vehiculo_page.dart';
import 'package:taller_movil/features/acceso_registro/gestionar_vehiculos/gestionar_vehiculos_page.dart';
import 'package:taller_movil/features/acceso_registro/registrar_taller/registrar_taller_page.dart';
import 'package:taller_movil/features/acceso_registro/aprobar_talleres/aprobar_talleres_page.dart';
import 'package:taller_movil/features/acceso_registro/gestionar_usuarios/gestionar_usuarios_page.dart';

// Dashboard
import 'package:taller_movil/features/dashboard/dashboard_page.dart';

// Emergencias
import 'package:taller_movil/features/emergencias/reportar_emergencia/reportar_emergencia_page.dart';
import 'package:taller_movil/features/emergencias/enviar_audio/enviar_audio_page.dart';
import 'package:taller_movil/features/emergencias/agregar_descripcion/agregar_descripcion_page.dart';

// Solicitudes
import 'package:taller_movil/features/solicitudes/ver_estado_solicitud/ver_estado_solicitud_page.dart';
import 'package:taller_movil/features/solicitudes/cancelar_solicitud/cancelar_solicitud_page.dart';
import 'package:taller_movil/features/solicitudes/ver_solicitudes_disponibles/ver_solicitudes_disponibles_page.dart';
import 'package:taller_movil/features/solicitudes/ver_detalle_incidente/ver_detalle_incidente_page.dart';
import 'package:taller_movil/features/solicitudes/aceptar_solicitud/aceptar_solicitud_page.dart';
import 'package:taller_movil/features/solicitudes/rechazar_solicitud/rechazar_solicitud_page.dart';
import 'package:taller_movil/features/solicitudes/verificar_llegada/verificar_llegada_page.dart';

// Talleres y Técnicos
import 'package:taller_movil/features/talleres_tecnicos/gestionar_tecnicos/gestionar_tecnicos_page.dart';
import 'package:taller_movil/features/talleres_tecnicos/cobro_visita/cobro_visita_page.dart';
import 'package:taller_movil/features/talleres_tecnicos/gestionar_disponibilidad/gestionar_disponibilidad_page.dart';
import 'package:taller_movil/features/talleres_tecnicos/actualizar_estado_servicio/actualizar_estado_servicio_page.dart';
import 'package:taller_movil/features/talleres_tecnicos/registrar_servicio_realizado/registrar_servicio_realizado_page.dart';

// Cotización y Pagos
import 'package:taller_movil/features/cotizacion_pagos/generar_cotizacion/generar_cotizacion_page.dart';
import 'package:taller_movil/features/cotizacion_pagos/ver_cotizacion/ver_cotizacion_page.dart';
import 'package:taller_movil/features/cotizacion_pagos/confirmar_cotizacion/confirmar_cotizacion_page.dart';
import 'package:taller_movil/features/cotizacion_pagos/realizar_pago/realizar_pago_page.dart';
import 'package:taller_movil/features/cotizacion_pagos/ver_comisiones/ver_comisiones_page.dart';

// Comunicación
import 'package:taller_movil/features/comunicacion/chat/chat_page.dart';
import 'package:taller_movil/features/comunicacion/notificaciones/notificaciones_page.dart';
import 'package:taller_movil/features/comunicacion/ver_tecnico_mapa/ver_tecnico_mapa_page.dart';
import 'package:taller_movil/features/comunicacion/compartir_ubicacion/compartir_ubicacion_page.dart';

// Reportes
import 'package:taller_movil/features/reportes/historial_servicios/historial_servicios_page.dart';
import 'package:taller_movil/features/reportes/calificar_servicio/calificar_servicio_page.dart';
import 'package:taller_movil/features/reportes/recordatorios_mantenimiento/recordatorios_mantenimiento_page.dart';
import 'package:taller_movil/features/reportes/metricas_taller/metricas_taller_page.dart';
import 'package:taller_movil/features/reportes/metricas_globales/metricas_globales_page.dart';
import 'package:taller_movil/features/reportes/auditoria/auditoria_page.dart';
import 'package:taller_movil/features/reportes/ranking_talleres/ranking_talleres_page.dart';
import 'package:taller_movil/features/reportes/mis_reportes/mis_reportes_page.dart';

import 'dart:async';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:taller_movil/services/websocket_service.dart';
import 'package:taller_movil/services/offline_queue_service.dart';
import 'package:taller_movil/services/emergencia_service.dart' show EmergenciaService;
import 'package:taller_movil/services/api_helper.dart' show TokenExpiradoException;
import 'package:taller_movil/services/pago_stripe_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Stripe.publishableKey = 'pk_test_51TelETCmJ0cJf47FTLW32lZ4b3G6K9iZLfaiOIuca7iFjNkiAucJFXQELwsQSsxqgh8ro70MnvTQHUebDU9yFgas005thJT0Jn';
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  runApp(const RutaSegura());
}

class RutaSegura extends StatefulWidget {
  const RutaSegura({super.key});

  @override
  State<RutaSegura> createState() => _RutaSeguraState();
}

class _RutaSeguraState extends State<RutaSegura> {
  StreamSubscription? _notifSub;
  StreamSubscription? _msgSub;
  StreamSubscription? _pagoSub;
  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    _notifSub = WebSocketService().on('notificacion').listen((payload) {
      _showSnack(
        payload['titulo'] as String? ?? 'Notificación',
        payload['mensaje'] as String? ?? '',
      );
    });
    _msgSub = WebSocketService().on('nuevo_mensaje').listen((payload) {
      final remitente = payload['remitente'] as String? ?? 'Nuevo mensaje';
      final contenido = payload['contenido'] as String? ?? '';
      _showSnack('Mensaje de $remitente', contenido);
    });
    _pagoSub = WebSocketService().on('solicitud_pago').listen((payload) {
      _showPagoBottomSheet(payload);
    });
    _syncSub = OfflineQueueService().sincronizadoStream.listen((result) {
      final detalle = result.labels.length == 1
          ? result.labels.first
          : '${result.sincronizados} acciones sincronizadas';
      _showSnack('✅ Conexión restaurada', detalle);
    });
  }

  void _showSnack(String titulo, String mensaje) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      backgroundColor: const Color(0xFF1E3A8A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 4),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
          if (mensaje.isNotEmpty)
            Text(mensaje, style: const TextStyle(fontSize: 12, color: Color(0xFFBFDBFE)), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    ));
  }

  void _showPagoBottomSheet(Map<String, dynamic> payload) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final cotizacionId = payload['cotizacion_id'] as int?;
    final monto = (payload['monto'] as num?)?.toDouble() ?? 0.0;
    if (cotizacionId == null) return;

    // Solo mostrar al cliente — evita que aparezca en cuentas de técnico/taller
    final user = await AuthService().getUser();
    if (user == null || user['role'] != 'cliente') return;

    showModalBottomSheet(
      context: ctx,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PagoBottomSheet(
        cotizacionId: cotizacionId,
        monto: monto,
      ),
    );
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _msgSub?.cancel();
    _pagoSub?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RutaSegura',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      locale: const Locale('es'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const _SplashRouter(),
      routes: {
        // ── Auth ──────────────────────────────────────────
        '/login':                    (_) => const IniciarSesionPage(),
        '/registro':                 (_) => const RegistrarsePage(),
        '/recuperar-contrasena':     (_) => const RecuperarContrasenaPage(),
        '/dashboard':                (_) => const DashboardPage(),
        '/acceso/cambiar-contrasena': (_) => const CambiarContrasenaPage(),

        // ── Pantalla de acceso denegado ───────────────────
        '/acceso-denegado': (_) => const AccesoDenegadoPage(),

        // ── Acceso y Registro ─────────────────────────────
        '/acceso/registrar-vehiculo': (_) => const RegistrarVehiculoPage(),
        '/acceso/mis-vehiculos':      (_) => const GestionarVehiculosPage(),
        '/acceso/registrar-taller':   (_) => const RegistrarTallerPage(),
        '/aprobar-talleres':          (_) => const AprobarTalleresPage(),
        '/gestionar-usuarios':        (_) => const GestionarUsuariosPage(),

        // ── Emergencias ───────────────────────────────────
        '/emergencias/reportar':     (_) => const ReportarEmergenciaPage(),
        '/emergencias/audio':        (ctx) => EnviarAudioPage(
                                     incidenteId: (ModalRoute.of(ctx)?.settings.arguments as int?) ?? 0),
        '/emergencias/descripcion':  (_) => const AgregarDescripcionPage(),
        // ubicacion y fotos se navegan desde ReportarEmergencia (requieren incidenteId)

        // ── Solicitudes ───────────────────────────────────
        '/solicitudes/estado':       (_) => const VerEstadoSolicitudPage(),
        '/solicitudes/cancelar':     (_) => const CancelarSolicitudPage(),
        '/solicitudes/disponibles':  (_) => const VerSolicitudesDisponiblesPage(),
        '/solicitudes/detalle':      (_) => const VerDetalleIncidentePage(),
        '/solicitudes/aceptar':          (_) => const AceptarSolicitudPage(),
        '/solicitudes/rechazar':         (_) => const RechazarSolicitudPage(),
        '/solicitudes/verificar-llegada': (_) => const VerificarLlegadaPage(),

        // ── Talleres y Técnicos ───────────────────────────
        '/talleres/gestionar-tecnicos':  (_) => const GestionarTecnicosPage(),
        '/talleres/cobro-visita':        (_) => const CobroVisitaPage(),
        '/talleres/disponibilidad':      (_) => const GestionarDisponibilidadPage(),
        '/talleres/estado-servicio':     (_) => const ActualizarEstadoServicioPage(),
        '/talleres/servicio-realizado':  (_) => const RegistrarServicioRealizadoPage(),

        // ── Cotización y Pagos ────────────────────────────
        '/pagos/generar':    (_) => const GenerarCotizacionPage(),
        '/pagos/ver':        (_) => const VerCotizacionPage(),
        '/pagos/confirmar':  (_) => const ConfirmarCotizacionPage(),
        '/pagos/realizar':   (_) => const RealizarPagoPage(),
        '/pagos/comisiones': (_) => const VerComisionesPage(),

        // ── Comunicación ──────────────────────────────────
        '/comunicacion/chat':                  (_) => const ChatPage(),
        '/comunicacion/notificaciones':        (_) => const NotificacionesPage(),
        '/comunicacion/ver-tecnico':           (_) => const VerTecnicoMapaPage(),
        '/comunicacion/compartir-ubicacion':   (_) => const CompartirUbicacionPage(),

        // ── Reportes ──────────────────────────────────────
        '/reportes/historial':          (_) => const HistorialServiciosPage(),
        '/reportes/calificar':          (_) => const CalificarServicioPage(),
        '/mantenimiento/recordatorios': (_) => const RecordatoriosMantenimientoPage(),
        '/reportes/metricas-taller':    (_) => const MetricasTallerPage(),
        '/reportes/metricas-globales':  (_) => const MetricasGlobalesPage(),
        '/reportes/auditoria':          (_) => const AuditoriaPage(),
        '/reportes/ranking-talleres':   (_) => const RankingTalleresPage(),
        '/reportes/mis-reportes':       (_) => const MisReportesPage(),
      },
    );
  }
}

// ── Splash Router ────────────────────────────────────────────
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  bool _pushInitDone = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().isLoggedIn(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (snapshot.data!) {
          if (!_pushInitDone) {
            _pushInitDone = true;
            NotificacionService().inicializar(context).ignore();
          }
          WebSocketService().conectar();
          OfflineQueueService().init().then((_) => OfflineQueueService().probarYSincronizar());
          return const DashboardPage();
        }
        return const IniciarSesionPage();
      },
    );
  }
}

// ── Bottom Sheet de pago automático ─────────────────────────
class _PagoBottomSheet extends StatefulWidget {
  const _PagoBottomSheet({required this.cotizacionId, required this.monto});
  final int cotizacionId;
  final double monto;

  @override
  State<_PagoBottomSheet> createState() => _PagoBottomSheetState();
}

class _PagoBottomSheetState extends State<_PagoBottomSheet> {
  final _svc      = EmergenciaService();
  final _stripeSvc = PagoStripeService();
  // Estado por botón para que el spinner aparezca solo en el botón pulsado
  bool _cargandoEfectivo = false;
  bool _cargandoTarjeta  = false;
  String _error = '';

  bool get _cualquieraCargando => _cargandoEfectivo || _cargandoTarjeta;

  Future<void> _pagarTarjeta() async {
    setState(() { _cargandoTarjeta = true; _error = ''; });
    try {
      final intent          = await _stripeSvc.crearIntent(widget.cotizacionId);
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
      await _stripeSvc.confirmarPago(widget.cotizacionId, paymentIntentId);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF16A34A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: const Text('Pago con tarjeta completado',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ));
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() { _cargandoTarjeta = false; _error = e.error.localizedMessage ?? 'Pago cancelado'; });
    } on TokenExpiradoException {
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pushReplacementNamed(navigatorKey.currentContext!, '/login');
    } catch (e) {
      if (!mounted) return;
      setState(() { _cargandoTarjeta = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _pagarEfectivo() async {
    setState(() { _cargandoEfectivo = true; _error = ''; });
    try {
      await _svc.realizarPago(cotizacionId: widget.cotizacionId, metodo: 'efectivo');
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF16A34A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: const Text('Pago registrado correctamente',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ));
    } on TokenExpiradoException {
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pushReplacementNamed(navigatorKey.currentContext!, '/login');
    } catch (e) {
      if (!mounted) return;
      setState(() { _cargandoEfectivo = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final montoStr = widget.monto.toStringAsFixed(2);
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF16A34A)),
          const SizedBox(height: 12),
          const Text('Servicio completado',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: Color(0xFF111827))),
          const SizedBox(height: 6),
          const Text('El técnico finalizó el trabajo. Por favor realiza el pago.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(children: [
              const Text('Total a pagar',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 4),
              Text('Bs. $montoStr',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                      color: AppColors.primary)),
            ]),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_error,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
            ),
          ],
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _cualquieraCargando ? null : _pagarEfectivo,
                icon: _cargandoEfectivo
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.payments_outlined),
                label: const Text('Efectivo',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _cualquieraCargando ? null : _pagarTarjeta,
                icon: _cargandoTarjeta
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.credit_card_outlined),
                label: const Text('Tarjeta',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white70,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(navigatorKey.currentContext!, '/pagos/realizar',
                  arguments: widget.cotizacionId);
            },
            child: const Text('Pagar después',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
