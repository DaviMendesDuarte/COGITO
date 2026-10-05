import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/common/constant/text_styles.dart';
import 'package:cogito/features/conrado/conrado_chat_page.dart';
import 'package:cogito/features/plans/plans_page.dart';
import 'package:cogito/services/debug_mock_service.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Tela de Gestão de Metas Financeiras ("Caixinhas") do aplicativo COGITO.
///
/// Organiza reservatórios de economia para objetivos específicos com:
/// - Indicadores visuais de progresso com esquema semafórico.
/// - Suporte a aportes diários, edições e exclusões.
/// - Separação por abas ("Em Andamento" e "Concluídas").
/// - Sincronização em tempo real via Cloud Firestore.
/// - Modularização de componentes para manter a árvore rasa e sem indentação profunda.
class MetasFinanceirasPage extends StatefulWidget {
  const MetasFinanceirasPage({super.key});

  @override
  MetasFinanceirasPageState createState() => MetasFinanceirasPageState();
}

/// Estado da [MetasFinanceirasPage].
class MetasFinanceirasPageState extends State<MetasFinanceirasPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Retorna o ID do cliente autenticado no Firebase.
  String _getClienteId() => FirebaseFirestoreService.idClienteAtual;

  /// Exibe modal com validação estrita para criação de uma nova meta financeira ("Caixinha").
  void exibirDialogoNovaMeta() {
    // 1. Verificação de limites de metas do plano atual
    final usuario = FirebaseFirestoreService.usuarioLogado;
    final String plano = (usuario?['plano'] ?? 'Grátis').toString().trim();
    final String pLower = plano.toLowerCase();
    final bool isMock = DebugMockService.instance.modoMockAtivo;
    final bool isPremium = pLower.contains('prem') || isMock;
    final bool isFreelancer = pLower.contains('free') || pLower.contains('lancer');

    // Identifica as metas ativas pertinentes ao usuário atual
    final String idCliente = _getClienteId();
    final List<Map<String, dynamic>> fonteMetas = isMock
        ? DebugMockService.instance.metasFinanceirasMock
        : _firestoreService.cacheMetasLocal;

    final int metasAtivas = fonteMetas
        .where((m) =>
            (isMock ||
                m['id_cliente'] == idCliente ||
                m['id_cliente'] == null ||
                m['id_cliente'] == 'guest') &&
            m['concluida'] != true &&
            m['status'] != 'concluida')
        .length;

    int limiteMetas = 2; // Plano Grátis: até 2 metas ativas simultâneas
    if (isFreelancer) limiteMetas = 5; // Freelancer: até 5 metas ativas
    if (isPremium) limiteMetas = 9999; // Premium ou Mock: ilimitadas

    if (metasAtivas >= limiteMetas) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.getCardColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.stars_rounded, color: AppColors.primaryOrange),
              const SizedBox(width: 8),
              Text(
                'Limite de Metas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ],
          ),
          content: Text(
            'Seu plano $plano permite até $limiteMetas metas financeiras ativas simultâneas.\n\nFaça um upgrade para o plano Premium e crie metas e caixinhas ilimitadas!',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              color: AppColors.getTextColor(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
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

    final formKey = GlobalKey<FormState>();
    final tituloController = TextEditingController();
    final objetivoController = TextEditingController(text: 'R\$ 0,00');
    final inicialController = TextEditingController(text: 'R\$ 0,00');
    String categoria = 'Reserva';
    final List<String> categorias = ['Reserva', 'Viagem', 'Veículo', 'Imóvel', 'Educação', 'Outros'];

    final Color corPrimaria = AppColors.getPrimaryAccent(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppColors.getCardColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.savings_outlined, color: corPrimaria),
              const SizedBox(width: 8),
              Text('Nova Meta Financeira', style: TextStyle(color: AppColors.getTextColor(context))),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: tituloController,
                    style: TextStyle(color: AppColors.getTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Nome da Meta (ex: Viagem de Férias)',
                      prefixIcon: Icon(Icons.flag_outlined, color: corPrimaria),
                      filled: true,
                      fillColor: AppColors.getInputFillColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe o nome da meta';
                      if (v.trim().length < 2) return 'Nome muito curto';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: objetivoController,
                    style: TextStyle(color: AppColors.getTextColor(context)),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _formatarMoedaEmTempoReal(val, objetivoController),
                    decoration: InputDecoration(
                      labelText: 'Valor Objetivo',
                      prefixIcon: Icon(Icons.attach_money, color: corPrimaria),
                      filled: true,
                      fillColor: AppColors.getInputFillColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe o valor objetivo';
                      final val = _extrairValorMoeda(v);
                      if (val <= 0) return 'O valor deve ser maior que R\$ 0,00';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: inicialController,
                    style: TextStyle(color: AppColors.getTextColor(context)),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _formatarMoedaEmTempoReal(val, inicialController),
                    decoration: InputDecoration(
                      labelText: 'Saldo Inicial Guardado',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: corPrimaria),
                      filled: true,
                      fillColor: AppColors.getInputFillColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categoria,
                    dropdownColor: AppColors.getCardColor(context),
                    style: TextStyle(color: AppColors.getTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Categoria',
                      prefixIcon: Icon(Icons.category_outlined, color: corPrimaria),
                      filled: true,
                      fillColor: AppColors.getInputFillColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    items: categorias.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: AppColors.getTextColor(context))))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => categoria = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final String titulo = tituloController.text.trim();
                final double objetivo = _extrairValorMoeda(objetivoController.text);
                final double inicial = _extrairValorMoeda(inicialController.text);

                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);

                await _firestoreService.salvarMeta(
                  idCliente: _getClienteId(),
                  titulo: titulo,
                  valorObjetivo: objetivo,
                  valorAtual: inicial,
                  categoria: categoria,
                );

                if (mounted) {
                  setState(() {});
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Meta "$titulo" criada com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: corPrimaria,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('CRIAR META', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Exibe o modal para edição de uma meta financeira existente com validação estrita.
  void _exibirDialogoEditarMeta(Map<String, dynamic> meta) {
    final formKey = GlobalKey<FormState>();
    final Color corPrimaria = AppColors.getPrimaryAccent(context);
    final tituloController = TextEditingController(text: meta['titulo'] ?? '');
    final double objetivoOriginal = (meta['valor_objetivo'] as num?)?.toDouble() ?? 0.0;
    final double atualOriginal = (meta['valor_atual'] as num?)?.toDouble() ?? 0.0;
    final objetivoController = TextEditingController(
      text: 'R\$ ${objetivoOriginal.toStringAsFixed(2).replaceAll('.', ',')}',
    );
    final inicialController = TextEditingController(
      text: 'R\$ ${atualOriginal.toStringAsFixed(2).replaceAll('.', ',')}',
    );
    String categoria = meta['categoria'] ?? 'Reserva';
    final List<String> categorias = ['Reserva', 'Viagem', 'Veículo', 'Imóvel', 'Educação', 'Outros'];
    if (!categorias.contains(categoria)) categorias.add(categoria);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppColors.getCardColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: corPrimaria),
              const SizedBox(width: 8),
              Text('Editar Meta', style: TextStyle(color: AppColors.getTextColor(context))),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: tituloController,
                    style: TextStyle(color: AppColors.getTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Nome da Meta',
                      prefixIcon: Icon(Icons.flag_outlined, color: corPrimaria),
                      filled: true,
                      fillColor: AppColors.getInputFillColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe o nome da meta';
                      if (v.trim().length < 2) return 'Nome muito curto';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: objetivoController,
                    style: TextStyle(color: AppColors.getTextColor(context)),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _formatarMoedaEmTempoReal(val, objetivoController),
                    decoration: InputDecoration(
                      labelText: 'Valor Objetivo',
                      prefixIcon: Icon(Icons.attach_money, color: corPrimaria),
                      filled: true,
                      fillColor: AppColors.getInputFillColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe o valor objetivo';
                      final val = _extrairValorMoeda(v);
                      if (val <= 0) return 'O valor deve ser maior que R\$ 0,00';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: inicialController,
                    style: TextStyle(color: AppColors.getTextColor(context)),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _formatarMoedaEmTempoReal(val, inicialController),
                    decoration: InputDecoration(
                      labelText: 'Saldo Acumulado',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: corPrimaria),
                      filled: true,
                      fillColor: AppColors.getInputFillColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categoria,
                    dropdownColor: AppColors.getCardColor(context),
                    style: TextStyle(color: AppColors.getTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Categoria',
                      prefixIcon: Icon(Icons.category_outlined, color: corPrimaria),
                      filled: true,
                      fillColor: AppColors.getInputFillColor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    items: categorias.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: AppColors.getTextColor(context))))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => categoria = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final String titulo = tituloController.text.trim();
                final double objetivo = _extrairValorMoeda(objetivoController.text);
                final double atual = _extrairValorMoeda(inicialController.text);

                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);

                await _firestoreService.salvarMeta(
                  idCliente: _getClienteId(),
                  metaId: meta['firestore_id'],
                  titulo: titulo,
                  valorObjetivo: objetivo,
                  valorAtual: atual,
                  categoria: categoria,
                );

                if (mounted) {
                  setState(() {});
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Meta "$titulo" atualizada com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: corPrimaria,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('SALVAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Exibe modal para aportar (adicionar dinheiro) na meta financeira selecionada.
  void _exibirDialogoAporte(Map<String, dynamic> meta) {
    final valorAporteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.add_card, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Aportar em "${meta['titulo']}"', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo atual: R\$ ${((meta['valor_atual'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: valorAporteController,
              keyboardType: TextInputType.number,
              autofocus: true,
              onChanged: (val) => _formatarMoedaEmTempoReal(val, valorAporteController),
              decoration: InputDecoration(
                labelText: 'Valor do Aporte',
                hintText: 'R\$ 0,00',
                prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final double aporte = _extrairValorMoeda(valorAporteController.text);
              if (aporte > 0) {
                Navigator.pop(ctx);
                await _efetivarAporte(meta, aporte);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ADICIONAR DINHEIRO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Realiza o aporte financeiro no Firebase Firestore e atualiza o estado local.
  Future<void> _efetivarAporte(Map<String, dynamic> meta, double aporte) async {
    final String metaId = (meta['firestore_id'] ?? meta['id'] ?? '').toString();
    final double valorAtual = (meta['valor_atual'] as num?)?.toDouble() ?? 0.0;
    final double valorObjetivo = (meta['valor_objetivo'] as num?)?.toDouble() ?? 1.0;

    // 1. Chamada atômica ao Firestore ou Mock para somar o valor e verificar conclusão
    await _firestoreService.aportarMeta(
      metaId: metaId,
      valorAporte: aporte,
      valorAtualAntigo: valorAtual,
      valorObjetivo: valorObjetivo,
      idCliente: _getClienteId(),
    );

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Aporte de R\$ ${aporte.toStringAsFixed(2)} adicionado com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Formata moeda em tempo real enquanto o usuário digita.
  void _formatarMoedaEmTempoReal(String value, TextEditingController controller) {
    String clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) {
      controller.value = const TextEditingValue(text: 'R\$ 0,00', selection: TextSelection.collapsed(offset: 7));
      return;
    }
    final double parsed = (double.tryParse(clean) ?? 0) / 100.0;
    final String formatted = 'R\$ ${parsed.toStringAsFixed(2).replaceAll('.', ',')}';
    controller.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }

  /// Converte a string de moeda formatada em double.
  double _extrairValorMoeda(String text) {
    final clean = text.replaceAll('R\$', '').replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  /// Retorna a cor semafórica de acordo com a porcentagem atingida.
  static Color getCorSemaforo(double percentual) {
    if (percentual < 0.34) return const Color(0xFFE53935);
    if (percentual < 0.67) return const Color(0xFFFB8C00);
    return const Color(0xFF4CAF50);
  }

  @override
  Widget build(BuildContext context) {
    final String idCliente = _getClienteId();
    final bool isDark = AppColors.isDarkMode(context);
    final Color corPrimaria = AppColors.getPrimaryAccent(context);
    final Color corDestaque = isDark ? AppColors.primaryOrange : corPrimaria;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
          : AppColors.getOverlayStyleForBackground(corPrimaria),
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: _buildAppBar(corPrimaria, isDark),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          initialData: FirebaseFirestoreService.obterMetasDoCache(idCliente),
          stream: _firestoreService.buscarMetasStream(idCliente),
          builder: (context, snapshot) {
            final List<Map<String, dynamic>> todasMetas =
                snapshot.data ?? FirebaseFirestoreService.obterMetasDoCache(idCliente);

            // Totalizadores acumulados
            double totalAtual = 0;
            double totalObjetivo = 0;
            for (final m in todasMetas) {
              totalAtual += (m['valor_atual'] as num?)?.toDouble() ?? 0.0;
              totalObjetivo += (m['valor_objetivo'] as num?)?.toDouble() ?? 0.0;
            }

            final double progressoGeral = totalObjetivo > 0 ? (totalAtual / totalObjetivo).clamp(0.0, 1.0) : 0.0;
            final metasEmAndamento = todasMetas.where((m) => (m['concluida'] != true)).toList();
            final metasConcluidas = todasMetas.where((m) => (m['concluida'] == true)).toList();

            return Column(
              children: [
                // Resumo do progresso total (limpo sem sombras)
                _HeaderProgressoTotal(
                  atual: totalAtual,
                  objetivo: totalObjetivo,
                  progresso: progressoGeral,
                ),

                // Lista de metas separadas por abas
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaMetas(
                        metasEmAndamento,
                        isConcluidas: false,
                        totalAtual: totalAtual,
                        totalObjetivo: totalObjetivo,
                      ),
                      _buildListaMetas(
                        metasConcluidas,
                        isConcluidas: true,
                        totalAtual: totalAtual,
                        totalObjetivo: totalObjetivo,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: exibirDialogoNovaMeta,
          backgroundColor: corDestaque,
          elevation: 0,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Nova Meta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  /// Constrói a AppBar superior com abas de alternância e acento dinâmico.
  /// No modo escuro, utiliza o fundo escuro do app e destaca as abas com a cor laranja.
  PreferredSizeWidget _buildAppBar(Color corPrimaria, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppColors.getBackgroundColor(context) : corPrimaria,
      elevation: 0,
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: isDark ? AppColors.getTextColor(context) : Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: Text(
        'Metas Financeiras',
        style: TextStyle(
          color: isDark ? AppColors.getTextColor(context) : Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: isDark ? AppColors.primaryOrange : AppColors.primaryYellow,
        indicatorWeight: 3,
        labelColor: isDark ? AppColors.primaryOrange : Colors.white,
        unselectedLabelColor: isDark ? AppColors.getSubtextColor(context) : Colors.white70,
        tabs: const [
          Tab(icon: Icon(Icons.hourglass_top_outlined, size: 20), text: 'Em Andamento'),
          Tab(icon: Icon(Icons.check_circle_outline, size: 20), text: 'Concluídas'),
        ],
      ),
    );
  }

  /// Gera insight inteligente e contextual do CONRADO para a gestão de metas financeiras.
  String _obterDicaConrado({
    required bool isConcluidas,
    required List<Map<String, dynamic>> metas,
    required double totalAtual,
    required double totalObjetivo,
  }) {
    if (isConcluidas) {
      if (metas.isEmpty) {
        return 'Suas conquistas financeiras aparecerão aqui assim que atingir 100% de cada objetivo. Cada caixinha concluída é um grande passo para sua liberdade financeira!';
      }
      return 'Sensacional! Você já concluiu ${metas.length} meta${metas.length > 1 ? 's' : ''}! O hábito de poupar com consistência transforma sonhos em realidade. Que tal definir sua próxima caixinha?';
    }

    if (metas.isEmpty) {
      return 'Guardar dinheiro sem um propósito claro torna a economia mais difícil. Crie sua primeira caixinha agora e estipule pequenos aportes semanais para transformar intenção em resultado!';
    }

    final double percentualGeral =
        totalObjetivo > 0 ? (totalAtual / totalObjetivo) * 100 : 0.0;

    if (percentualGeral >= 80) {
      return 'Você já atingiu ${percentualGeral.toStringAsFixed(1)}% do seu objetivo total! Falta muito pouco para bater sua meta. Mantenha o foco e direcione suas sobras para fechar essa conquista!';
    } else if (percentualGeral >= 40) {
      return 'Ritmo excelente! Com ${percentualGeral.toStringAsFixed(1)}% alcançado, o segredo é a constância: aportes semanais pequenos e automáticos são 3x mais eficazes que grandes valores esporádicos.';
    } else {
      return 'O primeiro passo é sempre o mais importante! Automatizar um pequeno valor toda vez que receber uma entrada acelerará seu progresso para alcançar R\$ ${totalObjetivo.toStringAsFixed(2)}.';
    }
  }

  /// Constrói o Card "Dicas do CONRADO" (Análise Inteligente) estilizado com o mesmo padrão do "Entenda o CONRADO".
  Widget _buildCardDicasDoConrado({
    required bool isConcluidas,
    required List<Map<String, dynamic>> metas,
    required double totalAtual,
    required double totalObjetivo,
  }) {
    final String dica = _obterDicaConrado(
      isConcluidas: isConcluidas,
      metas: metas,
      totalAtual: totalAtual,
      totalObjetivo: totalObjetivo,
    );

    final Color corCard = AppColors.getPrimaryAccent(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: corCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: corCard.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com ícone autêntico de coroa, título e tag "Análise Inteligente"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(MdiIcons.crown, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Dicas do CONRADO',
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

          // Caixa translúcida com a dica contextual do Conrado
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
                    dica,
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

          // Botão pill branco: leva ao chat com o CONRADO com mensagem inicial de metas
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                final String mensagemInicial = isConcluidas
                    ? 'Olá Conrado! Acompanhei minhas metas financeiras concluídas no COGITO. Como você me recomenda direcionar esses recursos conquistados para acelerar minha independência financeira?'
                    : 'Olá Conrado! Estou acompanhando minhas metas financeiras e caixinhas no COGITO. Você pontuou: "$dica". Que estratégias práticas você me sugere para atingir meus objetivos mais rápido?';

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConradoChatPage(
                      chatId:
                          'chat_metas_${DateTime.now().millisecondsSinceEpoch}',
                      tituloChat: 'Dicas do CONRADO',
                      topicoChat: 'Metas Financeiras e Caixinhas',
                      mensagemInicial: mensagemInicial,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.primaryBlue,
                size: 18,
              ),
              label: const Text(
                'Conversar com o CONRADO',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói o estado visual quando não há metas na aba selecionada.
  Widget _buildEstadoVazioMetas({required bool isConcluidas}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConcluidas ? Icons.emoji_events_outlined : Icons.savings_outlined,
            size: 56,
            color: AppColors.getSubtextColor(context).withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            isConcluidas
                ? 'Nenhuma meta concluída ainda.'
                : 'Você ainda não possui metas em andamento.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.getSubtextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isConcluidas
                ? 'Continue guardando regularmente nas suas caixinhas ativas para vê-las aqui!'
                : 'Defina objetivos para seus sonhos clicando no botão "Nova Meta" abaixo.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.getSubtextColor(context).withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Constrói a lista de caixinhas integrando o Card "Dicas do CONRADO" ao fluxo de rolagem.
  /// Inclui espaçamento inferior de 96px para que o botão "Nova Meta" nunca ofusque nenhum elemento.
  Widget _buildListaMetas(
    List<Map<String, dynamic>> metas, {
    required bool isConcluidas,
    required double totalAtual,
    required double totalObjetivo,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        // Card "Dicas do CONRADO" (estilo Entenda o CONRADO)
        _buildCardDicasDoConrado(
          isConcluidas: isConcluidas,
          metas: metas,
          totalAtual: totalAtual,
          totalObjetivo: totalObjetivo,
        ),

        // Estado Vazio ou Lista de Caixinhas
        if (metas.isEmpty)
          _buildEstadoVazioMetas(isConcluidas: isConcluidas)
        else
          ...metas.map((m) {
            return _MetaCard(
              meta: m,
              isConcluida: isConcluidas,
              onEditar: () => _exibirDialogoEditarMeta(m),
              onAporte: () => _exibirDialogoAporte(m),
              onExcluir: () async {
                final String metaId =
                    (m['firestore_id'] ?? m['id'] ?? '').toString();
                if (metaId.isNotEmpty) {
                  await _firestoreService.excluirMeta(
                    metaId,
                    idCliente: _getClienteId(),
                  );
                  if (mounted) setState(() {});
                }
              },
            );
          }),
      ],
    );
  }
}

/// Card superior com o progresso consolidado das caixinhas (sem sombras).
class _HeaderProgressoTotal extends StatelessWidget {
  final double atual;
  final double objetivo;
  final double progresso;

  const _HeaderProgressoTotal({
    required this.atual,
    required this.objetivo,
    required this.progresso,
  });

  @override
  Widget build(BuildContext context) {
    final cor = MetasFinanceirasPageState.getCorSemaforo(progresso);
    final Color corPrimaria = AppColors.getPrimaryAccent(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progresso Total das Caixinhas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: corPrimaria),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: cor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${(progresso * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: cor, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 10,
              backgroundColor: AppColors.isDarkMode(context) ? Colors.white10 : Colors.grey.shade200,
              color: cor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Acumulado: R\$ ${atual.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getTextColor(context)),
              ),
              Text(
                'Objetivo: R\$ ${objetivo.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: AppColors.getSubtextColor(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card de exibição individual de uma meta financeira (sem contorno e sem sombra).
class _MetaCard extends StatelessWidget {
  final Map<String, dynamic> meta;
  final bool isConcluida;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback onAporte;

  const _MetaCard({
    required this.meta,
    required this.isConcluida,
    required this.onEditar,
    required this.onExcluir,
    required this.onAporte,
  });

  @override
  Widget build(BuildContext context) {
    final double atual = (meta['valor_atual'] as num?)?.toDouble() ?? 0.0;
    final double objetivo = (meta['valor_objetivo'] as num?)?.toDouble() ?? 1.0;
    final double progresso = (atual / objetivo).clamp(0.0, 1.0);
    final Color cor = MetasFinanceirasPageState.getCorSemaforo(progresso);
    final Color corPrimaria = AppColors.getPrimaryAccent(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: cor.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.savings_outlined, color: cor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meta['titulo'] ?? 'Sem Título',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextColor(context)),
                          ),
                          Text(
                            meta['categoria'] ?? 'Geral',
                            style: TextStyle(fontSize: 12, color: AppColors.getSubtextColor(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: corPrimaria, size: 20),
                    tooltip: 'Editar Meta',
                    onPressed: onEditar,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: AppColors.getSubtextColor(context), size: 20),
                    tooltip: 'Excluir Meta',
                    onPressed: onExcluir,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 8,
              backgroundColor: AppColors.isDarkMode(context) ? Colors.white10 : Colors.grey.shade200,
              color: cor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SALDO ACUMULADO',
                    style: TextStyle(fontSize: 10, color: AppColors.getSubtextColor(context), fontWeight: FontWeight.bold),
                  ),
                  Text('R\$ ${atual.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cor)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'META FINAL',
                    style: TextStyle(fontSize: 10, color: AppColors.getSubtextColor(context), fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'R\$ ${objetivo.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.getTextColor(context)),
                  ),
                ],
              ),
            ],
          ),
          if (!isConcluida) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAporte,
                icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.white),
                label: const Text('Adicionar Dinheiro à Caixinha', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: corPrimaria,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


