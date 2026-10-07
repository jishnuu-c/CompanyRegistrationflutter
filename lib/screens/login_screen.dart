import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/server_config_dialog.dart';
import 'main_shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'admin@enterprise.com');
  final _passwordController = TextEditingController(text: 'admin123');

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate realistic authentication delay
    await Future.delayed(const Duration(milliseconds: 850));

    if (!mounted) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Dummy validation logic
    if (email.isNotEmpty && password.length >= 4) {
      setState(() {
        _isLoading = false;
      });

      // Show success toast feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Welcome back, ${email.split('@').first}!',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Navigate to main shell
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainShellScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid email or password. Password must be at least 4 characters.';
      });
    }
  }

  void _fillDemoCredentials(String email, String password) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
      _errorMessage = null;
    });
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_reset_rounded, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Reset Password',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your registered email address and we will send you a password recovery link.',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Password reset link sent to ${resetEmailController.text.trim()}',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final apiConfig = ApiConfig();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // Background Decorative Top Mesh Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.42,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF312E81),
                    Color(0xFF4338CA),
                    Color(0xFF4F46E5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  // Decorative background blur circles
                  Positioned(
                    top: -50,
                    right: -30,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: -40,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App Branding Header
                          _buildBrandHeader(),
                          const SizedBox(height: 24),

                          // Login Card Container
                          _buildLoginCard(),
                          const SizedBox(height: 18),

                          // Demo Credentials Helper
                          _buildDemoCredentialsHelper(),
                          const SizedBox(height: 16),

                          // Server Connection & Footer
                          _buildFooter(apiConfig),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        // App Logo Icon Container
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                offset: const Offset(0, 8),
                blurRadius: 20,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.apartment_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Title
        Text(
          'CorpRegistry',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),

        // Subtitle
        Text(
          'Enterprise Directory & Catalog System',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.85),
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderLight, width: 1),
        boxShadow: AppTheme.shadowLg,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heading
            Text(
              'Sign In',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter your credentials to access your organization portal',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Error Banner if present
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.errorBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.errorBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Email Field
            Text(
              'Work Email',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. admin@enterprise.com',
                prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20, color: AppTheme.textSecondary),
                suffixIcon: _emailController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textMuted),
                        onPressed: () => setState(() => _emailController.clear()),
                      )
                    : null,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your work email';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password Field
            Text(
              'Password',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppTheme.textSecondary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 4) {
                  return 'Password must be at least 4 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Remember Me & Forgot Password Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Remember Me
                InkWell(
                  onTap: () {
                    setState(() {
                      _rememberMe = !_rememberMe;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            activeColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            side: const BorderSide(color: AppTheme.borderMedium, width: 1.5),
                            onChanged: (val) {
                              setState(() {
                                _rememberMe = val ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remember me',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Forgot Password
                TextButton(
                  onPressed: _showForgotPasswordDialog,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Sign In to Dashboard',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoCredentialsHelper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.bolt_rounded, color: AppTheme.primary, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Demo Quick Access',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'Tap to load',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildRoleChip(
                  role: 'Admin',
                  email: 'admin@enterprise.com',
                  pass: 'admin123',
                  badgeColor: AppTheme.primaryLight,
                  textColor: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRoleChip(
                  role: 'Manager',
                  email: 'manager@corp.com',
                  pass: 'manager123',
                  badgeColor: const Color(0xFFF3E8FF),
                  textColor: const Color(0xFF7E22CE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip({
    required String role,
    required String email,
    required String pass,
    required Color badgeColor,
    required Color textColor,
  }) {
    final isSelected = _emailController.text == email;

    return InkWell(
      onTap: () => _fillDemoCredentials(email, pass),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? badgeColor : AppTheme.bgSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? textColor.withValues(alpha: 0.4) : AppTheme.borderLight,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                role,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                email,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ApiConfig apiConfig) {
    return Column(
      children: [
        // Backend Config & Status Button
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderLight),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? AppTheme.success : AppTheme.warning,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Backend: Connected' : 'Backend: Offline (Demo Mode)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.settings_outlined, size: 13, color: AppTheme.textMuted),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Security Notice
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 12, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(
              'End-to-End Enterprise Encryption • v1.0.0',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
