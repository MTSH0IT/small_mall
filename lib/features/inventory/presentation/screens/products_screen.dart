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
  String? _selectedCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategoryId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InventoryCubit>(
      create: (context) =>
          InventoryCubit(getIt<InventoryRepository>())..loadInventory(),
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

          // Validate selected category still exists if categories changed/deleted
          if (state is InventoryLoaded &&
              _selectedCategoryId != null &&
              _selectedCategoryId != '__uncategorized__' &&
              !state.categories.any((c) => c.id == _selectedCategoryId)) {
            _selectedCategoryId = null;
          }

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
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.textSecondary,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Padding(
                        padding: const EdgeInsets.only(top: 22.0),
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _showAddCategoryDialog(context, cubit),
                              icon: const Icon(
                                Icons.category_outlined,
                                color: AppColors.primary,
                              ),
                              label: Text(
                                'inventory.categories'.tr(),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            PrimaryButton(
                              label: 'inventory.add_product'.tr(),
                              icon: Icons.add,
                              onPressed: () {
                                if (state is InventoryLoaded) {
                                  _showProductFormDialog(
                                    context,
                                    cubit,
                                    state.categories,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Modern Category Filter Chips Strip
                  if (state is InventoryLoaded &&
                      (state.categories.isNotEmpty ||
                          state.products.any((p) => p.product.categoryId == null))) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // "All" / "كل الأصناف" Chip
                          _buildCategoryChip(
                            label: 'inventory.all_categories'.tr(),
                            count: state.products.length,
                            isSelected: _selectedCategoryId == null,
                            onTap: () => setState(() => _selectedCategoryId = null),
                          ),
                          // Specific Category Chips
                          ...state.categories.map((cat) {
                            final count = state.products
                                .where((p) => p.product.categoryId == cat.id)
                                .length;
                            return Padding(
                              padding: const EdgeInsetsDirectional.only(start: 8.0),
                              child: _buildCategoryChip(
                                label: cat.name,
                                count: count,
                                isSelected: _selectedCategoryId == cat.id,
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryId =
                                        _selectedCategoryId == cat.id ? null : cat.id;
                                  });
                                },
                              ),
                            );
                          }),
                          // Uncategorized products chip (if any exist)
                          if (state.products.any((p) => p.product.categoryId == null)) ...[
                            Padding(
                              padding: const EdgeInsetsDirectional.only(start: 8.0),
                              child: _buildCategoryChip(
                                label: 'inventory.uncategorized'.tr(),
                                count: state.products
                                    .where((p) => p.product.categoryId == null)
                                    .length,
                                isSelected: _selectedCategoryId == '__uncategorized__',
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryId =
                                        _selectedCategoryId == '__uncategorized__'
                                            ? null
                                            : '__uncategorized__';
                                  });
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Table or List
                  Expanded(child: _buildBody(context, cubit, state)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    InventoryCubit cubit,
    InventoryState state,
  ) {
    if (state is InventoryLoading) {
      return LoadingIndicator(message: 'inventory.loading_products'.tr());
    }

    if (state is InventoryLoaded) {
      return ProductsTable(
        products: state.products,
        searchQuery: _searchQuery,
        selectedCategoryId: _selectedCategoryId,
        onResetFilters: _clearFilters,
        onEditProduct: (item) => _showProductFormDialog(
          context,
          cubit,
          state.categories,
          existing: item,
        ),
        onDeleteProduct: (item) =>
            _showDeleteConfirmDialog(context, cubit, item),
      );
    }

    return const SizedBox();
  }

  Widget _buildCategoryChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, InventoryCubit cubit) {
    final addController = TextEditingController();
    final searchController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return BlocProvider.value(
          value: cubit,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: AppColors.surfaceElevated,
                child: Container(
                  width: 520,
                  constraints: const BoxConstraints(maxHeight: 640),
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
                                child: const Icon(
                                  Icons.category_outlined,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
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
                            icon: const Icon(
                              Icons.close,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
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
                                controller: addController,
                                decoration: InputDecoration(
                                  labelText: 'inventory.category_name'.tr(),
                                  hintText: 'inventory.category_name'.tr(),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 20,
                                  ),
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                        ? 'common.required_field'.tr()
                                        : null,
                                onFieldSubmitted: (_) {
                                  if (formKey.currentState?.validate() ?? false) {
                                    cubit.addCategory(addController.text.trim());
                                    addController.clear();
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
                                    cubit.addCategory(addController.text.trim());
                                    addController.clear();
                                  }
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: Text('common.add'.tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Search Categories Bar
                      TextFormField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'inventory.search_categories'.tr(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchController.clear();
                                    setDialogState(() {
                                      searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            searchQuery = val.trim();
                          });
                        },
                      ),

                      const SizedBox(height: 14),

                      // Section Title (Existing categories / Search results)
                      BlocBuilder<InventoryCubit, InventoryState>(
                        builder: (context, state) {
                          final allCategories = state is InventoryLoaded
                              ? state.categories
                              : <Category>[];
                          final filtered = allCategories.where((c) {
                            if (searchQuery.isEmpty) return true;
                            return c.name
                                .toLowerCase()
                                .contains(searchQuery.toLowerCase());
                          }).toList();

                          final titleText = searchQuery.isEmpty
                              ? '${'inventory.existing_categories'.tr()} (${allCategories.length})'
                              : '${'inventory.existing_categories'.tr()} (${filtered.length} / ${allCategories.length})';

                          return Text(
                            titleText,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),

                      // Categories List
                      Flexible(
                        child: BlocBuilder<InventoryCubit, InventoryState>(
                          builder: (context, state) {
                            if (state is! InventoryLoaded) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final allCategories = state.categories;
                            final filteredCategories = allCategories.where((c) {
                              if (searchQuery.isEmpty) return true;
                              return c.name
                                  .toLowerCase()
                                  .contains(searchQuery.toLowerCase());
                            }).toList();

                            if (allCategories.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'inventory.no_categories'.tr(),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            }

                            if (filteredCategories.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.search_off_rounded,
                                        size: 36,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'inventory.no_matching_categories'.tr(),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
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
                                padding: const EdgeInsets.all(6),
                                itemCount: filteredCategories.length,
                                separatorBuilder: (_, _) => const Divider(
                                  color: AppColors.border,
                                  height: 1,
                                ),
                                itemBuilder: (context, index) {
                                  final cat = filteredCategories[index];
                                  final count = state.products
                                      .where((p) => p.product.categoryId == cat.id)
                                      .length;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.folder_outlined,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            cat.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.border.withValues(
                                              alpha: 0.5,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'inventory.products_count'.tr(
                                              args: [count.toString()],
                                            ),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),

                                        // Edit Button
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                          tooltip: 'inventory.edit_category'.tr(),
                                          splashRadius: 18,
                                          onPressed: () => _showEditCategoryDialog(
                                            context,
                                            cubit,
                                            cat,
                                          ),
                                        ),

                                        // Delete Button
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: AppColors.danger,
                                          ),
                                          tooltip: 'inventory.delete_category'.tr(),
                                          splashRadius: 18,
                                          onPressed: () => _showDeleteCategoryDialog(
                                            context,
                                            cubit,
                                            cat,
                                            count,
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
              );
            },
          ),
        );
      },
    );
  }

  void _showEditCategoryDialog(
    BuildContext context,
    InventoryCubit cubit,
    Category category,
  ) {
    final controller = TextEditingController(text: category.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'inventory.edit_category'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'inventory.category_name'.tr(),
                hintText: 'inventory.category_name'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'common.required_field'.tr()
                  : null,
              onFieldSubmitted: (_) {
                if (formKey.currentState?.validate() ?? false) {
                  final newName = controller.text.trim();
                  if (newName != category.name) {
                    cubit.updateCategory(category.id, newName);
                    AppToast.success(
                      context,
                      message: 'inventory.category_updated'.tr(),
                    );
                  }
                  Navigator.pop(ctx);
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'common.cancel'.tr(),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final newName = controller.text.trim();
                  if (newName != category.name) {
                    cubit.updateCategory(category.id, newName);
                    AppToast.success(
                      context,
                      message: 'inventory.category_updated'.tr(),
                    );
                  }
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('common.save'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteCategoryDialog(
    BuildContext context,
    InventoryCubit cubit,
    Category category,
    int productCount,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'inventory.delete_category_confirm_title'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          content: Text(
            productCount > 0
                ? 'inventory.delete_category_confirm_msg'.tr(
                    namedArgs: {
                      'name': category.name,
                      'count': productCount.toString(),
                    },
                  )
                : 'inventory.delete_category_confirm_msg_empty'.tr(
                    namedArgs: {'name': category.name},
                  ),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'common.cancel'.tr(),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                cubit.deleteCategory(category.id);
                AppToast.success(
                  context,
                  message: 'inventory.category_deleted'.tr(),
                );
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('common.delete'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showProductFormDialog(
    BuildContext context,
    InventoryCubit cubit,
    List<Category> categories, {
    ProductWithDetails? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nextSeq = existing == null ? await cubit.getNextSerialNumber() : null;
    final idController = TextEditingController(
      text: existing != null
          ? (existing.product.serialNumber?.toString() ?? '')
          : (nextSeq?.toString() ?? '1'),
    );
    final codeController = TextEditingController(
      text: existing?.product.code ?? '',
    );
    final nameController = TextEditingController(
      text: existing?.product.name ?? '',
    );
    final costController = TextEditingController(
      text: existing?.product.costPrice.toString() ?? '',
    );
    final minStockController = TextEditingController(
      text: existing?.product.minStockAlert.toString() ?? '5',
    );
    final initialStockController = TextEditingController(text: '0');

    String? selectedCatId = existing?.product.categoryId;
    final retail = existing?.prices.firstWhere(
      (p) => p.priceLabel == 'retail',
      orElse: () => ProductPrice(
        id: '',
        productId: '',
        priceLabel: 'retail',
        priceValue: 0.0,
      ),
    );
    final wholesale = existing?.prices.firstWhere(
      (p) => p.priceLabel == 'wholesale',
      orElse: () => ProductPrice(
        id: '',
        productId: '',
        priceLabel: 'wholesale',
        priceValue: 0.0,
      ),
    );
    final promo = existing?.prices.firstWhere(
      (p) => p.priceLabel == 'promo',
      orElse: () => ProductPrice(
        id: '',
        productId: '',
        priceLabel: 'promo',
        priceValue: 0.0,
      ),
    );

    final retailController = TextEditingController(
      text: retail?.priceValue.toString() ?? '',
    );
    final wholesaleController = TextEditingController(
      text: wholesale?.priceValue.toString() ?? '',
    );
    final promoController = TextEditingController(
      text: promo?.priceValue.toString() ?? '',
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                existing == null
                    ? 'inventory.add_product'.tr()
                    : 'inventory.edit_product'.tr(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (existing != null)
                IconButton(
                  tooltip: 'inventory.delete_product'.tr(),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirmDialog(context, cubit, existing);
                  },
                ),
            ],
          ),
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
                      validator: (val) => val == null || val.isEmpty
                          ? 'common.required_field'.tr()
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'inventory.product_id'.tr(),
                            controller: idController,
                            hint: '1, 2, 3...',
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(
                              Icons.tag_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            suffixIcon: existing == null
                                ? IconButton(
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    tooltip: 'inventory.auto_generate_id'.tr(),
                                    onPressed: () async {
                                      final seq = await cubit.getNextSerialNumber();
                                      idController.text = seq.toString();
                                    },
                                  )
                                : null,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'common.required_field'.tr();
                              }
                              if (int.tryParse(val.trim()) == null) {
                                return 'common.numeric_only'.tr();
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'inventory.product_code'.tr(),
                            controller: codeController,
                            hint: 'inventory.code_hint'.tr(),
                            prefixIcon: const Icon(
                              Icons.qr_code_scanner_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: categories.any((c) => c.id == selectedCatId)
                          ? selectedCatId
                          : null,
                      hint: Text('inventory.category'.tr()),
                      decoration: InputDecoration(
                        labelText: 'inventory.category'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      items: categories.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        );
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
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (val) => val == null || val.isEmpty
                                ? 'common.required_field'.tr()
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'inventory.alert_quantity'.tr(),
                            controller: minStockController,
                            keyboardType: TextInputType.number,
                            validator: (val) => val == null || val.isEmpty
                                ? 'common.required_field'.tr()
                                : null,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'inventory.retail_price'.tr(),
                            controller: retailController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (val) => val == null || val.isEmpty
                                ? 'common.required_field'.tr()
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'inventory.wholesale_price'.tr(),
                            controller: wholesaleController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (val) => val == null || val.isEmpty
                                ? 'common.required_field'.tr()
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'inventory.promo_price'.tr(),
                      controller: promoController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            if (existing != null)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmDialog(context, cubit, existing);
                },
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.danger,
                ),
                label: Text(
                  'inventory.delete_product'.tr(),
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                onPressed: () {
                  if (existing == null) {
                    idController.clear();
                  }
                  codeController.clear();
                  nameController.clear();
                  costController.clear();
                  minStockController.text = '5';
                  initialStockController.text = '0';
                  retailController.clear();
                  wholesaleController.clear();
                  promoController.clear();
                },
                icon: const Icon(
                  Icons.clear_all,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                label: Text(
                  'common.clear_all'.tr(),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('common.cancel'.tr()),
                ),
                const SizedBox(width: 8),
                PrimaryButton(
                  label: 'inventory.save_product'.tr(),
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      final retailPrice =
                          double.tryParse(retailController.text) ?? 0.0;
                      final wholesalePrice =
                          double.tryParse(wholesaleController.text) ?? 0.0;
                      final promoPrice = double.tryParse(promoController.text);
                      final costPrice =
                          double.tryParse(costController.text) ?? 0.0;
                      final minStock =
                          double.tryParse(minStockController.text) ?? 5.0;
                      final initialStock =
                          double.tryParse(initialStockController.text) ?? 0.0;

                      final prices = [
                        {'price_label': 'retail', 'price_value': retailPrice},
                        {
                          'price_label': 'wholesale',
                          'price_value': wholesalePrice,
                        },
                      ];
                      if (promoPrice != null && promoPrice > 0) {
                        prices.add({
                          'price_label': 'promo',
                          'price_value': promoPrice,
                        });
                      }

                      final serialNumber = int.tryParse(idController.text.trim());
                      final customCode = codeController.text.trim();

                      if (existing == null) {
                        cubit.addProduct(
                          serialNumber: serialNumber,
                          code: customCode.isNotEmpty ? customCode : null,
                          name: nameController.text.trim(),
                          categoryId: selectedCatId,
                          costPrice: costPrice,
                          minStockAlert: minStock,
                          prices: prices,
                          initialStock: initialStock,
                        );
                      } else {
                        cubit.updateProduct(
                          id: existing.product.id,
                          serialNumber: serialNumber,
                          code: customCode.isNotEmpty ? customCode : null,
                          name: nameController.text.trim(),
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
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    InventoryCubit cubit,
    ProductWithDetails item,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.danger,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'inventory.delete_product'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            '${'common.delete_warning'.tr()}\n\n(${item.product.name})',
            style: const TextStyle(
              color: AppColors.textPrimary,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text('common.confirm_delete'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
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
