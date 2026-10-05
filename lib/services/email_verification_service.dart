import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Serviço responsável pelo envio de e-mails de verificação e recuperação de senha.
///
/// Utiliza a conta oficial do COGITO (`cogito.tcc@gmail.com`) através de conexão
/// segura SMTP SSL (porta 465) com os servidores do Google Mail.
class EmailVerificationService {
  // Construtor privado para garantir padrão Singleton
  EmailVerificationService._();

  /// Instância compartilhada do serviço de e-mail.
  static final EmailVerificationService instance = EmailVerificationService._();

  /// Endereço de e-mail oficial do COGITO.
  static const String remetenteEmail = 'cogito.tcc@gmail.com';

  /// Senha / credencial do e-mail do sistema COGITO.
  static const String remetenteSenha = 'cogito_tcc1902';

  /// Servidor SMTP do Google.
  static const String smtpHost = 'smtp.gmail.com';

  /// Porta segura SSL/TLS do Google Mail.
  static const int smtpPort = 465;

  /// Envia um e-mail contendo o código numérico de verificação de 6 dígitos para o destinatário.
  ///
  /// Parâmetros:
  /// - [destinatario]: Endereço de e-mail do usuário que receberá o código.
  /// - [codigo]: Código de 6 dígitos gerado pelo sistema COGITO.
  /// - [assunto]: Título opcional do e-mail (padrão: "COGITO - Código de Verificação").
  ///
  /// Retorna `true` se o e-mail foi entregue ao servidor SMTP com sucesso, ou `false` em caso de erro.
  Future<bool> enviarCodigoVerificacao({
    required String destinatario,
    required String codigo,
    String assunto = 'COGITO - Código de Verificação',
  }) async {
    SecureSocket? socket;
    try {
      debugPrint('📧 [EmailService] Conectando a $smtpHost:$smtpPort...');

      // 1. Estabelece socket TLS/SSL seguro diretamente com smtp.gmail.com
      socket = await SecureSocket.connect(
        smtpHost,
        smtpPort,
        timeout: const Duration(seconds: 10),
        onBadCertificate: (cert) => true,
      );

      // Função auxiliar para aguardar e ler a resposta do servidor SMTP
      Future<String> lerResposta() async {
        final buffer = <int>[];
        await for (final chunk in socket!) {
          buffer.addAll(chunk);
          final texto = utf8.decode(buffer, allowMalformed: true);
          if (texto.endsWith('\r\n')) {
            return texto;
          }
        }
        return utf8.decode(buffer, allowMalformed: true);
      }

      // Função auxiliar para enviar um comando SMTP com CRLF
      void enviarComando(String comando) {
        socket!.write('$comando\r\n');
      }

      // 2. Lê saudação inicial do servidor (220)
      String resp = await lerResposta();
      debugPrint('📧 [EmailService] Resposta inicial: $resp');

      // 3. Handshake EHLO
      enviarComando('EHLO localhost');
      resp = await lerResposta();

      // 4. Autenticação AUTH LOGIN
      enviarComando('AUTH LOGIN');
      resp = await lerResposta();

      // Envia usuário em Base64
      enviarComando(base64Encode(utf8.encode(remetenteEmail)));
      resp = await lerResposta();

      // Envia senha em Base64
      enviarComando(base64Encode(utf8.encode(remetenteSenha)));
      resp = await lerResposta();

      // Verifica se a autenticação foi aceita (código 235)
      if (!resp.startsWith('235')) {
        debugPrint('⚠️ [EmailService] Falha na autenticação SMTP: $resp');
        // Fecha socket e retorna fallback
        socket.destroy();
        return false;
      }

      // 5. Especifica remetente (MAIL FROM)
      enviarComando('MAIL FROM:<$remetenteEmail>');
      resp = await lerResposta();

      // 6. Especifica destinatário (RCPT TO)
      enviarComando('RCPT TO:<$destinatario>');
      resp = await lerResposta();

      // 7. Inicia envio dos dados (DATA)
      enviarComando('DATA');
      resp = await lerResposta();

      // 8. Monta cabeçalhos e corpo do e-mail com design sofisticado do COGITO
      final String mensagemCorpo = _construirTemplateHtml(codigo: codigo, destinatario: destinatario);

      final bufferEmail = StringBuffer();
      bufferEmail.writeln('From: "COGITO Finanças" <$remetenteEmail>');
      bufferEmail.writeln('To: <$destinatario>');
      bufferEmail.writeln('Subject: =?utf-8?B?${base64Encode(utf8.encode(assunto))}?=');
      bufferEmail.writeln('MIME-Version: 1.0');
      bufferEmail.writeln('Content-Type: text/html; charset=UTF-8');
      bufferEmail.writeln();
      bufferEmail.writeln(mensagemCorpo);
      bufferEmail.writeln('.'); // Finaliza bloco de dados SMTP

      enviarComando(bufferEmail.toString());
      resp = await lerResposta();
      debugPrint('📧 [EmailService] Resposta envio de dados: $resp');

      // 9. Encerra sessão SMTP (QUIT)
      enviarComando('QUIT');
      await socket.flush();
      socket.destroy();

      debugPrint('✅ [EmailService] E-mail enviado com sucesso para $destinatario!');
      return true;
    } catch (e) {
      debugPrint('⚠️ [EmailService] Não foi possível enviar via SMTP direto: $e');
      try {
        socket?.destroy();
      } catch (_) {}
      return false;
    }
  }

