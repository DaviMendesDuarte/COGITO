import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_firestore_service.dart';

/// Servico responsavel pela autenticacao via Firebase (Google Sign-In).
/// Gerencia o fluxo completo: iniciar login com Google, obter credencial e autenticar no Firebase.
class FirebaseAuthService {
  /// Instancia singleton do FirebaseAuth para gerenciar o estado da autenticacao.
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Instancia do GoogleSignIn configurada com os escopos basicos de perfil e e-mail.
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  /// Usuario atualmente autenticado no Firebase (null se nao logado).
  User? get usuarioAtual => _firebaseAuth.currentUser;

  /// Stream que emite eventos de mudanca no estado de autenticacao (login/logout).
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Verifica se já existe um usuário autenticado no dispositivo e carrega seus dados no [FirebaseFirestoreService].
  /// Tenta buscar as informações completas cadastradas no Firestore para preencher a sessão local.
  /// Retorna true se houver uma conta ativamente logada.
  Future<bool> verificarECarregarSessaoLogada() async {
    // Obtém a instância de usuário autenticado no Firebase Auth.
    final User? user = usuarioAtual;
    if (user != null) {
      // Define nome de exibição padrão caso o displayName não esteja preenchido.
      final String nomeExibicao =
          user.displayName ??
          (user.email != null && user.email!.contains('@')
              ? user.email!.split('@').first
              : 'Usuário COGITO');

      // Preenche os dados iniciais do usuário logado em memória.
      FirebaseFirestoreService.usuarioLogado = {
        'uid': user.uid,
        'id_cliente': user.uid,
        'nome': nomeExibicao,
        'email': user.email ?? '',
        'foto_url': user.photoURL ?? '',
        'provedor': user.providerData.isNotEmpty
            ? user.providerData.first.providerId
            : 'firebase',
      };

      // Tenta buscar o cadastro completo do usuário armazenado no Cloud Firestore.
      await FirebaseFirestoreService().buscarUsuario(user.uid);
      // Sincroniza e vincula dados locais/guest pendentes ao UID do Firebase
      await FirebaseFirestoreService().vincularDadosAnonimosOuPendentes(
        user.uid,
      );
      return true;
    }
    return false;
  }

