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

/// Floating Viewport Notification Toast matching the Angular .feedback-toast design:
/// - Crisp #FFFFFF card background
/// - 5px solid left border accent (#10B981 emerald for success, #EF4444 red for error)
/// - Subtle border tint on remaining sides
/// - 14px border radius with deep elevation shadow
/// - 34x34px rounded icon badge
/// - Bold title in emerald / crimson and Slate 700 body message
/// - Interactive close button and smooth float-up entrance animation
class FeedbackToast extends StatefulWidget {
  final FeedbackData feedback;
  final VoidCallback onClose;
  final bool animate;

  const FeedbackToast({
    super.key,
    required this.feedback,
    required this.onClose,
    this.animate = true,
  });

  @override
  State<FeedbackToast> createState() => _FeedbackToastState();
}

class _FeedbackToastState extends State<FeedbackToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
      ),
    );

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(FeedbackToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feedback != oldWidget.feedback && widget.animate) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() async {
    await _controller.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.feedback.isSuccess;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Palette strictly matching Angular styles.css
    final accentColor = isSuccess
        ? const Color(0xFF10B981) // Emerald 500
        : const Color(0xFFEF4444); // Red 500

    final subtleBorderColor = isSuccess
        ? const Color(0x3310B981) // rgba(16, 185, 129, 0.2)
        : const Color(0x33EF4444); // rgba(239, 68, 68, 0.2)

    final iconBgColor = isSuccess
        ? const Color(0xFFD1FAE5) // Emerald 100
        : const Color(0xFFFEE2E2); // Red 100

    final iconColor = isSuccess
        ? const Color(0xFF059669) // Emerald 600
        : const Color(0xFFDC2626); // Red 600

    final titleColor = isSuccess
        ? const Color(0xFF065F46) // Emerald 800
        : const Color(0xFF991B1B); // Red 800

    const messageColor = Color(0xFF334155); // Slate 700

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: subtleBorderColor, width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x380F172A), // rgba(15, 23, 42, 0.22)
                blurRadius: 32,
                offset: Offset(0, 14),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Color(0x140F172A), // 1px subtle edge shadow
                blurRadius: 2,
                offset: Offset(0, 1),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Accent 5px Bar matching Angular border-left: 5px solid
                  Container(
                    width: 5.0,
                    color: accentColor,
                  ),

                  // Main Content Area
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 12 : 14,
                        isMobile ? 12 : 14,
                        isMobile ? 8 : 10,
                        isMobile ? 12 : 14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 34x34 Icon Badge with 9px rounded corners
                          Container(
                            width: 34,
                            height: 34,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              isSuccess
                                  ? Icons.check_circle_rounded
                                  : Icons.error_outline_rounded,
                              color: iconColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Text Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Title
                                Text(
                                  widget.feedback.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isMobile ? 13.5 : 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    color: titleColor,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 3),

                                // Message
                                Text(
                                  widget.feedback.message,
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 12.5 : 13,
                                    fontWeight: FontWeight.w400,
                                    color: messageColor,
                                    height: 1.45,
                                  ),
                                ),

                                // Optional Badges
                                if (widget.feedback.badges != null &&
                                    widget.feedback.badges!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: widget.feedback.badges!.map((badge) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSuccess
                                              ? const Color(0xFFF0FDF4)
                                              : const Color(0xFFFEF2F2),
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
                                              color: iconColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              badge.label,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: titleColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],

                                // Optional Action Prompt
                                if (widget.feedback.actionPrompt != null &&
                                    widget.feedback.actionPrompt!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_downward_rounded,
                                        size: 13,
                                        color: accentColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          widget.feedback.actionPrompt!,
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            fontStyle: FontStyle.italic,
                                            color: const Color(0xFF64748B),
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

                          const SizedBox(width: 6),

                          // Close Button (28x28 with 8px radius)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _handleDismiss,
                              borderRadius: BorderRadius.circular(8),
                              hoverColor: const Color(0xFFF1F5F9),
                              child: Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
