import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/common/constant/text_styles.dart';
import 'package:cogito/features/auth/login_page.dart';
import 'package:cogito/features/home/home_page.dart';
import 'package:cogito/services/firebase_auth_service.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tela de Cadastro de novos usuários.
///
/// Realiza a criação de credenciais no Firebase Authentication e grava
/// as informações cadastrais iniciais no Firestore com fluxo modularizado.
class CadastroPage extends StatefulWidget {
  /// Construtor padrão da tela de cadastro.
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  /// Chave global do formulário para validação dos campos.
  final _formKey = GlobalKey<FormState>();

  /// Controladores dos campos de texto (Nome, E-mail, Senha e Confirmação de Senha).
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController =
      TextEditingController();

  /// Flags de visibilidade de senha e estado de requisição assíncrona.
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  /// Instância do serviço de autenticação do Firebase.
  final FirebaseAuthService _firebaseService = FirebaseAuthService();

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  /// Realiza o processo de cadastro no Firebase Authentication e Firestore.
  ///
  /// Valida os campos do formulário, cria a credencial no Auth, salva
  /// o perfil inicial no Firestore e redireciona para a [HomePage].

  Future<void> _efetuarCadastro() async {
    // 1. Validação completa dos campos do formulário
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final String nomeCompleto = _nomeController.text.trim();
    final String email = _emailController.text.trim();
    final String senha = _senhaController.text;

    try {
      // 2. Chamada ao serviço para criação de usuário e persistência no banco
      final usuario = await _firebaseService.cadastrarComEmailESenha(
        email: email,
        senha: senha,
        nome: nomeCompleto.isNotEmpty ? nomeCompleto : 'Usuário COGITO',
        telefone: '',
        idade: 18,
        tipoRenda: 'Salario_Fixo',
        rendaMensal: 0.0,
      );

      if (!mounted) return;

      // 3. Validação de sucesso e feedback ao usuário
      if (usuario != null || FirebaseFirestoreService.usuarioLogado != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta criada com sucesso! Bem-vindo(a) ao COGITO.'),
            backgroundColor: Colors.green,
          ),
        );

        // 4. Redirecionamento com limpeza da pilha de rotas
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Tratamento de falhas (ex.: e-mail já cadastrado, senha fraca)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao cadastrar: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Realiza o cadastro/login social com a conta Google via Firebase Authentication.
  ///
  /// Autentica pelo OAuth do Google e vincula os dados ao Firestore.
  Future<void> _cadastrarComGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final usuario = await _firebaseService.signInWithGoogle();

      if (!mounted) return;

      if (usuario != null) {
        FirebaseFirestoreService.usuarioLogado =
            FirebaseAuthService.extrairDadosUsuarioGoogle(usuario);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bem-vindo(a), ${usuario.displayName ?? 'usuário'}!'),
            backgroundColor: Colors.green,
          ),
        );

        // Redireciona para a tela principal
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao entrar com Google: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
            // Desativa a rolagem da tela para que ela não seja scrollável
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 12.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho com mascote e textos informativos
                  const _RegisterHeader(),

                  const SizedBox(height: 28),

                  // Campo de Nome Completo
                  _buildNameField(),

                  const SizedBox(height: 16),

                  // Campo de E-mail
                  _buildEmailField(),

                  const SizedBox(height: 16),

                  // Campo de Senha
                  _buildPasswordField(),

                  const SizedBox(height: 16),

                  // Campo de Confirmação de Senha
                  _buildConfirmPasswordField(),

                  const SizedBox(height: 28),

                  // Botão de envio do formulário
                  _buildSubmitButton(),

                  const SizedBox(height: 24),

                  // Divisor 'ou'
                  const _SocialRegisterDivider(),

                  const SizedBox(height: 16),

                  // Botão de cadastro social Google
                  _buildGoogleButton(),

                  const SizedBox(height: 24),

                  // Rodapé com link para Login
                  const _LoginPrompt(),

                  const SizedBox(height: 32),

                  // Selo institucional discreto
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