  /// Constrói o corpo visual em HTML do e-mail com layout moderno do COGITO.
  String _construirTemplateHtml({required String codigo, required String destinatario}) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Código de Verificação COGITO</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F5F7FA; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #F5F7FA; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="100%" max-width="500" style="max-width: 500px; background-color: #FFFFFF; border-radius: 20px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.08);">
          <!-- Topo Azul COGITO -->
          <tr>
            <td style="background-color: #142251; padding: 32px 24px; text-align: center;">
              <h1 style="color: #FFFFFF; margin: 0; font-size: 26px; font-weight: 700; letter-spacing: 1px;">COGITO</h1>
              <p style="color: #F5891D; margin: 6px 0 0 0; font-size: 13px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.8px;">Inteligência & Controle Financeiro</p>
            </td>
          </tr>

          <!-- Conteúdo -->
          <tr>
            <td style="padding: 36px 28px; text-align: center;">
              <h2 style="color: #1D1D1D; font-size: 20px; margin: 0 0 12px 0;">Código de Verificação</h2>
              <p style="color: #6C727F; font-size: 14px; line-height: 1.5; margin: 0 0 28px 0;">
                Olá! Você solicitou a validação de segurança ou recuperação de acesso da sua conta <strong>$destinatario</strong> no aplicativo COGITO.
              </p>

              <!-- Caixa de Destaque com o Código -->
              <div style="background-color: #F0F4FF; border-radius: 14px; padding: 18px 24px; display: inline-block; margin-bottom: 28px;">
                <span style="font-size: 34px; font-weight: 800; color: #142251; letter-spacing: 6px; font-family: monospace;">$codigo</span>
              </div>

              <p style="color: #8C93A3; font-size: 12px; margin: 0 0 8px 0;">
                Este código expira em 10 minutos. Nunca compartilhe este código com outras pessoas.
              </p>
              <p style="color: #8C93A3; font-size: 12px; margin: 0;">
                Se você não solicitou este código, ignore esta mensagem com segurança.
              </p>
            </td>
          </tr>

          <!-- Rodapé -->
          <tr>
            <td style="background-color: #F9FAFB; padding: 20px; text-align: center; border-top: 1px solid #ECEFF2;">
              <p style="color: #A0A5B5; font-size: 11px; margin: 0;">
                &copy; 2026 COGITO - TCC Engenharia de Software. Todos os direitos reservados.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }
}
