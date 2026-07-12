import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:artisan_gift_manager/core/widgets/main_layout.dart';
import 'package:artisan_gift_manager/features/login/presentation/screens/login_screen.dart';
import 'package:artisan_gift_manager/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:artisan_gift_manager/features/pos/presentation/screens/pos_screen.dart';
import 'package:artisan_gift_manager/features/inventory/presentation/screens/products_screen.dart';
import 'package:artisan_gift_manager/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:artisan_gift_manager/features/customers_debts/presentation/screens/customers_screen.dart';
import 'package:artisan_gift_manager/features/suppliers_purchasing/presentation/screens/suppliers_screen.dart';
import 'package:artisan_gift_manager/features/reports/presentation/screens/reports_screen.dart';
import 'package:artisan_gift_manager/features/settings/presentation/screens/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    // Login Screen (outside ShellRoute)
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    // Main App with Navigation Rail Sidebar
    ShellRoute(
      builder: (context, state, child) {
        return MainLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/pos',
          builder: (context, state) => const POSScreen(),
        ),
        GoRoute(
          path: '/products',
          builder: (context, state) => const ProductsScreen(),
        ),
        GoRoute(
          path: '/inventory',
          builder: (context, state) => const InventoryScreen(),
        ),
        GoRoute(
          path: '/customers',
          builder: (context, state) => const CustomersScreen(),
        ),
        GoRoute(
          path: '/suppliers',
          builder: (context, state) => const SuppliersScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
