import 'package:cogito/services/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Central de tokens de cores do aplicativo COGITO.
/// Define paletas primárias, secundárias e métodos auxiliares para adequação visual aos modos Claro e Escuro.
class AppColors {
  // Construtor privado para impedir instanciação da classe utilitária.
  AppColors._();

  // Cores de marca principais
  static const Color primaryBlue = Color(0xFF142251);
  static const Color primaryOrange = Color(0xFFF5891D);
  static const Color primaryYellow = Color(0xFFFCAA17);

  // Cores secundárias e neutras
  static const Color secundaryBlue = Color(0xFF232E5C);

  /// Cor principal para textos legíveis (#1D1D1D) com alto contraste e elegância
  static const Color textPrimary = Color(0xFF1D1D1D);

  static const Color white = Color(0xFFFFFFFF);
  static const Color gray = Color(0xFFB0B0B0);

  // Cor padrão do plano de fundo da aplicação em modo claro
  static const Color backgroundColor = Color(0xFFF5F5F5);

  // =========================================================================
  // TOKENS DO TEMA ESCURO (Baseados na paleta: Navy Blue + Charcoal + Laranja)
  // =========================================================================

  /// Fundo principal do modo escuro (#15161A - Carvão profundo neutro)
  static const Color darkBackground = Color(0xFF15161A);

  /// Superfície de cards e containers elevados (#212227 - Superfície elevada elegante)
  static const Color darkCardColor = Color(0xFF212227);

  /// Cor de bordas suaves no modo escuro (#2E3038)
  static const Color darkBorderColor = Color(0xFF2E3038);

  /// Preenchimento de inputs e campos de texto no modo escuro (#282930)
  static const Color darkInputFill = Color(0xFF282930);

  /// Texto de alta legibilidade no modo escuro (#FFFFFF)
  static const Color darkTextPrimary = Color(0xFFFFFFFF);

  /// Texto secundário e legendas no modo escuro (#A0A5B5)
  static const Color darkTextSecondary = Color(0xFFA0A5B5);

  // Lista com as cores primárias do sistema
  static const List<Color> primaryColors = [
    primaryBlue,
    primaryOrange,
    primaryYellow,
  ];

  /// Verifica se a cor fornecida pertence à lista de cores primárias.
  static bool isPrimaryColor(Color color) {
    return primaryColors.contains(color);
  }

  /// Verifica se o tema escuro está ativado respeitando a preferência explícita do usuário
  /// ou o tema do sistema caso esteja configurado no modo automático.
  static bool isDarkMode(BuildContext context) {
    final settings = AppSettingsController.instance;
    if (settings.themeMode == ThemeMode.dark) return true;
    if (settings.themeMode == ThemeMode.light) return false;
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Retorna a cor de card dinâmica de acordo com o tema ativo (Escuro ou Claro).
  static Color getCardColor(BuildContext context) {
    return isDarkMode(context) ? darkCardColor : Colors.white;
  }

  /// Retorna a cor de fundo principal de tela de acordo com o tema ativo.
  static Color getBackgroundColor(BuildContext context) {
    return isDarkMode(context) ? darkBackground : backgroundColor;
  }

  /// Retorna a cor de destaque principal dinâmica (Laranja no modo Escuro e Azul no modo Claro).
  static Color getPrimaryAccent(BuildContext context) {
    return isDarkMode(context) ? primaryOrange : primaryBlue;
  }

  /// Retorna a cor da barra vertical de acentuação do card de saldo (Laranja no modo Escuro, Azul no Claro).
  static Color getAccentBarColor(BuildContext context) {
    return isDarkMode(context) ? primaryOrange : primaryBlue;
  }

  /// Retorna a cor de botões de ação e botões flutuantes principais (Laranja no modo Escuro, Azul no Claro).
  static Color getActionButtonColor(BuildContext context) {
    return isDarkMode(context) ? primaryOrange : primaryBlue;
  }

  /// Retorna a cor de fundo do card de Metas Financeiras (Laranja no modo Escuro idêntico à imagem de referência).
  static Color getMetasCardColor(BuildContext context) {
    return isDarkMode(context) ? primaryOrange : Colors.white;
  }

  /// Retorna a cor do título e textos do card de Metas Financeiras.
  static Color getMetasTextColor(BuildContext context) {
    return isDarkMode(context) ? Colors.white : primaryBlue;
  }

  /// Retorna a cor primária de texto ajustada ao contraste do tema.
  static Color getTextColor(BuildContext context) {
    return isDarkMode(context) ? darkTextPrimary : textPrimary;
  }

  /// Retorna a cor secundária para rótulos, subtítulos e textos informativos.
  static Color getSubtextColor(BuildContext context) {
    return isDarkMode(context) ? darkTextSecondary : Colors.grey.shade600;
  }

  /// Retorna a cor de contorno/borda da interface. Para atender ao requisito de não possuir
  /// contornos ao redor dos containers e cards, retorna [Colors.transparent].
  /// Para separações e divisões estruturais, utilize [getDividerColor].
  static Color getBorderColor(BuildContext context) {
    return Colors.transparent;
  }

  /// Retorna a cor determinada padronizada para separadores e divisórias estruturais da interface.
  static Color getDividerColor(BuildContext context) {
    return isDarkMode(context) ? const Color(0xFF2E3038) : const Color(0xFFE5E7EB);
  }

  /// Retorna a cor de preenchimento para campos de formulário e buscas.
  static Color getInputFillColor(BuildContext context) {
    return isDarkMode(context) ? darkInputFill : const Color(0xFFF2F4F7);
  }

  /// Estilo fixo e padronizado para a barra de status do sistema: fundo de cor azul primária (#142251) e ícones brancos.
  static const SystemUiOverlayStyle statusBarStyle = SystemUiOverlayStyle(
    statusBarColor: primaryBlue, // Fundo azul sólido permanente
    statusBarIconBrightness: Brightness.light, // Ícones brancos no Android
    statusBarBrightness: Brightness.dark, // Ícones brancos no iOS
  );

  /// Retorna o estilo da barra de status adaptado dinamicamente ao tema ativo (Laranja no modo escuro, Azul no modo claro).
  static SystemUiOverlayStyle getStatusBarStyle(BuildContext context) {
    return getOverlayStyleForBackground(getPrimaryAccent(context));
  }

  /// Retorna o estilo da barra de status com base na cor de fundo fornecida e ícones brancos.
  static SystemUiOverlayStyle getOverlayStyleForBackground([Color? color]) {
    final Color barColor = color ?? primaryBlue;
    return SystemUiOverlayStyle(
      statusBarColor: barColor,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );
  }
}
