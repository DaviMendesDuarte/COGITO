import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/common/constant/text_styles.dart';
import 'package:cogito/features/plans/plans_page.dart';
import 'package:cogito/services/debug_mock_service.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tela dedicada da Carteira do Usuário do COGITO.
///
/// Centraliza a gestão de Contas Bancárias Vinculadas e Cartões de Crédito:
/// - Saldo Consolidado em tempo real somando rigorosamente as contas bancárias conectadas.
/// - Subtela modal para vinculação de novas contas bancárias com saldo inicial.
/// - Subtela modal para cadastro completo de cartões de crédito.
/// - Visual moderno, sem contornos (`BorderSide.none`) e adaptativo ao Modo Escuro.
class CarteiraPage extends StatefulWidget {
  const CarteiraPage({super.key});

  @override
  State<CarteiraPage> createState() => _CarteiraPageState();
}

class _CarteiraPageState extends State<CarteiraPage> {
  /// Instância do serviço de banco de dados Firestore.
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  /// ID do cliente autenticado no COGITO.
  String get _idCliente => FirebaseFirestoreService.idClienteAtual;

  /// Controla a visibilidade do saldo consolidado (olho aberto/fechado).
  bool _isSaldoVisivel = true;

  @override
  Widget build(BuildContext context) {
    final Color primaryAccent = AppColors.getPrimaryAccent(context);
    final Color cardBg = AppColors.getCardColor(context);
    final Color textPrimary = AppColors.getTextColor(context);
    final Color subText = AppColors.getSubtextColor(context);

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
          title: Text(
            'Minha Carteira',
            style: TextStyles.poppinsBold(fontSize: 18, color: Colors.white),
          ),
          centerTitle: true,
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestoreService.buscarContasBancariasStream(_idCliente),
          builder: (context, snapshotContas) {
            final List<Map<String, dynamic>> contas = snapshotContas.data ?? [];

            // Calcula a soma exata de todos os saldos das contas bancárias vinculadas
            double saldoConsolidado = 0.0;
            for (final c in contas) {
              saldoConsolidado += (c['saldo'] as num?)?.toDouble() ?? 0.0;
            }

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestoreService.buscarCartoesStream(_idCliente),
              builder: (context, snapshotCartoes) {
                final List<Map<String, dynamic>> cartoes = snapshotCartoes.data ?? [];

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. CARD SUPERIOR DE SALDO CONSOLIDADO
                      _buildSaldoConsolidadoCard(
                        context: context,
                        saldoConsolidado: saldoConsolidado,
                        quantidadeContas: contas.length,
                        cardBg: cardBg,
                        textPrimary: textPrimary,
                        subText: subText,
                        primaryAccent: primaryAccent,
                      ),

                      const SizedBox(height: 24),

                      // 2. SEÇÃO DE CONTAS BANCÁRIAS VINCULADAS
                      _buildHeaderSecao(
                        titulo: 'Contas Bancárias (${contas.length})',
                        textoBotao: '+ Vincular Banco',
                        onTap: () => _abrirSubtelaVincularBanco(context, contas.length),
                        primaryAccent: primaryAccent,
                        textPrimary: textPrimary,
                      ),
                      const SizedBox(height: 12),
                      _buildListaContasBancarias(
                        context: context,
                        contas: contas,
                        cardBg: cardBg,
                        textPrimary: textPrimary,
                        subText: subText,
                        primaryAccent: primaryAccent,
                      ),

                      const SizedBox(height: 28),

                      // 3. SEÇÃO DE CARTÕES DE CRÉDITO
                      _buildHeaderSecao(
                        titulo: 'Meus Cartões (${cartoes.length})',
                        textoBotao: '+ Adicionar Cartão',
                        onTap: () => _abrirSubtelaAdicionarCartao(context),
                        primaryAccent: primaryAccent,
                        textPrimary: textPrimary,
                      ),
                      const SizedBox(height: 12),
                      _buildListaCartoes(
                        context: context,
                        cartoes: cartoes,
                        cardBg: cardBg,
                        textPrimary: textPrimary,
                        subText: subText,
                        primaryAccent: primaryAccent,
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Constrói o card superior com o saldo consolidado rigorosamente igual à soma dos bancos vinculados.
  Widget _buildSaldoConsolidadoCard({
    required BuildContext context,
    required double saldoConsolidado,
    required int quantidadeContas,
    required Color cardBg,
    required Color textPrimary,
    required Color subText,
    required Color primaryAccent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.account_balance_wallet, color: primaryAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SALDO CONSOLIDADO',
                        style: TextStyles.poppinsBold(fontSize: 12.5, color: subText, letterSpacing: 0.5),
                      ),
                      Text(
                        '$quantidadeContas ${quantidadeContas == 1 ? "conta bancária vinculada" : "contas bancárias vinculadas"}',
                        style: TextStyles.poppinsRegular(fontSize: 11, color: subText),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  _isSaldoVisivel ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: textPrimary,
                  size: 22,
                ),
                onPressed: () => setState(() => _isSaldoVisivel = !_isSaldoVisivel),
                tooltip: 'Mostrar/Ocultar Saldo',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _isSaldoVisivel
                ? 'R\$ ${saldoConsolidado.toStringAsFixed(2).replaceAll('.', ',')}'
                : '••••••••',
            style: TextStyles.poppinsBold(fontSize: 30, color: textPrimary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.getInputFillColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: primaryAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'O saldo consolidado reflete a soma exata das suas contas de bancos conectadas.',
                    style: TextStyle(fontSize: 11.5, color: subText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói o cabeçalho de seção com título e botão de ação para abrir a subtela.
  Widget _buildHeaderSecao({
    required String titulo,
    required String textoBotao,
    required VoidCallback onTap,
    required Color primaryAccent,
    required Color textPrimary,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          titulo,
          style: TextStyles.poppinsBold(fontSize: 16, color: textPrimary),
        ),
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryAccent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            textoBotao,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }

  /// Constrói a lista de contas bancárias vinculadas ou o estado vazio.
  Widget _buildListaContasBancarias({
    required BuildContext context,
    required List<Map<String, dynamic>> contas,
    required Color cardBg,
    required Color textPrimary,
    required Color subText,
    required Color primaryAccent,
  }) {
    if (contas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.account_balance_outlined, size: 44, color: subText.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Text(
              'Nenhuma conta bancária vinculada.',
              style: TextStyles.poppinsRegular(fontSize: 13, color: subText),
            ),
            const SizedBox(height: 6),
            Text(
              'Toque em "+ Vincular Banco" para conectar sua conta.',
              style: TextStyle(fontSize: 11.5, color: primaryAccent, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: contas.map((conta) {
        final String nomeBanco = conta['nome_banco'] ?? 'Conta Bancária';
        final String agencia = conta['agencia'] ?? '0001';
        final String numeroConta = conta['numero_conta'] ?? '00000-0';
        final double saldoConta = (conta['saldo'] as num?)?.toDouble() ?? 0.0;
        final String docId = conta['firestore_id'] ?? conta['id'] ?? _idCliente;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.account_balance, color: primaryAccent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomeBanco,
                      style: TextStyles.poppinsBold(fontSize: 15, color: textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Agência: $agencia • CC: $numeroConta',
                      style: TextStyle(fontSize: 12, color: subText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSaldoVisivel
                          ? 'Saldo: R\$ ${saldoConta.toStringAsFixed(2).replaceAll('.', ',')}'
                          : 'Saldo: ••••••••',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                tooltip: 'Desvincular Conta',
                onPressed: () => _confirmarRemoverConta(context, docId, nomeBanco),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Constrói a lista de cartões de crédito ou o estado vazio.
  Widget _buildListaCartoes({
    required BuildContext context,
    required List<Map<String, dynamic>> cartoes,
    required Color cardBg,
    required Color textPrimary,
    required Color subText,
    required Color primaryAccent,
  }) {
    if (cartoes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.credit_card_off_outlined, size: 44, color: subText.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Text(
              'Nenhum cartão cadastrado.',
              style: TextStyles.poppinsRegular(fontSize: 13, color: subText),
            ),
            const SizedBox(height: 6),
            Text(
              'Toque em "+ Adicionar Cartão" para cadastrar.',
              style: TextStyle(fontSize: 11.5, color: primaryAccent, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: cartoes.map((cartao) {
        final String titular = cartao['titular'] ?? 'TITULAR';
        final String numero = cartao['numero'] ?? '•••• •••• •••• 0000';
        final String bandeira = cartao['bandeira'] ?? 'Mastercard';
        final String validade = cartao['validade'] ?? '12/28';
        final double limite = (cartao['limite_total'] as num?)?.toDouble() ?? 3000.0;
        final String cartaoId = cartao['id'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(20),
          // Cartão com cor sólida sem gradientes conforme solicitado
          decoration: BoxDecoration(
            color: primaryAccent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.contactless_rounded, color: Colors.white70, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        bandeira.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                    tooltip: 'Remover Cartão',
                    onPressed: () => _confirmarRemoverCartao(context, cartaoId, titular),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                numero,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TITULAR',
                        style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1),
                      ),
                      Text(
                        titular.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VALIDADE',
                        style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1),
                      ),
                      Text(
                        validade,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'LIMITE',
                        style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1),
                      ),
                      Text(
                        'R\$ ${limite.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Exibe diálogo informativo explicando o limite de contas consolidadas do plano atual.
  void _exibirDialogoLimiteContasBancarias(BuildContext context, String planoAtual, int limiteAtual) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.account_balance, color: AppColors.primaryOrange),
            const SizedBox(width: 8),
            Text(
              'Limite de Contas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppColors.getTextColor(context),
              ),
            ),
          ],
        ),
        content: Text(
          'No seu plano $planoAtual, o limite é de $limiteAtual ${limiteAtual == 1 ? "conta bancária vinculada" : "contas bancárias vinculadas"} para saldo consolidado.\n\n'
          'Para conectar contas ilimitadas e ter uma gestão multi-bancos completa, faça upgrade para o plano Premium.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.35,
            color: AppColors.getTextColor(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              PlanosModal.exibir(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text(
              'Conhecer Planos',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Abre a subtela modal (BottomSheet) para vinculação de Conta Bancária respeitando os limites do plano.
  void _abrirSubtelaVincularBanco(BuildContext context, int contasAtuais) {
    final usuario = FirebaseFirestoreService.usuarioLogado;
    final String plano = usuario?['plano'] ?? 'Grátis';
    final bool isPremium = plano == 'Premium' || DebugMockService.instance.modoMockAtivo;
    final bool isFreelancer = plano == 'Freelancer';

    // Regras de limites de contas consolidadas:
    // - Grátis: até 1 conta bancária
    // - Freelancer: até 3 contas bancárias
    // - Premium: contas bancárias ilimitadas
    int limiteContas = 1;
    if (isFreelancer) limiteContas = 3;
    if (isPremium) limiteContas = 9999;

    if (contasAtuais >= limiteContas) {
      _exibirDialogoLimiteContasBancarias(context, plano, limiteContas);
      return;
    }

    String bancoSelecionado = 'Nubank';
    String tipoContaSelecionado = 'Corrente';
    final titularController = TextEditingController();
    final agenciaController = TextEditingController();
    final contaController = TextEditingController();
    final saldoController = TextEditingController(text: 'R\$ 0,00');
    final formKey = GlobalKey<FormState>();

    final List<String> bancosDisponiveis = [
      'Nubank',
      'Itaú Unibanco',
      'Bradesco',
      'Banco do Brasil',
      'Santander',
      'Inter',
      'Caixa Econômica',
      'C6 Bank',
      'Outro Banco',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).viewPadding.bottom +
                    24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho da subtela
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Vincular Conta Bancária',
                            style: TextStyles.poppinsBold(fontSize: 18, color: AppColors.getPrimaryAccent(context)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Seleção de Banco
                      DropdownButtonFormField<String>(
                        initialValue: bancoSelecionado,
                        dropdownColor: AppColors.getCardColor(context),
                        decoration: InputDecoration(
                          labelText: 'Instituição Bancária',
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                        items: bancosDisponiveis.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => bancoSelecionado = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Nome do Titular
                      TextFormField(
                        controller: titularController,
                        decoration: InputDecoration(
                          labelText: 'Nome do Titular',
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome do titular' : null,
                      ),
                      const SizedBox(height: 12),

                      // Tipo de Conta (Corrente ou Poupança)
                      DropdownButtonFormField<String>(
                        initialValue: tipoContaSelecionado,
                        dropdownColor: AppColors.getCardColor(context),
                        decoration: InputDecoration(
                          labelText: 'Tipo de Conta',
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Corrente', child: Text('Conta Corrente')),
                          DropdownMenuItem(value: 'Poupança', child: Text('Conta Poupança')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => tipoContaSelecionado = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Agência
                      TextFormField(
                        controller: agenciaController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Agência (ex: 0001)',
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a agência' : null,
                      ),
                      const SizedBox(height: 12),

                      // Número da Conta
                      TextFormField(
                        controller: contaController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'Número da Conta com Dígito (ex: 12345-6)',
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a conta' : null,
                      ),
                      const SizedBox(height: 12),

                      // Saldo Inicial da Conta
                      TextFormField(
                        controller: saldoController,
                        keyboardType: TextInputType.number,
                        onChanged: (val) => _formatarMoeda(val, saldoController),
                        decoration: InputDecoration(
                          labelText: 'Saldo Inicial da Conta',
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botão Salvar
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            final double saldoNum = _extrairMoeda(saldoController.text);
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(modalCtx);

                            await _firestoreService.vincularContaBancaria(
                              idCliente: _idCliente,
                              nomeBanco: bancoSelecionado,
                              agencia: agenciaController.text.trim(),
                              numeroConta: contaController.text.trim(),
                              tipoConta: tipoContaSelecionado,
                              nomeTitular: titularController.text.trim(),
                              saldo: saldoNum,
                            );

                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Conta do $bancoSelecionado vinculada com sucesso!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.getPrimaryAccent(context),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Vincular Conta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Abre a subtela modal (BottomSheet) para cadastro de Cartão de Crédito.
  void _abrirSubtelaAdicionarCartao(BuildContext context) {
    final titularController = TextEditingController();
    final numeroController = TextEditingController();
    final validadeController = TextEditingController();
    final cvvController = TextEditingController();
    final limiteController = TextEditingController(text: 'R\$ 3.500,00');
    String bandeiraSelecionada = 'Mastercard';
    final formKey = GlobalKey<FormState>();

    final List<String> bandeiras = ['Mastercard', 'Visa', 'Elo', 'American Express', 'Hipercard'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).viewPadding.bottom +
                    24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho da subtela
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cadastrar Novo Cartão',
                            style: TextStyles.poppinsBold(fontSize: 18, color: AppColors.getPrimaryAccent(context)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Nome do Titular
                      TextFormField(
                        controller: titularController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Nome do Titular impresso no cartão',
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome do titular' : null,
                      ),
                      const SizedBox(height: 12),

                      // Número do Cartão
                      TextFormField(
                        controller: numeroController,
                        keyboardType: TextInputType.number,
                        maxLength: 19,
                        onChanged: (val) {
                          String clean = val.replaceAll(' ', '');
                          StringBuffer buffer = StringBuffer();
                          for (int i = 0; i < clean.length; i++) {
                            if (i > 0 && i % 4 == 0) buffer.write(' ');
                            buffer.write(clean[i]);
                          }
                          final formatted = buffer.toString();
                          numeroController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        },
                        decoration: InputDecoration(
                          labelText: 'Número do Cartão (16 dígitos)',
                          counterText: '',
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                        validator: (v) => (v == null || v.replaceAll(' ', '').length < 16) ? 'Cartão deve conter 16 dígitos' : null,
                      ),
                      const SizedBox(height: 12),

                      // Bandeira
                      DropdownButtonFormField<String>(
                        initialValue: bandeiraSelecionada,
                        dropdownColor: AppColors.getCardColor(context),
                        decoration: InputDecoration(
                          labelText: 'Bandeira do Cartão',
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                        items: bandeiras.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => bandeiraSelecionada = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Linha de Validade e CVV
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: validadeController,
                              keyboardType: TextInputType.number,
                              maxLength: 5,
                              onChanged: (val) {
                                String clean = val.replaceAll('/', '');
                                if (clean.length >= 2) {
                                  final formatted = '${clean.substring(0, 2)}/${clean.substring(2)}';
                                  validadeController.value = TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(offset: formatted.length),
                                  );
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Validade (MM/AA)',
                                counterText: '',
                                filled: true,
                                fillColor: AppColors.getInputFillColor(context),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                              ),
                              validator: (v) => (v == null || v.length < 5) ? 'Formato MM/AA' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: cvvController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 4,
                              decoration: InputDecoration(
                                labelText: 'CVV',
                                counterText: '',
                                filled: true,
                                fillColor: AppColors.getInputFillColor(context),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                              ),
                              validator: (v) => (v == null || v.length < 3) ? 'CVV inválido' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Limite Total com validação de valor positivo
                      TextFormField(
                        controller: limiteController,
                        keyboardType: TextInputType.number,
                        onChanged: (val) => _formatarMoeda(val, limiteController),
                        decoration: InputDecoration(
                          labelText: 'Limite do Cartão',
                          filled: true,
                          fillColor: AppColors.getInputFillColor(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Informe o limite do cartão';
                          final val = _extrairMoeda(v);
                          if (val <= 0) return 'O limite deve ser maior que R\$ 0,00';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Botão Salvar Cartão com persistência completa
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            final double limiteNum = _extrairMoeda(limiteController.text);
                            final String numCompleto = numeroController.text.trim();
                            final String numLimpo = numCompleto.replaceAll(RegExp(r'\D'), '');
                            final String ultimosDigitos = numLimpo.length >= 4
                                ? numLimpo.substring(numLimpo.length - 4)
                                : numLimpo.padLeft(4, '0');

                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(modalCtx);

                            await _firestoreService.salvarCartao(
                              idCliente: _idCliente,
                              banco: 'Cartão $bandeiraSelecionada',
                              bandeira: bandeiraSelecionada,
                              titular: titularController.text.trim(),
                              numero: numCompleto,
                              validade: validadeController.text.trim(),
                              ultimosDigitos: ultimosDigitos,
                              limiteTotal: limiteNum,
                              faturaAtual: 0.0,
                              vencimento: 'Dia 10',
                            );

                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Cartão cadastrado com sucesso!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.getPrimaryAccent(context),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Cadastrar Cartão', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Diálogo para confirmação de remoção de conta bancária vinculada.
  void _confirmarRemoverConta(BuildContext context, String docId, String nomeBanco) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Desvincular Conta'),
        content: Text('Deseja realmente desconectar a conta do "$nomeBanco"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogCtx);
              await _firestoreService.removerContaBancaria(docId);
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Conta do $nomeBanco desvinculada.'), backgroundColor: Colors.orange),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0),
            child: const Text('Desvincular', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Diálogo para confirmação de exclusão de cartão de crédito cadastrado.
  void _confirmarRemoverCartao(BuildContext context, String cartaoId, String titular) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remover Cartão'),
        content: Text('Deseja remover o cartão de "$titular"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogCtx);
              await _firestoreService.removerCartao(cartaoId);
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Cartão removido com sucesso.'), backgroundColor: Colors.orange),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Formata moeda enquanto o usuário digita.
  void _formatarMoeda(String value, TextEditingController controller) {
    String clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) {
      controller.value = const TextEditingValue(text: 'R\$ 0,00', selection: TextSelection.collapsed(offset: 7));
      return;
    }
    final double parsed = (double.tryParse(clean) ?? 0) / 100.0;
    final String formatted = 'R\$ ${parsed.toStringAsFixed(2).replaceAll('.', ',')}';
    controller.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }

  /// Converte texto formatado de moeda em número double.
  double _extrairMoeda(String text) {
    final clean = text.replaceAll('R\$', '').replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(clean) ?? 0.0;
  }
}
