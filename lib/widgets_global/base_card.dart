import 'package:flutter/material.dart';

class BaseCardWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final String priceOrStatus;
  final String? statusLabel;
  final Color? statusColor;
  final VoidCallback onTap;

  const BaseCardWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.priceOrStatus,
    this.statusLabel,
    this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(priceOrStatus, style: TextStyle(color: Colors.teal[800])),
            if (statusLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: statusColor?.withOpacity(0.2),
                child: Text(statusLabel!, style: TextStyle(fontSize: 10, color: statusColor)),
              ),
          ],
        ),
      ),
    );
  }
}