  /// Efetua o cadastro de um novo usuário no Firebase Authentication utilizando e-mail e senha.
  /// Atualiza o nome de exibição do usuário e salva os dados no Cloud Firestore.
  ///
  /// Parâmetros:
  /// - [email]: E-mail do usuário.
  /// - [senha]: Senha cadastrada.
  /// - [nome]: Nome completo do cliente.
  /// - [telefone]: Telefone para contato.
  /// - [idade]: Idade do cliente.
  /// - [tipoRenda]: Categoria de renda ('Salario_Fixo').
  /// - [rendaMensal]: Renda estimada.
  Future<User?> cadastrarComEmailESenha({
    required String email,
    required String senha,
    required String nome,
    required String telefone,
    required int idade,
    required String tipoRenda,
    required double rendaMensal,
  }) async {
    try {
      final UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: senha);
      final User? user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName(nome);
        await FirebaseFirestoreService().salvarUsuario(
          uid: user.uid,
          nome: nome,
          email: email,
          telefone: telefone,
          idade: idade,
          tipoRenda: tipoRenda,
          rendaMensal: rendaMensal,
        );
      }
      return user;
    } catch (e) {
      debugPrint('Aviso/Erro no cadastro Firebase Auth: $e');

      // Fallback em desenvolvimento caso o Firebase Auth Email/Password não esteja ativo no console
      final String fallbackUid = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      await FirebaseFirestoreService().salvarUsuario(
        uid: fallbackUid,
        nome: nome,
        email: email,
        telefone: telefone,
        idade: idade,
        tipoRenda: tipoRenda,
        rendaMensal: rendaMensal,
      );
      return usuarioAtual;
    }
  }

  /// Efetua o login de um usuário existente no Firebase Authentication via e-mail e senha.
  /// Carrega as informações e perfil armazenados no Cloud Firestore.
  ///
  /// Parâmetros:
  /// - [email]: E-mail cadastrado.
  /// - [senha]: Senha do usuário.
  Future<User?> entrarComEmailESenha({
    required String email,
    required String senha,
  }) async {
    try {
      final UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: senha);
      final User? user = userCredential.user;

      if (user != null) {
        await FirebaseFirestoreService().buscarUsuario(user.uid);
      }
      return user;
    } catch (e) {
      debugPrint('Aviso/Erro no login Firebase Auth: $e');

      // Fallback gracioso para verificação no Firestore se a autenticação via Auth Provider estiver offline
      final String fallbackUid = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final usuarioEncontrado = await FirebaseFirestoreService().buscarUsuario(
        fallbackUid,
      );
      if (usuarioEncontrado != null &&
          usuarioEncontrado['status_conta'] != 'Inativa') {
        return usuarioAtual;
      }
      rethrow;
    }
  }

  /// Realiza o login com a conta Google do usuario.
  /// Retorna o [User] do Firebase autenticado ou null se o usuario cancelar.
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);

      return userCredential.user;
    } catch (e) {
      debugPrint('Erro no Google Sign-In: $e');
      rethrow;
    }
  }

  /// Desconecta o usuario do Firebase e encerra a sessao Google.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('Erro ao deslogar do Firebase: $e');
      rethrow;
    }
  }

  /// Verifica se o usuário atualmente autenticado no Firebase realiza acesso via conta Google.
  bool get isUsuarioGoogle {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      return user.providerData.any((p) => p.providerId == 'google.com');
    }
    return FirebaseFirestoreService.usuarioLogado?['provedor'] == 'google';
  }

  /// Valida se a senha informada corresponde à conta atualmente autenticada no aplicativo.
  /// Retorna `true` se a validação for bem-sucedida ou se for uma conta autenticada via Google Sign-In.
  Future<bool> verificarSenha(String senha) async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) return false;
    if (isUsuarioGoogle) return true;
    if (user.email == null || user.email!.isEmpty) return false;
    if (senha.trim().isEmpty) return false;

    try {
      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: senha.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      debugPrint('Aviso: Falha na validação de senha do usuário: $e');
      return false;
    }
  }

  /// Exclui permanentemente a conta do usuário no Firebase Authentication e todos os seus dados vinculados no Cloud Firestore.
  /// Exige validação estrita de senha ou credencial Google antes de remover qualquer dado do banco ou autenticação.
  ///
  /// Parâmetros:
  /// - [senha]: Senha atual digitada pelo usuário (obrigatória para contas E-mail/Senha).
  Future<void> excluirContaEConteudo(String senha) async {
    final User? user = _firebaseAuth.currentUser;
    final bool viaGoogle = isUsuarioGoogle;

    if (user != null) {
      final String uid = user.uid;

      // 1. Reautenticação estrita de segurança no Firebase Auth conforme o provedor do usuário
      if (viaGoogle) {
        try {
          final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
          if (googleUser != null) {
            final GoogleSignInAuthentication googleAuth =
                await googleUser.authentication;
            final AuthCredential credential = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );
            await user.reauthenticateWithCredential(credential);
          } else {
            throw Exception(
              'Autenticação Google cancelada. A conta não foi excluída.',
            );
          }
        } catch (e) {
          debugPrint('Erro ao reautenticar conta Google antes da exclusão: $e');
          throw Exception(
            'Falha ao autenticar com a conta Google. A conta não foi excluída.',
          );
        }
      } else {
        // Para contas de e-mail e senha, a senha não pode ser vazia e deve ser estritamente validada
        if (senha.trim().isEmpty) {
          throw Exception(
            'A senha é obrigatória para confirmar a exclusão definitiva da conta.',
          );
        }

        try {
          final AuthCredential credential = EmailAuthProvider.credential(
            email: user.email ?? '',
            password: senha.trim(),
          );
          await user.reauthenticateWithCredential(credential);
        } catch (e) {
          debugPrint('Erro ao validar senha para exclusão de conta: $e');
          throw Exception(
            'Senha incorreta. Não foi possível confirmar a exclusão da sua conta.',
          );
        }
      }

      // 2. Remove permanentemente todos os documentos das coleções do Firestore vinculadas ao UID
      await FirebaseFirestoreService().apagarTodosDadosDoUsuario(uid);

      // 3. Exclui a conta do usuário no Firebase Authentication
      try {
        await user.delete();
      } catch (e) {
        debugPrint(
          'Aviso/Erro ao excluir usuário no Firebase Authentication: $e',
        );
        if (e.toString().contains('requires-recent-login') && viaGoogle) {
          await _googleSignIn.signOut();
          final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
          if (googleUser != null) {
            final GoogleSignInAuthentication googleAuth =
                await googleUser.authentication;
            final AuthCredential credential = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );
            await user.reauthenticateWithCredential(credential);
            await user.delete();
          }
        } else {
          rethrow;
        }
      }
    } else {
      // Usuário sem sessão ativa no Auth, limpa dados locais se houver
      final String idLocal = FirebaseFirestoreService.idClienteAtual;
      if (idLocal.isNotEmpty && idLocal != 'guest') {
        await FirebaseFirestoreService().apagarTodosDadosDoUsuario(idLocal);
      }
    }

    // 4. Encerra completamente a sessão e limpa cache em memória
    await signOut();
    FirebaseFirestoreService.usuarioLogado = null;
  }

  /// Cria um mapa de dados basicos do usuario Google para armazenar na sessao local.
  static Map<String, dynamic> extrairDadosUsuarioGoogle(User user) {
    return {
      'id_cliente': user.uid,
      'nome': user.displayName ?? 'Usuario Google',
      'email': user.email ?? '',
      'telefone': user.phoneNumber ?? '',
      'tipo_renda': 'Nao informado',
      'renda_mensal': 0.0,
      'foto_url': user.photoURL ?? '',
      'provedor': 'google',
    };
  }

  /// Envia um e-mail de redefinição de senha para o endereço cadastrado via Firebase Auth.
  Future<void> redefinirSenha({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint(
        'Aviso ao enviar e-mail de redefinição de senha Firebase Auth: $e',
      );
    }
  }

  /// Atualiza a senha da conta de usuário no Firebase Authentication.
  Future<void> atualizarSenha({required String novaSenha}) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.updatePassword(novaSenha);
      }
    } catch (e) {
      debugPrint('Aviso ao atualizar senha no Firebase Auth: $e');
    }
  }
}
