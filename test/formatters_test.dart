import 'package:cogito/common/utils/phone_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testes unitários para formatadores de texto e de telefone do COGITO.
void main() {
  group('Testes de Formatadores e Máscaras de Telefone', () {
    final formatter = TelefoneInputFormatter();

    test('Deve formatar telefone celular brasileiro com DDD (11 dígitos)', () {
      const input = '11987654321';
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: input,
          selection: TextSelection.collapsed(offset: input.length),
        ),
      );
      expect(result.text, equals('(11) 98765-4321'));
    });

    test('Deve formatar telefone fixo brasileiro com DDD (10 dígitos)', () {
      const input = '1134567890';
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: input,
          selection: TextSelection.collapsed(offset: input.length),
        ),
      );
      expect(result.text, equals('(11) 3456-7890'));
    });

    test('Deve truncar caracteres extras além de 11 dígitos', () {
      const input = '119876543219999';
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: input,
          selection: TextSelection.collapsed(offset: input.length),
        ),
      );
      expect(result.text, equals('(11) 98765-4321'));
    });
  });

  group('Testes de Sanitização Monetária', () {
    double converterTextoParaMoeda(String texto) {
      final limpo = texto
          .replaceAll('R\$', '')
          .replaceAll(' ', '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .trim();
      return double.tryParse(limpo) ?? 0.0;
    }

    test('Deve converter texto formatado em Real para double numérico', () {
      expect(converterTextoParaMoeda('R\$ 3.500,50'), equals(3500.50));
      expect(converterTextoParaMoeda('1.250,00'), equals(1250.00));
      expect(converterTextoParaMoeda('450,75'), equals(450.75));
      expect(converterTextoParaMoeda('0,00'), equals(0.0));
      expect(converterTextoParaMoeda('inválido'), equals(0.0));
    });
  });
}
