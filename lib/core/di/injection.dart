import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/features/customers_debts/data/customers_debts_repository.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';
import 'package:small_mall/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> setupDependencyInjection() async {
  // Database (Singleton)
  final database = AppDatabase();
  getIt.registerSingleton<AppDatabase>(database);

  // Sync Service (Singleton)
  final syncService = SyncService(database);
  getIt.registerSingleton<SyncService>(syncService);

  // Repositories
  getIt.registerLazySingleton<InventoryRepository>(() => InventoryRepository(database, syncService));
  getIt.registerLazySingleton<POSRepository>(() => POSRepository(database, syncService));
  getIt.registerLazySingleton<CustomersDebtsRepository>(() => CustomersDebtsRepository(database, syncService));
  getIt.registerLazySingleton<SuppliersPurchasingRepository>(() => SuppliersPurchasingRepository(database, syncService));
  getIt.registerLazySingleton<ReportsRepository>(() => ReportsRepository(database));

  // Initialize Sync Service
  await syncService.initialize();
}

