import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/features/conrado/services/conrado_api_service.dart';
import 'package:cogito/features/plans/plans_page.dart';
import 'package:cogito/services/debug_mock_service.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Modelo de dados representativo de uma mensagem trocada no chat com o CONRADO.
class ChatMessage {
  /// Conteúdo textual da mensagem.
  final String text;

  /// Indica se a mensagem foi enviada pelo usuário (true) ou pela IA CONRADO (false).
  final bool isUser;

  /// Data e horário em que a mensagem foi gerada.
  final DateTime timestamp;

  /// Construtor da mensagem de chat.
  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();

  /// Converte a mensagem para mapa serializável para persistência no Firestore.
  Map<String, dynamic> toMap() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
  };

  /// Constrói uma mensagem a partir de um mapa de dados recuperado do Firestore.
  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    text: map['text'] ?? '',
    isUser: map['isUser'] ?? false,
    timestamp: map['timestamp'] != null
        ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
        : DateTime.now(),
  );
}

/// Tela de Chat Interativo com o assistente virtual CONRADO.
///
/// Apresenta interface de diálogo financeiro com:
/// - Comunicação assíncrona com IA via [ConradoApiService].
/// - Validação de permissões por plano de assinatura (Grátis vs Pagos).
/// - Histórico e persistência de sessões no Cloud Firestore.
/// - Formatação rica de texto para listas, negritos e títulos no diálogo.
class ConradoChatPage extends StatefulWidget {
  /// Identificador único da sessão de chat.
  final String? chatId;

  /// Título atribuído à conversa.
  final String? tituloChat;

  /// Tópico temático que orienta o contexto da conversa.
  final String? topicoChat;

  /// Mensagem inicial enviada automaticamente pelo usuário (ex: gerada a partir do card Entenda o CONRADO).
  final String? mensagemInicial;

  /// Construtor padrão da tela de chat.
  const ConradoChatPage({
    super.key,
    this.chatId,
    this.tituloChat,
    this.topicoChat,
    this.mensagemInicial,
  });

  @override
  ConradoChatPageState createState() => ConradoChatPageState();
}

