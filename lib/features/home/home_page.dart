import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/features/conrado/conrado_chat_selector_page.dart';
import 'package:cogito/services/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/app_navigation.dart';

// Importação das telas acessadas via navegação
import '../finances/finances_page.dart';
import '../user/user_page.dart';
import 'dashboard.dart';

/// Tela principal (HomePage) que gerencia o fluxo de abas e a navegação da aplicação COGITO.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Chave de estado local única para a instância da FinancesPage.
  final GlobalKey<FinancesPageState> _financasPageKey =
      GlobalKey<FinancesPageState>();

  /// Guarda o índice da aba atual ativa (0: Dashboard, 1: Finanças, 2: Conrado Hub, 3: Perfil).
  int _currentIndex = 0;

  /// Lista de páginas associadas a cada aba do menu inferior.
  late final List<Widget> _pages = [
    Dashboard(onNavigateToTab: _onItemTapped),
    FinancesPage(key: _financasPageKey, onNavigateToTab: _onItemTapped),
    const ConradoChatSelectorPage(),
    const UserPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Ouve alterações no controlador de configurações para reconstrução instantânea em caso de mudança de tema
    AppSettingsController.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    AppSettingsController.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  /// Callback disparado quando o tema ou qualquer preferência é alterada
  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Atualiza o índice da aba selecionada no estado e opcionalmente seleciona a sub-aba na FinancasPage.
  void _onItemTapped(int index, [int? subTabIndex]) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 1 && subTabIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _financasPageKey.currentState?.selecionarAba(subTabIndex);
      });
    }
  }

  /// Lógica do botão "+" da navbar — comportamento inteligente por aba.
  void _onAddPressed() {
    if (_currentIndex == 0 || _currentIndex == 1) {
      if (_currentIndex == 0) {
        setState(() {
          _currentIndex = 1;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _financasPageKey.currentState?.exibirDialogoNovaTransacao();
        });
      } else {
        _financasPageKey.currentState?.exibirDialogoNovaTransacao();
      }
    } else {
      setState(() {
        _currentIndex = 1;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _financasPageKey.currentState?.exibirDialogoNovaTransacao();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsController.instance,
      builder: (context, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppColors.getStatusBarStyle(context),
          child: Scaffold(
            backgroundColor: AppColors.getBackgroundColor(context),
            body: SafeArea(
              top: false,
              child: IndexedStack(
                key: ValueKey('home_stack_${AppSettingsController.instance.isDarkMode}'),
                index: _currentIndex,
                children: _pages,
              ),
            ),
            bottomNavigationBar: AppNavigation(
              currentIndex: _currentIndex,
              onTap: _onItemTapped,
              onAddPressed: _onAddPressed,
            ),
          ),
        );
      },
    );
  }
}
