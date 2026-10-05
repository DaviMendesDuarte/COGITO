import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Modal e Tela de Planos do COGITO em formato de Pop-up Deslizável (Draggable Bottom Sheet).
///
/// Características:
/// - Abertura como pop-up deslizável na própria tela da dashboard e em outras áreas.
/// - Cores temáticas simplificadas e específicas:
///   * Plano Freelancer: Laranja (AppColors.primaryOrange).
///   * Plano Premium: Amarelo (AppColors.primaryYellow).
///   * Plano Grátis: Azul-marinho clássico sóbrio (AppColors.primaryBlue).
/// - Modularização de componentes para manter a árvore rasa e sem indentação excessiva.
class PlanosModal {
  /// Exibe o pop-up deslizável de planos diretamente na tela atual.
  static void exibir(BuildContext context, {VoidCallback? onPlanoAtualizado}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => PlanosBottomSheet(onPlanoAtualizado: onPlanoAtualizado),
    );
  }
}

/// Widget que renderiza o conteúdo deslizável dos planos com DraggableScrollableSheet.
class PlanosBottomSheet extends StatefulWidget {
  /// Callback disparado quando o plano é atualizado com sucesso no backend.
  final VoidCallback? onPlanoAtualizado;

  /// Construtor constante do Bottom Sheet de planos.
  const PlanosBottomSheet({super.key, this.onPlanoAtualizado});

  @override
  State<PlanosBottomSheet> createState() => _PlanosBottomSheetState();
}

class _PlanosBottomSheetState extends State<PlanosBottomSheet> {
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  String _planoAtual = 'Grátis';
  bool _isLoading = false;

  /// Controller para o carrossel horizontal de planos (deslizável para o lado).
  final PageController _horizontalPlansController =
      PageController(viewportFraction: 0.88);

  /// Índice atual do plano em visualização no carrossel lateral.
  int _horizontalActiveIndex = 0;

  @override
  void initState() {
    super.initState();
    final usuario = FirebaseFirestoreService.usuarioLogado;
    if (usuario != null && usuario['plano'] != null) {
      _planoAtual = usuario['plano'];
    }
  }

  @override
  void dispose() {
    _horizontalPlansController.dispose();
    super.dispose();
  }

  /// Inicia a troca de plano abrindo confirmação de downgrade ou modal de checkout.
  void _iniciarTrocaPlano(String novoPlano, String preco) {
    if (novoPlano == _planoAtual) return;

    if (novoPlano == 'Grátis') {
      _exibirDialogoConfirmarDowngrade();
    } else {
      _exibirModalCheckout(novoPlano, preco);
    }
  }

