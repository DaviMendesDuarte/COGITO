import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tela de Análise de Gastos e Relatórios Unificados do COGITO.
/// Centraliza todos os relatórios financeiros, estatísticas de entradas/saídas,
/// distribuição por categoria, gráfico comparativo mensal e diagnósticos do CONRADO.
class AnaliseDetalhadaPage extends StatefulWidget {
  const AnaliseDetalhadaPage({super.key});

  @override
  State<AnaliseDetalhadaPage> createState() => _AnaliseDetalhadaPageState();
}

class _AnaliseDetalhadaPageState extends State<AnaliseDetalhadaPage> {
  /// Instância do serviço Firebase Firestore para consulta reativa dos dados de transações.
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  /// Filtro de período selecionado ("Este mês" por padrão).
  String _selectedPeriodo = 'Este mês';

  /// Extrai com segurança a data [DateTime] de um registro de transação.
  DateTime _extrairData(Map<String, dynamic> t) {
    if (t['data_dt'] is DateTime) {
      return t['data_dt'] as DateTime;
    }
    if (t['data'] is Timestamp) {
      return (t['data'] as Timestamp).toDate();
    }
    if (t['data'] is String) {
      try {
        return DateTime.parse(t['data'] as String);
      } catch (_) {}
    }
    if (t['data_criacao'] is Timestamp) {
      return (t['data_criacao'] as Timestamp).toDate();
    }
    return DateTime.now();
  }

  /// Filtra a lista de transações conforme o período selecionado no Combo Box.
  List<Map<String, dynamic>> _filtrarTransacoesPorPeriodo(
    List<Map<String, dynamic>> transacoes,
  ) {
    final agora = DateTime.now();

    return transacoes.where((t) {
      final DateTime dt = _extrairData(t);

      switch (_selectedPeriodo) {
        case 'Este mês':
          return dt.year == agora.year && dt.month == agora.month;
        case 'Mês passado':
          int anoMp = agora.year;
          int mesMp = agora.month - 1;
          if (mesMp <= 0) {
            mesMp = 12;
            anoMp -= 1;
          }
          return dt.year == anoMp && dt.month == mesMp;
        case 'Últimos 3 meses':
          final limite = agora.subtract(const Duration(days: 90));
          return dt.isAfter(limite) || dt.isAtSameMomentAs(limite);
        case 'Este ano':
          return dt.year == agora.year;
        case 'Todo o período':
        default:
          return true;
      }
    }).toList();
  }

  /// Constrói o Combo Box estilizado com ícones e sombra suave para filtragem de período.
  Widget _buildFiltroComboBox() {
    final Map<String, IconData> opcoesComIcones = {
      'Este mês': Icons.today_rounded,
      'Mês passado': Icons.event_repeat_rounded,
      'Últimos 3 meses': Icons.date_range_rounded,
      'Este ano': Icons.calendar_month_rounded,
      'Todo o período': Icons.history_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriodo,
          icon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.getPrimaryAccent(context),
              size: 22,
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          dropdownColor: AppColors.getCardColor(context),
          elevation: 0,
          items: opcoesComIcones.entries.map((entry) {
            final isSelected = entry.key == _selectedPeriodo;
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    entry.value,
                    size: 18,
                    color: isSelected
                        ? AppColors.getPrimaryAccent(context)
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.getPrimaryAccent(context)
                          : AppColors.getTextColor(context),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (novoVal) {
            if (novoVal != null) {
              setState(() {
                _selectedPeriodo = novoVal;
              });
            }
          },
        ),
      ),
    );
  }

