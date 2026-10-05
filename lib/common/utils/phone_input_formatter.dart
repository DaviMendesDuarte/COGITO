import 'package:flutter/services.dart';

/// Formatador de entrada de texto para aplicar máscara de telefone brasileiro.
/// Suporta números fixos (10 dígitos: (XX) XXXX-XXXX) e celulares (11 dígitos: (XX) XXXXX-XXXX).
class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove todos os caracteres não numéricos
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Limita ao máximo de 11 dígitos (DDD + 9 dígitos)
    final limitedDigits = digitsOnly.length > 11
        ? digitsOnly.substring(0, 11)
        : digitsOnly;

    final StringBuffer buffer = StringBuffer();
    final int length = limitedDigits.length;

    // Formatação progressiva conforme o usuário digita
    if (length > 0) {
      buffer.write('(');
      buffer.write(limitedDigits.substring(0, length >= 2 ? 2 : length));

      if (length >= 2) {
        buffer.write(') ');
      }

      if (length > 2) {
        if (length <= 10) {
          // Telefone Fixo: (XX) XXXX-XXXX
          buffer.write(limitedDigits.substring(2, length >= 6 ? 6 : length));
          if (length > 6) {
            buffer.write('-');
            buffer.write(limitedDigits.substring(6, length));
          }
        } else {
          // Celular: (XX) XXXXX-XXXX
          buffer.write(limitedDigits.substring(2, 7));
          buffer.write('-');
          buffer.write(limitedDigits.substring(7, length));
        }
      }
    }

    final String formattedText = buffer.toString();

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
