import 'package:cogito/common/constant/app_colors.dart';
import 'package:cogito/common/constant/text_styles.dart';
import 'package:cogito/features/splash/splash_page.dart';
import 'package:cogito/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

/// Widget raiz da aplicação COGITO.
/// Configura o [MaterialApp], suporte reativo a tema escuro/claro com a fonte Poppins, tamanho de fontes e modo daltonismo.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsController.instance,
      builder: (context, _) {
        final settings = AppSettingsController.instance;
        final matrix = settings.daltonismoColorMatrix;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'COGITO',
          // Suporte reativo a temas Claro e Escuro com a fonte Poppins
          themeMode: settings.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: TextStyles.fontFamily,
            brightness: Brightness.light,
            primaryColor: AppColors.primaryBlue,
            scaffoldBackgroundColor: AppColors.backgroundColor,
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide.none, // Interface sem contornos
              ),
            ),
            dividerTheme: const DividerThemeData(
              color: Color(0xFFE5E7EB), // Cor determinada para separação
              thickness: 1,
              space: 1,
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primaryBlue,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: TextStyles.fontFamily,
            brightness: Brightness.dark,
            primaryColor: AppColors.primaryOrange,
            scaffoldBackgroundColor: AppColors.darkBackground,
            cardColor: AppColors.darkCardColor,
            canvasColor: AppColors.darkBackground,
            dividerColor: AppColors.darkBorderColor,
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.darkCardColor,
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: AppColors.darkCardColor,
              modalBackgroundColor: AppColors.darkCardColor,
            ),
            cardTheme: CardThemeData(
              color: AppColors.darkCardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide.none, // Interface sem contornos
              ),
            ),
            dividerTheme: const DividerThemeData(
              color: AppColors.darkBorderColor, // Cor determinada para separação no tema escuro
              thickness: 1,
              space: 1,
            ),
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryOrange,
              secondary: AppColors.primaryYellow,
              surface: AppColors.darkCardColor,
              error: Colors.redAccent,
              onPrimary: Colors.white,
              onSecondary: Colors.black,
              onSurface: AppColors.darkTextPrimary,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.primaryOrange, // Barra laranja no tema escuro
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primaryOrange;
                }
                return Colors.grey.shade400;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primaryOrange.withValues(alpha: 0.5);
                }
                return Colors.grey.shade700;
              }),
            ),
          ),

          // Injeta escala de fonte e filtro de cores para daltonismo globalmente
          builder: (context, child) {
            Widget appWidget = child ?? const SizedBox.shrink();

            // Aplica o escalonamento dinâmico de texto (tamanho da letra)
            final mediaData = MediaQuery.of(context);
            appWidget = MediaQuery(
              data: mediaData.copyWith(
                textScaler: TextScaler.linear(settings.fontScale),
              ),
              child: appWidget,
            );

            // Aplica filtro de daltonismo caso esteja ativo
            if (matrix != null) {
              appWidget = ColorFiltered(
                colorFilter: ColorFilter.matrix(matrix),
                child: appWidget,
              );
            }

            return appWidget;
          },

          // Define a SplashPage como tela inicial para verificação de sessão e biometria.
          // Se o usuário não possuir sessão ativa, a SplashPage direciona direto para a tela de autenticação (AuthChoicePage - Cadastro ou Login),
          // eliminando completamente qualquer tela intermediária de onboarding.
          home: const SplashPage(),
        );
      },
    );
  }
}
