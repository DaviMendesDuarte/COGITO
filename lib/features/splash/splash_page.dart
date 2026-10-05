import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/features/auth/auth_choice_page.dart';
import 'package:cogito/features/auth/recuperar_senha_page.dart';
import 'package:cogito/features/home/home_page.dart';
import 'package:cogito/services/biometric_service.dart';
import 'package:cogito/services/firebase_auth_service.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tela de Splash (exibida durante a inicialização / carregamento do aplicativo).
/// Realiza a verificação de sessão ativa no Firebase e Biometria Nativa no Splash.
/// Se a conta estiver logada, leva diretamente para a [HomePage].
/// Caso não haja usuário autenticado, direciona diretamente para a tela de autenticação ([AuthChoicePage]),
/// eliminando completamente a etapa de onboarding.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  /// Instância dos serviços de autenticação e biometria.
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _inicializarSplash();
  }

  /// Inicializa a splash screen, verifica credenciais ativas e biometria no splash.
  /// Caso o usuário já esteja autenticado, direciona para a [HomePage].
  /// Caso contrário, redireciona diretamente para a tela de cadastro ou login ([AuthChoicePage]).
  Future<void> _inicializarSplash() async {
    // Aguarda 1.0 segundo para exibição da logomarca institucional
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    // Verifica se já existe uma sessão ativa
    final bool temSessao = await _firebaseAuthService
        .verificarECarregarSessaoLogada();
    final bool usuarioLogado =
        temSessao || FirebaseFirestoreService.usuarioLogado != null;

    if (usuarioLogado) {
      // Carrega as preferências de segurança do Splash
      final prefs = await SharedPreferences.getInstance();
      final bool? biometriaPref = prefs.getBool('biometria_splash_enabled');
      final bool podeUsarBiometria = await _biometricService.podeUsarBiometria();

      // Ativa se explicitamente configurada como true, ou por padrão se o aparelho possuir biometria configurada
      final bool biometriaSplashAtiva = (biometriaPref == true) || (biometriaPref == null && podeUsarBiometria);

      // Se a biometria puder ser utilizada e estiver ativa
      if (biometriaSplashAtiva && podeUsarBiometria) {
        final bool autenticado = await _biometricService
            .autenticarComImpressaoDigital(
              motivo: 'Toque no sensor biométrico para entrar no COGITO',
            );

        if (!mounted) return;

        if (autenticado) {
          _navegarParaHome();
        } else {
          // Em caso de cancelamento da biometria, exibe opção para tentar novamente ou entrar com senha
          _exibirOpcaoReautenticacao();
        }
      } else {
        // Sem biometria configurada ou indisponível, vai direto para a HomePage
        _navegarParaHome();
      }
    } else {
      // Usuário não autenticado, direciona diretamente para a tela de cadastro ou login (AuthChoicePage)
      _navegarParaAutenticacao();
    }
  }

  /// Navega diretamente para a HomePage para usuários já autenticados.
  void _navegarParaHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  /// Navega diretamente para a tela de autenticação (AuthChoicePage - Login ou Cadastro),
  /// iniciando o fluxo direto sem exibição de tela de onboarding.
  void _navegarParaAutenticacao() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthChoicePage()),
      (route) => false,
    );
  }

  /// Exibe diálogo de segurança na splash caso a leitura biométrica falhe ou seja cancelada pelo usuário.
  /// Remove qualquer possibilidade de bypass, exigindo confirmação biométrica ou validação obrigatória de senha.
  void _exibirOpcaoReautenticacao() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.getBorderColor(context)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        actionsPadding: const EdgeInsets.fromLTRB(12, 10, 14, 14),
        title: Row(
          children: [
            Icon(
              Icons.fingerprint,
              color: AppColors.isDarkMode(context) ? AppColors.primaryOrange : AppColors.primaryBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Acesso Seguro',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.getTextColor(context),
              ),
            ),
          ],
        ),
        content: Text(
          'Autenticação biométrica não confirmada. Valide sua identidade para acessar suas finanças.',
          style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.getSubtextColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _exibirDialogoSenhaObrigatoria();
            },
            child: Text(
              'Entrar com Senha',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppColors.isDarkMode(context) ? AppColors.primaryOrange : AppColors.primaryBlue,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _inicializarSplash();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getActionButtonColor(context),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Tentar Novamente',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Exibe modal com campo de senha obrigatório para desbloquear o aplicativo quando a biometria falhar.
  void _exibirDialogoSenhaObrigatoria() {
    final TextEditingController senhaController = TextEditingController();
    bool carregando = false;
    String? erroMensagem;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (senhaDialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isDark = AppColors.isDarkMode(context);

            return AlertDialog(
              backgroundColor: AppColors.getCardColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: AppColors.getBorderColor(context)),
              ),
              titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18),
              actionsPadding: const EdgeInsets.fromLTRB(12, 6, 14, 14),
              title: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Confirme sua Senha',
                    style: TextStyle(
                      color: AppColors.getTextColor(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Digite a senha da sua conta para desbloquear o aplicativo:',
                    style: TextStyle(fontSize: 12, color: AppColors.getSubtextColor(context)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: senhaController,
                    obscureText: true,
                    style: TextStyle(fontSize: 13, color: AppColors.getTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      labelStyle: TextStyle(fontSize: 12, color: AppColors.getSubtextColor(context)),
                      filled: true,
                      fillColor: AppColors.getInputFillColor(context),
                      prefixIcon: Icon(
                        Icons.password,
                        size: 20,
                        color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.getBorderColor(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.getBorderColor(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
                        ),
                      ),
                      errorText: erroMensagem,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(senhaDialogContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RecuperarSenhaPage(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Esqueci minha senha',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.primaryOrange : AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: carregando
                      ? null
                      : () async {
                          Navigator.pop(senhaDialogContext);
                          // Se desistir de digitar a senha, desloga e envia diretamente para a tela de autenticação
                          FirebaseFirestoreService.deslogar();
                          await _firebaseAuthService.signOut();
                          if (mounted) _navegarParaAutenticacao();
                        },
                  child: Text(
                    'Sair da Conta',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: carregando
                      ? null
                      : () async {
                          final String senha = senhaController.text.trim();
                          if (senha.isEmpty) {
                            setDialogState(() {
                              erroMensagem = 'Informe sua senha';
                            });
                            return;
                          }

                          setDialogState(() {
                            carregando = true;
                            erroMensagem = null;
                          });

                          final dialogNav = Navigator.of(senhaDialogContext);
                          final bool senhaValida = await _firebaseAuthService
                              .verificarSenha(senha);

                          if (!mounted) return;

                          if (senhaValida) {
                            dialogNav.pop();
                            _navegarParaHome();
                          } else {
                            setDialogState(() {
                              carregando = false;
                              erroMensagem =
                                  'Senha incorreta. Tente novamente.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getActionButtonColor(context),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: carregando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Desbloquear',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.getOverlayStyleForBackground(AppColors.primaryBlue),
      child: Scaffold(
        backgroundColor: AppColors.primaryBlue,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Center(
                child: Image.asset('assets/images/logo/logo.png', width: 230),
              ),
              const Spacer(),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 5.5,
                  strokeCap: StrokeCap.round,
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
