import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/features/auth/login_page.dart';
import 'package:cogito/features/auth/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tela de Escolha de Autenticação (AuthChoicePage).
///
/// Exibida após a conclusão do onboarding de apresentação do app.
/// Apresenta uma interface limpa e modular com as opções de Login e Cadastro,
/// mantendo a árvore de widgets rasa e sem níveis profundos de indentação.
class AuthChoicePage extends StatelessWidget {
  /// Construtor padrão da tela de escolha de autenticação.
  const AuthChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode(context);
    final Color bottomCardColor = AppColors.getCardColor(context);

    // Configura a barra de status com fundo azul e a barra de navegação/gestos com a cor do card inferior
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: AppColors.primaryBlue,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        // Remove a cor azul da barra de navegação por gestos, sincronizando com o card inferior
        systemNavigationBarColor: bottomCardColor,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: const Scaffold(
        backgroundColor: AppColors.primaryBlue,
        body: SafeArea(
          bottom: false, // Permite que o container de ações preencha até a borda inferior sem expor o fundo azul
          child: Column(
            children: [
              // Seção superior: Logotipo da marca COGITO
              _LogoSection(),

              // Seção inferior: Card com as opções de autenticação
              _AuthActionsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget privado responsável pela exibição da identidade visual (Logo COGITO).
///
/// Ocupa a parte superior da tela de forma proporcional (flex: 5) e exibe
/// a imagem oficial com um fallback em texto caso haja falha no carregamento do asset.
class _LogoSection extends StatelessWidget {
  /// Construtor constante da seção de logotipo.
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 5,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Image.asset(
            'assets/images/logo/logo_writing.png',
            height: 65,
            fit: BoxFit.contain,
            // Fallback elegante caso a imagem não seja encontrada
            errorBuilder: (context, error, stackTrace) => const Text(
              'COGITO',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget privado que engloba o container inferior de ações e informações.
///
/// Ocupa a área inferior da tela (flex: 4), com fundo branco e bordas retas,
/// contendo textos introdutórios, botões de ação e rodapé institucional.
class _AuthActionsSection extends StatelessWidget {
  /// Construtor constante da seção de ações.
  const _AuthActionsSection();

  @override
  Widget build(BuildContext context) {
    // Espaçamento inferior respeitando a barra de navegação/gestos do sistema
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Expanded(
      flex: 4,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(28, 36, 28, 20 + bottomInset),
        decoration: BoxDecoration(
          color: AppColors.getCardColor(context),
          borderRadius: BorderRadius.zero,
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título e subtítulo explicativo
            _SectionHeader(),

            Spacer(),

            // Botão principal: Entrar na Conta
            _LoginButton(),

            SizedBox(height: 14),

            // Botão secundário: Criar Conta Grátis
            _RegisterButton(),

            Spacer(),

            // Informações do rodapé
            _FooterSection(),
          ],
        ),
      ),
    );
  }
}

/// Widget privado para o cabeçalho textual da seção de ações adaptado ao tema.
class _SectionHeader extends StatelessWidget {
  /// Construtor constante do cabeçalho da seção.
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comece agora',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextColor(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Acesse ou crie sua conta para começar a organizar suas finanças.',
          style: TextStyle(fontSize: 14, color: AppColors.getSubtextColor(context)),
        ),
      ],
    );
  }
}

/// Botão de ação primário para navegação até a tela de Login adaptado ao tema escuro.
class _LoginButton extends StatelessWidget {
  /// Construtor constante do botão de login.
  const _LoginButton();

  /// Realiza a navegação para a tela [LoginPage].
  void _navigateToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color botaoCor = AppColors.getActionButtonColor(context);

    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: () => _navigateToLogin(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: botaoCor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: botaoCor.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login_rounded, size: 20),
            SizedBox(width: 10),
            Text(
              'ENTRAR NA CONTA',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botão de ação secundário para navegação até a tela de Cadastro adaptado ao tema escuro.
class _RegisterButton extends StatelessWidget {
  /// Construtor constante do botão de cadastro.
  const _RegisterButton();

  /// Realiza a navegação para a tela [CadastroPage].
  void _navigateToRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CadastroPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDarkMode(context);
    final Color bordaCor = isDark ? AppColors.primaryOrange : AppColors.primaryBlue;

    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: () => _navigateToRegister(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : AppColors.primaryBlue,
          side: BorderSide(color: bordaCor, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_rounded, size: 20),
            SizedBox(width: 10),
            Text(
              'CRIAR CONTA GRÁTIS',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget privado que renderiza o rodapé institucional com tipografia reduzida e discreta.
class _FooterSection extends StatelessWidget {
  /// Construtor constante do rodapé institucional.
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14.0),
      child: Center(
        // Identificação acadêmica e institucional em tamanho reduzido
        child: Text(
          '3°DS PI • COGITO',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 8.0,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
