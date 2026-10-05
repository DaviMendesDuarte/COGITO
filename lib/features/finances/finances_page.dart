import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/common/constant/text_styles.dart';
import 'package:cogito/common/utils/conrado_advice_helper.dart';
import 'package:cogito/common/utils/financial_utils.dart';
import 'package:cogito/features/conrado/conrado_chat_page.dart';
import 'package:cogito/features/finances/financial_goals_page.dart';
import 'package:cogito/services/app_settings_controller.dart';
import 'package:cogito/services/debug_mock_service.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:cogito/features/plans/plans_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Tela principal de Finanças do COGITO.
/// Estruturada com 3 abas principais integradas: "Extrato", "Orçamentos" e "Relatórios".
class FinancesPage extends StatefulWidget {
  /// Callback opcional para navegar entre as abas globais do app (ex: aba do Conrado).
  final void Function(int index)? onNavigateToTab;

  const FinancesPage({super.key, this.onNavigateToTab});

  @override
  FinancesPageState createState() => FinancesPageState();
}

/// Estado público para permitir que a HomePage acione ações da página de Finanças.
class FinancesPageState extends State<FinancesPage> {
  /// Controller da aba principal (0: Extrato, 1: Orçamentos, 2: Relatórios).
  int _mainTabIndex = 0;

  /// Retorna o índice da aba principal ativa.
  int get mainTabIndex => _mainTabIndex;

  /// Permite selecionar a aba principal programaticamente.
  void selecionarAba(int index) {
    if (mounted) {
      setState(() {
        _mainTabIndex = index;
      });
    }
  }

  /// Permite selecionar a aba de extrato programaticamente.
  void selecionarAbaExtrato() => selecionarAba(0);

  /// Permite selecionar a aba de orçamentos programaticamente.
  void selecionarAbaOrcamentos() => selecionarAba(1);

  /// Permite selecionar a aba de relatórios programaticamente.
  void selecionarAbaRelatorios() => selecionarAba(2);