  /// Diálogo de confirmação para downgrade ao plano Grátis.
  void _exibirDialogoConfirmarDowngrade() {
    final bool isDark = AppColors.isDarkMode(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.getBorderColor(context)),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
            ),
            const SizedBox(width: 8),
            Text(
              'Alterar para Grátis',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppColors.getTextColor(context),
              ),
            ),
          ],
        ),
        content: Text(
          'Ao retornar para o plano Grátis, os recursos avançados de IA e de relatórios serão limitados. Deseja prosseguir?',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.35,
            color: AppColors.getSubtextColor(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _efetivarPlanoNoFirestore('Grátis');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Abre o modal de Checkout com PIX e Cartão de Crédito com suporte ao tema escuro.
  void _exibirModalCheckout(String novoPlano, String preco) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _CheckoutModal(
        novoPlano: novoPlano,
        preco: preco,
        onConfirmar: () async {
          Navigator.pop(sheetCtx);
          await _efetivarPlanoNoFirestore(novoPlano);
        },
      ),
    );
  }

  /// Atualiza o plano do cliente autenticado no Cloud Firestore.
  Future<void> _efetivarPlanoNoFirestore(String novoPlano) async {
    setState(() => _isLoading = true);

    final uid = FirebaseFirestoreService.idClienteAtual;
    await _firestoreService.atualizarPlano(uid, novoPlano);

    if (!mounted) return;

    setState(() {
      _planoAtual = novoPlano;
      _isLoading = false;
    });

    widget.onPlanoAtualizado?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Plano "$novoPlano" ativado com sucesso!', style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: novoPlano == 'Freelancer'
            ? AppColors.primaryOrange
            : (novoPlano == 'Premium' ? const Color(0xFFE5A000) : AppColors.primaryBlue),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double sheetHeight = (MediaQuery.of(context).size.height * 0.58).clamp(430.0, 480.0);
    final bool isDark = AppColors.isDarkMode(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra superior e alça de arrasto do popup
              const _PlanosHeader(),

              Divider(height: 1, color: AppColors.getDividerColor(context)),

              // Subtítulo comparativo
              const _CompareSubheader(),

              // Carrossel horizontal de planos
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
                        ),
                      )
                    : _buildCarrosselPlanos(),
              ),

              // Indicadores de bolinha (dots)
              _buildPageIndicators(),
            ],
          ),
        ),
      ),
    );
  }

  /// Constrói o PageView com os 3 planos do aplicativo.
  Widget _buildCarrosselPlanos() {
    final bool isDark = AppColors.isDarkMode(context);

    return PageView(
      controller: _horizontalPlansController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (idx) => setState(() => _horizontalActiveIndex = idx),
      children: [
        _PlanCard(
          nome: 'Grátis',
          preco: 'R\$ 0,00',
          periodo: '/mês',
          descricao: 'Controle orçamentário essencial para o seu dia a dia.',
          corTema: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
          recursos: const [
            'Lançamento manual de receitas e despesas',
            'Vinculação de 1 conta bancária consolidada',
            '1 conversa ativa com o assistente CONRADO',
            'Até 2 metas financeiras simultâneas',
            'Dicas financeiras inteligentes do CONRADO',
          ],
          isAtual: _planoAtual == 'Grátis',
          onSelecionar: () => _iniciarTrocaPlano('Grátis', 'R\$ 0,00'),
        ),
        _PlanCard(
          nome: 'Freelancer',
          preco: 'R\$ 5,90',
          periodo: '/mês',
          descricao: 'Para profissionais autônomos com fluxo de caixa variável.',
          corTema: AppColors.primaryOrange,
          badge: 'RECOMENDADO',
          recursos: const [
            'Até 3 contas bancárias para saldo consolidado',
            'Até 2 conversas simultâneas com o CONRADO',
            'Assistente CONRADO com digitação livre',
            'Até 5 metas financeiras simultâneas',
            'Exportação de extratos em PDF e planilhas',
          ],
          isAtual: _planoAtual == 'Freelancer',
          onSelecionar: () => _iniciarTrocaPlano('Freelancer', 'R\$ 5,90'),
        ),
        _PlanCard(
          nome: 'Premium',
          preco: 'R\$ 15,90',
          periodo: '/mês',
          descricao: 'Assistente CONRADO completo com conversas simultâneas ilimitadas.',
          corTema: AppColors.primaryYellow,
          badge: 'COMPLETO & ILIMITADO',
          recursos: const [
            'Contas bancárias e saldo consolidado ilimitados',
            'Conversas simultâneas ilimitadas com o CONRADO',
            'Metas financeiras ilimitadas',
            'Categorização inteligente de transações',
            'Consultoria financeira personalizada 24/7',
          ],
          isAtual: _planoAtual == 'Premium',
          onSelecionar: () => _iniciarTrocaPlano('Premium', 'R\$ 15,90'),
        ),
      ],
    );
  }

  /// Constrói os indicadores de página ativos/inativos.
  Widget _buildPageIndicators() {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final bool isSelected = _horizontalActiveIndex == index;
          final Color cor = index == 0
              ? AppColors.primaryBlue
              : (index == 1 ? AppColors.primaryOrange : AppColors.primaryYellow);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isSelected ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isSelected ? cor : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

/// Cabeçalho superior do modal de planos com título e botão de fechar com suporte ao tema escuro.
class _PlanosHeader extends StatelessWidget {
  const _PlanosHeader();

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode(context);

    return Column(
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    MdiIcons.crown,
                    color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Planos COGITO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: isDark ? Colors.white60 : Colors.grey, size: 22),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Fechar',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Subcabeçalho com título descritivo e dica de deslize horizontal.
class _CompareSubheader extends StatelessWidget {
  const _CompareSubheader();

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Compare os planos disponíveis',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.primaryBlue,
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Icon(Icons.swipe_outlined, size: 14, color: isDark ? Colors.white38 : Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Deslize pro lado',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card de exibição individual de cada plano no carrossel adaptado ao tema escuro.
class _PlanCard extends StatelessWidget {
  final String nome;
  final String preco;
  final String periodo;
  final String descricao;
  final List<String> recursos;
  final Color corTema;
  final String? badge;
  final bool isAtual;
  final VoidCallback onSelecionar;

  const _PlanCard({
    required this.nome,
    required this.preco,
    required this.periodo,
    required this.descricao,
    required this.recursos,
    required this.corTema,
    this.badge,
    required this.isAtual,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final bool isYellow = corTema == AppColors.primaryYellow;
    final bool isDark = AppColors.isDarkMode(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAtual
            ? corTema.withValues(alpha: isDark ? 0.15 : 0.08)
            : AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha com nome do plano, badge e tag de plano ativo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(nome, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: corTema)),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: corTema.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isYellow ? const Color(0xFFB87800) : corTema,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isAtual)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PLANO ATUAL',
                      style: TextStyle(
                        color: isDark ? Colors.greenAccent : Colors.green.shade800,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Preço e período
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(preco, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: corTema)),
                const SizedBox(width: 3),
                Text(
                  periodo,
                  style: TextStyle(fontSize: 11.5, color: AppColors.getSubtextColor(context)),
                ),
              ],
            ),
            const SizedBox(height: 4),

            Text(
              descricao,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: AppColors.getSubtextColor(context), height: 1.25),
            ),
            const SizedBox(height: 8),

            // Lista de recursos
            ...recursos.map(
              (rec) => Padding(
                padding: const EdgeInsets.only(bottom: 3.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_rounded, color: corTema, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rec,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: AppColors.getTextColor(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Botão de seleção
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                onPressed: isAtual ? null : onSelecionar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: corTema,
                  foregroundColor: isYellow ? Colors.black87 : Colors.white,
                  disabledBackgroundColor: isDark ? Colors.white12 : const Color(0xFFEBECEF),
                  disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade600,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isAtual ? 'Plano Ativo' : 'Selecionar $nome',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal de checkout com simulação de gateway de pagamento (PIX e Cartão) adaptado ao tema escuro.
class _CheckoutModal extends StatefulWidget {
  final String novoPlano;
  final String preco;
  final Future<void> Function() onConfirmar;

  const _CheckoutModal({
    required this.novoPlano,
    required this.preco,
    required this.onConfirmar,
  });

  @override
  State<_CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends State<_CheckoutModal> {
  String _metodo = 'PIX';
  bool _processando = false;

  @override
  Widget build(BuildContext context) {
    final Color corPlano = widget.novoPlano == 'Freelancer' ? AppColors.primaryOrange : AppColors.primaryYellow;
    final bool isDark = AppColors.isDarkMode(context);

    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: corPlano.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(Icons.lock_outline, color: corPlano, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Checkout Seguro COGITO',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : AppColors.primaryBlue,
                          ),
                        ),
                        Text(
                          'Ambiente Criptografado SSL 256-bit',
                          style: TextStyle(fontSize: 11, color: AppColors.getSubtextColor(context)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? Colors.white60 : Colors.grey, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.getInputFillColor(context) : const Color(0xFFF6F7FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plano ${widget.novoPlano}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: corPlano)),
                      const SizedBox(height: 2),
                      Text('Renovação Mensal', style: TextStyle(fontSize: 11, color: AppColors.getSubtextColor(context))),
                    ],
                  ),
                  Text('${widget.preco}/mês', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: corPlano)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _PaymentOptionPill(
                    label: 'PIX',
                    icon: Icons.qr_code,
                    isSelected: _metodo == 'PIX',
                    cor: corPlano,
                    onTap: () => setState(() => _metodo = 'PIX'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PaymentOptionPill(
                    label: 'Cartão',
                    icon: Icons.credit_card,
                    isSelected: _metodo == 'Cartão',
                    cor: corPlano,
                    onTap: () => setState(() => _metodo = 'Cartão'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _processando
                  ? null
                  : () async {
                      setState(() => _processando = true);
                      await Future.delayed(const Duration(milliseconds: 1000));
                      if (!mounted) return;
                      await widget.onConfirmar();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: corPlano,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _processando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _metodo == 'PIX' ? 'Confirmar Pagamento PIX' : 'Concluir Pagamento (${widget.preco})',
                      style: TextStyle(color: widget.novoPlano == 'Premium' ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pílula de seleção do método de pagamento adaptada ao tema escuro.
class _PaymentOptionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color cor;
  final VoidCallback onTap;

  const _PaymentOptionPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? cor
              : (isDark ? AppColors.getInputFillColor(context) : const Color(0xFFF6F7FA)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? cor : AppColors.getBorderColor(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? (cor == AppColors.primaryYellow ? Colors.black87 : Colors.white)
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (cor == AppColors.primaryYellow ? Colors.black87 : Colors.white)
                    : (isDark ? Colors.white70 : Colors.grey.shade800),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Página de fallback caso os planos sejam abertos em rota de tela inteira adaptada ao tema escuro.
class PlanosPage extends StatelessWidget {
  const PlanosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.getPrimaryAccent(context),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Planos COGITO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: AppColors.getPrimaryAccent(context),
          ),
        ),
      ),
      body: const PlanosBottomSheet(),
    );
  }
}
