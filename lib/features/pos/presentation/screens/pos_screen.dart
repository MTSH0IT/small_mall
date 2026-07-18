import 'package:artisan_gift_manager/core/database/app_database.dart';
import 'package:artisan_gift_manager/core/di/injection.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/widgets/app_text_field.dart';
import 'package:artisan_gift_manager/core/widgets/primary_button.dart';
import 'package:artisan_gift_manager/features/customers_debts/data/customers_debts_repository.dart';
import 'package:artisan_gift_manager/features/pos/presentation/cubit/pos_cubit.dart';
import 'package:artisan_gift_manager/features/pos/presentation/cubit/pos_state.dart';
import 'package:artisan_gift_manager/features/pos/presentation/widgets/cart_item_row.dart';
import 'package:artisan_gift_manager/features/pos/presentation/widgets/checkout_panel.dart';
import 'package:artisan_gift_manager/features/pos/presentation/widgets/pos_product_card.dart';
import 'package:artisan_gift_manager/features/pos/presentation/widgets/return_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider<POSCubit>(
      create: (context) => POSCubit(
        getIt(),
        getIt(),
        getIt(),
      )..loadPOSData(),
      child: BlocConsumer<POSCubit, POSState>(
        listener: (context, state) {
          if (state is POSCheckoutSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تمت عملية البيع بنجاح'), backgroundColor: AppColors.success),
            );
          } else if (state is POSError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.danger),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<POSCubit>();

          if (state is! POSLoaded) {
            if (state is POSError) {
              return Scaffold(
                backgroundColor: AppColors.surface,
                appBar: AppBar(
                  title: Text('نقطة البيع', style: theme.textTheme.displayMedium?.copyWith(
                    fontFamily: 'ElMessiri', color: AppColors.primary,
                  )),
                  backgroundColor: Colors.transparent, elevation: 0,
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                      const SizedBox(height: 16),
                      Text('حدث خطأ: ${state.message}', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: cubit.loadPOSData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Scaffold(
              backgroundColor: AppColors.surface,
              appBar: AppBar(
                title: Text('نقطة البيع', style: theme.textTheme.displayMedium?.copyWith(
                  fontFamily: 'ElMessiri', color: AppColors.primary,
                )),
                backgroundColor: Colors.transparent, elevation: 0,
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          // Filter products based on search query and category
          final filteredProducts = state.products.where((p) {
            final matchQuery = p.product.name.contains(_searchQuery) ||
                (p.category?.name.contains(_searchQuery) ?? false);
            final matchCategory = _selectedCategory == null || p.product.categoryId == _selectedCategory;
            return matchQuery && matchCategory;
          }).toList();

          // Get unique categories list
          final categories = state.products
              .map((p) => p.category)
              .whereType<Category>()
              .toSet()
              .toList();

          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              title: Text(
                'نقطة البيع',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontFamily: 'ElMessiri',
                  color: AppColors.primary,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.replay, color: AppColors.accent),
                  tooltip: 'إرجاع منتجات',
                  onPressed: () => showDialog(context: context, builder: (_) => BlocProvider.value(value: cubit, child: const ReturnDialog())),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  onPressed: () => cubit.loadPOSData(),
                ),
              ],
            ),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Right Pane: Product Selection Grid
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search & Category Filters
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: 'البحث عن منتج',
                                hint: 'ابحث بالاسم أو الفئة...',
                                controller: _searchController,
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Category Chips Scroll
                        SizedBox(
                          height: 38,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ChoiceChip(
                                label: const Text('الكل'),
                                selected: _selectedCategory == null,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _selectedCategory = null);
                                  }
                                },
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: _selectedCategory == null ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ...categories.map((cat) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: ChoiceChip(
                                    label: Text(cat.name),
                                    selected: _selectedCategory == cat.id,
                                    onSelected: (val) {
                                      setState(() {
                                        _selectedCategory = val ? cat.id : null;
                                      });
                                    },
                                    selectedColor: AppColors.primary,
                                    labelStyle: TextStyle(
                                      color: _selectedCategory == cat.id ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Products Grid
                        Expanded(
                          child: filteredProducts.isEmpty
                              ? const Center(child: Text('لا توجد منتجات مطابقة للبحث'))
                              : GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 0.85,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredProducts[index];
                                    return POSProductCard(
                                      item: item,
                                      onPriceSelected: (price) => cubit.addToCart(item, price),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Divider
                const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
                // Left Pane: Cart & Checkout Form
                Expanded(
                  flex: 2,
                  child: Container(
                    color: AppColors.surfaceElevated,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cart Header
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'سلة المشتريات',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: cubit.clearCart,
                                icon: const Icon(Icons.delete_sweep, color: AppColors.danger),
                                label: const Text('تفريغ السلة', style: TextStyle(color: AppColors.danger)),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        // Cart Items List
                        Expanded(
                          child: state.cart.isEmpty
                              ? const Center(child: Text('سلة المشتريات فارغة. اضغط على سعر منتج لإضافته.'))
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: state.cart.length,
                                  separatorBuilder: (_, _) => const Divider(color: AppColors.border),
                                  itemBuilder: (context, index) {
                                    final cartItem = state.cart[index];
                                    return CartItemRow(
                                      item: cartItem,
                                      onRemove: () => cubit.removeFromCart(index),
                                      onQuantityChanged: (qty) => cubit.updateCartItemQuantity(index, qty),
                                      onDiscountChanged: (disc) => cubit.updateCartItemDiscount(index, disc),
                                    );
                                  },
                                ),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        // Checkout Summary Panel
                        CheckoutPanel(
                          state: state,
                          isLoading: cubit.state is POSLoading,
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
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, POSCubit cubit) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة عميل جديد', style: TextStyle(fontFamily: 'ElMessiri', color: AppColors.primary)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    label: 'اسم العميل *',
                    controller: nameController,
                    validator: (val) => val == null || val.isEmpty ? 'الرجاء إدخال اسم العميل' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'رقم الهاتف',
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'ملاحظات',
                    controller: notesController,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء'),
              ),
              PrimaryButton(
                label: 'حفظ العميل',
                onPressed: () async {
                  if (formKey.currentState?.validate() ?? false) {
                    final repo = getIt<CustomersDebtsRepository>();
                    final customer = await repo.addCustomer(
                      name: nameController.text,
                      phone: phoneController.text.isNotEmpty ? phoneController.text : null,
                      notes: notesController.text.isNotEmpty ? notesController.text : null,
                    );
                    await cubit.loadPOSData();
                    cubit.selectCustomer(customer);
                    if (context.mounted) {
                      Navigator.pop(dialogCtx);
                    }
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
