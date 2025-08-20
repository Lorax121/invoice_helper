import 'package:flutter/material.dart';

class TokenChip extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  final double baseFontSize; 

  const TokenChip({
    super.key,
    required this.text,
    required this.isSelected,
    required this.onTap,
    required this.baseFontSize, 
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.2)
              : Colors.black.withOpacity(0.1),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: baseFontSize, 
          ),
        ),
      ),
    );
  }
}
