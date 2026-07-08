import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RoundCheck extends StatelessWidget {
  final bool checked;
  final VoidCallback? onTap;

  const RoundCheck({super.key, required this.checked, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? Colors.greenAccent.shade400 : Colors.transparent,
          border: Border.all(
            color: checked ? Colors.greenAccent.shade400 : AppColors.textSecondary,
            width: 2,
          ),
        ),
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutBack,
            scale: checked ? 1 : 0,
            child: const Icon(Icons.check, color: Colors.black, size: 18),
          ),
        ),
      ),
    );
  }
}
