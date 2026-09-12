import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';

/// Column definition for [AppTable].
class AppTableColumn<T> {
  const AppTableColumn({
    this.title,
    this.headerWidget,
    required this.cellBuilder,
    this.numeric = false,
    this.tooltip,
    this.onSort,
  }) : assert(
          title != null || headerWidget != null,
          'Either title or headerWidget must be provided.',
        );

  /// Plain string title displayed in the header.
  final String? title;

  /// Custom header widget (takes priority over [title] if provided).
  final Widget? headerWidget;

  /// Function that returns the cell widget for a given row item.
  final Widget Function(T item) cellBuilder;

  /// Whether this column displays numeric data (right-aligned in standard LTR).
  final bool numeric;

  /// Tooltip message shown on hover over column header.
  final String? tooltip;

  /// Optional sort callback.
  final void Function(int columnIndex, bool ascending)? onSort;

  /// Builds the [DataColumn] for this column definition.
  DataColumn toDataColumn(BuildContext context) {
    return DataColumn(
      label: headerWidget ??
          Text(
            title ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
      numeric: numeric,
      tooltip: tooltip,
      onSort: onSort,
    );
  }
}

/// A reusable, responsive, and beautifully styled table widget used across the application.
///
/// Features:
/// - Automatically stretches to 100% of container width using [LayoutBuilder] & [ConstrainedBox].
/// - Smooth horizontal scrolling when columns exceed available screen width.
/// - Integrated empty state ([EmptyStateView]) with optional filter reset button.
/// - Integrated loading indicator state.
/// - Unified styling: elevated surface, primary-tinted headers, rounded borders, and consistent spacing.
class AppTable<T> extends StatelessWidget {
  const AppTable({
    super.key,
    required this.items,
    required this.columns,
    this.isLoading = false,
    this.emptyWidget,
    this.emptyTitle,
    this.emptyDescription,
    this.emptyIcon = Icons.inbox_outlined,
    this.onResetFilters,
    this.resetFiltersLabel,
    this.columnSpacing = 24.0,
    this.horizontalMargin = 16.0,
    this.dataRowMinHeight = 48.0,
    this.dataRowMaxHeight = 56.0,
    this.headingRowHeight = 52.0,
    this.headingRowColor,
    this.decoration,
    this.clipBehavior = Clip.antiAlias,
    this.horizontalScrollController,
    this.verticalScrollController,
    this.sortColumnIndex,
    this.sortAscending = true,
  }) : _isRaw = false,
       _rawColumns = const [],
       _rawRows = const [];

  /// Alternative constructor to display raw [DataColumn]s and [DataRow]s
  /// while still benefiting from [AppTable]'s responsive shell and unified styling.
  const AppTable.raw({
    super.key,
    required List<DataColumn> columns,
    required List<DataRow> rows,
    this.isLoading = false,
    this.emptyWidget,
    this.emptyTitle,
    this.emptyDescription,
    this.emptyIcon = Icons.inbox_outlined,
    this.onResetFilters,
    this.resetFiltersLabel,
    this.columnSpacing = 24.0,
    this.horizontalMargin = 16.0,
    this.dataRowMinHeight = 48.0,
    this.dataRowMaxHeight = 56.0,
    this.headingRowHeight = 52.0,
    this.headingRowColor,
    this.decoration,
    this.clipBehavior = Clip.antiAlias,
    this.horizontalScrollController,
    this.verticalScrollController,
    this.sortColumnIndex,
    this.sortAscending = true,
  }) : _isRaw = true,
       items = const [],
       columns = const [],
       _rawColumns = columns,
       _rawRows = rows;

  final bool _isRaw;
  final List<DataColumn> _rawColumns;
  final List<DataRow> _rawRows;

  /// The list of items to display.
  final List<T> items;

  /// The columns of the table.
  final List<AppTableColumn<T>> columns;

  /// Whether the table is currently in a loading state.
  final bool isLoading;

  /// Custom widget to display when [items] is empty.
  final Widget? emptyWidget;

  /// Title for standard empty state.
  final String? emptyTitle;

  /// Description for standard empty state.
  final String? emptyDescription;

  /// Icon for standard empty state.
  final IconData emptyIcon;

  /// Optional callback to reset filters when no matching results are found.
  final VoidCallback? onResetFilters;

  /// Label for the reset filters button.
  final String? resetFiltersLabel;

  /// Horizontal space between columns. Defaults to 24.0.
  final double columnSpacing;

  /// Horizontal margin on left and right edges. Defaults to 16.0.
  final double horizontalMargin;

  /// Minimum height of each data row. Defaults to 48.0.
  final double dataRowMinHeight;

  /// Maximum height of each data row. Defaults to 56.0.
  final double dataRowMaxHeight;

  /// Height of the header row. Defaults to 52.0.
  final double headingRowHeight;

  /// Background color of the header row. Defaults to subtle primary tint.
  final Color? headingRowColor;

  /// Custom container decoration.
  final BoxDecoration? decoration;

  /// Clip behavior of the table container.
  final Clip clipBehavior;

  /// Optional custom controller for horizontal scrolling.
  final ScrollController? horizontalScrollController;

  /// Optional custom controller for vertical scrolling.
  final ScrollController? verticalScrollController;

  /// Index of the column currently used for sorting.
  final int? sortColumnIndex;

  /// Whether the current sort is ascending.
  final bool sortAscending;

  bool get _isEmpty => _isRaw ? _rawRows.isEmpty : items.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: LoadingIndicator(message: 'common.loading'.tr()),
      );
    }

    if (_isEmpty) {
      if (emptyWidget != null) return emptyWidget!;
      if (emptyTitle != null) {
        return _buildEmptyState(context);
      }
    }

    final tableDecoration = decoration ??
        BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        );

    return Container(
      decoration: tableDecoration,
      clipBehavior: clipBehavior,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dataColumns = _isRaw
              ? _rawColumns
              : columns.map((col) => col.toDataColumn(context)).toList();

          final dataRows = _isRaw
              ? _rawRows
              : items.map((item) {
                  return DataRow(
                    cells: columns.map((col) {
                      return DataCell(col.cellBuilder(item));
                    }).toList(),
                  );
                }).toList();

          return SingleChildScrollView(
            controller: verticalScrollController,
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              controller: horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: columnSpacing,
                  horizontalMargin: horizontalMargin,
                  headingRowHeight: headingRowHeight,
                  dataRowMinHeight: dataRowMinHeight,
                  dataRowMaxHeight: dataRowMaxHeight,
                  headingRowColor: WidgetStateProperty.all(
                    headingRowColor ?? AppColors.primary.withValues(alpha: 0.04),
                  ),
                  sortColumnIndex: sortColumnIndex,
                  sortAscending: sortAscending,
                  columns: dataColumns,
                  rows: dataRows,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    if (onResetFilters != null) {
      return Center(
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
              child: Icon(
                emptyIcon,
                size: 40,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              emptyTitle!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (emptyDescription != null) ...[
              const SizedBox(height: 6),
              Text(
                emptyDescription!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
              label: Text(resetFiltersLabel ?? 'pos.clear_filters'.tr()),
              onPressed: onResetFilters,
            ),
          ],
        ),
      );
    }

    return Center(
      child: EmptyStateView(
        icon: emptyIcon,
        title: emptyTitle!,
        description: emptyDescription ?? '',
      ),
    );
  }
}
