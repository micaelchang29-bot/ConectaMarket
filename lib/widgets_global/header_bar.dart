import 'package:flutter/material.dart';

class HeaderBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isSynced;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final int? badgeCount;
  final bool showBackButton;

  const HeaderBarWidget({
    super.key,
    required this.title,
    this.isSynced = true,
    this.onBack,
    this.actions,
    this.badgeCount,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: showBackButton,
      leading: showBackButton 
        ? IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF005440)),
            onPressed: onBack ?? () => Navigator.pop(context),
          )
        : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF005440),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          if (badgeCount != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE7E8E9),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                badgeCount.toString(),
                style: const TextStyle(
                  color: Color(0xFF3F4944),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (actions != null) ...actions!,
        // Comentamos o quitamos el chip "Sincronizado" si no se requiere, 
        // pero lo mantenemos por compatibilidad y para no romper otras vistas.
        /* 
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Chip(
            backgroundColor: isSynced ? Colors.green[50] : Colors.orange[50],
            avatar: Icon(
              isSynced ? Icons.check_circle : Icons.cloud_off,
              color: isSynced ? Colors.green : Colors.orange,
              size: 18,
            ),
            label: Text(
              isSynced ? "Sincronizado" : "Local",
              style: TextStyle(
                color: isSynced ? Colors.green[800] : Colors.orange[800],
                fontSize: 12,
              ),
            ),
          ),
        ),
        */
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
