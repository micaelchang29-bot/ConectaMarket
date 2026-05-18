import 'package:conectamarket/repositories/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:conectamarket/screens/router.dart'; // Asegura esta ruta

void main() async{
// 1. Asegura que los bindings de Flutter estén listos
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializa la base de datos antes de arrancar la App
  await DatabaseHelper.instance.database;

  runApp(const ConectaMarketApp());
}

class ConectaMarketApp extends StatelessWidget {
  const ConectaMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ConectaMarket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005440)),
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: const Color(0xFF3F4944),
          displayColor: const Color(0xFF3F4944),
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}