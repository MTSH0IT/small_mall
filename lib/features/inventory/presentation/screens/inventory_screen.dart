import 'package:artisan_gift_manager/core/di/injection.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/widgets/app_text_field.dart';
import 'package:artisan_gift_manager/core/widgets/loading_indicator.dart';
import 'package:artisan_gift_manager/core/widgets/primary_button.dart';
import 'package:artisan_gift_manager/features/inventory/data/inventory_repository.dart';
import 'package:artisan_gift_manager/features/inventory/presentation/cubit/inventory_cubit.dart';
import 'package:artisan_gift_manager/features/inventory/presentation/widgets/inventory_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _filterLowStockOnly = false;

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
                'إدارة المخزون',
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
                  // Filter and Search controls
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
                        child: FilterChip(
                          label: const Text('المخزون المنخفض فقط'),
                          selected: _filterLowStockOnly,
                          onSelected: (val) {
                            setState(() {
                              _filterLowStockOnly = val;
                            });
                          },
                          selectedColor: AppColors.danger.withValues(alpha: 0.1),
                          checkmarkColor: AppColors.danger,
                          labelStyle: TextStyle(
                            color: _filterLowStockOnly ? AppColors.danger : AppColors.textPrimary,
                            fontWeight: _filterLowStockOnly ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Table or list
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
      return const LoadingIndicator(message: 'جاري تحميل تفاصيل المخزون...');
    }

    if (state is InventoryLoaded) {
      return InventoryTable(
        products: state.products,
        searchQuery: _searchQuery,
        filterLowStockOnly: _filterLowStockOnly,
        onAdjustStock: (item) => _showAdjustStockDialog(context, cubit, item),
      );
    }

    return const SizedBox();
  }

  void _showAdjustStockDialog(BuildContext context, InventoryCubit cubit, ProductWithDetails item) {
    final formKey = GlobalKey<FormState>();
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
    String direction = 'add'; // 'add' or 'subtract'

    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (dialogCtx, setStateDialog) {
              return AlertDialog(
                title: Text('تعديل مخزون: ${item.product.name}',
                    style: const TextStyle(fontFamily: 'ElMessiri', color: AppColors.primary)),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioGroup<String>(
                        groupValue: direction,
                        onChanged: (val) {
                          setStateDialog(() => direction = val!);
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('زيادة (+)'),
                                value: 'add',
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('تسوية / إنقاص (-)'),
                                value: 'subtract',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'الكمية *',
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'الرجاء إدخال الكمية';
                          final numVal = double.tryParse(val);
                          if (numVal == null || numVal <= 0) return 'الرجاء إدخال كمية صحيحة أكبر من 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'سبب التعديل / ملاحظات *',
                        controller: reasonController,
                        hint: 'مثال: جرد سنوي، تلف، تعديل يدوي...',
                        validator: (val) => val == null || val.isEmpty ? 'الرجاء كتابة سبب التعديل' : null,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
                  PrimaryButton(
                    label: 'تأكيد التسوية',
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        double qty = double.parse(qtyController.text);
                        if (direction == 'subtract') {
                          qty = -qty;
                        }
                        cubit.adjustStock(item.product.id, qty, reasonController.text);
                        Navigator.pop(dialogCtx);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
