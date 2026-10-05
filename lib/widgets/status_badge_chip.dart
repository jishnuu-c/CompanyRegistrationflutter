import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class StatusBadgeChip extends StatelessWidget {
  final String status;
  final bool isMini;

  const StatusBadgeChip({
    super.key,
    required this.status,
    this.isMini = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase().trim();

    Color bgColor;
    Color textColor;
    Color dotColor;
    Border? border;

    switch (s) {
      case 'ACTIVE':
        bgColor = const Color(0xFFECFDF5);
        textColor = const Color(0xFF065F46);
        dotColor = const Color(0xFF10B981);
        border = Border.all(color: const Color(0xFFA7F3D0));
        break;
      case 'PENDING':
        bgColor = const Color(0xFFFFFBEB);
        textColor = const Color(0xFF92400E);
        dotColor = const Color(0xFFF59E0B);
        border = Border.all(color: const Color(0xFFFDE68A));
        break;
      case 'INACTIVE':
        bgColor = const Color(0xFFFEF2F2);
        textColor = const Color(0xFF991B1B);
        dotColor = const Color(0xFFEF4444);
        border = Border.all(color: const Color(0xFFFECACA));
        break;
      case 'FEATURED':
        bgColor = const Color(0xFFEEF2FF);
        textColor = const Color(0xFF4338CA);
        dotColor = const Color(0xFF6366F1);
        border = Border.all(color: const Color(0xFFC7D2FE));
        break;
      default:
        bgColor = AppTheme.bgSubtle;
        textColor = AppTheme.textSecondary;
        dotColor = AppTheme.textMuted;
        border = Border.all(color: AppTheme.borderLight);
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMini ? 7 : 10,
        vertical: isMini ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isMini ? 5 : 7,
            height: isMini ? 5 : 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            s,
            style: GoogleFonts.inter(
              fontSize: isMini ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
