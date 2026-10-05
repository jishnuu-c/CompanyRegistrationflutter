import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class FeedbackData {
  final String type; // 'success' or 'error'
  final String title;
  final String message;

  FeedbackData({
    required this.type,
    required this.title,
    required this.message,
  });

  bool get isSuccess => type == 'success';
}

class FeedbackToast extends StatelessWidget {
  final FeedbackData feedback;
  final VoidCallback onClose;

  const FeedbackToast({
    super.key,
    required this.feedback,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = feedback.isSuccess;
    final bgColor = isSuccess ? AppTheme.successBg : AppTheme.errorBg;
    final borderColor = isSuccess ? AppTheme.successBorder : AppTheme.errorBorder;
    final iconColor = isSuccess ? AppTheme.success : AppTheme.error;
    final icon = isSuccess ? Icons.check_circle_rounded : Icons.warning_rounded;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  feedback.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feedback.message,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isSuccess ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 16,
                color: isSuccess ? const Color(0xFF047857) : const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
