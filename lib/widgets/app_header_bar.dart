import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';
import 'server_config_dialog.dart';

class AppHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget>? actions;

  const AppHeaderBar({
    super.key,
    required this.title,
    this.subtitle = 'Enterprise Directory & Catalog System',
    required this.icon,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    final apiConfig = ApiConfig();

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgSurface,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderLight, width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // Logo Icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // Backend Status Chip & Server Switcher
              ListenableBuilder(
                listenable: apiConfig,
                builder: (context, _) {
                  final isOnline = apiConfig.isOnline;
                  return InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ServerConfigDialog(),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOnline ? AppTheme.successBg : AppTheme.bgSubtle,
                        border: Border.all(
                          color: isOnline ? AppTheme.successBorder : AppTheme.borderMedium,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline ? AppTheme.success : AppTheme.textMuted,
                              boxShadow: isOnline
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.success.withValues(alpha: 0.5),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isOnline ? 'Online' : 'Configure',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isOnline ? const Color(0xFF065F46) : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
