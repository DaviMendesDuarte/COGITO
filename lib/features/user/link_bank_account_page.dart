import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tela moderna para vinculação e gerenciamento de contas bancárias no aplicativo COGITO.
/// Apresenta seleção interativa de bancos com cores de marca (Nubank, Itaú, Banco do Brasil, etc.),
/// preview dinâmico do cartão bancário em tempo real e formulário com validação.
class VincularContaBancariaPage extends StatefulWidget {
  /// Dados da conta bancária existente (caso esteja no modo de edição).
  final Map<String, dynamic>? contaExistente;

  const VincularContaBancariaPage({super.key, this.contaExistente});

  @override
  State<VincularContaBancariaPage> createState() =>
      _VincularContaBancariaPageState();
}

class _VincularContaBancariaPageState extends State<VincularContaBancariaPage> {
  /// Chave do formulário para validação dos campos.
  final _formKey = GlobalKey<FormState>();

  /// Controladores dos campos de texto.
  final TextEditingController _agenciaController = TextEditingController();
  final TextEditingController _numeroContaController = TextEditingController();
  final TextEditingController _titularController = TextEditingController();

  /// Banco selecionado.
  String _bancoSelecionado = 'Nubank';

  /// Tipo de conta ('Corrente' ou 'Poupança').
  String _tipoContaSelecionado = 'Corrente';

  /// Estado de carregamento.
  bool _isLoading = false;

