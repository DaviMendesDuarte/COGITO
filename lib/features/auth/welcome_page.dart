import 'package:cogito/features/auth/auth_choice_page.dart';
import 'package:flutter/material.dart';

/// Tela de boas-vindas transferida para o módulo de autenticação.
/// Redireciona imediatamente para a [AuthChoicePage] (tela de cadastro ou login),
/// mantendo compatibilidade de rotas caso seja instanciada.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Renderiza diretamente a tela de cadastro ou login (AuthChoicePage)
    return const AuthChoicePage();
  }
}
