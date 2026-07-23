import 'package:small_mall/core/widgets/main_layout.dart';
import 'package:small_mall/features/customers_debts/presentation/screens/customers_screen.dart';
import 'package:small_mall/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:small_mall/features/inventory/presentation/screens/products_screen.dart';
import 'package:small_mall/features/invoices/presentation/screens/invoices_screen.dart';
import 'package:small_mall/features/login/presentation/screens/login_screen.dart';
import 'package:small_mall/features/pos/presentation/screens/pos_screen.dart';
import 'package:small_mall/features/reports/presentation/screens/reports_screen.dart';
import 'package:small_mall/features/settings/presentation/screens/settings_screen.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/screens/suppliers_screen.dart';
import 'package:go_router/go_router.dart';

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
          path: '/invoices',
          builder: (context, state) => const InvoicesScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
