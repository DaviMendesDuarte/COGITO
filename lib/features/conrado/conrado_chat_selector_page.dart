import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/common/constant/text_styles.dart';
import 'package:cogito/features/conrado/conrado_chat_page.dart';
import 'package:cogito/features/plans/plans_page.dart';
import 'package:cogito/services/debug_mock_service.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Tela Hub de Apresentação e Seleção de Chats do CONRADO.
///
/// Apresenta interface minimalista com:
/// - Hero View centralizada com apresentação do CONRADO.
/// - Mascote oficial CONRADO em escala ampliada.
/// - Seção interativa "CONRADO diz:" com dicas financeiras rotativas.
/// - Botão de destaque "Iniciar chat com CONRADO".
/// - Integração direta com o Cloud Firestore para listagem de sessões.
/// - Histórico com política de retenção de 7 dias e recurso de exportação.
class ConradoChatSelectorPage extends StatefulWidget {
  /// Construtor padrão da tela seletora de chats.
  const ConradoChatSelectorPage({super.key});

  @override
  State<ConradoChatSelectorPage> createState() =>
      _ConradoChatSelectorPageState();
}

class _ConradoChatSelectorPageState extends State<ConradoChatSelectorPage> {
  /// Instância do serviço Firebase Firestore para persistência de dados.
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  /// Lista de dicas inteligentes rotativas exibidas na seção "CONRADO diz:".
  final List<String> _dicasConrado = [
    'Separe 20% do faturamento para imprevistos e custos fixos antes de definir seu pró-labore.',
    'Nunca misture a conta bancária do seu negócio com suas contas e despesas pessoais.',
    'Monte sua Reserva de Emergência para cobrir de 3 a 6 meses dos seus custos essenciais.',
    'Calcule seu valor por hora considerando horas não faturáveis e dias de descanso.',
    'A regra 50-30-20 equilibra 50% em necessidades, 30% em lazer e 20% em investimentos.',
    'Revise semanalmente suas despesas invisíveis e assinaturas que não está mais utilizando.',
  ];

  /// Índice da dica atualmente visível em tela.
  int _indiceDicaAtual = 0;

  /// Indica se os chats estão sendo carregados do Firestore.
  bool _carregandoChats = false;

  /// Lista em memória de sessões ativas de conversa carregadas do Firestore.
  final List<Map<String, dynamic>> _chatSessions = [];

  @override
  void initState() {
    super.initState();
    _carregarChatsFirestore();
    DebugMockService.instance.modoMockAtivoNotifier.addListener(_onMockChanged);
  }

  /// Recarrega a listagem de conversas caso o usuário ative ou desative a versão mock.
  void _onMockChanged() {
    if (mounted) {
      _carregarChatsFirestore();
    }
  }

  @override
  void dispose() {
    DebugMockService.instance.modoMockAtivoNotifier.removeListener(_onMockChanged);
    super.dispose();
  }

