import 'package:cloud_firestore/cloud_firestore.dart';

/// Funções utilitárias e regras de negócio financeiras do COGITO.
/// Centraliza a lógica de conversão monetária, filtragem temporal,
/// agregação de dados e exportação de relatórios.
class FinancialUtils {
  /// Converte texto formatado em Real brasileiro (ex: "R$ 3.500,50" ou "1500,00") para [double].
  /// Retorna 0.0 caso a string seja vazia ou contenha formato inválido.
  static double converterTextoParaMoeda(String texto) {
    if (texto.trim().isEmpty) return 0.0;
    final String limpo = texto
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(limpo) ?? 0.0;
  }

  /// Extrai com segurança uma data [DateTime] a partir dos campos de um mapa de transação.
  /// Suporta instâncias de [DateTime], [Timestamp] do Firestore e strings ISO-8601.
  static DateTime extrairDataTransacao(Map<String, dynamic> t) {
    if (t['data_dt'] is DateTime) return t['data_dt'] as DateTime;
    final dynamic dataVal = t['data'];
    if (dataVal is Timestamp) return dataVal.toDate();
    if (dataVal is DateTime) return dataVal;
    if (dataVal is String) {
      try {
        return DateTime.parse(dataVal);
      } catch (_) {}
    }
    final dynamic dataCriacao = t['data_criacao'];
    if (dataCriacao is Timestamp) return dataCriacao.toDate();
    if (dataCriacao is DateTime) return dataCriacao;
    return DateTime.now();
  }

  /// Filtra a lista de transações conforme o período selecionado.
  /// Aceita [dataReferencia] para possibilitar testes determinísticos no tempo.
  static List<Map<String, dynamic>> filtrarTransacoesPorPeriodo(
    List<Map<String, dynamic>> lista,
    String periodo, {
    DateTime? dataReferencia,
  }) {
    final agora = dataReferencia ?? DateTime.now();
    return lista.where((t) {
      final DateTime dt = extrairDataTransacao(t);
      switch (periodo) {
        case 'Este mês':
          return dt.year == agora.year && dt.month == agora.month;
        case 'Últimos 30 dias':
          final limite = agora.subtract(const Duration(days: 30));
          return dt.isAfter(limite) || dt.isAtSameMomentAs(limite);
        case 'Últimos 3 meses':
          final limite = DateTime(agora.year, agora.month - 3, agora.day);
          return dt.isAfter(limite) || dt.isAtSameMomentAs(limite);
        case 'Este ano':
          return dt.year == agora.year;
        case 'Todo o período':
        default:
          return true;
      }
    }).toList();
  }

  /// Calcula os totais de Receitas, Despesas e Saldo Líquido de uma lista de transações.
  static Map<String, double> calcularTotaisFinanceiros(
    List<Map<String, dynamic>> transacoes,
  ) {
    double totalReceitas = 0.0;
    double totalDespesas = 0.0;

    for (final t in transacoes) {
      final double valor = (t['valor'] as num?)?.toDouble() ?? 0.0;
      final String tipo = (t['tipo'] as String?) ?? 'Receita';
      if (tipo == 'Receita') {
        totalReceitas += valor;
      } else {
        totalDespesas += valor;
      }
    }

    return {
      'receitas': totalReceitas,
      'despesas': totalDespesas,
      'saldoLiquido': totalReceitas - totalDespesas,
    };
  }

  /// Calcula o valor total de despesas por categoria e o percentual de cada categoria sobre o total.
  static Map<String, Map<String, double>> calcularDistribuicaoCategorias(
    List<Map<String, dynamic>> transacoes,
  ) {
    final Map<String, double> totaisPorCategoria = {};
    double totalGeralDespesas = 0.0;

    for (final t in transacoes) {
      final String tipo = (t['tipo'] as String?) ?? '';
      if (tipo == 'Despesa') {
        final String categoria = (t['categoria'] as String?) ?? 'Outros';
        final double valor = (t['valor'] as num?)?.toDouble() ?? 0.0;
        totaisPorCategoria[categoria] =
            (totaisPorCategoria[categoria] ?? 0.0) + valor;
        totalGeralDespesas += valor;
      }
    }

    final Map<String, Map<String, double>> resultado = {};
    totaisPorCategoria.forEach((categoria, valor) {
      final double percentual = totalGeralDespesas > 0
          ? (valor / totalGeralDespesas) * 100.0
          : 0.0;
      resultado[categoria] = {'valor': valor, 'percentual': percentual};
    });

    return resultado;
  }

