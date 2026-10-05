import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/common/constant/text_styles.dart';
import 'package:cogito/features/auth/recuperar_senha_page.dart';
import 'package:cogito/features/auth/register_page.dart';
import 'package:cogito/features/home/home_page.dart';
import 'package:cogito/services/firebase_auth_service.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tela de Login para autenticação do usuário.
///
/// Integra com o Firebase Authentication (E-mail/Senha e Google Sign-In) e Firestore,
/// estruturada com métodos e componentes desacoplados para reduzir aninhamento.
class LoginPage extends StatefulWidget {
  /// Construtor padrão da tela de login.
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// Chave global para identificação e validação do formulário.
  final _formKey = GlobalKey<FormState>();

  /// Controladores dos campos de entrada de texto.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  /// Estado para controlar a visibilidade da senha (ocultar/mostrar).
  bool _obscurePassword = true;

  /// Estado para controlar a exibição do indicador de carregamento durante a requisição.
  bool _isLoading = false;

  /// Instância do serviço de autenticação Firebase.
  final FirebaseAuthService _firebaseService = FirebaseAuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  /// Realiza o login via E-mail e Senha no Firebase Authentication.
  Future<void> _efetuarLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _firebaseService.entrarComEmailESenha(
        email: _emailController.text.trim(),
        senha: _senhaController.text,
      );
      if (!mounted) return;

      final nome = FirebaseFirestoreService.usuarioLogado?['nome'] ?? 'Usuário COGITO';
      _concluirAutenticacao('Bem-vindo(a), $nome!');
    } catch (e) {
      if (mounted) _exibirAlerta('Erro ao efetuar login: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Realiza o login social via Google Sign-In integrado ao Firebase.
  Future<void> _entrarComGoogle() async {
    setState(() => _isLoading = true);

    try {
      final usuario = await _firebaseService.signInWithGoogle();
      if (!mounted || usuario == null) return;

      FirebaseFirestoreService.usuarioLogado = FirebaseAuthService.extrairDadosUsuarioGoogle(usuario);
      await FirebaseFirestoreService().buscarUsuario(usuario.uid);
      if (!mounted) return;

      _concluirAutenticacao('Bem-vindo(a), ${usuario.displayName ?? 'usuário'}!');
    } catch (e) {
      if (mounted) _exibirAlerta('Erro ao entrar com Google: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Notifica o usuário e redireciona para a HomePage limpando o histórico de rotas
  void _concluirAutenticacao(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.green),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  // Exibe mensagem de feedback de erro
  void _exibirAlerta(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.getOverlayStyleForBackground(AppColors.getBackgroundColor(context)),
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: _buildAppBar(),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho institucional (mascote + títulos)
                  const _LoginHeader(),

                  const SizedBox(height: 32),

                  // Campo de e-mail com validação
                  _buildEmailField(),

                  const SizedBox(height: 16),

                  // Campo de senha com controle de visibilidade
                  _buildPasswordField(),

                  const SizedBox(height: 8),

                  // Ação de recuperação de senha
                  _buildForgotPasswordButton(),

                  const SizedBox(height: 16),

                  // Botão de login tradicional
                  _buildSubmitButton(),

                  const SizedBox(height: 24),

                  // Separador 'ou'
                  const _SocialLoginDivider(),

                  const SizedBox(height: 16),

                  // Botão de login social via Google
                  _buildGoogleButton(),

                  const SizedBox(height: 24),

                  // Rodapé com link para cadastro
                  const _RegisterPrompt(),

                  const SizedBox(height: 32),

                  // Selo institucional com o ícone negativo acima do texto
                  const _InstitutionalFooter(),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Constrói a AppBar transparente com botão de retorno adaptada ao tema.
  PreferredSizeWidget _buildAppBar() {
    final bool isDark = AppColors.isDarkMode(context);

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: isDark ? Colors.white : AppColors.primaryBlue,
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  /// Constrói o campo de texto para inserção do e-mail.
  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: _buildInputDecoration(
        label: 'E-mail',
        hint: 'exemplo@cogito.com',
        prefixIcon: Icons.email_outlined,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Informe o seu e-mail';
        }
        if (!value.contains('@')) {
          return 'Informe um e-mail válido';
        }
        return null;
      },
    );
  }

  /// Constrói o campo de texto para inserção da senha com botão para alternar visibilidade.
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _senhaController,
      obscureText: _obscurePassword,
      decoration:
          _buildInputDecoration(
            label: 'Senha',
            prefixIcon: Icons.lock_outline,
          ).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Informe a sua senha';
        }
        return null;
      },
    );
  }

  /// Constrói o botão de link para a tela de recuperação de senha.
  Widget _buildForgotPasswordButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RecuperarSenhaPage()),
          );
        },
        child: Text(
          'Esqueceu a senha?',
          style: TextStyles.poppinsBold(
            fontSize: 13,
            color: AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }

  /// Constrói o botão principal de envio do formulário de login.
  Widget _buildSubmitButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _efetuarLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.getActionButtonColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 2,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('ENTRAR', style: TextStyles.buttonPrimary),
      ),
    );
  }

  /// Constrói o botão para autenticação via Google com suporte ao tema escuro.
  Widget _buildGoogleButton() {
    final bool isDark = AppColors.isDarkMode(context);

    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _entrarComGoogle,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.getBorderColor(context), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          backgroundColor: isDark ? AppColors.darkCardColor : Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logotipo oficial colorido do Google
            Image.asset(
              'assets/images/other_logo/google_logo.png',
              height: 24,
              width: 24,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Text(
              'Entrar com Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gera a decoração padronizada para os campos de texto do formulário.
  InputDecoration _buildInputDecoration({
    required String label,
    String? hint,
    required IconData prefixIcon,
  }) {
    final bool isDark = AppColors.isDarkMode(context);

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.getSubtextColor(context)),
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
      prefixIcon: Icon(
        prefixIcon,
        color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
      ),
      filled: true,
      fillColor: AppColors.getInputFillColor(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.getBorderColor(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.getBorderColor(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
          width: 2,
        ),
      ),
    );
  }
}

/// Cabeçalho da tela de login contendo o mascote e os textos de boas-vindas.
class _LoginHeader extends StatelessWidget {
  /// Construtor constante do cabeçalho de login.
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        // Logo tipográfica negativa mantida no tamanho ideal
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/logo/logo_writingNegative.png',
              height: 64,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Entrar na sua conta',
          textAlign: TextAlign.center,
          style: TextStyles.welcomeTitle.copyWith(
            color: AppColors.getTextColor(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Acesse com suas credenciais do COGITO',
          textAlign: TextAlign.center,
          style: TextStyles.welcomeDescription.copyWith(
            color: AppColors.getSubtextColor(context),
          ),
        ),
      ],
    );
  }
}

