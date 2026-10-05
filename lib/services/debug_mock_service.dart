import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Serviço responsável pelo gerenciamento de Dados Fictícios (Mock) para fins de depuração (Debug).
///
/// Permite alternar o aplicativo entre o modo real (conectado ao Firebase) e o modo simulado,
/// preenchendo automaticamente todas as telas do aplicativo com dados realistas de:
/// - Dashboard (Resumo, saldos, gráficos, transações recentes, contas e metas)
/// - Finanças e Análise Detalhada (Receitas, despesas, gráficos de evolução por categoria)
/// - Contas bancárias conectadas com saldos
/// - Metas financeiras com porcentagens e barras de progresso
/// - Notificações do sistema
/// - Sessões de chats salvos com o CONRADO
/// - Dados de perfil do usuário e plano ativo
class DebugMockService {
  /// Instância singleton para acesso global em qualquer ponto da aplicação.
  static final DebugMockService instance = DebugMockService._internal();

  DebugMockService._internal();

  /// Notificador reativo de estado do Modo Mock (permite que a interface atualize imediatamente).
  final ValueNotifier<bool> modoMockAtivoNotifier = ValueNotifier<bool>(false);

  /// Retorna se o Modo Mock de dados falsos está atualmente ativado.
  bool get modoMockAtivo => modoMockAtivoNotifier.value;

  /// Alterna o estado do modo de dados fictícios (Ligar/Desligar).
  void alternarModoMock() {
    setModoMock(!modoMockAtivoNotifier.value);
  }

  /// Define explicitamente se o modo de dados fictícios deve ser ativado ou desativado.
  /// Notifica também os controladores de streams de dados simulados.
  ///
  /// Parâmetros:
  /// - [ativo]: `true` para preencher o app com dados falsos, `false` para usar dados reais.
  void setModoMock(bool ativo) {
    if (modoMockAtivoNotifier.value != ativo) {
      modoMockAtivoNotifier.value = ativo;
      _transacoesMockStreamController.add(List.from(_transacoesMockList));
      _sessoesChatMockStreamController.add(List.from(_sessoesChatMockList));
      _orcamentosMockStreamController.add(List.from(_orcamentosMock));
      _metasMockStreamController.add(List.from(_metasMockList));
    }
  }

  // =========================================================================
  // DADOS FICTÍCIOS DE PERFIL E USUÁRIO
  // =========================================================================

  /// Retorna os dados fictícios do usuário logado no aplicativo.
  Map<String, dynamic> get usuarioMock => {
        'uid': 'mock_user_123',
        'id_cliente': 'mock_user_123',
        'nome': 'Lucas Mendes Ferreira',
        'email': 'lucas.mendes@cogito.app',
        'telefone': '(11) 98765-4321',
        'idade': 24,
        'tipo_renda': 'Salario_Fixo',
        'renda_mensal': 2200.0,
        'plano': 'Freelancer',
        'status_conta': 'Ativa',
        'criado_em': Timestamp.now(),
        'ultimo_acesso': Timestamp.now(),
      };

  // =========================================================================
  // DADOS FICTÍCIOS DO RESUMO FINANCEIRO
  // =========================================================================

  /// Retorna o resumo consolidado de saldos, receitas e despesas simuladas com valores moderados.
  Map<String, dynamic> get resumoFinanceiroMock => {
        'saldo_total': 1460.50,
        'receitas': 1850.00,
        'despesas': 620.40,
        'investimentos': 280.00,
      };

  // =========================================================================
  // DADOS FICTÍCIOS DE CONTAS BANCÁRIAS
  // =========================================================================

  /// Retorna a lista simulada de contas bancárias vinculadas com saldos equilibrados e realistas.
  List<Map<String, dynamic>> get contasBancariasMock => [
        {
          'id': 'conta_nubank',
          'firestore_id': 'conta_nubank',
          'id_cliente': 'mock_user_123',
          'instituicao': 'Nubank',
          'nome_banco': 'Nubank',
          'tipo_conta': 'Conta Corrente & Reserva',
          'saldo': 720.50,
          'cor_hex': '0xFF8A05BE',
          'numero_conta': '**** 4892',
          'nome_titular': 'Lucas Mendes Ferreira',
        },
        {
          'id': 'conta_itau',
          'firestore_id': 'conta_itau',
          'id_cliente': 'mock_user_123',
          'instituicao': 'Itaú Unibanco',
          'nome_banco': 'Itaú Unibanco',
          'tipo_conta': 'Conta Principal',
          'saldo': 490.00,
          'cor_hex': '0xFFEC7000',
          'numero_conta': '**** 1058',
          'nome_titular': 'Lucas Mendes Ferreira',
        },
        {
          'id': 'conta_inter',
          'firestore_id': 'conta_inter',
          'id_cliente': 'mock_user_123',
          'instituicao': 'Banco Inter',
          'nome_banco': 'Banco Inter',
          'tipo_conta': 'Investimentos',
          'saldo': 250.00,
          'cor_hex': '0xFFFF7A00',
          'numero_conta': '**** 9931',
          'nome_titular': 'Lucas Mendes Ferreira',
        },
      ];

  /// Stream reativo emitindo as contas bancárias simuladas.
  Stream<List<Map<String, dynamic>>> get contasBancariasStream =>
      Stream.value(contasBancariasMock);

