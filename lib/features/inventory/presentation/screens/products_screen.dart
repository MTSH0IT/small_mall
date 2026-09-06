import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/inventory/presentation/cubit/inventory_cubit.dart';
import 'package:small_mall/features/inventory/presentation/cubit/inventory_state.dart';
import 'package:small_mall/features/inventory/presentation/widgets/products_table.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InventoryCubit>(
      create: (context) => InventoryCubit(getIt<InventoryRepository>())..loadInventory(),
      child: BlocConsumer<InventoryCubit, InventoryState>(
        listener: (context, state) {
          if (state is InventoryError) {
            AppToast.error(context, message: state.message);
          } else if (state is InventoryLoaded && state.errorMessage != null) {
            AppToast.error(context, message: state.errorMessage!);
          }
        },
        builder: (context, state) {
          final cubit = context.read<InventoryCubit>();

          return AppScreenScaffold(
            title: 'inventory.products_title'.tr(),
            onRefresh: () => cubit.loadInventory(),
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
                          label: 'common.search'.tr(),
                          hint: 'common.search'.tr(),
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
                              label: Text('inventory.categories'.tr(), style: const TextStyle(color: AppColors.primary)),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                            const SizedBox(width: 12),
                            PrimaryButton(
                              label: 'inventory.add_product'.tr(),
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
      return LoadingIndicator(message: 'inventory.loading_products'.tr());
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
        return BlocProvider.value(
          value: cubit,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: AppColors.surfaceElevated,
            child: Container(
              width: 480,
              constraints: const BoxConstraints(maxHeight: 520),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: Title and Close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.category_outlined, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'inventory.categories'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Add Category Input & Button
                  Form(
                    key: formKey,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: controller,
                            decoration: InputDecoration(
                              labelText: 'inventory.category_name'.tr(),
                              hintText: 'inventory.category_name'.tr(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              prefixIcon: const Icon(Icons.add_circle_outline, size: 20),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty
                                ? 'common.required_field'.tr()
                                : null,
                            onFieldSubmitted: (_) {
                              if (formKey.currentState?.validate() ?? false) {
                                cubit.addCategory(controller.text.trim());
                                controller.clear();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (formKey.currentState?.validate() ?? false) {
                                cubit.addCategory(controller.text.trim());
                                controller.clear();
                              }
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: Text('common.add'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 12),

                  // Existing Categories Title
                  BlocBuilder<InventoryCubit, InventoryState>(
                    builder: (context, state) {
                      final categories = state is InventoryLoaded ? state.categories : <Category>[];
                      return Text(
                        '${'inventory.existing_categories'.tr()} (${categories.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // Existing Categories List
                  Flexible(
                    child: BlocBuilder<InventoryCubit, InventoryState>(
                      builder: (context, state) {
                        if (state is! InventoryLoaded) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final categories = state.categories;
                        if (categories.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'inventory.no_categories'.tr(),
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          );
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(8),
                            itemCount: categories.length,
                            separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 1),
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final count = state.products.where((p) => p.product.categoryId == cat.id).length;

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.folder_outlined, size: 18, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        cat.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.border.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'inventory.products_count'.tr(args: [count.toString()]),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('common.close'.tr()),
                    ),
                  ),
                ],
              ),
            ),
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
        return AlertDialog(
          title: Text(existing == null ? 'inventory.add_product'.tr() : 'inventory.edit_product'.tr(),
              style: const TextStyle(color: AppColors.primary)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    AppTextField(
                      label: 'inventory.product_name'.tr(),
                      controller: nameController,
                      validator: (val) => val == null || val.isEmpty ? 'common.required_field'.tr() : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: categories.any((c) => c.id == selectedCatId) ? selectedCatId : null,
                      hint: Text('inventory.category'.tr()),
                      decoration: InputDecoration(
                        labelText: 'inventory.category'.tr(),
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
                            label: 'inventory.cost_price'.tr(),
                            controller: costController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) => val == null || val.isEmpty ? 'common.required_field'.tr() : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'inventory.alert_quantity'.tr(),
                            controller: minStockController,
                            keyboardType: TextInputType.number,
                            validator: (val) => val == null || val.isEmpty ? 'common.required_field'.tr() : null,
                          ),
                        ),
                      ],
                    ),
                    if (existing == null) ...[
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'inventory.initial_stock'.tr(),
                        controller: initialStockController,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.border),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'inventory.selling_prices'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'inventory.retail_price'.tr(),
                            controller: retailController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) => val == null || val.isEmpty ? 'common.required_field'.tr() : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'inventory.wholesale_price'.tr(),
                            controller: wholesaleController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) => val == null || val.isEmpty ? 'common.required_field'.tr() : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'inventory.promo_price'.tr(),
                      controller: promoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
            PrimaryButton(
              label: 'inventory.save_product'.tr(),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final retailPrice = double.tryParse(retailController.text) ?? 0.0;
                  final wholesalePrice = double.tryParse(wholesaleController.text) ?? 0.0;
                  final promoPrice = double.tryParse(promoController.text);
                  final costPrice = double.tryParse(costController.text) ?? 0.0;
                  final minStock = double.tryParse(minStockController.text) ?? 5.0;
                  final initialStock = double.tryParse(initialStockController.text) ?? 0.0;

                  final prices = [
                    {'price_label': 'retail', 'price_value': retailPrice},
                    {'price_label': 'wholesale', 'price_value': wholesalePrice},
                  ];
                  if (promoPrice != null && promoPrice > 0) {
                    prices.add({'price_label': 'promo', 'price_value': promoPrice});
                  }

                  if (existing == null) {
                    cubit.addProduct(
                      name: nameController.text,
                      categoryId: selectedCatId,
                      costPrice: costPrice,
                      minStockAlert: minStock,
                      prices: prices,
                      initialStock: initialStock,
                    );
                  } else {
                    cubit.updateProduct(
                      id: existing.product.id,
                      name: nameController.text,
                      categoryId: selectedCatId,
                      costPrice: costPrice,
                      minStockAlert: minStock,
                      prices: prices,
                    );
                  }
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, InventoryCubit cubit, ProductWithDetails item) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('inventory.delete_product'.tr(), style: const TextStyle(color: AppColors.danger)),
          content: Text('${'common.delete_warning'.tr()}\n(${item.product.name})'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
            PrimaryButton(
              label: 'common.confirm_delete'.tr(),
              backgroundColor: AppColors.danger,
              onPressed: () {
                cubit.deleteProduct(item.product.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        );
      },
    );
  }
}
