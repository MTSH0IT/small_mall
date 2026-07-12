import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/di/injection.dart';
import 'package:artisan_gift_manager/core/widgets/price_tag_chip.dart';
import 'package:artisan_gift_manager/core/widgets/primary_button.dart';
import 'package:artisan_gift_manager/core/widgets/app_text_field.dart';
import 'package:artisan_gift_manager/core/widgets/loading_indicator.dart';
import 'package:artisan_gift_manager/features/suppliers_purchasing/presentation/cubit/suppliers_purchasing_cubit.dart';
import 'package:artisan_gift_manager/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';
import 'package:artisan_gift_manager/features/inventory/data/inventory_repository.dart';
import 'package:artisan_gift_manager/core/database/app_database.dart';

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
  final List<Map<String, dynamic>> _purchaseItems = []; // productId, productName, quantity, unitCost
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

  double get _totalPurchaseAmount {
    return _purchaseItems.fold<double>(0.0, (sum, item) {
      final qty = item['quantity'] as double;
      final cost = item['unitCost'] as double;
      return sum + (qty * cost);
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
      final filtered = state.suppliers.where((s) {
        return s.supplier.name.contains(_searchQuery);
      }).toList();

      if (filtered.isEmpty) {
        return const Center(child: Text('لا يوجد موردين مطابقين للبحث.'));
      }

      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
          itemBuilder: (context, index) {
            final item = filtered[index];
            final isSelected = _selectedSupplier?.id == item.supplier.id;

            return ListTile(
              selected: isSelected,
              selectedTileColor: AppColors.primary.withOpacity(0.05),
              title: Text(item.supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.supplier.phone ?? 'بدون هاتف'),
              trailing: PriceTagChip(
                label: 'مشتريات: ${item.totalPurchasesAmount.toStringAsFixed(1)} د.أ',
                backgroundColor: AppColors.primary,
                cutSize: 6,
              ),
              onTap: () {
                setState(() {
                  _selectedSupplier = item.supplier;
                });
              },
            );
          },
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildRecordPurchasePanel(BuildContext context, SuppliersPurchasingCubit cubit, SuppliersPurchasingState state) {
    final theme = Theme.of(context);

    if (_selectedSupplier == null) {
      return const Center(child: Text('اختر مورداً من القائمة للبدء بتسجيل فاتورة مشتريات'));
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Info
          Text(
            'تسجيل فاتورة مشتريات من المورد: ${_selectedSupplier!.name}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'ElMessiri',
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          // Product Selector dropdown for adding rows
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ProductWithDetails>(
                  hint: const Text('اختر منتجاً لإضافته للفاتورة'),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  items: _availableProducts.map((p) {
                    return DropdownMenuItem(value: p, child: Text(p.product.name));
                  }).toList(),
                  onChanged: (prod) {
                    if (prod != null) {
                      _addPurchaseItemRow(prod.product);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Purchase Items Table/List
          Expanded(
            child: _purchaseItems.isEmpty
                ? const Center(child: Text('لم يتم إضافة أي منتجات للفاتورة بعد'))
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _purchaseItems.length,
                      separatorBuilder: (_, __) => const Divider(color: AppColors.border),
                      itemBuilder: (context, index) {
                        final item = _purchaseItems[index];
                        final subtotal = (item['quantity'] as double) * (item['unitCost'] as double);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(item['productName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _purchaseItems.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  // Quantity Field
                                  Expanded(
                                    child: AppTextField(
                                      label: 'الكمية المشتراة',
                                      hint: 'الكمية',
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) {
                                        setState(() {
                                          _purchaseItems[index]['quantity'] = double.tryParse(val) ?? 1.0;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Unit Cost Field
                                  Expanded(
                                    child: AppTextField(
                                      label: 'سعر التكلفة الجديد (د.أ)',
                                      hint: 'التكلفة بالقطعة',
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (val) {
                                        setState(() {
                                          _purchaseItems[index]['unitCost'] = double.tryParse(val) ?? 0.0;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('المجموع:', style: theme.textTheme.labelSmall),
                                      Text(
                                        '${subtotal.toStringAsFixed(2)} د.أ',
                                        style: AppTheme.numericStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          // Footer / Checkout
          const Divider(color: AppColors.border, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'إجمالي قيمة المشتريات:',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              Text(
                '${_totalPurchaseAmount.toStringAsFixed(2)} د.أ',
                style: AppTheme.numericStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'تأكيد وحفظ فاتورة المشتريات',
            icon: Icons.check,
            onPressed: _purchaseItems.isEmpty
                ? null
                : () async {
                    await cubit.recordPurchase(
                      supplierId: _selectedSupplier!.id,
                      totalAmount: _totalPurchaseAmount,
                      items: _purchaseItems,
                    );
                    setState(() {
                      _purchaseItems.clear();
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تسجيل فاتورة المشتريات وتحديث مخزون المنتجات بنجاح')),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }

  void _addPurchaseItemRow(Product product) {
    // Check if product already in list
    final existing = _purchaseItems.any((item) => item['productId'] == product.id);
    if (existing) return;

    setState(() {
      _purchaseItems.add({
        'productId': product.id,
        'productName': product.name,
        'quantity': 1.0,
        'unitCost': product.costPrice,
      });
    });
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
