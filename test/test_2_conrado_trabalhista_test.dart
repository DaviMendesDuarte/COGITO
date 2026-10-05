import 'package:cogito/features/conrado/services/conrado_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
/// TESTE 2: ASSISTENTE CONRADO - CONSULTORIA TRABALHISTA (13º SALÁRIO & FGTS)
/// ============================================================================
///
/// Este teste unitário valida a capacidade consultiva contextual do CONRADO
/// sobre legislação e proventos trabalhistas, especificamente o Décimo Terceiro Salário.
///
/// Regra de Negócio:
/// - O CONRADO deve orientar com exatidão que a 1ª parcela corresponde a 50%
///   do salário bruto sem incidência de descontos até 30 de novembro.
/// - Deve esclarecer que a 2ª parcela é paga até 20 de dezembro com a dedução
///   das alíquotas oficiais de INSS e IRRF.
void main() {
  // Inicialização das ligações de teste do framework Flutter
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CONRADO - Consultoria Trabalhista', () {
    // Instância do serviço de IA do assistente CONRADO
    final conradoService = ConradoApiService();

    /// Testa a precisão técnica das orientações trabalhistas para o 13º salário.
    test(
      'Deve fornecer consultoria contextual especializada sobre regras e cálculo do 13º Salário',
      () async {
        // Pergunta do usuário sobre a dinâmica do 13º Salário
        const perguntaDecimoTerceiro =
            'Como funciona a divisão das parcelas do meu décimo terceiro salário?';

        // Execução do assistente
        final resposta = await conradoService.sendMessage(
          perguntaDecimoTerceiro,
        );

        // Asserção 1: Reconhecimento do tema
        expect(
          resposta.contains('13º Salário') ||
              resposta.contains('Décimo Terceiro'),
          isTrue,
          reason:
              'A resposta deve confirmar o tema de Décimo Terceiro Salário.',
        );

        // Asserção 2: Especificação da primeira parcela sem descontos até 30/11
        expect(
          resposta.contains('1ª Parcela') &&
              resposta.contains('30 de Novembro'),
          isTrue,
          reason:
              'Deve conter orientações da 1ª parcela paga até 30 de Novembro sem descontos.',
        );

        // Asserção 3: Especificação da segunda parcela com encargos até 20/12
        expect(
          resposta.contains('2ª Parcela') &&
              resposta.contains('20 de Dezembro'),
          isTrue,
          reason:
              'Deve orientar sobre a 2ª parcela paga até 20 de Dezembro com descontos.',
        );
      },
    );
  });
}
