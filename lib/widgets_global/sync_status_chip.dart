import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../utils/mensajes_error.dart';

/// Etiqueta del dashboard: gris "Sin sincronizar" o verde "Synced · fecha".
class SyncStatusChip extends StatefulWidget {
  const SyncStatusChip({super.key});

  @override
  State<SyncStatusChip> createState() => _SyncStatusChipState();
}

class _SyncStatusChipState extends State<SyncStatusChip> {
  StreamSubscription<User?>? _sub;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = AuthService.instance.currentUser;
    SyncService.instance.cargarUltimoRespaldo(_user?.uid);
    _sub = AuthService.instance.userStream.listen((u) {
      if (!mounted) return;
      setState(() => _user = u);
      SyncService.instance.cargarUltimoRespaldo(u?.uid);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: SyncService.instance.ultimoRespaldo,
      builder: (context, ultimo, _) {
        final estado = estadoEtiquetaSync(autenticado: _user != null, ultimoRespaldo: ultimo);
        final ok = estado.sincronizado;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: ok ? const Color(0xFFE8F5E9) : const Color(0xFFF1F3F4),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: ok ? const Color(0xFFC8E6C9) : const Color(0xFFDADCE0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ok ? const Color(0xFF4CAF50) : const Color(0xFF9AA0A6),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                estado.texto,
                style: TextStyle(
                  color: ok ? const Color(0xFF2E7D32) : const Color(0xFF5F6368),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
