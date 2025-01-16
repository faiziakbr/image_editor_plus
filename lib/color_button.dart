import 'package:flutter/material.dart';

/// Button used in bottomNavigationBar in ImageEditorDrawing
class ColorButton extends StatelessWidget {
  final Color color;
  final Function(Color) onTap;
  final bool isSelected;

  const ColorButton({
    super.key,
    required this.color,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap(color);
      },
      child: Container(
        height: 34,
        width: 34,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 23),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white54,
            width: isSelected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
