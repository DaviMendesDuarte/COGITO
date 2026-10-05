import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Serviço responsável pelo gerenciamento de autenticação biométrica (impressão digital)
/// e detecção de ambiente (dispositivo físico real vs. emulador).
class BiometricService {
  /// Instância singleton do LocalAuthentication.
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Instância do DeviceInfoPlugin para inspecionar hardware do dispositivo.
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Verifica se o aplicativo está rodando em um dispositivo físico real (NÃO é emulador).
  ///
  /// Retorna `true` se for um aparelho físico (Android ou iOS) e `false` se for um emulador.
  Future<bool> isDispositivoFisico() async {
    try {
      if (kIsWeb) return false;

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Verifica se a flag isPhysicalDevice do Android é verdadeira
        return androidInfo.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Verifica se a flag isPhysicalDevice do iOS é verdadeira
        return iosInfo.isPhysicalDevice;
      }
      return false;
    } catch (e) {
      debugPrint('Erro ao verificar hardware do dispositivo: $e');
      return false;
    }
  }

  /// Verifica se o dispositivo suporta autenticação biométrica e possui biometrias cadastradas.
  ///
  /// Retorna `true` se a biometria puder ser utilizada.
  Future<bool> podeUsarBiometria() async {
    try {
      final bool canAuthenticateWithBiometrics =
          await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final List<BiometricType> availableBiometrics = await _localAuth
          .getAvailableBiometrics();

      return (canAuthenticateWithBiometrics || isDeviceSupported) &&
          availableBiometrics.isNotEmpty;
    } catch (e) {
      debugPrint('Erro ao checar suporte a biometria: $e');
      return false;
    }
  }

  /// Solicita a autenticação por Impressão Digital / Biometria Nativa do sistema operacional.
  ///
  /// Parâmetros:
  /// - [motivo]: Mensagem de justificativa exibida no modal nativo de biometria.
  ///
  /// Retorna `true` se a impressão digital for confirmada com sucesso.
  Future<bool> autenticarComImpressaoDigital({
    String motivo = 'Confirme sua impressão digital para entrar no COGITO',
  }) async {
    try {
      // Executa o prompt nativo do Android/iOS para leitura de impressão digital
      final bool autenticado = await _localAuth.authenticate(
        localizedReason: motivo,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
      return autenticado;
    } on PlatformException catch (e) {
      debugPrint('Erro na leitura de impressão digital nativa: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Erro inesperado na autenticação biométrica: $e');
      return false;
    }
  }
}
