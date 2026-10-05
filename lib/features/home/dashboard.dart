import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/common/constant/text_styles.dart';
import 'package:cogito/common/utils/conrado_advice_helper.dart';
import 'package:cogito/features/conrado/conrado_chat_page.dart';
import 'package:cogito/features/finances/finances_page.dart';
import 'package:cogito/features/finances/financial_goals_page.dart';
import 'package:cogito/features/notifications/notifications_page.dart';
import 'package:cogito/features/plans/plans_page.dart';
import 'package:cogito/features/wallet/carteira_page.dart';
import 'package:cogito/services/app_settings_controller.dart';
import 'package:cogito/services/debug_mock_service.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tela do Dashboard principal do aplicativo COGITO.
/// Apresenta a interface do aplicativo perfeitamente alinhada ao design de referência visual,
/// utilizando tipografia Poppins (Bold e Regular) e as cores da marca COGITO.
class Dashboard extends StatefulWidget {
  /// Callback para alternância de abas no container de navegação pai ([HomePage]).
  /// Aceita o índice da aba principal e opcionalmente o índice da sub-aba (ex: sub-aba 1 de Orçamentos na FinancasPage).
  final void Function(int tabIndex, [int? subTabIndex])? onNavigateToTab;

  const Dashboard({super.key, this.onNavigateToTab});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  /// Controller de rolagem para monitorar o scroll da tela e atualizar a status bar se necessário.
  final ScrollController _scrollController = ScrollController();

  /// Flag que controla a visibilidade dos valores financeiros na tela.
  bool _isSaldoVisivel = true;

  /// Plano do usuário carregado com fallback seguro e reativo.
  String _planoUsuario = 'Grátis';

  /// Controller para o carrossel horizontal de planos (deslizável para o lado).
  late final PageController _planosPageController;

  /// Índice atual do plano em visualização no carrossel horizontal do Dashboard.
  int _currentPlanoIndex = 0;

  /// Serviço do Firebase Firestore para sincronização de dados.
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  @override
  void initState() {
    super.initState();

    // 1. Prioriza imediatamente o plano salvo ou em cache para carregamento instantâneo
    final usuario = FirebaseFirestoreService.usuarioLogado;
    final planoGlobal = FirebaseFirestoreService.planoAtivoNotifier.value;
    if (usuario != null && usuario['plano'] != null) {
      _planoUsuario = usuario['plano'].toString();
    } else if (planoGlobal != 'Grátis') {
      _planoUsuario = planoGlobal;
    }

    _currentPlanoIndex = _obterIndicePlano(_planoUsuario);
    _planosPageController = PageController(
      viewportFraction: 0.90,
      initialPage: _currentPlanoIndex,
    );

    // 2. Carrega da persistência local SharedPreferences e Firestore
    _carregarPlanoUsuario();

    // 3. Ouve alterações reativas do plano em tempo real de qualquer parte do app
    FirebaseFirestoreService.planoAtivoNotifier.addListener(_onPlanoMudou);

    // 4. Ouve alterações no modo debug de dados fictícios
    DebugMockService.instance.modoMockAtivoNotifier.addListener(
      _onMockModeChanged,
    );

    // 5. Ouve alterações de tema (modo escuro/claro) para redesenhar instantaneamente
    AppSettingsController.instance.addListener(_onSettingsThemeChanged);
  }

  /// Callback disparado quando o modo escuro ou claro é alterado globalmente.
  void _onSettingsThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Callback acionado quando o plano ativo é alterado em qualquer ponto da aplicação.
  void _onPlanoMudou() {
    if (mounted) {
      _aplicarNovoPlano(FirebaseFirestoreService.planoAtivoNotifier.value);
    }
  }

  /// Retorna o índice correspondente ao plano informado no carrossel horizontal.
  int _obterIndicePlano(String plano) {
    final lower = plano.toLowerCase();
    if (lower.contains('prem')) return 2;
    if (lower.contains('free') || lower.contains('lancer')) return 1;
    return 0;
  }

  /// Retorna a cor característica de destaque de cada plano COGITO.
  Color _obterCorPlano(String plano, BuildContext context) {
    final lower = plano.toLowerCase();
    final bool isDark = AppColors.isDarkMode(context);
    if (lower.contains('prem')) return AppColors.primaryYellow;
    if (lower.contains('free') || lower.contains('lancer')) return AppColors.primaryOrange;
    return isDark ? AppColors.primaryOrange : AppColors.primaryBlue;
  }

