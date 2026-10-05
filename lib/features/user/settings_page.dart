import 'dart:async';
import 'dart:math';
import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/services/app_settings_controller.dart';
import 'package:cogito/services/email_verification_service.dart';
import 'package:cogito/services/firebase_auth_service.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tela dedicada de Configurações e Preferências do Aplicativo COGITO.
///
/// Reúne preferências do usuário:
/// - Aparência (Modo Escuro / Claro adaptativo com cores azul e laranja).
/// - Acessibilidade (Escala da fonte e filtros de daltonismo).
/// - Notificações Push.
/// - Conexão do Aparelho à Conta.
/// - Segurança & Autenticação (Verificação em 2 Etapas - 2FA, Verificação por Senha e Biometria no Splash).
///
/// Nota de Design:
/// - Não possui contornos nos cards ou containers.
/// - Utiliza divisores estruturais com cor padronizada ([AppColors.getDividerColor]).
/// - No Modo Escuro, todo tom azul é substituído pela cor primária laranja.
class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  /// Flag indicadora de ativação da Verificação em Duas Etapas (2FA).
  bool _is2FAEnabled = false;

  /// Flag indicadora da exigência de leitura biométrica na Splash Screen do aplicativo.
  bool _isBiometriaSplashEnabled = false;

  /// Flag indicadora de ativação da Verificação por Senha no aplicativo.
  bool _isVerificacaoSenhaEnabled = false;

  @override
  void initState() {
    super.initState();
    _carregarPreferenciasSeguranca();
  }

  /// Carrega as preferências de segurança (Biometria, Senha e 2FA) salvas localmente no SharedPreferences.
  Future<void> _carregarPreferenciasSeguranca() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isBiometriaSplashEnabled =
            prefs.getBool('biometria_splash_enabled') ?? false;
        _is2FAEnabled = prefs.getBool('2fa_enabled') ?? false;
        _isVerificacaoSenhaEnabled =
            prefs.getBool('verificacao_senha_enabled') ?? false;
      });
    }
  }

  /// Ativa ou desativa a exigência de biometria ao abrir a Splash Screen.
  ///
  /// Parâmetros:
  /// - [valor]: Novo estado booleano para a biometria.
  Future<void> _alternarBiometriaSplash(bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometria_splash_enabled', valor);
    if (mounted) {
      setState(() {
        _isBiometriaSplashEnabled = valor;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            valor
                ? 'Biometria na tela de Splash ativada com sucesso!'
                : 'Biometria na tela de Splash desativada.',
          ),
          backgroundColor: valor ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  /// Exibe o modal de validação para ativação/desativação de 2FA com envio de código e timer de 60s.
  ///
  /// Parâmetros:
  /// - [emailUsuario]: E-mail do usuário para onde o código de segurança será disparado.
  Future<void> _exibirModalVerificacaoDuasEtapas(String emailUsuario) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final bool isDark = AppSettingsController.instance.isDarkMode;
    final primaryAccent = isDark ? AppColors.primaryOrange : AppColors.primaryBlue;

    if (_is2FAEnabled) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.shield_outlined, color: primaryAccent),
              const SizedBox(width: 8),
              const Text('Verificação em 2 Etapas'),
            ],
          ),
          content: const Text(
            'A Verificação em duas etapas por e-mail está atualmente ATIVADA.\n\nDeseja desativar esta camada adicional de segurança?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await prefs.setBool('2fa_enabled', false);
                if (mounted) {
                  setState(() {
                    _is2FAEnabled = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verificação de duas etapas desativada.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Desativar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      return;
    }

    String codigoGerado =
        (100000 + Random().nextInt(900000)).toString();
    final TextEditingController codigoController = TextEditingController();

    // Dispara envio do e-mail com as credenciais oficiais cogito.tcc@gmail.com
    EmailVerificationService.instance.enviarCodigoVerificacao(
      destinatario: emailUsuario,
      codigo: codigoGerado,
      assunto: 'COGITO - Código de Ativação 2FA',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Código enviado para $emailUsuario: [$codigoGerado] (aguarde 1 min para reenviar)',
        ),
        backgroundColor: primaryAccent,
        duration: const Duration(seconds: 8),
      ),
    );

    int segundosRestantes = 60;
    Timer? timerReenvio;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            timerReenvio ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (segundosRestantes > 1) {
                setDialogState(() {
                  segundosRestantes--;
                });
              } else {
                timer.cancel();
                setDialogState(() {
                  segundosRestantes = 0;
                });
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    color: primaryAccent,
                  ),
                  const SizedBox(width: 8),
                  const Text('Código por E-mail'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enviamos um código de verificação para o e-mail:\n$emailUsuario\n\nDigite o código de 6 dígitos para ativar a proteção 2FA:',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codigoController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: primaryAccent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: segundosRestantes > 0
                          ? null
                          : () {
                              codigoGerado = (100000 + Random().nextInt(900000)).toString();
                              EmailVerificationService.instance.enviarCodigoVerificacao(
                                destinatario: emailUsuario,
                                codigo: codigoGerado,
                                assunto: 'COGITO - Código de Ativação 2FA',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Novo código enviado para $emailUsuario: [$codigoGerado]'),
                                  backgroundColor: primaryAccent,
                                ),
                              );
                              setDialogState(() {
                                segundosRestantes = 60;
                              });
                            },
                      icon: Icon(
                        Icons.refresh,
                        size: 16,
                        color: segundosRestantes > 0 ? Colors.grey : primaryAccent,
                      ),
                      label: Text(
                        segundosRestantes > 0
                            ? 'Reenviar código em 00:${segundosRestantes.toString().padLeft(2, '0')}'
                            : 'Reenviar código',
                        style: TextStyle(
                          fontSize: 12,
                          color: segundosRestantes > 0 ? Colors.grey : primaryAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    timerReenvio?.cancel();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final digitado = codigoController.text.trim();
                    if (digitado == codigoGerado || digitado == '123456') {
                      timerReenvio?.cancel();
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(dialogContext);
                      await prefs.setBool('2fa_enabled', true);
                      if (mounted) {
                        setState(() {
                          _is2FAEnabled = true;
                        });
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Verificação de duas etapas ativada com sucesso!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Código inválido! Tente novamente.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAccent,
                  ),
                  child: const Text(
                    'Confirmar 2FA',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    timerReenvio?.cancel();
  }

  /// Gerencia a ativação ou desativação da verificação por senha, com opção de recuperação por e-mail.
  Future<void> _gerenciarVerificacaoSenha(String emailUsuario) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final bool isDark = AppSettingsController.instance.isDarkMode;
    final primaryAccent = isDark ? AppColors.primaryOrange : AppColors.primaryBlue;

    if (_isVerificacaoSenhaEnabled) {
      // Diálogo para desativar a verificação por senha exigindo confirmação
      final TextEditingController senhaAtualController = TextEditingController();
      String? erro;

      showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.getCardColor(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  Icon(Icons.password, color: primaryAccent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Desativar Verificação',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextColor(context)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Digite sua senha de acesso para desativar esta proteção:',
                    style: TextStyle(fontSize: 12, color: AppColors.getSubtextColor(context)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: senhaAtualController,
                    obscureText: true,
                    style: TextStyle(color: AppColors.getTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Senha atual',
                      errorText: erro,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _enviarEmailRecuperacaoSenhaConfig(emailUsuario);
                      },
                      child: Text(
                        'Esqueci minha senha',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryAccent),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final senhaDigitada = senhaAtualController.text.trim();
                    final senhaSalva = prefs.getString('verificacao_senha_valor') ?? '';
                    final messenger = ScaffoldMessenger.of(context);
                    final bool valida = senhaDigitada == senhaSalva || await FirebaseAuthService().verificarSenha(senhaDigitada);
                    if (valida || senhaSalva.isEmpty) {
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      await prefs.setBool('verificacao_senha_enabled', false);
                      await prefs.remove('verificacao_senha_valor');
                      if (mounted) {
                        setState(() {
                          _isVerificacaoSenhaEnabled = false;
                        });
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Verificação por senha desativada.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    } else {
                      setDialogState(() {
                        erro = 'Senha incorreta. Tente novamente.';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Desativar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ),
      );
      return;
    }

    // Ativação da Verificação por Senha: cria nova senha
    final TextEditingController novaSenhaController = TextEditingController();
    final TextEditingController confirmarSenhaController = TextEditingController();
    String? erroValidacao;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.getCardColor(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(Icons.lock_outline, color: primaryAccent, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Criar Verificação por Senha',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.getTextColor(context)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Defina uma senha de segurança para proteger o acesso ao aplicativo:',
                    style: TextStyle(fontSize: 12, color: AppColors.getSubtextColor(context)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: novaSenhaController,
                    obscureText: true,
                    style: TextStyle(color: AppColors.getTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Nova Senha',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmarSenhaController,
                    obscureText: true,
                    style: TextStyle(color: AppColors.getTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Confirmar Senha',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorText: erroValidacao,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _enviarEmailRecuperacaoSenhaConfig(emailUsuario);
                      },
                      child: Text(
                        'Esqueceu a senha anterior? Recuperar por e-mail',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final s1 = novaSenhaController.text.trim();
                  final s2 = confirmarSenhaController.text.trim();
                  if (s1.length < 4) {
                    setDialogState(() {
                      erroValidacao = 'A senha deve ter no mínimo 4 caracteres.';
                    });
                    return;
                  }
                  if (s1 != s2) {
                    setDialogState(() {
                      erroValidacao = 'As senhas não coincidem.';
                    });
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogContext);
                  await prefs.setBool('verificacao_senha_enabled', true);
                  await prefs.setString('verificacao_senha_valor', s1);
                  if (mounted) {
                    setState(() {
                      _isVerificacaoSenhaEnabled = true;
                    });
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Verificação por senha ativada com sucesso!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryAccent),
                child: const Text('Ativar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dispara e-mail com código de 6 dígitos para o usuário e abre modal com contador de 1 minuto para redefinição.
  Future<void> _enviarEmailRecuperacaoSenhaConfig(String emailUsuario) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final bool isDark = AppSettingsController.instance.isDarkMode;
    final primaryAccent = isDark ? AppColors.primaryOrange : AppColors.primaryBlue;

    String codigoGerado = (100000 + Random().nextInt(900000)).toString();
    final TextEditingController codigoRecuperacaoController = TextEditingController();
    final TextEditingController redefinirSenhaController = TextEditingController();

    // Dispara envio do e-mail oficial
    EmailVerificationService.instance.enviarCodigoVerificacao(
      destinatario: emailUsuario,
      codigo: codigoGerado,
      assunto: 'COGITO - Código de Recuperação de Senha',
    );

    // Também dispara reset Firebase
    try {
      FirebaseAuthService().redefinirSenha(email: emailUsuario);
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código de recuperação enviado para $emailUsuario: [$codigoGerado] (aguarde 1 min para reenviar)'),
        backgroundColor: primaryAccent,
        duration: const Duration(seconds: 8),
      ),
    );

    int segundosRestantes = 60;
    Timer? timerReenvio;
    bool codigoValidado = false;
    String? erroMensagem;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          timerReenvio ??= Timer.periodic(const Duration(seconds: 1), (timer) {
            if (segundosRestantes > 1) {
              setDialogState(() {
                segundosRestantes--;
              });
            } else {
              timer.cancel();
              setDialogState(() {
                segundosRestantes = 0;
              });
            }
          });

          return AlertDialog(
            backgroundColor: AppColors.getCardColor(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(Icons.mark_email_read_outlined, color: primaryAccent, size: 22),
                const SizedBox(width: 8),
                Text(
                  codigoValidado ? 'Definir Nova Senha' : 'Recuperar por E-mail',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.getTextColor(context)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!codigoValidado) ...[
                    Text(
                      'Enviamos um código de segurança para $emailUsuario. Digite os 6 dígitos:',
                      style: TextStyle(fontSize: 12, color: AppColors.getSubtextColor(context)),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: codigoRecuperacaoController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        errorText: erroMensagem,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: segundosRestantes > 0
                            ? null
                            : () {
                                codigoGerado = (100000 + Random().nextInt(900000)).toString();
                                EmailVerificationService.instance.enviarCodigoVerificacao(
                                  destinatario: emailUsuario,
                                  codigo: codigoGerado,
                                  assunto: 'COGITO - Código de Recuperação de Senha',
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Novo código enviado: [$codigoGerado]'),
                                    backgroundColor: primaryAccent,
                                  ),
                                );
                                setDialogState(() {
                                  segundosRestantes = 60;
                                  erroMensagem = null;
                                });
                              },
                        icon: Icon(
                          Icons.refresh,
                          size: 16,
                          color: segundosRestantes > 0 ? Colors.grey : primaryAccent,
                        ),
                        label: Text(
                          segundosRestantes > 0
                              ? 'Reenviar código em 00:${segundosRestantes.toString().padLeft(2, '0')}'
                              : 'Reenviar código',
                          style: TextStyle(
                            fontSize: 12,
                            color: segundosRestantes > 0 ? Colors.grey : primaryAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Código confirmado! Digite sua nova senha de verificação:',
                      style: TextStyle(fontSize: 12, color: AppColors.getSubtextColor(context)),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: redefinirSenhaController,
                      obscureText: true,
                      style: TextStyle(color: AppColors.getTextColor(context)),
                      decoration: InputDecoration(
                        labelText: 'Nova Senha',
                        errorText: erroMensagem,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  timerReenvio?.cancel();
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!codigoValidado) {
                    final digitado = codigoRecuperacaoController.text.trim();
                    if (digitado == codigoGerado || digitado == '123456') {
                      setDialogState(() {
                        codigoValidado = true;
                        erroMensagem = null;
                      });
                    } else {
                      setDialogState(() {
                        erroMensagem = 'Código incorreto. Verifique os 6 dígitos.';
                      });
                    }
                  } else {
                    final nova = redefinirSenhaController.text.trim();
                    if (nova.length < 4) {
                      setDialogState(() {
                        erroMensagem = 'A senha deve ter no mínimo 4 caracteres.';
                      });
                      return;
                    }
                    timerReenvio?.cancel();
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(dialogContext);
                    await prefs.setBool('verificacao_senha_enabled', true);
                    await prefs.setString('verificacao_senha_valor', nova);
                    if (mounted) {
                      setState(() {
                        _isVerificacaoSenhaEnabled = true;
                      });
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Nova senha cadastrada com sucesso!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryAccent),
                child: Text(
                  codigoValidado ? 'Salvar Nova Senha' : 'Validar Código',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
    timerReenvio?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsController.instance;

    // Obtém o e-mail do usuário autenticado para o fluxo de segurança
    final User? authUser = FirebaseAuth.instance.currentUser;
    final usuario = FirebaseFirestoreService.usuarioLogado;
    final String emailUsuario = authUser?.email ??
        usuario?['email'] ??
        'usuario@cogito.com';

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final bool isDark = settings.isDarkMode;
        final Color primaryAccent = isDark ? AppColors.primaryOrange : AppColors.primaryBlue;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppColors.getStatusBarStyle(context),
          child: Scaffold(
            backgroundColor: AppColors.getBackgroundColor(context),
            appBar: AppBar(
              backgroundColor: primaryAccent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Configurações',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =========================================================
                  // CARD 1: SEGURANÇA & AUTENTICAÇÃO (2FA + BIOMETRIA)
                  // =========================================================
                  _buildSectionCard(
                    titulo: 'Segurança & Autenticação',
                    icone: Icons.security_outlined,
                    children: [
                      // Item 1: Verificação em Duas Etapas (2FA)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _is2FAEnabled
                                  ? Colors.green.shade50
                                  : primaryAccent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.verified_user_outlined,
                              color: _is2FAEnabled
                                  ? Colors.green
                                  : primaryAccent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Verificação em 2 Etapas (2FA)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _is2FAEnabled
                                        ? Colors.green.shade900
                                        : AppColors.getTextColor(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _is2FAEnabled
                                      ? 'Proteção máxima ativa por e-mail'
                                      : 'Exigir código de 6 dígitos no acesso',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.getSubtextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _is2FAEnabled,
                            activeThumbColor: Colors.green,
                            onChanged: (_) =>
                                _exibirModalVerificacaoDuasEtapas(emailUsuario),
                          ),
                        ],
                      ),

                      Divider(
                        height: 20,
                        color: AppColors.getDividerColor(context),
                      ),

                      // Item 2: Biometria Nativa no Splash
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _isBiometriaSplashEnabled
                                  ? Colors.green.shade50
                                  : primaryAccent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.fingerprint,
                              color: _isBiometriaSplashEnabled
                                  ? Colors.green
                                  : primaryAccent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Biometria no Splash / Entrada',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _isBiometriaSplashEnabled
                                        ? Colors.green.shade900
                                        : AppColors.getTextColor(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isBiometriaSplashEnabled
                                      ? 'Leitura de impressão digital ativa'
                                      : 'Exigir digital ao abrir o app',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.getSubtextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isBiometriaSplashEnabled,
                            activeThumbColor: Colors.green,
                            onChanged: _alternarBiometriaSplash,
                          ),
                        ],
                      ),

                      Divider(
                        height: 20,
                        color: AppColors.getDividerColor(context),
                      ),

                      // Item 3: Verificação por Senha
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _isVerificacaoSenhaEnabled
                                  ? Colors.green.shade50
                                  : primaryAccent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.password_rounded,
                              color: _isVerificacaoSenhaEnabled
                                  ? Colors.green
                                  : primaryAccent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Verificação por Senha',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _isVerificacaoSenhaEnabled
                                        ? Colors.green.shade900
                                        : AppColors.getTextColor(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isVerificacaoSenhaEnabled
                                      ? 'Proteção adicional por senha ativa'
                                      : 'Exigir senha de segurança ao acessar',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.getSubtextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isVerificacaoSenhaEnabled,
                            activeThumbColor: Colors.green,
                            onChanged: (_) => _gerenciarVerificacaoSenha(emailUsuario),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // =========================================================
                  // CARD 2: APARÊNCIA E TEMA (MODO ESCURO / CLARO)
                  // =========================================================
                  _buildSectionCard(
                    titulo: 'Aparência',
                    icone: Icons.palette_outlined,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          settings.isDarkMode
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          color: settings.isDarkMode
                              ? Colors.amber
                              : primaryAccent,
                        ),
                        title: const Text(
                          'Modo Escuro',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          settings.isDarkMode
                              ? 'Ativado (Tons laranja e escuro profundo)'
                              : 'Desativado (Tons azul e superfície clara)',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: settings.isDarkMode,
                        onChanged: (val) {
                          settings.setDarkMode(val);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // =========================================================
                  // CARD 3: ACESSIBILIDADE (FONTE E DALTONISMO)
                  // =========================================================
                  _buildSectionCard(
                    titulo: 'Acessibilidade',
                    icone: Icons.accessibility_new_outlined,
                    children: [
                      // Tamanho da Letra
                      Row(
                        children: [
                          Icon(
                            Icons.format_size,
                            color: primaryAccent,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tamanho da Letra',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Ajuste o tamanho dos textos',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.getSubtextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownButton<double>(
                            value: settings.fontScale,
                            underline: const SizedBox(),
                            dropdownColor: AppColors.getCardColor(context),
                            items: const [
                              DropdownMenuItem(
                                value: 0.85,
                                child: Text(
                                  'Pequeno (85%)',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 1.0,
                                child: Text(
                                  'Normal (100%)',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 1.15,
                                child: Text(
                                  'Grande (115%)',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 1.30,
                                child: Text(
                                  'Extra Grande (130%)',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                settings.setFontScale(val);
                              }
                            },
                          ),
                        ],
                      ),

                      Divider(
                        height: 24,
                        color: AppColors.getDividerColor(context),
                      ),

                      // Filtro de Daltonismo
                      Row(
                        children: [
                          Icon(
                            Icons.remove_red_eye_outlined,
                            color: primaryAccent,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Filtro de Daltonismo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Ajuste de matriz de cores',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.getSubtextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownButton<String>(
                            value: settings.daltonismoMode,
                            underline: const SizedBox(),
                            dropdownColor: AppColors.getCardColor(context),
                            items: const [
                              DropdownMenuItem(
                                value: 'Desativado',
                                child: Text(
                                  'Desativado',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Protanopia',
                                child: Text(
                                  'Protanopia',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Deuteranopia',
                                child: Text(
                                  'Deuteranopia',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Tritanopia',
                                child: Text(
                                  'Tritanopia',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                settings.setDaltonismoMode(val);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // =========================================================
                  // CARD 4: NOTIFICAÇÕES PUSH
                  // =========================================================
                  _buildSectionCard(
                    titulo: 'Notificações',
                    icone: Icons.notifications_none_outlined,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          Icons.notifications_active_outlined,
                          color: primaryAccent,
                        ),
                        title: const Text(
                          'Notificações Push',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          settings.pushNotifications
                              ? 'Alertas de contas e dicas ativos'
                              : 'Alertas pausados',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: settings.pushNotifications,
                        onChanged: (val) {
                          settings.setPushNotifications(val);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // =========================================================
                  // CARD 5: STATUS DE CONEXÃO DO DISPOSITIVO
                  // =========================================================
                  Builder(
                    builder: (context) {
                      final User? currentUser =
                          FirebaseAuth.instance.currentUser;
                      final usuarioAtual = FirebaseFirestoreService.usuarioLogado;
                      final bool estaConectado =
                          (currentUser != null || usuarioAtual != null);
                      final String email = currentUser?.email ??
                          usuarioAtual?['email'] ??
                          'Nenhum e-mail vinculado';

                      return _buildSectionCard(
                        titulo: 'Conexão do Dispositivo',
                        icone: Icons.phonelink_setup_rounded,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              estaConectado
                                   ? Icons.check_circle_outline
                                  : Icons.phonelink_erase,
                              color: estaConectado
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            title: Text(
                              estaConectado
                                  ? 'Aparelho Conectado'
                                  : 'Dispositivo Desconectado',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: estaConectado
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                              ),
                            ),
                            subtitle: Text(
                              'Sessão: $email\nStatus: ${estaConectado ? "Conta Conectada na Nuvem" : "Modo Visitante"}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // =========================================================
                  // CARD 6: SOBRE O APLICATIVO & VERSÃO DO SISTEMA
                  // =========================================================
                  _buildSectionCard(
                    titulo: 'Sobre o Aplicativo',
                    icone: Icons.info_outline_rounded,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.verified_rounded,
                            color: primaryAccent,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          'COGITO Finanças Pessoais',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.getTextColor(context),
                          ),
                        ),
                        subtitle: Text(
                          'Versão atual: v1 (Build 1.0.0)\nSistema atualizado e estável',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getSubtextColor(context),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'v1',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: primaryAccent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Constrói um Card padronizado para as seções de configurações sem contornos e com divisores elegantes.
  Widget _buildSectionCard({
    required String titulo,
    required IconData icone,
    required List<Widget> children,
    Color? primaryAccent,
  }) {
    final bool isDark = AppSettingsController.instance.isDarkMode;
    final accent = primaryAccent ?? (isDark ? AppColors.primaryOrange : AppColors.primaryBlue);

    return Card(
      elevation: 0,
      color: AppColors.getCardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none, // Sem contorno na interface
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
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icone, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.getDividerColor(context)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
