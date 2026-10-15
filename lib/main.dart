import 'package:flutter/material.dart';
import 'core/database/database_helper.dart';
import 'core/theme/app_theme.dart';
import 'views/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-calentar la base de datos al arrancar (Maneja plataformas nativas y web automáticamente)
  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint('Error al inicializar BD al arrancar: $e');
  }

  runApp(const LaCasaDeLosPerrosApp());
}

class LaCasaDeLosPerrosApp extends StatelessWidget {
  const LaCasaDeLosPerrosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'La Casa de los Perros POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}
