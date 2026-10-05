import 'package:cogito/common/constant/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Barra de navegação inferior (Bottom Navigation Bar) personalizada do aplicativo COGITO.
///
/// Apresenta navegação entre as 4 áreas principais:
/// 1. Início (Dashboard)
/// 2. Finanças (Gráficos e Extratos)
/// 3. CONRADO (Assistente Virtual com ícone de coroa)
/// 4. Perfil (Configurações da Conta)
///
/// Possui suporte a indicador de aba ativa animado e estrutura modular sem aninhamento excessivo.
class AppNavigation extends StatefulWidget {
  /// Índice da aba atualmente selecionada.
  final int currentIndex;

  /// Callback disparado ao selecionar uma das abas de navegação.
  final ValueChanged<int> onTap;

  /// Callback disparado ao clicar no botão de adicionar ("+").
  final VoidCallback onAddPressed;

  /// Construtor da barra de navegação.
  const AppNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAddPressed,
  });

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  // Constantes de dimensão para o botão flutuante
  static const double _addButtonMaxWidth = 76;
  static const double _addButtonHeight = 46;
  static const double _addButtonMaxRadius = 23;

  /// Flag que controla a visibilidade do botão central "+".
  bool get _isAddButtonVisible => false;

  @override
  Widget build(BuildContext context) {
    final Color navBgColor = AppColors.getCardColor(context);
    final Color selectedColor = AppColors.getPrimaryAccent(context);
    final Color unselectedColor =
        Theme.of(context).brightness == Brightness.dark
        ? Colors.white54
        : AppColors.gray;

    return Container(
      decoration: BoxDecoration(
        color: navBgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: SizedBox(
            height: 54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Aba 0: Início
                Expanded(
                  child: _NavItem(
                    icon: Icons.home_filled,
                    index: 0,
                    isSelected: widget.currentIndex == 0,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    onTap: widget.onTap,
                  ),
                ),

                // Aba 1: Finanças
                Expanded(
                  child: _NavItem(
                    icon: Icons.bar_chart,
                    index: 1,
                    isSelected: widget.currentIndex == 1,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    onTap: widget.onTap,
                  ),
                ),

                // Botão central de adicionar
                _buildAddButton(selectedColor),

                // Aba 2: Assistente CONRADO
                Expanded(
                  child: _NavItem(
                    icon: MdiIcons.crown,
                    index: 2,
                    isSelected: widget.currentIndex == 2,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    onTap: widget.onTap,
                  ),
                ),

                // Aba 3: Perfil
                Expanded(
                  child: _NavItem(
                    icon: Icons.person,
                    index: 3,
                    isSelected: widget.currentIndex == 3,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    onTap: widget.onTap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Constrói o botão animado de adição ("+").
  Widget _buildAddButton(Color accentColor) {
    final double target = _isAddButtonVisible ? 1.0 : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: target, end: target),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubicEmphasized,
      builder: (context, t, child) {
        final double width = _addButtonMaxWidth * t;
        final double radius = _addButtonMaxRadius * t;

        return Opacity(
          opacity: t,
          child: Container(
            width: width,
            height: _addButtonHeight,
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: IgnorePointer(
              ignoring: t < 0.5,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onAddPressed,
                child: SizedBox(
                  width: _addButtonMaxWidth,
                  height: _addButtonHeight,
                  child: const Icon(
                    Icons.add,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Item individual de navegação com ícone e indicador de aba ativa.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final int index;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.index,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color itemColor = isSelected ? selectedColor : unselectedColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: itemColor),
            const SizedBox(height: 4),
            // Indicador em barra horizontal que anima conforme a seleção
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 14 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: isSelected ? selectedColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
