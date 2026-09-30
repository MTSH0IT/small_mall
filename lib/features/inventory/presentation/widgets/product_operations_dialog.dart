import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_table.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/inventory/presentation/cubit/inventory_cubit.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/invoices/presentation/widgets/transaction_detail_dialog.dart';

class ProductOperationsDialog extends StatefulWidget {
  const ProductOperationsDialog({
    super.key,
    required this.productDetails,
    required this.cubit,
  });

  final ProductWithDetails productDetails;
  final InventoryCubit cubit;

  @override
  State<ProductOperationsDialog> createState() =>
      _ProductOperationsDialogState();
}

class _ProductOperationsDialogState extends State<ProductOperationsDialog> {
  bool _isLoading = true;
  bool _isLoadingInvoice = false;
  List<ProductStockOperation> _allOperations = [];

  // Filter states
  String _selectedFilter = 'all'; // all, sale, purchase, adjustment, return
  String _selectedDateRange = 'all'; // all, today, 7days, month, year, custom
  DateTimeRange? _customDateRange;
  String _selectedCurrency = 'all'; // all, SYP, USD

  @override
  void initState() {
    super.initState();
    _fetchOperations();
  }

  Future<void> _fetchOperations() async {
    setState(() => _isLoading = true);
    try {
      final ops = await widget.cubit.getProductOperations(
        widget.productDetails.product.id,
      );
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

  Future<void> _openInvoiceDetails(ProductStockOperation op) async {
    if (op.referenceId == null || _isLoadingInvoice) return;

    setState(() => _isLoadingInvoice = true);
    try {
      final repo = getIt<InvoicesRepository>();
      final tx = await repo.getTransactionById(op.referenceId!);
      if (mounted) {
        if (tx != null) {
          await TransactionDetailDialog.show(context, tx);
          if (mounted) {
            _fetchOperations();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('invoices.select_invoice_to_view'.tr())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingInvoice = false);
      }
    }
  }

  List<ProductStockOperation> get _filteredOperations {
    final now = DateTime.now();

    return _allOperations.where((op) {
      // 1. Operation Type Filter
      if (_selectedFilter != 'all') {
        if (_selectedFilter == 'adjustment') {
          if (op.type != 'adjustment' && op.type != 'initial') return false;
        } else if (op.type != _selectedFilter) {
          return false;
        }
      }

      // 2. Currency Filter
      if (_selectedCurrency != 'all') {
        if (op.currency != _selectedCurrency) return false;
      }

      // 3. Date Range Filter
      switch (_selectedDateRange) {
        case 'today':
          final startOfToday = DateTime(now.year, now.month, now.day);
          if (op.createdAt.isBefore(startOfToday)) return false;
          break;
        case '7days':
          final sevenDaysAgo = now.subtract(const Duration(days: 7));
          if (op.createdAt.isBefore(sevenDaysAgo)) return false;
          break;
        case 'month':
          final startOfMonth = DateTime(now.year, now.month, 1);
          if (op.createdAt.isBefore(startOfMonth)) return false;
          break;
        case 'year':
          final startOfYear = DateTime(now.year, 1, 1);
          if (op.createdAt.isBefore(startOfYear)) return false;
          break;
        case 'custom':
          if (_customDateRange != null) {
            final start = _customDateRange!.start;
            final end = _customDateRange!.end.add(const Duration(days: 1));
            if (op.createdAt.isBefore(start) || op.createdAt.isAfter(end)) {
              return false;
            }
          }
          break;
        case 'all':
        default:
          break;
      }

      return true;
    }).toList();
  }

  // --- Financial & Stock Aggregations ---
  double get _initialStock {
    final initialOp = _allOperations
        .where((op) => op.type == 'initial')
        .toList();
    if (initialOp.isNotEmpty) {
      return initialOp.first.quantity;
    }
    return widget.productDetails.initialStock;
  }

  double get _currentStock {
    if (_allOperations.isNotEmpty) {
      return _allOperations.first.runningBalance;
    }
    return widget.productDetails.currentStock;
  }

  double get _totalInflowQty {
    return _filteredOperations.fold<double>(
      0.0,
      (sum, op) => sum + op.inflowQty,
    );
  }

  double get _totalOutflowQty {
    return _filteredOperations.fold<double>(
      0.0,
      (sum, op) => sum + op.outflowQty,
    );
  }

  double get _totalSalesRevenueSyp {
    return _filteredOperations
        .where((op) => op.type == 'sale' && op.currency != AppCurrency.usdCode)
        .fold<double>(0.0, (sum, op) => sum + op.totalMovementValue);
  }

  double get _totalSalesRevenueUsd {
    return _filteredOperations
        .where((op) => op.type == 'sale' && op.currency == AppCurrency.usdCode)
        .fold<double>(0.0, (sum, op) => sum + op.totalMovementValue);
  }

  double get _totalPurchasesCostSyp {
    return _filteredOperations
        .where(
          (op) => op.type == 'purchase' && op.currency != AppCurrency.usdCode,
        )
        .fold<double>(0.0, (sum, op) => sum + op.totalMovementValue);
  }

  double get _totalPurchasesCostUsd {
    return _filteredOperations
        .where(
          (op) => op.type == 'purchase' && op.currency == AppCurrency.usdCode,
        )
        .fold<double>(0.0, (sum, op) => sum + op.totalMovementValue);
  }

  double get _totalGrossProfitSyp {
    return _filteredOperations
        .where(
          (op) =>
              (op.type == 'sale' || op.type == 'return') &&
              op.currency != AppCurrency.usdCode,
        )
        .fold<double>(0.0, (sum, op) => sum + (op.grossProfit ?? 0.0));
  }

  double get _totalGrossProfitUsd {
    return _filteredOperations
        .where(
          (op) =>
              (op.type == 'sale' || op.type == 'return') &&
              op.currency == AppCurrency.usdCode,
        )
        .fold<double>(0.0, (sum, op) => sum + (op.grossProfit ?? 0.0));
  }

  String _formatAmount(double? amount, String currency) {
    if (amount == null) return '-';
    if (currency == AppCurrency.usdCode) {
      return '${amount.toStringAsFixed(2)} \$';
    }
    final formatted = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '$formatted ${AppCurrency.sypSymbol}';
  }

  String _formatProfit(double? profit, String currency) {
    if (profit == null) return '-';
    final sign = profit >= 0 ? '+' : '';
    if (currency == AppCurrency.usdCode) {
      return '$sign${profit.toStringAsFixed(2)} \$';
    }
    final formatted = profit % 1 == 0
        ? profit.toStringAsFixed(0)
        : profit.toStringAsFixed(2);
    return '$sign$formatted ${AppCurrency.sypSymbol}';
  }

  // --- Modal Dialog Actions ---
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
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
                              title: Text(
                                '(+) ${'inventory.stock_in'.tr()}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              value: 'add',
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text(
                                '(-) ${'inventory.stock_out'.tr()}',
                                style: const TextStyle(fontSize: 13),
                              ),
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
                        if (val == null || val.isEmpty) {
                          return 'common.required_field'.tr();
                        }
                        final numVal = double.tryParse(val);
                        if (numVal == null || numVal <= 0) {
                          return 'common.required_field'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: '${'inventory.adjust_reason'.tr()} *',
                      controller: reasonController,
                      validator: (val) => val == null || val.isEmpty
                          ? 'common.required_field'.tr()
                          : null,
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
                      if (mounted) {
                        _fetchOperations();
                      }
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

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange:
          _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDateRange = 'custom';
      });
    }
  }

  void _showPrintStatementDialog() {
    final prod = widget.productDetails.product;
    final catName = widget.productDetails.category?.name;
    final ops = _filteredOperations;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850, maxHeight: 750),
            child: Container(
              color: AppColors.surfaceElevated,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Statement Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'inventory.product_movement'.tr(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${prod.name} ${prod.code != null ? "(${prod.code})" : ""}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          if (catName != null)
                            Text(
                              '${'inventory.category'.tr()}: $catName',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            intl.DateFormat(
                              'yyyy/MM/dd  HH:mm',
                            ).format(DateTime.now()),
                            style: AppTheme.numericStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${'inventory.current_stock'.tr()}: ${_currentStock.toStringAsFixed(0)}',
                              style: AppTheme.numericStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Statement Content Table
                  Expanded(
                    child: SingleChildScrollView(
                      child: Table(
                        border: TableBorder.all(
                          color: AppColors.border,
                          width: 0.8,
                        ),
                        columnWidths: const {
                          0: FlexColumnWidth(1.6),
                          1: FlexColumnWidth(1.2),
                          2: FlexColumnWidth(1.2),
                          3: FlexColumnWidth(1.8),
                          4: FlexColumnWidth(1.0),
                          5: FlexColumnWidth(1.0),
                          6: FlexColumnWidth(1.2),
                          7: FlexColumnWidth(1.3),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: AppColors.surface),
                            children: [
                              _buildTableHeaderCell(
                                'invoices.invoice_date'.tr(),
                              ),
                              _buildTableHeaderCell(
                                'inventory.operation_type'.tr(),
                              ),
                              _buildTableHeaderCell(
                                'inventory.ref_number'.tr(),
                              ),
                              _buildTableHeaderCell(
                                'inventory.party_or_notes'.tr(),
                              ),
                              _buildTableHeaderCell('inventory.inflow'.tr()),
                              _buildTableHeaderCell('inventory.outflow'.tr()),
                              _buildTableHeaderCell(
                                'inventory.running_balance'.tr(),
                              ),
                              _buildTableHeaderCell(
                                'inventory.movement_value'.tr(),
                              ),
                            ],
                          ),
                          ...ops.map((op) {
                            return TableRow(
                              children: [
                                _buildTableCell(
                                  intl.DateFormat(
                                    'yyyy/MM/dd HH:mm',
                                  ).format(op.createdAt),
                                ),
                                _buildTableCell(op.typeLabel),
                                _buildTableCell(op.referenceNumber ?? '-'),
                                _buildTableCell(op.partyName ?? '-'),
                                _buildTableCell(
                                  op.inflowQty > 0
                                      ? '+${op.inflowQty.toStringAsFixed(op.inflowQty % 1 == 0 ? 0 : 1)}'
                                      : '-',
                                  isGreen: op.inflowQty > 0,
                                ),
                                _buildTableCell(
                                  op.outflowQty > 0
                                      ? '-${op.outflowQty.toStringAsFixed(op.outflowQty % 1 == 0 ? 0 : 1)}'
                                      : '-',
                                  isRed: op.outflowQty > 0,
                                ),
                                _buildTableCell(
                                  op.runningBalance.toStringAsFixed(
                                    op.runningBalance % 1 == 0 ? 0 : 1,
                                  ),
                                  isBold: true,
                                ),
                                _buildTableCell(
                                  _formatAmount(
                                    op.totalMovementValue,
                                    op.currency,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('common.close'.tr()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11.5,
          color: AppColors.textPrimary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isBold = false,
    bool isGreen = false,
    bool isRed = false,
  }) {
    Color color = AppColors.textPrimary;
    if (isGreen) color = AppColors.success;
    if (isRed) color = AppColors.danger;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Text(
        text,
        style: AppTheme.numericStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prod = widget.productDetails.product;
    final catName = widget.productDetails.category?.name;
    final costSyp = widget.productDetails.costPriceSyp;
    final costUsd = widget.productDetails.costPriceUsd;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1200,
          maxHeight: MediaQuery.sizeOf(context).height * 0.94,
        ),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Accounting Header Master Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.analytics_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${'inventory.product_movement'.tr()}: ',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  prod.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (prod.serialNumber != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
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
                              if (prod.code != null &&
                                  prod.code!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
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
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (catName != null) ...[
                                Text(
                                  '${'inventory.category'.tr()}: $catName',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                              ],
                              Text(
                                '${'inventory.cost_price'.tr()}: ${(costSyp > 0 || costUsd > 0) ? "${costSyp > 0 ? "${costSyp.toStringAsFixed(0)} ${AppCurrency.sypSymbol}" : ""}${costSyp > 0 && costUsd > 0 ? " / " : ""}${costUsd > 0 ? "${costUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}" : ""}" : "0 ${AppCurrency.sypSymbol}"}',
                                style: AppTheme.numericStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Actions
                    OutlinedButton.icon(
                      onPressed: _showPrintStatementDialog,
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: Text('inventory.print_statement'.tr()),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showAdjustStockInlineDialog,
                      icon: const Icon(Icons.swap_vert_rounded, size: 16),
                      label: Text('inventory.adjust_stock'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'common.close'.tr(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // 2. Financial & Inventory KPI Cards
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final hasBothPurchases =
                        _totalPurchasesCostUsd > 0 &&
                        _totalPurchasesCostSyp > 0;
                    final hasBothSales =
                        _totalSalesRevenueUsd > 0 && _totalSalesRevenueSyp > 0;
                    final hasBothProfit =
                        _totalGrossProfitUsd != 0 && _totalGrossProfitSyp != 0;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildKpiCard(
                          title: 'inventory.initial_stock_short'.tr(),
                          value: _initialStock.toStringAsFixed(0),
                          subtitle: 'inventory.pieces'.tr(),
                          icon: Icons.flag_circle_outlined,
                          color: const Color(0xFF2563EB),
                          width: (constraints.maxWidth - 50) / 6,
                        ),
                        _buildKpiCard(
                          title: 'inventory.inflow'.tr(),
                          value: _totalInflowQty.toStringAsFixed(0),
                          subtitle: hasBothPurchases
                              ? '${_totalPurchasesCostUsd.toStringAsFixed(2)} \$ + ${_totalPurchasesCostSyp.toStringAsFixed(0)} ل.س'
                              : (_totalPurchasesCostUsd > 0
                                    ? '${_totalPurchasesCostUsd.toStringAsFixed(2)} \$'
                                    : '${_totalPurchasesCostSyp.toStringAsFixed(0)} ل.س'),
                          icon: Icons.arrow_downward_rounded,
                          color: const Color(0xFF0D9488),
                          width: (constraints.maxWidth - 50) / 6,
                        ),
                        _buildKpiCard(
                          title: 'inventory.outflow'.tr(),
                          value: _totalOutflowQty.toStringAsFixed(0),
                          subtitle: hasBothSales
                              ? '${_totalSalesRevenueUsd.toStringAsFixed(2)} \$ + ${_totalSalesRevenueSyp.toStringAsFixed(0)} ل.س'
                              : (_totalSalesRevenueUsd > 0
                                    ? '${_totalSalesRevenueUsd.toStringAsFixed(2)} \$'
                                    : '${_totalSalesRevenueSyp.toStringAsFixed(0)} ل.س'),
                          icon: Icons.arrow_upward_rounded,
                          color: const Color(0xFFEA580C),
                          width: (constraints.maxWidth - 50) / 6,
                        ),
                        _buildKpiCard(
                          title: 'inventory.current_stock'.tr(),
                          value: _currentStock.toStringAsFixed(0),
                          subtitle: costUsd > 0
                              ? '≈ ${(_currentStock * costUsd).toStringAsFixed(2)} \$'
                              : (costSyp > 0
                                    ? '≈ ${(_currentStock * costSyp).toStringAsFixed(0)} ل.س'
                                    : 'inventory.pieces'.tr()),
                          tooltip: (costSyp > 0 && costUsd > 0)
                              ? '${'inventory.stock_valuation'.tr()}: ${(_currentStock * costUsd).toStringAsFixed(2)} \$ (≈ ${(_currentStock * costSyp).toStringAsFixed(0)} ل.س)'
                              : null,
                          icon: Icons.inventory_2_outlined,
                          color:
                              _currentStock <= prod.minStockAlert &&
                                  prod.minStockAlert > 0
                              ? AppColors.danger
                              : AppColors.success,
                          isEmphasized: true,
                          width: (constraints.maxWidth - 50) / 6,
                        ),
                        _buildKpiCard(
                          title: 'inventory.sales_revenue'.tr(),
                          value: _totalSalesRevenueUsd > 0
                              ? '${_totalSalesRevenueUsd.toStringAsFixed(2)} \$'
                              : '${_totalSalesRevenueSyp.toStringAsFixed(0)} ل.س',
                          subtitle: hasBothSales
                              ? '+ ${_totalSalesRevenueSyp.toStringAsFixed(0)} ل.س'
                              : 'inventory.sales'.tr(),
                          icon: Icons.point_of_sale_rounded,
                          color: const Color(0xFF7C3AED),
                          width: (constraints.maxWidth - 50) / 6,
                        ),
                        _buildKpiCard(
                          title: 'inventory.gross_profit'.tr(),
                          value: (_totalGrossProfitUsd != 0 || !hasBothProfit)
                              ? '${_totalGrossProfitUsd >= 0 ? "+" : ""}${_totalGrossProfitUsd.toStringAsFixed(2)} \$'
                              : '${_totalGrossProfitSyp >= 0 ? "+" : ""}${_totalGrossProfitSyp.toStringAsFixed(0)} ل.س',
                          subtitle: hasBothProfit
                              ? '${_totalGrossProfitSyp >= 0 ? "+" : ""}${_totalGrossProfitSyp.toStringAsFixed(0)} ل.س'
                              : (_totalGrossProfitUsd != 0
                                    ? (_totalSalesRevenueUsd > 0
                                          ? '${((_totalGrossProfitUsd / _totalSalesRevenueUsd) * 100).toStringAsFixed(1)}%'
                                          : 'common.total'.tr())
                                    : (_totalSalesRevenueSyp > 0
                                          ? '${((_totalGrossProfitSyp / _totalSalesRevenueSyp) * 100).toStringAsFixed(1)}%'
                                          : 'common.total'.tr())),
                          icon: Icons.trending_up_rounded,
                          color:
                              (_totalGrossProfitSyp >= 0 &&
                                  _totalGrossProfitUsd >= 0)
                              ? const Color(0xFF059669)
                              : AppColors.danger,
                          width: (constraints.maxWidth - 50) / 6,
                        ),
                      ],
                    );
                  },
                ),
              ),

              // 3. Accounting Filter Toolbar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    // Operation Type Filter
                    Text(
                      '${'inventory.operation_type'.tr()}:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip('all', 'inventory.all_operations'.tr()),
                    const SizedBox(width: 6),
                    _buildFilterChip('sale', 'inventory.sales'.tr()),
                    const SizedBox(width: 6),
                    _buildFilterChip('purchase', 'inventory.purchases'.tr()),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      'adjustment',
                      'inventory.adjustments'.tr(),
                    ),
                    const SizedBox(width: 6),
                    _buildFilterChip('return', 'inventory.returns'.tr()),

                    const SizedBox(width: 16),
                    const SizedBox(
                      height: 20,
                      child: VerticalDivider(width: 1, color: AppColors.border),
                    ),
                    const SizedBox(width: 16),

                    // Date Filter
                    Text(
                      '${'common.date'.tr()}:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildDateChip('all', 'inventory.all_time'.tr()),
                    const SizedBox(width: 6),
                    _buildDateChip('today', 'inventory.today'.tr()),
                    const SizedBox(width: 6),
                    _buildDateChip('7days', 'inventory.last_7_days'.tr()),
                    const SizedBox(width: 6),
                    _buildDateChip('month', 'inventory.this_month'.tr()),
                    const SizedBox(width: 6),
                    _buildDateChip(
                      'custom',
                      _customDateRange != null
                          ? '${intl.DateFormat('MM/dd').format(_customDateRange!.start)} - ${intl.DateFormat('MM/dd').format(_customDateRange!.end)}'
                          : 'inventory.custom_date'.tr(),
                      onTap: _selectCustomDateRange,
                    ),

                    const Spacer(),

                    // Currency Filter
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCurrencySegment('all', 'common.all'.tr()),
                          _buildCurrencySegment('SYP', AppCurrency.sypSymbol),
                          _buildCurrencySegment('USD', AppCurrency.usdSymbol),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // 4. Detailed Accounting Ledger Table
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
                            // 1. Date & Time
                            AppTableColumn<ProductStockOperation>(
                              title: 'invoices.invoice_date'.tr(),
                              cellBuilder: (op) => Text(
                                intl.DateFormat(
                                  'yyyy/MM/dd  HH:mm',
                                ).format(op.createdAt),
                                style: AppTheme.numericStyle(fontSize: 12),
                              ),
                            ),
                            // 2. Type Badge
                            AppTableColumn<ProductStockOperation>(
                              title: 'inventory.operation_type'.tr(),
                              cellBuilder: (op) => _buildTypeBadge(op.type),
                            ),
                            // 3. Document Ref # (Clickable)
                            AppTableColumn<ProductStockOperation>(
                              title: 'inventory.ref_number'.tr(),
                              cellBuilder: (op) {
                                if (op.referenceNumber == null ||
                                    op.referenceId == null) {
                                  return Text(
                                    op.referenceNumber ?? '-',
                                    style: AppTheme.numericStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  );
                                }
                                return Tooltip(
                                  message: 'invoices.details'.tr(),
                                  child: InkWell(
                                    onTap: () => _openInvoiceDetails(op),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            op.referenceNumber!,
                                            style:
                                                AppTheme.numericStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ).copyWith(
                                                  decoration:
                                                      TextDecoration.underline,
                                                  decorationColor: AppColors
                                                      .primary
                                                      .withValues(alpha: 0.5),
                                                ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.open_in_new,
                                            size: 13,
                                            color: AppColors.primary.withValues(
                                              alpha: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // 4. Counterparty / Description
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
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                );
                              },
                            ),
                            // 5. Inflow Quantity (+)
                            AppTableColumn<ProductStockOperation>(
                              title: 'inventory.inflow'.tr(),
                              numeric: true,
                              cellBuilder: (op) {
                                if (op.inflowQty <= 0) {
                                  return const Text(
                                    '-',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  );
                                }
                                return Text(
                                  '+${op.inflowQty.toStringAsFixed(op.inflowQty % 1 == 0 ? 0 : 1)}',
                                  style: AppTheme.numericStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                    fontSize: 13,
                                  ),
                                );
                              },
                            ),
                            // 6. Outflow Quantity (-)
                            AppTableColumn<ProductStockOperation>(
                              title: 'inventory.outflow'.tr(),
                              numeric: true,
                              cellBuilder: (op) {
                                if (op.outflowQty <= 0) {
                                  return const Text(
                                    '-',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  );
                                }
                                return Text(
                                  '-${op.outflowQty.toStringAsFixed(op.outflowQty % 1 == 0 ? 0 : 1)}',
                                  style: AppTheme.numericStyle(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFEA580C),
                                    fontSize: 13,
                                  ),
                                );
                              },
                            ),
                            // 7. Running Stock Balance
                            AppTableColumn<ProductStockOperation>(
                              title: 'inventory.running_balance'.tr(),
                              numeric: true,
                              cellBuilder: (op) => Text(
                                op.runningBalance.toStringAsFixed(
                                  op.runningBalance % 1 == 0 ? 0 : 1,
                                ),
                                style: AppTheme.numericStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            // 8. Unit Price
                            AppTableColumn<ProductStockOperation>(
                              title: 'common.price'.tr(),
                              numeric: true,
                              cellBuilder: (op) => Text(
                                _formatAmount(op.unitPrice, op.currency),
                                style: AppTheme.numericStyle(fontSize: 12),
                              ),
                            ),
                            // 9. Total Movement Value
                            AppTableColumn<ProductStockOperation>(
                              title: 'inventory.movement_value'.tr(),
                              numeric: true,
                              cellBuilder: (op) => Text(
                                _formatAmount(
                                  op.totalMovementValue,
                                  op.currency,
                                ),
                                style: AppTheme.numericStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            // 10. Gross Profit (for sales)
                            AppTableColumn<ProductStockOperation>(
                              title: 'inventory.gross_profit'.tr(),
                              numeric: true,
                              cellBuilder: (op) {
                                final profit = op.grossProfit;
                                if (profit == null) {
                                  return const Text(
                                    '-',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  );
                                }
                                final isPositive = profit >= 0;
                                return Text(
                                  _formatProfit(profit, op.currency),
                                  style: AppTheme.numericStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isPositive
                                        ? const Color(0xFF059669)
                                        : AppColors.danger,
                                  ),
                                );
                              },
                            ),
                            // 11. Currency
                            AppTableColumn<ProductStockOperation>(
                              title: 'common.currency_select'.tr(),
                              cellBuilder: (op) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: op.currency == AppCurrency.usdCode
                                      ? const Color(
                                          0xFF059669,
                                        ).withValues(alpha: 0.1)
                                      : AppColors.primary.withValues(
                                          alpha: 0.08,
                                        ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  op.currencySymbol,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: op.currency == AppCurrency.usdCode
                                        ? const Color(0xFF059669)
                                        : AppColors.primary,
                                  ),
                                ),
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
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
    bool isEmphasized = false,
    String? tooltip,
  }) {
    final card = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isEmphasized
            ? color.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isEmphasized ? 0.4 : 0.2),
          width: isEmphasized ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
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
                  style: const TextStyle(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTheme.numericStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(
        message: tooltip,
        child: card,
      );
    }
    return card;
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
          color: isSelected
              ? AppColors.primary
              : Colors.grey.withValues(alpha: 0.25),
        ),
      ),
    );
  }

  Widget _buildDateChip(String value, String label, {VoidCallback? onTap}) {
    final isSelected = _selectedDateRange == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (onTap != null) {
          onTap();
        } else if (selected) {
          setState(() => _selectedDateRange = value);
        }
      },
      selectedColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? const Color(0xFF0D9488) : AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF0D9488)
              : Colors.grey.withValues(alpha: 0.25),
        ),
      ),
    );
  }

  Widget _buildCurrencySegment(String code, String label) {
    final isSelected = _selectedCurrency == code;
    return InkWell(
      onTap: () => setState(() => _selectedCurrency = code),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
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
        bg = const Color(0xFFEA580C).withValues(alpha: 0.1);
        fg = const Color(0xFFEA580C);
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
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
