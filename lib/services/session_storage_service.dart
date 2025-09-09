// lib/services/session_storage_service.dart
import 'dart:html' as html;

class SessionStorageService {
  final html.Storage _sessionStorage = html.window.sessionStorage;

  // Salva o token de autenticação na sessão
  void saveAuthToken(String token) {
    _sessionStorage['authToken'] = token;
  }

  // Recupera o token de autenticação da sessão
  String? getAuthToken() {
    return _sessionStorage['authToken'];
  }

  // Remove o token ao fazer logout
  void clearAuthToken() {
    _sessionStorage.remove('authToken');
  }
}