import 'package:artisan_gift_manager/core/database/app_database.dart';
import 'package:artisan_gift_manager/core/di/injection.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/widgets/app_text_field.dart';
import 'package:artisan_gift_manager/core/widgets/loading_indicator.dart';
import 'package:artisan_gift_manager/core/widgets/primary_button.dart';
import 'package:artisan_gift_manager/features/inventory/data/inventory_repository.dart';
import 'package:artisan_gift_manager/features/inventory/presentation/cubit/inventory_cubit.dart';
import 'package:artisan_gift_manager/features/inventory/presentation/cubit/inventory_state.dart';
import 'package:artisan_gift_manager/features/inventory/presentation/widgets/products_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider<InventoryCubit>(
      create: (context) => InventoryCubit(getIt<InventoryRepository>())..loadInventory(),
      child: BlocConsumer<InventoryCubit, InventoryState>(
        listener: (context, state) {
          if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.danger),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<InventoryCubit>();

          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              title: Text(
                'المنتجات',
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
                  onPressed: () => cubit.loadInventory(),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search and Actions Bar
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'بحث عن منتج',
                          hint: 'ابحث بالاسم...',
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Padding(
                        padding: const EdgeInsets.only(top: 22.0),
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showAddCategoryDialog(context, cubit),
                              icon: const Icon(Icons.category_outlined, color: AppColors.primary),
                              label: const Text('إضافة فئة جديدة', style: TextStyle(color: AppColors.primary)),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                            const SizedBox(width: 12),
                            PrimaryButton(
                              label: 'إضافة منتج جديد',
                              icon: Icons.add,
                              onPressed: () {
                                if (state is InventoryLoaded) {
                                  _showProductFormDialog(context, cubit, state.categories);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Table or List
                  Expanded(
                    child: _buildBody(context, cubit, state),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, InventoryCubit cubit, InventoryState state) {
    if (state is InventoryLoading) {
      return const LoadingIndicator(message: 'جاري تحميل قائمة المنتجات...');
    }

    if (state is InventoryLoaded) {
      return ProductsTable(
        products: state.products,
        searchQuery: _searchQuery,
        onEditProduct: (item) => _showProductFormDialog(context, cubit, state.categories, existing: item),
        onDeleteProduct: (item) => _showDeleteConfirmDialog(context, cubit, item),
      );
    }

    return const SizedBox();
  }

  void _showAddCategoryDialog(BuildContext context, InventoryCubit cubit) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة فئة جديدة', style: TextStyle(fontFamily: 'ElMessiri', color: AppColors.primary)),
            content: Form(
              key: formKey,
              child: AppTextField(
                label: 'اسم الفئة *',
                controller: controller,
                validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال اسم الفئة' : null,
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              PrimaryButton(
                label: 'حفظ الفئة',
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    cubit.addCategory(controller.text);
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

  void _showProductFormDialog(
    BuildContext context,
    InventoryCubit cubit,
    List<Category> categories, {
    ProductWithDetails? existing,
  }) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.product.name ?? '');
    final costController = TextEditingController(text: existing?.product.costPrice.toString() ?? '');
    final minStockController = TextEditingController(text: existing?.product.minStockAlert.toString() ?? '5');
    final initialStockController = TextEditingController(text: '0');

    String? selectedCatId = existing?.product.categoryId;
    final retail = existing?.prices.firstWhere((p) => p.priceLabel == 'retail',
        orElse: () => ProductPrice(id: '', productId: '', priceLabel: 'retail', priceValue: 0.0));
    final wholesale = existing?.prices.firstWhere((p) => p.priceLabel == 'wholesale',
        orElse: () => ProductPrice(id: '', productId: '', priceLabel: 'wholesale', priceValue: 0.0));
    final promo = existing?.prices.firstWhere((p) => p.priceLabel == 'promo',
        orElse: () => ProductPrice(id: '', productId: '', priceLabel: 'promo', priceValue: 0.0));

    final retailController = TextEditingController(text: retail?.priceValue.toString() ?? '');
    final wholesaleController = TextEditingController(text: wholesale?.priceValue.toString() ?? '');
    final promoController = TextEditingController(text: promo?.priceValue.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(existing == null ? 'إضافة منتج جديد' : 'تعديل منتج',
                style: const TextStyle(fontFamily: 'ElMessiri', color: AppColors.primary)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'اسم المنتج *',
                        controller: nameController,
                        validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال الاسم' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCatId,
                        hint: const Text('اختر فئة'),
                        decoration: InputDecoration(
                          labelText: 'الفئة',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        items: categories.map((c) {
                          return DropdownMenuItem(value: c.id, child: Text(c.name));
                        }).toList(),
                        onChanged: (val) {
                          selectedCatId = val;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              label: 'سعر التكلفة *',
                              controller: costController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              label: 'تنبيه الحد الأدنى للمخزون *',
                              controller: minStockController,
                              keyboardType: TextInputType.number,
                              validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
                            ),
                          ),
                        ],
                      ),
                      if (existing == null) ...[
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'المخزون الافتتاحي الأولي',
                          controller: initialStockController,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Divider(color: AppColors.border),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'أسعار البيع',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              label: 'سعر المفرق *',
                              controller: retailController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              label: 'سعر الجملة *',
                              controller: wholesaleController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'سعر ترويجي / عرض (اختياري)',
                        controller: promoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              PrimaryButton(
                label: 'حفظ المنتج',
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    final prices = [
                      {'price_label': 'retail', 'price_value': double.parse(retailController.text)},
                      {'price_label': 'wholesale', 'price_value': double.parse(wholesaleController.text)},
                    ];
                    if (promoController.text.isNotEmpty) {
                      prices.add({'price_label': 'promo', 'price_value': double.parse(promoController.text)});
                    }

                    if (existing == null) {
                      cubit.addProduct(
                        name: nameController.text,
                        categoryId: selectedCatId,
                        costPrice: double.parse(costController.text),
                        minStockAlert: double.parse(minStockController.text),
                        prices: prices,
                        initialStock: double.parse(initialStockController.text),
                      );
                    } else {
                      cubit.updateProduct(
                        id: existing.product.id,
                        name: nameController.text,
                        categoryId: selectedCatId,
                        costPrice: double.parse(costController.text),
                        minStockAlert: double.parse(minStockController.text),
                        prices: prices,
                      );
                    }
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

  void _showDeleteConfirmDialog(BuildContext context, InventoryCubit cubit, ProductWithDetails item) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف المنتج', style: TextStyle(color: AppColors.danger)),
            content: Text('هل أنت متأكد من رغبتك في حذف المنتج "${item.product.name}"؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              PrimaryButton(
                label: 'تأكيد الحذف',
                backgroundColor: AppColors.danger,
                onPressed: () {
                  cubit.deleteProduct(item.product.id);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