  // =========================================================================
  // DADOS FICTÍCIOS DE TRANSAÇÕES FINANCEIRAS
  // =========================================================================

  /// Função auxiliar interna para gerar datas retroativas seguras com base em meses anteriores.
  static DateTime _calcularDataMesAnterior(
    DateTime ref,
    int mesesAtras,
    int dia, {
    int hora = 14,
    int minuto = 30,
  }) {
    int ano = ref.year;
    int mes = ref.month - mesesAtras;
    while (mes <= 0) {
      mes += 12;
      ano -= 1;
    }
    final int diasNoMes = DateTime(ano, mes + 1, 0).day;
    final int diaValido = dia > diasNoMes ? diasNoMes : (dia < 1 ? 1 : dia);
    return DateTime(ano, mes, diaValido, hora, minuto);
  }

  /// Cache mutável das transações simuladas em memória.
  late final List<Map<String, dynamic>> _transacoesMockList =
      _gerarTransacoesIniciais();

  /// Controller broadcast para notificar ouvintes sobre alterações nas transações mock.
  final StreamController<List<Map<String, dynamic>>>
      _transacoesMockStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  /// Retorna as transações simuladas do modo mock.
  List<Map<String, dynamic>> get transacoesMock =>
      List.unmodifiable(_transacoesMockList);

