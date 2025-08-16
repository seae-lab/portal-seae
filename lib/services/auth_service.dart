import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

// CAMINHO DE IMPORTAÇÃO CORRIGIDO
import 'package:projetos/screens/models/user_permissions.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '624901911891-5f8d7ra7b7ph2gej1001ju5prnfbgl2e.apps.googleusercontent.com' : null,
  );

  Stream<User?> get user => _auth.authStateChanges();
  UserPermissions? currentUserPermissions;

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
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
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

        final docSnapshot = await _firestore.collection('base_permissoes').doc(user.email).get();

        if (!docSnapshot.exists) {
          await signOut();
          return 'Este usuário não possui permissões de acesso.';
        }

        final permissionsData = docSnapshot.data() as Map<String, dynamic>;
        currentUserPermissions = UserPermissions.fromMap(permissionsData);

        if (!currentUserPermissions!.hasAnyRole) {
          await signOut();
          return 'Este usuário não possui nenhum papel atribuído no sistema.';
        }

        notifyListeners();
        return null;
      }
      return 'Ocorreu um erro desconhecido.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') return 'Login cancelado.';
      return 'Ocorreu um erro durante o login.';
    } catch (e) {
      return 'Ocorreu um erro inesperado.';
    }
  }

  String getInitialRouteForUser() {
    if (currentUserPermissions == null) return '/';

    if (currentUserPermissions!.isAdmin) {
      return '/home/overview';
    }

    if (currentUserPermissions!.hasRole('papel_dij')) {
      return '/home/dij';
    }

    // Adicione outras regras de redirecionamento aqui

    // Se não encontrar uma rota principal para o papel, redireciona para a primeira que ele tiver acesso
    // Ou uma página genérica de "bem-vindo". Por enquanto, vamos manter um fallback.
    return '/home/overview';
  }

  Future<void> signOut() async {
    currentUserPermissions = null;
    await _googleSignIn.signOut();
    await _auth.signOut();
    notifyListeners();
  }
}