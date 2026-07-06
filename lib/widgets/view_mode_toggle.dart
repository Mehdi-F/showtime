import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Grid/list view switcher, floating above the scrollable content rather
/// than occupying its own row in the layout.
class ViewModeToggle extends StatelessWidget {
  final bool isGrid;
  final VoidCallback onTap;

  const ViewModeToggle({super.key, required this.isGrid, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(isGrid ? Icons.view_list : Icons.grid_view, color: Colors.black, size: 20),
      ),
    );
  }
}
