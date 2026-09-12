import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/entity_form_dialog.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/search_bar_with_action.dart';
import 'package:small_mall/core/widgets/split_pane_layout.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/cubit/suppliers_purchasing_cubit.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/cubit/suppliers_purchasing_state.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/widgets/supplier_operations_panel.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/widgets/suppliers_list.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Purchase Form State
  Supplier? _selectedSupplier;
  final _inventoryRepo = getIt<InventoryRepository>();
  List<ProductWithDetails> _availableProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final list = await _inventoryRepo.getProducts();
    setState(() {
      _availableProducts = list.where((p) => p.product.isActive).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SuppliersPurchasingCubit>(
      create: (context) => SuppliersPurchasingCubit(getIt<SuppliersPurchasingRepository>())..loadSuppliers(),
      child: BlocConsumer<SuppliersPurchasingCubit, SuppliersPurchasingState>(
        listener: (context, state) {
          if (state is SuppliersPurchasingError) {
            AppToast.error(context, message: state.message);
          } else if (state is SuppliersPurchasingLoaded) {
            if (state.errorMessage != null) {
              AppToast.error(context, message: state.errorMessage!);
            }
            _loadProducts();
          }
        },
        builder: (context, state) {
          final cubit = context.read<SuppliersPurchasingCubit>();

          return AppScreenScaffold(
            title: 'suppliers.title'.tr(),
            onRefresh: () => cubit.loadSuppliers(),
            body: SplitPaneLayout(
              leftChild: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SearchBarWithAction(
                      searchLabel: 'suppliers.supplier_name'.tr(),
                      searchHint: 'common.search'.tr(),
                      searchController: _searchController,
                      onSearchChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      actionLabel: 'suppliers.add_supplier'.tr(),
                      actionIcon: Icons.local_shipping,
                      onActionPressed: () => _showAddSupplierDialog(context, cubit),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildSuppliersList(context, cubit, state)),
                  ],
                ),
              ),
              rightChild: _buildRightPanel(context, cubit, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuppliersList(BuildContext context, SuppliersPurchasingCubit cubit, SuppliersPurchasingState state) {
    if (state is SuppliersPurchasingLoading) {
      return LoadingIndicator(message: 'common.loading'.tr());
    }

    if (state is SuppliersPurchasingLoaded) {
      return SuppliersList(
        suppliers: state.suppliers,
        selectedSupplierId: _selectedSupplier?.id,
        searchQuery: _searchQuery,
        onSelectSupplier: (supplier) {
          setState(() {
            _selectedSupplier = supplier;
          });
        },
      );
    }

    return const SizedBox();
  }

  Widget _buildRightPanel(BuildContext context, SuppliersPurchasingCubit cubit, SuppliersPurchasingState state) {
    if (_selectedSupplier == null) {
      return Center(
        child: EmptyStateView(
          icon: Icons.local_shipping_outlined,
          title: 'suppliers.purchase_invoices'.tr(),
          description: 'suppliers.select_supplier_to_view'.tr(),
        ),
      );
    }

    // Resolve up-to-date supplier if updated in cubit state
    Supplier supplier = _selectedSupplier!;
    if (state is SuppliersPurchasingLoaded) {
      final updated = state.suppliers.where((s) => s.supplier.id == supplier.id).toList();
      if (updated.isNotEmpty) {
        supplier = updated.first.supplier;
      }
    }

    return SupplierOperationsPanel(
      key: ValueKey(supplier.id),
      supplier: supplier,
      availableProducts: _availableProducts,
      onEditSupplier: () => _showEditSupplierDialog(context, cubit, supplier),
    );
  }

  void _showEditSupplierDialog(BuildContext context, SuppliersPurchasingCubit cubit, Supplier supplier) {
    final nameController = TextEditingController(text: supplier.name);
    final phoneController = TextEditingController(text: supplier.phone);
    final notesController = TextEditingController(text: supplier.notes);

    showDialog(
      context: context,
      builder: (_) => EntityFormDialog(
        title: 'suppliers.edit_supplier'.tr(),
        saveLabel: 'common.save'.tr(),
        nameLabel: 'suppliers.supplier_name'.tr(),
        notesLabel: 'common.notes'.tr(),
        nameController: nameController,
        phoneController: phoneController,
        notesController: notesController,
        onSave: () async {
          await cubit.updateSupplier(
            id: supplier.id,
            name: nameController.text,
            phone: phoneController.text.isNotEmpty ? phoneController.text : null,
            notes: notesController.text.isNotEmpty ? notesController.text : null,
          );
        },
      ),
    );
  }

  void _showAddSupplierDialog(BuildContext context, SuppliersPurchasingCubit cubit) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => EntityFormDialog(
        title: 'suppliers.add_supplier'.tr(),
        saveLabel: 'common.save'.tr(),
        nameLabel: 'suppliers.supplier_name'.tr(),
        notesLabel: 'common.notes'.tr(),
        nameController: nameController,
        phoneController: phoneController,
        notesController: notesController,
        onSave: () async {
          await cubit.addSupplier(
            name: nameController.text,
            phone: phoneController.text.isNotEmpty ? phoneController.text : null,
            notes: notesController.text.isNotEmpty ? notesController.text : null,
          );
        },
      ),
    );
  }
}