  /// Gera a lista inicial de transações financeiras diversificadas, com valores realistas e moderados,
  /// distribuídas estrategicamente ao longo de vários períodos (este mês, mês passado, últimos 3 meses,
  /// este ano e histórico geral) para validar relatórios e filtros de data com dados distintos.
  static List<Map<String, dynamic>> _gerarTransacoesIniciais() {
    final agora = DateTime.now();

    // Datas calculadas de meses anteriores para períodos distintos
    final dtMesPassado1 = _calcularDataMesAnterior(agora, 1, 5, hora: 10);
    final dtMesPassado2 = _calcularDataMesAnterior(agora, 1, 10, hora: 12);
    final dtMesPassado3 = _calcularDataMesAnterior(agora, 1, 14, hora: 15);
    final dtMesPassado4 = _calcularDataMesAnterior(agora, 1, 19, hora: 17);
    final dtMesPassado5 = _calcularDataMesAnterior(agora, 1, 24, hora: 19);

    final dtDoisMeses1 = _calcularDataMesAnterior(agora, 2, 7, hora: 10);
    final dtDoisMeses2 = _calcularDataMesAnterior(agora, 2, 15, hora: 14);
    final dtDoisMeses3 = _calcularDataMesAnterior(agora, 2, 23, hora: 18);

    final dtTresMeses1 = _calcularDataMesAnterior(agora, 3, 6, hora: 9);
    final dtTresMeses2 = _calcularDataMesAnterior(agora, 3, 17, hora: 14);
    final dtTresMeses3 = _calcularDataMesAnterior(agora, 3, 22, hora: 16);

    final dtCincoMeses1 = _calcularDataMesAnterior(agora, 5, 10, hora: 11);
    final dtCincoMeses2 = _calcularDataMesAnterior(agora, 5, 20, hora: 16);

    final dtAnoPassado = DateTime(agora.year - 1, 11, 18, 14, 0);

    return [
      // -----------------------------------------------------------------------
      // TRANSAÇÕES DESTE MÊS (MÊS ATUAL) - Valores alinhados ao planejamento
      // -----------------------------------------------------------------------
      {
        'id': 'tx_1',
        'firestore_id': 'tx_1',
        'id_cliente': 'mock_user_123',
        'titulo': 'Salário Base Mensal',
        'descricao': 'Depósito mensal de rendimento',
        'valor': 2500.00,
        'tipo': 'Receita',
        'categoria': 'Salário',
        'data': Timestamp.fromDate(DateTime(agora.year, agora.month, 5, 10, 0)),
        'data_dt': DateTime(agora.year, agora.month, 5, 10, 0),
        'status': 'concluida',
        'banco': 'Itaú Unibanco',
      },
      {
        'id': 'tx_moradia_1',
        'firestore_id': 'tx_moradia_1',
        'id_cliente': 'mock_user_123',
        'titulo': 'Aluguel e Condomínio',
        'descricao': 'Pagamento mensal de moradia',
        'valor': 980.00,
        'tipo': 'Despesa',
        'categoria': 'Moradia',
        'data': Timestamp.fromDate(DateTime(agora.year, agora.month, 10, 14, 0)),
        'data_dt': DateTime(agora.year, agora.month, 10, 14, 0),
        'status': 'concluida',
        'banco': 'Nubank',
      },
      {
        'id': 'tx_moradia_2',
        'firestore_id': 'tx_moradia_2',
        'id_cliente': 'mock_user_123',
        'titulo': 'Energia e Internet',
        'descricao': 'Contas de consumo residenciais',
        'valor': 200.00,
        'tipo': 'Despesa',
        'categoria': 'Moradia',
        'data': Timestamp.fromDate(DateTime(agora.year, agora.month, 15, 11, 30)),
        'data_dt': DateTime(agora.year, agora.month, 15, 11, 30),
        'status': 'concluida',
        'banco': 'Nubank',
      },
      {
        'id': 'tx_alim_1',
        'firestore_id': 'tx_alim_1',
        'id_cliente': 'mock_user_123',
        'titulo': 'Supermercado da Praça',
        'descricao': 'Compras essenciais do mês',
        'valor': 450.00,
        'tipo': 'Despesa',
        'categoria': 'Alimentação',
        'data': Timestamp.fromDate(DateTime(agora.year, agora.month, (agora.day - 1).clamp(1, 28), 12, 0)),
        'data_dt': DateTime(agora.year, agora.month, (agora.day - 1).clamp(1, 28), 12, 0),
        'status': 'concluida',
        'banco': 'Nubank',
      },
      {
        'id': 'tx_alim_2',
        'firestore_id': 'tx_alim_2',
        'id_cliente': 'mock_user_123',
        'titulo': 'Restaurantes e Almoço',
        'descricao': 'Alimentação e refeições no dia a dia',
        'valor': 200.00,
        'tipo': 'Despesa',
        'categoria': 'Alimentação',
        'data': Timestamp.fromDate(agora.subtract(const Duration(hours: 3))),
        'data_dt': agora.subtract(const Duration(hours: 3)),
        'status': 'concluida',
        'banco': 'Nubank',
      },
      {
        'id': 'tx_transp_1',
        'firestore_id': 'tx_transp_1',
        'id_cliente': 'mock_user_123',
        'titulo': 'Posto Combustível e Transporte',
        'descricao': 'Deslocamento semanal e recarga',
        'valor': 250.00,
        'tipo': 'Despesa',
        'categoria': 'Transporte',
        'data': Timestamp.fromDate(DateTime(agora.year, agora.month, (agora.day - 2).clamp(1, 28), 16, 0)),
        'data_dt': DateTime(agora.year, agora.month, (agora.day - 2).clamp(1, 28), 16, 0),
        'status': 'concluida',
        'banco': 'Itaú Unibanco',
      },
      {
        'id': 'tx_lazer_1',
        'firestore_id': 'tx_lazer_1',
        'id_cliente': 'mock_user_123',
        'titulo': 'Cinema, Streaming e Lazer',
        'descricao': 'Assinaturas e lazer com amigos',
        'valor': 100.00,
        'tipo': 'Despesa',
        'categoria': 'Lazer',
        'data': Timestamp.fromDate(DateTime(agora.year, agora.month, (agora.day - 3).clamp(1, 28), 20, 0)),
        'data_dt': DateTime(agora.year, agora.month, (agora.day - 3).clamp(1, 28), 20, 0),
        'status': 'concluida',
        'banco': 'Nubank',
      },

      // -----------------------------------------------------------------------
      // TRANSAÇÕES DO MÊS PASSADO - Realistas e equilibradas
      // -----------------------------------------------------------------------
      {
        'id': 'tx_mp_1',
        'firestore_id': 'tx_mp_1',
        'id_cliente': 'mock_user_123',
        'titulo': 'Salário Base',
        'descricao': 'Salário mês anterior',
        'valor': 1400.00,
        'tipo': 'Receita',
        'categoria': 'Salário',
        'data': Timestamp.fromDate(dtMesPassado1),
        'data_dt': dtMesPassado1,
        'status': 'concluida',
        'banco': 'Itaú Unibanco',
      },
      {
        'id': 'tx_mp_2',
        'firestore_id': 'tx_mp_2',
        'id_cliente': 'mock_user_123',
        'titulo': 'Projeto Criação de Banner',
        'descricao': 'Projeto pontual de design',
        'valor': 350.00,
        'tipo': 'Receita',
        'categoria': 'Serviços',
        'data': Timestamp.fromDate(dtMesPassado2),
        'data_dt': dtMesPassado2,
        'status': 'concluida',
        'banco': 'Nubank',
      },
      {
        'id': 'tx_mp_3',
        'firestore_id': 'tx_mp_3',
        'id_cliente': 'mock_user_123',
        'titulo': 'Contribuição Moradia / Contas',
        'descricao': 'Luz, internet e despesas de casa',
        'valor': 420.00,
        'tipo': 'Despesa',
        'categoria': 'Moradia',
        'data': Timestamp.fromDate(dtMesPassado3),
        'data_dt': dtMesPassado3,
        'status': 'concluida',
        'banco': 'Itaú Unibanco',
      },
      {
        'id': 'tx_mp_4',
        'firestore_id': 'tx_mp_4',
        'id_cliente': 'mock_user_123',
        'titulo': 'Supermercado Mensal',
        'descricao': 'Compras do mês anterior',
        'valor': 185.40,
        'tipo': 'Despesa',
        'categoria': 'Alimentação',
        'data': Timestamp.fromDate(dtMesPassado4),
        'data_dt': dtMesPassado4,
        'status': 'concluida',
        'banco': 'Nubank',
      },
      {
        'id': 'tx_mp_5',
        'firestore_id': 'tx_mp_5',
        'id_cliente': 'mock_user_123',
        'titulo': 'Transporte / Aplicativo',
        'descricao': 'Corridas de deslocamento',
        'valor': 62.00,
        'tipo': 'Despesa',
        'categoria': 'Transporte',
        'data': Timestamp.fromDate(dtMesPassado5),
        'data_dt': dtMesPassado5,
        'status': 'concluida',
        'banco': 'Itaú Unibanco',
      },

      // -----------------------------------------------------------------------
      // TRANSAÇÕES DE 2 MESES ATRÁS
      // -----------------------------------------------------------------------
      {
        'id': 'tx_2m_1',
        'firestore_id': 'tx_2m_1',
        'id_cliente': 'mock_user_123',
        'titulo': 'Salário Base',
        'descricao': 'Salário regular',
        'valor': 1400.00,
        'tipo': 'Receita',
        'categoria': 'Salário',
        'data': Timestamp.fromDate(dtDoisMeses1),
        'data_dt': dtDoisMeses1,
        'status': 'concluida',
        'banco': 'Itaú Unibanco',
      },
      {
        'id': 'tx_2m_2',
        'firestore_id': 'tx_2m_2',
        'id_cliente': 'mock_user_123',
        'titulo': 'Supermercado Econômico',
        'descricao': 'Mantimentos da quinzena',
        'valor': 165.00,
        'tipo': 'Despesa',
        'categoria': 'Alimentação',
        'data': Timestamp.fromDate(dtDoisMeses2),
        'data_dt': dtDoisMeses2,
        'status': 'concluida',
        'banco': 'Nubank',
      },
      {
        'id': 'tx_2m_3',
        'firestore_id': 'tx_2m_3',
        'id_cliente': 'mock_user_123',
        'titulo': 'Curso Online de Flutter',
        'descricao': 'Material de estudo promocional',
        'valor': 49.90,
        'tipo': 'Despesa',
        'categoria': 'Educação',
        'data': Timestamp.fromDate(dtDoisMeses3),
        'data_dt': dtDoisMeses3,
        'status': 'concluida',
        'banco': 'Nubank',
      },

      // -----------------------------------------------------------------------
      // TRANSAÇÕES DE 3 MESES ATRÁS
      // -----------------------------------------------------------------------
      {
        'id': 'tx_3m_1',
        'firestore_id': 'tx_3m_1',
        'id_cliente': 'mock_user_123',
        'titulo': 'Salário Base',
        'descricao': 'Salário regular',
        'valor': 1400.00,
        'tipo': 'Receita',
        'categoria': 'Salário',
        'data': Timestamp.fromDate(dtTresMeses1),
        'data_dt': dtTresMeses1,
        'status': 'concluida',
        'banco': 'Itaú Unibanco',
      },
      {
        'id': 'tx_3m_2',
        'firestore_id': 'tx_3m_2',
        'id_cliente': 'mock_user_123',
        'titulo': 'Supermercado Básico',
        'descricao': 'Alimentação essencial',
        'valor': 152.00,
        'tipo': 'Despesa',
        'categoria': 'Alimentação',
        'data': Timestamp.fromDate(dtTresMeses2),
        'data_dt': dtTresMeses2,
        'status': 'concluida',
        'banco': 'Nubank',
      },
      {
        'id': 'tx_3m_3',
        'firestore_id': 'tx_3m_3',
        'id_cliente': 'mock_user_123',
        'titulo': 'Farmácia e Vitaminas',
        'descricao': 'Cuidados pessoais',
        'valor': 32.50,
        'tipo': 'Despesa',
        'categoria': 'Saúde & Bem-estar',
        'data': Timestamp.fromDate(dtTresMeses3),
        'data_dt': dtTresMeses3,
        'status': 'concluida',
        'banco': 'Nubank',
      },

      // -----------------------------------------------------------------------
      // TRANSAÇÕES ANTERIORES DESTE ANO (5 MESES ATRÁS)
      // -----------------------------------------------------------------------
      {
        'id': 'tx_5m_1',
        'firestore_id': 'tx_5m_1',
        'id_cliente': 'mock_user_123',
        'titulo': 'Renda Extra / Bônus Pontual',
        'descricao': 'Reconhecimento por meta batida',
        'valor': 260.00,
        'tipo': 'Receita',
        'categoria': 'Salário',
        'data': Timestamp.fromDate(dtCincoMeses1),
        'data_dt': dtCincoMeses1,
        'status': 'concluida',
        'banco': 'Itaú Unibanco',
      },
      {
        'id': 'tx_5m_2',
        'firestore_id': 'tx_5m_2',
        'id_cliente': 'mock_user_123',
        'titulo': 'Fone de Ouvido para Trabalho',
        'descricao': 'Acessório de produtividade',
        'valor': 89.00,
        'tipo': 'Despesa',
        'categoria': 'Trabalho',
        'data': Timestamp.fromDate(dtCincoMeses2),
        'data_dt': dtCincoMeses2,
        'status': 'concluida',
        'banco': 'Nubank',
      },

      // -----------------------------------------------------------------------
      // TRANSAÇÃO DO ANO PASSADO (TODO O PERÍODO)
      // -----------------------------------------------------------------------
      {
        'id': 'tx_ano_passado_1',
        'firestore_id': 'tx_ano_passado_1',
        'id_cliente': 'mock_user_123',
        'titulo': 'Salário Ano Anterior',
        'descricao': 'Histórico consolidado',
        'valor': 1320.00,
        'tipo': 'Receita',
        'categoria': 'Salário',
        'data': Timestamp.fromDate(dtAnoPassado),
        'data_dt': dtAnoPassado,
        'status': 'concluida',
        'banco': 'Itaú Unibanco',
      },
    ];
  }

