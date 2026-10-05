import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/common/utils/profile_photo_helper.dart';
import 'package:cogito/features/auth/welcome_page.dart';
import 'package:cogito/features/notifications/notifications_page.dart';
import 'package:cogito/features/plans/plans_page.dart';
import 'package:cogito/features/user/edit_profile_page.dart';
import 'package:cogito/features/user/help_support_page.dart';
import 'package:cogito/features/user/settings_page.dart';
import 'package:cogito/features/wallet/carteira_page.dart';
import 'package:cogito/services/app_settings_controller.dart';
import 'package:cogito/services/debug_mock_service.dart';
import 'package:cogito/services/firebase_auth_service.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tela do Perfil do Usuário contendo informações pessoais, foto, atalho para a carteira,
/// carrossel de planos, configurações do aplicativo, ajuda/suporte e opções de conta.
class UserPage extends StatefulWidget {
  /// Construtor constante da página de usuário.
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  /// Controller para escutar o deslocamento de rolagem na página.
  final ScrollController _scrollController = ScrollController();

  /// Instância do serviço Firebase Firestore para leitura e gravação dos dados do usuário.
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  /// Instância do serviço Firebase Authentication para logout e gerenciamento de conta.
  final FirebaseAuthService _firebaseService = FirebaseAuthService();

  /// Dados da conta bancária vinculada ao usuário (null se não vinculada).
  Map<String, dynamic>? _contaBancaria;

  /// Dados do perfil do usuário carregados dinamicamente do Firebase Firestore e Auth.
  Map<String, dynamic>? _dadosUsuario;

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
    _carregarContaBancaria();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Carrega as informações reais da conta cadastrada diretamente do Firestore.
  Future<void> _carregarDadosUsuario() async {
    final String idCliente = FirebaseFirestoreService.idClienteAtual;
    final dados = await _firestoreService.buscarUsuario(idCliente);

    if (mounted) {
      setState(() {
        _dadosUsuario = dados ?? FirebaseFirestoreService.usuarioLogado;
      });
    }
  }

  /// Carrega a conta bancária principal vinculada para exibir um resumo no card de Carteira.
  Future<void> _carregarContaBancaria() async {
    final String idCliente = FirebaseFirestoreService.idClienteAtual;
    final conta = await _firestoreService.obterContaBancaria(idCliente);

    if (mounted) {
      setState(() {
        _contaBancaria = conta;
      });
    }
  }

  /// Força o recarregamento total dos dados cadastrais do usuário e de sua carteira vinculada.
  Future<void> _carregarDadosCompletos() async {
    await Future.wait([
      _carregarDadosUsuario(),
      _carregarContaBancaria(),
    ]);
  }

