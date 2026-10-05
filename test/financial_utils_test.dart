import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cogito/common/utils/financial_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Suíte de testes unitários para as funções e regras de negócio financeiras reais do COGITO.
void main() {
  group('FinancialUtils - Conversão Monetária Real', () {
    test(
      'Deve converter strings em formato Real brasileiro (R\$) para double com precisão',
      () {
        expect(
          FinancialUtils.converterTextoParaMoeda('R\$ 3.500,50'),
          equals(3500.50),
        );
        expect(
          FinancialUtils.converterTextoParaMoeda('R\$ 12.450,90'),
          equals(12450.90),
        );
        expect(
          FinancialUtils.converterTextoParaMoeda('1.250,00'),
          equals(1250.00),
        );
        expect(
          FinancialUtils.converterTextoParaMoeda('450,75'),
          equals(450.75),
        );
        expect(FinancialUtils.converterTextoParaMoeda('0,00'), equals(0.0));
        expect(FinancialUtils.converterTextoParaMoeda(''), equals(0.0));
        expect(FinancialUtils.converterTextoParaMoeda('inválido'), equals(0.0));
      },
    );
  });

  group('FinancialUtils - Extração de Datas de Transações', () {
    test('Deve extrair DateTime a partir de Timestamp do Cloud Firestore', () {
      final now = DateTime(2026, 9, 1, 15, 30);
      final transacao = {
        'titulo': 'Freelance Flutter',
        'valor': 2500.0,
        'data': Timestamp.fromDate(now),
      };
      final resultado = FinancialUtils.extrairDataTransacao(transacao);
      expect(resultado.year, equals(2026));
      expect(resultado.month, equals(9));
      expect(resultado.day, equals(1));
    });

    test('Deve extrair DateTime a partir de String ISO-8601', () {
      final transacao = {
        'titulo': 'Aluguel',
        'valor': 1200.0,
        'data': '2026-08-15T10:00:00.000Z',
      };
      final resultado = FinancialUtils.extrairDataTransacao(transacao);
      expect(resultado.year, equals(2026));
      expect(resultado.month, equals(8));
      expect(resultado.day, equals(15));
    });
  });

  group('FinancialUtils - Filtro de Período do Extrato', () {
    final dataBase = DateTime(2026, 9, 15);

    final transacoes = [
      {
        'titulo': 'Salário Setembro',
        'valor': 5000.0,
        'tipo': 'Receita',
        'data': DateTime(2026, 9, 5),
      },
      {
        'titulo': 'Mercado Setembro',
        'valor': 600.0,
        'tipo': 'Despesa',
        'data': DateTime(2026, 9, 10),
      },
      {
        'titulo': 'Conta Agosto (30 dias)',
        'valor': 150.0,
        'tipo': 'Despesa',
        'data': DateTime(2026, 8, 25),
      },
      {
        'titulo': 'Compra Julho (2 meses)',
        'valor': 300.0,
        'tipo': 'Despesa',
        'data': DateTime(2026, 7, 10),
      },
      {
        'titulo': 'Compra Janeiro (mesmo ano)',
        'valor': 400.0,
        'tipo': 'Despesa',
        'data': DateTime(2026, 1, 15),
      },
      {
        'titulo': 'Ano Passado',
        'valor': 1000.0,
        'tipo': 'Despesa',
        'data': DateTime(2025, 11, 20),
      },
    ];

    test(
      'Filtro "Este mês" deve retornar apenas lançamentos de Setembro de 2026',
      () {
        final filtradas = FinancialUtils.filtrarTransacoesPorPeriodo(
          transacoes,
          'Este mês',
          dataReferencia: dataBase,
        );
        expect(filtradas.length, equals(2));
        expect(
          filtradas.map((t) => t['titulo']),
          containsAll(['Salário Setembro', 'Mercado Setembro']),
        );
      },
    );

    test(
      'Filtro "Últimos 30 dias" deve retornar lançamentos dentro da janela de 30 dias',
      () {
        final filtradas = FinancialUtils.filtrarTransacoesPorPeriodo(
          transacoes,
          'Últimos 30 dias',
          dataReferencia: dataBase,
        );
        expect(filtradas.length, equals(3));
        expect(
          filtradas.map((t) => t['titulo']),
          containsAll([
            'Salário Setembro',
            'Mercado Setembro',
            'Conta Agosto (30 dias)',
          ]),
        );
      },
    );

    test(
      'Filtro "Últimos 3 meses" deve retornar lançamentos dos últimos 90 dias',
      () {
        final filtradas = FinancialUtils.filtrarTransacoesPorPeriodo(
          transacoes,
          'Últimos 3 meses',
          dataReferencia: dataBase,
        );
        expect(filtradas.length, equals(4));
      },
    );

    test(
      'Filtro "Este ano" deve retornar todos os lançamentos do ano de 2026',
      () {
        final filtradas = FinancialUtils.filtrarTransacoesPorPeriodo(
          transacoes,
          'Este ano',
          dataReferencia: dataBase,
        );
        expect(filtradas.length, equals(5));
        expect(filtradas.any((t) => t['titulo'] == 'Ano Passado'), isFalse);
      },
    );

    test('Filtro "Todo o período" deve retornar 100% das transações', () {
      final filtradas = FinancialUtils.filtrarTransacoesPorPeriodo(
        transacoes,
        'Todo o período',
        dataReferencia: dataBase,
      );
      expect(filtradas.length, equals(6));
    });
  });

  group('FinancialUtils - Agregação e Totais Financeiros', () {
    final transacoes = [
      {
        'titulo': 'Salário',
        'valor': 4500.0,
        'tipo': 'Receita',
        'categoria': 'Receita',
      },
      {
        'titulo': 'Freelance',
        'valor': 1500.0,
        'tipo': 'Receita',
        'categoria': 'Receita',
      },
      {
        'titulo': 'Aluguel',
        'valor': 1200.0,
        'tipo': 'Despesa',
        'categoria': 'Moradia',
      },
      {
        'titulo': 'Supermercado',
        'valor': 800.0,
        'tipo': 'Despesa',
        'categoria': 'Alimentação',
      },
      {
        'titulo': 'Internet',
        'valor': 150.0,
        'tipo': 'Despesa',
        'categoria': 'Moradia',
      },
    ];

    test('Deve calcular totais de Receitas, Despesas e Saldo Líquido', () {
      final totais = FinancialUtils.calcularTotaisFinanceiros(transacoes);
      expect(totais['receitas'], equals(6000.0));
      expect(totais['despesas'], equals(2150.0));
      expect(totais['saldoLiquido'], equals(3850.0));
    });

    test('Deve calcular distribuição percentual das categorias de despesa', () {
      final distribuicao = FinancialUtils.calcularDistribuicaoCategorias(
        transacoes,
      );
      expect(distribuicao.containsKey('Moradia'), isTrue);
      expect(distribuicao.containsKey('Alimentação'), isTrue);

      // Moradia: 1350 / 2150 ≈ 62.79%
      expect(distribuicao['Moradia']!['valor'], equals(1350.0));
      expect(distribuicao['Moradia']!['percentual']!, closeTo(62.79, 0.01));

      // Alimentação: 800 / 2150 ≈ 37.21%
      expect(distribuicao['Alimentação']!['valor'], equals(800.0));
      expect(distribuicao['Alimentação']!['percentual']!, closeTo(37.21, 0.01));
    });

    test('Deve calcular evolução dos últimos 4 meses em ordem cronológica', () {
      final ref = DateTime(2026, 9, 1);
      final transacoesMeses = [
        {
          'titulo': 'Gasto Junho',
          'valor': 500.0,
          'tipo': 'Despesa',
          'data': DateTime(2026, 6, 10),
        },
        {
          'titulo': 'Gasto Julho',
          'valor': 700.0,
          'tipo': 'Despesa',
          'data': DateTime(2026, 7, 15),
        },
        {
          'titulo': 'Gasto Agosto',
          'valor': 900.0,
          'tipo': 'Despesa',
          'data': DateTime(2026, 8, 20),
        },
        {
          'titulo': 'Gasto Setembro',
          'valor': 1100.0,
          'tipo': 'Despesa',
          'data': DateTime(2026, 9, 1),
        },
      ];

      final evolucao = FinancialUtils.calcularEvolucaoUltimos4Meses(
        transacoesMeses,
        dataReferencia: ref,
      );
      expect(evolucao.length, equals(4));
      expect(evolucao[0]['mes'], equals('Jun'));
      expect(evolucao[0]['valor'], equals(500.0));
      expect(evolucao[3]['mes'], equals('Set'));
      expect(evolucao[3]['valor'], equals(1100.0));
    });
  });

  group('FinancialUtils - Geração de Arquivos de Exportação', () {
    final transacoes = [
      {
        'titulo': 'Consultoria',
        'valor': 2000.0,
        'tipo': 'Receita',
        'categoria': 'Receita',
        'data': DateTime(2026, 9, 1),
      },
      {
        'titulo': 'Software',
        'valor': 150.0,
        'tipo': 'Despesa',
        'categoria': 'Trabalho',
        'data': DateTime(2026, 9, 2),
      },
    ];

    test('Deve gerar arquivo CSV formatado com cabeçalho padrão', () {
      final csv = FinancialUtils.gerarExtratoCSV(transacoes);
      expect(csv, startsWith('Data,Categoria,Descricao,Tipo,Valor'));
      expect(csv, contains('01/09/2026,Receita,Consultoria,Receita,2000.00'));
      expect(csv, contains('02/09/2026,Trabalho,Software,Despesa,150.00'));
    });

    test('Deve gerar Relatório Executivo com resumo e saldo', () {
      final relatorio = FinancialUtils.gerarRelatorioExecutivo(
        transacoes,
        'Este mês',
        dataGeracao: DateTime(2026, 9, 1, 12, 0),
      );
      expect(relatorio, contains('COGITO - RELATÓRIO FINANCEIRO'));
      expect(relatorio, contains('Total de Receitas: R\$ 2000.00'));
      expect(relatorio, contains('Total de Despesas: R\$ 150.00'));
      expect(relatorio, contains('Saldo Líquido:     R\$ 1850.00'));
    });

    test('Deve gerar JSON estruturado válido contendo as transações', () {
      final json = FinancialUtils.gerarExtratoJSON(
        transacoes,
        'Este mês',
        dataGeracao: DateTime(2026, 9, 1, 12, 0),
      );
      expect(json, contains('"aplicativo": "COGITO"'));
      expect(json, contains('"quantidade": 2'));
      expect(json, contains('"titulo": "Consultoria"'));
      expect(json, contains('"valor": 2000.0'));
    });
  });
}
