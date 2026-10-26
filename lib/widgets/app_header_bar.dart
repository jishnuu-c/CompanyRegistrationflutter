import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/login_screen.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

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
  Size get preferredSize => const Size.fromHeight(66);

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppTheme.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Sign Out',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out from the enterprise session?',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              AuthService().logout();
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const LoginScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showUserProfileBottomSheet(BuildContext context) {
    final auth = AuthService();
    final user = auth.currentUser;
    final isSuper = auth.isSuperAdmin;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title row with close icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Session',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // User Info Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bgPage,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isSuper
                            ? const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF059669), Color(0xFF10B981)],
                              ),
                      ),
                      child: Center(
                        child: Text(
                          (user?.username.isNotEmpty == true)
                              ? user!.username[0].toUpperCase()
                              : 'A',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName.isNotEmpty == true
                                ? user!.fullName
                                : (user?.username ?? 'Administrator'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? 'admin@corpregistry.com',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Role Permissions Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSuper
                      ? const Color(0xFFEEF2FF)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSuper
                        ? const Color(0xFFC7D2FE)
                        : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSuper
                              ? Icons.shield_rounded
                              : Icons.business_rounded,
                          size: 16,
                          color: isSuper
                              ? const Color(0xFF4338CA)
                              : const Color(0xFF047857),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isSuper ? 'SUPER_ADMIN ROLE' : 'COMPANY_USER ROLE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isSuper
                                ? const Color(0xFF4338CA)
                                : const Color(0xFF047857),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isSuper
                          ? '• Full administrative authority: create, edit, and delete all corporate records across the directory.'
                          : '• Standard enterprise authority: register and update your own company records. Company deletion is restricted to Super Admin.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isSuper
                            ? const Color(0xFF3730A3)
                            : const Color(0xFF065F46),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Enterprise Session Security Status Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.bgPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        size: 16,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enterprise Session Active',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Corporate Single Sign-On Verified',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Sign Out Button
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showLogoutDialog(context);
                },
                icon: const Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: AppTheme.error,
                ),
                label: Text(
                  'Sign Out of Enterprise Session',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.error,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.errorBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiConfig = ApiConfig();

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgSurface,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderLight, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x060F172A),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Module Brand Icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.22),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),

              // 2. Title & Live Status / Role (Never squished or truncated)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Role & Online Sub-row
                    ListenableBuilder(
                      listenable: AuthService(),
                      builder: (context, _) {
                        final auth = AuthService();
                        final isSuper = auth.isSuperAdmin;

                        return ListenableBuilder(
                          listenable: apiConfig,
                          builder: (context, _) {
                            final isOnline = apiConfig.isOnline;

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Role Micro Pill
                                InkWell(
                                  onTap: () =>
                                      _showUserProfileBottomSheet(context),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSuper
                                          ? const Color(0xFFEEF2FF)
                                          : const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isSuper
                                            ? const Color(0xFFC7D2FE)
                                            : const Color(0xFFA7F3D0),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isSuper
                                              ? Icons.shield_rounded
                                              : Icons.business_rounded,
                                          size: 10,
                                          color: isSuper
                                              ? const Color(0xFF4338CA)
                                              : const Color(0xFF047857),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          isSuper
                                              ? 'SUPER_ADMIN'
                                              : 'COMPANY_USER',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: isSuper
                                                ? const Color(0xFF4338CA)
                                                : const Color(0xFF047857),
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 5),
                                Container(
                                  width: 2.5,
                                  height: 2.5,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                                const SizedBox(width: 5),

                                // Online Status Pill
                                InkWell(
                                  onTap: () {
                                    apiConfig.checkConnection();
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 1,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isOnline
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFF94A3B8),
                                            boxShadow: isOnline
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFF10B981,
                                                      ).withValues(alpha: 0.5),
                                                      blurRadius: 3,
                                                      spreadRadius: 0.5,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isOnline ? 'Online' : 'Offline',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isOnline
                                                ? const Color(0xFF059669)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
            ),
          ),

          const SizedBox(width: 8),

          // 3. User Avatar Button with Status Dot
          ListenableBuilder(
            listenable: AuthService(),
            builder: (context, _) {
              final auth = AuthService();
              final user = auth.currentUser;
              final isSuper = auth.isSuperAdmin;
              final username = user?.username ?? 'Admin';
              final initial = username.isNotEmpty
                  ? username[0].toUpperCase()
                  : 'A';

              return InkWell(
                onTap: () => _showUserProfileBottomSheet(context),
                borderRadius: BorderRadius.circular(18),
                child: Tooltip(
                  message: 'Account: $username (${user?.role ?? "ROLE_ADMIN"})',
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isSuper
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF4F46E5),
                                    Color(0xFF6366F1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF059669),
                                    Color(0xFF10B981),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isSuper
                                          ? const Color(0xFF4F46E5)
                                          : const Color(0xFF059669))
                                      .withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 8),

          // 4. Clean Logout Action Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showLogoutDialog(context),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
