import 'package:conectamarket/screens/products_list_screen.dart';
import 'package:conectamarket/screens/dashboard_screen.dart';
import 'package:conectamarket/screens/receipts_list.dart';
import 'package:conectamarket/screens/product_details_screen.dart';
import 'package:conectamarket/screens/csvimportscreen.dart';
import 'package:conectamarket/screens/receipt_details_screen.dart';
import 'package:conectamarket/screens/provider_list_screen.dart';
import 'package:conectamarket/screens/sunat_export_screen.dart';
import 'package:conectamarket/models/products_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/widgets_global/navigation_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

final GoRouter router = GoRouter(
  initialLocation: '/catalog',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        // Aquí encapsulas tu estructura global
        return Scaffold(
          body: child, // El contenido cambia dinámicamente
          bottomNavigationBar: NavigationBarWidget(
            currentIndex: _calculateIndex(context),
            onTap: (index) => _onItemTapped(index, context),
          ),
        );
      },
      routes: [
        GoRoute(path: '/catalog', builder: (context, state) => CatalogScreen()),
        GoRoute(path: '/dashboard', builder: (context, state) => DashboardScreen()),
        GoRoute(path: '/receipts', builder: (context, state) => ReceiptListScreen()),
        GoRoute(path: '/providers', builder: (context, state) => ProviderListScreen()),
      ],
    ),
    GoRoute(
      path: '/product-details',
      builder: (context, state) {
        final product = state.extra as Product?;
        return ProductDetailsScreen(product: product);
      },
    ),
    GoRoute(
      path: '/import-csv',
      builder: (context, state) => const ImportCsvScreen(),
    ),
    GoRoute(
      path: '/receipt-form',
      builder: (context, state) {
        final receipt = state.extra as Receipt?;
        return ReceiptDetailsScreen(receipt: receipt);
      },
    ),
    GoRoute(
      path: '/sunat-export',
      builder: (context, state) => const SunatExportScreen(),
    ),
  ],
);

// Lógica auxiliar para manejar los índices
int _calculateIndex(BuildContext context) {
  final String location = GoRouterState.of(context).uri.path;
  if (location.startsWith('/catalog')) return 0;
  if (location.startsWith('/dashboard')) return 1;
  if (location.startsWith('/receipts')) return 2;
  if (location.startsWith('/providers')) return 3;
  return 0;
}

void _onItemTapped(int index, BuildContext context) {
  switch (index) {
    case 0: context.go('/catalog'); break;
    case 1: context.go('/dashboard'); break;
    case 2: context.go('/receipts'); break;
    case 3: context.go('/providers'); break;
  }
}