  /// Sincroniza a página visível do carrossel com o plano ativo do usuário.
  void _sincronizarIndicePlano(String plano) {
    final int alvo = _obterIndicePlano(plano);
    _currentPlanoIndex = alvo;
    if (_planosPageController.hasClients) {
      _planosPageController.animateToPage(
        alvo,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Aplica a alteração do plano e atualiza o estado da tela de forma segura.
  void _aplicarNovoPlano(String novoPlano) {
    if (!mounted) return;
    if (_planoUsuario != novoPlano) {
      setState(() {
        _planoUsuario = novoPlano;
      });
      _sincronizarIndicePlano(novoPlano);
    }
  }

  /// Callback disparado quando o modo de dados fictícios é ligado ou desligado.
  void _onMockModeChanged() {
    if (mounted) {
      _carregarPlanoUsuario();
      setState(() {});
    }
  }

  /// Carrega o plano do usuário ativo a partir do SharedPreferences, Firestore e memória.
  Future<void> _carregarPlanoUsuario() async {
    // A. Verifica se há preferência salva localmente em SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? planoSalvo = prefs.getString('plano_usuario_ativo');
      if (planoSalvo != null && planoSalvo.isNotEmpty) {
        _aplicarNovoPlano(planoSalvo);
      }
    } catch (_) {}

    // B. Consulta o Firestore em segundo plano
    final String idCliente = FirebaseFirestoreService.idClienteAtual;
    final perfil = await _firestoreService.buscarUsuario(idCliente);

    if (mounted) {
      if (perfil != null && perfil['plano'] != null) {
        _aplicarNovoPlano(perfil['plano'].toString());
      }
      // Garante reconstrução para atualizar nome e dados reais recebidos do Firestore
      setState(() {});
    }
  }

  /// Retorna o nome completo ou de exibição do usuário com fallback resiliente.
  /// Prioriza a sessão do Firestore, depois o Firebase Authentication (displayName ou prefixo do e-mail).
  String _obterNomeUsuario() {
    // 1. Tenta recuperar o nome registrado na sessão do Firestore
    final usuario = FirebaseFirestoreService.usuarioLogado;
    final String? nomeFirestore = usuario?['nome']?.toString().trim();
    if (nomeFirestore != null && nomeFirestore.isNotEmpty) {
      return nomeFirestore;
    }

    // 2. Fallback para o displayName da conta ativa no Firebase Authentication
    try {
      final userAuth = FirebaseAuth.instance.currentUser;
      final String? authDisplayName = userAuth?.displayName?.trim();
      if (authDisplayName != null && authDisplayName.isNotEmpty) {
        return authDisplayName;
      }

      // 3. Fallback para o prefixo do e-mail do usuário autenticado
      if (userAuth?.email != null && userAuth!.email!.contains('@')) {
        final emailPrefix = userAuth.email!.split('@').first.trim();
        if (emailPrefix.isNotEmpty) {
          return emailPrefix;
        }
      }
    } catch (_) {}

    // 4. Nome padrão caso nenhum dado esteja disponível
    return 'Usuário';
  }

  /// Retorna apenas o primeiro nome do usuário para a saudação amigável no cabeçalho.
  String _obterPrimeiroNomeUsuario() {
    final String nomeCompleto = _obterNomeUsuario();
    final partes = nomeCompleto.split(' ');
    return partes.isNotEmpty && partes.first.isNotEmpty ? partes.first : 'Usuário';
  }

  /// Atualiza reativamente os dados da Dashboard ao efetuar o gesto Pull-to-Refresh.
  Future<void> _atualizarDadosDashboard() async {
    await _carregarPlanoUsuario();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _planosPageController.dispose();
    FirebaseFirestoreService.planoAtivoNotifier.removeListener(_onPlanoMudou);
    DebugMockService.instance.modoMockAtivoNotifier.removeListener(
      _onMockModeChanged,
    );
    AppSettingsController.instance.removeListener(_onSettingsThemeChanged);
    super.dispose();
  }

  /// Exibe o modal detalhado do cartão selecionado pelo usuário.
  void _exibirDetalhesCartao(Map<String, dynamic> cartao, String nomeTitular) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
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
                      color: AppColors.getBorderColor(context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cartao['banco'].toString(),
                      style: TextStyles.poppinsBold(
                        fontSize: 20,
                        color: AppColors.getTextColor(context),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cartao['bandeira'].toString(),
                        style: TextStyles.poppinsBold(
                          fontSize: 12,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppColors.getBorderColor(context)),
                const SizedBox(height: 12),
                _buildInfoItem(
                  Icons.credit_card,
                  'Número do Cartão',
                  cartao['numero'].toString(),
                ),
                const SizedBox(height: 12),
                _buildInfoItem(Icons.person_outline, 'Titular', nomeTitular),
                const SizedBox(height: 12),
                _buildInfoItem(
                  Icons.account_balance_wallet_outlined,
                  'Limite Disponível',
                  cartao['limite_disponivel'] != null
                      ? 'R\$ ${(cartao['limite_disponivel'] as num).toStringAsFixed(2)}'
                      : (cartao['limite']?.toString() ?? 'R\$ 0,00'),
                ),
                const SizedBox(height: 12),
                _buildInfoItem(
                  Icons.receipt_long_outlined,
                  'Fatura Atual',
                  cartao['fatura_atual'] != null
                      ? 'R\$ ${(cartao['fatura_atual'] as num).toStringAsFixed(2)}'
                      : 'R\$ 0,00',
                ),
                const SizedBox(height: 12),
                _buildInfoItem(
                  Icons.calendar_today_outlined,
                  'Vencimento',
                  cartao['vencimento']?.toString() ??
                      cartao['validade']?.toString() ??
                      'Dia 10',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.getActionButtonColor(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Fechar',
                      style: TextStyles.poppinsBold(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Constrói um item de informação no modal de detalhes do cartão.
  Widget _buildInfoItem(IconData icone, String rotulo, String valor) {
    return Row(
      children: [
        Icon(icone, color: AppColors.getPrimaryAccent(context), size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rotulo,
              style: TextStyles.poppinsRegular(
                fontSize: 12,
                color: AppColors.getSubtextColor(context),
              ),
            ),
            Text(
              valor,
              style: TextStyles.poppinsBold(
                fontSize: 14,
                color: AppColors.getTextColor(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Recupera o nome de exibição de forma resiliente
    final String nomeUsuario = _obterNomeUsuario();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.getStatusBarStyle(context),
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        body: RefreshIndicator(
          onRefresh: _atualizarDadosDashboard,
          color: AppColors.getPrimaryAccent(context),
          backgroundColor: AppColors.getCardColor(context),
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // 1. Cabeçalho superior com cor de destaque dinâmica (Laranja no escuro, Azul no claro)
                _buildHeader(context),

                // 2. Container dos cards sobrepostos com translação negativa para sobreposição suave
                Transform.translate(
                  offset: const Offset(0, -35),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // CARD 1: SALDO TOTAL (com barra vertical dinâmica e separação clara)
                        _buildBalanceCard(),

                        const SizedBox(height: 16),

                        // CARD 2: "Entenda o CONRADO" (com Insights inteligentes do Conrado e botão para conversar)
                        _buildConradoCard(),

                        const SizedBox(height: 20),

                        // SEÇÃO 3: "Meus Cartões" (com atalho e botão para a Carteira)
                        _buildMeusCartoesSection(nomeUsuario),

                        const SizedBox(height: 20),

                        // SEÇÃO 5: Planos COGITO (exibição dos planos Grátis, Freelancer e Premium acima das Metas)
                        _buildPlanosSection(context),

                        const SizedBox(height: 20),

                        // SEÇÃO EXTRA: Carrossel de Metas & Caixinhas
                        _buildMetasFinanceirasSection(context),

                        const SizedBox(height: 20),

                        // SEÇÃO EXTRA: Transações Recentes
                        _buildTransacoesRecentesSection(context),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Constrói o cabeçalho superior adaptado dinamicamente ao tema (Laranja no modo escuro, Azul no claro) com foto de perfil e ícone de sino com notificação.
  /// Obtém as informações do usuário autenticado para ouvir a stream de notificações do Firestore.
  Widget _buildHeader(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    // Obtém os dados do usuário atualmente autenticado no Firebase
    final usuario = FirebaseFirestoreService.usuarioLogado;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 55),
      decoration: BoxDecoration(
        color: AppColors.getPrimaryAccent(
          context,
        ), // Cor dinâmica: Laranja no escuro, Azul no claro
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Identificação do Usuário e Badge do Plano Ativo Atual
          Row(
            children: [
              GestureDetector(
                onTap: () => widget.onNavigateToTab?.call(3), // Navega para a aba de Perfil
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.getPrimaryAccent(context),
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Olá, ${_obterPrimeiroNomeUsuario()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Badge destacando visualmente o plano ativo atual
                  GestureDetector(
                    onTap: () {
                      PlanosModal.exibir(
                        context,
                        onPlanoAtualizado: () => _carregarPlanoUsuario(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 11, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Plano $_planoUsuario',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Botão de notificação reativo com ícone de sino e ponto indicador de não lidas via Firebase Stream
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firestoreService.buscarNotificacoesStream(
              (usuario?['uid'] ?? usuario?['id_cliente'] ?? 'guest').toString(),
            ),
            builder: (context, snapshot) {
              final notifs = snapshot.data ?? [];
              final bool temNaoLidas = notifs.any((n) => n['lida'] != true);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificacoesPage(),
                    ),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_none_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                    if (temNaoLidas)
                      Positioned(
                        top: 0,
                        right: 2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Constrói o Card de Saldo Total flutuante com cálculo reativo em tempo real via Cloud Firestore.
  Widget _buildBalanceCard() {
    return _DashboardBalanceCard(
      idCliente: FirebaseFirestoreService.idClienteAtual,
      firestoreService: _firestoreService,
      isSaldoVisivel: _isSaldoVisivel,
      onToggleVisibilidade: () =>
          setState(() => _isSaldoVisivel = !_isSaldoVisivel),
      onNavigateToTab: widget.onNavigateToTab,
    );
  }

  /// Constrói o Card "Entenda o CONRADO" com o título (tamanho 18),
  /// os insights inteligentes que o Conrado diz (tamanho 14) e o botão para conversar.
  Widget _buildConradoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getPrimaryAccent(
          context,
        ), // Dinâmico: Laranja no escuro, Azul no claro
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.getPrimaryAccent(context).withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha de título com ícone de coroa em destaque posicionado mais para cima e "Entenda o CONRADO" em Poppins Bold tamanho 18
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ícone autêntico de coroa em branco
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

          const SizedBox(height: 14),

          // Área de Insights reais do CONRADO e ação direta de conversa
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firestoreService.buscarTransacoesStream(
              FirebaseFirestoreService.idClienteAtual,
            ),
            builder: (context, snapshotTransacoes) {
              final transacoes = snapshotTransacoes.data ?? [];
              final String dicaReal = ConradoAdviceHelper.gerarDicaDashboard(
                transacoes: transacoes,
              );

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.amberAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            dicaReal,
                            style: TextStyles.poppinsRegular(
                              fontSize: 13.5,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Botão pill branco: ao apertar leva a um novo chat com o usuário enviando mensagem sobre a análise da IA
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final String mensagemParaConrado =
                            'Olá Conrado! Analisando o meu resumo financeiro você pontuou: "$dicaReal". O que você me recomenda fazer na prática para otimizar meus gastos e finanças?';

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ConradoChatPage(
                              chatId: 'chat_analise_${DateTime.now().millisecondsSinceEpoch}',
                              tituloChat: 'Análise do CONRADO',
                              topicoChat: 'Análise Inteligente de Finanças',
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Retorna uma instância de [Color] a partir de uma cor dinâmica ou hexadecimal.
  Color _obterCorCartao(dynamic valor, Color fallback) {
    if (valor is Color) return valor;
    if (valor is String && valor.isNotEmpty) {
      try {
        final clean = valor.replaceAll('#', '').replaceAll('0x', '');
        return Color(int.parse('FF$clean', radix: 16));
      } catch (_) {}
    }
    return fallback;
  }

  /// Constrói a Seção "Meus Cartões" com título "Meus Cartões" (tamanho 18), "Deslize >" (tamanho 18),
  /// o botão azul escuro "+" quadrado (56x56) que direciona para a nova tela [CartoesPage]
  /// e carrossel deslizável sincronizado em tempo real com o Cloud Firestore.
  Widget _buildMeusCartoesSection(String nomeTitular) {
    final String idCliente = FirebaseFirestoreService.idClienteAtual;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.buscarCartoesStream(idCliente),
      builder: (context, snapshot) {
        final cartoes = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha de cabeçalho da seção com o texto "Meus Cartões" e "Deslize >" com atalho para a CartoesPage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Meus Cartões',
                  style: TextStyles.poppinsBold(
                    fontSize: 18,
                    color: AppColors.getPrimaryAccent(context),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CarteiraPage(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'Deslize',
                        style: TextStyles.poppinsBold(
                          fontSize: 14,
                          color: AppColors.getSubtextColor(context),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.getSubtextColor(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Linha contendo o botão escuro "+" quadrado (56x56) e o carrossel de cartões deslizáveis estilizados
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Botão quadrado com cor primária dinâmica (laranja no escuro, azul no claro)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CarteiraPage(),
                        ),
                      );
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.getPrimaryAccent(context),
                        borderRadius: BorderRadius.circular(16),
                        // Sem sombra conforme solicitação visual do usuário
                      ),
                      child: const Center(
                        child: Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Carrossel deslizável horizontal com os cartões do usuário ou estado vazio limpo
                  cartoes.isEmpty
                      ? Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CarteiraPage(),
                                ),
                              );
                            },
                            child: Container(
                              height: 140,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.getCardColor(context),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.getPrimaryAccent(
                                        context,
                                      ).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.credit_card_off_outlined,
                                      color: AppColors.getPrimaryAccent(
                                        context,
                                      ),
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Nenhum cartão conectado',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.getTextColor(
                                              context,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Toque aqui para conectar seus cartões ao Firebase.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.getSubtextColor(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: AppColors.getSubtextColor(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: cartoes.length,
                            itemBuilder: (context, index) {
                              final c = cartoes[index];
                              final Color corInicial = _obterCorCartao(
                                c['cor'] ?? c['corInicial'],
                                AppColors.getPrimaryAccent(context),
                              );

                              final double? ld =
                                  (c['limite_disponivel'] as num?)?.toDouble();
                              final String strLimiteDisp = ld != null
                                  ? 'R\$ ${ld.toStringAsFixed(2)}'
                                  : (c['limite']?.toString() ?? 'R\$ 0,00');

                              return GestureDetector(
                                onTap: () =>
                                    _exibirDetalhesCartao(c, nomeTitular),
                                child: Container(
                                  width: 250,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: corInicial,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            c['banco'].toString(),
                                            style: TextStyles.poppinsBold(
                                              fontSize: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white24,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              c['bandeira'].toString(),
                                              style: TextStyles.poppinsBold(
                                                fontSize: 10,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        c['numero'].toString(),
                                        style: TextStyles.poppinsBold(
                                          fontSize: 14,
                                          color: Colors.white,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'TITULAR',
                                                style:
                                                    TextStyles.poppinsRegular(
                                                      fontSize: 9,
                                                      color: Colors.white70,
                                                    ),
                                              ),
                                              Text(
                                                nomeTitular,
                                                style: TextStyles.poppinsBold(
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'DISPONÍVEL',
                                                style:
                                                    TextStyles.poppinsRegular(
                                                      fontSize: 9,
                                                      color: Colors.white70,
                                                    ),
                                              ),
                                              Text(
                                                strLimiteDisp,
                                                style: TextStyles.poppinsBold(
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Botão abaixo dos cartões direcionando para a tela de Carteira
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CarteiraPage(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Acessar Carteira (Contas & Cartões)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.getPrimaryAccent(context),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Constrói o atalho simplificado e minimalista de "Planos COGITO" no Dashboard.
  /// Ao tocar, abre a tela de planos em um pop-up deslizável (Draggable Bottom Sheet).
  Widget _buildPlanosSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da seção com indicação de deslize lateral protegido contra overflow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.getPrimaryAccent(
                          context,
                        ).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          MdiIcons.crown,
                          color: AppColors.getPrimaryAccent(context),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Planos COGITO',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.getPrimaryAccent(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _obterCorPlano(_planoUsuario, context)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Ativo: $_planoUsuario',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: _obterCorPlano(_planoUsuario, context),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Compare os recursos disponíveis',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.getSubtextColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Dica visual de arrastar para o lado
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swipe_outlined,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Deslize',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Carrossel horizontal deslizável para o lado
          SizedBox(
            height: 295,
            child: PageView.builder(
              controller: _planosPageController,
              itemCount: 3,
              onPageChanged: (index) {
                setState(() {
                  _currentPlanoIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final bool isDark = AppColors.isDarkMode(context);
                final String pLower = _planoUsuario.toLowerCase();
                final bool isGratis = pLower.contains('grátis') || pLower.contains('gratis');
                final bool isFreelancer = pLower.contains('free') || pLower.contains('lancer');
                final bool isPremium = pLower.contains('prem');

                // Lista estruturada com os 3 planos do COGITO e o que cada um faz
                final List<Map<String, dynamic>> planos = [
                  {
                    'nome': 'Grátis',
                    'preco': 'R\$ 0,00',
                    'periodo': '/mês',
                    'subtitulo':
                        'Controle financeiro essencial para o dia a dia',
                    'cor': isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
                    'badge': 'ESSENCIAL',
                    'oQueFaz': [
                      'Registro manual de despesas e receitas',
                      '1 conta bancária para saldo consolidado',
                      '1 conversa ativa com o assistente CONRADO',
                      'Até 2 metas financeiras simultâneas',
                    ],
                    'isAtual': isGratis,
                  },
                  {
                    'nome': 'Freelancer',
                    'preco': 'R\$ 5,90',
                    'periodo': '/mês',
                    'subtitulo':
                        'Feito sob medida para autônomos e freelancers',
                    'cor': AppColors.primaryOrange,
                    'badge': 'MAIS POPULAR',
                    'oQueFaz': [
                      'Até 3 contas bancárias para saldo consolidado',
                      'Até 2 conversas simultâneas com o CONRADO',
                      'CONRADO com digitação livre de perguntas personalizadas',
                      'Até 5 metas financeiras simultâneas',
                      'Exportação de extratos em PDF e planilhas',
                    ],
                    'isAtual': isFreelancer,
                  },
                  {
                    'nome': 'Premium',
                    'preco': 'R\$ 15,90',
                    'periodo': '/mês',
                    'subtitulo':
                        'A experiência definitiva em inteligência financeira',
                    'cor': AppColors.primaryYellow,
                    'badge': 'VIP & COMPLETO',
                    'oQueFaz': [
                      'Contas bancárias e saldo consolidado ilimitados',
                      'Conversas simultâneas ilimitadas com o CONRADO',
                      'Projeções financeiras inteligentes de longo prazo',
                      'Metas financeiras ilimitadas',
                      'Suporte VIP prioritário 24/7',
                    ],
                    'isAtual': isPremium,
                  },
                ];

                final plano = planos[index];
                final String nome = plano['nome'];
                final String preco = plano['preco'];
                final String periodo = plano['periodo'];
                final String subtitulo = plano['subtitulo'];
                final Color cor = plano['cor'];
                final String badge = plano['badge'];
                final List<String> oQueFaz = List<String>.from(
                  plano['oQueFaz'],
                );
                final bool isAtual = plano['isAtual'];
                final bool isYellow = cor == AppColors.primaryYellow;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isAtual
                        ? cor.withValues(alpha: 0.12)
                        : AppColors.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho do Card: Nome e Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            nome,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: cor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isAtual
                                  ? cor
                                  : cor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isAtual ? 'PLANO ATIVO' : badge,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: isAtual
                                    ? (isYellow ? Colors.black87 : Colors.white)
                                    : cor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Preço
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            preco,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextColor(context),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            periodo,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getSubtextColor(context),
                            ),
                          ),
                        ],
                      ),

                      Text(
                        subtitulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.getSubtextColor(context),
                        ),
                      ),

                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        color: AppColors.getDividerColor(context),
                      ),
                      const SizedBox(height: 8),

                      // "O que este plano faz:"
                      Text(
                        'O que este plano faz:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Lista dos recursos que o plano faz
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: oQueFaz.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: cor,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.getSubtextColor(
                                          context,
                                        ),
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Botão de Ação: "Ver Detalhes" para planos disponíveis ou "Plano Ativo"
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton(
                          onPressed: () {
                            PlanosModal.exibir(
                              context,
                              onPlanoAtualizado: () => _carregarPlanoUsuario(),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAtual
                                ? Colors.green.shade600
                                : cor,
                            foregroundColor: isYellow && !isAtual
                                ? Colors.black87
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isAtual) ...[
                                const Icon(Icons.check, size: 16),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                isAtual ? 'Plano Ativo' : 'Ver Detalhes',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // Indicador de Páginas (Bolinhas) para o carrossel horizontal
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final bool isSelected = _currentPlanoIndex == index;
              final Color dotColor = index == 0
                  ? AppColors.primaryBlue
                  : (index == 1
                        ? AppColors.primaryOrange
                        : AppColors.primaryYellow);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? dotColor : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Constrói a Seção "Metas Financeiras" com metas reais cadastradas no Firebase Firestore,
  /// ícones simples e barra de progresso na cor azul, e atalho "Ver todas" em cinza.
  Widget _buildMetasFinanceirasSection(BuildContext context) {
    // Identificador único do cliente para consulta no Firestore
    final String idCliente = FirebaseFirestoreService.idClienteAtual;
    final Color corDestaque = AppColors.getPrimaryAccent(context);
    final bool isDark = AppColors.isDarkMode(context);

    return StreamBuilder<List<Map<String, dynamic>>>(
      initialData: FirebaseFirestoreService.obterMetasDoCache(idCliente),
      stream: _firestoreService.buscarMetasStream(idCliente),
      builder: (context, snapshot) {
        final List<Map<String, dynamic>> metasFirestore =
            snapshot.data ?? FirebaseFirestoreService.obterMetasDoCache(idCliente);
        final List<Map<String, dynamic>> metasEmAndamento = metasFirestore
            .where((m) =>
                (m['status'] ?? 'em_andamento') == 'em_andamento' &&
                m['concluida'] != true)
            .toList();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.getCardColor(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        color: corDestaque,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Metas Financeiras',
                        style: TextStyles.poppinsBold(
                          fontSize: 18,
                          color: corDestaque,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MetasFinanceirasPage(),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Ver todas',
                          style: TextStyles.poppinsBold(
                            fontSize: 14,
                            color: AppColors.getSubtextColor(context),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.getMetasTextColor(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Caso ainda não haja metas cadastradas, exibe card informativo para criação
              if (metasEmAndamento.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkInputFill : const Color(0xFFF8F9FD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorderColor : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.savings_outlined,
                        color: corDestaque,
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nenhuma meta cadastrada ainda',
                        style: TextStyles.poppinsBold(
                          fontSize: 14,
                          color: corDestaque,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Crie suas caixinhas de economia e acompanhe seu progresso.',
                        textAlign: TextAlign.center,
                        style: TextStyles.poppinsRegular(
                          fontSize: 12,
                          color: AppColors.getSubtextColor(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MetasFinanceirasPage(),
                          ),
                        ),
                        icon: const Icon(
                          Icons.add,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Criar Meta',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: corDestaque,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Carrossel deslizável de cartões de Metas Financeiras reais
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: metasEmAndamento.map((meta) {
                      final String titulo = meta['titulo'] ?? 'Meta';
                      final String? categoria = meta['categoria']?.toString();
                      final double atual =
                          (meta['valor_atual'] as num?)?.toDouble() ?? 0.0;
                      final double objetivo =
                          (meta['valor_objetivo'] as num?)?.toDouble() ?? 1.0;
                      final double progresso = (atual / objetivo).clamp(
                        0.0,
                        1.0,
                      );
                      final int porcentagem = (progresso * 100).toInt();

                      return Container(
                        width: 220,
                        margin: const EdgeInsets.only(right: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkInputFill
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Linha superior com ícone e porcentagem em destaque adaptativo
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: corDestaque.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _obterIconeSimplesMeta(categoria),
                                    color: corDestaque,
                                    size: 22,
                                  ),
                                ),
                                Text(
                                  '$porcentagem%',
                                  style: TextStyles.poppinsBold(
                                    fontSize: 15,
                                    color: corDestaque,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Título da Meta
                            Text(
                              titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyles.poppinsBold(
                                fontSize: 15,
                                color: AppColors.getTextColor(context),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Barra de Progresso Arredondada com acento dinâmico
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progresso,
                                minHeight: 8,
                                backgroundColor: isDark
                                    ? Colors.white12
                                    : Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  corDestaque,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Valores de saldo acumulado e objetivo final
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'R\$ ${atual.toStringAsFixed(0)}',
                                  style: TextStyles.poppinsRegular(
                                    fontSize: 12,
                                    color: AppColors.getSubtextColor(context),
                                  ),
                                ),
                                Text(
                                  'R\$ ${objetivo.toStringAsFixed(0)}',
                                  style: TextStyles.poppinsBold(
                                    fontSize: 13,
                                    color: AppColors.getTextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Retorna um ícone simples e direto de acordo com a categoria da meta cadastrada.
  IconData _obterIconeSimplesMeta(String? categoria) {
    switch (categoria?.toLowerCase()) {
      case 'reserva':
        return Icons.savings_outlined;
      case 'viagem':
        return Icons.flight_takeoff_outlined;
      case 'veículo':
      case 'veiculo':
      case 'carro':
        return Icons.directions_car_outlined;
      case 'imóvel':
      case 'imovel':
      case 'casa':
        return Icons.home_outlined;
      case 'educação':
      case 'educacao':
        return Icons.school_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  /// Constrói a lista das últimas transações financeiras no formato vertical.
  Widget _buildTransacoesRecentesSection(BuildContext context) {
    final String idCliente = FirebaseFirestoreService.idClienteAtual;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.buscarTransacoesStream(idCliente),
      builder: (context, snapshot) {
        final List<Map<String, dynamic>> transacoes = snapshot.data ?? [];
        final ultimasTransacoes = transacoes.take(4).toList();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.getCardColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.getBorderColor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: AppColors.getPrimaryAccent(context),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Transações Recentes',
                        style: TextStyles.poppinsBold(
                          fontSize: 18,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateToTab?.call(1),
                    child: Text(
                      'Extrato ➔',
                      style: TextStyles.poppinsBold(
                        fontSize: 14,
                        color: AppColors.getPrimaryAccent(context),
                      ),
                    ),
                  ),
                ],
              ),
              // Espaçamento vertical entre o cabeçalho de transações e a lista/mensagem
              const SizedBox(height: 2),

              if (ultimasTransacoes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      'Nenhuma transação registrada.',
                      style: TextStyles.poppinsRegular(
                        fontSize: 14,
                        color: AppColors.getSubtextColor(context),
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ultimasTransacoes.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 33,
                    thickness: 1,
                    color: AppColors.getBorderColor(context),
                  ),
                  itemBuilder: (context, index) {
                    final t = ultimasTransacoes[index];
                    final String tipo = t['tipo'] ?? 'Receita';
                    final bool isReceita = tipo == 'Receita';
                    final double valor =
                        (t['valor'] as num?)?.toDouble() ?? 0.0;

                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isReceita
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.red.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isReceita
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
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
                                t['titulo'] ?? 'Lançamento',
                                style: TextStyles.poppinsBold(
                                  fontSize: 14,
                                  color: AppColors.getTextColor(context),
                                ),
                              ),
                              Text(
                                t['categoria'] ?? 'Geral',
                                style: TextStyles.poppinsRegular(
                                  fontSize: 14,
                                  color: AppColors.getSubtextColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isReceita ? '+' : '-'} R\$ ${valor.toStringAsFixed(2)}',
                          style: TextStyles.poppinsBold(
                            fontSize: 14,
                            color: isReceita ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Card de Saldo Total reativo que escuta as streams de contas e transações do Cloud Firestore.
class _DashboardBalanceCard extends StatelessWidget {
  final String idCliente;
  final FirebaseFirestoreService firestoreService;
  final bool isSaldoVisivel;
  final VoidCallback onToggleVisibilidade;
  final void Function(int tabIndex, [int? subTabIndex])? onNavigateToTab;

  const _DashboardBalanceCard({
    required this.idCliente,
    required this.firestoreService,
    required this.isSaldoVisivel,
    required this.onToggleVisibilidade,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firestoreService.buscarContasBancariasStream(idCliente),
      builder: (context, snapshotContas) {
        final List<Map<String, dynamic>> contas = snapshotContas.data ?? [];
        final int totalContasCount = contas.length;
        final String textoContas =
            'Saldo consolidado - $totalContasCount ${totalContasCount == 1 ? 'conta' : 'contas'}';

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: firestoreService.buscarTransacoesStream(idCliente),
          builder: (context, snapshotTransacoes) {
            final List<Map<String, dynamic>> transacoes =
                snapshotTransacoes.data ?? [];

            // 1. Soma saldo base de todas as contas bancárias (Saldo Consolidado real)
            double saldoBaseContas = 0.0;
            for (final c in contas) {
              saldoBaseContas += (c['saldo'] as num?)?.toDouble() ?? 0.0;
            }

            // 2. Calcula total de receitas (entradas) e despesas (saídas) do período
            double totalEntradas = 0.0;
            double totalSaidas = 0.0;
            for (final t in transacoes) {
              final double valor = (t['valor'] as num?)?.toDouble() ?? 0.0;
              final String tipo = t['tipo'] ?? 'Receita';
              if (tipo == 'Receita') {
                totalEntradas += valor;
              } else {
                totalSaidas += valor;
              }
            }

            // 3. Saldo consolidado reflete rigorosamente a soma das contas bancárias vinculadas
            final double saldoConsolidadoBancos = saldoBaseContas;

            return _BalanceCardView(
              textoContas: textoContas,
              saldoCalculado: saldoConsolidadoBancos,
              totalEntradas: totalEntradas,
              totalSaidas: totalSaidas,
              isSaldoVisivel: isSaldoVisivel,
              onToggleVisibilidade: onToggleVisibilidade,
              onNavigateToRelatorios: () {
                if (onNavigateToTab != null) {
                  onNavigateToTab!(
                    1,
                    2,
                  ); // Direciona para a aba de Relatórios na página de Finanças
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FinancesPage(),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

/// Interface visual do card de saldo com formatação, receitas/despesas e botão de navegação para relatórios.
class _BalanceCardView extends StatelessWidget {
  final String textoContas;
  final double saldoCalculado;
  final double totalEntradas;
  final double totalSaidas;
  final bool isSaldoVisivel;
  final VoidCallback onToggleVisibilidade;
  final VoidCallback onNavigateToRelatorios;

  const _BalanceCardView({
    required this.textoContas,
    required this.saldoCalculado,
    required this.totalEntradas,
    required this.totalSaidas,
    required this.isSaldoVisivel,
    required this.onToggleVisibilidade,
    required this.onNavigateToRelatorios,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Reduz o espaçamento inferior para aproximar das ações inferiores
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 5,
                              decoration: BoxDecoration(
                                color: AppColors.getAccentBarColor(context),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'SALDO CONSOLIDADO',
                                    style: TextStyles.poppinsBold(
                                      fontSize: 16,
                                      color: AppColors.getTextColor(context),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    textoContas,
                                    style: TextStyles.poppinsRegular(
                                      fontSize: 13,
                                      color: AppColors.getSubtextColor(context),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isSaldoVisivel
                                        ? 'R\$ ${saldoCalculado.toStringAsFixed(2).replaceAll('.', ',')}'
                                        : '••••••••',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyles.poppinsBold(
                                      fontSize: 30,
                                      color: AppColors.getTextColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        isSaldoVisivel
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.getTextColor(context),
                        size: 28,
                      ),
                      onPressed: onToggleVisibilidade,
                      tooltip: 'Mostrar/Ocultar Saldo',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ENTRADAS E SAÍDAS (Fluxo de Caixa Mensal / Receitas & Despesas)
                Row(
                  children: [
                    // Caixa de Entradas (Receitas)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_downward_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Receitas',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.getSubtextColor(context),
                                    ),
                                  ),
                                  Text(
                                    isSaldoVisivel
                                        ? '+ R\$ ${totalEntradas.toStringAsFixed(2).replaceAll('.', ',')}'
                                        : '••••••',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Caixa de Saídas (Despesas)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Despesas',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.getSubtextColor(context),
                                    ),
                                  ),
                                  Text(
                                    isSaldoVisivel
                                        ? '- R\$ ${totalSaidas.toStringAsFixed(2).replaceAll('.', ',')}'
                                        : '••••••',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.getBorderColor(context),
          ),
          Padding(
            // Reduz o espaçamento vertical entre o divisor e o botão de acessar relatórios
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onNavigateToRelatorios,
                icon: const Icon(
                  Icons.donut_large_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  'Acessar Tela de Relatórios',
                  style: TextStyles.poppinsBold(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.getActionButtonColor(context),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
