import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/auth_model.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'main_shell_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final FocusNode _fullNameFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();

    // If already logged in, navigate immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_authService.isLoggedIn) {
        _navigateToDashboard();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    _fullNameFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _navigateToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainShellScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
      (route) => false,
    );
  }

  void _navigateToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 250),
        ),
      );
    }
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match. Please verify both fields.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final request = RegisterRequest(
      fullName: _fullNameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: password,
    );

    try {
      final response = await _authService.register(request);

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      _navigateToDashboard();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Account created successfully! Welcome, ${response.fullName.isNotEmpty ? response.fullName : response.username}!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      HapticFeedback.heavyImpact();

      setState(() {
        _isLoading = false;
        final rawMsg = e.toString().replaceFirst('Exception: ', '');
        _errorMessage = rawMsg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 440;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 20,
                vertical: 24,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Brand Header matching Angular
                        _buildBrandHeader(),
                        const SizedBox(height: 18),

                        // Main White Register Card
                        _buildRegisterCard(isSmallScreen),
                        const SizedBox(height: 18),

                        // Server Connectivity Status & Footer Note
                        _buildServerStatusAndFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Brand Header matching Angular brand-header
  Widget _buildBrandHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Brand Logo Icon
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.apartment_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),

        // Brand Name & Tagline
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CorpRegistry',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'Enterprise Directory System',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Main White Register Card matching Angular .register-card
  Widget _buildRegisterCard(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 25,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 20 : 28,
        vertical: isSmallScreen ? 24 : 30,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Header
            Text(
              'Create your account',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isSmallScreen ? 21 : 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter your details below to set up your account',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),

            // Error Alert Banner
            if (_errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFEF4444),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFB91C1C),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Full Name Field
            _buildFieldLabel('Full Name', isRequired: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _fullNameController,
              focusNode: _fullNameFocus,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              decoration: _buildInputDecoration(
                hintText: 'e.g. John Doe',
                prefixIcon: Icons.badge_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Full name is required';
                }
                if (value.trim().length < 2) {
                  return 'Full name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Username Field
            _buildFieldLabel('Username', isRequired: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _usernameController,
              focusNode: _usernameFocus,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              decoration: _buildInputDecoration(
                hintText: 'e.g. johndoe',
                prefixIcon: Icons.person_rounded,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Username is required (min 3 characters)';
                }
                if (value.trim().length < 3) {
                  return 'Username must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Email Address Field
            _buildFieldLabel('Email Address', isRequired: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              focusNode: _emailFocus,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              decoration: _buildInputDecoration(
                hintText: 'e.g. john@company.com',
                prefixIcon: Icons.mail_outline_rounded,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'A valid email address is required';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value.trim())) {
                  return 'Please enter a valid email format';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Password Field
            _buildFieldLabel('Password', isRequired: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              obscureText: !_isPasswordVisible,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              decoration: _buildInputDecoration(
                hintText: 'Minimum 6 characters',
                prefixIcon: Icons.lock_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  tooltip: _isPasswordVisible
                      ? 'Hide password'
                      : 'Show password',
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Confirm Password Field
            _buildFieldLabel('Confirm Password', isRequired: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocus,
              obscureText: !_isConfirmPasswordVisible,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleRegister(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              decoration: _buildInputDecoration(
                hintText: 'Re-enter password',
                prefixIcon: Icons.shield_outlined,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  tooltip: _isConfirmPasswordVisible
                      ? 'Hide password'
                      : 'Show password',
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Submit Button
            _buildSubmitButton(),
            const SizedBox(height: 16),

            // Switch to Login Link
            _buildSwitchToLoginLink(),
            const SizedBox(height: 18),

            // Security Trust Badges
            _buildSecurityTrustBadges(),
          ],
        ),
      ),
    );
  }

  /// Field Label with Required Asterisk
  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFEF4444),
            ),
          ),
        ],
      ],
    );
  }

  /// Input Decoration matching Angular light form-control
  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hintText,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF94A3B8),
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF94A3B8), size: 20),
      suffixIcon: suffixIcon,
      errorStyle: GoogleFonts.plusJakartaSans(
        color: const Color(0xFFDC2626),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
      ),
    );
  }

  /// Submit Button with Gradient and Loading Spinner
  Widget _buildSubmitButton() {
    return SizedBox(
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Creating Account...',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Create Account',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Auth Switch Link: Already have an account? Sign In
  Widget _buildSwitchToLoginLink() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      runSpacing: 2,
      children: [
        Text(
          'Already have an account?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w400,
          ),
        ),
        InkWell(
          onTap: _navigateToLogin,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Text(
              'Sign In',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4F46E5),
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xFF4F46E5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Security Trust Badges matching Angular bottom card badges
  Widget _buildSecurityTrustBadges() {
    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 8,
          children: [
            _buildSecurityBadgeItem(
              icon: Icons.verified_user_rounded,
              text: 'Encrypted Credentials',
            ),
            _buildSecurityBadgeItem(
              icon: Icons.lock_rounded,
              text: 'BCrypt Password Security',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityBadgeItem({
    required IconData icon,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF10B981)),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  /// Enterprise Security & Footer Note
  Widget _buildServerStatusAndFooter() {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 13,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(width: 5),
            Text(
              'Enterprise Grade 256-bit TLS Security',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '© 2026 CorpRegistry Enterprise. All rights reserved.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: const Color(0xFF94A3B8),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
