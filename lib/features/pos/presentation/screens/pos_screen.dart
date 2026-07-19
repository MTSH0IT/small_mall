import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/entity_form_dialog.dart';
import 'package:small_mall/core/widgets/split_pane_layout.dart';
import 'package:small_mall/features/customers_debts/data/customers_debts_repository.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_cubit.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_state.dart';
import 'package:small_mall/features/pos/presentation/widgets/cart_item_row.dart';
import 'package:small_mall/features/pos/presentation/widgets/checkout_panel.dart';
import 'package:small_mall/features/pos/presentation/widgets/pos_product_card.dart';
import 'package:small_mall/features/pos/presentation/widgets/return_dialog.dart';
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
              return AppScreenScaffold(
                title: 'نقطة البيع',
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
            return AppScreenScaffold(
              title: 'نقطة البيع',
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

          return AppScreenScaffold(
            title: 'نقطة البيع',
            onRefresh: () => cubit.loadPOSData(),
            actions: [],
            body: SplitPaneLayout(
              leftFlex: 3,
              rightFlex: 2,
              leftChild: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
              rightChild: Container(
                color: AppColors.surfaceElevated,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'سلة المشتريات',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => showDialog(context: context, builder: (_) => BlocProvider.value(value: cubit, child: const ReturnDialog())),
                                icon: const Icon(Icons.replay, color: AppColors.accent),
                                label: const Text('إرجاع', style: TextStyle(color: AppColors.accent)),
                              ),
                              TextButton.icon(
                                onPressed: cubit.clearCart,
                                icon: const Icon(Icons.delete_sweep, color: AppColors.danger),
                                label: const Text('تفريغ السلة', style: TextStyle(color: AppColors.danger)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
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
          );
        },
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
        title: 'إضافة عميل جديد',
        saveLabel: 'حفظ العميل',
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