  /// Stream reativo das transações simuladas com emissão inicial imediata.
  Stream<List<Map<String, dynamic>>> get transacoesStream {
    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? sub;

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        controller.add(List.from(_transacoesMockList));
        sub = _transacoesMockStreamController.stream.listen((lista) {
          if (!controller.isClosed) {
            controller.add(List.from(lista));
          }
        });
      },
      onCancel: () {
        sub?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  /// Adiciona ou atualiza uma transação na sessão mock.
  void salvarTransacaoMock(Map<String, dynamic> transacao) {
    final String id = transacao['firestore_id'] ??
        transacao['id'] ??
        'mock_${DateTime.now().millisecondsSinceEpoch}';
    transacao['id'] = id;
    transacao['firestore_id'] = id;
    final idx = _transacoesMockList
        .indexWhere((t) => t['id'] == id || t['firestore_id'] == id);
    if (idx >= 0) {
      _transacoesMockList[idx] = transacao;
    } else {
      _transacoesMockList.insert(0, transacao);
    }
    _transacoesMockStreamController.add(List.from(_transacoesMockList));
  }

  /// Remove uma transação mock pelo seu identificador.
  void excluirTransacaoMock(String id) {
    _transacoesMockList
        .removeWhere((t) => t['id'] == id || t['firestore_id'] == id);
    _transacoesMockStreamController.add(List.from(_transacoesMockList));
  }

  // =========================================================================
  // DADOS FICTÍCIOS DE ORÇAMENTOS POR CATEGORIA (LIMITES MODERADOS)
  // =========================================================================

  /// Cache em memória dos orçamentos fictícios configurados com limites realistas e categorias completas.
  final List<Map<String, dynamic>> _orcamentosMock = [
    {
      'id': 'mock_user_123_Geral',
      'id_cliente': 'mock_user_123',
      'nome': 'Orçamento Global Mensal',
      'categoria': 'Geral',
      'limite': 4200.00,
    },
    {
      'id': 'mock_user_123_Alimentacao',
      'id_cliente': 'mock_user_123',
      'nome': 'Mercado e Refeições',
      'categoria': 'Alimentação',
      'limite': 1200.00,
    },
    {
      'id': 'mock_user_123_Moradia',
      'id_cliente': 'mock_user_123',
      'nome': 'Moradia e Contas da Casa',
      'categoria': 'Moradia',
      'limite': 1800.00,
    },
    {
      'id': 'mock_user_123_Transporte',
      'id_cliente': 'mock_user_123',
      'nome': 'Combustível e Mobilidade',
      'categoria': 'Transporte',
      'limite': 500.00,
    },
    {
      'id': 'mock_user_123_Lazer',
      'id_cliente': 'mock_user_123',
      'nome': 'Lazer e Restaurantes',
      'categoria': 'Lazer',
      'limite': 400.00,
    },
    {
      'id': 'mock_user_123_Saude',
      'id_cliente': 'mock_user_123',
      'nome': 'Farmácia e Cuidados Pessoais',
      'categoria': 'Saúde',
      'limite': 300.00,
    },
  ];

  /// Notificador reativo de orçamentos simulados via broadcast stream.
  final StreamController<List<Map<String, dynamic>>>
      _orcamentosMockStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  /// Retorna a lista atual de orçamentos simulados em formato imutável.
  List<Map<String, dynamic>> get orcamentosMock =>
      List.unmodifiable(_orcamentosMock);

  /// Stream reativo de orçamentos simulados com emissão inicial imediata.
  Stream<List<Map<String, dynamic>>> get orcamentosStream {
    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? sub;

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        // Emite imediatamente o estado atual da lista de orçamentos simulados
        controller.add(List.from(_orcamentosMock));

        // Escuta atualizações subsequentes decorrentes de novo cadastro ou edição
        sub = _orcamentosMockStreamController.stream.listen((lista) {
          if (!controller.isClosed) {
            controller.add(List.from(lista));
          }
        });
      },
      onCancel: () {
        sub?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  /// Salva ou atualiza um orçamento fictício na sessão de dados simulados (Mock).
  /// Salva ou atualiza um orçamento na lista simulada.
  /// Suporta especificação de tipo ('Despesa' ou 'Receita') para diferenciar limites de gastos de fontes de renda.
  void salvarOrcamentoMock({
    String? id,
    String? categoria,
    required double limite,
    required String nome,
    String? tipo,
  }) {
    final String nomeFinal =
        nome.trim().isNotEmpty ? nome.trim() : 'Orçamento Geral';
    final String idAlvo = id ??
        'mock_user_123_${nomeFinal.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
    final idx = _orcamentosMock
        .indexWhere((o) => o['id'] == idAlvo || o['nome'] == nomeFinal);

    final item = {
      'id': idAlvo,
      'id_cliente': 'mock_user_123',
      'nome': nomeFinal,
      'categoria': categoria ?? 'Geral',
      'limite': limite,
      'tipo': tipo ?? 'Despesa',
    };
    if (idx >= 0) {
      _orcamentosMock[idx] = item;
    } else {
      _orcamentosMock.add(item);
    }
    _orcamentosMockStreamController.add(List.from(_orcamentosMock));
  }

  /// Exclui um orçamento fictício na sessão de dados simulados (Mock).
  /// Permite exclusão por id, nome ou categoria.
  void excluirOrcamentoMock({
    String? categoria,
    String? id,
    String? nome,
  }) {
    _orcamentosMock.removeWhere((o) =>
        (id != null && o['id'] == id) ||
        (categoria != null && o['categoria'] == categoria) ||
        (nome != null && o['nome'] == nome));
    _orcamentosMockStreamController.add(List.from(_orcamentosMock));
  }

  // =========================================================================
  // DADOS FICTÍCIOS DE METAS FINANCEIRAS (VALORES ALCANÇÁVEIS E REATIVOS)
  // =========================================================================

  /// Cache mutável em memória das metas simuladas para permitir adição, edição e aportes em tempo real.
  late final List<Map<String, dynamic>> _metasMockList =
      _gerarMetasIniciais();

  /// StreamController Broadcast para notificação de atualizações instantâneas de metas simuladas.
  final StreamController<List<Map<String, dynamic>>>
      _metasMockStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  /// Gera a lista inicial de metas financeiras simuladas.
  static List<Map<String, dynamic>> _gerarMetasIniciais() {
    return [
      {
        'id': 'meta_reserva',
        'firestore_id': 'meta_reserva',
        'id_cliente': 'mock_user_123',
        'titulo': 'Reserva de Emergência',
        'valor_objetivo': 2000.00,
        'valor_meta': 2000.00,
        'valor_atual': 1100.00,
        'categoria': 'Segurança',
        'concluida': false,
        'status': 'em_andamento',
        'prazo': 'Dezembro 2026',
      },
      {
        'id': 'meta_viagem',
        'firestore_id': 'meta_viagem',
        'id_cliente': 'mock_user_123',
        'titulo': 'Passeio de Fim de Semana',
        'valor_objetivo': 800.00,
        'valor_meta': 800.00,
        'valor_atual': 420.00,
        'categoria': 'Lazer',
        'concluida': false,
        'status': 'em_andamento',
        'prazo': 'Novembro 2026',
      },
      {
        'id': 'meta_fone',
        'firestore_id': 'meta_fone',
        'id_cliente': 'mock_user_123',
        'titulo': 'Fone com Cancelamento de Ruído',
        'valor_objetivo': 400.00,
        'valor_meta': 400.00,
        'valor_atual': 240.00,
        'categoria': 'Trabalho',
        'concluida': false,
        'status': 'em_andamento',
        'prazo': 'Outubro 2026',
      },
    ];
  }

  /// Retorna a lista atual de metas financeiras simuladas em formato imutável.
  List<Map<String, dynamic>> get metasFinanceirasMock =>
      List.unmodifiable(_metasMockList);

  /// Stream reativo das metas simuladas com emissão imediata e suporte a alterações.
  Stream<List<Map<String, dynamic>>> get metasStream {
    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? sub;

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        controller.add(List.from(_metasMockList));
        sub = _metasMockStreamController.stream.listen((lista) {
          if (!controller.isClosed) {
            controller.add(List.from(lista));
          }
        });
      },
      onCancel: () {
        sub?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  /// Salva ou atualiza uma meta financeira no ambiente simulado (Mock).
  ///
  /// Parâmetros:
  /// - [id]: Identificador único da meta simulada.
  /// - [titulo]: Título descritivo da meta.
  /// - [valorObjetivo]: Valor total almejado.
  /// - [valorAtual]: Saldo guardado até o momento.
  /// - [categoria]: Categoria visual associada à meta.
  void salvarMetaMock({
    required String id,
    required String titulo,
    required double valorObjetivo,
    required double valorAtual,
    String categoria = 'Geral',
  }) {
    final bool concluida = valorAtual >= valorObjetivo;
    final item = {
      'id': id,
      'firestore_id': id,
      'id_cliente': 'mock_user_123',
      'titulo': titulo,
      'valor_objetivo': valorObjetivo,
      'valor_meta': valorObjetivo,
      'valor_atual': valorAtual,
      'categoria': categoria,
      'concluida': concluida,
      'status': concluida ? 'concluida' : 'em_andamento',
      'prazo': 'Meta Ativa',
    };

    final idx = _metasMockList.indexWhere(
      (m) => m['id'] == id || m['firestore_id'] == id,
    );
    if (idx >= 0) {
      _metasMockList[idx] = item;
    } else {
      _metasMockList.insert(0, item);
    }
    _metasMockStreamController.add(List.from(_metasMockList));
  }

  /// Adiciona um valor de aporte a uma meta simulada e recalcula sua conclusão.
  ///
  /// Parâmetros:
  /// - [id]: ID da meta que receberá o aporte financeiro.
  /// - [valorAporte]: Quantia a ser somada ao saldo atual.
  void aportarMetaMock({
    required String id,
    required double valorAporte,
  }) {
    final idx = _metasMockList.indexWhere(
      (m) => m['id'] == id || m['firestore_id'] == id,
    );
    if (idx >= 0) {
      final double atual =
          (_metasMockList[idx]['valor_atual'] as num?)?.toDouble() ?? 0.0;
      final double novo = atual + valorAporte;
      final double obj =
          (_metasMockList[idx]['valor_objetivo'] as num?)?.toDouble() ?? 1.0;
      final bool concluida = novo >= obj;

      _metasMockList[idx]['valor_atual'] = novo;
      _metasMockList[idx]['concluida'] = concluida;
      _metasMockList[idx]['status'] = concluida ? 'concluida' : 'em_andamento';
      _metasMockStreamController.add(List.from(_metasMockList));
    }
  }

  /// Remove uma meta financeira simulada pelo seu identificador.
  ///
  /// Parâmetros:
  /// - [id]: ID da meta a ser excluída.
  void excluirMetaMock(String id) {
    _metasMockList.removeWhere(
      (m) => m['id'] == id || m['firestore_id'] == id,
    );
    _metasMockStreamController.add(List.from(_metasMockList));
  }

  // =========================================================================
  // DADOS FICTÍCIOS DE NOTIFICAÇÕES (MENSAGENS MODERADAS E REATIVAS)
  // =========================================================================

  /// Cache em memória das notificações simuladas para permitir alteração de status (lida/não lida).
  late final List<Map<String, dynamic>> _notificacoesMock =
      _gerarNotificacoesIniciais();

  /// Notificador reativo de alterações em notificações simuladas.
  final StreamController<List<Map<String, dynamic>>>
      _notificacoesMockStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  /// Gera a lista inicial de notificações simuladas.
  static List<Map<String, dynamic>> _gerarNotificacoesIniciais() {
    final agora = DateTime.now();
    return [
      {
        'id': 'notif_1',
        'firestore_id': 'notif_1',
        'id_cliente': 'mock_user_123',
        'titulo': 'Pix Recebido com Sucesso!',
        'mensagem':
            'Você recebeu R\$ 170,00 referente ao suporte técnico web.',
        'data': Timestamp.fromDate(agora.subtract(const Duration(minutes: 42))),
        'lida': false,
        'tipo': 'pix_recebido',
        'categoria': 'Sistema',
      },
      {
        'id': 'notif_2',
        'firestore_id': 'notif_2',
        'id_cliente': 'mock_user_123',
        'titulo': 'Meta Reserva de Emergência Próxima!',
        'mensagem':
            'Parabéns! Você já completou 55% da sua meta de Reserva de Emergência.',
        'data': Timestamp.fromDate(agora.subtract(const Duration(hours: 3))),
        'lida': false,
        'tipo': 'meta',
        'categoria': 'Finanças',
      },
      {
        'id': 'notif_3',
        'firestore_id': 'notif_3',
        'id_cliente': 'mock_user_123',
        'titulo': 'Dica do CONRADO',
        'mensagem':
            'Seus gastos com Lazer foram R\$ 25,00 menores nesta semana. Excelente controle de fluxo!',
        'data': Timestamp.fromDate(agora.subtract(const Duration(days: 1))),
        'lida': true,
        'tipo': 'conrado_ia',
        'categoria': 'IA Financeira',
      },
      {
        'id': 'notif_4',
        'firestore_id': 'notif_4',
        'id_cliente': 'mock_user_123',
        'titulo': 'Fatura do Cartão Fechando',
        'mensagem':
            'Sua fatura do cartão Nubank fecha em 4 dias. Saldo atual: R\$ 145,80.',
        'data': Timestamp.fromDate(agora.subtract(const Duration(days: 2))),
        'lida': true,
        'tipo': 'cartao',
        'categoria': 'Sistema',
      },
    ];
  }

  /// Retorna as notificações simuladas de alertas, finanças e dicas do CONRADO.
  List<Map<String, dynamic>> get notificacoesMock =>
      List.unmodifiable(_notificacoesMock);

  /// Stream reativo das notificações simuladas com emissão inicial imediata.
  Stream<List<Map<String, dynamic>>> get notificacoesStream {
    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? sub;

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        controller.add(List.from(_notificacoesMock));
        sub = _notificacoesMockStreamController.stream.listen((lista) {
          if (!controller.isClosed) {
            controller.add(List.from(lista));
          }
        });
      },
      onCancel: () {
        sub?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  /// Marca uma notificação simulada específica como lida na sessão mock.
  void marcarNotificacaoComoLida(String idNotificacao) {
    final idx = _notificacoesMock.indexWhere(
      (n) => n['id'] == idNotificacao || n['firestore_id'] == idNotificacao,
    );
    if (idx >= 0) {
      _notificacoesMock[idx]['lida'] = true;
      _notificacoesMockStreamController.add(List.from(_notificacoesMock));
    }
  }

  /// Marca todas as notificações simuladas como lidas na sessão mock.
  void marcarTodasNotificacoesComoLidas() {
    for (final n in _notificacoesMock) {
      n['lida'] = true;
    }
    _notificacoesMockStreamController.add(List.from(_notificacoesMock));
  }

  /// Limpa todas as notificações simuladas na sessão mock.
  void limparNotificacoes() {
    _notificacoesMock.clear();
    _notificacoesMockStreamController.add(List.from(_notificacoesMock));
  }

  // =========================================================================
  // DADOS FICTÍCIOS DE CHATS SALVOS COM O CONRADO
  // =========================================================================

  /// Cache interno mutável das sessões de chat gravadas com o CONRADO.
  late final List<Map<String, dynamic>> _sessoesChatMockList =
      _gerarSessoesChatIniciais();

  /// StreamController broadcast para notificações de mudanças nas sessões de chat mock.
  final StreamController<List<Map<String, dynamic>>>
      _sessoesChatMockStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  /// Retorna as sessões de chats realistas gravadas com o CONRADO.
  List<Map<String, dynamic>> get sessoesChatMock =>
      List.unmodifiable(_sessoesChatMockList);

  /// Salva ou atualiza uma sessão de chat no modo mock.
  void salvarSessaoChatMock({
    required String chatId,
    required String titulo,
    required String topico,
    required List<Map<String, dynamic>> mensagens,
  }) {
    final agora = DateTime.now();
    final String preview = mensagens.isNotEmpty
        ? (mensagens.last['text'] ?? 'Conversa realizada.')
        : 'Conversa realizada.';

    final idx = _sessoesChatMockList.indexWhere((s) => s['id'] == chatId);
    final dados = {
      'id': chatId,
      'titulo': titulo,
      'topico': topico,
      'preview': preview,
      'data': Timestamp.fromDate(agora),
      'atualizadoEm': agora,
      'mensagens': mensagens,
    };

    if (idx >= 0) {
      _sessoesChatMockList[idx] = dados;
    } else {
      _sessoesChatMockList.insert(0, dados);
    }
    _sessoesChatMockStreamController.add(List.from(_sessoesChatMockList));
  }

  /// Exclui uma sessão de chat no modo mock.
  void excluirSessaoChatMock(String chatId) {
    _sessoesChatMockList.removeWhere((s) => s['id'] == chatId);
    _sessoesChatMockStreamController.add(List.from(_sessoesChatMockList));
  }

  /// Gera a lista inicial de conversas simuladas com o CONRADO.
  static List<Map<String, dynamic>> _gerarSessoesChatIniciais() {
    final agora = DateTime.now();
    return [
      {
        'id': 'chat_mock_1',
        'titulo': 'Estratégia de Gestão Financeira',
        'data': Timestamp.fromDate(agora.subtract(const Duration(hours: 5))),
        'preview':
            'CONRADO analisou os recebimentos e sugeriu separar 20% para despesas e reserva.',
        'mensagens': [
          {
            'text':
                'Como devo organizar os gastos e despesas do mês?',
            'isUser': true,
            'timestamp':
                agora.subtract(const Duration(hours: 5, minutes: 10)).toIso8601String(),
          },
          {
            'text':
                '# Organização Financeira Pessoal\n\n'
                'Aqui estão os passos recomendados pelo **CONRADO**:\n\n'
                '• **Separação de Contas**: Mantenha conta pessoal e de trabalho separadas.\n'
                '• **Provisão de Gastos**: Reserve **15% a 20%** de cada valor faturado para segurança.\n'
                '• **Acompanhamento**: Registre pequenas compras diárias para evitar vazamentos.',
            'isUser': false,
            'timestamp':
                agora.subtract(const Duration(hours: 5, minutes: 8)).toIso8601String(),
          },
        ],
      },
      {
        'id': 'chat_mock_2',
        'titulo': 'CDB x Tesouro Selic para Reserva',
        'data': Timestamp.fromDate(agora.subtract(const Duration(days: 2))),
        'preview':
            'Comparativo detalhado de liquidez diária e rentabilidade para pequenas reservas.',
        'mensagens': [
          {
            'text':
                'Vale mais a pena colocar minha reserva de R\$ 1.000 em CDB ou Tesouro Selic?',
            'isUser': true,
            'timestamp':
                agora.subtract(const Duration(days: 2, minutes: 15)).toIso8601String(),
          },
          {
            'text':
                'Ambas as opções são excelentes para a sua **Reserva de Emergência**:\n\n'
                '1. **CDB 100% CDI**: Liquidez imediata inclusive aos finais de semana na maioria dos bancos digitais.\n'
                '2. **Tesouro Selic**: O ativo de menor risco soberano do Brasil, com taxa de custódia da B3 zerada.',
            'isUser': false,
            'timestamp':
                agora.subtract(const Duration(days: 2, minutes: 12)).toIso8601String(),
          },
        ],
      },
      {
        'id': 'chat_mock_3',
        'titulo': 'Plano para Compra de Equipamento de Estudo',
        'data': Timestamp.fromDate(agora.subtract(const Duration(days: 4))),
        'preview':
            'Simulação de aportes mensais de R\$ 120 para adquirir o acessório em 3 meses.',
        'mensagens': [
          {
            'text':
                'Quero comprar um acessório de R\$ 400 à vista com desconto. Em quanto tempo consigo?',
            'isUser': true,
            'timestamp':
                agora.subtract(const Duration(days: 4, minutes: 20)).toIso8601String(),
          },
          {
            'text':
                'Com a sua capacidade atual de poupança de **R\$ 120/mês**, você alcançará o valor em aproximadamente **3 meses e meio** mantendo o saldo rendendo no CDI.',
            'isUser': false,
            'timestamp':
                agora.subtract(const Duration(days: 4, minutes: 18)).toIso8601String(),
          },
        ],
      },
    ];
  }
}
