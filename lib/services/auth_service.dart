import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_permissions.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '624901911891-5f8d7ra7b7ph2gej1001ju5prnfbgl2e.apps.googleusercontent.com'
        : null,
  );

  Stream<User?> get user => _auth.authStateChanges();
  UserPermissions? currentUserPermissions;

  /// Método privado para buscar e configurar as permissões de um usuário no Firestore.
  /// Retorna 'true' se as permissões foram carregadas com sucesso.
  Future<bool> _fetchAndSetPermissions(User user) async {
    final docSnapshot =
    await _firestore.collection('base_permissoes').doc(user.email).get();

    if (!docSnapshot.exists) {
      await signOut(); // Garante que o usuário seja deslogado se não tiver um documento de permissão
      return false;
    }

    final permissionsData = docSnapshot.data() as Map<String, dynamic>;
    currentUserPermissions = UserPermissions.fromMap(permissionsData);

    if (!currentUserPermissions!.hasAnyRole) {
      await signOut(); // Garante que o usuário seja deslogado se não tiver nenhum papel ativo
      return false;
    }

    notifyListeners();
    return true; // Permissões carregadas com sucesso
  }

  /// Tenta logar o usuário com o Google e carregar suas permissões.
  Future<String?> signInWithGoogle() async {
    try {
      late UserCredential userCredential;
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return 'Login cancelado pelo usuário.';
        final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
        if (googleAuth.idToken == null) {
          await signOut();
          return 'Não foi possível obter o token do Google.';
        }
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      final User? user = userCredential.user;

      if (user != null) {
        if (!user.email!.endsWith('@seae.org.br')) {
          await signOut();
          return 'Acesso permitido apenas para contas @seae.org.br.';
        }

        // Usa o método centralizado para buscar permissões
        final bool hasPermissions = await _fetchAndSetPermissions(user);

        if (hasPermissions) {
          return null; // Sucesso
        } else {
          return 'Este usuário não possui nenhum papel atribuído no sistema.';
        }
      }
      return 'Ocorreu um erro desconhecido.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return 'Login cancelado.';
      }
      return 'Ocorreu um erro durante o login.';
    } catch (e) {
      return 'Ocorreu um erro inesperado.';
    }
  }

  /// Tenta carregar as permissões para o usuário atualmente logado (usado no refresh).
  Future<bool> tryToLoadPermissionsForCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Se as permissões já foram carregadas, não busca de novo
      if (currentUserPermissions != null) return true;

      // Se não, busca no Firestore
      return await _fetchAndSetPermissions(user);
    }
    return false;
  }

  /// Determina a rota inicial para o usuário com base em seus papéis.
  String getInitialRouteForUser() {
    if (currentUserPermissions == null || !currentUserPermissions!.hasAnyRole) {
      return '/';
    }

    final mainPageRoutes = {
      'admin': '/home/dashboard',
      'secretaria': '/home/dashboard',
      'dij': '/home/dij',
    };

    for (var entry in mainPageRoutes.entries) {
      final role = entry.key;
      final route = entry.value;
      if (currentUserPermissions!.hasRole(role)) {
        return route;
      }
    }

    // Fallback de segurança
    return '/';
  }

  /// Desloga o usuário de todos os serviços.
  Future<void> signOut() async {
    currentUserPermissions = null;
    await _googleSignIn.signOut();
    await _auth.signOut();
    // notifyListeners() foi removido daqui para evitar erros de renderização durante a navegação
  }
}