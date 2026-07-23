import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/features/customers_debts/data/customers_debts_repository.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';
import 'package:small_mall/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> setupDependencyInjection() async {
  // Logger (Singleton)
  final logger = AppLogger();
  getIt.registerSingleton<AppLogger>(logger);

  // Database (Singleton)
  final database = AppDatabase();
  getIt.registerSingleton<AppDatabase>(database);

  // Sync Service (Singleton)
  final syncService = SyncService(database, logger);
  getIt.registerSingleton<SyncService>(syncService);

  // Repositories
  getIt.registerLazySingleton<InventoryRepository>(() => InventoryRepository(database, syncService, logger));
  getIt.registerLazySingleton<POSRepository>(() => POSRepository(database, syncService, logger));
  getIt.registerLazySingleton<CustomersDebtsRepository>(() => CustomersDebtsRepository(database, syncService, logger));
  getIt.registerLazySingleton<SuppliersPurchasingRepository>(() => SuppliersPurchasingRepository(database, syncService, logger));
  getIt.registerLazySingleton<ReportsRepository>(() => ReportsRepository(database, logger));

  // Initialize Sync Service
  await syncService.initialize();
}

