import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AuthService with ChangeNotifier implements Disposable {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '624901911891-5f8d7ra7b7ph2gej1001ju5prnfbgl2e.apps.googleusercontent.com' : null,
  );

  Stream<User?> get user => _auth.authStateChanges();

  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return 'Login cancelado pelo usuário.';
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        await signOut();
        return 'Não foi possível obter o token de identificação do Google. Tente novamente.';
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        if (!user.email!.endsWith('@seae.org.br')) {
          await signOut();
          return 'Acesso permitido apenas para contas @seae.org.br.';
        }

        final docSnapshot = await _firestore.collection('admins').doc(user.email).get();
        if (!docSnapshot.exists) {
          await signOut();
          return 'Este usuário não possui permissão de administrador.';
        }

        return null;
      }

      return 'Ocorreu um erro desconhecido após a autenticação.';

    } catch (e) {
      if (e.toString().contains('popup_closed') || e.toString().contains('popup_closed_by_user')) {
        return 'Login cancelado.';
      }
      print('Erro inesperado no signInWithGoogle: $e');
      return 'Ocorreu um erro inesperado. Verifique a conexão e tente novamente.';
    }
  }

  Future<void> signOut() async {
    if (kIsWeb) {
      await _googleSignIn.disconnect();
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
    notifyListeners();
  }

  @override
  void dispose() {
    // Método dispose da interface Disposable do Modular.
  }
}
