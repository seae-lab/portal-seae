import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // O clientId é necessário apenas para a Web para garantir o idToken.
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
        // Se o idToken vier nulo, a autenticação falhou do ponto de vista do Firebase.
        await signOut(); // Limpa qualquer estado parcial de login.
        return 'Não foi possível obter o token de identificação do Google. Tente novamente.';
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. Autentica no Firebase com as credenciais obtidas.
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      // 4. Se a autenticação no Firebase foi bem-sucedida, fazemos as validações de negócio.
      if (user != null) {
        // Validação de Domínio
        if (!user.email!.endsWith('@seae.org.br')) {
          await signOut(); // Desloga IMEDIATAMENTE se o domínio for inválido.
          return 'Acesso permitido apenas para contas @seae.org.br.';
        }

        // Validação de Permissão na lista de admins
        final docSnapshot = await _firestore.collection('admins').doc(user.email).get();
        if (!docSnapshot.exists) {
          await signOut(); // Desloga IMEDIATAMENTE se não estiver na lista.
          return 'Este usuário não possui permissão de administrador.';
        }

        // Se todas as validações passaram, o login é um sucesso.
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

  // MÉTODO ATUALIZADO
  Future<void> signOut() async {
    // O disconnect é mais eficaz na web para garantir um estado limpo.
    if (kIsWeb) {
      await _googleSignIn.disconnect();
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
    notifyListeners();
  }
}
