import 'package:cogito/features/conrado/services/conrado_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
/// TESTE 3: ASSISTENTE CONRADO - RESTRIÇÃO TEMÁTICA EXCLUSIVA PARA FINANÇAS
/// ============================================================================
///
/// Este teste unitário valida a política rígida de escopo temático do assistente.
///
/// Regra de Negócio:
/// - O CONRADO é uma inteligência especializada exclusivamente no gerenciamento
///   financeiro pessoal e orçamentário.
/// - Qualquer questionamento fora desse contexto (esportes, culinária, etc.)
///   deve ser educadamente recusado com o aviso institucional de foco em finanças.
void main() {
  // Inicialização das ligações de teste do framework Flutter
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CONRADO - Restrição Temática de Escopo', () {
    // Instância do serviço de IA do assistente CONRADO
    final conradoService = ConradoApiService();

    /// Testa se o assistente recusa perguntas que fogem do âmbito de finanças.
    test(
      'Deve restringir o escopo temático recusando perguntas alheias a finanças pessoais',
      () async {
        // Pergunta desvinculada do universo financeiro
        const perguntaForaDeEscopo = 'Qual time venceu a partida de basquete?';

        // Execução da consulta
        final resposta = await conradoService.sendMessage(perguntaForaDeEscopo);

        // Asserção 1: Presença do cabeçalho de aviso
        expect(
          resposta.contains('Aviso do CONRADO'),
          isTrue,
          reason:
              'Deve exibir o cabeçalho de aviso sobre a restrição de domínio.',
        );

        // Asserção 2: Declaração de exclusividade temático-financeira
        expect(
          resposta.contains('exclusivamente'),
          isTrue,
          reason:
              'Deve declarar expressamente que atua com exclusividade em finanças.',
        );

        // Asserção 3: Citação do escopo do aplicativo COGITO
        expect(
          resposta.contains('Finanças Pessoais'),
          isTrue,
          reason:
              'Deve reforçar a área de atuação do assistente dentro do COGITO.',
        );
      },
    );
  });
}
