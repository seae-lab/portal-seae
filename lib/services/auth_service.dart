import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Este clientId é usado pelo google_sign_in na web, mas nosso novo fluxo usará o do Firebase.
    // Pode manter por segurança, mas o fluxo principal web não dependerá mais dele diretamente.
    clientId: kIsWeb ? '624901911891-5f8d7ra7b7ph2gej1001ju5prnfbgl2e.apps.googleusercontent.com' : null,
  );

  Stream<User?> get user => _auth.authStateChanges();

  // MÉTODO ATUALIZADO E CORRIGIDO
  Future<String?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      // --- LÓGICA PARA WEB ---
      if (kIsWeb) {
        // Na web, usamos o fluxo de popup gerenciado diretamente pelo Firebase Auth.
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        // Opcional: Força o usuário a sempre escolher uma conta.
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        userCredential = await _auth.signInWithPopup(googleProvider);

        // --- LÓGICA PARA MOBILE ---
      } else {
        // No mobile, o fluxo que você já tinha está correto.
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return 'Login cancelado pelo usuário.';
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        if (googleAuth.idToken == null) {
          // Isso é raro no mobile, mas é uma boa verificação.
          await signOut();
          return 'Não foi possível obter o token de identificação do Google. Tente novamente.';
        }

        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      // --- LÓGICA COMUM DE VALIDAÇÃO (APÓS O LOGIN) ---
      final User? user = userCredential.user;

      if (user != null) {
        // 1. Validação de Domínio
        if (!user.email!.endsWith('@seae.org.br')) {
          await signOut();
          return 'Acesso permitido apenas para contas @seae.org.br.';
        }

        // 2. Validação de Permissão na lista de admins
        final docSnapshot = await _firestore.collection('admins').doc(user.email).get();
        if (!docSnapshot.exists) {
          await signOut(); // Desloga IMEDIATAMENTE se não estiver na lista.
          return 'Este usuário não possui permissão de administrador.';
        }

        // Se todas as validações passaram, o login é um sucesso.
        return null; // Sucesso
      }

      return 'Ocorreu um erro desconhecido após a autenticação.';

    } on FirebaseAuthException catch (e) {
      // Trata erros específicos do Firebase, como popup fechado pelo usuário na web.
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        return 'Login cancelado.';
      }
      print('Erro de FirebaseAuth no signInWithGoogle: ${e.code} - ${e.message}');
      return 'Ocorreu um erro durante o login. Tente novamente.';
    } catch (e) {
      // Trata outros erros inesperados.
      print('Erro inesperado no signInWithGoogle: $e');
      return 'Ocorreu um erro inesperado. Verifique a conexão e tente novamente.';
    }
  }

  Future<void> signOut() async {
    // O disconnect é mais eficaz na web para garantir um estado limpo.
    if (kIsWeb) {
      // Embora o fluxo principal agora seja pelo Firebase, chamar disconnect do google_sign_in
      // ajuda a limpar qualquer estado residual, caso o usuário tenha interagido com ele.
      await _googleSignIn.disconnect();
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
    notifyListeners();
  }
}