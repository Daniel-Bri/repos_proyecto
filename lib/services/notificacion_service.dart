import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:taller_movil/core/config/app_config.dart';
import 'package:taller_movil/services/api_helper.dart';
import 'package:taller_movil/services/auth_service.dart';

// Handler de mensajes en background (debe ser función top-level)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  _NotificacionLocal.mostrar(message);
}

class _NotificacionLocal {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _canal = AndroidNotificationChannel(
    'rutasegura_canal',
    'RutaSegura',
    description: 'Notificaciones de RutaSegura',
    importance: Importance.high,
  );

  static Future<void> inicializar() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canal);

    await _plugin.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  static void mostrar(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;

    _plugin.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _canal.id,
          _canal.name,
          channelDescription: _canal.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}

class NotificacionService {
  static final _instance = NotificacionService._();
  factory NotificacionService() => _instance;
  NotificacionService._();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final _auth = AuthService();
  String? _token;

  Future<bool> _asegurarFirebase() async {
    try {
      Firebase.app();
      return true;
    } catch (_) {
      try {
        await Firebase.initializeApp();
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Inicializar FCM + notificaciones locales. Llamar una vez al arrancar la app.
  Future<void> inicializar(BuildContext? context) async {
    final firebaseOk = await _asegurarFirebase();
    if (!firebaseOk) return;

    await _NotificacionLocal.inicializar();

    // Solicitar permiso (Android 13+ / iOS)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Obtener token y registrar en backend
    _token = await _fcm.getToken();
    if (_token != null) await _registrarToken(_token!);

    // Actualizar token si FCM lo rota
    _fcm.onTokenRefresh.listen((newToken) async {
      _token = newToken;
      await _registrarToken(newToken);
    });

    // Notificaciones cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen((message) {
      _NotificacionLocal.mostrar(message);
    });

    // Handler de mensajes en background / app terminada
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  }

  /// Eliminar token del backend al cerrar sesión.
  Future<void> eliminarToken() async {
    final firebaseOk = await _asegurarFirebase();
    if (!firebaseOk) return;

    if (_token == null) return;
    try {
      final t = await _auth.getToken();
      await safeDelete(
        Uri.parse('${AppConfig.baseUrl}/api/notificaciones/token'),
        headers: {
          'Content-Type': 'application/json',
          if (t != null) 'Authorization': 'Bearer $t',
        },
        body: jsonEncode({'token': _token, 'plataforma': 'android'}),
      );
    } catch (_) {}
    await _fcm.deleteToken();
    _token = null;
  }

  Future<void> _registrarToken(String token) async {
    final firebaseOk = await _asegurarFirebase();
    if (!firebaseOk) return;

    try {
      final t = await _auth.getToken();
      if (t == null) return; // usuario no autenticado aún
      await safePost(
        Uri.parse('${AppConfig.baseUrl}/api/notificaciones/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $t',
        },
        body: jsonEncode({'token': token, 'plataforma': 'android'}),
      );
    } catch (_) {}
  }
}
