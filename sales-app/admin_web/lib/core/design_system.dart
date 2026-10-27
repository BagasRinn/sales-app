import 'package:flutter/material.dart';

import 'design_system/app_colors.dart';
import 'design_system/widgets/app_badge.dart';

export 'design_system/app_colors.dart';
export 'design_system/app_tokens.dart';
export 'design_system/app_theme.dart';
export 'design_system/app_responsive.dart';
export 'design_system/widgets/app_card.dart';
export 'design_system/widgets/app_stat_card.dart';
export 'design_system/widgets/app_button.dart';
export 'design_system/widgets/app_input.dart';
export 'design_system/widgets/app_badge.dart';
export 'design_system/widgets/app_choice_chip.dart';
export 'design_system/widgets/app_page_header.dart';
export 'design_system/widgets/app_adaptive_table.dart';
export 'design_system/widgets/app_shell.dart';
export 'design_system/widgets/app_filter_bar.dart';
export 'design_system/widgets/app_states.dart';
export 'design_system/widgets/app_pagination.dart';
export 'design_system/widgets/app_feedback.dart';

// ─── Shared status helpers ────────────────────────────────────────────────────

enum StockStatus { available, low, outOfStock }

Color statusColor(StockStatus s) {
  switch (s) {
    case StockStatus.available:
      return AppColors.success;
    case StockStatus.low:
      return AppColors.warning;
    case StockStatus.outOfStock:
      return AppColors.error;
  }
}

Color statusBgColor(StockStatus s) {
  switch (s) {
    case StockStatus.available:
      return AppColors.successBg;
    case StockStatus.low:
      return AppColors.warningBg;
    case StockStatus.outOfStock:
      return AppColors.errorBg;
  }
}

/// Versi gelap untuk teks chip di atas soft background (kontras ≥ 4.5:1).
Color statusTextColor(StockStatus s) {
  switch (s) {
    case StockStatus.available:
      return AppColors.successText;
    case StockStatus.low:
      return AppColors.warningText;
    case StockStatus.outOfStock:
      return AppColors.dangerText;
  }
}

String stockStatusLabel(StockStatus s) {
  switch (s) {
    case StockStatus.available:
      return 'Tersedia';
    case StockStatus.low:
      return 'Stok Rendah';
    case StockStatus.outOfStock:
      return 'Stok Habis';
  }
}

StockStatus stockStatusFromValue(int available) {
  if (available <= 0) return StockStatus.outOfStock;
  if (available <= 5) return StockStatus.low;
  return StockStatus.available;
}

class StockChip extends StatelessWidget {
  final int available;
  const StockChip({super.key, required this.available});

  @override
  Widget build(BuildContext context) {
    final status = stockStatusFromValue(available);
    return AppBadge(
      label: stockStatusLabel(status),
      variant: switch (status) {
        StockStatus.available => AppBadgeVariant.success,
        StockStatus.low => AppBadgeVariant.warning,
        StockStatus.outOfStock => AppBadgeVariant.danger,
      },
      compact: true,
    );
  }
}

enum OrderStatus { draft, pending, approved, rejected, cancelled }

Color orderStatusColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.draft:
      return AppColors.textMuted;
    case OrderStatus.pending:
      return AppColors.info;
    case OrderStatus.approved:
      return AppColors.success;
    case OrderStatus.rejected:
      return AppColors.error;
    case OrderStatus.cancelled:
      return AppColors.textSubtle;
  }
}

/// Versi gelap untuk teks chip di atas soft background (kontras ≥ 4.5:1).
Color orderStatusTextColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.draft:
      return AppColors.textSecondary;
    case OrderStatus.pending:
      return AppColors.infoText;
    case OrderStatus.approved:
      return AppColors.successText;
    case OrderStatus.rejected:
      return AppColors.dangerText;
    case OrderStatus.cancelled:
      return AppColors.textSecondary;
  }
}

Color orderStatusBgColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.draft:
      return AppColors.border;
    case OrderStatus.pending:
      return AppColors.infoBg;
    case OrderStatus.approved:
      return AppColors.successBg;
    case OrderStatus.rejected:
      return AppColors.errorBg;
    case OrderStatus.cancelled:
      return AppColors.border;
  }
}

String orderStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'DRAFT':
      return 'Draft';
    case 'PENDING':
      return 'Menunggu';
    case 'APPROVED':
      return 'Disetujui';
    case 'REJECTED':
      return 'Ditolak';
    case 'CANCELLED':
      return 'Dibatalkan';
    default:
      return status;
  }
}

OrderStatus? orderStatusFromString(String? s) {
  if (s == null) return null;
  switch (s.toUpperCase()) {
    case 'DRAFT':
      return OrderStatus.draft;
    case 'PENDING':
      return OrderStatus.pending;
    case 'APPROVED':
      return OrderStatus.approved;
    case 'REJECTED':
      return OrderStatus.rejected;
    case 'CANCELLED':
      return OrderStatus.cancelled;
    default:
      return null;
  }
}

class OrderStatusChip extends StatelessWidget {
  final String status;
  const OrderStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = orderStatusFromString(status);
    if (s == null) return const SizedBox.shrink();
    return AppBadge(
      label: orderStatusLabel(status),
      variant: switch (s) {
        OrderStatus.draft || OrderStatus.cancelled => AppBadgeVariant.neutral,
        OrderStatus.pending => AppBadgeVariant.info,
        OrderStatus.approved => AppBadgeVariant.success,
        OrderStatus.rejected => AppBadgeVariant.danger,
      },
      compact: true,
    );
  }
}
