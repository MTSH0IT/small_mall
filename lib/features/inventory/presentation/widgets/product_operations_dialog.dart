import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_table.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/inventory/presentation/cubit/inventory_cubit.dart';

class ProductOperationsDialog extends StatefulWidget {
  const ProductOperationsDialog({
    super.key,
    required this.productDetails,
    required this.cubit,
  });

  final ProductWithDetails productDetails;
  final InventoryCubit cubit;

  @override
  State<ProductOperationsDialog> createState() => _ProductOperationsDialogState();
}

class _ProductOperationsDialogState extends State<ProductOperationsDialog> {
  bool _isLoading = true;
  List<ProductStockOperation> _allOperations = [];
  String _selectedFilter = 'all'; // all, sale, purchase, adjustment, return

  @override
  void initState() {
    super.initState();
    _fetchOperations();
  }

  Future<void> _fetchOperations() async {
    setState(() => _isLoading = true);
    try {
      final ops = await widget.cubit.getProductOperations(widget.productDetails.product.id);
      if (mounted) {
        setState(() {
          _allOperations = ops;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<ProductStockOperation> get _filteredOperations {
    if (_selectedFilter == 'all') {
      return _allOperations;
    }
    if (_selectedFilter == 'adjustment') {
      return _allOperations.where((op) => op.type == 'adjustment' || op.type == 'initial').toList();
    }
    return _allOperations.where((op) => op.type == _selectedFilter).toList();
  }

  double get _initialStock {
    final initialOp = _allOperations.where((op) => op.type == 'initial').toList();
    if (initialOp.isNotEmpty) {
      return initialOp.first.quantity;
    }
    return widget.productDetails.initialStock;
  }

  double get _totalPurchases {
    return _allOperations
        .where((op) => op.type == 'purchase')
        .fold<double>(0.0, (sum, op) => sum + op.quantity);
  }

  double get _totalSales {
    return _allOperations
        .where((op) => op.type == 'sale')
        .fold<double>(0.0, (sum, op) => sum + op.quantity.abs());
  }

  double get _netAdjustments {
    return _allOperations
        .where((op) => op.type == 'adjustment')
        .fold<double>(0.0, (sum, op) => sum + op.quantity);
  }

  double get _currentStock {
    if (_allOperations.isNotEmpty) {
      return _allOperations.first.runningBalance;
    }
    return widget.productDetails.currentStock;
  }

  void _showAdjustStockInlineDialog() {
    final formKey = GlobalKey<FormState>();
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
    String direction = 'add';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.swap_vert, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${'inventory.adjust_stock'.tr()}: ${widget.productDetails.product.name}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
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
                              title: Text('(+) ${'inventory.stock_in'.tr()}', style: const TextStyle(fontSize: 13)),
                              value: 'add',
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text('(-) ${'inventory.stock_out'.tr()}', style: const TextStyle(fontSize: 13)),
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
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('common.cancel'.tr()),
                ),
                PrimaryButton(
                  label: 'common.confirm'.tr(),
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      double qty = double.parse(qtyController.text);
                      if (direction == 'subtract') {
                        qty = -qty;
                      }
                      Navigator.pop(dialogCtx);
                      await widget.cubit.adjustStock(
                        widget.productDetails.product.id,
                        qty,
                        reasonController.text,
                      );
                      await _fetchOperations();
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

  @override
  Widget build(BuildContext context) {
    final prod = widget.productDetails.product;
    final catName = widget.productDetails.category?.name;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1050,
          maxHeight: 750,
        ),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Dialog Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.manage_history_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                prod.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (prod.serialNumber != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '#${prod.serialNumber}',
                                    style: AppTheme.numericStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              if (prod.code != null && prod.code!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    prod.code!,
                                    style: AppTheme.numericStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (catName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${'inventory.category'.tr()}: $catName',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Stock adjustment action button
                    OutlinedButton.icon(
                      onPressed: _showAdjustStockInlineDialog,
                      icon: const Icon(Icons.swap_vert, size: 16, color: AppColors.primary),
                      label: Text(
                        'inventory.adjust_stock'.tr(),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'common.cancel'.tr(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // 2. Summary KPI Cards
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    _buildKpiCard(
                      title: 'inventory.initial_stock_short'.tr(),
                      value: _initialStock.toStringAsFixed(0),
                      icon: Icons.flag_circle_outlined,
                      color: const Color(0xFF2563EB), // Info Blue
                    ),
                    const SizedBox(width: 10),
                    _buildKpiCard(
                      title: 'inventory.total_purchases_qty'.tr(),
                      value: '+${_totalPurchases.toStringAsFixed(0)}',
                      icon: Icons.local_shipping_outlined,
                      color: const Color(0xFF7C3AED), // Purple
                    ),
                    const SizedBox(width: 10),
                    _buildKpiCard(
                      title: 'inventory.total_sales_qty'.tr(),
                      value: '-${_totalSales.toStringAsFixed(0)}',
                      icon: Icons.shopping_cart_outlined,
                      color: const Color(0xFFD97706), // Amber / Orange
                    ),
                    const SizedBox(width: 10),
                    _buildKpiCard(
                      title: 'inventory.net_adjustments'.tr(),
                      value: _netAdjustments >= 0
                          ? '+${_netAdjustments.toStringAsFixed(0)}'
                          : _netAdjustments.toStringAsFixed(0),
                      icon: Icons.tune_rounded,
                      color: const Color(0xFF0D9488), // Teal
                    ),
                    const SizedBox(width: 10),
                    _buildKpiCard(
                      title: 'inventory.current_stock'.tr(),
                      value: _currentStock.toStringAsFixed(0),
                      icon: Icons.inventory_2_outlined,
                      color: _currentStock <= prod.minStockAlert && prod.minStockAlert > 0
                          ? AppColors.danger
                          : AppColors.success,
                      isEmphasized: true,
                    ),
                  ],
                ),
              ),

              // 3. Filter Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${'inventory.operation_type'.tr()}:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterChip('all', 'inventory.all_operations'.tr()),
                        _buildFilterChip('sale', 'inventory.sales'.tr()),
                        _buildFilterChip('purchase', 'inventory.purchases'.tr()),
                        _buildFilterChip('adjustment', 'inventory.adjustments'.tr()),
                        _buildFilterChip('return', 'inventory.returns'.tr()),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 4. Operations AppTable
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _isLoading
                      ? LoadingIndicator(message: 'common.loading'.tr())
                      : AppTable<ProductStockOperation>(
                          items: _filteredOperations,
                          emptyTitle: 'inventory.operations_history'.tr(),
                          emptyDescription: 'inventory.no_operations'.tr(),
                          emptyIcon: Icons.history_toggle_off_rounded,
                          columns: [
                            AppTableColumn<ProductStockOperation>(
                              title: 'invoices.invoice_date'.tr(),
                              cellBuilder: (op) => Text(
                                intl.DateFormat('yyyy/MM/dd  HH:mm').format(op.createdAt),
                                style: AppTheme.numericStyle(fontSize: 12),
                              ),
                            ),
                            AppTableColumn<ProductStockOperation>(
                              title: 'inventory.operation_type'.tr(),
                              cellBuilder: (op) => _buildTypeBadge(op.type),
                            ),
                            AppTableColumn<ProductStockOperation>(
                              title: 'common.quantity'.tr(),
                              cellBuilder: (op) {
                                final isPositive = op.quantity > 0;
                                final isZero = op.quantity == 0;
                                final color = isZero
                                    ? AppColors.textSecondary
                                    : (isPositive ? AppColors.success : AppColors.danger);
                                final prefix = isPositive ? '+' : '';
                                return Text(
                                  '$prefix${op.quantity.toStringAsFixed(0)}',
                                  style: AppTheme.numericStyle(
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                );
                              },
                            ),
                            AppTableColumn<ProductStockOperation>(
                              title: 'inventory.running_balance'.tr(),
                              cellBuilder: (op) => Text(
                                op.runningBalance.toStringAsFixed(0),
                                style: AppTheme.numericStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            AppTableColumn<ProductStockOperation>(
                              title: 'inventory.ref_number'.tr(),
                              cellBuilder: (op) => Text(
                                op.referenceNumber ?? '-',
                                style: AppTheme.numericStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            AppTableColumn<ProductStockOperation>(
                              title: 'inventory.party_or_notes'.tr(),
                              cellBuilder: (op) {
                                final text = op.partyName ?? '-';
                                return Tooltip(
                                  message: text,
                                  child: Text(
                                    text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                            AppTableColumn<ProductStockOperation>(
                              title: 'common.price'.tr(),
                              cellBuilder: (op) => Text(
                                op.unitPrice != null ? op.unitPrice!.toStringAsFixed(2) : '-',
                                style: AppTheme.numericStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isEmphasized = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isEmphasized ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: isEmphasized ? 0.4 : 0.2),
            width: isEmphasized ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTheme.numericStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = value);
        }
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.25),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (type) {
      case 'initial':
        bg = const Color(0xFF2563EB).withValues(alpha: 0.1);
        fg = const Color(0xFF2563EB);
        icon = Icons.flag_circle_rounded;
        label = 'inventory.initial_balance'.tr();
        break;
      case 'sale':
        bg = const Color(0xFFD97706).withValues(alpha: 0.1);
        fg = const Color(0xFFD97706);
        icon = Icons.shopping_cart_outlined;
        label = 'inventory.sales'.tr();
        break;
      case 'purchase':
        bg = const Color(0xFF7C3AED).withValues(alpha: 0.1);
        fg = const Color(0xFF7C3AED);
        icon = Icons.local_shipping_outlined;
        label = 'inventory.purchases'.tr();
        break;
      case 'return':
        bg = Colors.pink.withValues(alpha: 0.1);
        fg = Colors.pink;
        icon = Icons.assignment_return_outlined;
        label = 'inventory.returns'.tr();
        break;
      case 'adjustment':
      default:
        bg = const Color(0xFF0D9488).withValues(alpha: 0.1);
        fg = const Color(0xFF0D9488);
        icon = Icons.tune_rounded;
        label = 'inventory.adjustments'.tr();
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}
