import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';

/// An elegant, theme-integrated searchable dropdown widget powered by [DropdownButtonFormField2].
///
/// Uses standard Flutter [DropdownMenuItem] for maximum consistency and zero
/// direct dependence on third-party item classes in calling screens.
class AppSearchableDropdown<T> extends StatefulWidget {
  const AppSearchableDropdown({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.label,
    this.hint,
    this.hintWidget,
    this.searchHint,
    this.prefixIcon,
    this.validator,
    this.isSearchable = true,
    this.searchMatchFn,
    this.itemSearchText,
    this.menuMaxHeight = 320,
    this.menuWidth,
    this.fillColor,
    this.borderColor,
    this.borderRadius = 8.0,
    this.contentPadding,
    this.isExpanded = true,
    this.noResultsWidget,
    this.enabled = true,
  });

  /// The list of items the user can select from, using standard Flutter [DropdownMenuItem].
  final List<DropdownMenuItem<T>> items;

  /// The currently selected value.
  final T? value;

  /// Called when the user selects an item.
  final ValueChanged<T?>? onChanged;

  /// Optional label displayed above the dropdown field.
  final String? label;

  /// Optional hint text displayed when no value is selected.
  final String? hint;

  /// Optional custom hint widget displayed when no value is selected.
  final Widget? hintWidget;

  /// Hint text for the search input field inside the dropdown menu.
  final String? searchHint;

  /// Icon displayed at the start of the input field.
  final Widget? prefixIcon;

  /// Form validation function.
  final FormFieldValidator<T>? validator;

  /// Whether the dropdown menu should include a search field.
  final bool isSearchable;

  /// Custom search matching function for dropdown items.
  final bool Function(DropdownMenuItem<T> item, String searchValue)? searchMatchFn;

  /// Convenience function to extract searchable text from item value [T].
  final String Function(T item)? itemSearchText;

  /// Maximum height of the popup menu.
  final double menuMaxHeight;

  /// Optional explicit width for the popup menu.
  final double? menuWidth;

  /// Background color of the input field.
  final Color? fillColor;

  /// Border color of the input field.
  final Color? borderColor;

  /// Corner radius of the input field.
  final double borderRadius;

  /// Padding inside the input field.
  final EdgeInsetsGeometry? contentPadding;

  /// Whether the dropdown button should expand to fill its container.
  final bool isExpanded;

  /// Custom widget shown when search yields no results.
  final Widget? noResultsWidget;

  /// Whether the dropdown is enabled.
  final bool enabled;

  @override
  State<AppSearchableDropdown<T>> createState() => _AppSearchableDropdownState<T>();
}

class _AppSearchableDropdownState<T> extends State<AppSearchableDropdown<T>> {
  late final TextEditingController _searchController;
  late final ValueNotifier<T?> _valueNotifier;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    _valueNotifier = ValueNotifier<T?>(widget.value);
  }

  @override
  void didUpdateWidget(covariant AppSearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _valueNotifier.value = widget.value;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _valueNotifier.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _defaultSearchMatch(DropdownMenuItem<T> item, String searchValue) {
    final query = searchValue.trim().toLowerCase();
    if (query.isEmpty) return true;

    if (widget.itemSearchText != null && item.value != null) {
      try {
        return widget.itemSearchText!(item.value as T).toLowerCase().contains(query);
      } catch (_) {}
    }

    final child = item.child;
    if (child is Text && child.data != null) {
      return child.data!.toLowerCase().contains(query);
    }

    if (item.value != null) {
      final valStr = item.value.toString().toLowerCase();
      return valStr.contains(query);
    }

    return true;
  }

  List<DropdownItem<T>> _buildDropdownItems() {
    return widget.items
        .map(
          (item) => DropdownItem<T>(
            value: item.value,
            enabled: item.enabled,
            onTap: item.onTap,
            child: item.child,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBorderColor = widget.borderColor ?? AppColors.border;
    final effectiveFillColor = widget.fillColor ?? AppColors.surfaceElevated;

    final hintWidget = widget.hintWidget ??
        (widget.hint != null
            ? Text(
                widget.hint!,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
              )
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        DropdownButtonFormField2<T>(
          valueListenable: _valueNotifier,
          items: _buildDropdownItems(),
          onChanged: widget.enabled
              ? (val) {
                  _valueNotifier.value = val;
                  widget.onChanged?.call(val);
                }
              : null,
          validator: widget.validator,
          isExpanded: widget.isExpanded,
          hint: hintWidget,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: effectiveFillColor,
            prefixIcon: widget.prefixIcon,
            contentPadding: widget.contentPadding ??
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              borderSide: BorderSide(color: effectiveBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              borderSide: BorderSide(color: effectiveBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
            ),
          ),
          iconStyleData: const IconStyleData(
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            openMenuIcon: Icon(
              Icons.keyboard_arrow_up_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            iconSize: 20,
          ),
          dropdownStyleData: DropdownStyleData(
            maxHeight: widget.menuMaxHeight,
            width: widget.menuWidth,
            elevation: 0,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            offset: const Offset(0, -4),
            scrollbarTheme: ScrollbarThemeData(
              radius: const Radius.circular(8),
              thickness: WidgetStateProperty.all(6),
              thumbVisibility: WidgetStateProperty.all(true),
              thumbColor: WidgetStateProperty.all(AppColors.border),
            ),
          ),
          menuItemStyleData: const MenuItemStyleData(
            padding: EdgeInsets.symmetric(horizontal: 14),
          ),
          dropdownSearchData: widget.isSearchable
              ? DropdownSearchData<T>(
                  searchController: _searchController,
                  searchBarWidgetHeight: 52,
                  searchBarWidget: Container(
                    height: 52,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: TextFormField(
                      expands: true,
                      maxLines: null,
                      controller: _searchController,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        hintText: widget.searchHint ?? 'common.search'.tr(),
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                splashRadius: 14,
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        fillColor: AppColors.surface,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  searchMatchFn: (item, searchValue) {
                    final originalItem = widget.items
                            .where((orig) => orig.value == item.value)
                            .firstOrNull ??
                        DropdownMenuItem<T>(value: item.value, child: item.child);
                    if (widget.searchMatchFn != null) {
                      return widget.searchMatchFn!(originalItem, searchValue);
                    }
                    return _defaultSearchMatch(originalItem, searchValue);
                  },
                  noResultsWidget: widget.noResultsWidget ??
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 28,
                                color: AppColors.textSecondary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'common.no_results'.tr(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                )
              : null,
          onMenuStateChange: (isOpen) {
            if (!isOpen && widget.isSearchable) {
              _searchController.clear();
            }
          },
        ),
      ],
    );
  }
}
