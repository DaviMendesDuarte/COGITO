/// Assistente utilitário do CONRADO para geração de diagnósticos e dicas financeiras reais.
///
/// Analisa transações, saldos, metas e orçamentos do usuário em tempo real
/// para fornecer orientações práticas e contextuais tanto no Dashboard quanto na aba de Relatórios.
class ConradoAdviceHelper {
  ConradoAdviceHelper._();

  /// Mensagem padrão exibida quando não há dados ou transações suficientes para análise.
  static const String fallbackSemDica =
      'Nenhuma movimentação registrada no momento. Registre suas receitas e despesas para receber diagnósticos do CONRADO.';

  /// Gera um insight real e contextual do CONRADO para o card "Entenda o CONRADO" no Dashboard.
  ///
  /// Parâmetros:
  /// - [transacoes]: Lista de transações (receitas e despesas) registradas pelo usuário.
  /// - [saldoConsolidado]: Saldo total consolidado das contas bancárias vinculadas.
  /// - [metas]: Lista opcional de metas financeiras do usuário.
  ///
  /// Retorna o diagnóstico inteligente em texto estritamente baseado nos dados reais.
  static String gerarDicaDashboard({
    required List<Map<String, dynamic>> transacoes,
    double saldoConsolidado = 0.0,
    List<Map<String, dynamic>> metas = const [],
  }) {
    if (transacoes.isEmpty) {
      return fallbackSemDica;
    }

    double totalReceitas = 0.0;
    double totalDespesas = 0.0;
    final Map<String, double> gastosPorCategoria = {};
    Map<String, dynamic>? transacaoMaisRecente;

    for (final t in transacoes) {
      final double valor = (t['valor'] as num?)?.toDouble() ?? 0.0;
      final String tipo = t['tipo'] ?? 'Despesa';
      final String categoria = t['categoria'] ?? 'Outros';

      if (tipo == 'Receita') {
        totalReceitas += valor;
      } else {
        totalDespesas += valor;
        gastosPorCategoria[categoria] = (gastosPorCategoria[categoria] ?? 0.0) + valor;
      }

      transacaoMaisRecente ??= t;
    }

    // Se não há receitas nem despesas
    if (totalDespesas == 0 && totalReceitas == 0) {
      return fallbackSemDica;
    }

    // Se só tem receitas e sem despesas
    if (totalDespesas == 0 && totalReceitas > 0) {
      return 'Você registrou R\$ ${totalReceitas.toStringAsFixed(2).replaceAll('.', ',')} em receitas e ainda não teve despesas! Ótima oportunidade para aportar em suas metas.';
    }

    // Categoria líder de gastos
    String categoriaLider = 'Diversos';
    double maiorGastoCategoria = 0.0;
    gastosPorCategoria.forEach((cat, total) {
      if (total > maiorGastoCategoria) {
        maiorGastoCategoria = total;
        categoriaLider = cat;
      }
    });

    // Se só tem despesas registradas e nenhuma receita cadastrada
    if (totalReceitas == 0 && totalDespesas > 0) {
      return 'Você registrou R\$ ${totalDespesas.toStringAsFixed(2).replaceAll('.', ',')} em despesas recentes, principalmente em "$categoriaLider". Registre suas receitas para ter um diagnóstico de fluxo completo!';
    }

    final double proporcaoLider = totalDespesas > 0 ? (maiorGastoCategoria / totalDespesas) * 100 : 0.0;

    // Cenário 1: Despesas superam receitas
    if (totalDespesas > totalReceitas && totalReceitas > 0) {
      final double deficit = totalDespesas - totalReceitas;
      return 'Atenção ao fluxo: suas despesas superaram as receitas em R\$ ${deficit.toStringAsFixed(2).replaceAll('.', ',')}. A categoria "$categoriaLider" foi responsável por ${proporcaoLider.toStringAsFixed(0)}% dos gastos.';
    }

    // Cenário 2: Economia positiva
    if (totalReceitas > totalDespesas && totalReceitas > 0) {
      final double taxaPoupanca = ((totalReceitas - totalDespesas) / totalReceitas) * 100;
      if (taxaPoupanca >= 10) {
        return 'Parabéns! Você economizou ${taxaPoupanca.toStringAsFixed(0)}% da sua receita recente. Seu maior consumo foi em "$categoriaLider" (R\$ ${maiorGastoCategoria.toStringAsFixed(2).replaceAll('.', ',')}).';
      }
    }

    // Cenário 3: Transação recente de alto valor
    if (transacaoMaisRecente != null && transacaoMaisRecente['tipo'] == 'Despesa') {
      final double valRecente = (transacaoMaisRecente['valor'] as num?)?.toDouble() ?? 0.0;
      final String tituloRecente = transacaoMaisRecente['titulo'] ?? 'Despesa';
      if (valRecente >= 100) {
        return 'Sua última despesa foi "$tituloRecente" de R\$ ${valRecente.toStringAsFixed(2).replaceAll('.', ',')} na categoria "$categoriaLider". Acompanhe seus gastos para fechar o mês no azul!';
      }
    }

    final double saldoMes = totalReceitas - totalDespesas;
    if (saldoMes >= 0) {
      return 'Seu fluxo está positivo em R\$ ${saldoMes.toStringAsFixed(2).replaceAll('.', ',')}. Sua maior concentração de despesas é em "$categoriaLider" (R\$ ${maiorGastoCategoria.toStringAsFixed(2).replaceAll('.', ',')}).';
    } else {
      return 'Suas despesas superaram suas receitas em R\$ ${(-saldoMes).toStringAsFixed(2).replaceAll('.', ',')}. Maior concentração em "$categoriaLider" (R\$ ${maiorGastoCategoria.toStringAsFixed(2).replaceAll('.', ',')}).';
    }
  }

