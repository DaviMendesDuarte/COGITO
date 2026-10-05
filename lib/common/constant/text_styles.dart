import 'package:cogito/common/constant/app_colors.dart';
import 'package:flutter/material.dart';

/// Central de definições tipográficas do aplicativo COGITO.
/// Provê estilos padronizados utilizando a fonte Poppins (Regular w400 e Bold w700)
/// em estrita conformidade com as especificações do Figma.
class TextStyles {
  // Construtor privado para evitar instanciação da classe utilitária.
  TextStyles._();

  /// Família de fonte padrão Poppins utilizada em toda a aplicação COGITO.
  static const String fontFamily = 'Poppins';

  /// Retorna o estilo Poppins Regular padronizado (FontWeight.w400 / Normal).
  ///
  /// Parâmetros:
  /// - [fontSize]: Tamanho da fonte em pixels (padrão 14).
  /// - [color]: Cor do texto (padrão [AppColors.textPrimary]).
  /// - [fontWeight]: Peso tipográfico (padrão [FontWeight.w400]).
  /// - [letterSpacing]: Espaçamento entre letras opcional.
  /// - [height]: Altura da linha opcional.
  static TextStyle poppinsRegular({
    double fontSize = 14,
    Color color = AppColors.textPrimary,
    FontWeight fontWeight = FontWeight.w400,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Retorna o estilo Poppins Bold padronizado conforme especificação do Figma (FontWeight.w700 / Bold).
  ///
  /// Parâmetros:
  /// - [fontSize]: Tamanho da fonte em pixels (padrão 14).
  /// - [color]: Cor do texto (padrão [AppColors.textPrimary]).
  /// - [fontWeight]: Peso tipográfico (padrão [FontWeight.w700] conforme o design system).
  /// - [letterSpacing]: Espaçamento entre letras opcional.
  /// - [height]: Altura da linha opcional.
  static TextStyle poppinsBold({
    double fontSize = 14,
    Color color = AppColors.textPrimary,
    FontWeight fontWeight = FontWeight.w700,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Retorna o estilo Poppins Extra Bold para casos específicos que demandem peso superior (w800/w900).
  ///
  /// Parâmetros:
  /// - [fontSize]: Tamanho da fonte em pixels (padrão 14).
  /// - [color]: Cor do texto (padrão [AppColors.textPrimary]).
  /// - [letterSpacing]: Espaçamento entre letras opcional.
  /// - [height]: Altura da linha opcional.
  static TextStyle poppinsExtraBold({
    double fontSize = 14,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // --- Estilos para as telas de Onboarding e Gerais (Constantes para uso em widgets const) ---

  /// Título em destaque para a tela de boas-vindas / onboarding.
  static const TextStyle welcomeTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryBlue,
  );

  /// Texto descritivo para as telas de onboarding.
  static const TextStyle welcomeDescription = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    color: Color.fromARGB(255, 75, 75, 75),
    fontWeight: FontWeight.bold,
  );

  /// Subtítulo auxiliar de instrução ou navegação.
  static const TextStyle subtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    color: Colors.grey,
  );

  /// Texto para botões primários (brancos).
  static const TextStyle buttonPrimary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    color: AppColors.white,
  );

  /// Texto para botões secundários (azul escuro e negrito).
  static const TextStyle buttonSecondary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    color: AppColors.primaryBlue,
    fontWeight: FontWeight.bold,
  );

  /// Texto pequeno de rodapé ou copyright.
  static const TextStyle footer = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    color: Colors.grey,
  );
}
