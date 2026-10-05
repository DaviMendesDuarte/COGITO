import 'dart:convert';
import 'package:flutter/material.dart';

/// Utilitário responsável pelo processo de gerenciamento, criptografia e exibição
/// da Foto de Perfil padrão (`default_00.png`) no aplicativo COGITO.
/// A opção de alteração da foto foi removida conforme a especificação do sistema,
/// padronizando a foto institucional padrão em todas as telas.
class ProfilePhotoHelper {
  ProfilePhotoHelper._();

  /// Caminho relativo do asset da foto de perfil padrão oficial do COGITO.
  static const String caminhoFotoPadrao =
      'assets/images/default_pics/default_00.png';

  /// Prefixo identificador de segurança do algoritmo de integridade da foto.
  static const String _prefixoEncriptado = 'enc_v1_';

  /// Sal com assinatura secreta do sistema COGITO para hashing.
  static const String _saltChave = 'COGITO_SECURE_KEY_2026_AVATAR';

  /// Criptografa o identificador ou dados da foto em um hash Base64 assinado.
  ///
  /// Parâmetros:
  /// - [avatarId]: Identificador string da foto a ser codificada.
  ///
  /// Retorno:
  /// - [String]: String codificada com o prefixo seguro do aplicativo.
  static String encriptarFoto(String avatarId) {
    final String raw = '$_saltChave:$avatarId';
    final List<int> bytes = utf8.encode(raw);
    final String base64Str = base64Encode(bytes);
    return '$_prefixoEncriptado$base64Str';
  }

  /// Descriptografa a string codificada e valida a assinatura interna do sistema.
  ///
  /// Parâmetros:
  /// - [codigoEncriptado]: String contendo o identificador encriptado.
  ///
  /// Retorno:
  /// - [String?]: Identificador decodificado ou nulo em caso de falha.
  static String? decriptarFoto(String? codigoEncriptado) {
    if (codigoEncriptado == null ||
        !codigoEncriptado.startsWith(_prefixoEncriptado)) {
      return null;
    }
    try {
      final String base64Clean = codigoEncriptado.replaceFirst(
        _prefixoEncriptado,
        '',
      );
      final List<int> bytes = base64Decode(base64Clean);
      final String decoded = utf8.decode(bytes);
      if (decoded.startsWith('$_saltChave:')) {
        return decoded.substring('$_saltChave:'.length);
      }
    } catch (e) {
      debugPrint('Erro ao descriptografar foto de perfil: $e');
    }
    return null;
  }

  /// Constrói o Widget de Avatar de Perfil exibindo a foto padrão `default_00.png`.
  /// A opção de troca de foto e o selo de edição de câmera foram desativados.
  ///
  /// Parâmetros:
  /// - [codigoEncriptado]: Identificador criptografado (mantido para compatibilidade).
  /// - [radius]: Raio do círculo do avatar em pixels (padrão 28).
  /// - [onTap]: Callback opcional de clique (não exibe troca de foto).
  /// - [showEditBadge]: Mantido por compatibilidade de assinatura, sempre forçado para falso.
  ///
  /// Retorno:
  /// - [Widget]: Componente circular elegante renderizando a foto padrão `default_00.png`.
  static Widget buildProfileAvatar({
    String? codigoEncriptado,
    double radius = 28,
    VoidCallback? onTap,
    bool showEditBadge = false,
  }) {
    // Conteúdo principal do avatar: container branco elegante com ícone de usuário azul clássico
    final Widget avatarContent = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: const Color(0xFF142251),
          size: radius * 1.25,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatarContent);
    }

    return avatarContent;
  }
}
