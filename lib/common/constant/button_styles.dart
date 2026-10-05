import 'package:cogito/common/constant/app_colors.dart';
import 'package:flutter/material.dart';

/// Classe de estilos padronizados para botões do aplicativo.
class ButtonStyles {
  // Construtor privado para evitar instanciação.
  ButtonStyles._();

  /// Estilo de botão primário preenchido (ElevatedButton), com fundo azul e bordas arredondadas.
  static ButtonStyle primary = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primaryBlue,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(67)),
  );

  /// Estilo de botão secundário com contorno (OutlinedButton), com borda azul espessa.
  static ButtonStyle secondary = OutlinedButton.styleFrom(
    side: const BorderSide(color: AppColors.primaryBlue, width: 3.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(67)),
  );
}
