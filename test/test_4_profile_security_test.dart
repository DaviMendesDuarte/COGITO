import 'package:cogito/common/utils/profile_photo_helper.dart';
import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
/// TESTE 4: SEGURANÇA DO PERFIL - CRIPTOGRAFIA E ASSINATURA DO AVATAR
/// ============================================================================
///
/// Este teste unitário valida os mecanismos criptográficos de proteção da imagem
/// de perfil padrão do usuário na classe [ProfilePhotoHelper].
///
/// Regra de Negócio:
/// - O identificador do avatar deve ser assinado com o salt secreto do COGITO
///   (`COGITO_SECURE_KEY_2026_AVATAR`) e codificado com o prefixo de versão `enc_v1_`.
/// - A descriptografia de identificadores válidos deve recompor o nome original.
/// - Tentativas de adulteração, hashes corrompidos ou nulos devem ser rejeitados com `null`.
void main() {
  group('Perfil do Usuário - Segurança e Assinatura Criptográfica', () {
    /// Testa a criptografia reversível de identificadores e resistência a adulterações.
    test(
      'Deve criptografar e descriptografar identificador de foto com salt e validar integridade',
      () {
        // Identificador oficial da foto de perfil padrão
        const avatarOriginalId = 'default_00.png';

        // 1. Criptografa o identificador
        final String codigoEncriptado = ProfilePhotoHelper.encriptarFoto(
          avatarOriginalId,
        );

        // Asserção 1: Formato correto com prefixo enc_v1_
        expect(
          codigoEncriptado.startsWith('enc_v1_'),
          isTrue,
          reason: 'O hash gerado deve conter o prefixo oficial enc_v1_.',
        );

        // 2. Descriptografa com sucesso e valida consistência do dado
        final String? avatarDecodificado = ProfilePhotoHelper.decriptarFoto(
          codigoEncriptado,
        );
        expect(
          avatarDecodificado,
          equals(avatarOriginalId),
          reason:
              'O identificador decodificado deve coincidir perfeitamente com o original.',
        );

        // 3. Teste de resiliência: strings adulteradas ou nulas devem ser rejeitadas
        final String? resultadoInvalido = ProfilePhotoHelper.decriptarFoto(
          'enc_v1_hashCorrompidoOuFalso123',
        );
        expect(
          resultadoInvalido,
          isNull,
          reason:
              'Assinaturas sem o salt legítimo do COGITO devem ser rejeitadas como null.',
        );

        final String? resultadoNulo = ProfilePhotoHelper.decriptarFoto(null);
        expect(
          resultadoNulo,
          isNull,
          reason: 'Entrada nula deve resultar em retorno nulo seguro.',
        );
      },
    );
  });
}
