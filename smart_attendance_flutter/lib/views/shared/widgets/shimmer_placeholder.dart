import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_theme.dart';

class ShimmerListPlaceholder extends StatelessWidget {
  final int itemCount;
  const ShimmerListPlaceholder({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const ShimmerCardPlaceholder(),
    );
  }
}

class ShimmerCardPlaceholder extends StatelessWidget {
  const ShimmerCardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.divider,
      highlightColor: Colors.white,
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class ShimmerStatsGrid extends StatelessWidget {
  const ShimmerStatsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: List.generate(4, (_) => const ShimmerCardPlaceholder()),
    );
  }
}
