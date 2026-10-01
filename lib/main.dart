import 'package:conectamarket/repositories/database_helper.dart';
import 'package:conectamarket/services/auth_service.dart';
import 'package:conectamarket/services/bodega_backfill_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:conectamarket/navigation/router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await DatabaseHelper.instance.database;

  // Backfillea bodega_id en el historial que quedó en NULL antes de que el
  // estampado en el alta existiera (ver los *_repository.dart). Se dispara
  // en cada emisión de sesión activa del stream de Auth: cubre tanto el
  // arranque con una sesión ya persistida (authStateChanges la resuelve de
  // forma asíncrona, por eso no se lee currentUser una sola vez acá arriba)
  // como un login explícito más adelante. No se espera (sin `await`): es
  // una corrección en segundo plano, nunca debe bloquear el arranque de la
  // UI ni el login — BodegaBackfillService ya garantiza no lanzar.
  AuthService.instance.userStream.listen((user) {
    if (user != null) {
      BodegaBackfillService().runForBodega(user.uid);
    }
  });

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