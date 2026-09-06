import 'package:easy_localization/easy_localization.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/inventory/presentation/cubit/inventory_cubit.dart';
import 'package:small_mall/features/inventory/presentation/cubit/inventory_state.dart';
import 'package:small_mall/features/inventory/presentation/widgets/products_table.dart';
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
    return BlocProvider<InventoryCubit>(
      create: (context) => InventoryCubit(getIt<InventoryRepository>())..loadInventory(),
      child: BlocConsumer<InventoryCubit, InventoryState>(
        listener: (context, state) {
          if (state is InventoryError) {
            AppToast.error(context, message: state.message);
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
                              label: Text('inventory.add_category'.tr(), style: const TextStyle(color: AppColors.primary)),
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
        return AlertDialog(
          title: Text('inventory.add_category'.tr(), style: const TextStyle(color: AppColors.primary)),
          content: Form(
            key: formKey,
            child: AppTextField(
              label: 'inventory.category_name'.tr(),
              controller: controller,
              validator: (val) => val == null || val.isEmpty ? 'common.required_field'.tr() : null,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
            PrimaryButton(
              label: 'inventory.save_category'.tr(),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  cubit.addCategory(controller.text);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
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
                      initialValue: selectedCatId,
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