  /// Permite navegar para a página de metas financeiras.
  void selecionarAbaMetas() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MetasFinanceirasPage()),
    );
  }

  /// Instância do serviço Firebase Firestore.
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  /// Controller para o campo de busca de transações.
  final TextEditingController _searchController = TextEditingController();

  /// Filtro de categoria selecionado ("Todas as categorias" por padrão).
  String _selectedCategoryFilter = 'Todas as categorias';

  /// Filtro de período selecionado ("Este mês" por padrão).
  String _selectedPeriodoFilter = 'Este mês';

  /// Período selecionado na aba de Relatórios ('1D', '1S', '1M', '3M', '1A').
  String _periodoRelatorio = '1M';

  /// Limite mensal de gastos ajustável pelo Slider que desliza com o dedo na aba de Relatórios.
  double _limiteMensal = 2500.0;

  /// Mês de referência selecionado para cálculo e acompanhamento dos orçamentos.
  DateTime _mesOrcamentoSelecionado = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  /// Indica se é possível avançar para o próximo mês (bloqueia meses futuros além do mês atual).
  bool get _podeAvancarMesOrcamento {
    final DateTime agora = DateTime.now();
    final DateTime mesAtual = DateTime(agora.year, agora.month);
    return _mesOrcamentoSelecionado.isBefore(mesAtual);
  }

  /// Avança para o próximo mês na tela de Orçamentos, limitado rigorosamente até o mês atual.
  void _proximoMesOrcamento() {
    if (!_podeAvancarMesOrcamento) return;
    final DateTime proximo = DateTime(
      _mesOrcamentoSelecionado.year,
      _mesOrcamentoSelecionado.month + 1,
    );
    final DateTime agora = DateTime.now();
    final DateTime mesAtual = DateTime(agora.year, agora.month);
    if (!proximo.isAfter(mesAtual)) {
      setState(() {
        _mesOrcamentoSelecionado = proximo;
      });
    }
  }

  /// Retrocede para o mês anterior na tela de Orçamentos.
  void _mesAnteriorOrcamento() {
    setState(() {
      _mesOrcamentoSelecionado = DateTime(
        _mesOrcamentoSelecionado.year,
        _mesOrcamentoSelecionado.month - 1,
      );
    });
  }

  /// Retorna o nome formatado do mês e ano em português (ex: "Outubro de 2026").
  String _formatarMesAnoOrcamento(DateTime data) {
    const List<String> nomesMeses = [
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
    final String mes = nomesMeses[data.month - 1];
    return '$mes de ${data.year}';
  }

  /// Controla a visibilidade dos campos de busca e filtros no extrato.
  bool _mostrarFiltros = false;

  /// Modo de visualização do extrato ('list': Lista, 'grid': Grade, 'table': Tabela).
  String _viewMode = 'list';

  /// Extrai com segurança a data [DateTime] de uma transação via [FinancialUtils].
  DateTime _extrairData(Map<String, dynamic> t) =>
      FinancialUtils.extrairDataTransacao(t);

  /// Filtra a lista de transações conforme o período selecionado via [FinancialUtils].
  List<Map<String, dynamic>> _filtrarTransacoesPorPeriodo(
    List<Map<String, dynamic>> lista,
  ) {
    return FinancialUtils.filtrarTransacoesPorPeriodo(
      lista,
      _selectedPeriodoFilter,
    );
  }

  @override
  void initState() {
    super.initState();
    // Escuta alterações na alternância do modo mock para atualizar o extrato e relatórios imediatamente
    DebugMockService.instance.modoMockAtivoNotifier.addListener(_onMockChanged);
    // Escuta alterações de tema (modo claro/escuro) para atualização visual instantânea
    AppSettingsController.instance.addListener(_onThemeChanged);
  }

  /// Atualiza a interface da página quando o tema escuro ou claro é alterado.
  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  /// Atualiza a interface da página quando a versão mock é ativada ou desativada.
  void _onMockChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DebugMockService.instance.modoMockAtivoNotifier.removeListener(_onMockChanged);
    AppSettingsController.instance.removeListener(_onThemeChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Exibe modal com validação estrita para criação de uma nova transação (Receita ou Despesa).
  /// Método público acessível globalmente via [financasPageKey].
  void exibirDialogoNovaTransacao({String tipoInicial = 'Despesa'}) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    // Lista de categorias segmentadas por tipo de movimentação
    final List<String> categoriasReceitas = [
      'Receita',
      'Trabalho',
      'Freelance',
      'Mesada',
      'Salário',
      'Investimentos',
      'Outros',
    ];
    final List<String> categoriasDespesas = [
      'Alimentação',
      'Moradia',
      'Transporte',
      'Lazer',
      'Saúde',
      'Educação',
      'Compras',
      'Outros',
    ];

    String tipo = tipoInicial;
    String categoria = tipoInicial == 'Receita' ? 'Trabalho' : 'Alimentação';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final List<String> listaCategoriasAtuais =
                tipo == 'Receita' ? categoriasReceitas : categoriasDespesas;
            if (!listaCategoriasAtuais.contains(categoria)) {
              categoria = listaCategoriasAtuais.first;
            }

            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).viewPadding.bottom +
                    24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Alça visual do modal
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Text(
                      'Nova Transação',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getPrimaryAccent(context),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Seleção de Tipo (Despesa / Receita)
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'Despesa',
                          label: Text('Despesa'),
                          icon: Icon(Icons.arrow_downward, color: Colors.red),
                        ),
                        ButtonSegment(
                          value: 'Receita',
                          label: Text('Receita'),
                          icon: Icon(Icons.arrow_upward, color: Colors.green),
                        ),
                      ],
                      selected: {tipo},
                      onSelectionChanged: (val) {
                        setModalState(() {
                          tipo = val.first;
                          if (tipo == 'Receita') {
                            categoria = 'Trabalho';
                          } else {
                            categoria = 'Alimentação';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    // Descrição da Transação com validação de preenchimento
                    TextFormField(
                      controller: titleController,
                      style: TextStyle(color: AppColors.getTextColor(context)),
                      decoration: InputDecoration(
                        labelText: 'Descrição (Ex: iFood, Freelance Site, Mesada)',
                        filled: true,
                        fillColor: AppColors.getInputFillColor(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Informe a descrição da transação';
                        }
                        if (v.trim().length < 2) {
                          return 'A descrição deve ter pelo menos 2 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Valor em Reais com validação estrita maior que zero
                    TextFormField(
                      controller: amountController,
                      style: TextStyle(color: AppColors.getTextColor(context)),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Valor (R\$)',
                        filled: true,
                        fillColor: AppColors.getInputFillColor(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Informe o valor da transação';
                        }
                        final val = double.tryParse(v.replaceAll(',', '.').trim()) ?? 0.0;
                        if (val <= 0) {
                          return 'O valor deve ser maior que R\$ 0,00';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Seleção de Categoria adaptada dinamicamente ao tipo selecionado
                    DropdownButtonFormField<String>(
                      initialValue: listaCategoriasAtuais.contains(categoria)
                          ? categoria
                          : listaCategoriasAtuais.first,
                      dropdownColor: AppColors.getCardColor(context),
                      style: TextStyle(color: AppColors.getTextColor(context)),
                      decoration: InputDecoration(
                        labelText: 'Categoria / Fonte',
                        filled: true,
                        fillColor: AppColors.getInputFillColor(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: listaCategoriasAtuais
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c,
                                style: TextStyle(
                                  color: AppColors.getTextColor(context),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            categoria = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Botão para salvar transação no Firestore após validação completa
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        final val = double.parse(
                          amountController.text.replaceAll(',', '.').trim(),
                        );
                        final String uid = FirebaseFirestoreService.idClienteAtual;

                        Navigator.pop(modalCtx);

                        await _firestoreService.adicionarTransacao(
                          idCliente: uid,
                          titulo: titleController.text.trim(),
                          valor: val,
                          categoria: categoria,
                          tipo: tipo,
                          data: DateTime.now(),
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 10),
                                  Text('Transação salva com sucesso!'),
                                ],
                              ),
                              backgroundColor: Colors.green.shade600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.getPrimaryAccent(context),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'SALVAR TRANSAÇÃO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Exibe diálogo de confirmação seguro antes de realizar a exclusão de qualquer transação.
  Future<bool> _confirmarExclusaoTransacao(BuildContext context) async {
    final bool isDark = AppColors.isDarkMode(context);
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Excluir Transação',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppColors.getTextColor(context),
              ),
            ),
          ],
        ),
        content: Text(
          'Você tem certeza de que deseja excluir esta transação?',
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: AppColors.getTextColor(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  /// Exibe o leitor inteligente de Nota Fiscal, Cupom Fiscal e Código de Barras (OCR simulado),
  /// permitindo escanear comprovantes ou boletos com a câmera para cadastrar transações automaticamente.
  void _exibirScannerNotaFiscal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        bool isScanning = false;
        return StatefulBuilder(
          builder: (modalCtx, setScannerState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom +
                    MediaQuery.of(modalCtx).viewPadding.bottom +
                    24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.getPrimaryAccent(context),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Scanner de Comprovante & Código',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getPrimaryAccent(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aponte para o Cupom Fiscal (NFC-e), Recibo ou Código de Barras de Boleto',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getSubtextColor(context),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Moldura visual do Viewfinder do Scanner
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 170,
                          height: 130,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.getPrimaryAccent(context).withValues(alpha: 0.8),
                              width: 2.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.receipt_long_rounded,
                              size: 44,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 80,
                          child: Container(
                            width: 160,
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.primaryYellow,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryYellow.withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          child: Text(
                            isScanning ? 'Processando dados via OCR COGITO...' : 'Enquadre o comprovante ou código',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Ações de Escaneamento
                  ElevatedButton.icon(
                    onPressed: isScanning
                        ? null
                        : () async {
                            setScannerState(() => isScanning = true);
                            await Future.delayed(const Duration(milliseconds: 900));
                            if (!modalCtx.mounted) return;
                            Navigator.pop(modalCtx);
                            _confirmarNotaFiscalEscaneada(
                              titulo: 'Supermercado Pão de Açúcar',
                              valor: 84.90,
                              categoria: 'Alimentação',
                              itens: '2x Pão Francês • 1x Leite • 1x Café • Frutas',
                            );
                          },
                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
                    label: const Text(
                      'Escanear com Câmera (Simular NFC-e)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.getPrimaryAccent(context),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isScanning
                              ? null
                              : () async {
                                  setScannerState(() => isScanning = true);
                                  await Future.delayed(const Duration(milliseconds: 700));
                                  if (!modalCtx.mounted) return;
                                  Navigator.pop(modalCtx);
                                  _confirmarNotaFiscalEscaneada(
                                    titulo: 'Farmácia Drogasil',
                                    valor: 46.50,
                                    categoria: 'Saúde',
                                    itens: 'Medicamentos e Higiene',
                                  );
                                },
                          icon: Icon(Icons.photo_library_outlined, size: 18, color: AppColors.getPrimaryAccent(context)),
                          label: Text(
                            'Importar Galeria',
                            style: TextStyle(color: AppColors.getPrimaryAccent(context), fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.getPrimaryAccent(context)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isScanning
                              ? null
                              : () async {
                                  setScannerState(() => isScanning = true);
                                  await Future.delayed(const Duration(milliseconds: 700));
                                  if (!modalCtx.mounted) return;
                                  Navigator.pop(modalCtx);
                                  _confirmarNotaFiscalEscaneada(
                                    titulo: 'Boleto Enel Energia',
                                    valor: 135.20,
                                    categoria: 'Moradia',
                                    itens: 'Conta de Energia Elétrica',
                                  );
                                },
                          icon: Icon(Icons.barcode_reader, size: 18, color: AppColors.getPrimaryAccent(context)),
                          label: Text(
                            'Código de Barras',
                            style: TextStyle(color: AppColors.getPrimaryAccent(context), fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.getPrimaryAccent(context)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Diálogo de confirmação para salvar a transação extraída pelo leitor de nota fiscal.
  void _confirmarNotaFiscalEscaneada({
    required String titulo,
    required double valor,
    required String categoria,
    required String itens,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.getPrimaryAccent(context)),
            const SizedBox(width: 8),
            const Text('Comprovante Reconhecido'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Valor: R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
              style: TextStyle(
                color: AppColors.getPrimaryAccent(context),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text('Categoria: $categoria', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.getInputFillColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Itens detectados:\n$itens',
                style: TextStyle(fontSize: 11.5, color: AppColors.getSubtextColor(context)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Descartar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final String uid = FirebaseFirestoreService.idClienteAtual;
              await _firestoreService.adicionarTransacao(
                idCliente: uid,
                titulo: titulo,
                valor: valor,
                categoria: categoria,
                tipo: 'Despesa',
                data: DateTime.now(),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Transação de "$titulo" cadastrada com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getPrimaryAccent(context),
              elevation: 0,
            ),
            child: const Text('Cadastrar no Extrato', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Configura a barra de status e estrutura o layout da tela com cabeçalho e 3 abas
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.getOverlayStyleForBackground(
        AppColors.getPrimaryAccent(context),
      ),
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        body: Column(
          children: [
            // Cabeçalho da Tela com 3 Abas Principais (Extrato, Orçamentos, Relatórios)
            _buildHeader(context),

            // Conteúdo principal alternado pelas abas
            Expanded(
              child: _mainTabIndex == 0
                  ? _buildExtratoSection()
                  : (_mainTabIndex == 1
                      ? _buildOrcamentosSection()
                      : _buildRelatoriosSection()),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói o cabeçalho superior adaptativo (azul no tema claro, laranja no tema escuro)
  /// com bordas retas e botões das 3 abas principais no estilo TabBar.
  Widget _buildHeader(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.getPrimaryAccent(context),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Text(
                'Gestão Financeira',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Seletor de 3 Abas Principais: Extrato, Orçamentos e Relatórios
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _buildMainTabButton(
                  titulo: 'Extrato',
                  icon: Icons.receipt_long_outlined,
                  index: 0,
                ),
              ),
              Expanded(
                child: _buildMainTabButton(
                  titulo: 'Orçamentos',
                  icon: Icons.pie_chart_outline,
                  index: 1,
                ),
              ),
              Expanded(
                child: _buildMainTabButton(
                  titulo: 'Relatórios',
                  icon: Icons.donut_large_outlined,
                  index: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Constrói o botão individual da aba principal com ícone, texto e sublinhado amarelo reto.
  Widget _buildMainTabButton({
    required String titulo,
    required IconData icon,
    required int index,
  }) {
    final bool isSelected = _mainTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _mainTabIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? Colors.white : Colors.white70,
          ),
          const SizedBox(height: 4),
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          // Indicador sublinhado amarelo reto em destaque para a aba ativa
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: isSelected ? 48 : 0,
            decoration: const BoxDecoration(
              color: AppColors.primaryYellow,
              borderRadius: BorderRadius.zero,
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói a seção de EXTRATO de transações com atalho direto para a Análise de Gastos.
  Widget _buildExtratoSection() {
    return _buildTransacoesSection();
  }

  /// Constrói a aba de TRANSAÇÕES inteiramente conectada ao Firestore em tempo real ou dados mock.
  Widget _buildTransacoesSection() {
    final String uid = FirebaseFirestoreService.idClienteAtual;
    final bool isMock = DebugMockService.instance.modoMockAtivo;
    final List<Map<String, dynamic>> mockData =
        isMock ? DebugMockService.instance.transacoesMock : [];

    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('extrato_stream_${isMock}_$uid'),
      initialData: isMock ? mockData : null,
      stream: isMock
          ? DebugMockService.instance.transacoesStream
          : _firestoreService.ouvirTransacoes(uid),
      builder: (context, snapshot) {
        // Garante exibição instantânea e reativa dos dados no modo mock
        final List<Map<String, dynamic>> rawTransacoes =
            (snapshot.data != null && snapshot.data!.isNotEmpty)
                ? snapshot.data!
                : (isMock ? mockData : (snapshot.data ?? []));

        // Aplica o filtro de período ativo antes de calcular os totais
        final List<Map<String, dynamic>> transacoesNoPeriodo =
            _filtrarTransacoesPorPeriodo(rawTransacoes);

        // Cálculo dinâmico das totais de Receitas e Despesas baseado no período selecionado
        double totalReceitas = 0.0;
        double totalDespesas = 0.0;

        for (final t in transacoesNoPeriodo) {
          final double val = (t['valor'] as num?)?.toDouble() ?? 0.0;
          if (t['tipo'] == 'Receita') {
            totalReceitas += val;
          } else {
            totalDespesas += val;
          }
        }

        // Filtragem adicional por busca de texto e categoria
        List<Map<String, dynamic>> transacoesFiltradas = List.from(
          transacoesNoPeriodo,
        );

        if (_searchController.text.trim().isNotEmpty) {
          final query = _searchController.text.trim().toLowerCase();
          transacoesFiltradas = transacoesFiltradas.where((t) {
            final titulo = (t['titulo'] ?? '').toString().toLowerCase();
            final cat = (t['categoria'] ?? '').toString().toLowerCase();
            return titulo.contains(query) || cat.contains(query);
          }).toList();
        }

        if (_selectedCategoryFilter != 'Todas as categorias') {
          transacoesFiltradas = transacoesFiltradas.where((t) {
            return t['categoria'] == _selectedCategoryFilter;
          }).toList();
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          children: [
            // 1. Card Superior com Saldo Atual (Current Balance) e 4 Ações Rápidas (Estilo Imagem 2)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.getCardColor(context),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saldo Atual ($_selectedPeriodoFilter)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.getSubtextColor(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'R\$ ${(totalReceitas - totalDespesas).toStringAsFixed(2).replaceAll('.', ',')}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextColor(context),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (totalReceitas >= totalDespesas ? Colors.green : Colors.redAccent).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              totalReceitas >= totalDespesas ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 14,
                              color: totalReceitas >= totalDespesas ? Colors.green : Colors.redAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              totalReceitas >= totalDespesas ? 'Positivo' : 'Atenção',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: totalReceitas >= totalDespesas ? Colors.green : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Receitas: +R\$ ${totalReceitas.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(fontSize: 11.5, color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Despesas: -R\$ ${totalDespesas.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: TextStyle(fontSize: 11.5, color: AppColors.getPrimaryAccent(context), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Divider(height: 1, color: AppColors.getDividerColor(context)),
                  const SizedBox(height: 14),

                  // 4 Botões de Ação Rápida em Linha Horizontal (Imagem 2)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickActionButton(
                        icon: Icons.add,
                        label: 'Entrada',
                        color: Colors.green,
                        onTap: () => exibirDialogoNovaTransacao(tipoInicial: 'Receita'),
                      ),
                      _buildQuickActionButton(
                        icon: Icons.arrow_outward_rounded,
                        label: 'Saída',
                        color: AppColors.getPrimaryAccent(context),
                        onTap: () => exibirDialogoNovaTransacao(tipoInicial: 'Despesa'),
                      ),
                      _buildQuickActionButton(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Ler Nota',
                        color: AppColors.getPrimaryAccent(context),
                        destacado: true,
                        onTap: _exibirScannerNotaFiscal,
                      ),
                      _buildQuickActionButton(
                        icon: Icons.tune_rounded,
                        label: 'Filtros',
                        color: AppColors.getSubtextColor(context),
                        onTap: () => setState(() => _mostrarFiltros = !_mostrarFiltros),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Barra de Busca e Filtros Condicionais
            if (_mostrarFiltros) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.getCardColor(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // Campo "Buscar transação..."
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: AppColors.getTextColor(context)),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar transação...',
                      hintStyle: TextStyle(
                        color: AppColors.getSubtextColor(context),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.getSubtextColor(context),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      filled: true,
                      fillColor: AppColors.getInputFillColor(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Linha com Seletores Dropdown de Categoria e Período (com isExpanded para evitar overflow)
                  Row(
                    children: [
                      // Seletor de Categoria
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryFilter,
                          dropdownColor: AppColors.getCardColor(context),
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: AppColors.getInputFillColor(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items:
                              [
                                    'Todas as categorias',
                                    'Alimentação',
                                    'Moradia',
                                    'Transporte',
                                    'Lazer',
                                    'Receita',
                                    'Outros',
                                  ]
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                        c,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.getTextColor(context),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCategoryFilter = val;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Seletor de Período
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedPeriodoFilter,
                          dropdownColor: AppColors.getCardColor(context),
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: AppColors.getInputFillColor(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items:
                              [
                                    'Este mês',
                                    'Últimos 30 dias',
                                    'Últimos 3 meses',
                                    'Este ano',
                                    'Todo o período',
                                  ]
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(
                                        p,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.getTextColor(context),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedPeriodoFilter = val;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

            // 3. Cabeçalho da Lista ("Transações", Botões de Alternância Lista/Grade/Tabela e Exportar)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transações (${transacoesFiltradas.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                Row(
                  children: [
                    // Botões de alternância Lista / Grade / Tabela sem contorno
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.getCardColor(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.view_list_rounded,
                              size: 20,
                              color: _viewMode == 'list'
                                  ? AppColors.getPrimaryAccent(context)
                                  : Colors.grey,
                            ),
                            onPressed: () => setState(() => _viewMode = 'list'),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: 'Visualizar em Lista',
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.grid_view_rounded,
                              size: 20,
                              color: _viewMode == 'grid'
                                  ? AppColors.getPrimaryAccent(context)
                                  : Colors.grey,
                            ),
                            onPressed: () => setState(() => _viewMode = 'grid'),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: 'Visualizar em Grade',
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.table_chart_outlined,
                              size: 20,
                              color: _viewMode == 'table'
                                  ? AppColors.getPrimaryAccent(context)
                                  : Colors.grey,
                            ),
                            onPressed: () =>
                                setState(() => _viewMode = 'table'),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: 'Visualizar em Tabela',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Botão "Exportar" em Laranja
                    InkWell(
                      onTap: () =>
                          _exibirModalExportar(context, transacoesFiltradas),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.file_download_outlined,
                            color: AppColors.primaryOrange,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Exportar',
                            style: TextStyle(
                              color: AppColors.primaryOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 5. Lista de Transações (Lista, Grade ou Tabela)
            if (transacoesFiltradas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Nenhuma transação encontrada.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else if (_viewMode == 'table')
              _buildTableView(transacoesFiltradas)
            else if (_viewMode == 'grid')
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                itemCount: transacoesFiltradas.length,
                itemBuilder: (context, index) {
                  final t = transacoesFiltradas[index];
                  return _buildGridTransactionCard(t);
                },
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transacoesFiltradas.length,
                itemBuilder: (context, index) {
                  final t = transacoesFiltradas[index];
                  final String firestoreId = t['firestore_id'] ?? '';

                  return Dismissible(
                    key: Key(
                      firestoreId.isEmpty ? index.toString() : firestoreId,
                    ),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        // Deslizar para a DIREITA -> Editar Transação
                        _exibirDialogoEditarTransacao(t);
                        return false;
                      } else {
                        // Deslizar para a ESQUERDA -> Confirmação antes de excluir
                        final bool confirmar = await _confirmarExclusaoTransacao(context);
                        return confirmar;
                      }
                    },
                    onDismissed: (direction) async {
                      if (direction == DismissDirection.endToStart) {
                        final String idReal = firestoreId.isNotEmpty
                            ? firestoreId
                            : (t['id'] ?? '').toString();
                        if (idReal.isNotEmpty) {
                          // Exclui a transação e atualiza orçamentos e metas instantaneamente
                          await _firestoreService.excluirTransacao(idReal);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Transação excluída.'),
                              backgroundColor: Colors.red.shade400,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.edit, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Editar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    secondaryBackground: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Excluir',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.delete, color: Colors.white),
                        ],
                      ),
                    ),
                    child: _buildListTransactionCard(t),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  /// Exibe caixa de diálogo com validação estrita para edição dos dados de uma transação existente.
  ///
  /// Parâmetros:
  /// - [transacao]: Mapa contendo os dados atuais da transação a ser editada.
  void _exibirDialogoEditarTransacao(Map<String, dynamic> transacao) {
    final formKey = GlobalKey<FormState>();
    final tituloController = TextEditingController(
      text: transacao['titulo'] ?? '',
    );
    final valorController = TextEditingController(
      text: (transacao['valor'] as num?)?.toStringAsFixed(2) ?? '',
    );
    String categoriaSelecionada = transacao['categoria'] ?? 'Alimentação';
    String tipoSelecionado = transacao['tipo'] ?? 'Despesa';

    final categorias = [
      'Alimentação',
      'Moradia',
      'Transporte',
      'Lazer',
      'Saúde',
      'Educação',
      'Compras',
      'Trabalho',
      'Freelance',
      'Mesada',
      'Salário',
      'Investimentos',
      'Receita',
      'Outros',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.getCardColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: AppColors.getPrimaryAccent(context)),
                  const SizedBox(width: 8),
                  Text('Editar Transação', style: TextStyle(color: AppColors.getTextColor(context))),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Descrição com validação
                      TextFormField(
                        controller: tituloController,
                        style: TextStyle(color: AppColors.getTextColor(context)),
                        decoration: InputDecoration(
                          labelText: 'Descrição / Título',
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Informe a descrição';
                          if (v.trim().length < 2) return 'Descrição muito curta';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Valor com validação estrita
                      TextFormField(
                        controller: valorController,
                        style: TextStyle(color: AppColors.getTextColor(context)),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Valor (R\$)',
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Informe o valor';
                          final val = double.tryParse(v.replaceAll(',', '.').trim()) ?? 0.0;
                          if (val <= 0) return 'O valor deve ser maior que R\$ 0,00';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Categoria / Fonte
                      DropdownButtonFormField<String>(
                        initialValue: categorias.contains(categoriaSelecionada)
                            ? categoriaSelecionada
                            : 'Outros',
                        dropdownColor: AppColors.getCardColor(context),
                        style: TextStyle(color: AppColors.getTextColor(context)),
                        decoration: InputDecoration(
                          labelText: 'Categoria / Fonte',
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: categorias
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: AppColors.getTextColor(context)))),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => categoriaSelecionada = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Tipo da transação
                      DropdownButtonFormField<String>(
                        initialValue: tipoSelecionado,
                        dropdownColor: AppColors.getCardColor(context),
                        style: TextStyle(color: AppColors.getTextColor(context)),
                        decoration: InputDecoration(
                          labelText: 'Tipo',
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Receita',
                            child: Text('Receita (+)'),
                          ),
                          DropdownMenuItem(
                            value: 'Despesa',
                            child: Text('Despesa (-)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => tipoSelecionado = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final String novoTitulo = tituloController.text.trim();
                    final double novoValor = double.parse(
                      valorController.text.replaceAll(',', '.').trim(),
                    );

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    final String firestoreId =
                        (transacao['firestore_id'] ?? transacao['id'] ?? '').toString();
                    if (firestoreId.isNotEmpty) {
                      await _firestoreService.atualizarTransacao(
                        transacaoId: firestoreId,
                        titulo: novoTitulo,
                        valor: novoValor,
                        categoria: categoriaSelecionada,
                        tipo: tipoSelecionado,
                      );
                    }
                    if (mounted) {
                      setState(() {});
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Transação atualizada com sucesso!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getPrimaryAccent(context),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Salvar Alterações', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Exibe o modal para exportação real do extrato financeiro nos formatos CSV, PDF/Texto, TXT e JSON.
  /// No plano Grátis, exibe convite para os planos Freelancer ou Premium onde a exportação é liberada.
  void _exibirModalExportar(
    BuildContext context, [
    List<Map<String, dynamic>>? listaTransacoes,
  ]) {
    final usuario = FirebaseFirestoreService.usuarioLogado;
    final String plano = usuario?['plano'] ?? 'Grátis';
    final bool isGratis = plano == 'Grátis' && !DebugMockService.instance.modoMockAtivo;

    if (isGratis) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.getCardColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_outline, color: AppColors.primaryOrange),
              const SizedBox(width: 8),
              Text(
                'Recurso Exclusivo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ],
          ),
          content: Text(
            'A exportação de extratos em PDF, planilhas e relatórios é uma funcionalidade exclusiva dos planos Freelancer e Premium.\n\nFaça um upgrade e tenha controle total do seu histórico financeiro!',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              color: AppColors.getTextColor(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Agora não'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                PlanosModal.exibir(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Conhecer Planos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final List<Map<String, dynamic>> transacoes =
        listaTransacoes ?? _firestoreService.cacheTransacoesLocal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewPadding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                'Exportar Extrato Financeiro',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getPrimaryAccent(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Exportando ${transacoes.length} lançamentos ($_selectedPeriodoFilter):',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(
                  Icons.table_view_outlined,
                  color: Colors.green,
                  size: 28,
                ),
                title: const Text(
                  'Microsoft Excel / Google Planilhas (.CSV)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Estrutura de colunas com Data, Categoria, Título e Valor',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _gerarEProcessarExportacao(
                    'CSV',
                    _gerarConteudoCSV(transacoes),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Colors.red,
                  size: 28,
                ),
                title: const Text(
                  'Relatório Financeiro Formatado (.PDF / Texto)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Relatório executivo estruturado com balanço e categorias',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _gerarEProcessarExportacao(
                    'PDF / Relatório Formatado',
                    _gerarConteudoRelatorio(transacoes),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: Colors.blue,
                  size: 28,
                ),
                title: const Text(
                  'Texto Simples (.TXT)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Extrato limpo para anotações e compartilhamento rápido',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _gerarEProcessarExportacao(
                    'TXT',
                    _gerarConteudoTXT(transacoes),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.code_outlined,
                  color: Colors.purple,
                  size: 28,
                ),
                title: const Text(
                  'Dados Estruturados (.JSON)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'JSON válido com metadados para desenvolvedores e integrações',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _gerarEProcessarExportacao(
                    'JSON',
                    _gerarConteudoJSON(transacoes),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Gera string no formato CSV a partir da lista de transações via [FinancialUtils].
  String _gerarConteudoCSV(List<Map<String, dynamic>> transacoes) {
    return FinancialUtils.gerarExtratoCSV(transacoes);
  }

  /// Gera relatório executivo detalhado em formato de texto via [FinancialUtils].
  String _gerarConteudoRelatorio(List<Map<String, dynamic>> transacoes) {
    return FinancialUtils.gerarRelatorioExecutivo(
      transacoes,
      _selectedPeriodoFilter,
    );
  }

  /// Gera arquivo de texto simples para cópia rápida.
  String _gerarConteudoTXT(List<Map<String, dynamic>> transacoes) {
    final buffer = StringBuffer();
    buffer.writeln('EXTRATO COGITO - $_selectedPeriodoFilter');
    for (final t in transacoes) {
      final dt = _extrairData(t);
      final dataStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
      final val = ((t['valor'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
      buffer.writeln(
        '$dataStr - ${t['titulo']} (${t['categoria']}): R\$ $val [${t['tipo']}]',
      );
    }
    return buffer.toString();
  }

  /// Gera estrutura JSON formatada via [FinancialUtils].
  String _gerarConteudoJSON(List<Map<String, dynamic>> transacoes) {
    return FinancialUtils.gerarExtratoJSON(transacoes, _selectedPeriodoFilter);
  }

  /// Copia o conteúdo para a área de transferência e abre modal de pré-visualização e confirmação.
  void _gerarEProcessarExportacao(String formato, String conteudo) {
    Clipboard.setData(ClipboardData(text: conteudo));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).viewPadding.bottom +
              24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.green, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Exportação Gerada ($formato)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.getPrimaryAccent(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'O conteúdo foi copiado para a Área de Transferência com sucesso. Você pode colar onde desejar ou visualizar o conteúdo abaixo:',
              style: TextStyle(fontSize: 12, color: AppColors.getSubtextColor(context)),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.getInputFillColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  conteudo,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.getTextColor(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: conteudo));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Conteúdo do $formato copiado novamente!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.copy, color: Colors.white, size: 18),
              label: const Text(
                'Copiar Novamente',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getPrimaryAccent(context),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói a visualização do extrato em formato de Tabela de Dados (DataTable).
  Widget _buildTableView(List<Map<String, dynamic>> transacoes) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            AppColors.getPrimaryAccent(context).withValues(alpha: 0.1),
          ),
          columns: [
            DataColumn(
              label: Text(
                'Data',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getPrimaryAccent(context),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Categoria',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getPrimaryAccent(context),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Descrição',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getPrimaryAccent(context),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Tipo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getPrimaryAccent(context),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Valor',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getPrimaryAccent(context),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Ações',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getPrimaryAccent(context),
                ),
              ),
            ),
          ],
          rows: transacoes.map((t) {
            final DateTime dt = t['data_dt'] ?? DateTime.now();
            final String dataStr =
                '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
            final bool isReceita = t['tipo'] == 'Receita';
            final double val = (t['valor'] as num?)?.toDouble() ?? 0.0;

            return DataRow(
              cells: [
                DataCell(Text(dataStr, style: const TextStyle(fontSize: 12))),
                DataCell(
                  Text(
                    t['categoria'] ?? '-',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Text(
                    t['titulo'] ?? '-',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isReceita
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isReceita ? 'Receita' : 'Despesa',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isReceita ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${isReceita ? '+' : '-'} R\$ ${val.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isReceita ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.getPrimaryAccent(context),
                        ),
                        onPressed: () => _exibirDialogoEditarTransacao(t),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          final bool confirmar = await _confirmarExclusaoTransacao(context);
                          if (!confirmar) return;
                          final String firestoreId = t['firestore_id'] ?? '';
                          if (firestoreId.isNotEmpty &&
                              !firestoreId.startsWith('mock_')) {
                            await _firestoreService.excluirTransacao(
                              firestoreId,
                            );
                          }
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }


  /// Constrói cada card de transação na lista com design limpo sem contorno e sem sombra.
  Widget _buildListTransactionCard(Map<String, dynamic> t) {
    final String titulo = t['titulo'] ?? 'Transação';
    final bool isDespesa = t['tipo'] == 'Despesa';
    final double valor = (t['valor'] as num?)?.toDouble() ?? 0.0;
    final String categoria = t['categoria'] ?? 'Outros';
    final DateTime data = t['data_dt'] as DateTime? ?? DateTime.now();

    // Formatação amigável da data ("Hoje", "Ontem" ou "02 de ago.")
    final String dataStr = _formatarDataAmigavel(data);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Ícone em container suave
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.isDarkMode(context)
                  ? AppColors.darkInputFill
                  : const Color(0xFFEDF2F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _obterIconeCategoria(categoria),
              color: AppColors.getPrimaryAccent(context),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Título e Categoria • Data
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$categoria  •  $dataStr',
                  style: TextStyle(color: AppColors.getSubtextColor(context), fontSize: 12),
                ),
              ],
            ),
          ),

          // Valor em destaque
          Text(
            '${isDespesa ? "- " : "+ "}R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
            style: TextStyle(
              color: isDespesa
                  ? AppColors.getPrimaryAccent(context)
                  : const Color(0xFF1976D2),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói o card individual quando exibido no modo Grade sem contorno.
  Widget _buildGridTransactionCard(Map<String, dynamic> t) {
    final String titulo = t['titulo'] ?? 'Transação';
    final bool isDespesa = t['tipo'] == 'Despesa';
    final double valor = (t['valor'] as num?)?.toDouble() ?? 0.0;
    final String categoria = t['categoria'] ?? 'Outros';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.isDarkMode(context)
                  ? AppColors.darkInputFill
                  : const Color(0xFFEDF2F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _obterIconeCategoria(categoria),
              color: AppColors.getPrimaryAccent(context),
              size: 20,
            ),
          ),
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.getTextColor(context),
            ),
          ),
          Text(
            '${isDespesa ? "- " : "+ "}R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
            style: TextStyle(
              color: isDespesa
                  ? AppColors.getPrimaryAccent(context)
                  : const Color(0xFF1976D2),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói um botão de ação rápida circular / arredondado (Entrada, Saída, Ler Nota, Filtros)
  /// no estilo moderno da Imagem 2.
  ///
  /// Parâmetros:
  /// - [icon]: Ícone a ser exibido dentro do botão.
  /// - [label]: Rótulo explicativo da ação abaixo do botão.
  /// - [color]: Cor temática do ícone ou fundo do botão.
  /// - [destacado]: Define se o botão possui preenchimento total de destaque.
  /// - [onTap]: Ação executada ao clicar no botão.
  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    bool destacado = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: destacado
                  ? color
                  : (AppColors.isDarkMode(context)
                      ? AppColors.darkInputFill
                      : const Color(0xFFF1F5F9)),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                color: destacado ? Colors.white : color,
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextColor(context),
            ),
          ),
        ],
      ),
    );
  }


  /// Formata a data para exibir "Hoje", "Ontem" ou a data amigável.
  String _formatarDataAmigavel(DateTime dt) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dataTrans = DateTime(dt.year, dt.month, dt.day);

    if (dataTrans == hoje) return 'Hoje';
    if (dataTrans == hoje.subtract(const Duration(days: 1))) return 'Ontem';

    final meses = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];
    return '${dt.day.toString().padLeft(2, '0')} de ${meses[dt.month - 1]}.';
  }

  /// Formata dinamicamente o valor monetário no padrão R$ 0,00 enquanto o usuário digita.
  void _formatarMoedaEmTempoReal(
    String value,
    TextEditingController controller,
  ) {
    String clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) {
      controller.value = const TextEditingValue(
        text: 'R\$ 0,00',
        selection: TextSelection.collapsed(offset: 7),
      );
      return;
    }
    final double parsed = (double.tryParse(clean) ?? 0) / 100.0;
    final String formatted =
        'R\$ ${parsed.toStringAsFixed(2).replaceAll('.', ',')}';
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Converte o texto no formato R$ 0,00 para valor numérico double.
  double _extrairValorMoeda(String text) {
    final clean = text
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(clean) ?? 0.0;
  }

  /// Exibe o modal para criação ou edição de um Orçamento com o design moderno do COGITO.
  /// Permite definir o Nome do Orçamento, Limite Mensal e Tipo (Gastos/Despesas ou Fontes de Renda/Receitas).
  void _exibirDialogoNovoOrcamento({Map<String, dynamic>? orcamentoExistente}) {
    final String nomeInicial = orcamentoExistente?['nome'] ??
        orcamentoExistente?['titulo'] ??
        '';
    final nomeController = TextEditingController(text: nomeInicial);

    final double limiteOriginal =
        (orcamentoExistente?['limite'] as num?)?.toDouble() ?? 0.0;
    final limiteController = TextEditingController(
      text: limiteOriginal > 0
          ? 'R\$ ${limiteOriginal.toStringAsFixed(2).replaceAll('.', ',')}'
          : 'R\$ 0,00',
    );

    // Identifica se o orçamento é de despesa ou receita/fonte de renda
    final String lowerNomeIni = nomeInicial.toLowerCase();
    final bool isReceitaSugerida = lowerNomeIni.contains('trabalho') ||
        lowerNomeIni.contains('freelance') ||
        lowerNomeIni.contains('mesada') ||
        lowerNomeIni.contains('salário') ||
        lowerNomeIni.contains('salario') ||
        lowerNomeIni.contains('renda') ||
        lowerNomeIni.contains('investimento') ||
        lowerNomeIni.contains('receita');

    String tipo = orcamentoExistente?['tipo'] ??
        (isReceitaSugerida ? 'Receita' : 'Despesa');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bool isReceita = tipo == 'Receita';

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).viewPadding.bottom +
                    24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho do Modal: Título, Botão Excluir (se edição) e Botão Fechar 'x'
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          orcamentoExistente != null
                              ? (isReceita
                                  ? 'Editar Fonte de Receita'
                                  : 'Editar Orçamento')
                              : (isReceita
                                  ? 'Definir Fonte de Receita'
                                  : 'Definir Orçamento'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getPrimaryAccent(context),
                          ),
                        ),
                        Row(
                          children: [
                            if (orcamentoExistente != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 22,
                                ),
                                tooltip: isReceita
                                    ? 'Excluir Receita'
                                    : 'Excluir Orçamento',
                                onPressed: () async {
                                  final bool? confirmar =
                                      await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      backgroundColor:
                                          AppColors.getCardColor(context),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                      ),
                                      title: Text(isReceita
                                          ? 'Excluir Fonte de Receita?'
                                          : 'Excluir Orçamento?'),
                                      content: Text(
                                        isReceita
                                            ? 'Deseja realmente remover a fonte de receita "$nomeInicial"? Suas transações continuarão salvas no Extrato.'
                                            : 'Deseja realmente remover o orçamento "$nomeInicial"? Suas transações continuarão salvas no Extrato.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(c, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(c, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                          ),
                                          child: const Text(
                                            'Excluir',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmar == true && mounted) {
                                    final String idCliente =
                                        FirebaseFirestoreService.idClienteAtual;
                                    final messenger = ScaffoldMessenger.of(context);
                                    if (modalCtx.mounted) {
                                      Navigator.pop(modalCtx);
                                    }

                                    await _firestoreService.excluirOrcamento(
                                      idCliente: idCliente,
                                      id: orcamentoExistente['id'] ?? nomeInicial,
                                      nome: nomeInicial,
                                    );

                                    if (mounted) {
                                      setState(() {});
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Orçamento excluído com sucesso.'),
                                          backgroundColor: Colors.redAccent,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.grey,
                                size: 22,
                              ),
                              onPressed: () => Navigator.pop(modalCtx),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Seletor centralizado de Tipo de Orçamento: Gastos/Despesas vs Fontes/Receitas
                    Center(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.getInputFillColor(context),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            // Opção 1: Gastos / Despesas (centralizado)
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setModalState(() {
                                    tipo = 'Despesa';
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !isReceita
                                        ? (AppColors.isDarkMode(context)
                                            ? Colors.redAccent.withValues(alpha: 0.25)
                                            : Colors.redAccent.withValues(alpha: 0.12))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: !isReceita
                                        ? Border.all(
                                            color: Colors.redAccent.withValues(alpha: 0.4),
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_downward_rounded,
                                        size: 18,
                                        color: !isReceita
                                            ? Colors.redAccent
                                            : AppColors.getSubtextColor(context),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Gastos / Despesas',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: !isReceita
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: !isReceita
                                              ? Colors.redAccent
                                              : AppColors.getSubtextColor(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Opção 2: Fontes / Receitas (centralizado)
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setModalState(() {
                                    tipo = 'Receita';
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isReceita
                                        ? (AppColors.isDarkMode(context)
                                            ? Colors.green.withValues(alpha: 0.25)
                                            : Colors.green.withValues(alpha: 0.12))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isReceita
                                        ? Border.all(
                                            color: Colors.green.withValues(alpha: 0.4),
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_upward_rounded,
                                        size: 18,
                                        color: isReceita
                                            ? Colors.green
                                            : AppColors.getSubtextColor(context),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Fonte / Receita',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isReceita
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isReceita
                                              ? Colors.green
                                              : AppColors.getSubtextColor(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Frase explicativa contextual centralizada para cada opção
                    Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          isReceita
                              ? 'Defina quanto você espera receber de cada fonte.'
                              : 'Defina um limite mensal para os gastos de cada categoria.',
                          key: ValueKey(isReceita),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.getSubtextColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo de Nome do Orçamento ou Nome da Receita
                    Text(
                      isReceita ? 'Nome da Receita' : 'Nome do Orçamento',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getPrimaryAccent(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nomeController,
                      style: TextStyle(color: AppColors.getTextColor(context)),
                      onChanged: (val) {
                        // Sugere automaticamente se o usuário digitar uma fonte de renda
                        final lower = val.toLowerCase();
                        if (lower.contains('trabalho') ||
                            lower.contains('freelance') ||
                            lower.contains('aluguel') ||
                            lower.contains('mesada') ||
                            lower.contains('salário') ||
                            lower.contains('salario')) {
                          if (tipo != 'Receita') {
                            setModalState(() => tipo = 'Receita');
                          }
                        }
                      },
                      decoration: InputDecoration(
                        hintText: isReceita
                            ? 'Ex: Trabalho, Freelance, Aluguel'
                            : 'Ex: Alimentação, Lazer, Compras, Transporte',
                        filled: true,
                        fillColor: AppColors.getInputFillColor(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Label: Valor Mensal Esperado ou Limite Mensal de Gastos
                    Text(
                      isReceita ? 'Valor Mensal Esperado' : 'Limite Mensal de Gastos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getPrimaryAccent(context),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Input formatado automaticamente em R$ sem contorno
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.getInputFillColor(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: limiteController,
                        keyboardType: TextInputType.number,
                        onChanged: (val) =>
                            _formatarMoedaEmTempoReal(val, limiteController),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getPrimaryAccent(context),
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Box Informativo com explicação de integração automática
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.getPrimaryAccent(context).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.sync_rounded,
                                color: AppColors.getPrimaryAccent(context),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isReceita
                                      ? 'Todas as receitas registradas no Extrato serão contabilizadas automaticamente nesta fonte.'
                                      : 'Todas as despesas registradas no Extrato serão contabilizadas automaticamente no orçamento.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.getTextColor(context),
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                color: isReceita ? Colors.green : AppColors.primaryOrange,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isReceita
                                      ? 'O COGITO poderá alertar quando suas receitas estiverem abaixo do valor esperado.'
                                      : 'O COGITO poderá alertar quando seus gastos atingirem 75% do limite definido.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.getSubtextColor(context),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Botões Cancelar e Salvar
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(modalCtx),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: AppColors.getInputFillColor(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                color: AppColors.getTextColor(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final String nome = nomeController.text.trim();
                              if (nome.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isReceita
                                          ? 'Por favor, informe o nome da receita.'
                                          : 'Por favor, dê um nome para o seu orçamento.',
                                    ),
                                    backgroundColor: Colors.orange,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              final double limite = _extrairValorMoeda(
                                limiteController.text,
                              );
                              if (limite <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isReceita
                                          ? 'Por favor, informe um valor mensal esperado maior que R\$ 0,00.'
                                          : 'Por favor, informe um limite mensal maior que R\$ 0,00.',
                                    ),
                                    backgroundColor: Colors.orange,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              final String idCliente =
                                  FirebaseFirestoreService.idClienteAtual;
                              final messenger = ScaffoldMessenger.of(context);
                              final String? idOrcamento = orcamentoExistente?['id'];
                              Navigator.pop(modalCtx);

                              await _firestoreService.salvarOrcamento(
                                idCliente: idCliente,
                                id: idOrcamento,
                                nome: nome,
                                limite: limite,
                                tipo: tipo,
                              );

                              if (mounted) {
                                setState(() {});
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isReceita
                                          ? 'Fonte de receita salva com sucesso!'
                                          : 'Orçamento salvo com sucesso!',
                                    ),
                                    backgroundColor: AppColors.getPrimaryAccent(context),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              orcamentoExistente != null
                                  ? 'Atualizar'
                                  : (isReceita
                                      ? 'Salvar Receita'
                                      : 'Salvar Orçamento'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Constrói a aba de Orçamentos conectada em tempo real com o Cloud Firestore e Mock,
  /// integrando automaticamente os gastos a partir do Extrato filtrados pelo mês selecionado.
  /// Contém seletor mensal, painel de acompanhamento "Resumo dos Orçamentos",
  /// seção "Seus Orçamentos" com cartões individuais e botão "Novo Orçamento" na própria tela.
  Widget _buildOrcamentosSection() {
    final String idCliente = FirebaseFirestoreService.idClienteAtual;
    final bool isMock = DebugMockService.instance.modoMockAtivo;
    final List<Map<String, dynamic>> mockOrcamentos =
        isMock ? DebugMockService.instance.orcamentosMock : [];
    final List<Map<String, dynamic>> mockTransacoes =
        isMock ? DebugMockService.instance.transacoesMock : [];

    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('orcamentos_stream_${isMock}_$idCliente'),
      initialData: isMock ? mockOrcamentos : null,
      stream: isMock
          ? DebugMockService.instance.orcamentosStream
          : _firestoreService.buscarOrcamentosStream(idCliente),
      builder: (context, snapshotOrcamentos) {
        // Previne oscilações na interface aguardando a carga inicial
        if (snapshotOrcamentos.connectionState == ConnectionState.waiting &&
            !snapshotOrcamentos.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColors.getPrimaryAccent(context),
            ),
          );
        }

        final List<Map<String, dynamic>> orcamentosFirestore =
            snapshotOrcamentos.data ?? (isMock ? mockOrcamentos : []);

        return StreamBuilder<List<Map<String, dynamic>>>(
          key: ValueKey('transacoes_stream_orc_${isMock}_$idCliente'),
          initialData: isMock ? mockTransacoes : null,
          stream: isMock
              ? DebugMockService.instance.transacoesStream
              : _firestoreService.buscarTransacoesStream(idCliente),
          builder: (context, snapshotTransacoes) {
            final List<Map<String, dynamic>> transacoes =
                snapshotTransacoes.data ?? (isMock ? mockTransacoes : []);

            // Filtra as transações estritamente pelo mês selecionado e acumula valores por categoria
            final List<Map<String, dynamic>> transacoesDoMes = [];
            final Map<String, double> despesasPorCategoria = {};
            final Map<String, double> receitasPorCategoria = {};
            double totalDespesasDoMes = 0.0;
            double totalReceitasDoMes = 0.0;

            for (final t in transacoes) {
              final DateTime dt = FinancialUtils.extrairDataTransacao(t);
              if (dt.year == _mesOrcamentoSelecionado.year &&
                  dt.month == _mesOrcamentoSelecionado.month) {
                transacoesDoMes.add(t);
                final String tipo = t['tipo'] ?? 'Despesa';
                final String cat = t['categoria'] ?? 'Outros';
                final double val = (t['valor'] as num?)?.toDouble() ?? 0.0;

                if (tipo == 'Despesa') {
                  despesasPorCategoria[cat] =
                      (despesasPorCategoria[cat] ?? 0.0) + val;
                  totalDespesasDoMes += val;
                } else if (tipo == 'Receita') {
                  receitasPorCategoria[cat] =
                      (receitasPorCategoria[cat] ?? 0.0) + val;
                  totalReceitasDoMes += val;
                }
              }
            }

            // Lista consolidada de orçamentos vinculando os limites aos gastos ou entradas reais do mês
            final List<Map<String, dynamic>> listaExibicao = orcamentosFirestore
                .map((orc) {
                  final String nome = orc['nome'] ?? orc['titulo'] ?? 'Orçamento';
                  final String? catInterna = orc['categoria'];
                  final String? tipoOrc = orc['tipo'];
                  final double limite =
                      (orc['limite'] as num?)?.toDouble() ?? 0.0;

                  // Calcula dinamicamente o valor movimentado (gastos ou receitas)
                  final double gastoCalculado = _calcularGastoOrcamento(
                    nome: nome,
                    tipo: tipoOrc,
                    categoriaInterna: catInterna,
                    despesasPorCategoria: despesasPorCategoria,
                    receitasPorCategoria: receitasPorCategoria,
                    totalDespesasDoMes: totalDespesasDoMes,
                    totalReceitasDoMes: totalReceitasDoMes,
                    transacoesDoMes: transacoesDoMes,
                  );

                  return {
                    'nome': nome,
                    'tipo': tipoOrc,
                    'categoria': catInterna,
                    'limite': limite,
                    'gasto': gastoCalculado,
                    'cor': _obterCorOrcamento(nome),
                    'id': orc['id'] ?? nome,
                  };
                })
                .toList();

            // Totalizadores consolidados para o painel de acompanhamento geral
            double totalPlanejado = 0.0;
            double totalUtilizado = 0.0;
            for (final item in listaExibicao) {
              totalPlanejado += (item['limite'] as num).toDouble();
              totalUtilizado += (item['gasto'] as num).toDouble();
            }

            final double pctGeral = totalPlanejado > 0
                ? (totalUtilizado / totalPlanejado).clamp(0.0, 1.0)
                : 0.0;
            final double totalDisponivel = totalPlanejado - totalUtilizado;

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Navegador de Mês no Topo (Ex: "Outubro de 2026")
                _buildSeletorMesOrcamento(),

                const SizedBox(height: 14),

                // 2. Painel de Acompanhamento: "Resumo dos Orçamentos"
                _buildPainelResumoOrcamentos(
                  totalPlanejado: totalPlanejado,
                  totalUtilizado: totalUtilizado,
                  totalDisponivel: totalDisponivel,
                  pctGeral: pctGeral,
                ),

                const SizedBox(height: 22),

                // 3. Cabeçalho da Seção "Seus Orçamentos" com botão de ação na própria tela
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Seus Orçamentos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextColor(context),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _exibirDialogoNovoOrcamento(),
                      icon: const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Novo Orçamento',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 4. Lista dos Cartões de Orçamento ou Estado Vazio
                if (listaExibicao.isEmpty)
                  _buildEstadoVazioOrcamentos()
                else
                  ...listaExibicao.map((item) {
                    return _buildCartaoOrcamento(
                      item: item,
                      todasTransacoes: transacoes,
                    );
                  }),

                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  /// Constrói o seletor de mês com navegação anterior/próximo e título formatado.
  Widget _buildSeletorMesOrcamento() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 26),
            color: AppColors.getPrimaryAccent(context),
            onPressed: _mesAnteriorOrcamento,
            tooltip: 'Mês anterior',
          ),
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 19,
                color: AppColors.getPrimaryAccent(context),
              ),
              const SizedBox(width: 8),
              Text(
                _formatarMesAnoOrcamento(_mesOrcamentoSelecionado),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.5,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              size: 26,
              color: _podeAvancarMesOrcamento
                  ? AppColors.getPrimaryAccent(context)
                  : Colors.grey.withValues(alpha: 0.35),
            ),
            onPressed: _podeAvancarMesOrcamento ? _proximoMesOrcamento : null,
            tooltip: _podeAvancarMesOrcamento
                ? 'Próximo mês'
                : 'Limite alcançado (mês atual)',
          ),
        ],
      ),
    );
  }

  /// Constrói o painel de acompanhamento "Resumo dos Orçamentos"
  /// com percentual utilizado geral, barra de progresso e 3 métricas essenciais:
  /// planejados, utilizados e disponíveis.
  Widget _buildPainelResumoOrcamentos({
    required double totalPlanejado,
    required double totalUtilizado,
    required double totalDisponivel,
    required double pctGeral,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.getPrimaryAccent(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título do painel e percentual de utilização
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Painel de Acompanhamento',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Resumo dos Orçamentos',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${(pctGeral * 100).toStringAsFixed(1)}% utilizado',
                  style: const TextStyle(
                    color: AppColors.primaryYellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Barra de progresso geral do mês
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pctGeral,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: AlwaysStoppedAnimation<Color>(
                pctGeral >= 0.85
                    ? Colors.redAccent
                    : (pctGeral >= 0.75
                        ? AppColors.primaryOrange
                        : AppColors.primaryYellow),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3 métricas de acompanhamento solicitadas: planejados, utilizados e disponíveis
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Planejado
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planejados',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'R\$ ${totalPlanejado.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Utilizados
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Utilizados',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        'R\$ ${totalUtilizado.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(
                          color: AppColors.primaryYellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Disponíveis
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Disponíveis',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'R\$ ${totalDisponivel.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: TextStyle(
                          color: totalDisponivel >= 0
                              ? const Color(0xFF00E676)
                              : Colors.redAccent.shade100,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Constrói o cartão individual de um orçamento com:
  /// - Ícone temático e Nome do Orçamento
  /// - Botão de edição direta
  /// - Valores: "R$ X de R$ Y utilizados" (despesa) ou "R$ X de R$ Y recebidos" (receita)
  /// - Barra de progresso com coloração proporcional aos limites
  /// - Valores restantes e percentual
  Widget _buildCartaoOrcamento({
    required Map<String, dynamic> item,
    required List<Map<String, dynamic>> todasTransacoes,
  }) {
    final String nome = item['nome'] ?? 'Orçamento';
    final double gasto = (item['gasto'] as num).toDouble();
    final double limite = (item['limite'] as num).toDouble();
    final Color cor = item['cor'] as Color? ?? AppColors.primaryOrange;
    final double pct = limite > 0 ? (gasto / limite).clamp(0.0, 1.0) : 0.0;
    final double pctReal = limite > 0 ? (gasto / limite) * 100 : 0.0;
    final double restante = limite - gasto;

    final String lower = nome.toLowerCase();
    final bool isReceita = (item['tipo'] == 'Receita') ||
        lower.contains('trabalho') ||
        lower.contains('freelance') ||
        lower.contains('mesada') ||
        lower.contains('salário') ||
        lower.contains('salario') ||
        lower.contains('renda') ||
        lower.contains('investimento') ||
        lower.contains('receita');

    final bool isAlerta = !isReceita && pct >= 0.75;
    final bool isEstourado = !isReceita && gasto > limite;
    final bool isMetaAtingida = isReceita && gasto >= limite;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            // Abre o detalhamento do orçamento com histórico de transações e métricas
            _exibirDetalhesOrcamento(
              item: item,
              todasTransacoes: todasTransacoes,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Topo: Ícone, Nome do Orçamento e Botão de Edição
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _obterIconeOrcamento(nome),
                              color: cor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nome,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.getTextColor(context),
                                  ),
                                ),
                                Text(
                                  isReceita ? 'Fonte de Renda / Meta' : 'Orçamento de Despesa',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.getSubtextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Botão direto de editar orçamento
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: Colors.blueAccent,
                      ),
                      tooltip: 'Editar orçamento',
                      onPressed: () => _exibirDialogoNovoOrcamento(orcamentoExistente: item),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Linha de Valores: "R$ 1.180,00 de R$ 1.500,00 utilizados / recebidos"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isReceita
                          ? 'R\$ ${gasto.toStringAsFixed(2).replaceAll('.', ',')} de R\$ ${limite.toStringAsFixed(2).replaceAll('.', ',')} recebidos'
                          : 'R\$ ${gasto.toStringAsFixed(2).replaceAll('.', ',')} de R\$ ${limite.toStringAsFixed(2).replaceAll('.', ',')} utilizados',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isEstourado
                            ? Colors.red.shade600
                            : (isMetaAtingida
                                ? Colors.green.shade600
                                : AppColors.getTextColor(context)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Barra de progresso do orçamento
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: AppColors.isDarkMode(context)
                        ? AppColors.darkInputFill
                        : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isReceita
                          ? (isMetaAtingida ? Colors.green.shade600 : cor)
                          : (isEstourado
                              ? Colors.red.shade600
                              : (isAlerta ? Colors.orange : cor)),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Linha Inferior com métricas de atingimento ou restante
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isReceita
                          ? (restante <= 0
                              ? 'Meta atingida! (+ R\$ ${(-restante).toStringAsFixed(2).replaceAll('.', ',')})'
                              : 'Faltam R\$ ${restante.toStringAsFixed(2).replaceAll('.', ',')} para a meta')
                          : (restante >= 0
                              ? 'R\$ ${restante.toStringAsFixed(2).replaceAll('.', ',')} restantes'
                              : 'Excedido em R\$ ${(-restante).toStringAsFixed(2).replaceAll('.', ',')}'),
                      style: TextStyle(
                        color: isReceita
                            ? (restante <= 0
                                ? Colors.green.shade700
                                : AppColors.getTextColor(context))
                            : (restante >= 0
                                ? (isAlerta
                                    ? Colors.orange.shade800
                                    : Colors.green.shade700)
                                : Colors.red.shade700),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isReceita
                          ? '${pctReal.toStringAsFixed(1)}% atingido'
                          : '${pctReal.toStringAsFixed(1)}% utilizado',
                      style: TextStyle(
                        color: isReceita
                            ? (isMetaAtingida
                                ? Colors.green.shade700
                                : AppColors.getSubtextColor(context))
                            : (isEstourado
                                ? Colors.red.shade600
                                : (isAlerta
                                    ? Colors.orange.shade800
                                    : AppColors.getSubtextColor(context))),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Constrói o estado visual quando nenhum orçamento foi cadastrado no mês selecionado.
  Widget _buildEstadoVazioOrcamentos() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.getPrimaryAccent(context).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pie_chart_outline_rounded,
              size: 44,
              color: AppColors.getPrimaryAccent(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum orçamento cadastrado',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Defina limites mensais para seus orçamentos e acompanhe seus gastos em tempo real.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.getSubtextColor(context),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _exibirDialogoNovoOrcamento(),
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text(
              'Criar Primeiro Orçamento',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getPrimaryAccent(context),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  /// Retorna o ícone temático adequado para o orçamento com base no seu nome ou fonte de renda.
  IconData _obterIconeOrcamento(String nome) {
    final lower = nome.toLowerCase();
    // Fontes de Renda / Receitas
    if (lower.contains('trabalho')) {
      return Icons.work_outline_rounded;
    }
    if (lower.contains('freelance')) {
      return Icons.laptop_mac_rounded;
    }
    if (lower.contains('mesada')) {
      return Icons.payments_outlined;
    }
    if (lower.contains('salário') || lower.contains('salario')) {
      return Icons.monetization_on_outlined;
    }
    if (lower.contains('invest')) {
      return Icons.trending_up_rounded;
    }

    // Categorias de Despesas
    if (lower.contains('alimenta') ||
        lower.contains('mercado') ||
        lower.contains('comida') ||
        lower.contains('refeição') ||
        lower.contains('lanche')) {
      return Icons.fastfood_outlined;
    }
    if (lower.contains('transporte') ||
        lower.contains('combustível') ||
        lower.contains('gasolina') ||
        lower.contains('carro') ||
        lower.contains('uber')) {
      return Icons.directions_car_outlined;
    }
    if (lower.contains('moradia') ||
        lower.contains('casa') ||
        lower.contains('aluguel') ||
        lower.contains('condomínio')) {
      return Icons.home_outlined;
    }
    if (lower.contains('lazer') ||
        lower.contains('passeio') ||
        lower.contains('viagem') ||
        lower.contains('cinema')) {
      return Icons.sports_esports_outlined;
    }
    if (lower.contains('saúde') ||
        lower.contains('saude') ||
        lower.contains('farmácia') ||
        lower.contains('farmacia') ||
        lower.contains('médico')) {
      return Icons.medical_services_outlined;
    }
    if (lower.contains('educação') ||
        lower.contains('educacao') ||
        lower.contains('curso') ||
        lower.contains('escola') ||
        lower.contains('livro')) {
      return Icons.school_outlined;
    }
    if (lower.contains('compra') ||
        lower.contains('shopping') ||
        lower.contains('roupa')) {
      return Icons.shopping_bag_outlined;
    }
    return Icons.savings_outlined;
  }

  /// Retorna a cor característica para o orçamento com base no seu nome.
  Color _obterCorOrcamento(String nome) {
    final lower = nome.toLowerCase();
    // Fontes de Renda / Receitas
    if (lower.contains('trabalho')) {
      return Colors.teal;
    }
    if (lower.contains('freelance')) {
      return Colors.deepPurpleAccent;
    }
    if (lower.contains('mesada')) {
      return Colors.amber.shade800;
    }
    if (lower.contains('salário') || lower.contains('salario')) {
      return Colors.green;
    }
    if (lower.contains('invest')) {
      return Colors.indigo;
    }

    // Despesas
    if (lower.contains('alimenta') ||
        lower.contains('mercado') ||
        lower.contains('comida')) {
      return Colors.orange;
    }
    if (lower.contains('transporte') ||
        lower.contains('combustível') ||
        lower.contains('carro')) {
      return Colors.blue;
    }
    if (lower.contains('moradia') ||
        lower.contains('casa') ||
        lower.contains('aluguel')) {
      return Colors.teal;
    }
    if (lower.contains('lazer') ||
        lower.contains('passeio') ||
        lower.contains('viagem')) {
      return Colors.purple;
    }
    if (lower.contains('saúde') ||
        lower.contains('saude') ||
        lower.contains('farmácia')) {
      return Colors.redAccent;
    }
    if (lower.contains('educação') ||
        lower.contains('educacao') ||
        lower.contains('curso')) {
      return Colors.indigo;
    }
    if (lower.contains('compra') || lower.contains('shopping')) {
      return Colors.pink;
    }
    return AppColors.getPrimaryAccent(context);
  }

  /// Calcula dinamicamente o valor movimentado de um orçamento a partir dos dados do extrato do mês.
  /// Suporta orçamentos de Despesas e orçamentos de Fontes de Renda / Receitas ("Trabalho", "Freelance", "Mesada", etc.).
  double _calcularGastoOrcamento({
    required String nome,
    String? tipo,
    String? categoriaInterna,
    required Map<String, double> despesasPorCategoria,
    required Map<String, double> receitasPorCategoria,
    required double totalDespesasDoMes,
    required double totalReceitasDoMes,
    required List<Map<String, dynamic>> transacoesDoMes,
  }) {
    final lowerNome = nome.toLowerCase().trim();
    final bool isReceita = (tipo == 'Receita') ||
        lowerNome.contains('trabalho') ||
        lowerNome.contains('freelance') ||
        lowerNome.contains('mesada') ||
        lowerNome.contains('salário') ||
        lowerNome.contains('salario') ||
        lowerNome.contains('renda') ||
        lowerNome.contains('investimento') ||
        lowerNome.contains('receita');

    // Se for orçamento global / geral do mês
    if (lowerNome.contains('geral') ||
        lowerNome.contains('global') ||
        lowerNome == 'orçamento' ||
        lowerNome == 'orcamento' ||
        lowerNome.contains('total do mês')) {
      return isReceita ? totalReceitasDoMes : totalDespesasDoMes;
    }

    if (isReceita) {
      // 1. Verificação por categoria direta no mapa agregado de receitas
      for (final entry in receitasPorCategoria.entries) {
        final catLower = entry.key.toLowerCase().trim();
        if (catLower == lowerNome ||
            lowerNome.contains(catLower) ||
            catLower.contains(lowerNome)) {
          return entry.value;
        }
      }

      // 2. Busca detalhada nas transações de receita do mês por título, descrição ou categoria
      double somaReceitas = 0.0;
      for (final t in transacoesDoMes) {
        if (t['tipo'] == 'Receita') {
          final String cat = (t['categoria'] ?? '').toString().toLowerCase();
          final String desc = (t['titulo'] ?? t['descricao'] ?? '').toString().toLowerCase();
          final double val = (t['valor'] as num?)?.toDouble() ?? 0.0;

          if (desc.contains(lowerNome) ||
              lowerNome.contains(desc) ||
              cat.contains(lowerNome) ||
              lowerNome.contains(cat)) {
            somaReceitas += val;
          }
        }
      }
      return somaReceitas;
    } else {
      // Associações diretas por palavras-chave com as despesas computadas
      if (lowerNome.contains('alimenta') ||
          lowerNome.contains('mercado') ||
          lowerNome.contains('comida') ||
          lowerNome.contains('refeição')) {
        return despesasPorCategoria['Alimentação'] ?? 0.0;
      }
      if (lowerNome.contains('moradia') ||
          lowerNome.contains('casa') ||
          lowerNome.contains('aluguel') ||
          lowerNome.contains('condomínio')) {
        return despesasPorCategoria['Moradia'] ?? 0.0;
      }
      if (lowerNome.contains('transporte') ||
          lowerNome.contains('combustível') ||
          lowerNome.contains('carro') ||
          lowerNome.contains('uber')) {
        return despesasPorCategoria['Transporte'] ?? 0.0;
      }
      if (lowerNome.contains('lazer') ||
          lowerNome.contains('passeio') ||
          lowerNome.contains('viagem')) {
        return despesasPorCategoria['Lazer'] ?? 0.0;
      }
      if (lowerNome.contains('saúde') ||
          lowerNome.contains('saude') ||
          lowerNome.contains('farmácia')) {
        return despesasPorCategoria['Saúde'] ?? 0.0;
      }
      if (lowerNome.contains('educação') ||
          lowerNome.contains('educacao') ||
          lowerNome.contains('curso')) {
        return despesasPorCategoria['Educação'] ?? 0.0;
      }
      if (lowerNome.contains('compra') || lowerNome.contains('shopping')) {
        return despesasPorCategoria['Compras'] ?? 0.0;
      }

      // Se houver categoria interna compatível no documento
      if (categoriaInterna != null &&
          despesasPorCategoria.containsKey(categoriaInterna)) {
        return despesasPorCategoria[categoriaInterna]!;
      }

      // Verificação por categoria direta no mapa agregado de despesas
      for (final entry in despesasPorCategoria.entries) {
        final catLower = entry.key.toLowerCase().trim();
        if (catLower == lowerNome ||
            lowerNome.contains(catLower) ||
            catLower.contains(lowerNome)) {
          return entry.value;
        }
      }

      // Fallback por busca nas descrições de despesas
      double somaEspecifica = 0.0;
      for (final t in transacoesDoMes) {
        if (t['tipo'] == 'Despesa') {
          final String cat = (t['categoria'] ?? '').toString().toLowerCase();
          final String desc =
              (t['titulo'] ?? t['descricao'] ?? '').toString().toLowerCase();
          if (desc.contains(lowerNome) ||
              lowerNome.contains(desc) ||
              cat.contains(lowerNome) ||
              lowerNome.contains(cat)) {
            somaEspecifica += (t['valor'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
      return somaEspecifica;
    }
  }

  /// Retorna o ícone temático adequado para cada categoria de orçamento utilizando os ícones do app.
  IconData _obterIconeCategoria(String cat) {
    switch (cat) {
      case 'Geral':
        return Icons.account_balance_wallet_outlined;
      case 'Alimentação':
        return Icons.fastfood_outlined;
      case 'Transporte':
        return Icons.directions_car_outlined;
      case 'Lazer':
        return Icons.sports_esports_outlined;
      case 'Saúde':
        return Icons.medical_services_outlined;
      case 'Educação':
        return Icons.school_outlined;
      case 'Moradia':
        return Icons.home_outlined;
      case 'Compras':
        return Icons.shopping_bag_outlined;
      case 'Outros':
      default:
        return Icons.inventory_2_outlined;
    }
  }

  /// Retorna a cor temática para cada categoria.
  Color _obterCorCategoria(String cat) {
    switch (cat) {
      case 'Geral':
        return AppColors.getPrimaryAccent(context);
      case 'Alimentação':
        return Colors.orange;
      case 'Transporte':
        return Colors.blue;
      case 'Lazer':
        return Colors.purple;
      case 'Saúde':
        return Colors.redAccent;
      case 'Educação':
        return Colors.indigo;
      case 'Moradia':
        return Colors.teal;
      case 'Compras':
        return Colors.pink;
      case 'Outros':
      default:
        return Colors.grey.shade600;
    }
  }

  // --- ABA 3: RELATÓRIOS FINANCEIROS (BASEADA NA 3ª IMAGEM) ---

  /// Constrói a aba de Relatórios Financeiros consolidando as visualizações
  /// e preservando Donut Chart, seletor de períodos, Slider de Limite e lista de despesas.
  Widget _buildRelatoriosSection() {
    final String uid = FirebaseFirestoreService.idClienteAtual;
    final bool isMock = DebugMockService.instance.modoMockAtivo;
    final List<Map<String, dynamic>> mockData =
        isMock ? DebugMockService.instance.transacoesMock : [];

    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('relatorios_stream_${isMock}_$uid'),
      initialData: isMock ? mockData : null,
      stream: isMock
          ? DebugMockService.instance.transacoesStream
          : _firestoreService.ouvirTransacoes(uid),
      builder: (context, snapshot) {
        // Garante exibição instantânea e reativa dos dados no modo mock
        final List<Map<String, dynamic>> todasTransacoes =
            (snapshot.data != null && snapshot.data!.isNotEmpty)
                ? snapshot.data!
                : (isMock ? mockData : (snapshot.data ?? []));

        // Filtra despesas pelo período selecionado na aba de Relatórios
        final List<Map<String, dynamic>> despesasPeriodo = todasTransacoes.where((t) {
          if (t['tipo'] != 'Despesa') return false;
          final DateTime dt = FinancialUtils.extrairDataTransacao(t);
          final DateTime agora = DateTime.now();

          switch (_periodoRelatorio) {
            case '1D':
              return dt.year == agora.year && dt.month == agora.month && dt.day == agora.day;
            case '1S':
              return agora.difference(dt).inDays <= 7;
            case '1M':
              return dt.year == agora.year && dt.month == agora.month;
            case '3M':
              return agora.difference(dt).inDays <= 90;
            case '1A':
              return dt.year == agora.year;
            default:
              return true;
          }
        }).toList();


        // Calcula o total geral de despesas do período
        double totalDespesas = 0.0;
        final Map<String, double> despesasPorCategoria = {};

        for (final d in despesasPeriodo) {
          final double val = (d['valor'] as num?)?.toDouble() ?? 0.0;
          totalDespesas += val;
          final String cat = d['categoria'] ?? 'Outros';
          despesasPorCategoria[cat] = (despesasPorCategoria[cat] ?? 0.0) + val;
        }

        // Ordena categorias por maior valor para desenhar os arcos do Donut e o Top 3
        final categoriasOrdenadas = despesasPorCategoria.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Limite mensal configurado dinamicamente pelo usuário através do Slider
        final double limiteMensal = _limiteMensal;
        final double pctLimite = (totalDespesas / limiteMensal).clamp(0.0, 1.0);

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // =========================================================
            // SEÇÃO 1: GRÁFICO DONUT CENTRALIZADO COM VALOR TOTAL E PERÍODOS
            // =========================================================
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.getCardColor(context),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Desenho vetorial do Donut com arcos por categoria
                        CustomPaint(
                          size: const Size(200, 200),
                          painter: _DonutChartPainter(
                            categorias: categoriasOrdenadas,
                            total: totalDespesas,
                            corPadrao: AppColors.getPrimaryAccent(context),
                            isDark: AppColors.isDarkMode(context),
                            obterCor: _obterCorCategoria,
                          ),
                        ),

                        // Valor Central e Período (Estilo €800 / Spent in December)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'R\$ ${totalDespesas.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextColor(context),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gasto no período',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.getSubtextColor(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 2. Seletor de Período em Pílulas: 1D, 1S, 1M, 3M, 1A (Imagem 3)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.isDarkMode(context)
                          ? AppColors.darkInputFill
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['1D', '1S', '1M', '3M', '1A'].map((p) {
                        final bool ativo = _periodoRelatorio == p;
                        return GestureDetector(
                          onTap: () => setState(() => _periodoRelatorio = p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: ativo
                                  ? AppColors.getPrimaryAccent(context)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              p,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: ativo ? FontWeight.bold : FontWeight.w600,
                                color: ativo
                                    ? Colors.white
                                    : AppColors.getSubtextColor(context),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Card "Definir Limite Mensal" controlado por uma barrinha que desliza com o dedo (Slider)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.getCardColor(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.getPrimaryAccent(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.speed_rounded,
                          color: AppColors.getPrimaryAccent(context),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Definir Limite Mensal',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextColor(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Deslize a barra para ajustar o seu teto',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.getSubtextColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'R\$ ${_limiteMensal.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getPrimaryAccent(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Barrinha que desliza com o dedo para controlar o limite mensal
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.getPrimaryAccent(context),
                      inactiveTrackColor: AppColors.isDarkMode(context)
                          ? AppColors.darkInputFill
                          : const Color(0xFFEDF2F7),
                      thumbColor: AppColors.getPrimaryAccent(context),
                      overlayColor: AppColors.getPrimaryAccent(context).withValues(alpha: 0.2),
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                    ),
                    child: Slider(
                      value: _limiteMensal.clamp(500.0, 15000.0),
                      min: 500.0,
                      max: 15000.0,
                      divisions: 29,
                      label: 'R\$ ${_limiteMensal.toStringAsFixed(0)}',
                      onChanged: (novoLimite) {
                        setState(() {
                          _limiteMensal = novoLimite;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Barra de Progresso do Limite Consumido
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pctLimite,
                      minHeight: 8,
                      backgroundColor: AppColors.isDarkMode(context)
                          ? AppColors.darkInputFill
                          : const Color(0xFFEDF2F7),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pctLimite > 0.85
                            ? Colors.redAccent
                            : AppColors.getPrimaryAccent(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Consumido: ${(pctLimite * 100).toStringAsFixed(0)}% (R\$ ${totalDespesas.toStringAsFixed(2).replaceAll('.', ',')})',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getSubtextColor(context),
                        ),
                      ),
                      Text(
                        'Teto: R\$ ${_limiteMensal.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // =========================================================
            // SEÇÃO 4: ENTENDA O CONRADO (ABAIXO DO DEFINIR LIMITE MENSAL)
            // =========================================================
            _buildCardEntendaOConradoRelatorios(despesasPeriodo, totalDespesas),

            const SizedBox(height: 18),

            // 4. Seção "Maiores Despesas do Período" (Lista de Itens da Imagem 3)
            Text(
              'Despesas no Período (${despesasPeriodo.length})',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),
            const SizedBox(height: 10),

            if (despesasPeriodo.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.getCardColor(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        size: 40,
                        color: AppColors.getSubtextColor(context).withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Nenhuma despesa registrada neste período.',
                        style: TextStyle(
                          color: AppColors.getSubtextColor(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...despesasPeriodo.map((despesa) {
                final String titulo = despesa['titulo'] ?? 'Despesa';
                final double valor = (despesa['valor'] as num?)?.toDouble() ?? 0.0;
                final String categoria = despesa['categoria'] ?? 'Outros';
                final DateTime dt = FinancialUtils.extrairDataTransacao(despesa);
                final Color corCat = _obterCorCategoria(categoria);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.getCardColor(context),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      // Ícone com fundo colorido da categoria (Imagem 3)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: corCat,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _obterIconeCategoria(categoria),
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Descrição e Horário/Data
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextColor(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$categoria • ${_formatarDataAmigavel(dt)}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.getSubtextColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Valor negativo em destaque
                      Text(
                        '- R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 18),

            // =========================================================
            // SEÇÃO 5: TOP 3 MAIORES GASTOS COM DADOS REAIS (ABAIXO DAS DESPESAS DO PERÍODO)
            // =========================================================
            _buildCardTop3MaioresGastos(categoriasOrdenadas, totalDespesas),

            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  /// Constrói o Card "Entenda o CONRADO" (Análise Inteligente) com a mesma interface do Dashboard (Imagem 3).
  Widget _buildCardEntendaOConradoRelatorios(
    List<Map<String, dynamic>> despesasPeriodo,
    double totalDespesas,
  ) {
    final String dicaDinamica = ConradoAdviceHelper.gerarDicaRelatorios(
      despesasPeriodo: despesasPeriodo,
      totalDespesas: totalDespesas,
      limiteMensal: _limiteMensal,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getPrimaryAccent(context), // Dinâmico: Laranja no escuro, Azul no claro
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.getPrimaryAccent(context).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha de título com ícone autêntico de coroa e "Entenda o CONRADO"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(MdiIcons.crown, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Entenda o CONRADO',
                    style: TextStyles.poppinsBold(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Análise Inteligente',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Container translúcido com o Insight do Conrado gerado dinamicamente
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Colors.amberAccent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dicaDinamica,
                    style: TextStyles.poppinsRegular(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Botão pill branco: ao apertar leva a um novo chat com o usuário enviando mensagem referente à análise da IA
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                final String mensagemParaConrado =
                    'Olá Conrado! Analisando os relatórios do período você pontuou: "$dicaDinamica". O que você me recomenda fazer na prática para equilibrar meus gastos e orçamento?';

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConradoChatPage(
                      chatId: 'chat_relatorio_${DateTime.now().millisecondsSinceEpoch}',
                      tituloChat: 'Relatório do CONRADO',
                      topicoChat: 'Análise de Despesas do Período',
                      mensagemInicial: mensagemParaConrado,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.signal_cellular_alt_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
              label: Text(
                'Conversar com o CONRADO',
                style: TextStyles.poppinsBold(
                  fontSize: 14,
                  color: AppColors.primaryBlue,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói o Card Top 3 Maiores Gastos com dados 100% reais calculados das transações do período.
  Widget _buildCardTop3MaioresGastos(
    List<MapEntry<String, double>> categoriasOrdenadas,
    double totalDespesas,
  ) {
    final bool temDados = categoriasOrdenadas.isNotEmpty && totalDespesas > 0;
    final List<MapEntry<String, double>> rankingReal = temDados
        ? categoriasOrdenadas.take(3).toList()
        : [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_down_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Top 3 Maiores Gastos',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (!temDados)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Nenhuma despesa registrada neste período para ranqueamento.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.getSubtextColor(context),
                  ),
                ),
              ),
            )
          else
            ...List.generate(rankingReal.length, (index) {
              final entry = rankingReal[index];
              final String categoria = entry.key;
              final double valor = entry.value;
              final double pct = (valor / totalDespesas) * 100;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    // Círculo com o número do ranking (1, 2, 3)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.isDarkMode(context)
                            ? AppColors.darkInputFill
                            : const Color(0xFFF1F4F8),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Nome da Categoria e Porcentagem Real
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoria,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextColor(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${pct.toStringAsFixed(1)}% do total',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.getSubtextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Valor Real em vermelho
                    Text(
                      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }



  /// Exibe o modal detalhado de uma Categoria de Orçamento (Estilo da Tela Direita da Imagem 4),
  /// Exibe o modal detalhado de um Orçamento,
  /// apresentando métricas dos últimos 30 dias, limite orçado, percentual consumido,
  /// gráfico e lista das transações reais correspondentes.
  ///
  /// Parâmetros:
  /// - [item]: Mapa contendo as informações do orçamento, limite, gasto e cor.
  /// - [todasTransacoes]: Lista de todas as transações para filtrar as transações deste orçamento.
  void _exibirDetalhesOrcamento({
    required Map<String, dynamic> item,
    required List<Map<String, dynamic>> todasTransacoes,
  }) {
    final String nome = item['nome'] ?? 'Orçamento';
    final double limite = (item['limite'] as num?)?.toDouble() ?? 0.0;
    final double gasto = (item['gasto'] as num?)?.toDouble() ?? 0.0;
    final Color cor = item['cor'] as Color? ?? AppColors.getPrimaryAccent(context);
    final double pct = limite > 0 ? (gasto / limite).clamp(0.0, 1.0) : 0.0;

    // Identifica se é orçamento de despesa ou de receita/fonte de renda
    final lowerNome = nome.toLowerCase();
    final bool isReceita = (item['tipo'] == 'Receita') ||
        lowerNome.contains('trabalho') ||
        lowerNome.contains('freelance') ||
        lowerNome.contains('mesada') ||
        lowerNome.contains('salário') ||
        lowerNome.contains('salario') ||
        lowerNome.contains('renda') ||
        lowerNome.contains('investimento') ||
        lowerNome.contains('receita');

    final bool isGlobal = lowerNome.contains('geral') ||
        lowerNome.contains('global') ||
        lowerNome == 'orçamento' ||
        lowerNome == 'orcamento' ||
        lowerNome.contains('total do mês');

    // Filtra transações correspondentes a este orçamento no mês selecionado
    final transacoesOrcamento = todasTransacoes.where((t) {
      final String tipoTransacao = t['tipo'] ?? 'Despesa';
      if (isReceita) {
        if (tipoTransacao != 'Receita') return false;
      } else {
        if (tipoTransacao != 'Despesa') return false;
      }

      final DateTime dt = FinancialUtils.extrairDataTransacao(t);
      if (dt.year != _mesOrcamentoSelecionado.year ||
          dt.month != _mesOrcamentoSelecionado.month) {
        return false;
      }
      if (isGlobal) return true;

      final String catTransacao = (t['categoria'] ?? '').toString().toLowerCase();
      final String descTransacao = (t['titulo'] ?? t['descricao'] ?? '').toString().toLowerCase();

      if (isReceita) {
        return catTransacao.contains(lowerNome) ||
            lowerNome.contains(catTransacao) ||
            descTransacao.contains(lowerNome) ||
            lowerNome.contains(descTransacao);
      }

      if (lowerNome.contains('alimenta') || lowerNome.contains('mercado') || lowerNome.contains('comida') || lowerNome.contains('refeição')) {
        return catTransacao.contains('alimenta') || catTransacao.contains('mercado') || descTransacao.contains('mercado') || descTransacao.contains('alimenta');
      }
      if (lowerNome.contains('moradia') || lowerNome.contains('casa') || lowerNome.contains('aluguel')) {
        return catTransacao.contains('moradia') || descTransacao.contains('aluguel') || descTransacao.contains('casa');
      }
      if (lowerNome.contains('transporte') || lowerNome.contains('combustível') || lowerNome.contains('carro')) {
        return catTransacao.contains('transporte') || descTransacao.contains('uber') || descTransacao.contains('posto') || descTransacao.contains('gasolina');
      }
      if (lowerNome.contains('lazer') || lowerNome.contains('viagem')) {
        return catTransacao.contains('lazer') || descTransacao.contains('viagem') || descTransacao.contains('cinema');
      }
      if (lowerNome.contains('saúde') || lowerNome.contains('saude') || lowerNome.contains('farmácia')) {
        return catTransacao.contains('saúde') || catTransacao.contains('saude') || descTransacao.contains('farmácia');
      }
      if (lowerNome.contains('educação') || lowerNome.contains('educacao')) {
        return catTransacao.contains('educação') || catTransacao.contains('educacao');
      }

      return descTransacao.contains(lowerNome) || lowerNome.contains(descTransacao) || lowerNome.contains(catTransacao);
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewPadding.bottom + 20,
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  const SizedBox(height: 12),
                  // Alça superior do modal
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cabeçalho do Orçamento com Ícone e Nome
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_obterIconeOrcamento(nome), color: cor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextColor(context),
                              ),
                            ),
                            Text(
                              '${transacoesOrcamento.length} transações registradas',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.getSubtextColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 2 Cards de Métricas Superiores (Imagem 4)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.getInputFillColor(context),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isReceita ? 'Recebido no Mês' : 'Gasto no Mês',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.getSubtextColor(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isReceita
                                    ? '+ R\$ ${gasto.toStringAsFixed(2).replaceAll('.', ',')}'
                                    : '- R\$ ${gasto.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isReceita
                                      ? Colors.green.shade600
                                      : AppColors.getPrimaryAccent(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.getInputFillColor(context),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isReceita ? 'Meta Mensal' : 'Limite do Orçamento',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.getSubtextColor(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'R\$ ${limite.toStringAsFixed(2).replaceAll('.', ',')}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.getTextColor(context),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${(pct * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: cor),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Mini Gráfico de Barras de Histórico Mensal (Estilo Sport Analysis da Imagem 4)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.getInputFillColor(context),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Consumo Mensal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextColor(context),
                              ),
                            ),
                            Text(
                              '2026',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.getSubtextColor(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Barras verticais estilizadas de Jan a Ago
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            {'m': 'Jan', 'h': 35.0},
                            {'m': 'Fev', 'h': 65.0},
                            {'m': 'Mar', 'h': 45.0},
                            {'m': 'Abr', 'h': 55.0},
                            {'m': 'Mai', 'h': 85.0},
                            {'m': 'Jun', 'h': 40.0},
                            {'m': 'Jul', 'h': 70.0},
                            {'m': 'Ago', 'h': 90.0},
                          ].map((b) {
                            final double h = b['h'] as double;
                            final String mes = b['m'] as String;
                            final bool isAtivo = mes == 'Ago';
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 18,
                                  height: h,
                                  decoration: BoxDecoration(
                                    color: isAtivo ? cor : cor.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  mes,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isAtivo ? FontWeight.bold : FontWeight.w500,
                                    color: AppColors.getSubtextColor(context),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Lista de Transações do Orçamento
                  Text(
                    'Transações Deste Orçamento',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (transacoesOrcamento.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Nenhuma transação vinculada a este orçamento.',
                          style: TextStyle(color: AppColors.getSubtextColor(context), fontSize: 12.5),
                        ),
                      ),
                    )
                  else
                    ...transacoesOrcamento.map((t) {
                      final String desc = t['titulo'] ?? 'Despesa';
                      final double val = (t['valor'] as num?)?.toDouble() ?? 0.0;
                      final DateTime dt = FinancialUtils.extrairDataTransacao(t);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.getInputFillColor(context),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_obterIconeOrcamento(nome), color: cor, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    desc,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: AppColors.getTextColor(context),
                                    ),
                                  ),
                                  Text(
                                    _formatarDataAmigavel(dt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.getSubtextColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '- R\$ ${val.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: AppColors.getTextColor(context),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// CustomPainter para desenhar o Gráfico Donut da 3ª Imagem,
/// renderizando os arcos coloridos proporcionais de cada categoria com miolo vazado sem contornos.
class _DonutChartPainter extends CustomPainter {
  /// Lista de pares categoria -> valor ordenados por representatividade.
  final List<MapEntry<String, double>> categorias;

  /// Valor total acumulado de despesas.
  final double total;

  /// Cor de destaque padrão caso o total seja zero.
  final Color corPadrao;

  /// Indica se o app está em modo escuro.
  final bool isDark;

  /// Função para recuperar a cor correspondente a cada categoria.
  final Color Function(String) obterCor;

  _DonutChartPainter({
    required this.categorias,
    required this.total,
    required this.corPadrao,
    required this.isDark,
    required this.obterCor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const strokeWidth = 28.0;

    final backgroundPaint = Paint()
      ..color = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Fundo cinza suave do anel Donut
    canvas.drawCircle(center, radius, backgroundPaint);

    if (total <= 0 || categorias.isEmpty) return;

    double startAngle = -3.1415926535 / 2; // Começa no topo (12 horas)
    const double sweepGap = 0.05; // Pequeno espaçamento suave entre fatias

    for (final entry in categorias) {
      final sweepAngle = (entry.value / total) * (2 * 3.1415926535);
      if (sweepAngle <= 0.05) continue;

      final slicePaint = Paint()
        ..color = obterCor(entry.key)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (sweepGap / 2),
        sweepAngle - sweepGap,
        false,
        slicePaint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.categorias != categorias;
  }
}