  /// Abre a tela de edição de informações do perfil do usuário.
  Future<void> _abrirEditarPerfil() async {
    final atualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const EditarPerfilPage()),
    );

    if (atualizado == true && mounted) {
      await _carregarDadosUsuario();
      setState(() {});
    }
  }

  /// Confirma e realiza a desautenticação do usuário (Logout) com diálogo adaptado ao tema visual.
  void _confirmarLogout() {
    final primaryAccent = AppColors.getPrimaryAccent(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Sair da Conta',
          style: TextStyle(color: AppColors.getTextColor(context)),
        ),
        content: Text(
          'Deseja realmente encerrar sua sessão no aplicativo COGITO?',
          style: TextStyle(color: AppColors.getSubtextColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.getSubtextColor(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              FirebaseFirestoreService.deslogar();
              try {
                await _firebaseService.signOut();
              } catch (_) {}

              if (!mounted) return;
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const WelcomePage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryAccent,
            ),
            child: const Text('Sair', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Exibe a caixa de diálogo exigindo a confirmação para excluir permanentemente a conta e seus dados no Firebase,
  /// com estilo adaptado aos temas Claro e Escuro e confirmação segura por e-mail para usuários Google.
  void _exibirDialogoExcluirConta() {
    final bool isGoogleUser = _firebaseService.isUsuarioGoogle;
    final String userEmail = _firebaseService.usuarioAtual?.email ??
        FirebaseFirestoreService.usuarioLogado?['email'] ??
        '';
    bool isProcessing = false;
    final passwordController = TextEditingController();
    final googleConfirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.getCardColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Excluir Conta',
                    style: TextStyle(color: AppColors.getTextColor(context)),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGoogleUser
                          ? 'Esta ação excluirá permanentemente sua conta COGITO e todos os seus dados vinculados (transações, conversas, metas e configurações).\n\nPara confirmar que deseja excluir sua conta Google com segurança, digite seu e-mail abaixo:'
                          : 'Esta ação excluirá permanentemente sua conta COGITO e todos os seus dados vinculados (transações, conversas, metas e configurações).\n\nDigite sua senha atual para confirmar:',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.getTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Campo de confirmação específico por tipo de login
                    if (isGoogleUser) ...[
                      TextFormField(
                        controller: googleConfirmController,
                        style: TextStyle(color: AppColors.getTextColor(context)),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Confirmar e-mail',
                          hintText: userEmail.isNotEmpty ? userEmail : 'seu.email@gmail.com',
                          labelStyle: TextStyle(color: AppColors.getSubtextColor(context)),
                          prefixIcon: Icon(
                            Icons.alternate_email,
                            color: AppColors.getPrimaryAccent(context),
                          ),
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Digite seu e-mail cadastrado';
                          }
                          if (userEmail.isNotEmpty &&
                              value.trim().toLowerCase() != userEmail.trim().toLowerCase() &&
                              value.trim().toUpperCase() != 'EXCLUIR') {
                            return 'O e-mail digitado não confere com sua conta';
                          }
                          return null;
                        },
                      ),
                    ] else ...[
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        style: TextStyle(color: AppColors.getTextColor(context)),
                        decoration: InputDecoration(
                          labelText: 'Senha atual',
                          labelStyle: TextStyle(color: AppColors.getSubtextColor(context)),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: AppColors.getPrimaryAccent(context),
                          ),
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe sua senha para confirmar';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.getSubtextColor(context)),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setDialogState(() {
                            isProcessing = true;
                          });

                          final dialogNav = Navigator.of(dialogContext);
                          final scaffoldMessenger = ScaffoldMessenger.of(this.context);
                          final rootNavigator = Navigator.of(this.context, rootNavigator: true);

                          try {
                            final String senha = passwordController.text.trim();
                            await _firebaseService.excluirContaEConteudo(senha);

                            if (!mounted) return;
                            dialogNav.pop();

                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Sua conta e todos os seus dados foram excluídos com sucesso.',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );

                            rootNavigator.pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const WelcomePage(),
                              ),
                              (route) => false,
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() {
                              isProcessing = false;
                            });

                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Erro ao excluir conta: ${e.toString().replaceAll('Exception: ', '')}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Excluir Conta',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Escuta alterações do controlador de configurações para reagir imediatamente ao Modo Escuro
    final settings = AppSettingsController.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final authUser = FirebaseAuth.instance.currentUser;
        final usuario = _dadosUsuario ?? FirebaseFirestoreService.usuarioLogado;

        final String nomeUsuario =
            (usuario?['nome'] != null && usuario!['nome'].toString().isNotEmpty)
                ? usuario['nome'].toString()
                : (authUser?.displayName?.isNotEmpty == true
                    ? authUser!.displayName!
                    : 'Usuário COGITO');

        final String emailUsuario =
            (usuario?['email'] != null && usuario!['email'].toString().isNotEmpty)
                ? usuario['email'].toString()
                : (authUser?.email?.isNotEmpty == true
                    ? authUser!.email!
                    : 'usuario@cogito.com');

        final String telefoneUsuario =
            (usuario?['telefone'] != null && usuario!['telefone'].toString().isNotEmpty)
                ? usuario['telefone'].toString()
                : (authUser?.phoneNumber?.isNotEmpty == true
                    ? authUser!.phoneNumber!
                    : '(Não informado)');

        final String planoAtual =
            FirebaseFirestoreService.planoAtivoNotifier.value.isNotEmpty
                ? FirebaseFirestoreService.planoAtivoNotifier.value
                : (usuario?['plano']?.toString() ?? 'Grátis');

        final double rendaMensal =
            (usuario?['renda_mensal'] as num?)?.toDouble() ?? 0.0;
        final String fotoEncriptada =
            usuario?['foto_perfil_encriptada']?.toString() ?? '';
        final String uidUsuario = FirebaseFirestoreService.idClienteAtual;
        final Color primaryAccent = AppColors.getPrimaryAccent(context);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppColors.getStatusBarStyle(context),
          child: Scaffold(
            backgroundColor: AppColors.getBackgroundColor(context),
            body: SingleChildScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  // Cabeçalho inspirado na foto (Account) com avatar grande, nome e email
                  _buildHeader(
                    context: context,
                    nome: nomeUsuario,
                    email: emailUsuario,
                    fotoEncriptada: fotoEncriptada,
                  ),

                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      children: [
                        // GRUPO 1: CARTEIRA (WALLET) - Estilo Imagem 1
                        _buildMenuGroup([
                          _buildMenuItem(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Carteira',
                            subtitle: _contaBancaria != null
                                ? '${_contaBancaria!['banco'] ?? 'Conta Vinculada'} • R\$ ${((_contaBancaria!['saldo'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2).replaceAll('.', ',')}'
                                : 'Bancos e cartões cadastrados',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CarteiraPage(),
                                ),
                              ).then((_) => _carregarContaBancaria());
                            },
                          ),
                        ]),

                        const SizedBox(height: 14),

                        // GRUPO 2: PERFIL, METAS E DADOS CADASTRAIS - Estilo Imagem 1
                        _buildMenuGroup([
                          _buildMenuItem(
                            icon: Icons.person_outline_rounded,
                            title: 'Editar Perfil',
                            subtitle: 'Foto, nome e dados pessoais',
                            onTap: _abrirEditarPerfil,
                          ),
                          _buildMenuItem(
                            icon: Icons.badge_outlined,
                            title: 'Dados Cadastrais',
                            subtitle: 'Telefone e informações da conta',
                            onTap: () => _exibirModalDadosCadastrais(
                              nome: nomeUsuario,
                              email: emailUsuario,
                              telefone: telefoneUsuario,
                              rendaMensal: rendaMensal,
                            ),
                          ),
                        ]),

                        const SizedBox(height: 14),

                        // GRUPO 3: CONFIGURAÇÕES, PLANOS E AJUDA - Estilo Imagem 1
                        _buildMenuGroup([
                          _buildMenuItem(
                            icon: Icons.settings_outlined,
                            title: 'Configurações',
                            subtitle: 'Tema, notificações e segurança (v1)',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ConfiguracoesPage(),
                                ),
                              ).then((_) {
                                if (mounted) setState(() {});
                              });
                            },
                          ),
                          _buildMenuItem(
                            icon: Icons.workspace_premium_outlined,
                            title: 'Plano de Assinatura',
                            subtitle: 'Recursos e vantagens exclusivas',
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryAccent.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    planoAtual,
                                    style: TextStyle(
                                      color: primaryAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: AppColors.getSubtextColor(context)
                                      .withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                            onTap: () {
                              PlanosModal.exibir(
                                context,
                                onPlanoAtualizado: () {
                                  _carregarDadosUsuario();
                                  if (mounted) setState(() {});
                                },
                              );
                            },
                          ),
                          _buildMenuItem(
                            icon: Icons.headset_mic_outlined,
                            title: 'Ajuda e Suporte',
                            subtitle: 'FAQ e canais de contato com suporte',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AjudaSuportePage(),
                                ),
                              );
                            },
                          ),
                        ]),

                        const SizedBox(height: 14),

                        // GRUPO 4: SESSÃO E CONTA (LOGOUT & EXCLUSÃO) - Estilo Imagem 1
                        _buildMenuGroup([
                          _buildMenuItem(
                            icon: Icons.logout_rounded,
                            title: 'Sair da Conta',
                            subtitle: 'Encerrar sessão neste aparelho',
                            iconColor: const Color(0xFFE55353),
                            textColor: const Color(0xFFE55353),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Color(0xFFE55353),
                            ),
                            onTap: _confirmarLogout,
                          ),
                          _buildMenuItem(
                            icon: Icons.delete_forever_outlined,
                            title: 'Excluir Conta',
                            subtitle:
                                'Apagar permanentemente a conta e dados',
                            iconColor: Colors.red.shade700,
                            textColor: Colors.red.shade700,
                            trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Colors.red.shade700,
                            ),
                            onTap: _exibirDialogoExcluirConta,
                          ),
                        ]),

                        const SizedBox(height: 20),

                        // PAINEL DE FERRAMENTAS DO DESENVOLVEDOR (EXPANSÍVEL)
                        _buildDeveloperDebugTile(uidUsuario),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Constrói o cabeçalho moderno da tela de Conta/Usuário inspirado no design da foto de referência.
  /// Contém barra superior com navegação e notificações, avatar centralizado com badge de câmera,
  /// nome do usuário em destaque e seu endereço de e-mail com adaptação dinâmica para o tema escuro.
  Widget _buildHeader({
    required BuildContext context,
    required String nome,
    required String email,
    required String fotoEncriptada,
  }) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final bool canPop = Navigator.canPop(context);
    final bool isDark = AppColors.isDarkMode(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 26),
      decoration: BoxDecoration(
        color: AppColors.getPrimaryAccent(context),
      ),
      child: Column(
        children: [
          // Barra superior com botão voltar, título centralizado e notificações
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botão Voltar quando a tela for acessada via navegação push; caso contrário mantém espaço vazio sem ícone
              if (canPop)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                )
              else
                // Espaço vazio para balancear o título "Conta" centralizado sem exibir ícone de usuário no canto superior esquerdo
                const SizedBox(width: 40, height: 40),

              // Título central da tela
              const Text(
                'Conta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),

              // Botão de Notificações
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificacoesPage(),
                    ),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Avatar centralizado com botão de câmera (estilo foto de referência)
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ProfilePhotoHelper.buildProfileAvatar(
                  codigoEncriptado: fotoEncriptada,
                  radius: 46,
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: _abrirEditarPerfil,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.primaryBlue : AppColors.primaryOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Nome do Usuário
          Text(
            nome.isNotEmpty ? nome : 'Usuário COGITO',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),

          const SizedBox(height: 4),

          // E-mail do Usuário
          Text(
            email.isNotEmpty ? email : 'contato@cogito.app',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói um container de grupo arredondado para itens de menu com suporte completo ao tema escuro.
  Widget _buildMenuGroup(List<Widget> children) {
    final bool isDark = AppColors.isDarkMode(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Divider(
                  height: 1,
                  thickness: 0.7,
                  indent: 58,
                  endIndent: 16,
                  color: isDark
                      ? AppColors.getDividerColor(context)
                      : Colors.black.withValues(alpha: 0.05),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Constrói cada linha de menu clicável dentro de um grupo, com ícone decorativo,
  /// título, subtítulo opcional e indicador de avanço/trailing adaptados ao tema ativo.
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final bool isDark = AppColors.isDarkMode(context);
    final Color effectiveIconColor =
        iconColor ?? AppColors.getPrimaryAccent(context);
    final Color effectiveTextColor =
        textColor ?? AppColors.getTextColor(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Ícone com fundo suave arredondado adaptativo
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: effectiveIconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),

              // Textos (Título e Subtítulo)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: effectiveTextColor,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getSubtextColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Elemento trailing (customizado ou seta padrão cinza do mockup)
              trailing ??
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.getSubtextColor(context).withValues(alpha: 0.5),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  /// Exibe um modal bottom sheet moderno com os dados cadastrais do usuário
  /// (Telefone, Renda informada, e identificadores da conta) adaptado ao tema escuro.
  void _exibirModalDadosCadastrais({
    required String nome,
    required String email,
    required String telefone,
    required double rendaMensal,
  }) {
    final bool isDark = AppColors.isDarkMode(context);
    final User? firebaseUser = FirebaseAuth.instance.currentUser;
    final usuario = FirebaseFirestoreService.usuarioLogado;
    final String idConexao = firebaseUser?.uid ??
        usuario?['uid'] ??
        usuario?['id_cliente'] ??
        'Não informado';

    final Color primaryAccent = AppColors.getPrimaryAccent(context);

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 22,
            top: 16,
            right: 22,
            bottom: MediaQuery.of(ctx).viewPadding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de arrasto
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white24
                        : Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dados Cadastrais',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.getTextColor(context),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _buildInfoRow(
                Icons.person_outline_rounded,
                'Nome Completo',
                nome.isNotEmpty ? nome : 'Não informado',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.email_outlined,
                'E-mail',
                email.isNotEmpty ? email : 'Não informado',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.phone_outlined,
                'Telefone',
                telefone.isNotEmpty ? telefone : 'Não cadastrado',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.attach_money_rounded,
                'Renda Mensal Informada',
                'R\$ ${rendaMensal.toStringAsFixed(2).replaceAll('.', ',')}',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.fingerprint_rounded,
                'ID do Cliente (UID)',
                idConexao,
                isMonospace: true,
              ),

              const SizedBox(height: 20),

              // Botão para fechar o modal informativo
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Fechar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Constrói uma linha formatada para o modal de dados cadastrais adaptada ao tema ativo.
  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isMonospace = false,
  }) {
    final Color primaryAccent = AppColors.getPrimaryAccent(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: primaryAccent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.getSubtextColor(context),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: isMonospace ? 'monospace' : null,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Constrói o painel de ferramentas do desenvolvedor para auditoria e diagnósticos técnicos adaptado ao tema escuro.
  Widget _buildDeveloperDebugTile(String uidUsuario) {
    final bool isDark = AppColors.isDarkMode(context);
    final Color primaryAccent = AppColors.getPrimaryAccent(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorderColor
              : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: primaryAccent,
          collapsedIconColor: AppColors.getSubtextColor(context),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.code_rounded,
              color: Colors.amber,
              size: 20,
            ),
          ),
          title: Text(
            'Diagnósticos Técnicos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context),
            ),
          ),
          subtitle: Text(
            'Ferramentas de depuração de sincronização',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.getSubtextColor(context),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'UID Conectado: $uidUsuario',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Controle interativo para alternar para a Versão Mock de testes
                  ValueListenableBuilder<bool>(
                    valueListenable:
                        DebugMockService.instance.modoMockAtivoNotifier,
                    builder: (context, modoMockAtivo, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: modoMockAtivo
                              ? AppColors.primaryOrange.withValues(alpha: 0.12)
                              : (isDark
                                  ? AppColors.darkInputFill
                                  : Colors.grey.withValues(alpha: 0.08)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: modoMockAtivo
                                ? AppColors.primaryOrange
                                : (isDark
                                    ? AppColors.darkBorderColor
                                    : Colors.grey.withValues(alpha: 0.25)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  modoMockAtivo
                                      ? Icons.science_rounded
                                      : Icons.cloud_done_rounded,
                                  color: modoMockAtivo
                                      ? AppColors.primaryOrange
                                      : primaryAccent,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Versão Mock (Dados Fictícios)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.getTextColor(context),
                                      ),
                                    ),
                                    Text(
                                      modoMockAtivo
                                          ? 'Ativado: simulando contas e transações'
                                          : 'Desativado: dados reais do Firebase',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color:
                                            AppColors.getSubtextColor(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: modoMockAtivo,
                              activeTrackColor: AppColors.primaryOrange,
                              activeThumbColor: Colors.white,
                              onChanged: (novoValor) async {
                                final messenger = ScaffoldMessenger.of(context);
                                DebugMockService.instance.setModoMock(novoValor);
                                await _carregarDadosCompletos();
                                if (!mounted) return;
                                setState(() {});
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      novoValor
                                          ? 'Modo Mock ATIVADO! Operando com base simulada.'
                                          : 'Modo Mock DESATIVADO. Conectado ao Firebase.',
                                    ),
                                    backgroundColor: novoValor
                                        ? AppColors.primaryOrange
                                        : primaryAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _carregarDadosCompletos,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Forçar Recarregamento Total'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryAccent,
                      side: BorderSide(color: primaryAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionDebug(uidUsuario),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  /// Constrói a Sessão de Debug e Testes (Operações Financeiras e Notificações) na tela de Usuário com suporte ao tema escuro.
  Widget _buildSectionDebug(String uid) {
    final bool isDark = AppColors.isDarkMode(context);
    final Color primaryAccent = AppColors.getPrimaryAccent(context);

    return Card(
      elevation: 0,
      color: AppColors.getCardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.darkBorderColor : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.bug_report_outlined,
                    color: primaryAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sessão de Debug & Testes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryAccent,
                        ),
                      ),
                      Text(
                        'Ferramentas de simulação e disparo para testes',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.getSubtextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(
              height: 24,
              color: AppColors.getDividerColor(context),
            ),

            // 1. Operações de Teste de Transações
            Text(
              'Transações de Teste (Firebase Firestore):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _firestoreService.executarOperacaoDebug10Reais(
                        idCliente: uid,
                        titulo: 'Depósito Teste Debug (+10)',
                        categoria: 'Receita',
                        adicionar: true,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '+ R\$ 10,00 adicionados como Receita de teste!',
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text(
                      '+ R\$ 10 Receita',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _firestoreService.executarOperacaoDebug10Reais(
                        idCliente: uid,
                        titulo: 'Despesa Teste Debug (-10)',
                        categoria: 'Alimentação',
                        adicionar: false,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '- R\$ 10,00 debitados como Despesa de teste!',
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.remove,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      '- R\$ 10 Despesa',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 2. Disparo de Notificações de Teste
            Text(
              'Disparo de Notificações de Teste:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  backgroundColor: isDark ? AppColors.darkInputFill : null,
                  avatar: const Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: AppColors.primaryOrange,
                  ),
                  label: Text(
                    '💡 Dica CONRADO',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  onPressed: () async {
                    await _firestoreService.criarNotificacao(
                      idCliente: uid,
                      titulo: 'Dica do CONRADO 💡',
                      mensagem:
                          'Você economizou R\$ 150,00 na categoria Alimentação este mês!',
                      categoria: 'IA Financeira',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              const Text('Notificação "Dica CONRADO" enviada!'),
                          backgroundColor: primaryAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                ActionChip(
                  backgroundColor: isDark ? AppColors.darkInputFill : null,
                  avatar: const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Colors.amber,
                  ),
                  label: Text(
                    '⚠️ Alerta Orçamento',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  onPressed: () async {
                    await _firestoreService.criarNotificacao(
                      idCliente: uid,
                      titulo: 'Alerta de Orçamento ⚠️',
                      mensagem:
                          'Atenção: Seu orçamento de Lazer atingiu 85% do limite estipulado.',
                      categoria: 'Sistema',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Notificação "Alerta Orçamento" enviada!',
                          ),
                          backgroundColor: primaryAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                ActionChip(
                  backgroundColor: isDark ? AppColors.darkInputFill : null,
                  avatar: const Icon(
                    Icons.emoji_events_outlined,
                    size: 16,
                    color: Colors.green,
                  ),
                  label: Text(
                    '🎉 Meta Concluída',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  onPressed: () async {
                    await _firestoreService.criarNotificacao(
                      idCliente: uid,
                      titulo: 'Meta Alcançada! 🎉',
                      mensagem:
                          'Parabéns! Sua caixinha "Viagem Europa" atingiu 100% da meta calculada.',
                      categoria: 'Metas',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Notificação "Meta Concluída" enviada!',
                          ),
                          backgroundColor: primaryAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                ActionChip(
                  backgroundColor: isDark ? AppColors.darkInputFill : null,
                  avatar: Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: primaryAccent,
                  ),
                  label: Text(
                    '🔒 Aviso Segurança',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  onPressed: () async {
                    await _firestoreService.criarNotificacao(
                      idCliente: uid,
                      titulo: 'Aviso de Segurança 🔒',
                      mensagem:
                          'Sua sessão foi sincronizada com segurança no novo dispositivo.',
                      categoria: 'Segurança',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Notificação "Aviso Segurança" enviada!',
                          ),
                          backgroundColor: primaryAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Ações extras: Enviar Notificação Personalizada e Limpar Notificações
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _exibirDialogoEnviarNotificacaoPersonalizada(uid),
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text(
                      'Personalizada',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryAccent,
                      side: BorderSide(color: primaryAccent),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _firestoreService.limparNotificacoes(uid);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notificações de teste apagadas!'),
                            backgroundColor: Colors.grey,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                    label: const Text(
                      'Limpar Todas',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
  }

  /// Exibe o diálogo para envio de notificação de teste personalizada com suporte a tema escuro.
  void _exibirDialogoEnviarNotificacaoPersonalizada(String uid) {
    final tituloCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String categoria = 'Sistema';
    final primaryAccent = AppColors.getPrimaryAccent(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppColors.getCardColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Enviar Notificação de Teste',
            style: TextStyle(color: AppColors.getTextColor(context)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tituloCtrl,
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: InputDecoration(
                    labelText: 'Título',
                    labelStyle: TextStyle(
                      color: AppColors.getSubtextColor(context),
                    ),
                    filled: true,
                    fillColor: AppColors.getInputFillColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: msgCtrl,
                  maxLines: 2,
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: InputDecoration(
                    labelText: 'Mensagem',
                    labelStyle: TextStyle(
                      color: AppColors.getSubtextColor(context),
                    ),
                    filled: true,
                    fillColor: AppColors.getInputFillColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: categoria,
                  dropdownColor: AppColors.getCardColor(context),
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    labelStyle: TextStyle(
                      color: AppColors.getSubtextColor(context),
                    ),
                    filled: true,
                    fillColor: AppColors.getInputFillColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Sistema', child: Text('Sistema')),
                    DropdownMenuItem(
                      value: 'IA Financeira',
                      child: Text('IA Financeira'),
                    ),
                    DropdownMenuItem(value: 'Metas', child: Text('Metas')),
                    DropdownMenuItem(
                      value: 'Segurança',
                      child: Text('Segurança'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => categoria = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.getSubtextColor(context)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final t = tituloCtrl.text.trim();
                final m = msgCtrl.text.trim();
                if (t.isNotEmpty && m.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(this.context);
                  Navigator.pop(ctx);
                  await _firestoreService.criarNotificacao(
                    idCliente: uid,
                    titulo: t,
                    mensagem: m,
                    categoria: categoria,
                  );
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Notificação personalizada disparada com sucesso!',
                      ),
                      backgroundColor: primaryAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Disparar',
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
  }
}
