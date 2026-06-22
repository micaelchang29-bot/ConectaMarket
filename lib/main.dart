import 'package:conectamarket/repositories/database_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:conectamarket/navigation/router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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