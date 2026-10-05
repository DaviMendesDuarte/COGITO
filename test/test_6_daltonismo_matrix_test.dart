import 'package:cogito/services/app_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
/// TESTE 6: ACESSIBILIDADE VISUAL - MATRIZES ESPECTRAIS DE DALTONISMO
/// ============================================================================
///
/// Este teste unitário valida a geração precisa de matrizes matemáticas 4x5
/// (20 coeficientes de cor) para filtros de acessibilidade a usuários daltônicos.
///
/// Regra de Negócio:
/// - Modo Protanopia: Matriz de 20 coeficientes otimizada para deficiência no espectro vermelho.
/// - Modo Deuteranopia: Matriz de 20 coeficientes otimizada para deficiência no espectro verde.
/// - Modo Tritanopia: Matriz de 20 coeficientes otimizada para deficiência no espectro azul.
/// - Modo Desativado: Deve retornar valor nulo (sem processamento matricial).
void main() {
  group('Acessibilidade Visual - Filtros Cromáticos para Daltonismo', () {
    // Instância singleton do controlador de configurações
    final controller = AppSettingsController.instance;

    /// Testa a geração das matrizes cromáticas 4x5 de daltonismo.
    test(
      'Deve gerar matrizes cromáticas 4x5 exatas para filtros de Protanopia, Deuteranopia e Tritanopia',
      () {
        try {
          // 1. Validação do Modo Protanopia (Vermelho)
          controller.setDaltonismoMode('Protanopia');
          expect(controller.daltonismoMode, equals('Protanopia'));
          final matrizProtan = controller.daltonismoColorMatrix;
          expect(
            matrizProtan,
            isNotNull,
            reason: 'A matriz de Protanopia não pode ser nula.',
          );
          expect(
            matrizProtan!.length,
            equals(20),
            reason: 'A matriz para ColorFiltered deve conter 20 elementos.',
          );
          expect(
            matrizProtan[0],
            closeTo(0.56667, 0.00001),
            reason:
                'O primeiro coeficiente deve corresponder ao espectro Protanopia.',
          );

          // 2. Validação do Modo Deuteranopia (Verde)
          controller.setDaltonismoMode('Deuteranopia');
          expect(controller.daltonismoMode, equals('Deuteranopia'));
          final matrizDeuteran = controller.daltonismoColorMatrix;
          expect(matrizDeuteran, isNotNull);
          expect(matrizDeuteran!.length, equals(20));
          expect(
            matrizDeuteran[0],
            closeTo(0.62500, 0.00001),
            reason:
                'O primeiro coeficiente deve corresponder ao espectro Deuteranopia.',
          );

          // 3. Validação do Modo Tritanopia (Azul)
          controller.setDaltonismoMode('Tritanopia');
          expect(controller.daltonismoMode, equals('Tritanopia'));
          final matrizTritan = controller.daltonismoColorMatrix;
          expect(matrizTritan, isNotNull);
          expect(matrizTritan!.length, equals(20));
          expect(
            matrizTritan[0],
            closeTo(0.95000, 0.00001),
            reason:
                'O primeiro coeficiente deve corresponder ao espectro Tritanopia.',
          );

          // 4. Validação do Modo Desativado
          controller.setDaltonismoMode('Desativado');
          expect(controller.daltonismoMode, equals('Desativado'));
          expect(
            controller.daltonismoColorMatrix,
            isNull,
            reason:
                'Quando o modo está desativado, o getter deve retornar null.',
          );
        } finally {
          // Limpeza e restauração do padrão do app
          controller.setDaltonismoMode('Desativado');
        }
      },
    );
  });
}
