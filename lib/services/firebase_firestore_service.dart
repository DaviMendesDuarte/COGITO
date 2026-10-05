import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cogito/services/debug_mock_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço responsável pelo gerenciamento de dados do aplicativo COGITO via Firebase Firestore.
/// Substitui integralmente o antigo serviço MySQL por uma solução em nuvem reativa, segura e escalável.
class FirebaseFirestoreService {
  /// Instância singleton do FirebaseFirestore.
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Armazena em memória os dados do usuário atualmente autenticado no app.
  static Map<String, dynamic>? usuarioLogado;

  /// Notifier reativo para transmitir alterações do plano ativo para toda a interface do aplicativo.
  static final ValueNotifier<String> planoAtivoNotifier = ValueNotifier<String>('Grátis');

  // Coleções do Firestore
  static const String _colecaoUsuarios = 'usuarios';
  static const String _colecaoContasBancarias = 'contas_bancarias';
  static const String _colecaoTransacoes = 'transacoes';
  static const String _colecaoOrcamentos = 'orcamentos';
  static const String _colecaoNotificacoes = 'notificacoes';
  static const String _colecaoChats = 'conrado_chats';
  static const String _colecaoMetas = 'metas_financeiras';
  static const String _colecaoCartoes = 'cartoes';

  // --- GESTÃO DE USUÁRIOS ---

