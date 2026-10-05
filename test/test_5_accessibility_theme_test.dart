import 'package:cogito/services/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
/// TESTE 5: ACESSIBILIDADE & TEMA - CONTROLE REATIVO GLOBAL VIA CHANGENOTIFIER
/// ============================================================================
///
/// Este teste unitário valida o controlador global [AppSettingsController].
///
/// Regra de Negócio:
/// - O aplicativo deve permitir a alternância imediata entre Modo Claro e Modo Escuro.
/// - Deve permitir a personalização do fator de escala tipográfica (fontScale).
/// - Deve controlar a permissão de notificações push.
/// - Todas as modificações de estado devem emitir notificações síncronas para ouvintes reativos.
void main() {
  group('Acessibilidade e Aparência - Controle Global Reativo', () {
    // Instância singleton do controlador de configurações
    final controller = AppSettingsController.instance;

    /// Testa a alteração de tema, escala de fonte e disparo do ChangeNotifier.
    test(
      'Deve alternar temas e ajustar escala de fonte notificando ouvintes reativos',
      () {
        int contadorNotificacoes = 0;
        void ouvinteTeste() => contadorNotificacoes++;

        // Vincula ouvinte temporário de testes
        controller.addListener(ouvinteTeste);

        try {
          // 1. Ativação do Modo Escuro
          controller.setDarkMode(true);
          expect(
            controller.isDarkMode,
            isTrue,
            reason: 'O modo escuro deve estar ativo.',
          );
          expect(
            controller.themeMode,
            equals(ThemeMode.dark),
            reason: 'O ThemeMode deve ser ThemeMode.dark.',
          );

          // 2. Ajuste do fator de escala da fonte
          const double novaEscalaFonte = 1.25;
          controller.setFontScale(novaEscalaFonte);
          expect(
            controller.fontScale,
            equals(novaEscalaFonte),
            reason: 'A escala de fonte deve ter sido alterada para 1.25.',
          );

          // 3. Desativação de notificações push
          controller.setPushNotifications(false);
          expect(
            controller.pushNotifications,
            isFalse,
            reason: 'As notificações push devem estar desligadas.',
          );

          // Asserção: Total de notificações reativas emitidas
          expect(
            contadorNotificacoes,
            equals(3),
            reason:
                'Cada mutação de estado deve notificar os widgets cadastrados.',
          );
        } finally {
          // Limpeza e restauração do estado inicial
          controller.removeListener(ouvinteTeste);
          controller.setDarkMode(false);
          controller.setFontScale(1.0);
          controller.setPushNotifications(true);
        }
      },
    );
  });
}
