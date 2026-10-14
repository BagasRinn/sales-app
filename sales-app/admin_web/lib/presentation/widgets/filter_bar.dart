import 'package:flutter/material.dart';

import '../../core/responsive.dart';

class FilterBar extends StatelessWidget {
  final Widget? search;
  final List<Widget> filters;
  final Widget? trailing;

  const FilterBar({
    super.key,
    this.search,
    this.filters = const [],
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = Responsive.of(constraints.maxWidth);
        final padding = EdgeInsets.symmetric(
          horizontal: responsive.contentPadding,
        );

        if (responsive.isCompact) {
          return Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?search,
                if (search != null) const SizedBox(height: 8),
                if (filters.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: filters,
                  ),
                if (trailing != null) ...[
                  const SizedBox(height: 8),
                  trailing!,
                ],
              ],
            ),
          );
        }

        return Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ?search,
              if (search != null && filters.isNotEmpty)
                const SizedBox(width: 12),
              if (filters.isNotEmpty)
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: filters,
                  ),
                ),
              if ((search != null || filters.isNotEmpty) && trailing != null)
                const SizedBox(width: 12),
              ?trailing,
            ],
          ),
        );
      },
    );
  }
}
