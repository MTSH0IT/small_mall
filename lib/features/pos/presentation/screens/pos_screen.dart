import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/widgets/entity_form_dialog.dart';
import 'package:small_mall/core/widgets/split_pane_layout.dart';
import 'package:small_mall/features/customers_debts/data/customers_debts_repository.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_cubit.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_state.dart';
import 'package:small_mall/features/pos/presentation/widgets/cart_item_row.dart';
import 'package:small_mall/features/pos/presentation/widgets/checkout_panel.dart';
import 'package:small_mall/features/pos/presentation/widgets/pos_product_card.dart';
import 'package:small_mall/features/pos/presentation/widgets/return_dialog.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = null;
    });
  }

  void _handleBarcodeOrSubmit(String value, POSLoaded state, POSCubit cubit) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return;

    // Look for exact match by serial number (#ID), code (barcode), or name
    final exactSerialMatch = int.tryParse(query) != null
        ? state.products.where((p) => p.product.serialNumber == int.tryParse(query)).firstOrNull
        : null;

    final exactCodeMatch = state.products.where((p) {
      return p.product.code != null && p.product.code!.trim().toLowerCase() == query;
    }).firstOrNull;

    final exactNameMatch = state.products.where((p) {
      return p.product.name.toLowerCase() == query;
    }).firstOrNull;

    final target = exactSerialMatch ??
        exactCodeMatch ??
        exactNameMatch ??
        (state.products.where((p) =>
            p.product.name.toLowerCase().contains(query) ||
            (p.product.serialNumber != null && p.product.serialNumber.toString() == query) ||
            (p.product.code != null && p.product.code!.toLowerCase().contains(query))).length == 1
            ? state.products.where((p) =>
                p.product.name.toLowerCase().contains(query) ||
                (p.product.serialNumber != null && p.product.serialNumber.toString() == query) ||
                (p.product.code != null && p.product.code!.toLowerCase().contains(query))).first
            : null);

    if (target != null && target.prices.isNotEmpty && target.currentStock > 0) {
      cubit.addToCart(target, target.prices.first);
      AppToast.success(
        context,
        message: 'pos.barcode_scanned'.tr(namedArgs: {'name': target.product.name}),
      );
      _clearSearch();
    }
  }

  Future<void> _showClearCartConfirmDialog(POSCubit cubit) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'pos.clear_cart_confirm_title'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'pos.clear_cart_confirm_msg'.tr(),
          style: const TextStyle(color: AppColors.textPrimary, height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('pos.clear_cart'.tr()),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      cubit.clearCart();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<POSCubit>(
      create: (context) => POSCubit(
        getIt(),
        getIt(),
        getIt(),
      )..loadPOSData(),
      child: BlocConsumer<POSCubit, POSState>(
        listener: (context, state) {
          if (state is POSCheckoutSuccess) {
            AppToast.success(context, message: 'pos.sale_success'.tr());
          } else if (state is POSError) {
            AppToast.error(context, message: state.message);
          }
        },
        builder: (context, state) {
          final cubit = context.read<POSCubit>();

          if (state is! POSLoaded) {
            if (state is POSError) {
              return AppScreenScaffold(
                title: 'pos.title'.tr(),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                      const SizedBox(height: 16),
                      Text(
                        '${'common.error'.tr()}: ${state.message}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: cubit.loadPOSData,
                        icon: const Icon(Icons.refresh),
                        label: Text('common.retry'.tr()),
                      ),
                    ],
                  ),
                ),
              );
            }
            return AppScreenScaffold(
              title: 'pos.title'.tr(),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          // Filter products based on search query and category
          final query = _searchQuery.trim().toLowerCase();
          final filteredProducts = state.products.where((p) {
            final matchQuery = query.isEmpty ||
                p.product.name.toLowerCase().contains(query) ||
                (p.product.serialNumber != null && p.product.serialNumber.toString() == query) ||
                (p.product.code?.toLowerCase().contains(query) ?? false) ||
                (p.category?.name.toLowerCase().contains(query) ?? false);
            final matchCategory = _selectedCategory == null || p.product.categoryId == _selectedCategory;
            return matchQuery && matchCategory;
          }).toList();

          // Get unique categories list with counts
          final categories = state.products
              .map((p) => p.category)
              .whereType<Category>()
              .toSet()
              .toList();

          final totalCartUnits = state.cart.fold<double>(0.0, (sum, item) => sum + item.quantity);

          return AppScreenScaffold(
            title: 'pos.title'.tr(),
            onRefresh: () => cubit.loadPOSData(),
            actions: const [],
            body: SplitPaneLayout(
              leftFlex: 3,
              rightFlex: 2,
              leftChild: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'pos.search_products'.tr(),
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: _clearSearch,
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      onSubmitted: (value) => _handleBarcodeOrSubmit(value, state, cubit),
                    ),
                    const SizedBox(height: 12),

                    // Modern Category Filter Strip
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // "All" Category Chip
                          _buildCategoryChip(
                            label: 'common.all'.tr(),
                            count: state.products.length,
                            isSelected: _selectedCategory == null,
                            onTap: () => setState(() => _selectedCategory = null),
                          ),
                          const SizedBox(width: 8),
                          // Specific Category Chips
                          ...categories.map((cat) {
                            final count = state.products
                                .where((p) => p.product.categoryId == cat.id)
                                .length;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: _buildCategoryChip(
                                label: cat.name,
                                count: count,
                                isSelected: _selectedCategory == cat.id,
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = _selectedCategory == cat.id ? null : cat.id;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Products Responsive Grid
                    Expanded(
                      child: filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceElevated,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: const Icon(
                                      Icons.search_off_rounded,
                                      size: 40,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'inventory.no_matching_products'.tr(),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'pos.no_products_found_desc'.tr(),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: Text('pos.clear_filters'.tr()),
                                    onPressed: _clearAllFilters,
                                  ),
                                ],
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;
                                final crossAxisCount = width >= 720 ? 4 : (width >= 460 ? 3 : 2);

                                return GridView.builder(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    childAspectRatio: 0.92,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredProducts[index];
                                    final inCartItems = state.cart.where(
                                      (c) => c.productDetails.product.id == item.product.id,
                                    );
                                    final totalInCart = inCartItems.fold<double>(
                                      0.0,
                                      (sum, c) => sum + c.quantity,
                                    );

                                    return POSProductCard(
                                      item: item,
                                      quantityInCart: totalInCart,
                                      onPriceSelected: (price) => cubit.addToCart(item, price),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

              // Right Pane: Cart & Checkout
              rightChild: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surfaceElevated,
                  border: Border(left: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cart Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.shopping_bag_outlined,
                                color: AppColors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'pos.cart'.tr(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (state.cart.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${state.cart.length} (${totalCartUnits.toStringAsFixed(totalCartUnits % 1 == 0 ? 0 : 1)})',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => BlocProvider.value(
                                    value: cubit,
                                    child: const ReturnDialog(),
                                  ),
                                ),
                                icon: const Icon(Icons.replay_rounded, color: AppColors.accent, size: 16),
                                label: Text(
                                  'pos.return_btn'.tr(),
                                  style: const TextStyle(color: AppColors.accent, fontSize: 12),
                                ),
                              ),
                              if (state.cart.isNotEmpty)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  onPressed: () => _showClearCartConfirmDialog(cubit),
                                  icon: const Icon(
                                    Icons.delete_sweep_rounded,
                                    color: AppColors.danger,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'pos.clear_cart'.tr(),
                                    style: const TextStyle(color: AppColors.danger, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),

                    // Cart Items List
                    Expanded(
                      child: state.cart.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.06),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.remove_shopping_cart_outlined,
                                      size: 42,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'pos.empty_cart'.tr(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              itemCount: state.cart.length,
                              itemBuilder: (context, index) {
                                final cartItem = state.cart[index];
                                return CartItemRow(
                                  item: cartItem,
                                  onRemove: () => cubit.removeFromCart(index),
                                  onQuantityChanged: (qty) =>
                                      cubit.updateCartItemQuantity(index, qty),
                                  onDiscountChanged: (disc) =>
                                      cubit.updateCartItemDiscount(index, disc),
                                  onPriceChanged: (newPrice) =>
                                      cubit.updateCartItemPrice(index, newPrice),
                                );
                              },
                            ),
                    ),

                    // Checkout Controls
                    CheckoutPanel(
                      state: state,
                      isLoading: state.isCheckingOut,
                      onInvoiceDiscountChanged: (disc) => cubit.setInvoiceDiscount(disc),
                      onPaymentTypeChanged: (type) => cubit.setPaymentType(type),
                      onCustomerChanged: (cust) => cubit.selectCustomer(cust),
                      onAddCustomerPressed: () => _showAddCustomerDialog(context, cubit),
                      onCheckoutPressed: state.cart.isEmpty ? null : cubit.checkout,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, POSCubit cubit) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => EntityFormDialog(
        title: 'customers.add_customer'.tr(),
        saveLabel: 'common.save'.tr(),
        nameController: nameController,
        phoneController: phoneController,
        notesController: notesController,
        onSave: () async {
          final repo = getIt<CustomersDebtsRepository>();
          final customer = await repo.addCustomer(
            name: nameController.text,
            phone: phoneController.text.isNotEmpty ? phoneController.text : null,
            notes: notesController.text.isNotEmpty ? notesController.text : null,
          );
          await cubit.loadPOSData();
          cubit.selectCustomer(customer);
        },
      ),
    );
  }
}
