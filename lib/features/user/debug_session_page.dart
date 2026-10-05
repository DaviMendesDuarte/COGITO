import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/services/debug_mock_service.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tela dedicada à Sessão de Debug, Testes e Ferramentas do Desenvolvedor do aplicativo COGITO.
///
/// Permite ao desenvolvedor ou avaliador:
/// - Alternar o Modo Mock (preenchimento automático com dados fictícios).
/// - Injetar transações de teste no Cloud Firestore (+R$ 10 Receita, -R$ 10 Despesa).
/// - Disparar notificações de teste pré-configuradas e personalizadas para o Firebase.
/// - Limpar notificações armazenadas.
class DebugSessionPage extends StatefulWidget {
  /// Identificador do usuário para envio e manipulação dos dados de teste no Firestore.
  final String uid;

  /// Construtor da página de debug.
  const DebugSessionPage({super.key, required this.uid});

  @override
  State<DebugSessionPage> createState() => _DebugSessionPageState();
}

class _DebugSessionPageState extends State<DebugSessionPage> {
  /// Instância do serviço Firebase Firestore para operações de depuração.
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  /// Exibe um modal interativo para envio de notificação de teste personalizada ao Cloud Firestore.
  void _exibirDialogoEnviarNotificacaoPersonalizada(String uid) {
    final tituloCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String categoria = 'Sistema';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.add_alert_rounded, color: AppColors.getPrimaryAccent(context)),
              const SizedBox(width: 8),
              const Text(
                'Nova Notificação Teste',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tituloCtrl,
                  decoration: InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: msgCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Mensagem',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: categoria,
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Sistema', child: Text('Sistema')),
                    DropdownMenuItem(
                      value: 'IA Financeira',
                      child: Text('IA Financeira'),
                    ),
                    DropdownMenuItem(value: 'Metas', child: Text('Metas')),
                    DropdownMenuItem(
                      value: 'Segurança',
                      child: Text('Segurança'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => categoria = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final t = tituloCtrl.text.trim();
                final m = msgCtrl.text.trim();
                if (t.isNotEmpty && m.isNotEmpty) {
                  Navigator.pop(ctx);
                  await _firestoreService.criarNotificacao(
                    idCliente: uid,
                    titulo: t,
                    mensagem: m,
                    categoria: categoria,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Notificação personalizada disparada com sucesso!',
                        ),
                        backgroundColor: AppColors.getPrimaryAccent(context),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getPrimaryAccent(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Disparar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMockAtivo = DebugMockService.instance.modoMockAtivo;
    final primaryAccent = AppColors.getPrimaryAccent(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.getStatusBarStyle(context),
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: primaryAccent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Sessão de Debug & Testes',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===============================================================
              // 1. MODO MOCK (DEBUG MOCK SERVICE - DADOS FICTÍCIOS)
              // ===============================================================
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.data_exploration_outlined,
                            color: isMockAtivo
                                ? AppColors.primaryOrange
                                : primaryAccent,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Modo Mock (Dados Fictícios)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: primaryAccent,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isMockAtivo
                                  ? AppColors.primaryOrange
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isMockAtivo ? 'MOCK ATIVO' : 'FIREBASE REAL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isMockAtivo ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Preenche instantaneamente todo o aplicativo com dados fictícios realistas (Dashboard, Finanças, Contas Bancárias, Metas, Chats do CONRADO e Perfil).',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getSubtextColor(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          isMockAtivo
                              ? 'Desativar Dados Fictícios'
                              : 'Ativar Dados Fictícios (Mock)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isMockAtivo
                                ? AppColors.primaryOrange
                                : primaryAccent,
                          ),
                        ),
                        subtitle: Text(
                          isMockAtivo
                              ? 'Atualmente exibindo: Lucas Mendes Ferreira (R\$ 3.820,50)'
                              : 'Atualmente conectado ao banco de dados Firestore real.',
                          style: const TextStyle(fontSize: 11),
                        ),
                        activeThumbColor: AppColors.primaryOrange,
                        activeTrackColor: AppColors.primaryOrange.withValues(alpha: 0.4),
                        value: isMockAtivo,
                        onChanged: (bool valor) {
                          setState(() {
                            DebugMockService.instance.setModoMock(valor);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                valor
                                    ? 'Modo Mock ATIVADO! Perfil, Finanças e CONRADO preenchidos com dados fictícios.'
                                    : 'Modo Mock DESATIVADO. Conexão real com Firestore restaurada.',
                              ),
                              backgroundColor: valor
                                  ? AppColors.primaryOrange
                                  : primaryAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ===============================================================
              // 2. OPERAÇÕES DE TESTE DE TRANSAÇÕES
              // ===============================================================
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transações de Teste (Firebase Firestore)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Insira créditos ou débitos rápidos de teste na conta conectada:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getSubtextColor(context),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _firestoreService.executarOperacaoDebug10Reais(
                                  idCliente: widget.uid,
                                  titulo: 'Depósito Teste Debug (+10)',
                                  categoria: 'Receita',
                                  adicionar: true,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '+ R\$ 10,00 adicionados como Receita de teste!',
                                      ),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.add, size: 16, color: Colors.white),
                              label: const Text(
                                '+ R\$ 10 Receita',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _firestoreService.executarOperacaoDebug10Reais(
                                  idCliente: widget.uid,
                                  titulo: 'Despesa Teste Debug (-10)',
                                  categoria: 'Alimentação',
                                  adicionar: false,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '- R\$ 10,00 debitados como Despesa de teste!',
                                      ),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.remove, size: 16, color: Colors.white),
                              label: const Text(
                                '- R\$ 10 Despesa',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ===============================================================
              // 3. DISPARO DE NOTIFICAÇÕES DE TESTE
              // ===============================================================
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disparo de Notificações de Teste',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Envie alertas pré-definidos para simular o comportamento da central de notificações:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getSubtextColor(context),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(
                              Icons.lightbulb_outline,
                              size: 16,
                              color: AppColors.primaryOrange,
                            ),
                            label: const Text(
                              '💡 Dica CONRADO',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () async {
                              await _firestoreService.criarNotificacao(
                                idCliente: widget.uid,
                                titulo: 'Dica do CONRADO 💡',
                                mensagem:
                                    'Você economizou R\$ 150,00 na categoria Alimentação este mês!',
                                categoria: 'IA Financeira',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Notificação "Dica CONRADO" enviada!'),
                                    backgroundColor: primaryAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.amber,
                            ),
                            label: const Text(
                              '⚠️ Alerta Orçamento',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () async {
                              await _firestoreService.criarNotificacao(
                                idCliente: widget.uid,
                                titulo: 'Alerta de Orçamento ⚠️',
                                mensagem:
                                    'Atenção: Seu orçamento de Lazer atingiu 85% do limite estipulado.',
                                categoria: 'Sistema',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Notificação "Alerta Orçamento" enviada!'),
                                    backgroundColor: primaryAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(
                              Icons.emoji_events_outlined,
                              size: 16,
                              color: Colors.green,
                            ),
                            label: const Text(
                              '🎉 Meta Concluída',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () async {
                              await _firestoreService.criarNotificacao(
                                idCliente: widget.uid,
                                titulo: 'Meta Alcançada! 🎉',
                                mensagem:
                                    'Parabéns! Sua caixinha "Viagem Europa" atingiu 100% da meta calculada.',
                                categoria: 'Metas',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Notificação "Meta Concluída" enviada!'),
                                    backgroundColor: primaryAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                          ActionChip(
                            avatar: Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: primaryAccent,
                            ),
                            label: const Text(
                              '🔒 Aviso Segurança',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () async {
                              await _firestoreService.criarNotificacao(
                                idCliente: widget.uid,
                                titulo: 'Aviso de Segurança 🔒',
                                mensagem:
                                    'Sua sessão foi sincronizada com segurança no novo dispositivo.',
                                categoria: 'Segurança',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Notificação "Aviso Segurança" enviada!'),
                                    backgroundColor: primaryAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _exibirDialogoEnviarNotificacaoPersonalizada(widget.uid),
                              icon: Icon(
                                Icons.edit_notifications_outlined,
                                size: 16,
                                color: primaryAccent,
                              ),
                              label: Text(
                                'Personalizada',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primaryAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: primaryAccent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _firestoreService.limparNotificacoesDoUsuario(widget.uid);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Todas as notificações foram limpas do Firestore.',
                                      ),
                                      backgroundColor: Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.cleaning_services_outlined,
                                size: 16,
                                color: Colors.grey,
                              ),
                              label: const Text(
                                'Limpar Todas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
