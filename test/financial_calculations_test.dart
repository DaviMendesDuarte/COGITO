import 'package:flutter_test/flutter_test.dart';

/// Testes unitários para regras de agregação de transações e saldo do COGITO.
void main() {
  group('Testes de Agregação Financeira e Saldo', () {
    final transacoesExemplo = [
      {
        'titulo': 'Salário Freelance',
        'valor': 4500.0,
        'tipo': 'Receita',
        'categoria': 'Receita',
      },
      {
        'titulo': 'Supermercado',
        'valor': 650.0,
        'tipo': 'Despesa',
        'categoria': 'Alimentação',
      },
      {
        'titulo': 'Aluguel',
        'valor': 1200.0,
        'tipo': 'Despesa',
        'categoria': 'Moradia',
      },
      {
        'titulo': 'Combustível',
        'valor': 200.0,
        'tipo': 'Despesa',
        'categoria': 'Transporte',
      },
      {
        'titulo': 'Cinema e Lazer',
        'valor': 150.0,
        'tipo': 'Despesa',
        'categoria': 'Lazer',
      },
      {
        'titulo': 'Rendimento Investimentos',
        'valor': 120.0,
        'tipo': 'Receita',
        'categoria': 'Receita',
      },
    ];

    test('Deve calcular o total de receitas com exatidão', () {
      double totalReceitas = 0.0;
      for (final t in transacoesExemplo) {
        if (t['tipo'] == 'Receita') {
          totalReceitas += (t['valor'] as num).toDouble();
        }
      }
      expect(totalReceitas, equals(4620.0));
    });

    test('Deve calcular o total de despesas com exatidão', () {
      double totalDespesas = 0.0;
      for (final t in transacoesExemplo) {
        if (t['tipo'] == 'Despesa') {
          totalDespesas += (t['valor'] as num).toDouble();
        }
      }
      expect(totalDespesas, equals(2200.0));
    });

    test(
      'Deve calcular o saldo líquido (Receitas - Despesas) corretamente',
      () {
        double saldoLiquido = 0.0;
        for (final t in transacoesExemplo) {
          final valor = (t['valor'] as num).toDouble();
          if (t['tipo'] == 'Receita') {
            saldoLiquido += valor;
          } else {
            saldoLiquido -= valor;
          }
        }
        expect(saldoLiquido, equals(2420.0));
      },
    );

    test(
      'Deve calcular a distribuição percentual por categoria de despesa',
      () {
        final Map<String, double> totaisPorCategoria = {};
        double totalDespesas = 0.0;

        for (final t in transacoesExemplo) {
          if (t['tipo'] == 'Despesa') {
            final cat = t['categoria'] as String;
            final valor = (t['valor'] as num).toDouble();
            totaisPorCategoria[cat] = (totaisPorCategoria[cat] ?? 0.0) + valor;
            totalDespesas += valor;
          }
        }

        // Moradia: 1200 / 2200 ≈ 54.54%
        final percentualMoradia =
            (totaisPorCategoria['Moradia']! / totalDespesas) * 100.0;
        expect(percentualMoradia, closeTo(54.54, 0.01));

        // Alimentação: 650 / 2200 ≈ 29.54%
        final percentualAlimentacao =
            (totaisPorCategoria['Alimentação']! / totalDespesas) * 100.0;
        expect(percentualAlimentacao, closeTo(29.54, 0.01));
      },
    );

    test(
      'Deve verificar o status de consumo do limite de envelope orçamentário',
      () {
        const double limiteAlimentacao = 1000.0;
        const double gastoAlimentacao = 650.0;

        final double percentualConsumido =
            (gastoAlimentacao / limiteAlimentacao) * 100.0;
        final double saldoRestante = limiteAlimentacao - gastoAlimentacao;
        final bool estourouLimite = gastoAlimentacao > limiteAlimentacao;

        expect(percentualConsumido, equals(65.0));
        expect(saldoRestante, equals(350.0));
        expect(estourouLimite, isFalse);
      },
    );
  });
}