  /// Constrói a AppBar superior com título e botão de retorno adaptada ao tema.
  PreferredSizeWidget _buildAppBar() {
    final bool isDark = AppColors.isDarkMode(context);

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        'Cadastro COGITO',
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.primaryBlue,
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: isDark ? Colors.white : AppColors.primaryBlue,
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  /// Constrói o campo para entrada do nome e sobrenome do usuário.
  Widget _buildNameField() {
    return TextFormField(
      controller: _nomeController,
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      decoration: _buildInputDecoration(
        label: 'Nome e Sobrenome',
        icon: Icons.person_outline,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Informe seu nome e sobrenome';
        }
        return null;
      },
    );
  }

  /// Constrói o campo para inserção do endereço de e-mail.
  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: _buildInputDecoration(
        label: 'E-mail',
        icon: Icons.email_outlined,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Informe o e-mail';
        }
        if (!v.contains('@')) {
          return 'Informe um e-mail válido';
        }
        return null;
      },
    );
  }

  /// Constrói o campo para inserção da senha com alternância de visibilidade.
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _senhaController,
      obscureText: _obscurePassword,
      decoration:
          _buildInputDecoration(
            label: 'Senha',
            icon: Icons.lock_outline,
          ).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
      validator: (v) {
        if (v == null || v.length < 6) {
          return 'A senha deve ter no mínimo 6 caracteres';
        }
        return null;
      },
    );
  }

  /// Constrói o campo de confirmação de senha para validação de igualdade.
  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmarSenhaController,
      obscureText: _obscureConfirmPassword,
      decoration:
          _buildInputDecoration(
            label: 'Confirmar Senha',
            icon: Icons.lock_reset_outlined,
          ).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
      validator: (v) {
        if (v != _senhaController.text) {
          return 'As senhas não coincidem';
        }
        return null;
      },
    );
  }

  /// Constrói o botão principal de envio do formulário de cadastro.
  Widget _buildSubmitButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _efetuarCadastro,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.getActionButtonColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 2,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('CADASTRAR', style: TextStyles.buttonPrimary),
      ),
    );
  }

  /// Constrói o botão de cadastro social com o Google com suporte ao tema escuro.
  Widget _buildGoogleButton() {
    final bool isDark = AppColors.isDarkMode(context);

    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _cadastrarComGoogle,
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
              'Cadastrar com Google',
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

  /// Gera a estilização padrão dos campos de entrada adaptada ao tema escuro.
  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
  }) {
    final bool isDark = AppColors.isDarkMode(context);

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.getSubtextColor(context)),
      prefixIcon: Icon(
        icon,
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

/// Cabeçalho da tela de cadastro contendo a logo tipográfica e os títulos originais.
class _RegisterHeader extends StatelessWidget {
  /// Construtor constante do cabeçalho de cadastro.
  const _RegisterHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        // Logo tipográfica negativa mantida no tamanho original
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
        const SizedBox(height: 20),
        Text(
          'Crie sua conta',
          style: TextStyles.welcomeTitle.copyWith(
            color: AppColors.getTextColor(context),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Informe seu e-mail e crie uma senha para se cadastrar',
          textAlign: TextAlign.center,
          style: TextStyles.welcomeDescription.copyWith(
            color: AppColors.getSubtextColor(context),
          ),
        ),
      ],
    );
  }
}

/// Divisor com texto 'ou' para separar o cadastro tradicional do cadastro social.
class _SocialRegisterDivider extends StatelessWidget {
  /// Construtor constante do divisor.
  const _SocialRegisterDivider();

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

/// Linha de rodapé com navegação para a tela de Login.
class _LoginPrompt extends StatelessWidget {
  /// Construtor constante do prompt de login.
  const _LoginPrompt();

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Já possui uma conta? ',
          style: TextStyle(color: AppColors.getSubtextColor(context)),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
          child: Text(
            'Faça Login',
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

/// Rodapé institucional exibindo a identificação acadêmica do projeto com espaçamento expandido.
class _InstitutionalFooter extends StatelessWidget {
  /// Construtor constante do rodapé institucional.
  const _InstitutionalFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        // Identificação acadêmica e institucional do projeto
        child: Text(
          '3°DS PI • COGITO',
          style: TextStyle(
            color: AppColors.getSubtextColor(context).withValues(alpha: 0.55),
            fontSize: 9.5,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
