import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Grid/list view switcher, styled to sit inline with a section header row
/// (matching TV Time's layout) rather than in the app bar.
class ViewModeToggle extends StatelessWidget {
  final bool isGrid;
  final VoidCallback onTap;

  const ViewModeToggle({super.key, required this.isGrid, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(isGrid ? Icons.view_list : Icons.grid_view, color: Colors.black, size: 20),
      ),
    );
  }
}