/// Divisor visual entre o login por e-mail e o login social.
class _SocialLoginDivider extends StatelessWidget {
  /// Construtor constante do divisor.
  const _SocialLoginDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(thickness: 1, color: AppColors.getBorderColor(context))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ou',
            style: TextStyle(color: AppColors.getSubtextColor(context), fontSize: 13),
          ),
        ),
        Expanded(child: Divider(thickness: 1, color: AppColors.getBorderColor(context))),
      ],
    );
  }
}

/// Linha de rodapé direcionando o usuário sem conta para a tela de Cadastro.
class _RegisterPrompt extends StatelessWidget {
  /// Construtor constante do prompt de cadastro.
  const _RegisterPrompt();

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Ainda não tem conta? ',
          style: TextStyle(color: AppColors.getSubtextColor(context)),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CadastroPage()),
            );
          },
          child: Text(
            'Cadastre-se',
            style: TextStyle(
              color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rodapé institucional exibindo a identificação acadêmica do projeto com tipografia reduzida e discreta.
class _InstitutionalFooter extends StatelessWidget {
  /// Construtor constante do rodapé institucional.
  const _InstitutionalFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Center(
        // Identificação acadêmica e institucional do projeto em tamanho reduzido
        child: Text(
          '3°DS PI • COGITO',
          style: TextStyle(
            color: AppColors.getSubtextColor(context).withValues(alpha: 0.5),
            fontSize: 8.0,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
