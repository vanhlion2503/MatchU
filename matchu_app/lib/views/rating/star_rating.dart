import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onChanged;
  final int max;

  const StarRating({
    super.key,
    required this.rating,
    required this.onChanged,
    this.max = 5,
  });

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xFFFFC107);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(max, (index) {
        final value = index + 1.0;
        return IconButton(
          splashRadius: 22,
          onPressed: () => onChanged(value),
          icon: Icon(
            rating >= value ? Icons.star_rounded : Icons.star_border_rounded,
            color: rating >= value ? color : color,
            size: 36,
          ),
        );
      }),
    );
  }
}
