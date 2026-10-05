import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cogito/common/constant/app_colors.dart';
import 'app.dart';

/// Ponto de entrada principal do aplicativo Flutter.
void main() async {
  // Garante que o binding de widgets esteja inicializado antes de chamar recursos nativos da plataforma.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase com tratamento de erro seguro para evitar crash nativo na inicialização.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Aviso: Erro ao inicializar o Firebase: $e');
  }

  // Configura a interface do sistema (Android/iOS) para preencher a tela com a barra de status azul sólida
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(AppColors.statusBarStyle);

  // Inicializa a árvore de widgets da aplicação chamando a classe raiz App.
  runApp(const App());
}