/// Estado da tela de conversa com o CONRADO.
class ConradoChatPageState extends State<ConradoChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ConradoApiService _apiService = ConradoApiService();
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  /// Lista de mensagens exibidas na conversa atual.
  final List<ChatMessage> _mensagens = [];

  /// Flag indicativa de resposta em geração pela IA.
  bool _isTyping = false;

  /// Nome do plano do usuário autenticado ("Grátis", "Freelancer" ou "Premium").
  String _planoUsuario = 'Grátis';

  /// Sugestões rápidas de perguntas pré-definidas para o dia a dia.
  final List<String> _quickSuggestions = [
    '📊 Status do FGTS e Saque Aniversário',
    '💰 Como funciona o cálculo do 13º Salário?',
    '🏖️ Como planejar o orçamento das Férias?',
    'Como criar uma reserva de emergência?',
    'Dicas para economizar este mês',
    'Como organizar minhas despesas?',
    'O que é a regra 50-30-20?',
  ];

  @override
  void initState() {
    super.initState();
    _carregarPlanoEUltimasMensagens();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Recupera as mensagens anteriores salvas no Firestore ou inicia o envio imediato da mensagem inicial.
  Future<void> _carregarPlanoEUltimasMensagens() async {
    final usuario = FirebaseFirestoreService.usuarioLogado;
    if (usuario != null && usuario['plano'] != null) {
      _planoUsuario = usuario['plano'];
    }

    // Interceptação pelo Modo Debug: usuário mock tem plano liberado
    if (DebugMockService.instance.modoMockAtivo) {
      _planoUsuario = 'Freelancer';
    }

    final String uid = FirebaseFirestoreService.idClienteAtual;
    final String cId = widget.chatId ?? '';

    // Se uma mensagem inicial foi passada (ex: botão do Entenda o CONRADO),
    // inicia imediatamente a nova conversa com o envio dessa análise sem carregar histórico antigo.
    final bool temMensagemInicial = widget.mensagemInicial != null && widget.mensagemInicial!.trim().isNotEmpty;

    if (!temMensagemInicial && cId.isNotEmpty) {
      final salvas = await _firestoreService.obterMensagensChat(
        idCliente: uid,
        chatId: cId,
      );
      if (salvas.isNotEmpty && mounted) {
        setState(() {
          _mensagens.clear();
          for (final m in salvas) {
            _mensagens.add(ChatMessage.fromMap(m));
          }
        });
        _scrollToBottom();
        return;
      }
    }

    // Adiciona a saudação institucional do CONRADO se ainda não houver mensagens
    if (_mensagens.isEmpty && mounted) {
      setState(() {
        _mensagens.add(
          ChatMessage(
            text:
                'Olá! Sou o CONRADO, seu assistente de inteligência financeira do COGITO! 🧠💡\n\n'
                '${_planoUsuario == 'Grátis' ? 'No seu Plano Grátis, selecione uma das perguntas prontas abaixo para conversarmos no dia a dia!' : 'Como posso ajudar você a organizar seu dinheiro e atingir suas metas hoje?'}',
            isUser: false,
          ),
        );
      });
    }

    // Se possui mensagem inicial gerada a partir do card "Entenda o CONRADO", envia imediatamente
    if (temMensagemInicial && mounted) {
      final String textoInicial = widget.mensagemInicial!.trim();
      _handleSendMessage(textoInicial);
    }
  }

  /// Salva o estado atual da sessão e todas as mensagens no Cloud Firestore.
  void _salvarSessaoFirestore() {
    final String uid = FirebaseFirestoreService.idClienteAtual;
    final String cId = widget.chatId ?? 'chat_principal';
    final String cTitulo = widget.tituloChat ?? 'Conversa com CONRADO';

    _firestoreService.salvarSessaoChat(
      idCliente: uid,
      chatId: cId,
      titulo: cTitulo,
      topico: widget.topicoChat ?? cTitulo,
      mensagens: _mensagens.map((m) => m.toMap()).toList(),
    );
  }

  /// Envia mensagem para o CONRADO e processa o retorno da IA Generativa.
  ///
  /// Valida restrições do Plano Grátis, atualiza o estado local da conversa,
  /// aciona a API e rola a tela até a nova mensagem recebida.

  Future<void> _handleSendMessage([String? predefinedMessage]) async {
    final bool isGratis = _planoUsuario == 'Grátis';

    // Bloqueio de digitação livre para plano Grátis
    if (isGratis && predefinedMessage == null) {
      _exibirAlertaUpgradePlano();
      return;
    }

    final String textToSend = predefinedMessage ?? _inputController.text.trim();
    if (textToSend.isEmpty || _isTyping) return;

    if (predefinedMessage == null) _inputController.clear();

    // 1. Registra a mensagem do usuário e ativa o indicador de digitação
    setState(() {
      _mensagens.add(ChatMessage(text: textToSend, isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();

    // 2. Consulta assíncrona ao serviço de IA
    final String aiResponse = await _apiService.sendMessage(textToSend);

    if (!mounted) return;

    // 3. Renderiza a resposta da IA e desativa o indicador de digitação
    setState(() {
      _mensagens.add(ChatMessage(text: aiResponse, isUser: false));
      _isTyping = false;
    });
    _scrollToBottom();
  }

  /// Diálogo exibido antes de sair da tela perguntando se deseja salvar a conversa.
  Future<bool> _confirmarSaidaESalvar() async {
    final bool temMensagensUsuario = _mensagens.any((m) => m.isUser);
    if (!temMensagensUsuario) return true;

    final bool isDark = AppColors.isDarkMode(context);

    final bool? resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.getBorderColor(context)),
        ),
        title: Row(
          children: [
            Icon(
              Icons.save_outlined,
              color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
            ),
            const SizedBox(width: 8),
            Text(
              'Salvar conversa?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppColors.getTextColor(context),
              ),
            ),
          ],
        ),
        content: Text(
          'Deseja salvar esta conversa nos seus chats do CONRADO antes de sair?',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.35,
            color: AppColors.getSubtextColor(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(
              'Cancelar',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Não Salvar',
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Salvar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (resultado == true) {
      _salvarSessaoFirestore();
      return true;
    }
    return resultado == false;
  }

  /// Rola a lista suavemente até o final da conversa.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// Exibe modal oferecendo upgrade de plano para desbloquear digitação livre.
  void _exibirAlertaUpgradePlano() {
    final bool isDark = AppColors.isDarkMode(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.getBorderColor(context)),
        ),
        title: Row(
          children: [
            Icon(MdiIcons.crown, color: AppColors.primaryOrange, size: 24),
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
          'A digitação de mensagens livres com o CONRADO é um recurso dos planos Freelancer e Premium.\n\nNo Plano Grátis, utilize as perguntas prontas acima do campo de texto!',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: AppColors.getSubtextColor(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Entendi',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              PlanosModal.exibir(
                context,
                onPlanoAtualizado: () => _carregarPlanoEUltimasMensagens(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'VER PLANOS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Gerencia a ação de retorno do botão físico ou virtual do dispositivo.
  Future<void> _onPopInvoked(bool didPop, dynamic result) async {
    if (didPop) return;
    final bool sair = await _confirmarSaidaESalvar();
    if (sair && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode(context);
    // No modo escuro o CONRADO acima no chat tem o fundo laranja conforme solicitado
    final Color headerBgColor = isDark ? AppColors.primaryOrange : AppColors.primaryBlue;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppColors.getOverlayStyleForBackground(headerBgColor),
        child: Scaffold(
          backgroundColor: AppColors.getBackgroundColor(context),
          appBar: _buildAppBar(headerBgColor),
          body: Column(
            children: [
              // Lista rolável de mensagens trocadas
              Expanded(child: _buildMessagesList()),

              // Barra de sugestões de perguntas prontas para plano gratuito
              if (_planoUsuario == 'Grátis') _buildQuickSuggestions(),

              // Barra inferior de entrada de texto e botão de envio
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  /// AppBar com título do CONRADO e cor adaptada (Laranja no modo escuro, Azul no modo claro).
  PreferredSizeWidget _buildAppBar(Color backgroundColor) {
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () async {
          final bool sair = await _confirmarSaidaESalvar();
          if (sair && mounted) Navigator.pop(context);
        },
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MdiIcons.crown, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text(
            'CONRADO',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói a lista de mensagens do chat.
  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _mensagens.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _mensagens.length && _isTyping) {
          return const _TypingIndicatorBubble();
        }
        return _buildMessageBubble(_mensagens[index]);
      },
    );
  }

  /// Balão de mensagem individual (usuário ou assistente) com suporte ao tema escuro.
  Widget _buildMessageBubble(ChatMessage message) {
    final bool isUser = message.isUser;
    final bool isDark = AppColors.isDarkMode(context);
    final String hora =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(MdiIcons.crown, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? (isDark ? AppColors.primaryOrange : AppColors.primaryBlue)
                    : AppColors.getCardColor(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isUser ? Colors.transparent : AppColors.getBorderColor(context),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? .2 : .03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormattedText(message.text, isUser),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      hora,
                      style: TextStyle(
                        color: isUser
                            ? Colors.white70
                            : AppColors.getSubtextColor(context),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  /// Formatação rica para o texto da mensagem (títulos, marcadores e listas) adaptada ao tema.
  Widget _buildFormattedText(String text, bool isUser) {
    final List<String> lines = text.split('\n');
    final List<Widget> widgets = [];
    final Color textColor = isUser ? Colors.white : AppColors.getTextColor(context);

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      if (trimmed.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              trimmed.substring(4),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('## ') || trimmed.startsWith('# ')) {
        final title = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              title,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        );
      } else if (RegExp(r'^[\*\-\•]\s+').hasMatch(trimmed)) {
        final itemText = trimmed.replaceFirst(RegExp(r'^[\*\-\•]\s+'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: _parseInlineSpans(itemText, isUser),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: RichText(
              text: TextSpan(children: _parseInlineSpans(rawLine, isUser)),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Converte marcações markdown inline em TextSpans estilizados adaptados ao tema.
  List<InlineSpan> _parseInlineSpans(String text, bool isUser) {
    final List<InlineSpan> spans = [];
    // Utiliza texto branco para usuário ou a cor dinâmica do tema para o Conrado
    final Color textColor = isUser ? Colors.white : AppColors.getTextColor(context);
    final TextStyle defaultStyle = TextStyle(
      color: textColor,
      fontSize: 13.5,
      height: 1.4,
    );
    final RegExp exp = RegExp(r'(\*\*(.*?)\*\*|\*(.*?)\*|`(.*?)`)');
    int lastIndex = 0;

    for (final Match match in exp.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: defaultStyle,
          ),
        );
      }

      final String fullMatch = match.group(0)!;
      if (fullMatch.startsWith('**') && fullMatch.endsWith('**')) {
        spans.add(
          TextSpan(
            text: match.group(2) ?? '',
            style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (fullMatch.startsWith('*') && fullMatch.endsWith('*')) {
        spans.add(
          TextSpan(
            text: match.group(3) ?? '',
            style: defaultStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: defaultStyle));
    }
    return spans;
  }

  /// Lista horizontal com perguntas prontas para o Plano Grátis com suporte ao tema escuro.
  Widget _buildQuickSuggestions() {
    final bool isDark = AppColors.isDarkMode(context);

    return Container(
      color: AppColors.getCardColor(context),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        border: Border(
          top: BorderSide(color: AppColors.getBorderColor(context)),
          bottom: BorderSide(color: AppColors.getBorderColor(context)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Text(
              'Perguntas Prontas (Plano Grátis):',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.getSubtextColor(context),
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _quickSuggestions[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    backgroundColor: isDark ? AppColors.getInputFillColor(context) : const Color(0xFFF2F4F8),
                    side: BorderSide(color: AppColors.getBorderColor(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    label: Text(
                      suggestion,
                      style: TextStyle(
                        color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _handleSendMessage(suggestion),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Barra de entrada de texto e envio de mensagem adaptada ao tema escuro.
  Widget _buildInputBar() {
    final bool isGratis = _planoUsuario == 'Grátis';
    final bool isDark = AppColors.isDarkMode(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.getCardColor(context),
          border: Border(
            top: BorderSide(color: AppColors.getBorderColor(context)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? .2 : .04),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: isGratis ? _exibirAlertaUpgradePlano : null,
                child: AbsorbPointer(
                  absorbing: isGratis,
                  child: TextField(
                    controller: _inputController,
                    enabled: !isGratis,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    style: TextStyle(fontSize: 14.5, color: AppColors.getTextColor(context)),
                    decoration: InputDecoration(
                      hintText: isGratis
                          ? 'Selecione uma pergunta pronta acima'
                          : 'Pergunte algo ao CONRADO...',
                      hintStyle: TextStyle(
                        color: isGratis ? AppColors.primaryOrange : (isDark ? Colors.white38 : Colors.grey),
                        fontSize: 12.5,
                        fontWeight: isGratis
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      filled: true,
                      fillColor: isGratis
                          ? (isDark ? AppColors.primaryOrange.withValues(alpha: 0.15) : const Color(0xFFFFF3E0))
                          : AppColors.getInputFillColor(context),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppColors.getBorderColor(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppColors.getBorderColor(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () =>
                  isGratis ? _exibirAlertaUpgradePlano() : _handleSendMessage(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isGratis
                      ? (isDark ? Colors.white24 : Colors.grey.shade400)
                      : (isDark ? AppColors.primaryOrange : AppColors.primaryBlue),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Balão indicador de digitação da IA com suporte ao tema escuro.
class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(MdiIcons.crown, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.getCardColor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.getBorderColor(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryOrange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'CONRADO está digitando...',
                  style: TextStyle(
                    color: AppColors.getSubtextColor(context),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
