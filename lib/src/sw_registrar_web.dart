// lib/src/sw_registrar_web.dart

import 'dart:html' as html;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';

void registerServiceWorker() {
  if (html.window.navigator.serviceWorker != null) {
    html.window.navigator.serviceWorker!.onMessage.listen((html.MessageEvent event) {
      final data = event.data;
      if (data != null && data['type'] == 'NEW_VERSION_ACTIVATED') {
        final authService = Modular.get<AuthService>();
        authService.signOut();
        html.window.location.reload();
      }
    });
  }
}