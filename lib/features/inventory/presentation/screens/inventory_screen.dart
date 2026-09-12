import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:small_mall/features/inventory/presentation/widgets/inventory_table.dart';
import 'package:small_mall/features/inventory/presentation/widgets/product_operations_dialog.dart';

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
            title: 'inventory.title'.tr(),
            onRefresh: () => cubit.loadInventory(),
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
                        child: FilterChip(
                          label: Text('inventory.low_stock_only'.tr()),
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
      return LoadingIndicator(message: 'common.loading'.tr());
    }

    if (state is InventoryLoaded) {
      return InventoryTable(
        products: state.products,
        searchQuery: _searchQuery,
        filterLowStockOnly: _filterLowStockOnly,
        onViewHistory: (item) => _showOperationsDialog(context, cubit, item),
        onAdjustStock: (item) => _showAdjustStockDialog(context, cubit, item),
      );
    }

    return const SizedBox();
  }

  void _showOperationsDialog(BuildContext context, InventoryCubit cubit, ProductWithDetails item) {
    showDialog(
      context: context,
      builder: (_) => ProductOperationsDialog(
        productDetails: item,
        cubit: cubit,
      ),
    );
  }

  void _showAdjustStockDialog(BuildContext context, InventoryCubit cubit, ProductWithDetails item) {
    final formKey = GlobalKey<FormState>();
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
    String direction = 'add'; // 'add' or 'subtract'

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            return AlertDialog(
              title: Text('${'inventory.adjust_stock'.tr()}: ${item.product.name}',
                  style: const TextStyle(color: AppColors.primary)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioGroup<String>(
                      groupValue: direction,
                      onChanged: (val) {
                        if (val != null) setStateDialog(() => direction = val);
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text('(+) ${'inventory.stock_in'.tr()}'),
                              value: 'add',
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text('(-) ${'inventory.stock_out'.tr()}'),
                              value: 'subtract',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: '${'common.quantity'.tr()} *',
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'common.required_field'.tr();
                        final numVal = double.tryParse(val);
                        if (numVal == null || numVal <= 0) return 'common.required_field'.tr();
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: '${'inventory.adjust_reason'.tr()} *',
                      controller: reasonController,
                      validator: (val) => val == null || val.isEmpty ? 'common.required_field'.tr() : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('common.cancel'.tr())),
                PrimaryButton(
                  label: 'common.confirm'.tr(),
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
        );
      },
    );
  }
}
