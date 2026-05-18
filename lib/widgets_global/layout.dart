import 'package:conectamarket/widgets_global/header_bar.dart';
import 'package:conectamarket/widgets_global/navigation_bar.dart';
import 'package:flutter/material.dart';

class Layout extends StatelessWidget {
  final Widget body;
  final String title;
  final int currentIndex;

  const Layout({
    required this.body,
    required this.title,
    required this.currentIndex,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderBarWidget(title: title), 
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBarWidget( 
        currentIndex: currentIndex,
        onTap: (index) {
          // Lógica centralizada de navegación
        },
      ),
    );
  }
}