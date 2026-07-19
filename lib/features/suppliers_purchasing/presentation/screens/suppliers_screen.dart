import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/entity_form_dialog.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/search_bar_with_action.dart';
import 'package:small_mall/core/widgets/split_pane_layout.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/cubit/suppliers_purchasing_cubit.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/cubit/suppliers_purchasing_state.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/widgets/record_purchase_panel.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/widgets/suppliers_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.danger),
            );
          } else if (state is SuppliersPurchasingLoaded) {
            _loadProducts();
          }
        },
        builder: (context, state) {
          final cubit = context.read<SuppliersPurchasingCubit>();

          return AppScreenScaffold(
            title: 'الموردون والمشتريات',
            onRefresh: () => cubit.loadSuppliers(),
            body: SplitPaneLayout(
              leftChild: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SearchBarWithAction(
                      searchLabel: 'بحث عن مورد',
                      searchHint: 'ابحث بالاسم...',
                      searchController: _searchController,
                      onSearchChanged: (val) => _searchQuery = val,
                      actionLabel: 'إضافة مورد',
                      actionIcon: Icons.local_shipping,
                      onActionPressed: () => _showAddSupplierDialog(context, cubit),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildSuppliersList(context, cubit, state)),
                  ],
                ),
              ),
              rightChild: _buildRecordPurchasePanel(context, cubit, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuppliersList(BuildContext context, SuppliersPurchasingCubit cubit, SuppliersPurchasingState state) {
    if (state is SuppliersPurchasingLoading) {
      return const LoadingIndicator(message: 'جاري تحميل الموردين...');
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

  Widget _buildRecordPurchasePanel(BuildContext context, SuppliersPurchasingCubit cubit, SuppliersPurchasingState state) {
    if (_selectedSupplier == null) {
      return const Center(child: Text('اختر مورداً من القائمة للبدء بتسجيل فاتورة مشتريات'));
    }

    final supplier = _selectedSupplier!;
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              Text(
                supplier.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showEditSupplierDialog(context, cubit, supplier),
                child: const Icon(Icons.edit, size: 18, color: AppColors.primary),
              ),
            ],
          ),
        ),
        Expanded(
          child: RecordPurchasePanel(
            selectedSupplier: supplier,
            availableProducts: _availableProducts,
            onConfirmPurchase: (items, totalAmount) async {
              await cubit.recordPurchase(
                supplierId: supplier.id,
                totalAmount: totalAmount,
                items: items,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تسجيل فاتورة المشتريات وتحديث مخزون المنتجات بنجاح')),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  void _showEditSupplierDialog(BuildContext context, SuppliersPurchasingCubit cubit, Supplier supplier) {
    final nameController = TextEditingController(text: supplier.name);
    final phoneController = TextEditingController(text: supplier.phone);
    final notesController = TextEditingController(text: supplier.notes);

    showDialog(
      context: context,
      builder: (_) => EntityFormDialog(
        title: 'تعديل بيانات المورد',
        saveLabel: 'حفظ التعديلات',
        nameLabel: 'اسم المورد *',
        notesLabel: 'ملاحظات / البضائع',
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
        title: 'إضافة مورد جديد',
        saveLabel: 'حفظ المورد',
        nameLabel: 'اسم المورد *',
        notesLabel: 'ملاحظات / البضائع',
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
