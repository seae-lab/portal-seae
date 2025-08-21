// lib/services/auth_service.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:projetos/models/user_permissions.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '624901911891-5f8d7ra7b7ph2gej1001ju5prnfbgl2e.apps.googleusercontent.com'
        : null,
  );

  UserPermissions? currentUserPermissions;
  StreamSubscription? _authSubscription;

  final Completer<void> _initialAuthCheckCompleter = Completer<void>();
  Future<void> get initialAuthCheck => _initialAuthCheckCompleter.future;

  bool get isAuthenticated => _auth.currentUser != null;

  AuthService() {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _fetchAndSetPermissions(user);
      } else {
        currentUserPermissions = null;
      }

      if (!_initialAuthCheckCompleter.isCompleted) {
        _initialAuthCheckCompleter.complete();
      }
      notifyListeners();
    });
  }

  Future<bool> _fetchAndSetPermissions(User user) async {
    try {
      final docSnapshot =
      await _firestore.collection('base_permissoes').doc(user.email).get();

      if (!docSnapshot.exists || docSnapshot.data() == null) {
        currentUserPermissions = null;
        return false;
      }

      final permissions = UserPermissions.fromMap(docSnapshot.data()!);
      if (!permissions.hasAnyRole) {
        currentUserPermissions = null;
        return false;
      }

      currentUserPermissions = permissions;
      return true;
    } catch (e) {
      currentUserPermissions = null;
      return false;
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final User? user = await _getGoogleUser();
      if (user == null) return 'Login cancelado ou falhou.';

      if (!user.email!.endsWith('@seae.org.br')) {
        await signOut();
        return 'Acesso permitido apenas para contas @seae.org.br.';
      }

      final bool hasPermissions = await _fetchAndSetPermissions(user);
      if (hasPermissions) {
        notifyListeners();
        return null;
      } else {
        await signOut();
        return 'Este usuário não possui nenhum papel atribuído no sistema.';
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        return 'Login cancelado.';
      }
      return 'Erro de autenticação: ${e.message}';
    } catch (e) {
      return 'Ocorreu um erro inesperado.';
    }
  }

  Future<User?> _getGoogleUser() async {
    UserCredential userCredential;
    if (kIsWeb) {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.setCustomParameters({'prompt': 'select_account'});
      userCredential = await _auth.signInWithPopup(googleProvider);
    } else {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      userCredential = await _auth.signInWithCredential(credential);
    }
    return userCredential.user;
  }

  Future<bool> tryToLoadPermissionsForCurrentUser() async {
    final user = _auth.currentUser;
    return user != null ? await _fetchAndSetPermissions(user) : false;
  }

  String getInitialRouteForUser() {
    if (currentUserPermissions == null || !currentUserPermissions!.hasAnyRole) {
      return '/login';
    }
    if (currentUserPermissions!.hasRole('admin') || currentUserPermissions!.hasRole('secretaria')) {
      return '/home/dashboard';
    }
    if (currentUserPermissions!.hasRole('dij')) {
      return '/home/dij';
    }
    return '/login';
  }

  Future<void> signOut() async {
    currentUserPermissions = null;
    await _googleSignIn.signOut();
    await _auth.signOut();
    notifyListeners();
    Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}