import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tela de Notificações do aplicativo COGITO.
/// Exibe alertas do sistema, dicas do CONRADO e avisos sobre limites de orçamentos em tempo real.
class NotificacoesPage extends StatefulWidget {
  const NotificacoesPage({super.key});

  @override
  State<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends State<NotificacoesPage> {
  /// Instância do serviço Firebase Firestore.
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  /// Marca uma notificação individual como lida ao ser clicada pelo usuário, caso ainda não tenha sido lida.
  void _marcarNotificacaoComoLida(Map<String, dynamic> item) {
    final bool jaLida = item['lida'] == true;
    if (jaLida) {
      return; // Já está lida, nenhuma ação necessária
    }

    final String idNotif =
        item['id']?.toString() ?? item['firestore_id']?.toString() ?? '';

    // Atualização otimista imediata na interface
    setState(() {
      item['lida'] = true;
    });

    // Persiste a leitura no serviço (Cloud Firestore ou Sessão Mock)
    if (idNotif.isNotEmpty) {
      _firestoreService.marcarNotificacaoComoLida(idNotif);
    }

    // Feedback sensorial e visual para o usuário
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Notificação marcada como lida.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.getPrimaryAccent(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Marca todas as notificações exibidas como lidas no Firestore.
  void _marcarTodasComoLidas(List<Map<String, dynamic>> notificacoes) {
    for (var n in notificacoes) {
      final id = n['id'] ?? n['firestore_id'];
      if (id != null) {
        _firestoreService.marcarNotificacaoComoLida(id.toString());
      }
    }
    setState(() {
      for (var n in notificacoes) {
        n['lida'] = true;
      }
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Todas as notificações foram marcadas como lidas.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.getPrimaryAccent(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Limpa todas as notificações do usuário logado no Firestore.
  void _limparNotificacoes() {
    final usuario = FirebaseFirestoreService.usuarioLogado;
    final uid = usuario?['uid'] ?? usuario?['id_cliente'] ?? 'guest';
    _firestoreService.limparNotificacoesDoUsuario(uid.toString());
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseFirestoreService.idClienteAtual;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.getOverlayStyleForBackground(
        AppColors.getPrimaryAccent(context),
      ),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.buscarNotificacoesStream(uid),
        builder: (context, snapshot) {
          final List<Map<String, dynamic>> notificacoes = snapshot.data ?? [];
          final bool isLoading =
              snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData;

          return Scaffold(
            backgroundColor: AppColors.getBackgroundColor(context),
            appBar: AppBar(
              backgroundColor: AppColors.getPrimaryAccent(context),
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Notificações',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              actions: [
                if (notificacoes.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (val) {
                      if (val == 'marcar_lidas')
                        _marcarTodasComoLidas(notificacoes);
                      if (val == 'limpar') _limparNotificacoes();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'marcar_lidas',
                        child: Row(
                          children: [
                            Icon(
                              Icons.done_all,
                              color: AppColors.getPrimaryAccent(context),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Text('Marcar todas como lidas'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'limpar',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text('Limpar tudo'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            body: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.getPrimaryAccent(context),
                    ),
                  )
                : notificacoes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notificacoes.length,
                    itemBuilder: (context, index) {
                      final item = notificacoes[index];
                      return _buildNotificationCard(item);
                    },
                  ),
          );
        },
      ),
    );
  }

  /// Constrói o estado vazio quando não há notificações disponíveis.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.getPrimaryAccent(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 64,
                color: AppColors.getPrimaryAccent(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nenhuma notificação por aqui',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getPrimaryAccent(context),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Você está em dia! Quando houver novidades sobre seu orçamento ou dicas do CONRADO, elas aparecerão nesta tela.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói o card individual de notificação com ícone de categoria e marcação de leitura (sem contorno e sem sombra).
  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final bool lida = item['lida'] ?? false;
    final String categoria = item['categoria'] ?? 'Sistema';
    final String titulo = item['titulo'] ?? 'Notificação';
    final String mensagem = item['mensagem'] ?? '';
    final String idNotif = item['id']?.toString() ?? '';

    IconData iconData = Icons.notifications_active_outlined;
    Color iconColor = AppColors.getPrimaryAccent(context);

    if (categoria == 'IA Financeira') {
      iconData = Icons.psychology_outlined;
      iconColor = AppColors.primaryOrange;
    } else if (categoria == 'Segurança') {
      iconData = Icons.shield_outlined;
      iconColor = Colors.green;
    }

    return Dismissible(
      key: Key(
        idNotif.isNotEmpty
            ? idNotif
            : DateTime.now().microsecondsSinceEpoch.toString(),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        if (idNotif.isNotEmpty) {
          _firestoreService.marcarNotificacaoComoLida(idNotif);
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _marcarNotificacaoComoLida(item),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lida
                  ? AppColors.getCardColor(context)
                  : AppColors.getPrimaryAccent(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone da Categoria
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),

                // Conteúdo da Notificação
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              titulo,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: lida
                                    ? FontWeight.w600
                                    : FontWeight.bold,
                                color: AppColors.getTextColor(context),
                              ),
                            ),
                          ),
                          if (!lida)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mensagem,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.isDarkMode(context)
                              ? Colors.white70
                              : Colors.black87,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        categoria,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
