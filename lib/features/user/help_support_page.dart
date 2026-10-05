import 'package:cogito/common/constant/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tela de Ajuda e Suporte do aplicativo COGITO.
/// Disponibiliza o envio direto de e-mail para cogito.tcc@gmail.com e uma lista expansível de Perguntas Frequentes (FAQ).
class AjudaSuportePage extends StatelessWidget {
  const AjudaSuportePage({super.key});

  /// Endereço oficial de e-mail de suporte do projeto COGITO.
  static const String _emailSuporte = 'cogito.tcc@gmail.com';

  /// Lista das 8 perguntas e respostas frequentes requeridas pelo projeto.
  static const List<Map<String, String>> _faqs = [
    {
      'pergunta': 'Como adicionar uma nova conta bancária?',
      'resposta':
          'Para vincular uma nova conta bancária, acesse a aba "Perfil", clique no card "Conta Bancária" ou na opção "Vincular Conta Bancária". Preencha o nome do banco, agência, número da conta, tipo de conta (Corrente ou Poupança) e o titular, e confirme o salvamento.',
    },
    {
      'pergunta': 'Como excluir uma transação?',
      'resposta':
          'Acesse a aba "Finanças" e vá para a seção "Extrato" > "Transações". Localize a movimentação desejada e deslize o card para o lado esquerdo ou toque no ícone de lixeira para excluir permanentemente a transação.',
    },
    {
      'pergunta': 'Como alterar meu orçamento mensal?',
      'resposta':
          'Vá até a aba "Finanças" e selecione a seção "Orçamentos". Toque no botão de edição do orçamento que deseja ajustar e insira o novo nome ou limite financeiro mensal desejado. As alterações são atualizadas em tempo real.',
    },
    {
      'pergunta': 'O que é a categorização automática por IA?',
      'resposta':
          'A categorização por IA utiliza o assistente CONRADO para ler a descrição das suas despesas e receitas e classificá-las automaticamente em categorias como Alimentação, Transporte, Moradia ou Lazer, economizando seu tempo.',
    },
    {
      'pergunta': 'Como funcionam os orçamentos e metas financeiras?',
      'resposta':
          'Os orçamentos permitem definir limites de gastos por categoria no mês, enquanto as metas financeiras ("Caixinhas") organizam reservatórios de economia para objetivos específicos com aportes e acompanhamento de progresso.',
    },
    {
      'pergunta': 'Meus dados estão seguros?',
      'resposta':
          'Sim! O COGITO utiliza infraestrutura em nuvem de alta segurança com criptografia SSL/TLS em trânsito e em repouso. Suas informações pessoais e financeiras são armazenadas com rígidos protocolos de segurança e privacidade.',
    },
  ];

  /// Abre o aplicativo nativo de e-mail com destinatário pré-preenchido para [cogito.tcc@gmail.com].
  Future<void> _enviarEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _emailSuporte,
      queryParameters: {
        'subject': 'Suporte COGITO - Dúvida / Atendimento',
        'body': 'Olá equipe COGITO,\n\nPreciso de suporte referente a:\n',
      },
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        // Tenta abrir o link diretamente caso canLaunchUrl retorne falso em alguns emuladores
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'E-mail para suporte: $_emailSuporte (copiado ou indisponível no cliente de e-mail).',
          ),
          backgroundColor: AppColors.primaryBlue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.getStatusBarStyle(context),
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: AppColors.getPrimaryAccent(context),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Ajuda e Suporte',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card do Canal de Atendimento por E-mail
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.getCardColor(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.getBorderColor(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        color: AppColors.primaryOrange,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Precisa de suporte personalizado?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nossa equipe está pronta para responder suas dúvidas e receber suas sugestões.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.getSubtextColor(context)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _enviarEmail(context),
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Enviar E-mail para cogito.tcc@gmail.com',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.getActionButtonColor(context),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Título de Seção FAQ
              Row(
                children: [
                  Icon(
                    Icons.quiz_outlined,
                    color: AppColors.getPrimaryAccent(context),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Perguntas Frequentes (FAQ)',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Lista de Cards Expansíveis de FAQ
              ..._faqs.map((faq) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  color: AppColors.getCardColor(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: AppColors.getBorderColor(context)),
                  ),
                  child: ExpansionTile(
                    iconColor: AppColors.getPrimaryAccent(context),
                    collapsedIconColor: AppColors.getPrimaryAccent(context),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      faq['pergunta']!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.getTextColor(context),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          faq['resposta']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.getSubtextColor(context),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
