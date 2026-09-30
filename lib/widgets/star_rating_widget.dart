import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StarRatingWidget extends StatefulWidget {
  final double rating;
  final ValueChanged<double> onRatingChanged;
  final double size;
  final bool readOnly;

  const StarRatingWidget({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.size = 28,
    this.readOnly = false,
  });

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  double? _hoverRating;

  @override
  Widget build(BuildContext context) {
    final displayRating = _hoverRating ?? widget.rating;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        IconData icon;
        Color color;

        if (displayRating >= starNumber) {
          icon = Icons.star_rounded;
          color = AppTheme.starGold;
        } else if (displayRating >= starNumber - 0.5) {
          icon = Icons.star_half_rounded;
          color = AppTheme.starGold;
        } else {
          icon = Icons.star_outline_rounded;
          color = Colors.grey.shade400;
        }

        Widget starWidget = MouseRegion(
          cursor: widget.readOnly ? SystemMouseCursors.basic : SystemMouseCursors.click,
          onEnter: (_) {
            if (!widget.readOnly) {
              setState(() => _hoverRating = starNumber.toDouble());
            }
          },
          onExit: (_) {
            if (!widget.readOnly) {
              setState(() => _hoverRating = null);
            }
          },
          child: GestureDetector(
            onTap: widget.readOnly
                ? null
                : () {
                    widget.onRatingChanged(starNumber.toDouble());
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Icon(
                icon,
                size: widget.size,
                color: color,
              ),
            ),
          ),
        );

        return starWidget;
      }),
    );
  }
}