  /// Carrega as conversas do Firestore pertencentes ao usuário logado.
  Future<void> _carregarChatsFirestore() async {
    final String uid = FirebaseFirestoreService.idClienteAtual;
    if (uid.isEmpty) return;

    setState(() => _carregandoChats = true);

    try {
      final chatsRemotos = await _firestoreService.obterSessoesChat(
        idCliente: uid,
      );
      if (!mounted) return;

      setState(() {
        _chatSessions.clear();
        for (final c in chatsRemotos) {
          _chatSessions.add({
            'id': c['id'],
            'titulo': c['titulo'],
            'topico': c['topico'] ?? c['titulo'],
            'ultimaMensagem': c['ultimaMensagem'],
            'mensagensCount': c['mensagensCount'],
            'atualizadoEm': c['atualizadoEm'] ?? DateTime.now(),
            'iconColor': AppColors.primaryBlue,
          });
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar chats do Firestore: $e');
    } finally {
      if (mounted) setState(() => _carregandoChats = false);
    }
  }

  /// Alterna para a próxima dica do CONRADO com feedback tátil.
  void _proximaDica() {
    setState(() {
      _indiceDicaAtual = (_indiceDicaAtual + 1) % _dicasConrado.length;
    });
    HapticFeedback.lightImpact();
  }

  /// Cria uma nova sessão de chat com o CONRADO ou alerta sobre o limite de conversas simultâneas do plano.
  void _criarNovoChat([String? tituloInicial, String? topicoInicial]) {
    final usuario = FirebaseFirestoreService.usuarioLogado;
    final String plano = usuario?['plano'] ?? 'Grátis';
    final bool isPremium = plano == 'Premium' || DebugMockService.instance.modoMockAtivo;
    final bool isFreelancer = plano == 'Freelancer';

    // Regras de conversas simultâneas do CONRADO:
    // - Grátis: até 1 conversa ativa
    // - Freelancer: até 2 conversas ativas
    // - Premium: conversas simultâneas ilimitadas
    int limiteChats = 1;
    if (isFreelancer) limiteChats = 2;
    if (isPremium) limiteChats = 9999;

    if (_chatSessions.length >= limiteChats) {
      _exibirDialogoLimiteChats(plano, limiteChats);
      return;
    }

    final String novoId = 'chat_${DateTime.now().millisecondsSinceEpoch}';
    final String titulo = tituloInicial ?? 'Conversa com CONRADO';
    final String topico = topicoInicial ?? titulo;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConradoChatPage(
          chatId: novoId,
          tituloChat: titulo,
          topicoChat: topico,
        ),
      ),
    ).then((_) => _carregarChatsFirestore());
  }

  /// Exibe diálogo informativo explicando o limite de conversas simultâneas do plano atual.
  void _exibirDialogoLimiteChats(String planoAtual, int limiteAtual) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.stars_rounded, color: AppColors.primaryYellow),
            const SizedBox(width: 8),
            Text(
              'Limite de Conversas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppColors.getTextColor(context),
              ),
            ),
          ],
        ),
        content: Text(
          'No seu plano $planoAtual, o limite é de $limiteAtual ${limiteAtual == 1 ? "conversa ativa" : "conversas simultâneas"} com o CONRADO.\n\n'
          'Para criar conversas paralelas ilimitadas e organizar tópicos diferentes ao mesmo tempo, faça upgrade para o plano Premium ou utilize seus chats atuais.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.35,
            color: AppColors.getTextColor(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_chatSessions.isNotEmpty) {
                final primeiroChat = _chatSessions.first;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConradoChatPage(
                      chatId: primeiroChat['id'],
                      tituloChat: primeiroChat['titulo'],
                      topicoChat: primeiroChat['topico'],
                    ),
                  ),
                ).then((_) => _carregarChatsFirestore());
              }
            },
            child: const Text('Abrir Chat Atual'),
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
            child: const Text('Conhecer Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Remove permanentemente uma sessão de chat da lista local e do Firestore.
  Future<void> _excluirChat(int index) async {
    final chat = _chatSessions[index];
    final String chatId = chat['id'] ?? '';
    final String uid = FirebaseFirestoreService.idClienteAtual;

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'Excluir conversa?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: const Text(
          'Esta conversa e todas as mensagens serão excluídas permanentemente.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _chatSessions.removeAt(index));

    if (chatId.isNotEmpty && uid.isNotEmpty) {
      await _firestoreService.excluirSessaoChat(idCliente: uid, chatId: chatId);
    }
  }

  /// Calcula a quantidade de dias restantes para a expiração do chat (regra de 7 dias).
  String _calcularDiasRestantes(DateTime dataAtualizacao) {
    final agora = DateTime.now();
    final diferenca = agora.difference(dataAtualizacao).inDays;
    final restantes = 7 - diferenca;

    if (restantes <= 0) return 'Expira hoje';
    if (restantes == 1) return 'Expira em 1 dia';
    return 'Expira em $restantes dias';
  }

  /// Filtra as conversas que possuem menos de 7 dias de retenção.
  List<Map<String, dynamic>> _obterChatsValidos() {
    final agora = DateTime.now();
    return _chatSessions.where((c) {
      final DateTime data = c['atualizadoEm'] is DateTime
          ? c['atualizadoEm'] as DateTime
          : agora;
      return agora.difference(data).inDays < 7;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = AppColors.getBackgroundColor(context);
    final chatsValidos = _obterChatsValidos();
    final bool temChats = chatsValidos.isNotEmpty;
    final double telaHeight = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: !temChats
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Apresentação e Identidade Visual (sem indicador de plano superior)
                      const _ConradoHeader(),

                      const SizedBox(height: 10),

                      // Mascote oficial em destaque adaptativo ocupando o espaço livre sem causar scroll
                      Expanded(
                        child: Center(
                          child: Image.asset(
                            'assets/images/conrado/conrado_hi.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  MdiIcons.crown,
                                  size: 64,
                                  color: AppColors.getPrimaryAccent(context)
                                      .withValues(alpha: 0.6),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'CONRADO',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getPrimaryAccent(context),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Seção interativa de dicas inteligentes
                      _buildConradoDizSection(),

                      const SizedBox(height: 14),

                      // Botão principal para nova conversa
                      _buildIniciarChatButton(),

                      const SizedBox(height: 10),

                      // Mensagem informativa de lista vazia
                      const _SemChatsAviso(),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Apresentação e Identidade Visual (sem indicador de plano superior)
                        const _ConradoHeader(),

                        const SizedBox(height: 14),

                        // Mascote oficial em destaque
                        _buildCentralConradoCard(telaHeight),

                        const SizedBox(height: 14),

                        // Seção interativa de dicas inteligentes
                        _buildConradoDizSection(),

                        const SizedBox(height: 14),

                        // Botão principal para nova conversa
                        _buildIniciarChatButton(),

                        const SizedBox(height: 12),

                        // Indicador de rolagem para ver histórico
                        const _ScrollIndicator(),

                        // Seção inferior com o histórico recente
                        const SizedBox(height: 18),
                        _buildSeusChatsSection(chatsValidos),
                        SizedBox(
                          height:
                              MediaQuery.of(context).viewPadding.bottom + 24,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// Mascote do CONRADO centralizado com proporção adaptável.
  Widget _buildCentralConradoCard(double viewportHeight) {
    final double targetHeight = (viewportHeight * 0.44).clamp(240.0, 420.0);

    return SizedBox(
      height: targetHeight,
      width: double.infinity,
      child: Center(
        child: Image.asset(
          'assets/images/conrado/conrado_hi.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                MdiIcons.crown,
                size: 72,
                color: AppColors.primaryBlue.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 8),
              const Text(
                'CONRADO',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bloco "CONRADO diz:" com animação suave de transição entre dicas.
  Widget _buildConradoDizSection() {
    return GestureDetector(
      onTap: _proximaDica,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Text(
              'CONRADO diz:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.getPrimaryAccent(context),
                fontFamily: TextStyles.fontFamily,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                _dicasConrado[_indiceDicaAtual],
                key: ValueKey<int>(_indiceDicaAtual),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextColor(context),
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 12,
                  color: AppColors.getSubtextColor(context),
                ),
                const SizedBox(width: 4),
                Text(
                  'Toque para outra dica',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.getSubtextColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Botão de destaque "Iniciar chat com CONRADO".
  Widget _buildIniciarChatButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () => _criarNovoChat(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.getActionButtonColor(context),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MdiIcons.crown, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            const Text(
              'Iniciar chat com CONRADO',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Seção inferior contendo o aviso de retenção de 7 dias e os cards dos chats salvos.
  Widget _buildSeusChatsSection(List<Map<String, dynamic>> chatsValidos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Seus chats',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.getTextColor(context),
                fontFamily: TextStyles.fontFamily,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.getPrimaryAccent(
                  context,
                ).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${chatsValidos.length} ${chatsValidos.length == 1 ? "ativo" : "ativos"}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getPrimaryAccent(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _RetencaoAviso(),
        const SizedBox(height: 14),
        if (_carregandoChats)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Column(
            children: [
              for (int i = 0; i < chatsValidos.length; i++)
                _buildChatSessionCard(chatsValidos[i], i),
            ],
          ),
      ],
    );
  }

  /// Card representativo de cada conversa salva no Firestore.
  Widget _buildChatSessionCard(Map<String, dynamic> chat, int index) {
    final String id = chat['id'] ?? '';
    final String titulo = chat['titulo'] ?? 'Conversa com CONRADO';
    final String topico = chat['topico'] ?? titulo;
    final String ultimaMsg = chat['ultimaMensagem'] ?? '';
    final DateTime data = chat['atualizadoEm'] is DateTime
        ? chat['atualizadoEm'] as DateTime
        : DateTime.now();
    final bool isDark = AppColors.isDarkMode(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConradoChatPage(
                chatId: id,
                tituloChat: titulo,
                topicoChat: topico,
              ),
            ),
          ).then((_) => _carregarChatsFirestore());
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.primaryOrange.withValues(alpha: 0.15)
                : AppColors.primaryBlue.withValues(alpha: 0.07),
            shape: BoxShape.circle,
          ),
          child: Icon(
            MdiIcons.crown,
            color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
            size: 20,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                topico,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryOrange,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
                color: AppColors.getTextColor(context),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ultimaMsg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.getSubtextColor(context),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(
                    MdiIcons.timerSand,
                    size: 11,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _calcularDiasRestantes(data),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.file_download_outlined,
                color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
                size: 20,
              ),
              onPressed: () => _exportarChat(chat),
              tooltip: 'Exportar conversa',
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 20,
              ),
              onPressed: () => _excluirChat(index),
              tooltip: 'Excluir conversa',
            ),
          ],
        ),
      ),
    );
  }

  /// Gera a transcrição e exibe modal para cópia e exportação da conversa.
  Future<void> _exportarChat(Map<String, dynamic> chat) async {
    final String chatId = chat['id'] ?? '';
    final String titulo = chat['titulo'] ?? 'Conversa com CONRADO';
    final String topico = chat['topico'] ?? titulo;
    final String uid = FirebaseFirestoreService.idClienteAtual;
    final bool isDark = AppColors.isDarkMode(context);

    final mensagens = await _firestoreService.obterMensagensChat(
      idCliente: uid,
      chatId: chatId,
    );
    if (!mounted) return;

    if (mensagens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma mensagem salva encontrada.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('COGITO - Transcrição de Chat com CONRADO');
    buffer.writeln('Título: $titulo | Tópico: $topico');
    buffer.writeln('========================================\n');

    for (final m in mensagens) {
      final autor = m['isUser'] == true ? 'VOCÊ' : 'CONRADO';
      buffer.writeln('[$autor]:\n${m['text'] ?? ''}\n');
    }

    final String transcricaoCompleta = buffer.toString();

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppColors.getCardColor(context),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewPadding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  MdiIcons.crown,
                  color: isDark
                      ? AppColors.primaryOrange
                      : AppColors.primaryBlue,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Exportar "$titulo"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.copy_rounded,
                color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
              ),
              title: Text(
                'Copiar Transcrição Completa',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.getTextColor(context),
                ),
              ),
              subtitle: Text(
                'Copia todo o diálogo para a área de transferência',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getSubtextColor(context),
                ),
              ),
              onTap: () {
                Clipboard.setData(ClipboardData(text: transcricaoCompleta));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Transcrição copiada com sucesso!'),
                    backgroundColor: isDark
                        ? AppColors.primaryOrange
                        : AppColors.primaryBlue,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Cabeçalho textual e ícone oficial do CONRADO com suporte a tema escuro.
class _ConradoHeader extends StatelessWidget {
  const _ConradoHeader();

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode(context);

    return Column(
      children: [
        Icon(
          MdiIcons.crown,
          size: 48,
          color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
        ),
        const SizedBox(height: 8),
        Text(
          'OLÁ MUNDO, EU SOU O',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
            fontFamily: TextStyles.fontFamily,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'CONRADO',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 54,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.5,
            color: isDark ? Colors.white : AppColors.primaryBlue,
            fontFamily: TextStyles.fontFamily,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Seu Controlador de Orçamentos e Negócios\ncom Recursos de Análises Detalhadas e Organização',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : const Color(0xFF2C324B),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Banner de alerta sobre a retenção de 7 dias das conversas com suporte ao tema escuro.
class _RetencaoAviso extends StatelessWidget {
  const _RetencaoAviso();

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardColor : const Color(0xFFEFF3FD),
        borderRadius: BorderRadius.circular(14),
        border: isDark ? Border.all(color: AppColors.darkBorderColor) : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Os chats ficam salvos apenas por uma semana antes de serem apagados.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.primaryBlue,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador que sugere rolagem quando houver conversas salvas.
class _ScrollIndicator extends StatelessWidget {
  const _ScrollIndicator();

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode(context);

    return Column(
      children: [
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Role para baixo para ver seus chats',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down,
              size: 15,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ],
        ),
      ],
    );
  }
}

/// Mensagem exibida quando não houver conversas salvas.
class _SemChatsAviso extends StatelessWidget {
  const _SemChatsAviso();

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode(context);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            MdiIcons.chatOutline,
            size: 14,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
          const SizedBox(width: 6),
          Text(
            'Você não tem mais chats salvos ainda',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