  /// Exibe Pop-Up Modal com os detalhes completos do Gráfico de Categorias.
  void _exibirModalGraficoCategorias(
    BuildContext context,
    Map<String, double> categoriasMap,
    double totalSaidas,
  ) {
    final List<PieChartSectionData> secoes = [];
    final Color corPrimaria = AppColors.getPrimaryAccent(context);
    final List<Color> cores = [
      corPrimaria,
      AppColors.primaryOrange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
    ];

    int idx = 0;
    categoriasMap.forEach((cat, valor) {
      final double pct = totalSaidas > 0 ? (valor / totalSaidas * 100) : 0;
      final Color cor = cores[idx % cores.length];
      secoes.add(
        PieChartSectionData(
          color: cor,
          value: valor > 0 ? valor : 1,
          title: '${pct.toStringAsFixed(0)}%',
          radius: 45,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
      idx++;
    });

    if (secoes.isEmpty) {
      secoes.add(
        PieChartSectionData(
          color: Colors.grey,
          value: 100,
          title: '100%',
          radius: 45,
        ),
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(22),
          constraints: const BoxConstraints(maxHeight: 540),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: corPrimaria.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pie_chart,
                        color: corPrimaria,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Detalhamento por Categoria',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: corPrimaria,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.getSubtextColor(context)),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(sections: secoes, centerSpaceRadius: 35),
                  ),
                ),
                const SizedBox(height: 20),
                Divider(color: AppColors.getDividerColor(context)),
                const SizedBox(height: 10),
                if (categoriasMap.isEmpty)
                  Text(
                    'Nenhum gasto registrado neste período.',
                    style: TextStyle(color: AppColors.getSubtextColor(context)),
                  )
                else
                  ...categoriasMap.entries.map((e) {
                    final int i = categoriasMap.keys.toList().indexOf(e.key);
                    final Color cor = cores[i % cores.length];
                    final double pct = totalSaidas > 0
                        ? (e.value / totalSaidas * 100)
                        : 0;
                    return _buildCategoriaDetailItem(
                      e.key,
                      'R\$ ${e.value.toStringAsFixed(2)}',
                      '${pct.toStringAsFixed(0)}%',
                      cor,
                    );
                  }),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: corPrimaria.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dica do CONRADO: Acompanhar suas maiores categorias de gastos reduz em até 30% despesas impulsivas.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Classe auxiliar interna para agrupar totais de gastos dos últimos meses.
  List<Map<String, dynamic>> _calcularEvolucaoUltimos4Meses(
    List<Map<String, dynamic>> todasTransacoes,
  ) {
    final agora = DateTime.now();
    final List<Map<String, dynamic>> mesesData = [];
    final nomesMeses = [
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
    final nomesCompletos = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    // Coleta os últimos 4 meses em ordem cronológica (de 3 meses atrás até o atual)
    for (int i = 3; i >= 0; i--) {
      final mesRef = DateTime(agora.year, agora.month - i, 1);
      final int mes = mesRef.month;
      final int ano = mesRef.year;

      double totalGastoMes = 0.0;
      for (final t in todasTransacoes) {
        final DateTime dt = _extrairData(t);
        if (dt.year == ano && dt.month == mes && t['tipo'] == 'Despesa') {
          totalGastoMes += (t['valor'] as num?)?.toDouble() ?? 0.0;
        }
      }

      mesesData.add({
        'sigla': nomesMeses[mes - 1],
        'nomeCompleto':
            '${nomesCompletos[mes - 1]}${i == 0 ? ' (Mês Atual)' : ''}',
        'ano': ano,
        'totalGasto': totalGastoMes,
      });
    }

    // Calcula variação percentual em relação ao mês anterior
    for (int i = 0; i < mesesData.length; i++) {
      if (i == 0) {
        mesesData[i]['variacao'] = 'Estável';
      } else {
        final double anterior = mesesData[i - 1]['totalGasto'] as double;
        final double atual = mesesData[i]['totalGasto'] as double;
        if (anterior == 0) {
          mesesData[i]['variacao'] = atual > 0 ? '+ 100%' : '0%';
        } else {
          final double pct = ((atual - anterior) / anterior) * 100;
          final String prefix = pct >= 0 ? '+ ' : '- ';
          mesesData[i]['variacao'] = '$prefix${pct.abs().toStringAsFixed(0)}%';
        }
      }
    }

    return mesesData;
  }

  /// Exibe Pop-Up Modal com os detalhes completos do Gráfico de Evolução Mensal.
  void _exibirModalGraficoEvolucao(
    BuildContext context,
    List<Map<String, dynamic>> evolucaoMeses,
  ) {
    final Color corPrimaria = AppColors.getPrimaryAccent(context);
    double maxGasto = 100.0;
    for (final m in evolucaoMeses) {
      final double g = m['totalGasto'] as double;
      if (g > maxGasto) maxGasto = g;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(22),
          constraints: const BoxConstraints(maxHeight: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: corPrimaria.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bar_chart,
                        color: corPrimaria,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Evolução Mensal de Gastos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: corPrimaria,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.getSubtextColor(context)),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final int idx = value.toInt();
                              if (idx >= 0 && idx < evolucaoMeses.length) {
                                return Text(
                                  evolucaoMeses[idx]['sigla'].toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getTextColor(context),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(evolucaoMeses.length, (idx) {
                        final double valor =
                            evolucaoMeses[idx]['totalGasto'] as double;
                        final bool isAtual = idx == evolucaoMeses.length - 1;
                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: valor > 0 ? valor : 5,
                              color: isAtual
                                  ? corPrimaria
                                  : corPrimaria.withValues(
                                      alpha: 0.3 + (idx * 0.15),
                                    ),
                              width: 18,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Divider(color: AppColors.getDividerColor(context)),
                const SizedBox(height: 10),
                ...evolucaoMeses.map((m) {
                  final String nome = m['nomeCompleto'];
                  final double val = m['totalGasto'] as double;
                  final String varPct = m['variacao'];
                  return _buildEvolucaoMonthItem(
                    nome,
                    'R\$ ${val.toStringAsFixed(2).replaceAll('.', ',')}',
                    varPct,
                  );
                }),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: corPrimaria.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: corPrimaria,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sua evolução mensal é atualizada automaticamente a cada lançamento de transação no COGITO.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Item visual auxiliar para a lista de categorias no modal.
  Widget _buildCategoriaDetailItem(
    String nome,
    String valor,
    String pct,
    Color cor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nome,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Text(
            valor,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              pct,
              style: TextStyle(
                color: cor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Item visual auxiliar para comparativo mensal no modal.
  Widget _buildEvolucaoMonthItem(String mes, String valor, String varPct) {
    final bool isPos = varPct.startsWith('+');
    final Color corVar = varPct == 'Estável' || varPct == '0%'
        ? Colors.grey
        : (isPos ? Colors.red : Colors.green);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            mes,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Row(
            children: [
              Text(
                valor,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                varPct,
                style: TextStyle(
                  color: corVar,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String idCliente = FirebaseFirestoreService.idClienteAtual;

    final Color corPrimaria = AppColors.getPrimaryAccent(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.getOverlayStyleForBackground(corPrimaria),
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: corPrimaria,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Análise de Gastos & Relatórios',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestoreService.buscarTransacoesStream(idCliente),
          builder: (context, snapshot) {
            final DateTime agora = DateTime.now();
            final List<Map<String, dynamic>> transacoesBrutas =
                snapshot.data ?? [];

            // Aplica a filtragem reativa pelo período selecionado no Combo Box
            final List<Map<String, dynamic>> transacoes =
                _filtrarTransacoesPorPeriodo(transacoesBrutas);
            final List<Map<String, dynamic>> evolucaoMeses =
                _calcularEvolucaoUltimos4Meses(transacoesBrutas);

            double totalEntradas = 0.0;
            double totalSaidas = 0.0;
            final Map<String, double> categoriasMap = {};

            for (final t in transacoes) {
              final double val = (t['valor'] as num?)?.toDouble() ?? 0.0;
              final String tipo = t['tipo'] ?? 'Receita';
              final String cat = t['categoria'] ?? 'Outros';

              if (tipo == 'Receita') {
                totalEntradas += val;
              } else {
                totalSaidas += val;
                categoriasMap[cat] = (categoriasMap[cat] ?? 0.0) + val;
              }
            }

            final double balancoLiquido = totalEntradas - totalSaidas;

            // Determina a quantidade de dias proporcionais ao período selecionado
            final int diasPeriodo;
            switch (_selectedPeriodo) {
              case 'Este mês':
                diasPeriodo = agora.day > 0 ? agora.day : 1;
                break;
              case 'Mês passado':
                final int diasNoMesPassado =
                    DateTime(agora.year, agora.month, 0).day;
                diasPeriodo = diasNoMesPassado;
                break;
              case 'Últimos 3 meses':
                diasPeriodo = 90;
                break;
              case 'Este ano':
                final inicioAno = DateTime(agora.year, 1, 1);
                diasPeriodo = agora.difference(inicioAno).inDays + 1;
                break;
              case 'Todo o período':
              default:
                diasPeriodo = 365;
                break;
            }

            final double mediaDiaria = totalSaidas > 0
                ? (totalSaidas / (diasPeriodo > 0 ? diasPeriodo : 1))
                : 0.0;

            String maiorCategoriaNome = 'Nenhuma';
            double maiorCategoriaValor = 0.0;
            categoriasMap.forEach((k, v) {
              if (v > maiorCategoriaValor) {
                maiorCategoriaValor = v;
                maiorCategoriaNome = k;
              }
            });

            final List<PieChartSectionData> secoesCategorias = [];
            final List<Color> coresPie = [
              corPrimaria,
              AppColors.primaryOrange,
              Colors.purple,
              Colors.teal,
              Colors.pink,
              Colors.amber,
            ];

            int cIndex = 0;
            categoriasMap.forEach((cat, valor) {
              final double pct = totalSaidas > 0
                  ? (valor / totalSaidas * 100)
                  : 0;
              secoesCategorias.add(
                PieChartSectionData(
                  color: coresPie[cIndex % coresPie.length],
                  value: valor > 0 ? valor : 1,
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: 25,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              );
              cIndex++;
            });

            if (secoesCategorias.isEmpty) {
              secoesCategorias.add(
                PieChartSectionData(
                  color: Colors.grey.shade300,
                  value: 1,
                  title: '0%',
                  radius: 25,
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filtro de Período dos Relatórios com Combo Box estilizado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Período do Relatório:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                      _buildFiltroComboBox(),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Banner Superior Informativo (Limpo, sem sombra)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: corPrimaria,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.analytics_rounded,
                          size: 40,
                          color: AppColors.primaryYellow,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Relatório Inteligente de Gastos',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Balanço do Período: R\$ ${balancoLiquido.toStringAsFixed(2).replaceAll('.', ',')}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // SEÇÃO DE RESUMO DE BALANÇO (Entradas vs Saídas)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(
                              alpha: AppColors.isDarkMode(context) ? 0.15 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.arrow_upward_rounded,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Entradas',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'R\$ ${totalEntradas.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(
                              alpha: AppColors.isDarkMode(context) ? 0.15 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Saídas',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'R\$ ${totalSaidas.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  Text(
                    'Gráficos & Distribuição (Tempo Real)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // SEÇÃO DE GRÁFICOS LADO A LADO (ROW COM EXPANDED)
                  Row(
                    children: [
                      // GRÁFICO 1: PIZZA (CATEGORIAS)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _exibirModalGraficoCategorias(
                            context,
                            categoriasMap,
                            totalSaidas,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.getCardColor(context),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.pie_chart_outline,
                                      color: corPrimaria,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Categorias',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.getTextColor(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 110,
                                  child: PieChart(
                                    PieChartData(
                                      sections: secoesCategorias,
                                      centerSpaceRadius: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Ver detalhes ➔',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: corPrimaria,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // GRÁFICO 2: BARRAS (EVOLUÇÃO MENSAL)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _exibirModalGraficoEvolucao(
                            context,
                            evolucaoMeses,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.getCardColor(context),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.bar_chart,
                                      color: corPrimaria,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Evolução',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: corPrimaria,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 110,
                                  child: BarChart(
                                    BarChartData(
                                      borderData: FlBorderData(show: false),
                                      gridData: const FlGridData(show: false),
                                      titlesData: const FlTitlesData(
                                        show: false,
                                      ),
                                      barGroups: List.generate(
                                        evolucaoMeses.length,
                                        (idx) {
                                          final double v =
                                              evolucaoMeses[idx]['totalGasto']
                                                  as double;
                                          final bool isAtual =
                                              idx == evolucaoMeses.length - 1;
                                          return BarChartGroupData(
                                            x: idx,
                                            barRods: [
                                              BarChartRodData(
                                                toY: v > 0
                                                    ? (v / 100).clamp(
                                                        1.0,
                                                        100.0,
                                                      )
                                                    : 2,
                                                color: isAtual
                                                    ? AppColors.primaryOrange
                                                    : corPrimaria.withValues(
                                                        alpha: 0.3 + (idx * 0.15),
                                                      ),
                                                width: 10,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Ver histórico ➔',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: corPrimaria,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // SEÇÃO DE RELATÓRIOS EXECUTIVOS RECOMENDADOS & DIAGNÓSTICO CONRADO
                  Text(
                    'Relatórios & Diagnóstico CONRADO',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: corPrimaria,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.getCardColor(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildRelatorioRow(
                          'Média Diária de Gastos',
                          'R\$ ${mediaDiaria.toStringAsFixed(2).replaceAll('.', ',')} / dia',
                          Icons.today,
                          Colors.blue,
                        ),
                        Divider(height: 20, color: AppColors.getDividerColor(context)),
                        _buildRelatorioRow(
                          'Maior Categoria',
                          '$maiorCategoriaNome (R\$ ${maiorCategoriaValor.toStringAsFixed(2).replaceAll('.', ',')})',
                          Icons.restaurant,
                          Colors.orange,
                        ),
                        Divider(height: 20, color: AppColors.getDividerColor(context)),
                        _buildRelatorioRow(
                          'Projeção de Economia Potencial',
                          'R\$ ${(totalEntradas * 0.15).toStringAsFixed(2).replaceAll('.', ',')} ($_selectedPeriodo)',
                          Icons.savings,
                          Colors.green,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SEÇÃO DE TRANSAÇÕES FILTRADAS DO PERÍODO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transações do Período (${transacoes.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: corPrimaria,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: corPrimaria.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _selectedPeriodo,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: corPrimaria,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (transacoes.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.getCardColor(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 40,
                            color: AppColors.getSubtextColor(context),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Nenhuma transação encontrada no período "$_selectedPeriodo".',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getSubtextColor(context),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...transacoes.map((t) {
                      final String titulo =
                          t['titulo'] ?? t['descricao'] ?? 'Transação';
                      final String cat = t['categoria'] ?? 'Geral';
                      final String tipo = t['tipo'] ?? 'Despesa';
                      final double val =
                          (t['valor'] as num?)?.toDouble() ?? 0.0;
                      final bool isReceita = tipo == 'Receita';
                      final DateTime dt = _extrairData(t);
                      final String dataFormatada =
                          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.getCardColor(context),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isReceita
                                    ? Colors.green.withValues(
                                        alpha: AppColors.isDarkMode(context) ? 0.2 : 0.1,
                                      )
                                    : Colors.red.withValues(
                                        alpha: AppColors.isDarkMode(context) ? 0.2 : 0.1,
                                      ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isReceita
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                color: isReceita ? Colors.green : Colors.red,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titulo,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.getTextColor(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$cat • $dataFormatada',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.getSubtextColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isReceita ? '+' : '-'} R\$ ${val.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isReceita
                                    ? Colors.green
                                    : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Constrói cada linha dos relatórios executivos recomendados.
  Widget _buildRelatorioRow(
    String titulo,
    String valor,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(fontSize: 12, color: AppColors.getSubtextColor(context)),
              ),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
