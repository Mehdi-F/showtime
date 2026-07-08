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
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Fill/border snap instantly — fading this at the same time as
          // the checkmark scales in made the whole thing read as two
          // overlapping fades instead of one crisp pop.
          color: checked ? Colors.greenAccent.shade400 : Colors.transparent,
          border: Border.all(
            color: checked ? Colors.greenAccent.shade400 : AppColors.textSecondary,
            width: 2,
          ),
        ),
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutBack,
            scale: checked ? 1 : 0,
            child: const Icon(Icons.check, color: Colors.black, size: 18),
          ),
        ),
      ),
    );
  }
}