  /// Cadastra ou atualiza os dados de um usuário no Firebase Firestore.
  ///
  /// Parâmetros:
  /// - [uid]: Identificador único do usuário (geralmente vindo do Firebase Auth ou e-mail sanitizado).
  /// - [nome]: Nome completo do cliente.
  /// - [email]: E-mail de cadastro.
  /// - [telefone]: Número de telefone para contato.
  /// - [idade]: Idade do cliente.
  /// - [tipoRenda]: Tipo de renda do cliente ('Salario_Fixo').
  /// - [rendaMensal]: Valor numérico estimado da renda mensal.
  Future<bool> salvarUsuario({
    required String uid,
    required String nome,
    required String email,
    required String telefone,
    required int idade,
    required String tipoRenda,
    required double rendaMensal,
  }) async {
    final dados = {
      'uid': uid,
      'nome': nome,
      'email': email,
      'telefone': telefone,
      'idade': idade,
      'tipo_renda': tipoRenda,
      'renda_mensal': rendaMensal,
      'plano': 'Grátis',
      'criado_em': FieldValue.serverTimestamp(),
      'ultimo_acesso': FieldValue.serverTimestamp(),
      'status_conta': 'Ativa',
    };

    try {
      await _db
          .collection(_colecaoUsuarios)
          .doc(uid)
          .set(dados, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Aviso: Armazenando usuário em sessão local offline: $e');
    }

    // Salva na memória da aplicação para acesso imediato sem latência
    usuarioLogado = {
      'id_cliente': uid,
      'uid': uid,
      'nome': nome,
      'email': email,
      'telefone': telefone,
      'idade': idade,
      'tipo_renda': tipoRenda,
      'renda_mensal': rendaMensal,
      'plano': 'Grátis',
    };

    return true;
  }

  /// Carrega o perfil do usuário cadastrado no Firestore.
  Future<Map<String, dynamic>?> buscarUsuario(String uid) async {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      usuarioLogado = DebugMockService.instance.usuarioMock;
      if (usuarioLogado?['plano'] != null) {
        planoAtivoNotifier.value = usuarioLogado!['plano'];
      }
      return usuarioLogado;
    }

    try {
      final doc = await _db.collection(_colecaoUsuarios).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final String planoCarregado = data['plano'] ?? 'Grátis';
        usuarioLogado = {
          'id_cliente': uid,
          'uid': uid,
          'nome': data['nome'] ?? '',
          'email': data['email'] ?? '',
          'telefone': data['telefone'] ?? '',
          'idade': data['idade'] ?? 18,
          'tipo_renda': data['tipo_renda'] ?? 'Salario_Fixo',
          'renda_mensal': (data['renda_mensal'] as num?)?.toDouble() ?? 0.0,
          'plano': planoCarregado,
          'foto_perfil_encriptada': data['foto_perfil_encriptada'],
        };
        planoAtivoNotifier.value = planoCarregado;

        // Persiste localmente para carregamento offline instantâneo
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('plano_usuario_ativo', planoCarregado);
        } catch (_) {}

        return usuarioLogado;
      }
    } catch (e) {
      debugPrint('Erro ao buscar usuário no Firestore: $e');
    }

    // Fallback para cache local se offline
    try {
      final prefs = await SharedPreferences.getInstance();
      final planoSalvo = prefs.getString('plano_usuario_ativo');
      if (planoSalvo != null && planoSalvo.isNotEmpty) {
        if (usuarioLogado != null) {
          usuarioLogado!['plano'] = planoSalvo;
        }
        planoAtivoNotifier.value = planoSalvo;
      }
    } catch (_) {}

    return usuarioLogado;
  }

  /// Atualiza o plano de assinatura do usuário logado (Grátis, Freelancer ou Premium).
  Future<void> atualizarPlano(String uid, String novoPlano) async {
    if (usuarioLogado != null) {
      usuarioLogado!['plano'] = novoPlano;
    }
    if (DebugMockService.instance.modoMockAtivo) {
      DebugMockService.instance.usuarioMock['plano'] = novoPlano;
    }
    // Notifica instantaneamente todos os listeners reativos da aplicação
    planoAtivoNotifier.value = novoPlano;

    // Persiste no SharedPreferences para acesso sem latência
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('plano_usuario_ativo', novoPlano);
    } catch (_) {}

    try {
      await _db.collection(_colecaoUsuarios).doc(uid).update({
        'plano': novoPlano,
      });
    } catch (e) {
      debugPrint('Atualizado plano em memória local: $e');
    }
  }


  /// Retorna o identificador único (UID) do usuário atualmente autenticado no aplicativo.
  /// Prioriza a sessão do Firebase Authentication e faz fallback para a sessão local em memória.
  static String get idClienteAtual {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      return DebugMockService.instance.usuarioMock['id_cliente'] ?? 'mock_user_123';
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid.isNotEmpty) {
        return user.uid;
      }
    } catch (e) {
      debugPrint('Aviso ao consultar FirebaseAuth currentUser: $e');
    }

    if (usuarioLogado != null) {
      if (usuarioLogado!['uid'] != null &&
          usuarioLogado!['uid'].toString().isNotEmpty) {
        return usuarioLogado!['uid'].toString();
      }
      if (usuarioLogado!['id_cliente'] != null &&
          usuarioLogado!['id_cliente'].toString().isNotEmpty) {
        return usuarioLogado!['id_cliente'].toString();
      }
    }

    return 'guest';
  }

  /// Exclui permanentemente todos os documentos e dados associados ao usuário em todas as coleções do Cloud Firestore.
  ///
  /// Coleções e registros limpos:
  /// - `transacoes`: Remove todas as movimentações financeiras com `id_cliente == uid` (e registros orfãos/guest).
  /// - `conrado_chats`: Remove todas as conversas e histórico com o CONRADO.
  /// - `metas_financeiras`: Apaga todas as caixinhas/objetivos financeiros.
  /// - `orcamentos`: Apaga os orçamentos configurados por categoria.
  /// - `notificacoes`: Limpa as notificações push/sistema do usuário.
  /// - `contas_bancarias`: Exclui a conta bancária vinculada.
  /// - `usuarios`: Exclui o documento de perfil principal do Firestore.
  ///
  /// Parâmetros:
  /// - [uid]: Identificador único (UID) da conta a ter seus dados completamente apagados.
  Future<void> apagarTodosDadosDoUsuario(String uid) async {
    if (uid.isEmpty) return;

    try {
      // 1. Exclui todas as transações associadas ao UID do usuário
      final transacoesQuery = await _db
          .collection(_colecaoTransacoes)
          .where('id_cliente', isEqualTo: uid)
          .get();
      for (final doc in transacoesQuery.docs) {
        await doc.reference.delete();
      }

      // 2. Exclui transações pendentes/guest registradas sem ID vinculado
      final transacoesGuestQuery = await _db
          .collection(_colecaoTransacoes)
          .where('id_cliente', isEqualTo: 'guest')
          .get();
      for (final doc in transacoesGuestQuery.docs) {
        await doc.reference.delete();
      }

      // 3. Exclui todas as sessões de chat com o assistente Conrado
      final chatsQuery = await _db
          .collection(_colecaoChats)
          .where('id_cliente', isEqualTo: uid)
          .get();
      for (final doc in chatsQuery.docs) {
        await doc.reference.delete();
      }

      // 4. Exclui todas as metas financeiras (caixinhas) do usuário
      final metasQuery = await _db
          .collection(_colecaoMetas)
          .where('id_cliente', isEqualTo: uid)
          .get();
      for (final doc in metasQuery.docs) {
        await doc.reference.delete();
      }

      // 5. Exclui orçamentos por categoria vinculados
      final orcamentosQuery = await _db
          .collection(_colecaoOrcamentos)
          .where('id_cliente', isEqualTo: uid)
          .get();
      for (final doc in orcamentosQuery.docs) {
        await doc.reference.delete();
      }

      // 6. Exclui notificações registradas para o usuário
      final notificacoesQuery = await _db
          .collection(_colecaoNotificacoes)
          .where('id_cliente', isEqualTo: uid)
          .get();
      for (final doc in notificacoesQuery.docs) {
        await doc.reference.delete();
      }

      // 7. Exclui os dados da conta bancária cadastrada
      try {
        await _db.collection(_colecaoContasBancarias).doc(uid).delete();
      } catch (_) {}
      final contasBancariasQuery = await _db
          .collection(_colecaoContasBancarias)
          .where('id_cliente', isEqualTo: uid)
          .get();
      for (final doc in contasBancariasQuery.docs) {
        await doc.reference.delete();
      }

      // 8. Exclui os cartões de crédito cadastrados pelo usuário
      final cartoesQuery = await _db
          .collection(_colecaoCartoes)
          .where('id_cliente', isEqualTo: uid)
          .get();
      for (final doc in cartoesQuery.docs) {
        await doc.reference.delete();
      }

      // 9. Exclui o documento principal de perfil do usuário na coleção 'usuarios'
      try {
        await _db.collection(_colecaoUsuarios).doc(uid).delete();
      } catch (_) {}
    } catch (e) {
      debugPrint(
        'Aviso/Erro ao apagar dados do usuário no Cloud Firestore: $e',
      );
    }

    // 10. Reseta os caches locais da aplicação para evitar persistência em tela
    _cacheTransacoesLocal.clear();
    _cacheMetasLocal.clear();
    _cacheCartoesLocal.removeWhere((c) => c['id_cliente'] == uid);
    _cacheOrcamentosLocal.removeWhere((o) => o['id_cliente'] == uid);
    usuarioLogado = null;
    _notificarAtualizacaoTransacoes();
    _cartoesStreamController.add(List.from(_cacheCartoesLocal));
  }

  /// Vincula documentos criados sem UID definido (como registros 'guest' ou off-line) à conta autenticada no Firestore.
  ///
  /// Parâmetros:
  /// - [uid]: Identificador único (UID) do usuário logado ao qual os dados serão associados.
  Future<void> vincularDadosAnonimosOuPendentes(String uid) async {
    if (uid.isEmpty || uid == 'guest') return;

    try {
      // Atualiza transações pendentes para o UID autenticado
      final transacoesPendentes = await _db
          .collection(_colecaoTransacoes)
          .where('id_cliente', isEqualTo: 'guest')
          .get();
      for (final doc in transacoesPendentes.docs) {
        await doc.reference.update({'id_cliente': uid});
      }

      // Atualiza chats pendentes do Conrado
      final chatsPendentes = await _db
          .collection(_colecaoChats)
          .where('id_cliente', isEqualTo: 'guest')
          .get();
      for (final doc in chatsPendentes.docs) {
        await doc.reference.update({'id_cliente': uid});
      }

      // Atualiza metas financeiras pendentes
      final metasPendentes = await _db
          .collection(_colecaoMetas)
          .where('id_cliente', isEqualTo: 'guest')
          .get();
      for (final doc in metasPendentes.docs) {
        await doc.reference.update({'id_cliente': uid});
      }
    } catch (e) {
      debugPrint('Aviso ao vincular dados pendentes no Firestore: $e');
    }
  }

  /// Desativa a conta do usuário no Firebase Firestore mantendo histórico de auditoria local.
  Future<bool> inativarConta(String uid) async {
    await apagarTodosDadosDoUsuario(uid);
    return true;
  }

  /// Encerra a sessão atual do usuário logado no aplicativo, limpando com segurança todos os caches.
  static void deslogar() {
    usuarioLogado = null;
    _cacheTransacoesLocal.clear();
    _cacheMetasLocal.clear();
    _cacheCartoesLocal.removeWhere((c) => c['id_cliente'] != 'default');
    _cacheOrcamentosLocal.clear();
    _notificarAtualizacaoTransacoes();
  }

  // --- GESTÃO DE CONTAS BANCÁRIAS ---

  /// Vincula ou edita a conta bancária do usuário no Firestore.
  ///
  /// Parâmetros:
  /// - [idCliente]: UID do usuário proprietário da conta.
  /// - [nomeBanco]: Nome da instituição financeira (ex: Nubank, Itaú).
  /// - [agencia]: Número da agência bancária.
  /// - [numeroConta]: Número da conta com dígito verificador.
  /// - [tipoConta]: Modalidade ('Corrente' ou 'Poupança').
  /// - [nomeTitular]: Nome completo do titular da conta.
  /// - [saldo]: Saldo em reais disponível na conta (padrão 0.0).
  Future<bool> vincularContaBancaria({
    required String idCliente,
    required String nomeBanco,
    required String agencia,
    required String numeroConta,
    required String tipoConta,
    required String nomeTitular,
    double saldo = 0.0,
  }) async {
    final dadosConta = {
      'id_cliente': idCliente,
      'nome_banco': nomeBanco,
      'agencia': agencia,
      'numero_conta': numeroConta,
      'tipo_conta': tipoConta,
      'nome_titular': nomeTitular,
      'saldo': saldo,
      'atualizado_em': FieldValue.serverTimestamp(),
    };

    try {
      await _db
          .collection(_colecaoContasBancarias)
          .doc(idCliente)
          .set(dadosConta, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Erro no Firestore ao salvar conta bancária: $e');
    }

    if (usuarioLogado != null) {
      usuarioLogado!['conta_bancaria'] = dadosConta;
    }

    return true;
  }

  /// Busca os dados da conta bancária vinculada ao usuário.
  Future<Map<String, dynamic>?> buscarContaBancaria(String idCliente) async {
    try {
      final doc = await _db
          .collection(_colecaoContasBancarias)
          .doc(idCliente)
          .get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      debugPrint('Erro ao buscar conta bancária no Firestore: $e');
    }

    if (usuarioLogado != null && usuarioLogado!['conta_bancaria'] != null) {
      return usuarioLogado!['conta_bancaria'] as Map<String, dynamic>;
    }

    return null;
  }

  /// Obtém a conta bancária vinculada ao usuário (alias de conveniência para buscarContaBancaria).
  Future<Map<String, dynamic>?> obterContaBancaria(String idCliente) async {
    return buscarContaBancaria(idCliente);
  }

  /// Remove permanentemente uma conta bancária vinculada ao cliente no Firestore e limpa a sessão local.
  ///
  /// Parâmetros:
  /// - [idCliente]: Identificador único do cliente proprietário da conta bancária.
  ///
  /// Retorno:
  /// - [Future<bool>]: Retorna verdadeiro se a exclusão foi processada.
  Future<bool> removerContaBancaria(String idCliente) async {
    try {
      await _db.collection(_colecaoContasBancarias).doc(idCliente).delete();
    } catch (e) {
      debugPrint('Aviso ao remover conta bancária no Firestore: $e');
    }
    // Limpa a conta da sessão local em memória
    if (usuarioLogado != null) {
      usuarioLogado!['conta_bancaria'] = null;
    }
    return true;
  }

  /// Retorna um [Stream] reativo contendo a lista de contas bancárias vinculadas ao usuário no Cloud Firestore.
  /// Se não houver documentos na subcoleção, verifica os dados armazenados na sessão local.
  ///
  /// Parâmetros:
  /// - [idCliente]: UID do cliente cadastrado no sistema.
  Stream<List<Map<String, dynamic>>> buscarContasBancariasStream(
    String idCliente,
  ) {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      return DebugMockService.instance.contasBancariasStream;
    }

    return _db
        .collection(_colecaoContasBancarias)
        .where('id_cliente', isEqualTo: idCliente)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return usuarioLogado != null &&
                    usuarioLogado!['conta_bancaria'] != null
                ? [usuarioLogado!['conta_bancaria'] as Map<String, dynamic>]
                : [];
          }
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }

  /// Cache local em memória para sincronização instantânea e offline de transações.
  static final List<Map<String, dynamic>> _cacheTransacoesLocal = [];

  /// Getter público para acesso às transações em cache local.
  List<Map<String, dynamic>> get cacheTransacoesLocal => _cacheTransacoesLocal;

  /// StreamController Broadcast para notificação reativa instantânea de transações.
  static final StreamController<List<Map<String, dynamic>>>
  _transacoesStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  /// Notifica todos os ouvintes reativos de transações/saldo instantaneamente sem recarregar a tela.
  static void _notificarAtualizacaoTransacoes() {
    _transacoesStreamController.add(List.from(_cacheTransacoesLocal));
  }

  /// Retorna um [Stream] em tempo real do saldo total do usuário no Cloud Firestore.
  /// O saldo é calculado com base na soma de todas as Receitas subtraídas das Despesas registradas.
  ///
  /// Parâmetros:
  /// - [idCliente]: UID do usuário autenticado.
  Stream<double> obterSaldoStream(String idCliente) {
    return buscarTransacoesStream(idCliente).map((transacoes) {
      double total = 0.0;
      for (final t in transacoes) {
        final double valor = (t['valor'] as num?)?.toDouble() ?? 0.0;
        final String tipo = t['tipo'] ?? 'Receita';
        if (tipo == 'Receita') {
          total += valor;
        } else {
          total -= valor;
        }
      }
      return total;
    });
  }

  /// Executa uma operação de teste/debug de R$ 10,00 no Cloud Firestore.
  /// Adiciona uma transação (Receita se [adicionar] = true ou Despesa se [adicionar] = false)
  /// associada à categoria informada e sincroniza o saldo.
  ///
  /// Parâmetros:
  /// - [idCliente]: UID do usuário logado.
  /// - [titulo]: Título explicativo do extrato.
  /// - [categoria]: Categoria financeira da operação.
  /// - [adicionar]: Se true adiciona R$ 10 (Receita), se false remove R$ 10 (Despesa).
  Future<void> executarOperacaoDebug10Reais({
    required String idCliente,
    required String titulo,
    required String categoria,
    required bool adicionar,
  }) async {
    final double valor = 10.0;
    final String tipo = adicionar ? 'Receita' : 'Despesa';

    await adicionarTransacao(
      idCliente: idCliente,
      titulo: titulo,
      valor: valor,
      categoria: categoria,
      tipo: tipo,
      data: DateTime.now(),
    );
  }

  /// Adiciona uma nova transação (receita ou despesa) no Firestore e sincroniza no cache local.
  ///
  /// Garante que uma única ação gere apenas uma transação, utilizando o ID real do Firestore
  /// imediatamente para evitar duplicação entre o cache local e o listener de snapshots.
  ///
  /// Parâmetros:
  /// - [idCliente]: Identificador único do cliente no sistema.
  /// - [titulo]: Descrição sucinta da transação financeira.
  /// - [valor]: Valor monetário da movimentação em Reais.
  /// - [categoria]: Categoria associada à movimentação.
  /// - [tipo]: Classificação da movimentação ('Receita' ou 'Despesa').
  /// - [data]: Data e horário em que a operação ocorreu.
  /// - [metaId]: ID opcional de meta financeira vinculada à transação.
  /// - [metaTitulo]: Título opcional da meta financeira vinculada.
  Future<void> adicionarTransacao({
    required String idCliente,
    required String titulo,
    required double valor,
    required String categoria,
    required String tipo, // 'Receita' ou 'Despesa'
    required DateTime data,
    String? metaId,
    String? metaTitulo,
  }) async {
    // 1. Gera previamente a referência com o ID definitivo do Firestore para evitar duplicatas temporárias
    final docRef = _db.collection(_colecaoTransacoes).doc();
    final String docId = docRef.id;

    final transacao = {
      'firestore_id': docId,
      'id': docId,
      'id_cliente': idCliente,
      'titulo': titulo,
      'valor': valor,
      'categoria': categoria,
      'tipo': tipo,
      'data': Timestamp.fromDate(data),
      'data_dt': data,
      'criado_em': FieldValue.serverTimestamp(),
      'meta_id': ?metaId,
      'meta_titulo': ?metaTitulo,
    };

    // 2. Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      DebugMockService.instance.salvarTransacaoMock(transacao);
      sincronizarMetasComTransacoes(idCliente);
      return;
    }

    // 3. Remove previamente qualquer registro idêntico para evitar duplicação no cache
    _cacheTransacoesLocal.removeWhere((t) => t['firestore_id'] == docId || t['id'] == docId);
    _cacheTransacoesLocal.insert(0, transacao);
    _notificarAtualizacaoTransacoes();
    sincronizarMetasComTransacoes(idCliente);

    try {
      final payload = Map<String, dynamic>.from(transacao)
        ..remove('firestore_id')
        ..remove('data_dt');
      await docRef.set(payload);

      // 4. Atualiza também o timestamp de última atividade no documento do usuário
      _db.collection(_colecaoUsuarios).doc(idCliente).set({
        'ultimo_movimento': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _notificarAtualizacaoTransacoes();
      sincronizarMetasComTransacoes(idCliente);
    } catch (e) {
      debugPrint(
        'Aviso: Transação armazenada no cache local (modo offline): $e',
      );
    }
  }

  /// Atualiza os dados de uma transação existente no Firestore e no cache em memória.
  /// Atualiza imediatamente as metas financeiras e orçamentos vinculados.
  ///
  /// Parâmetros:
  /// - [transacaoId]: ID do documento no Firestore.
  /// - [titulo]: Novo título/descrição da movimentação.
  /// - [valor]: Novo valor numérico.
  /// - [categoria]: Nova categoria.
  /// - [tipo]: Tipo de transação ('Receita' ou 'Despesa').
  Future<void> atualizarTransacao({
    required String transacaoId,
    required String titulo,
    required double valor,
    required String categoria,
    required String tipo,
  }) async {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      final mockList = DebugMockService.instance.transacoesMock;
      final idx = mockList.indexWhere(
        (t) => t['id'] == transacaoId || t['firestore_id'] == transacaoId,
      );
      if (idx >= 0) {
        final t = Map<String, dynamic>.from(mockList[idx]);
        t['titulo'] = titulo;
        t['valor'] = valor;
        t['categoria'] = categoria;
        t['tipo'] = tipo;
        DebugMockService.instance.salvarTransacaoMock(t);
        sincronizarMetasComTransacoes(idClienteAtual);
      }
      return;
    }

    final int index = _cacheTransacoesLocal.indexWhere(
      (t) => t['firestore_id'] == transacaoId,
    );
    if (index != -1) {
      _cacheTransacoesLocal[index]['titulo'] = titulo;
      _cacheTransacoesLocal[index]['valor'] = valor;
      _cacheTransacoesLocal[index]['categoria'] = categoria;
      _cacheTransacoesLocal[index]['tipo'] = tipo;
      _notificarAtualizacaoTransacoes();
      sincronizarMetasComTransacoes(idClienteAtual);
    }

    try {
      await _db.collection(_colecaoTransacoes).doc(transacaoId).update({
        'titulo': titulo,
        'valor': valor,
        'categoria': categoria,
        'tipo': tipo,
        'atualizado_em': FieldValue.serverTimestamp(),
      });
      _notificarAtualizacaoTransacoes();
      sincronizarMetasComTransacoes(idClienteAtual);
    } catch (e) {
      debugPrint('Aviso: Atualização de transação salva no cache local: $e');
    }
  }

  /// Exclui uma transação pelo seu ID único no Firestore.
  /// Atualiza imediatamente o saldo de metas financeiras e orçamentos vinculados.
  Future<void> excluirTransacao(String transacaoId) async {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      DebugMockService.instance.excluirTransacaoMock(transacaoId);
      sincronizarMetasComTransacoes(idClienteAtual);
      return;
    }

    _cacheTransacoesLocal.removeWhere((t) => t['firestore_id'] == transacaoId);
    _notificarAtualizacaoTransacoes();
    sincronizarMetasComTransacoes(idClienteAtual);

    try {
      await _db.collection(_colecaoTransacoes).doc(transacaoId).delete();
      _notificarAtualizacaoTransacoes();
      sincronizarMetasComTransacoes(idClienteAtual);
    } catch (e) {
      debugPrint('Erro ao excluir transação no Firestore: $e');
    }
  }

  /// Retorna um [Stream] em tempo real com todas as transações do usuário.
  /// Alias amigável para [buscarTransacoesStream].
  Stream<List<Map<String, dynamic>>> ouvirTransacoes(String idCliente) {
    return buscarTransacoesStream(idCliente);
  }

  /// Retorna um [Stream] em tempo real com todas as transações do usuário salvas no Cloud Firestore,
  /// ordenadas por data de forma decrescente (mais recentes primeiro).
  /// Sincroniza o cache local com os dados remotos e notifica ouvintes imediatamente,
  /// garantindo que não ocorram duplicatas no extrato nem desvios no saldo.
  Stream<List<Map<String, dynamic>>> buscarTransacoesStream(String idCliente) {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      return DebugMockService.instance.transacoesStream;
    }

    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? firestoreSub;
    StreamSubscription? localSub;

    List<Map<String, dynamic>> obterListaAtual() {
      final list = _cacheTransacoesLocal
          .where((t) => t['id_cliente'] == idCliente)
          .toList();

      // Deduplicação estrita: assegura que cada ID apareça no máximo uma vez
      final Map<String, Map<String, dynamic>> unicos = {};
      for (final t in list) {
        final String id = (t['firestore_id'] ?? t['id'] ?? '').toString();
        if (id.isNotEmpty) {
          unicos[id] = t;
        } else {
          unicos['temp_${t['titulo']}_${t['valor']}_${t['tipo']}'] = t;
        }
      }

      final resultado = unicos.values.toList();
      resultado.sort((a, b) {
        final dtA = a['data_dt'] as DateTime? ?? DateTime.now();
        final dtB = b['data_dt'] as DateTime? ?? DateTime.now();
        return dtB.compareTo(dtA);
      });
      return resultado;
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        // Emite o estado em cache imediatamente
        controller.add(obterListaAtual());

        // Ouve disparos locais (como inclusão, edição ou exclusão instantânea)
        localSub = _transacoesStreamController.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(obterListaAtual());
          }
        });

        // Sincroniza com as alterações remotas do Cloud Firestore
        try {
          firestoreSub = _db
              .collection(_colecaoTransacoes)
              .where('id_cliente', isEqualTo: idCliente)
              .snapshots()
              .listen(
                (snapshot) {
                  // Mapeia todos os documentos reais presentes no banco de dados
                  final List<Map<String, dynamic>> doBanco = snapshot.docs.map((doc) {
                    final data = Map<String, dynamic>.from(doc.data());
                    data['firestore_id'] = doc.id;
                    data['id'] = doc.id;
                    if (data['data'] is Timestamp) {
                      data['data_dt'] = (data['data'] as Timestamp).toDate();
                    }
                    return data;
                  }).toList();

                  // Reconcilia o cache local: remove os registros deste cliente e atualiza com os documentos do banco
                  _cacheTransacoesLocal.removeWhere((t) => t['id_cliente'] == idCliente);
                  _cacheTransacoesLocal.addAll(doBanco);

                  if (!controller.isClosed) {
                    controller.add(obterListaAtual());
                  }
                },
                onError: (error) {
                  debugPrint(
                    'Aviso ao sincronizar transações com o Firestore: $error',
                  );
                  if (!controller.isClosed) {
                    controller.add(obterListaAtual());
                  }
                },
              );
        } catch (e) {
          debugPrint('Erro ao iniciar stream Firestore de transações: $e');
        }
      },
      onCancel: () {
        firestoreSub?.cancel();
        localSub?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Atualiza o perfil do usuário (nome, email, telefone, idade, renda mensal e tipo de renda) no Firebase Firestore.
  Future<bool> atualizarPerfil({
    required String uid,
    required String nome,
    required String email,
    required String telefone,
    int? idade,
    double? rendaMensal,
    String? tipoRenda,
  }) async {
    final Map<String, dynamic> atualizacoes = {
      'nome': nome,
      'email': email,
      'telefone': telefone,
      'atualizado_em': FieldValue.serverTimestamp(),
    };

    if (idade != null) atualizacoes['idade'] = idade;
    if (rendaMensal != null) atualizacoes['renda_mensal'] = rendaMensal;
    if (tipoRenda != null) atualizacoes['tipo_renda'] = tipoRenda;

    try {
      await _db
          .collection(_colecaoUsuarios)
          .doc(uid)
          .set(atualizacoes, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Erro ao atualizar perfil no Firestore: $e');
    }

    // Atualiza os dados em memória imediatamente, sem necessidade de recarregar
    if (usuarioLogado != null) {
      usuarioLogado!['nome'] = nome;
      usuarioLogado!['email'] = email;
      usuarioLogado!['telefone'] = telefone;
      if (idade != null) usuarioLogado!['idade'] = idade;
      if (rendaMensal != null) usuarioLogado!['renda_mensal'] = rendaMensal;
      if (tipoRenda != null) usuarioLogado!['tipo_renda'] = tipoRenda;
    }

    return true;
  }

  /// Atualiza de forma direta e atômica o tipo de renda do usuário ('Salario_Fixo' ou 'Freelancer').
  Future<bool> atualizarTipoRenda(String idCliente, String tipoRenda) async {
    try {
      await _db.collection(_colecaoUsuarios).doc(idCliente).set({
        'tipo_renda': tipoRenda,
        'atualizado_em': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (usuarioLogado != null) {
        usuarioLogado!['tipo_renda'] = tipoRenda;
      }
      return true;
    } catch (e) {
      debugPrint('Erro ao atualizar tipo de renda no Firestore: $e');
      return false;
    }
  }

  /// Alias amigável para salvarPerfilUsuario nos Primeiros Passos.
  Future<bool> salvarPerfilUsuario({
    required String uid,
    required String nome,
    required String email,
    required String telefone,
    required int idade,
    required String tipoRenda,
    required double rendaMensal,
  }) async {
    return atualizarPerfil(
      uid: uid,
      nome: nome,
      email: email,
      telefone: telefone,
      idade: idade,
      tipoRenda: tipoRenda,
      rendaMensal: rendaMensal,
    );
  }

  /// Salva uma imagem de perfil convertida em string criptografada com assinatura segura no Firestore.
  ///
  /// Parâmetros:
  /// - [uid]: Identificador único do usuário.
  /// - [codigoEncriptado]: String contendo os dados da imagem codificados/encriptados.
  Future<bool> salvarFotoPerfilEncriptada(
    String uid,
    String codigoEncriptado,
  ) async {
    try {
      await _db.collection(_colecaoUsuarios).doc(uid).set({
        'foto_perfil_encriptada': codigoEncriptado,
        'foto_atualizada_em': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Aviso: Foto armazenada em sessão local: $e');
    }

    if (usuarioLogado != null) {
      usuarioLogado!['foto_perfil_encriptada'] = codigoEncriptado;
    }

    return true;
  }

  // --- GESTÃO DE ORÇAMENTOS ---

  /// Cache local de orçamentos para garantia de reatividade instantânea e persistência offline.
  static final List<Map<String, dynamic>> _cacheOrcamentosLocal = [];

  /// StreamController Broadcast para notificação reativa instantânea de alterações em orçamentos.
  static final StreamController<List<Map<String, dynamic>>>
      _orcamentosStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  /// Identifica de forma inteligente se um orçamento se refere a uma fonte de renda/receita.
  static bool isCategoriaRenda(String nomeOuCategoria) {
    final lower = nomeOuCategoria.toLowerCase();
    return lower.contains('trabalho') ||
        lower.contains('freelance') ||
        lower.contains('mesada') ||
        lower.contains('salário') ||
        lower.contains('salario') ||
        lower.contains('renda') ||
        lower.contains('receita') ||
        lower.contains('investimento') ||
        lower.contains('comissão') ||
        lower.contains('comissao') ||
        lower.contains('bico') ||
        lower.contains('venda');
  }

  /// Notifica todos os ouvintes reativos de orçamentos instantaneamente.
  static void _notificarAtualizacaoOrcamentos(String idCliente) {
    _orcamentosStreamController.add(
      _cacheOrcamentosLocal
          .where((o) =>
              o['id_cliente'] == idCliente ||
              o['id_cliente'] == null ||
              o['id_cliente'] == 'guest')
          .toList(),
    );
  }

  /// Salva em cache persistente local (SharedPreferences) os orçamentos do usuário.
  static Future<void> _salvarOrcamentosEmCache(String idCliente) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listaUsuario = _cacheOrcamentosLocal
          .where((o) =>
              o['id_cliente'] == idCliente ||
              o['id_cliente'] == null ||
              o['id_cliente'] == 'guest')
          .toList();
      final String jsonStr = jsonEncode(listaUsuario);
      await prefs.setString('cogito_cache_orcamentos_$idCliente', jsonStr);
    } catch (e) {
      debugPrint('Aviso ao salvar orçamentos no SharedPreferences: $e');
    }
  }

  /// Carrega os orçamentos salvos do SharedPreferences para o cache em memória.
  static Future<void> carregarOrcamentosDoCache(String idCliente) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('cogito_cache_orcamentos_$idCliente');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final List<Map<String, dynamic>> orcamentosCarregados = decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _cacheOrcamentosLocal.removeWhere((o) => o['id_cliente'] == idCliente);
        _cacheOrcamentosLocal.addAll(orcamentosCarregados);
      }
    } catch (e) {
      debugPrint('Aviso ao carregar orçamentos do SharedPreferences: $e');
    }
  }

  /// Salva a definição de orçamento do usuário no Firestore, cache local e persistência em disco.
  ///
  /// Parâmetros:
  /// - [idCliente]: UID do usuário proprietário.
  /// - [id]: Identificador único do documento (se existente).
  /// - [categoria]: Categoria associada ao orçamento.
  /// - [limite]: Valor teto ou alvo monetário planejado.
  /// - [nome]: Título do orçamento (ex: "Trabalho", "Freelance", "Alimentação").
  /// - [tipo]: Classificação ('Despesa' para gastos ou 'Receita' para fontes de renda).
  Future<bool> salvarOrcamento({
    required String idCliente,
    String? id,
    String? categoria,
    required double limite,
    required String nome,
    String? tipo,
  }) async {
    final String nomeFinal =
        nome.trim().isNotEmpty ? nome.trim() : 'Orçamento Geral';
    final String catFinal = categoria ?? 'Geral';
    final String idDoc = id ??
        '${idCliente}_${nomeFinal.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
    final String tipoFinal = tipo ?? (isCategoriaRenda(nomeFinal) ? 'Receita' : 'Despesa');

    // Interceptação pelo Modo Debug de dados simulados
    if (DebugMockService.instance.modoMockAtivo) {
      DebugMockService.instance.salvarOrcamentoMock(
        id: idDoc,
        categoria: catFinal,
        limite: limite,
        nome: nomeFinal,
        tipo: tipoFinal,
      );
      return true;
    }

    final Map<String, dynamic> item = {
      'id_cliente': idCliente,
      'categoria': catFinal,
      'nome': nomeFinal,
      'limite': limite,
      'id': idDoc,
      'tipo': tipoFinal,
    };

    // Atualiza imediatamente o cache local para a interface reagir sem atrasos
    final idx = _cacheOrcamentosLocal.indexWhere(
      (o) =>
          (o['id'] == idDoc || o['nome'] == nomeFinal) &&
          o['id_cliente'] == idCliente,
    );
    if (idx >= 0) {
      _cacheOrcamentosLocal[idx] = item;
    } else {
      _cacheOrcamentosLocal.add(item);
    }

    // Persiste no SharedPreferences e notifica a UI
    await _salvarOrcamentosEmCache(idCliente);
    _notificarAtualizacaoOrcamentos(idCliente);

    try {
      await _db
          .collection(_colecaoOrcamentos)
          .doc(idDoc)
          .set({
            'id_cliente': idCliente,
            'categoria': catFinal,
            'nome': nomeFinal,
            'limite': limite,
            'tipo': tipoFinal,
            'atualizado_em': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Aviso: Orçamento salvo no cache local (modo offline): $e');
      return true;
    }
  }

  /// Retorna um Stream em tempo real das definições de orçamento do usuário.
  ///
  /// Garante emissão imediata dos dados em cache ou persistidos no SharedPreferences,
  /// reage instantaneamente aos cadastros locais e sincroniza continuamente com o Cloud Firestore.
  Stream<List<Map<String, dynamic>>> buscarOrcamentosStream(String idCliente) {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      return DebugMockService.instance.orcamentosStream;
    }

    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? firestoreSub;
    StreamSubscription? localSub;

    List<Map<String, dynamic>> obterListaAtual() {
      return _cacheOrcamentosLocal
          .where((o) =>
              o['id_cliente'] == idCliente ||
              o['id_cliente'] == null ||
              o['id_cliente'] == 'guest')
          .toList();
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () async {
        // 1. Carrega do armazenamento local se a memória estiver vazia
        if (_cacheOrcamentosLocal.where((o) => o['id_cliente'] == idCliente).isEmpty) {
          await carregarOrcamentosDoCache(idCliente);
        }
        if (!controller.isClosed) {
          controller.add(obterListaAtual());
        }

        // 2. Ouve disparos locais imediatos (salvamento e exclusão)
        localSub = _orcamentosStreamController.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(obterListaAtual());
          }
        });

        // 3. Ouve o Cloud Firestore em tempo real
        try {
          firestoreSub = _db
              .collection(_colecaoOrcamentos)
              .where('id_cliente', isEqualTo: idCliente)
              .snapshots()
              .listen(
                (snapshot) {
                  // Mapeia todos os orçamentos vigentes gravados no Cloud Firestore
                  final List<Map<String, dynamic>> orcamentosRemotos =
                      snapshot.docs.map((doc) {
                    final data = Map<String, dynamic>.from(doc.data());
                    data['id'] = doc.id;
                    return data;
                  }).toList();

                  // Reconcilia o cache local do cliente com o banco remoto
                  _cacheOrcamentosLocal
                      .removeWhere((o) => o['id_cliente'] == idCliente);
                  _cacheOrcamentosLocal.addAll(orcamentosRemotos);
                  _salvarOrcamentosEmCache(idCliente);

                  if (!controller.isClosed) {
                    controller.add(obterListaAtual());
                  }
                },
                onError: (error) {
                  debugPrint(
                    'Aviso ao sincronizar orçamentos do Firestore: $error',
                  );
                  if (!controller.isClosed) {
                    controller.add(obterListaAtual());
                  }
                },
              );
        } catch (e) {
          debugPrint('Erro ao iniciar escuta de orçamentos no Firestore: $e');
        }
      },
      onCancel: () {
        firestoreSub?.cancel();
        localSub?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Exclui uma definição de orçamento no Firestore, no cache local e em SharedPreferences.
  /// Suporta identificação flexível por id, nome ou categoria.
  ///
  /// Atualiza imediatamente a interface e sincroniza a remoção com o backend.
  Future<bool> excluirOrcamento({
    required String idCliente,
    String? id,
    String? nome,
    String? categoria,
  }) async {
    // Interceptação pelo Modo Debug de dados simulados
    if (DebugMockService.instance.modoMockAtivo) {
      DebugMockService.instance.excluirOrcamentoMock(
        id: id,
        nome: nome,
        categoria: categoria,
      );
      return true;
    }

    _cacheOrcamentosLocal.removeWhere(
      (o) =>
          o['id_cliente'] == idCliente &&
          ((id != null && o['id'] == id) ||
              (nome != null && o['nome'] == nome) ||
              (categoria != null && o['categoria'] == categoria)),
    );

    await _salvarOrcamentosEmCache(idCliente);
    _notificarAtualizacaoOrcamentos(idCliente);

    try {
      final docId = id ??
          (nome != null
              ? '${idCliente}_${nome.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}'
              : '${idCliente}_$categoria');
      await _db.collection(_colecaoOrcamentos).doc(docId).delete();
      return true;
    } catch (e) {
      debugPrint('Aviso: Orçamento removido do cache local: $e');
      return true;
    }
  }

  // --- GESTÃO DE NOTIFICAÇÕES (Firebase Sync) ---

  /// Cache local em memória de notificações para garantia de entrega e reação instantânea.
  static final List<Map<String, dynamic>> _cacheNotificacoesLocal = [];

  /// StreamController Broadcast para notificação reativa instantânea de notificações.
  static final StreamController<List<Map<String, dynamic>>>
  _notificacoesStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  /// Retorna um Stream em tempo real das notificações do usuário cadastradas no Firestore.
  Stream<List<Map<String, dynamic>>> buscarNotificacoesStream(
    String idCliente,
  ) {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      return DebugMockService.instance.notificacoesStream;
    }

    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? firestoreSub;
    StreamSubscription? localSub;

    List<Map<String, dynamic>> obterListaNotificacoes() {
      final list = _cacheNotificacoesLocal
          .where(
            (n) =>
                n['id_cliente'] == idCliente ||
                n['id_cliente'] == null ||
                n['id_cliente'] == 'guest',
          )
          .toList();
      list.sort((a, b) {
        final dtA = (a['data'] is Timestamp)
            ? (a['data'] as Timestamp).toDate()
            : (a['data'] as DateTime? ?? DateTime.now());
        final dtB = (b['data'] is Timestamp)
            ? (b['data'] as Timestamp).toDate()
            : (b['data'] as DateTime? ?? DateTime.now());
        return dtB.compareTo(dtA);
      });
      return list;
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        // Emite imediatamente as notificações em memória
        controller.add(obterListaNotificacoes());

        // Ouve disparos locais (inclusive da Sessão de Debug)
        localSub = _notificacoesStreamController.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(obterListaNotificacoes());
          }
        });

        // Ouve o Cloud Firestore em tempo real
        try {
          firestoreSub = _db
              .collection(_colecaoNotificacoes)
              .where('id_cliente', isEqualTo: idCliente)
              .snapshots()
              .listen(
                (snapshot) {
                  for (final doc in snapshot.docs) {
                    final data = doc.data();
                    data['id'] = doc.id;
                    final idx = _cacheNotificacoesLocal.indexWhere(
                      (n) => n['id'] == doc.id,
                    );
                    if (idx >= 0) {
                      _cacheNotificacoesLocal[idx] = data;
                    } else {
                      _cacheNotificacoesLocal.add(data);
                    }
                  }
                  if (!controller.isClosed) {
                    controller.add(obterListaNotificacoes());
                  }
                },
                onError: (err) {
                  debugPrint(
                    'Aviso ao sincronizar notificações do Firestore: $err',
                  );
                  if (!controller.isClosed) {
                    controller.add(obterListaNotificacoes());
                  }
                },
              );
        } catch (e) {
          debugPrint('Erro ao iniciar stream Firestore de notificações: $e');
        }
      },
      onCancel: () {
        firestoreSub?.cancel();
        localSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Cria e envia uma nova notificação para o usuário no Cloud Firestore e no cache reativo local.
  Future<bool> criarNotificacao({
    required String idCliente,
    required String titulo,
    required String mensagem,
    required String categoria,
  }) async {
    final item = {
      'id':
          'notif_${DateTime.now().millisecondsSinceEpoch}_${_cacheNotificacoesLocal.length}',
      'id_cliente': idCliente,
      'titulo': titulo,
      'mensagem': mensagem,
      'categoria': categoria,
      'lida': false,
      'data': DateTime.now(),
    };

    _cacheNotificacoesLocal.insert(0, item);
    _notificacoesStreamController.add(List.from(_cacheNotificacoesLocal));

    try {
      final docRef = await _db.collection(_colecaoNotificacoes).add({
        'id_cliente': idCliente,
        'titulo': titulo,
        'mensagem': mensagem,
        'categoria': categoria,
        'lida': false,
        'data': FieldValue.serverTimestamp(),
      });
      item['id'] = docRef.id;
      _notificacoesStreamController.add(List.from(_cacheNotificacoesLocal));
      return true;
    } catch (e) {
      debugPrint('Aviso: Notificação registrada em sessão local offline: $e');
      return true;
    }
  }

  /// Marca uma notificação específica como lida no Firestore e no cache local.
  Future<void> marcarNotificacaoComoLida(String idNotificacao) async {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      DebugMockService.instance.marcarNotificacaoComoLida(idNotificacao);
      return;
    }

    final idx = _cacheNotificacoesLocal.indexWhere(
      (n) => n['id'] == idNotificacao || n['firestore_id'] == idNotificacao,
    );
    if (idx >= 0) {
      _cacheNotificacoesLocal[idx]['lida'] = true;
      _notificacoesStreamController.add(List.from(_cacheNotificacoesLocal));
    }
    try {
      await _db.collection(_colecaoNotificacoes).doc(idNotificacao).update({
        'lida': true,
      });
    } catch (e) {
      debugPrint('Erro ao marcar notificação como lida: $e');
    }
  }

  /// Limpa todas as notificações do usuário no Cloud Firestore e no cache local.
  Future<void> limparNotificacoesDoUsuario(String idCliente) async {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      DebugMockService.instance.limparNotificacoes();
      return;
    }

    _cacheNotificacoesLocal.removeWhere(
      (n) =>
          n['id_cliente'] == idCliente ||
          n['id_cliente'] == null ||
          n['id_cliente'] == 'guest',
    );
    _notificacoesStreamController.add(List.from(_cacheNotificacoesLocal));

    try {
      final query = await _db
          .collection(_colecaoNotificacoes)
          .where('id_cliente', isEqualTo: idCliente)
          .get();
      for (final doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Erro ao limpar notificações do usuário: $e');
    }
  }

  /// Limpa todas as notificações do usuário (alias amigável para limparNotificacoesDoUsuario).
  Future<void> limparNotificacoes(String idCliente) async {
    await limparNotificacoesDoUsuario(idCliente);
  }

  /// Busca as notificações do usuário no Firestore (compatibilidade síncrona/fallback).
  Future<List<Map<String, dynamic>>> buscarNotificacoes(
    String idCliente,
  ) async {
    try {
      final querySnapshot = await _db
          .collection(_colecaoNotificacoes)
          .where('id_cliente', isEqualTo: idCliente)
          .get();

      final list = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      if (list.isEmpty) {
        return _obterNotificacoesPadrao();
      }
      return list;
    } catch (e) {
      debugPrint('Retornando notificações padrão em modo offline: $e');
      return _obterNotificacoesPadrao();
    }
  }

  /// Notificações padrão de demonstração offline.
  List<Map<String, dynamic>> _obterNotificacoesPadrao() {
    return [
      {
        'id': 'notif_1',
        'titulo': 'Bem-vindo ao COGITO!',
        'mensagem':
            'Sua conta foi criada com sucesso. Configure seus orçamentos por categoria.',
        'categoria': 'Sistema',
        'lida': false,
        'data': DateTime.now().subtract(const Duration(minutes: 30)),
      },
      {
        'id': 'notif_2',
        'titulo': 'Dica do CONRADO 💡',
        'mensagem':
            'Você atingiu 70% do seu limite de gastos com Alimentação este mês.',
        'categoria': 'IA Financeira',
        'lida': false,
        'data': DateTime.now().subtract(const Duration(hours: 4)),
      },
      {
        'id': 'notif_3',
        'titulo': 'Segurança em Primeiro Lugar',
        'mensagem':
            'Seus dados estão protegidos com criptografia de ponta a ponta na nuvem.',
        'categoria': 'Segurança',
        'lida': true,
        'data': DateTime.now().subtract(const Duration(days: 1)),
      },
    ];
  }

  // --- GESTÃO DE MÚLTIPLOS CHATS DO CONRADO ---

  /// Salva ou cria uma nova sessão de chat com o CONRADO no Firestore.
  ///
  /// Parâmetros:
  /// - [idCliente]: UID do usuário proprietário da conversa.
  /// - [chatId]: Identificador exclusivo da sessão de chat.
  /// - [titulo]: Título representativo da conversa.
  /// - [mensagens]: Lista de mapas contendo o histórico de mensagens trocadas.
  /// - [topico]: Tópico temático abordado na conversa (ex: "Planejamento Financeiro").
  Future<void> salvarSessaoChat({
    required String idCliente,
    required String chatId,
    required String titulo,
    required List<Map<String, dynamic>> mensagens,
    String? topico,
  }) async {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      DebugMockService.instance.salvarSessaoChatMock(
        chatId: chatId,
        titulo: titulo,
        topico: topico ?? titulo,
        mensagens: mensagens,
      );
      return;
    }

    // Monta o mapa de dados da sessão incluindo data de atualização e tópico temático
    final dadosChat = {
      'id_cliente': idCliente,
      'chat_id': chatId,
      'titulo': titulo,
      'topico': topico ?? titulo,
      'mensagens': mensagens,
      'atualizado_em': FieldValue.serverTimestamp(),
      'criado_em': FieldValue.serverTimestamp(),
    };

    try {
      await _db
          .collection(_colecaoChats)
          .doc('${idCliente}_$chatId')
          .set(dadosChat, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Sessão de chat salva no cache da aplicação: $e');
    }
  }

  /// Recupera as sessões de chat do CONRADO pertencentes ao usuário no Firestore.
  /// Filtra apenas os chats criados/atualizados dentro do período de retenção de 7 dias (uma semana).
  ///
  /// Parâmetros:
  /// - [idCliente]: UID do usuário para busca das conversas.
  Future<List<Map<String, dynamic>>> obterSessoesChat({
    required String idCliente,
  }) async {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      return DebugMockService.instance.sessoesChatMock.map((m) {
        final List mensagens = (m['mensagens'] as List?) ?? [];
        final DateTime dt = (m['data'] is Timestamp)
            ? (m['data'] as Timestamp).toDate()
            : DateTime.now();
        return {
          'id': m['id'],
          'titulo': m['titulo'],
          'topico': m['titulo'],
          'ultimaMensagem': m['preview'],
          'mensagensCount': mensagens.length,
          'atualizadoEm': dt,
        };
      }).toList();
    }

    try {
      final snapshot = await _db
          .collection(_colecaoChats)
          .where('id_cliente', isEqualTo: idCliente)
          .get();

      final List<Map<String, dynamic>> listaChats = [];
      final agora = DateTime.now();
      final limiteSeteDias = agora.subtract(const Duration(days: 7));

      for (final doc in snapshot.docs) {
        final data = doc.data();
        DateTime dataAtualizacao = agora;

        // Converte o timestamp do Firestore para DateTime
        if (data['atualizado_em'] is Timestamp) {
          dataAtualizacao = (data['atualizado_em'] as Timestamp).toDate();
        } else if (data['criado_em'] is Timestamp) {
          dataAtualizacao = (data['criado_em'] as Timestamp).toDate();
        }

        // Regra de retenção: chats com mais de 7 dias são desconsiderados
        if (dataAtualizacao.isAfter(limiteSeteDias)) {
          final List mensagens = (data['mensagens'] as List?) ?? [];
          final String ultimaMensagem = mensagens.isNotEmpty
              ? (mensagens.last['text'] ?? 'Conversa iniciada.')
              : 'Conversa iniciada.';

          listaChats.add({
            'id': data['chat_id'] ?? doc.id,
            'titulo': data['titulo'] ?? 'Conversa com CONRADO',
            'topico': data['topico'] ?? data['titulo'] ?? 'Geral',
            'ultimaMensagem': ultimaMensagem,
            'mensagensCount': mensagens.length,
            'atualizadoEm': dataAtualizacao,
          });
        }
      }

      // Ordena pelas conversas mais recentes primeiro
      listaChats.sort((a, b) {
        final DateTime dataA = a['atualizadoEm'] as DateTime;
        final DateTime dataB = b['atualizadoEm'] as DateTime;
        return dataB.compareTo(dataA);
      });

      return listaChats;
    } catch (e) {
      debugPrint('Erro ao obter sessões de chat no Firestore: $e');
      return [];
    }
  }

  /// Recupera as mensagens salvas de uma conversa específica do CONRADO no Firestore.
  ///
  /// Parâmetros:
  /// - [idCliente]: UID do usuário proprietário da conversa.
  /// - [chatId]: Identificador exclusivo do chat a ser carregado.
  Future<List<Map<String, dynamic>>> obterMensagensChat({
    required String idCliente,
    required String chatId,
  }) async {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      // Procura a sessão específica informada. Caso seja um chat novo, retorna lista vazia
      final sessao = DebugMockService.instance.sessoesChatMock
          .cast<Map<String, dynamic>?>()
          .firstWhere(
            (s) => s?['id'] == chatId,
            orElse: () => null,
          );
      if (sessao != null) {
        return List<Map<String, dynamic>>.from(sessao['mensagens'] ?? []);
      }
      return [];
    }

    try {
      final doc = await _db
          .collection(_colecaoChats)
          .doc('${idCliente}_$chatId')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final List mensagens = (data['mensagens'] as List?) ?? [];
        return mensagens
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erro ao obter mensagens do chat no Firestore: $e');
      return [];
    }
  }

  /// Exclui permanentemente uma sessão de chat do CONRADO no Firestore.
  ///
  /// Parâmetros:
  /// - [idCliente]: UID do usuário proprietário do chat.
  /// - [chatId]: Identificador único da conversa a ser apagada.
  Future<bool> excluirSessaoChat({
    required String idCliente,
    required String chatId,
  }) async {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      DebugMockService.instance.excluirSessaoChatMock(chatId);
      return true;
    }

    try {
      await _db.collection(_colecaoChats).doc('${idCliente}_$chatId').delete();
      return true;
    } catch (e) {
      debugPrint('Erro ao excluir sessão de chat no Firestore: $e');
      return false;
    }
  }

  // --- GESTÃO DE METAS FINANCEIRAS ("CAIXINHAS") ---

  /// Cache em memória local para garantir disponibilidade offline e resposta instantânea das metas.
  static final List<Map<String, dynamic>> _cacheMetasLocal = [];

  /// Conjunto com identificadores de metas excluídas recentemente para evitar reaparecimento por snapshots atrasados.
  static final Set<String> _metasExcluidasRecentemente = {};

  /// StreamController Broadcast para notificação reativa instantânea de metas financeiras.
  static final StreamController<List<Map<String, dynamic>>>
      _metasStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  /// Getter público para acesso às metas financeiras armazenadas no cache local.
  List<Map<String, dynamic>> get cacheMetasLocal => _cacheMetasLocal;

  /// Notifica todos os ouvintes reativos de metas financeiras instantaneamente.
  static void _notificarAtualizacaoMetas(String idCliente) {
    _metasStreamController.add(
      _cacheMetasLocal
          .where((m) =>
              m['id_cliente'] == idCliente ||
              m['id_cliente'] == null ||
              m['id_cliente'] == 'guest')
          .toList(),
    );
  }

  /// Salva em cache persistente local (SharedPreferences) as metas financeiras do usuário.
  /// Também salva em uma chave global de contingência para garantir restauração caso a sessão mude.
  static Future<void> _salvarMetasEmCache(String idCliente) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listaUsuario = _cacheMetasLocal
          .where((m) =>
              m['id_cliente'] == idCliente ||
              m['id_cliente'] == null ||
              m['id_cliente'] == 'guest')
          .toList();
      final String jsonStr = jsonEncode(listaUsuario);
      await prefs.setString('cogito_cache_metas_$idCliente', jsonStr);
      // Salva contingência global
      if (listaUsuario.isNotEmpty) {
        await prefs.setString('cogito_cache_metas_backup', jsonStr);
      }
    } catch (e) {
      debugPrint('Aviso ao salvar metas no SharedPreferences: $e');
    }
  }

  /// Carrega as metas salvas do SharedPreferences para o cache em memória de forma não-destrutiva.
  static Future<void> carregarMetasDoCache(String idCliente) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr = prefs.getString('cogito_cache_metas_$idCliente');
      // Se não encontrou no UID específico, tenta restaurar do backup ou da sessão guest
      if (jsonStr == null || jsonStr.isEmpty || jsonStr == '[]') {
        jsonStr = prefs.getString('cogito_cache_metas_backup') ??
            prefs.getString('cogito_cache_metas_guest');
      }

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final List<Map<String, dynamic>> metasCarregadas = decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .where((m) => !_metasExcluidasRecentemente.contains(m['id'] ?? m['firestore_id']))
            .toList();

        // Faz mesclagem inteligente sem apagar metas já presentes em memória
        for (final m in metasCarregadas) {
          final String id = (m['firestore_id'] ?? m['id'] ?? '').toString();
          if (id.isNotEmpty && !_cacheMetasLocal.any((existente) => (existente['firestore_id'] ?? existente['id']) == id)) {
            _cacheMetasLocal.add(m);
          }
        }
      }
    } catch (e) {
      debugPrint('Aviso ao carregar metas do SharedPreferences: $e');
    }
  }

  /// Envia para o Cloud Firestore quaisquer metas pendentes criadas localmente que ainda não foram sincronizadas.
  static Future<void> _sincronizarMetasPendentesComFirestore(String uid) async {
    final List<Map<String, dynamic>> pendentes = _cacheMetasLocal
        .where((m) =>
            m['synced_to_firestore'] != true &&
            !_metasExcluidasRecentemente.contains(m['id'] ?? m['firestore_id']))
        .toList();

    for (final meta in pendentes) {
      final String metaId = (meta['firestore_id'] ?? meta['id'] ?? '').toString();
      if (metaId.isEmpty) continue;

      try {
        final Map<String, dynamic> payload = Map<String, dynamic>.from(meta)
          ..remove('firestore_id')
          ..remove('synced_to_firestore');
        payload['id_cliente'] = uid;
        payload['atualizado_em'] = FieldValue.serverTimestamp();

        final db = FirebaseFirestore.instance;
        await db.collection(_colecaoMetas).doc(metaId).set(payload, SetOptions(merge: true));
        try {
          await db.collection('metas').doc(metaId).set(payload, SetOptions(merge: true));
        } catch (_) {}

        meta['synced_to_firestore'] = true;
        meta['id_cliente'] = uid;
        debugPrint('Meta pendente sincronizada com sucesso no Firestore: $metaId');
      } catch (e) {
        debugPrint('Aviso: Falha ao sincronizar meta pendente $metaId com Firestore: $e');
      }
    }
  }

  /// Retorna sincronamente as metas do cliente presentes no cache local em memória.
  static List<Map<String, dynamic>> obterMetasDoCache(String idCliente) {
    return _cacheMetasLocal
        .where((m) =>
            m['id_cliente'] == idCliente ||
            m['id_cliente'] == null ||
            m['id_cliente'] == 'guest')
        .toList();
  }

  /// Retorna as metas do cache local para a instância atual.
  List<Map<String, dynamic>> metasDoCacheLocal(String idCliente) =>
      obterMetasDoCache(idCliente);

  /// Sincroniza o saldo acumulado das metas financeiras com base nas movimentações do usuário.
  /// Caso uma transação esteja associada a uma meta (por meta_id, título da meta ou categoria),
  /// atualiza o valor atual da meta de forma reativa e instantânea.
  void sincronizarMetasComTransacoes(String idCliente) {
    if (DebugMockService.instance.modoMockAtivo) {
      // Sincronização no ambiente simulado (Mock)
      final metas = DebugMockService.instance.metasFinanceirasMock;
      final transacoes = DebugMockService.instance.transacoesMock;
      for (final meta in metas) {
        final String metaId =
            (meta['id'] ?? meta['firestore_id'] ?? '').toString();
        final String metaTitulo =
            (meta['titulo'] ?? '').toString().toLowerCase().trim();
        final double metaBase =
            (meta['valor_base'] ?? meta['valor_inicial'] as num?)?.toDouble() ??
                ((meta['valor_atual'] as num?)?.toDouble() ?? 0.0);
        double movimentacaoTotal = 0.0;
        bool temVinculo = false;

        for (final t in transacoes) {
          final String tMetaId = (t['meta_id'] ?? '').toString();
          final String tTitulo =
              (t['titulo'] ?? t['descricao'] ?? '').toString().toLowerCase();
          final String tCat = (t['categoria'] ?? '').toString().toLowerCase();
          final bool match = (tMetaId.isNotEmpty && tMetaId == metaId) ||
              (metaTitulo.isNotEmpty &&
                  metaTitulo.length >= 3 &&
                  (tTitulo.contains(metaTitulo) || tCat == metaTitulo));
          if (match) {
            temVinculo = true;
            final double val = (t['valor'] as num?)?.toDouble() ?? 0.0;
            if (t['tipo'] == 'Receita') {
              movimentacaoTotal += val;
            } else {
              movimentacaoTotal -= val;
            }
          }
        }

        if (temVinculo) {
          final double novoAtual =
              (metaBase + movimentacaoTotal).clamp(0.0, double.infinity);
          DebugMockService.instance.salvarMetaMock(
            id: metaId,
            titulo: meta['titulo'] ?? 'Meta',
            valorObjetivo:
                (meta['valor_objetivo'] as num?)?.toDouble() ?? 1000.0,
            valorAtual: novoAtual,
            categoria: meta['categoria'] ?? 'Geral',
          );
        }
      }
      return;
    }

    // Sincronização no ambiente real/Firestore
    final metas = _cacheMetasLocal
        .where((m) =>
            m['id_cliente'] == idCliente ||
            m['id_cliente'] == null ||
            m['id_cliente'] == 'guest')
        .toList();
    final transacoes = _cacheTransacoesLocal
        .where((t) =>
            t['id_cliente'] == idCliente ||
            t['id_cliente'] == null ||
            t['id_cliente'] == 'guest')
        .toList();
    bool houveAlteracao = false;

    for (final meta in metas) {
      final String metaId =
          (meta['firestore_id'] ?? meta['id'] ?? '').toString();
      final String metaTitulo =
          (meta['titulo'] ?? '').toString().toLowerCase().trim();
      final double metaBase =
          (meta['valor_base'] ?? meta['valor_inicial'] as num?)?.toDouble() ??
              ((meta['valor_atual'] as num?)?.toDouble() ?? 0.0);
      double movimentacao = 0.0;
      bool achouTransacao = false;

      for (final t in transacoes) {
        final String tMetaId = (t['meta_id'] ?? '').toString();
        final String tTitulo =
            (t['titulo'] ?? t['descricao'] ?? '').toString().toLowerCase();
        final String tCat = (t['categoria'] ?? '').toString().toLowerCase();
        final bool match = (tMetaId.isNotEmpty &&
                (tMetaId == metaId || tMetaId == meta['id'])) ||
            (metaTitulo.isNotEmpty &&
                metaTitulo.length >= 3 &&
                (tTitulo.contains(metaTitulo) || tCat == metaTitulo));
        if (match) {
          achouTransacao = true;
          final double val = (t['valor'] as num?)?.toDouble() ?? 0.0;
          if (t['tipo'] == 'Receita') {
            movimentacao += val;
          } else {
            movimentacao -= val;
          }
        }
      }

      if (achouTransacao) {
        final double novoValor =
            (metaBase + movimentacao).clamp(0.0, double.infinity);
        final double objetivo =
            (meta['valor_objetivo'] as num?)?.toDouble() ?? 1.0;
        final bool concluida = novoValor >= objetivo;
        meta['valor_atual'] = novoValor;
        meta['concluida'] = concluida;
        meta['status'] = concluida ? 'concluida' : 'em_andamento';
        meta['valor_base'] = metaBase;
        houveAlteracao = true;

        // Atualiza assincronamente o Cloud Firestore
        try {
          _db.collection(_colecaoMetas).doc(metaId).update({
            'valor_atual': novoValor,
            'concluida': concluida,
            'status': concluida ? 'concluida' : 'em_andamento',
            'atualizado_em': FieldValue.serverTimestamp(),
          }).catchError((_) {});
        } catch (_) {}
      }
    }

    if (houveAlteracao) {
      _salvarMetasEmCache(idCliente);
      _notificarAtualizacaoMetas(idCliente);
    }
  }

  /// Salva ou atualiza uma meta financeira ("caixinha") no Firestore, cache local e SharedPreferences.
  ///
  /// Parâmetros:
  /// - [idCliente]: UID do usuário proprietário da meta.
  /// - [metaId]: ID único da meta (se nulo ou vazio, gera um novo documento).
  /// - [titulo]: Nome da meta (ex: "Reserva de Emergência", "Viagem de Férias").
  /// - [valorObjetivo]: Meta financeira total a ser atingida.
  /// - [valorAtual]: Valor acumulado atualmente.
  /// - [categoria]: Categoria visual da meta.
  Future<bool> salvarMeta({
    required String idCliente,
    String? metaId,
    required String titulo,
    required double valorObjetivo,
    required double valorAtual,
    String categoria = 'Geral',
  }) async {
    final bool concluida = valorAtual >= valorObjetivo;

    // 1. Interceptação pelo Modo Debug de dados simulados
    if (DebugMockService.instance.modoMockAtivo) {
      final String idFinal = (metaId != null && metaId.isNotEmpty)
          ? metaId
          : 'mock_meta_${DateTime.now().millisecondsSinceEpoch}';
      DebugMockService.instance.salvarMetaMock(
        id: idFinal,
        titulo: titulo,
        valorObjetivo: valorObjetivo,
        valorAtual: valorAtual,
        categoria: categoria,
      );
      return true;
    }

    // Identifica o identificador do cliente com alta fidelidade (prioriza Firebase Auth)
    final String uidAuth = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String idClienteResolvido = uidAuth.isNotEmpty
        ? uidAuth
        : (idCliente.trim().isNotEmpty ? idCliente.trim() : idClienteAtual);

    final docRef = (metaId != null &&
            metaId.isNotEmpty &&
            !metaId.startsWith('mock_'))
        ? _db.collection(_colecaoMetas).doc(metaId)
        : _db.collection(_colecaoMetas).doc();
    final String generatedId = docRef.id;

    // Remove da lista de excluídos recentemente se estiver sendo recriado
    _metasExcluidasRecentemente.remove(generatedId);

    final dadosMeta = <String, dynamic>{
      'firestore_id': generatedId,
      'id': generatedId,
      'id_cliente': idClienteResolvido,
      'titulo': titulo,
      'valor_objetivo': valorObjetivo,
      'valor_meta': valorObjetivo,
      'valor_atual': valorAtual,
      'valor_base': valorAtual,
      'categoria': categoria,
      'concluida': concluida,
      'status': concluida ? 'concluida' : 'em_andamento',
      'synced_to_firestore': false,
      'criado_em_ms': DateTime.now().millisecondsSinceEpoch,
    };

    // Atualiza o cache local imediatamente para disponibilidade instantânea da UI
    final existingIndex = _cacheMetasLocal.indexWhere(
      (m) =>
          (m['firestore_id'] == generatedId || m['id'] == generatedId) &&
          (m['id_cliente'] == idClienteResolvido ||
              m['id_cliente'] == null ||
              m['id_cliente'] == 'guest'),
    );
    if (existingIndex >= 0) {
      _cacheMetasLocal[existingIndex] = dadosMeta;
    } else {
      _cacheMetasLocal.insert(0, dadosMeta);
    }

    // Persiste no SharedPreferences e notifica a interface imediatamente
    await _salvarMetasEmCache(idClienteResolvido);
    _notificarAtualizacaoMetas(idClienteResolvido);

    try {
      final Map<String, dynamic> firestorePayload = Map<String, dynamic>.from(dadosMeta)
        ..remove('firestore_id')
        ..remove('synced_to_firestore');
      firestorePayload['atualizado_em'] = FieldValue.serverTimestamp();
      if (metaId == null || metaId.isEmpty) {
        firestorePayload['criado_em'] = FieldValue.serverTimestamp();
      }

      // Grava no Firestore na coleção principal 'metas_financeiras'
      await docRef.set(firestorePayload, SetOptions(merge: true));

      // Espelha na coleção secundária 'metas' para compatibilidade total
      try {
        await _db.collection('metas').doc(generatedId).set(firestorePayload, SetOptions(merge: true));
      } catch (e2) {
        debugPrint('Aviso ao espelhar na coleção metas: $e2');
      }

      // Marca meta como sincronizada com sucesso
      dadosMeta['synced_to_firestore'] = true;
      final idx = _cacheMetasLocal.indexWhere((m) => (m['firestore_id'] ?? m['id']) == generatedId);
      if (idx >= 0) {
        _cacheMetasLocal[idx]['synced_to_firestore'] = true;
      }
      await _salvarMetasEmCache(idClienteResolvido);
      debugPrint('Meta $generatedId salva com sucesso no Cloud Firestore!');
      return true;
    } catch (e, stack) {
      debugPrint('Aviso ao salvar meta no Firestore (mantida no cache local persistente): $e\n$stack');
      return true;
    }
  }

  /// Adiciona um valor financeiro (aporte) a uma meta existente.
  ///
  /// Parâmetros:
  /// - [metaId]: ID do documento da meta no Firestore.
  /// - [valorAporte]: Quantia a ser somada ao saldo da meta.
  /// - [valorAtualAntigo]: Saldo atual antes do aporte.
  /// - [valorObjetivo]: Meta final para recalcular o status de conclusão.
  /// - [idCliente]: UID do usuário proprietário da meta.
  Future<bool> aportarMeta({
    required String metaId,
    required double valorAporte,
    required double valorAtualAntigo,
    required double valorObjetivo,
    String? idCliente,
  }) async {
    final String uid = idCliente ?? idClienteAtual;
    if (DebugMockService.instance.modoMockAtivo) {
      DebugMockService.instance.aportarMetaMock(
        id: metaId,
        valorAporte: valorAporte,
      );
      return true;
    }

    final double novoValorAtual = valorAtualAntigo + valorAporte;
    final bool concluida = novoValorAtual >= valorObjetivo;

    // Atualiza o cache em memória
    final index = _cacheMetasLocal.indexWhere(
      (m) => m['firestore_id'] == metaId || m['id'] == metaId,
    );
    if (index >= 0) {
      _cacheMetasLocal[index]['valor_atual'] = novoValorAtual;
      _cacheMetasLocal[index]['concluida'] = concluida;
      _cacheMetasLocal[index]['status'] =
          concluida ? 'concluida' : 'em_andamento';
    }

    await _salvarMetasEmCache(uid);
    _notificarAtualizacaoMetas(uid);

    try {
      final updateData = {
        'valor_atual': novoValorAtual,
        'concluida': concluida,
        'status': concluida ? 'concluida' : 'em_andamento',
        'atualizado_em': FieldValue.serverTimestamp(),
      };
      await _db.collection(_colecaoMetas).doc(metaId).update(updateData);
      try {
        await _db.collection('metas').doc(metaId).update(updateData);
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('Aviso: Aporte atualizado no cache local: $e');
      return true;
    }
  }

  /// Exclui uma meta financeira pelo seu ID no Firestore, cache local e SharedPreferences.
  ///
  /// Parâmetros:
  /// - [metaId]: Identificador único da meta a ser removida.
  /// - [idCliente]: UID opcional do usuário.
  Future<bool> excluirMeta(String metaId, {String? idCliente}) async {
    final String uid = idCliente ?? idClienteAtual;
    if (DebugMockService.instance.modoMockAtivo) {
      DebugMockService.instance.excluirMetaMock(metaId);
      return true;
    }

    // Registra na lista de exclusão recente para evitar ressurgimento pelo snapshot
    _metasExcluidasRecentemente.add(metaId);

    _cacheMetasLocal
        .removeWhere((m) => m['firestore_id'] == metaId || m['id'] == metaId);
    await _salvarMetasEmCache(uid);
    _notificarAtualizacaoMetas(uid);

    try {
      await _db.collection(_colecaoMetas).doc(metaId).delete();
      try {
        await _db.collection('metas').doc(metaId).delete();
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('Aviso: Meta removida do cache local: $e');
      return true;
    }
  }

  /// Retorna um [Stream] em tempo real com todas as metas financeiras do usuário.
  /// Incorpora persistência local com SharedPreferences, fallback offline e reconciliação não-destrutiva.
  ///
  /// Parâmetros:
  /// - [idCliente]: UID do usuário logado.
  Stream<List<Map<String, dynamic>>> buscarMetasStream(String idCliente) {
    // Interceptação pelo Modo Debug de dados fictícios
    if (DebugMockService.instance.modoMockAtivo) {
      return DebugMockService.instance.metasStream;
    }

    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? firestoreSub;
    StreamSubscription? localSub;

    final String uidAuth = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String uidBusca = uidAuth.isNotEmpty ? uidAuth : idCliente;

    List<Map<String, dynamic>> obterListaAtual() {
      return _cacheMetasLocal
          .where((m) {
            final String id = (m['firestore_id'] ?? m['id'] ?? '').toString();
            if (_metasExcluidasRecentemente.contains(id)) return false;
            return m['id_cliente'] == idCliente ||
                m['id_cliente'] == uidBusca ||
                m['id_cliente'] == null ||
                m['id_cliente'] == 'guest';
          })
          .toList();
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () async {
        // 1. Tenta carregar do SharedPreferences se o cache em memória estiver vazio
        if (_cacheMetasLocal.where((m) => m['id_cliente'] == idCliente || m['id_cliente'] == uidBusca).isEmpty) {
          await carregarMetasDoCache(idCliente);
          if (uidBusca != idCliente) {
            await carregarMetasDoCache(uidBusca);
          }
        }
        if (!controller.isClosed) {
          controller.add(obterListaAtual());
        }

        // 2. Ouve notificações locais imediatas (criação, edição, exclusão e aportes)
        localSub = _metasStreamController.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(obterListaAtual());
          }
        });

        // 3. Ouve sincronização em tempo real do Cloud Firestore com reconciliação não-destrutiva
        try {
          firestoreSub = _db
              .collection(_colecaoMetas)
              .where('id_cliente', isEqualTo: uidBusca)
              .snapshots()
              .listen(
                (snapshot) {
                  final List<Map<String, dynamic>> metasRemotas =
                      snapshot.docs.map((doc) {
                    final data = Map<String, dynamic>.from(doc.data());
                    data['firestore_id'] = doc.id;
                    data['id'] = doc.id;
                    data['synced_to_firestore'] = true;
                    return data;
                  }).where((m) => !_metasExcluidasRecentemente.contains(m['id'])).toList();

                  // Reconciliação não-destrutiva (merge inteligente):
                  final Set<String> idsRemotos =
                      metasRemotas.map((m) => m['id'].toString()).toSet();
                  final int agoraMs = DateTime.now().millisecondsSinceEpoch;

                  // Preserva metas locais recém criadas que ainda não subiram ao Firestore
                  final List<Map<String, dynamic>> metasLocaisPreservadas =
                      _cacheMetasLocal.where((local) {
                    final String id =
                        (local['firestore_id'] ?? local['id'] ?? '').toString();
                    if (_metasExcluidasRecentemente.contains(id)) return false;
                    if (idsRemotos.contains(id)) return false;

                    final bool pertence = local['id_cliente'] == idCliente ||
                        local['id_cliente'] == uidBusca ||
                        local['id_cliente'] == null ||
                        local['id_cliente'] == 'guest';
                    if (!pertence) return false;

                    final bool synced = local['synced_to_firestore'] == true;
                    final int criadoMs =
                        (local['criado_em_ms'] as num?)?.toInt() ?? 0;
                    final bool recente = (agoraMs - criadoMs) < 300000; // 5 minutos de janela
                    return !synced || recente;
                  }).toList();

                  // Remove apenas as metas remotas obsoletas ou marcadas para exclusão
                  _cacheMetasLocal.removeWhere((c) {
                    final String id =
                        (c['firestore_id'] ?? c['id'] ?? '').toString();
                    final bool pertence = c['id_cliente'] == idCliente ||
                        c['id_cliente'] == uidBusca ||
                        c['id_cliente'] == null ||
                        c['id_cliente'] == 'guest';
                    return pertence &&
                        (idsRemotos.contains(id) ||
                            _metasExcluidasRecentemente.contains(id));
                  });

                  // Adiciona os dados remotos atualizados do servidor
                  _cacheMetasLocal.addAll(metasRemotas);

                  // Re-adiciona as metas locais protegidas para garantir que nunca sumam
                  for (final pendente in metasLocaisPreservadas) {
                    final String id =
                        (pendente['firestore_id'] ?? pendente['id'] ?? '').toString();
                    if (!_cacheMetasLocal.any((m) => (m['firestore_id'] ?? m['id']) == id)) {
                      _cacheMetasLocal.add(pendente);
                    }
                  }

                  _salvarMetasEmCache(idCliente);
                  if (uidBusca != idCliente) {
                    _salvarMetasEmCache(uidBusca);
                  }

                  if (!controller.isClosed) {
                    controller.add(obterListaAtual());
                  }

                  // Sincroniza em segundo plano quaisquer metas pendentes locais
                  if (metasLocaisPreservadas.isNotEmpty) {
                    _sincronizarMetasPendentesComFirestore(uidBusca);
                  }
                },
                onError: (error) {
                  debugPrint(
                    'Aviso ao ouvir metas no Firestore, utilizando cache local: $error',
                  );
                  if (!controller.isClosed) {
                    controller.add(obterListaAtual());
                  }
                },
              );
        } catch (e) {
          debugPrint('Erro ao iniciar stream de metas: $e');
        }
      },
      onCancel: () {
        firestoreSub?.cancel();
        localSub?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  // --- GESTÃO DE CARTÕES DE CRÉDITO ---

  /// Cartões de demonstração utilizados exclusivamente quando o Modo Mock está ativado.
  static final List<Map<String, dynamic>> _mockCartoesPadrao = [
    {
      'id': 'card_mock_1',
      'id_cliente': 'mock',
      'banco': 'COGITO Black',
      'bandeira': 'Mastercard',
      'ultimos_digitos': '8829',
      'numero': '•••• •••• •••• 8829',
      'limite_total': 15000.0,
      'limite_disponivel': 11450.0,
      'fatura_atual': 3550.0,
      'vencimento': 'Dia 15',
      'cor': '0xFF1E1E1E',
      'cor_final': '0xFF3A3A3A',
    },
    {
      'id': 'card_mock_2',
      'id_cliente': 'mock',
      'banco': 'COGITO Platinum',
      'bandeira': 'Visa',
      'ultimos_digitos': '4102',
      'numero': '•••• •••• •••• 4102',
      'limite_total': 8500.0,
      'limite_disponivel': 6300.0,
      'fatura_atual': 2200.0,
      'vencimento': 'Dia 20',
      'cor': '0xFF142251',
      'cor_final': '0xFF244288',
    },
    {
      'id': 'card_mock_3',
      'id_cliente': 'mock',
      'banco': 'COGITO Flex',
      'bandeira': 'Elo',
      'ultimos_digitos': '9031',
      'numero': '•••• •••• •••• 9031',
      'limite_total': 5000.0,
      'limite_disponivel': 4120.0,
      'fatura_atual': 880.0,
      'vencimento': 'Dia 05',
      'cor': '0xFFF5891D',
      'cor_final': '0xFFFCAA17',
    },
  ];

  /// Cache local para persistência e fallback imediato de cartões reais em memória.
  static final List<Map<String, dynamic>> _cacheCartoesLocal = [];

  /// Controlador reativo para emissão imediata de atualizações nos cartões de crédito.
  static final StreamController<List<Map<String, dynamic>>>
  _cartoesStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  /// Cadastra um novo cartão de crédito para o cliente no Firestore e no cache local.
  ///
  /// Parâmetros:
  /// - [idCliente]: Identificador do usuário proprietário do cartão.
  /// - [banco]: Instituição financeira emissora (ex: Nubank, Itaú, COGITO Black).
  /// - [bandeira]: Bandeira do cartão (ex: Mastercard, Visa, Elo).
  /// - [ultimosDigitos]: Últimos 4 dígitos para exibição segura.
  /// - [limiteTotal]: Limite de crédito concedido total.
  /// - [faturaAtual]: Valor da fatura em aberto atualmente.
  /// - [vencimento]: Dia ou data de vencimento da fatura.
  /// - [validade]: Data de expiração no formato MM/AA. Se omitido, calcula 5 anos à frente.
  /// - [titular]: Nome do titular impresso no cartão.
  /// - [numero]: Número formatado completo ou mascarado do cartão.
  /// - [cor]: Cor primária em formato hexadecimal (String).
  /// - [corFinal]: Cor de gradiente secundária opcional.
  ///
  /// Retorno:
  /// - [Future<bool>]: Verdadeiro se cadastrado com sucesso.
  Future<bool> salvarCartao({
    required String idCliente,
    required String banco,
    required String bandeira,
    required String ultimosDigitos,
    required double limiteTotal,
    required double faturaAtual,
    required String vencimento,
    String? validade,
    String? titular,
    String? numero,
    String cor = '0xFF142251',
    String corFinal = '0xFF244288',
  }) async {
    final double limiteDisponivel = (limiteTotal - faturaAtual).clamp(
      0.0,
      limiteTotal,
    );
    final String digitosLimpos = ultimosDigitos.replaceAll(RegExp(r'\D'), '');
    final String digitosFinais = digitosLimpos.length >= 4
        ? digitosLimpos.substring(digitosLimpos.length - 4)
        : digitosLimpos.padLeft(4, '0');

    final String cartaoId = 'card_${DateTime.now().millisecondsSinceEpoch}';

    // Determina a validade correta: se foi informada pelo usuário, usa ela; senão calcula 5 anos à frente (MM/AA)
    final String validadeFinal = (validade != null && validade.trim().isNotEmpty)
        ? validade.trim()
        : '${DateTime.now().month.toString().padLeft(2, '0')}/${(DateTime.now().year + 5).toString().substring(2)}';

    final String titularFinal = (titular != null && titular.trim().isNotEmpty)
        ? titular.trim().toUpperCase()
        : 'TITULAR';

    final String numeroFinal = (numero != null && numero.trim().isNotEmpty)
        ? numero.trim()
        : '•••• •••• •••• $digitosFinais';

    final Map<String, dynamic> dados = {
      'id': cartaoId,
      'firestore_id': cartaoId,
      'id_cliente': idCliente,
      'banco': banco,
      'bandeira': bandeira,
      'titular': titularFinal,
      'ultimos_digitos': digitosFinais,
      'numero': numeroFinal,
      'validade': validadeFinal,
      'limite_total': limiteTotal,
      'limite_disponivel': limiteDisponivel,
      'fatura_atual': faturaAtual,
      'vencimento': vencimento,
      'cor': cor,
      'cor_final': corFinal,
      'criado_em': FieldValue.serverTimestamp(),
    };

    // 1. Salva imediatamente no cache local em memória e emite aos ouvintes
    _cacheCartoesLocal.removeWhere((c) => c['id'] == cartaoId || c['firestore_id'] == cartaoId);
    _cacheCartoesLocal.insert(0, dados);
    _cartoesStreamController.add(List.from(_cacheCartoesLocal));

    // 2. Tenta persistir no Cloud Firestore na coleção 'cartoes'
    try {
      final payload = Map<String, dynamic>.from(dados);
      await _db.collection(_colecaoCartoes).doc(cartaoId).set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Aviso: Armazenando cartão em sessão local offline: $e');
    }

    return true;
  }

  /// Retorna o fluxo reativo (Stream) dos cartões cadastrados pelo cliente.
  /// Emite os dados em cache de forma síncrona/imediata e ouve alterações do Firestore e do aplicativo.
  ///
  /// Parâmetros:
  /// - [idCliente]: UID do usuário ativo.
  ///
  /// Retorno:
  /// - [Stream<List<Map<String, dynamic>>>]: Lista em tempo real de cartões.
  Stream<List<Map<String, dynamic>>> buscarCartoesStream(
    String idCliente,
  ) async* {
    List<Map<String, dynamic>> filtrarParaCliente(
      List<Map<String, dynamic>> lista,
    ) {
      if (DebugMockService.instance.modoMockAtivo) {
        return _mockCartoesPadrao;
      }
      return lista
          .where((c) => c['id_cliente'] == idCliente)
          .toList();
    }

    // Emissão imediata do estado de cache para resposta instantânea na UI
    yield filtrarParaCliente(_cacheCartoesLocal);

    final controller = StreamController<List<Map<String, dynamic>>>();

    // Ouve notificações geradas por ações do usuário (salvar / remover)
    final subLocal = _cartoesStreamController.stream.listen((lista) {
      if (!controller.isClosed) {
        controller.add(filtrarParaCliente(lista));
      }
    });

    // Ouve snapshots em tempo real do Cloud Firestore
    StreamSubscription? subFirestore;
    try {
      subFirestore = _db
          .collection(_colecaoCartoes)
          .where('id_cliente', isEqualTo: idCliente)
          .snapshots()
          .listen(
            (snapshot) {
              final List<Map<String, dynamic>> cartoesFirestore = snapshot.docs
                  .map((doc) {
                    final data = doc.data();
                    data['id'] = doc.id;
                    return data;
                  })
                  .toList();

              // Substitui o cache local deste cliente pela lista real do Firestore
              _cacheCartoesLocal.removeWhere((c) => c['id_cliente'] == idCliente);
              _cacheCartoesLocal.addAll(cartoesFirestore);
              if (!controller.isClosed) {
                controller.add(filtrarParaCliente(_cacheCartoesLocal));
              }
            },
            onError: (e) {
              debugPrint('Aviso ao sincronizar cartões no Firestore: $e');
              if (!controller.isClosed) {
                controller.add(filtrarParaCliente(_cacheCartoesLocal));
              }
            },
          );
    } catch (e) {
      debugPrint('Erro ao iniciar stream de cartões no Firestore: $e');
    }

    try {
      yield* controller.stream;
    } finally {
      await subLocal.cancel();
      await subFirestore?.cancel();
      await controller.close();
    }
  }

  /// Remove um cartão de crédito cadastrado pelo ID.
  ///
  /// Parâmetros:
  /// - [cartaoId]: Identificador único do documento do cartão.
  ///
  /// Retorno:
  /// - [Future<bool>]: Confirmação de exclusão.
  Future<bool> removerCartao(String cartaoId) async {
    _cacheCartoesLocal.removeWhere((c) => c['id'] == cartaoId);
    _cartoesStreamController.add(List.from(_cacheCartoesLocal));

    try {
      await _db.collection(_colecaoCartoes).doc(cartaoId).delete();
    } catch (e) {
      debugPrint('Aviso ao remover cartão no Firestore: $e');
    }
    return true;
  }
}