  /// Instância do serviço Firebase Firestore.
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  /// Definição visual e de cores de marca das instituições financeiras suportadas.
  static const List<Map<String, dynamic>> _bancosDetalhados = [
    {
      'nome': 'Nubank',
      'cor': Color(0xFF820AD1),
      'icon': Icons.account_balance_outlined,
    },
    {
      'nome': 'Banco do Brasil',
      'cor': Color(0xFF0038A8),
      'icon': Icons.account_balance,
    },
    {'nome': 'Bradesco', 'cor': Color(0xFFCC092F), 'icon': Icons.business},
    {
      'nome': 'Itaú',
      'cor': Color(0xFFEC7000),
      'icon': Icons.account_balance_wallet,
    },
    {'nome': 'Caixa', 'cor': Color(0xFF005CA9), 'icon': Icons.account_balance},
    {'nome': 'Inter', 'cor': Color(0xFFFF7A00), 'icon': Icons.credit_card},
    {
      'nome': 'C6 Bank',
      'cor': Color(0xFF242424),
      'icon': Icons.credit_card_sharp,
    },
    {
      'nome': 'Santander',
      'cor': Color(0xFFE30613),
      'icon': Icons.account_balance_outlined,
    },
    {
      'nome': 'PicPay',
      'cor': Color(0xFF11C76F),
      'icon': Icons.account_balance_wallet_outlined,
    },
    {
      'nome': 'Outro',
      'cor': AppColors.primaryBlue,
      'icon': Icons.account_balance_sharp,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Se for edição, carrega os dados anteriores
    if (widget.contaExistente != null) {
      final conta = widget.contaExistente!;
      final String nomeBanco = conta['nome_banco'] ?? 'Nubank';
      _bancoSelecionado = _bancosDetalhados.any((b) => b['nome'] == nomeBanco)
          ? nomeBanco
          : 'Outro';
      _agenciaController.text = conta['agencia'] ?? '';
      _numeroContaController.text = conta['numero_conta'] ?? '';
      _titularController.text = conta['nome_titular'] ?? '';
      _tipoContaSelecionado = conta['tipo_conta'] ?? 'Corrente';
    } else {
      final usuario = FirebaseFirestoreService.usuarioLogado;
      _titularController.text = usuario?['nome'] ?? '';
    }

    _agenciaController.addListener(() => setState(() {}));
    _numeroContaController.addListener(() => setState(() {}));
    _titularController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _agenciaController.dispose();
    _numeroContaController.dispose();
    _titularController.dispose();
    super.dispose();
  }

  /// Retorna os detalhes de estilo (cor e ícone) do banco selecionado.
  Map<String, dynamic> _getBancoAtual() {
    return _bancosDetalhados.firstWhere(
      (b) => b['nome'] == _bancoSelecionado,
      orElse: () => _bancosDetalhados.last,
    );
  }

  /// Salva e vincula os dados da conta no Firebase Firestore.
  Future<void> _vincularConta() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final usuario = FirebaseFirestoreService.usuarioLogado;
      final String idCliente =
          (usuario?['uid'] ?? usuario?['id_cliente'] ?? 'guest').toString();

      await _firestoreService.vincularContaBancaria(
        idCliente: idCliente,
        nomeBanco: _bancoSelecionado,
        agencia: _agenciaController.text.trim(),
        numeroConta: _numeroContaController.text.trim(),
        tipoConta: _tipoContaSelecionado,
        nomeTitular: _titularController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conta bancária vinculada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao vincular conta: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bancoAtual = _getBancoAtual();
    final Color corBanco = bancoAtual['cor'] as Color;
    final bool isEdicao = widget.contaExistente != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.getOverlayStyleForBackground(corBanco),
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: corBanco,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isEdicao ? 'Editar Conta Bancária' : 'Vincular Conta Bancária',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Preview Vivo do Cartão do Banco Selecionado
                _buildCardPreview(bancoAtual, corBanco),

                const SizedBox(height: 24),

                // 2. Seção de Seleção do Banco em Grade/Carrossel de Botões Visuais
                Text(
                  'Escolha o Seu Banco',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.getPrimaryAccent(context),
                  ),
                ),
                const SizedBox(height: 12),
                _buildGradeSelecaoBancos(),

                const SizedBox(height: 24),

                // 3. Campos de Entrada (Agência e Conta)
                Text(
                  'Dados da Conta',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.getPrimaryAccent(context),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _agenciaController,
                        style: TextStyle(color: AppColors.getTextColor(context)),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: _inputDecoration(
                          'Agência',
                          Icons.location_city_outlined,
                          'Ex: 0001',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Informe a agência'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _numeroContaController,
                        style: TextStyle(color: AppColors.getTextColor(context)),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                        ],
                        decoration: _inputDecoration(
                          'Número da Conta',
                          Icons.credit_card_outlined,
                          'Ex: 12345-6',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Informe a conta'
                            : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 4. Tipo de Conta (Corrente vs Poupança)
                _buildTipoContaSelector(corBanco),

                const SizedBox(height: 16),

                // 5. Titular da Conta
                TextFormField(
                  controller: _titularController,
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration(
                    'Nome do Titular',
                    Icons.person_outline,
                    'Nome completo do titular',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Informe o nome do titular'
                      : null,
                ),

                const SizedBox(height: 32),

                // 6. Botão de Salvação
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _vincularConta,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: corBanco,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.link_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isEdicao
                                    ? 'SALVAR ALTERAÇÕES'
                                    : 'VINCULAR BANCO',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Constrói o cartão de pré-visualização ao vivo do banco selecionado.
  /// Constrói o cartão de pré-visualização ao vivo do banco selecionado (sem sombra e sem gradiente).
  Widget _buildCardPreview(Map<String, dynamic> banco, Color cor) {
    final String agencia = _agenciaController.text.isEmpty
        ? '0001'
        : _agenciaController.text;
    final String conta = _numeroContaController.text.isEmpty
        ? '12345-6'
        : _numeroContaController.text;
    final String titular = _titularController.text.isEmpty
        ? 'NOME DO TITULAR'
        : _titularController.text.toUpperCase();

    return Container(
      width: double.infinity,
      height: 190,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    banco['icon'] as IconData,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    banco['nome'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _tipoContaSelecionado.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONTA CONECTADA',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ag. $agencia  •  C/C $conta',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titular,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Icon(
                Icons.contactless_rounded,
                color: Colors.white70,
                size: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Constrói a grade de seleção rápida dos logos/cards de bancos (sem bordas e sem sombras).
  Widget _buildGradeSelecaoBancos() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _bancosDetalhados.length,
        itemBuilder: (context, index) {
          final item = _bancosDetalhados[index];
          final bool isSelected = _bancoSelecionado == item['nome'];
          final Color cor = item['cor'] as Color;

          return GestureDetector(
            onTap: () {
              setState(() {
                _bancoSelecionado = item['nome'] as String;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 86,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? cor : AppColors.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    color: isSelected ? Colors.white : cor,
                    size: 26,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['nome'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : AppColors.getTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Selector interativo para tipo de conta ('Corrente' ou 'Poupança') sem contornos.
  Widget _buildTipoContaSelector(Color corAtiva) {
    return Row(
      children: ['Corrente', 'Poupança'].map((tipo) {
        final bool selected = _tipoContaSelecionado == tipo;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tipoContaSelecionado = tipo),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: tipo == 'Corrente' ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: selected ? corAtiva : AppColors.getCardColor(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  'Conta $tipo',
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : AppColors.getTextColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Decoração de inputs sem contornos com suporte consistente aos temas claro e escuro.
  InputDecoration _inputDecoration(String label, IconData icon, String hint) {
    final bool isDark = AppColors.isDarkMode(context);
    final Color corAcento = AppColors.getPrimaryAccent(context);

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.getSubtextColor(context)),
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
      prefixIcon: Icon(
        icon,
        color: corAcento,
        size: 20,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: AppColors.getInputFillColor(context),
    );
  }
}
