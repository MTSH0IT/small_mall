import 'package:artisan_gift_manager/core/database/app_database.dart';
import 'package:artisan_gift_manager/core/di/injection.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/widgets/app_text_field.dart';
import 'package:artisan_gift_manager/core/widgets/loading_indicator.dart';
import 'package:artisan_gift_manager/core/widgets/primary_button.dart';
import 'package:artisan_gift_manager/features/inventory/data/inventory_repository.dart';
import 'package:artisan_gift_manager/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';
import 'package:artisan_gift_manager/features/suppliers_purchasing/presentation/cubit/suppliers_purchasing_cubit.dart';
import 'package:artisan_gift_manager/features/suppliers_purchasing/presentation/widgets/record_purchase_panel.dart';
import 'package:artisan_gift_manager/features/suppliers_purchasing/presentation/widgets/suppliers_list.dart';
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
    final theme = Theme.of(context);

    return BlocProvider<SuppliersPurchasingCubit>(
      create: (context) => SuppliersPurchasingCubit(getIt<SuppliersPurchasingRepository>())..loadSuppliers(),
      child: BlocConsumer<SuppliersPurchasingCubit, SuppliersPurchasingState>(
        listener: (context, state) {
          if (state is SuppliersPurchasingError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.danger),
            );
          } else if (state is SuppliersPurchasingLoaded) {
            _loadProducts(); // Sync products list in case cost changed
          }
        },
        builder: (context, state) {
          final cubit = context.read<SuppliersPurchasingCubit>();

          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              title: Text(
                'الموردون والمشتريات',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontFamily: 'ElMessiri',
                  color: AppColors.primary,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  onPressed: () => cubit.loadSuppliers(),
                ),
              ],
            ),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Right Pane: Suppliers List (40% width)
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: 'بحث عن مورد',
                                hint: 'ابحث بالاسم...',
                                controller: _searchController,
                                onChanged: (val) {
                                  setState(() => _searchQuery = val);
                                },
                                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 22.0),
                              child: PrimaryButton(
                                label: 'إضافة مورد',
                                icon: Icons.local_shipping,
                                onPressed: () => _showAddSupplierDialog(context, cubit),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _buildSuppliersList(context, cubit, state),
                        ),
                      ],
                    ),
                  ),
                ),
                // Divider
                const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
                // Left Pane: Record Purchase (60% width)
                Expanded(
                  flex: 3,
                  child: _buildRecordPurchasePanel(context, cubit, state),
                ),
              ],
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

    return RecordPurchasePanel(
      selectedSupplier: _selectedSupplier!,
      availableProducts: _availableProducts,
      onConfirmPurchase: (items, totalAmount) async {
        await cubit.recordPurchase(
          supplierId: _selectedSupplier!.id,
          totalAmount: totalAmount,
          items: items,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تسجيل فاتورة المشتريات وتحديث مخزون المنتجات بنجاح')),
          );
        }
      },
    );
  }

  void _showAddSupplierDialog(BuildContext context, SuppliersPurchasingCubit cubit) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة مورد جديد', style: TextStyle(fontFamily: 'ElMessiri', color: AppColors.primary)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    label: 'اسم المورد *',
                    controller: nameController,
                    validator: (val) => val == null || val.isEmpty ? 'الرجاء إدخال الاسم' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'رقم الهاتف',
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'ملاحظات / البضائع',
                    controller: notesController,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              PrimaryButton(
                label: 'حفظ المورد',
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    cubit.addSupplier(
                      name: nameController.text,
                      phone: phoneController.text.isNotEmpty ? phoneController.text : null,
                      notes: notesController.text.isNotEmpty ? notesController.text : null,
                    );
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
