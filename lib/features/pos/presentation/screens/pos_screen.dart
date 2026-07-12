import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/di/injection.dart';
import 'package:artisan_gift_manager/core/widgets/price_tag_chip.dart';
import 'package:artisan_gift_manager/core/widgets/primary_button.dart';
import 'package:artisan_gift_manager/core/widgets/app_text_field.dart';
import 'package:artisan_gift_manager/core/widgets/loading_indicator.dart';
import 'package:artisan_gift_manager/features/pos/presentation/cubit/pos_cubit.dart';
import 'package:artisan_gift_manager/features/inventory/data/inventory_repository.dart';
import 'package:artisan_gift_manager/features/customers_debts/data/customers_debts_repository.dart';
import 'package:artisan_gift_manager/core/database/app_database.dart';
import 'package:intl/intl.dart' hide TextDirection;

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
          if (state.status == POSStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تمت عملية البيع بنجاح'), backgroundColor: AppColors.success),
            );
          } else if (state.status == POSStatus.error && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: AppColors.danger),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<POSCubit>();

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
                                    return _buildProductCard(context, cubit, item);
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
                                  separatorBuilder: (_, __) => const Divider(color: AppColors.border),
                                  itemBuilder: (context, index) {
                                    final cartItem = state.cart[index];
                                    return _buildCartItemRow(context, cubit, index, cartItem);
                                  },
                                ),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        // Checkout Summary Panel
                        _buildCheckoutPanel(context, cubit, state),
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

  Widget _buildProductCard(BuildContext context, POSCubit cubit, ProductWithDetails item) {
    final theme = Theme.of(context);
    final inStock = item.currentStock > 0;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: item.isLowStock ? AppColors.danger.withOpacity(0.4) : AppColors.border,
          width: item.isLowStock ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name
            Text(
              item.product.name,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Category & Stock Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.category?.name ?? 'بدون فئة',
                  style: theme.textTheme.labelSmall,
                ),
                PriceTagChip(
                  label: inStock ? 'متوفر: ${item.currentStock.toStringAsFixed(0)}' : 'نفذ',
                  backgroundColor: inStock
                      ? (item.isLowStock ? AppColors.danger : AppColors.success)
                      : Colors.grey,
                  cutSize: 6,
                ),
              ],
            ),
            const Spacer(),
            const Divider(color: AppColors.border, height: 16),
            // Available Prices List (Cashier clicks to add)
            Text(
              'اختر السعر للإضافة:',
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.prices.map((price) {
                final label = price.priceLabel == 'retail'
                    ? 'مفرق'
                    : (price.priceLabel == 'wholesale' ? 'جملة' : 'عرض');
                final color = price.priceLabel == 'retail'
                    ? AppColors.primary
                    : (price.priceLabel == 'wholesale' ? AppColors.accent : AppColors.success);

                return InkWell(
                  onTap: inStock ? () => cubit.addToCart(item, price) : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: inStock ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: inStock ? color : Colors.grey, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: inStock ? color : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${price.priceValue.toStringAsFixed(1)}',
                          style: AppTheme.numericStyle(
                            fontSize: 11,
                            color: inStock ? color : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemRow(BuildContext context, POSCubit cubit, int index, CartItem item) {
    final theme = Theme.of(context);
    final label = item.selectedPrice.priceLabel == 'retail'
        ? 'مفرق'
        : (item.selectedPrice.priceLabel == 'wholesale' ? 'جملة' : 'عرض');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productDetails.product.name,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'سعر الـ$label: ${item.selectedPrice.priceValue.toStringAsFixed(2)} د.أ',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                onPressed: () => cubit.removeFromCart(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quantity and Discount Inputs
          Row(
            children: [
              // Quantity Adjustment
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.primary),
                    onPressed: item.quantity > 1
                        ? () => cubit.updateCartItemQuantity(index, item.quantity - 1)
                        : null,
                  ),
                  Container(
                    alignment: Alignment.center,
                    width: 40,
                    child: Text(
                      item.quantity.toStringAsFixed(0),
                      style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.primary),
                    onPressed: () => cubit.updateCartItemQuantity(index, item.quantity + 1),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Item-level Discount Field
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTheme.numericStyle(fontSize: 13),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.local_offer_outlined, size: 14, color: AppColors.textSecondary),
                      hintText: 'خصم (مبلغ)',
                      hintStyle: theme.textTheme.labelSmall,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onChanged: (val) {
                      final discount = double.tryParse(val) ?? 0.0;
                      cubit.updateCartItemDiscount(index, discount);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Subtotal
              Text(
                '${item.subtotal.toStringAsFixed(2)} د.أ',
                style: AppTheme.numericStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutPanel(BuildContext context, POSCubit cubit, POSState state) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtotal Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المجموع الفرعي:', style: theme.textTheme.bodyMedium),
              Text(
                '${state.cartSubtotal.toStringAsFixed(2)} د.أ',
                style: AppTheme.numericStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Discount total field
          Row(
            children: [
              Text('خصم إضافي:', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTheme.numericStyle(fontSize: 14),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      hintText: '0.00 د.أ',
                    ),
                    onChanged: (val) {
                      final discount = double.tryParse(val) ?? 0.0;
                      cubit.setInvoiceDiscount(discount);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Payment type toggle
          Row(
            children: [
              Text('طريقة الدفع:', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 16),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'cash',
                      label: Text('نقدي'),
                      icon: Icon(Icons.payments_outlined, size: 16),
                    ),
                    ButtonSegment<String>(
                      value: 'debt',
                      label: Text('آجل / دين'),
                      icon: Icon(Icons.assignment_ind_outlined, size: 16),
                    ),
                  ],
                  selected: {state.paymentType},
                  onSelectionChanged: (selection) {
                    cubit.setPaymentType(selection.first);
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.primary,
                    selectedForegroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Customer selector (Required for debt, optional for cash)
          Row(
            children: [
              Text('العميل:', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<Customer>(
                  value: state.selectedCustomer,
                  hint: const Text('اختر عميلاً (اختياري)'),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  items: state.customers.map((c) {
                    return DropdownMenuItem<Customer>(
                      value: c.customer,
                      child: Text('${c.customer.name} (دين: ${c.totalDebt.toStringAsFixed(1)})'),
                    );
                  }).toList(),
                  onChanged: (cust) {
                    cubit.selectCustomer(cust);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
                onPressed: () => _showAddCustomerDialog(context, cubit),
              )
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 16),
          // Total Amount Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المجموع النهائي:',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              Text(
                '${state.totalAmount.toStringAsFixed(2)} د.أ',
                style: AppTheme.numericStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Checkout Button
          PrimaryButton(
            label: state.paymentType == 'debt' ? 'تأكيد البيع الآجل' : 'تأكيد البيع النقدي',
            icon: Icons.check,
            onPressed: state.cart.isEmpty ? null : cubit.checkout,
            isLoading: state.status == POSStatus.loading,
          ),
        ],
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
                    await cubit.loadPOSData(); // Reload customer list
                    cubit.selectCustomer(customer); // Auto-select added customer
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