  /// Agrupa as despesas dos últimos 4 meses a partir de uma data de referência.
  static List<Map<String, dynamic>> calcularEvolucaoUltimos4Meses(
    List<Map<String, dynamic>> transacoes, {
    DateTime? dataReferencia,
  }) {
    final agora = dataReferencia ?? DateTime.now();
    final List<String> nomesMeses = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    final List<Map<String, dynamic>> evolucao = [];

    for (int i = 3; i >= 0; i--) {
      final int targetMonth = ((agora.month - 1 - i) % 12) + 1;
      final int targetYear = agora.month - i <= 0 ? agora.year - 1 : agora.year;
      final String labelMes = nomesMeses[targetMonth - 1];

      double despesasMes = 0.0;
      for (final t in transacoes) {
        if (t['tipo'] == 'Despesa') {
          final dt = extrairDataTransacao(t);
          if (dt.year == targetYear && dt.month == targetMonth) {
            despesasMes += (t['valor'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }

      evolucao.add({
        'mes': labelMes,
        'mesNum': targetMonth,
        'ano': targetYear,
        'valor': despesasMes,
      });
    }

    return evolucao;
  }

  /// Gera string no formato CSV para exportação em planilhas.
  static String gerarExtratoCSV(List<Map<String, dynamic>> transacoes) {
    final buffer = StringBuffer();
    buffer.writeln('Data,Categoria,Descricao,Tipo,Valor');
    for (final t in transacoes) {
      final dt = extrairDataTransacao(t);
      final dataStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      final val = ((t['valor'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
      final titulo = (t['titulo'] ?? '').toString().replaceAll(',', ' ');
      final categoria = (t['categoria'] ?? 'Outros').toString().replaceAll(
        ',',
        ' ',
      );
      final tipo = t['tipo'] ?? 'Despesa';
      buffer.writeln('$dataStr,$categoria,$titulo,$tipo,$val');
    }
    return buffer.toString();
  }

  /// Gera relatório executivo detalhado em formato de texto.
  static String gerarRelatorioExecutivo(
    List<Map<String, dynamic>> transacoes,
    String periodo, {
    DateTime? dataGeracao,
  }) {
    final buffer = StringBuffer();
    final agora = dataGeracao ?? DateTime.now();
    final totais = calcularTotaisFinanceiros(transacoes);

    buffer.writeln('====================================================');
    buffer.writeln('          COGITO - RELATÓRIO FINANCEIRO');
    buffer.writeln('====================================================');
    buffer.writeln(
      'Gerado em: ${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year} às ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}',
    );
    buffer.writeln(
      'Período: $periodo | Total de Lançamentos: ${transacoes.length}',
    );
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('RESUMO GERAL:');
    buffer.writeln(
      '• Total de Receitas: R\$ ${totais['receitas']!.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '• Total de Despesas: R\$ ${totais['despesas']!.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '• Saldo Líquido:     R\$ ${totais['saldoLiquido']!.toStringAsFixed(2)}',
    );
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('DETALHAMENTO DAS TRANSAÇÕES:');
    for (final t in transacoes) {
      final dt = extrairDataTransacao(t);
      final dataStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      final sinal = t['tipo'] == 'Receita' ? '(+)' : '(-)';
      final val = ((t['valor'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
      buffer.writeln(
        '[$dataStr] [${t['categoria'] ?? 'Outros'}] ${t['titulo']} : $sinal R\$ $val',
      );
    }
    buffer.writeln('====================================================');
    return buffer.toString();
  }

  /// Gera estrutura JSON formatada para exportação.
  static String gerarExtratoJSON(
    List<Map<String, dynamic>> transacoes,
    String periodo, {
    DateTime? dataGeracao,
  }) {
    final agora = dataGeracao ?? DateTime.now();
    final listClean = transacoes.map((t) {
      final dt = extrairDataTransacao(t);
      return {
        'titulo': t['titulo'],
        'valor': t['valor'],
        'categoria': t['categoria'],
        'tipo': t['tipo'],
        'data': dt.toIso8601String(),
      };
    }).toList();

    final jsonItems = listClean
        .map(
          (e) =>
              '    {"titulo": "${e['titulo']}", "valor": ${e['valor']}, "categoria": "${e['categoria']}", "tipo": "${e['tipo']}", "data": "${e['data']}"}',
        )
        .join(',\n');

    return '''{
  "aplicativo": "COGITO",
  "gerado_em": "${agora.toIso8601String()}",
  "periodo": "$periodo",
  "quantidade": ${listClean.length},
  "transacoes": [
$jsonItems
  ]
}''';
  }
}
