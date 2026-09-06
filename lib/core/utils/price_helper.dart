import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';

class PriceHelper {
  PriceHelper._();

  static String getLabel(String priceLabel) {
    switch (priceLabel.toLowerCase()) {
      case 'retail':
        return 'مفرق';
      case 'wholesale':
        return 'جملة';
      case 'promo':
        return 'عرض';
      default:
        return priceLabel;
    }
  }

  static Color getColor(String priceLabel) {
    switch (priceLabel.toLowerCase()) {
      case 'retail':
        return AppColors.primary;
      case 'wholesale':
        return AppColors.accent;
      case 'promo':
        return AppColors.success;
      default:
        return AppColors.textPrimary;
    }
  }
}

extension PriceLabelX on String {
  String get priceLabelDisplay => PriceHelper.getLabel(this);
  String get priceLabelText => PriceHelper.getLabel(this);
  Color get priceLabelColor => PriceHelper.getColor(this);
}
