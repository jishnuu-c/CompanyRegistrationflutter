import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FeedbackBadge {
  final IconData icon;
  final String label;

  const FeedbackBadge({required this.icon, required this.label});
}

class FeedbackData {
  final String type; // 'success' or 'error'
  final String title;
  final String message;
  final String? actionPrompt;
  final List<FeedbackBadge>? badges;

  FeedbackData({
    required this.type,
    required this.title,
    required this.message,
    this.actionPrompt,
    this.badges,
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    final bgColor = isSuccess
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFFEF2F2);
    final borderColor = isSuccess
        ? const Color(0xFF86EFAC)
        : const Color(0xFFFCA5A5);
    final iconColor = isSuccess
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    final iconBgColor = isSuccess
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEE2E2);
    final titleColor = isSuccess
        ? const Color(0xFF065F46)
        : const Color(0xFF991B1B);
    final messageColor = isSuccess
        ? const Color(0xFF047857)
        : const Color(0xFFB91C1C);

    return Container(
      margin: EdgeInsets.fromLTRB(
        isMobile ? 12 : 20,
        isMobile ? 8 : 12,
        isMobile ? 12 : 20,
        isMobile ? 2 : 4,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color:
                (isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                    .withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circular Icon Badge
          Container(
            width: isMobile ? 28 : 32,
            height: isMobile ? 28 : 32,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: iconColor,
              size: isMobile ? 18 : 20,
            ),
          ),
          SizedBox(width: isMobile ? 10 : 12),

          // Main Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  feedback.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 3),

                // Primary Message
                Text(
                  feedback.message,
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 12 : 12.5,
                    fontWeight: FontWeight.w500,
                    color: messageColor,
                    height: 1.4,
                  ),
                ),

                // Badges (if provided)
                if (feedback.badges != null && feedback.badges!.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: feedback.badges!.map((badge) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isSuccess
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSuccess
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFFECACA),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              badge.icon,
                              size: 11,
                              color: isSuccess
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              badge.label,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isSuccess
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Action Prompt (if provided)
                if (feedback.actionPrompt != null &&
                    feedback.actionPrompt!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_downward_rounded,
                        size: 12,
                        color: isSuccess
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          feedback.actionPrompt!,
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 11 : 11.5,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            color: messageColor.withValues(alpha: 0.9),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Dismiss Button
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: messageColor.withValues(alpha: 0.08),
                ),
                child: Icon(Icons.close, size: 14, color: messageColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
