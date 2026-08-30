import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Premium загварын үндсэн карт контейнер — surface өнгө, зөөлөн хүрээ,
/// сонголтоор "elevated" (илүү тод) хувилбартай.
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool elevated;
  final VoidCallback? onTap;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.card,
    this.elevated = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: elevated ? AppColors.surfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: child,
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: card,
    );
  }
}

/// Дэлгэц дэх хэсгийн гарчиг + сонголтоор "Бүгдийг харах" мэт trailing.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailingLabel,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTypography.sectionTitle()),
        if (trailingLabel != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailingLabel!,
              style: AppTypography.meta(color: AppColors.primaryLight),
            ),
          ),
      ],
    );
  }
}