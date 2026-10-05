import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controlador responsável pelo gerenciamento de estado global de acessibilidade e aparência do aplicativo COGITO.
/// Gerencia as preferências do usuário para:
/// 1. Modo Escuro (Claro, Escuro ou Sistema).
/// 2. Tamanho da Fonte (Escala de texto reativa em todo o app).
/// 3. Filtros de Daltonismo (Protanopia, Deuteranopia, Tritanopia ou Desativado).
class AppSettingsController extends ChangeNotifier {
  /// Instância singleton para acesso global em qualquer tela da aplicação.
  static final AppSettingsController instance = AppSettingsController._();

  AppSettingsController._() {
    _carregarPreferenciasLocais();
  }

  /// Modo do tema atual do aplicativo (por padrão, Modo Claro).
  ThemeMode _themeMode = ThemeMode.light;

  /// Fator de escala da fonte selecionado (1.0 = Tamanho Normal).
  double _fontScale = 1.0;

  /// Nome do modo de daltonismo ativo ('Desativado' por padrão).
  String _daltonismoMode = 'Desativado';

  /// Estado das notificações push ativas no dispositivo.
  bool _pushNotifications = true;

  /// Carrega as preferências salvas no armazenamento local do dispositivo.
  Future<void> _carregarPreferenciasLocais() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool? isDark = prefs.getBool('cogito_dark_mode_enabled');
      if (isDark != null) {
        _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      }
      final double? scale = prefs.getDouble('cogito_font_scale');
      if (scale != null) {
        _fontScale = scale;
      }
      final String? daltonismo = prefs.getString('cogito_daltonismo_mode');
      if (daltonismo != null) {
        _daltonismoMode = daltonismo;
      }
      notifyListeners();
    } catch (_) {}
  }

  // --- GETTERS PÚBLICOS ---

  /// Retorna o modo de tema atual ([ThemeMode.light], [ThemeMode.dark] ou [ThemeMode.system]).
  ThemeMode get themeMode => _themeMode;

  /// Retorna se o modo escuro está ativado explicitamente.
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Retorna o fator numérico de multiplicação para o tamanho dos textos.
  double get fontScale => _fontScale;

  /// Retorna a identificação textual do tipo de daltonismo configurado.
  String get daltonismoMode => _daltonismoMode;

  /// Retorna se as notificações push estão habilitadas no app.
  bool get pushNotifications => _pushNotifications;

  // --- MÉTODOS DE ALTERAÇÃO DE ESTADO ---

  /// Alterna ou define diretamente o Modo Escuro.
  ///
  /// Parâmetros:
  /// - [enableDark]: Se true, ativa o tema escuro; se false, ativa o tema claro.
  void setDarkMode(bool enableDark) {
    _themeMode = enableDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _salvarPreferenciaBool('cogito_dark_mode_enabled', enableDark);
  }

  /// Define o modo de tema através da enumeração [ThemeMode].
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    _salvarPreferenciaBool('cogito_dark_mode_enabled', mode == ThemeMode.dark);
  }

  /// Salva internamente uma preferência booleana no SharedPreferences.
  Future<void> _salvarPreferenciaBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  /// Salva internamente uma preferência double no SharedPreferences.
  Future<void> _salvarPreferenciaDouble(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (_) {}
  }

  /// Salva internamente uma preferência string no SharedPreferences.
  Future<void> _salvarPreferenciaString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }

  /// Atualiza o fator de escala de texto para alterar a acessibilidade de leitura.
  ///
  /// Parâmetros:
  /// - [scale]: Valor flutuante entre 0.85 (Pequeno) e 1.30 (Extra Grande).
  void setFontScale(double scale) {
    _fontScale = scale;
    notifyListeners();
    _salvarPreferenciaDouble('cogito_font_scale', scale);
  }

  /// Configura o filtro de cores específico para usuários com daltonismo.
  ///
  /// Parâmetros:
  /// - [modo]: Nome do filtro ('Desativado', 'Protanopia', 'Deuteranopia' ou 'Tritanopia').
  void setDaltonismoMode(String modo) {
    _daltonismoMode = modo;
    notifyListeners();
    _salvarPreferenciaString('cogito_daltonismo_mode', modo);
  }

  /// Ativa ou desativa as notificações push no aplicativo.
  ///
  /// Parâmetros:
  /// - [enable]: Se true, ativa o envio de alertas; se false, desativa.
  void setPushNotifications(bool enable) {
    _pushNotifications = enable;
    notifyListeners();
    _salvarPreferenciaBool('cogito_push_notifications', enable);
  }

  /// Retorna a matriz de transformação de cores correspondente ao modo de daltonismo ativo.
  /// Utilizada em conjunto com o widget [ColorFiltered] na raiz do aplicativo.
  List<double>? get daltonismoColorMatrix {
    switch (_daltonismoMode) {
      case 'Protanopia':
        // Matriz otimizada para deficiência no espectro vermelho (Protan)
        return <double>[
          0.56667,
          0.43333,
          0.00000,
          0,
          0,
          0.55833,
          0.44167,
          0.00000,
          0,
          0,
          0.00000,
          0.24167,
          0.75833,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
      case 'Deuteranopia':
        // Matriz otimizada para deficiência no espectro verde (Deuteran)
        return <double>[
          0.62500,
          0.37500,
          0.00000,
          0,
          0,
          0.70000,
          0.30000,
          0.00000,
          0,
          0,
          0.00000,
          0.30000,
          0.70000,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
      case 'Tritanopia':
        // Matriz otimizada para deficiência no espectro azul (Tritan)
        return <double>[
          0.95000,
          0.05000,
          0.00000,
          0,
          0,
          0.00000,
          0.43333,
          0.56667,
          0,
          0,
          0.00000,
          0.47500,
          0.52500,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
      case 'Desativado':
      default:
        return null;
    }
  }
}