  /// Gera um diagnóstico e recomendação acionável do CONRADO para a tela/aba de Relatórios.
  ///
  /// Parâmetros:
  /// - [despesasPeriodo]: Lista de despesas filtradas pelo período selecionado.
  /// - [totalDespesas]: Valor total gasto no período.
  /// - [limiteMensal]: Limite ou teto de gastos configurado pelo usuário.
  ///
  /// Retorna a dica real do CONRADO ou [fallbackSemDica] se não houver despesas.
  static String gerarDicaRelatorios({
    required List<Map<String, dynamic>> despesasPeriodo,
    required double totalDespesas,
    required double limiteMensal,
  }) {
    if (despesasPeriodo.isEmpty || totalDespesas <= 0) {
      return fallbackSemDica;
    }

    // Identifica categoria de maior peso no período
    final Map<String, double> categorias = {};
    for (final d in despesasPeriodo) {
      final String cat = d['categoria'] ?? 'Outros';
      final double val = (d['valor'] as num?)?.toDouble() ?? 0.0;
      categorias[cat] = (categorias[cat] ?? 0.0) + val;
    }

    String topCategoria = 'Outros';
    double topValor = 0.0;
    categorias.forEach((c, v) {
      if (v > topValor) {
        topValor = v;
        topCategoria = c;
      }
    });

    final double percentualConsumidoLimite = (totalDespesas / limiteMensal) * 100;
    final double percentualTopCategoria = (topValor / totalDespesas) * 100;

    // Diagnósticos baseados em limiares reais
    if (percentualConsumidoLimite >= 90) {
      return 'Alerta do CONRADO: você já consumiu ${percentualConsumidoLimite.toStringAsFixed(0)}% do seu teto mensal (R\$ ${totalDespesas.toStringAsFixed(2).replaceAll('.', ',')} de R\$ ${limiteMensal.toStringAsFixed(2).replaceAll('.', ',')}). A categoria "$topCategoria" representa ${percentualTopCategoria.toStringAsFixed(0)}% disso. Recomendo congelar novos gastos variáveis!';
    } else if (percentualConsumidoLimite >= 60) {
      return 'Dica do CONRADO: seus gastos atingiram ${percentualConsumidoLimite.toStringAsFixed(0)}% do limite planejado. Mais de ${percentualTopCategoria.toStringAsFixed(0)}% foi direcionado para "$topCategoria". Reduzir pequenos custos nessa área garantirá folga até o fim do mês.';
    } else {
      return 'Diagnóstico do CONRADO: seus gastos estão controlados (${percentualConsumidoLimite.toStringAsFixed(0)}% do teto). A maior movimentação foi em "$topCategoria" com R\$ ${topValor.toStringAsFixed(2).replaceAll('.', ',')}. Você está com ótimo ritmo financeiro!';
    }
  }
}
