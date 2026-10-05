import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/common/utils/profile_photo_helper.dart';
import 'package:cogito/services/firebase_firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tela de edição das configurações do perfil do usuário.
/// Permite alterar foto criptografada, nome, email e telefone, salvando as alterações no Firebase Firestore.
class EditarPerfilPage extends StatefulWidget {
  const EditarPerfilPage({super.key});

  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  /// Chave global para validação do formulário.
  final _formKey = GlobalKey<FormState>();

  /// Instância do serviço Firebase Firestore.
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  /// Controllers dos campos de texto editáveis.
  late final TextEditingController _nomeController;
  late final TextEditingController _emailController;
  late final TextEditingController _telefoneController;
  late final TextEditingController _rendaMensalController;

  /// Indica se está em processo de salvamento.
  bool _isSaving = false;

  /// Indica se há alterações não salvas.
  bool _hasChanges = false;


  @override
  void initState() {
    super.initState();

    final usuario = FirebaseFirestoreService.usuarioLogado;
    final double rendaNum =
        (usuario?['renda_mensal'] as num?)?.toDouble() ?? 3500.0;

    _nomeController = TextEditingController(text: usuario?['nome'] ?? '');
    _emailController = TextEditingController(text: usuario?['email'] ?? '');
    _telefoneController = TextEditingController(
      text: usuario?['telefone'] ?? '',
    );
    _rendaMensalController = TextEditingController(
      text: 'R\$${rendaNum.toStringAsFixed(2)}',
    );


    _nomeController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _telefoneController.addListener(_onFieldChanged);
    _rendaMensalController.addListener(_onFieldChanged);
  }

  /// Extrai e converte de forma segura uma string monetária (ex: "R$ 3.500,00" ou "3500.00") em double.
  double _converterTextoParaMoeda(String input) {
    if (input.trim().isEmpty) return 0.0;
    String limpo = input.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (limpo.isEmpty) return 0.0;

    // Se contém vírgula como separador decimal (formato brasileiro tipo 3.500,50 ou 3500,50)
    if (limpo.contains(',')) {
      limpo = limpo.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // Se contém apenas pontos, verifica se são separadores de milhar
      final int countDots = '.'.allMatches(limpo).length;
      if (countDots > 1) {
        final lastIndex = limpo.lastIndexOf('.');
        limpo =
            limpo.substring(0, lastIndex).replaceAll('.', '') +
            limpo.substring(lastIndex);
      }
    }
    return double.tryParse(limpo) ?? 0.0;
  }

  /// Callback chamado ao modificar qualquer campo — habilita o botão de salvar.
  void _onFieldChanged() {
    if (mounted && !_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _rendaMensalController.dispose();
    super.dispose();
  }

  /// Valida e salva as alterações do perfil no Firebase Firestore e sincroniza na sessão ativa.
  Future<void> _salvarAlteracoes() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final String uid = FirebaseFirestoreService.idClienteAtual;
      final double rendaMensal = _converterTextoParaMoeda(
        _rendaMensalController.text,
      );

      // Salva no Firestore e atualiza o cache em memória
      await _firestoreService.atualizarPerfil(
        uid: uid,
        nome: _nomeController.text.trim(),
        email: _emailController.text.trim(),
        telefone: _telefoneController.text.trim(),
        rendaMensal: rendaMensal,
        tipoRenda: 'Salario_Fixo',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Perfil atualizado com sucesso!'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Retorna para a UserPage com indicação de atualização
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar perfil: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.getStatusBarStyle(context),
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        body: Column(
          children: [
            // Cabeçalho adaptativo ao tema ativo
            _buildHeader(topPadding),

            // Formulário de edição
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Seção de Foto de Perfil Padrão Institucional
                      Center(
                        child: Column(
                          children: [
                            ProfilePhotoHelper.buildProfileAvatar(radius: 42),
                            const SizedBox(height: 10),
                            Text(
                              'Foto de Perfil Padrão COGITO',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Card de Identidade
                      _buildSectionCard(
                        titulo: 'Dados Pessoais',
                        icone: Icons.person_outline,
                        children: [
                          // Campo Nome
                          _buildCampo(
                            controller: _nomeController,
                            label: 'Nome Completo',
                            icone: Icons.badge_outlined,
                            hint: 'Seu nome completo',
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Informe seu nome';
                              if (v.trim().length < 3)
                                return 'Nome muito curto';
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Campo Email
                          _buildCampo(
                            controller: _emailController,
                            label: 'E-mail',
                            icone: Icons.email_outlined,
                            hint: 'seu@email.com',
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Informe seu e-mail';
                              if (!v.contains('@') || !v.contains('.'))
                                return 'E-mail inválido';
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Campo Telefone
                          _buildCampo(
                            controller: _telefoneController,
                            label: 'Telefone',
                            icone: Icons.phone_outlined,
                            hint: '(11) 99999-9999',
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Informe seu telefone';
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Campo Renda Mensal (Formatado em dinheiro tipo R$100.00)
                          _buildCampo(
                            controller: _rendaMensalController,
                            label: 'Renda Mensal (Ex: R\$100.00)',
                            icone: Icons.attach_money_outlined,
                            hint: 'R\$100.00',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Informe sua renda mensal';
                              return null;
                            },
                          ),


                        ],
                      ),

                      const SizedBox(height: 16),

                      // Aviso informativo
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'As alterações de e-mail podem exigir novo login na próxima vez.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Botão de salvar
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: (_hasChanges && !_isSaving)
                              ? _salvarAlteracoes
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.getActionButtonColor(context),
                            disabledBackgroundColor: Colors.grey.shade400,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 4,
                            shadowColor: AppColors.getActionButtonColor(context).withValues(
                              alpha: 0.3,
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.save_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'SALVAR ALTERAÇÕES',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Botão cancelar
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói o cabeçalho adaptativo da tela com botão de voltar.
  Widget _buildHeader(double topPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, topPadding + 8, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.getPrimaryAccent(context),
      ),
      child: Row(
        children: [
          // Botão de voltar
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editar Perfil',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  'Atualize suas informações pessoais',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói um card de seção do formulário.
  Widget _buildSectionCard({
    required String titulo,
    required IconData icone,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      color: AppColors.getCardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.getBorderColor(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título da seção
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.getPrimaryAccent(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icone, color: AppColors.getPrimaryAccent(context), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(height: 1, color: AppColors.getBorderColor(context)),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Constrói um campo de texto estilizado do formulário.
  Widget _buildCampo({
    required TextEditingController controller,
    required String label,
    required IconData icone,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: AppColors.getTextColor(context)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.getSubtextColor(context)),
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.getSubtextColor(context)),
        prefixIcon: Icon(icone, color: AppColors.getPrimaryAccent(context), size: 20),
        filled: true,
        fillColor: AppColors.getInputFillColor(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.getBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.getBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.getPrimaryAccent(context), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
