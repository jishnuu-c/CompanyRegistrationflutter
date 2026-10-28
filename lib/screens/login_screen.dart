import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/auth_model.dart';
import '../services/auth/auth_config.dart';
import '../services/auth/biometric_service.dart';
import '../services/auth_service.dart';
import '../widgets/otp_input_boxes.dart';
import 'main_shell_screen.dart';
import 'register_screen.dart';

enum LoginMode { password, otp }

enum OtpStep { enterIdentifier, verifyOtp }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // Mode selection
  LoginMode _loginMode = LoginMode.password;
  OtpStep _otpStep = OtpStep.enterIdentifier;

  // Password Login Controllers
  final _passwordFormKey = GlobalKey<FormState>();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _isPasswordVisible = false;

  // OTP Login Controllers
  final _otpFormKey = GlobalKey<FormState>();
  final _otpIdentifierController = TextEditingController();
  final FocusNode _otpIdentifierFocus = FocusNode();
  final GlobalKey<OtpInputBoxesState> _otpBoxesKey =
      GlobalKey<OtpInputBoxesState>();
  String _enteredOtp = '';
  String? _debugOtpCode;
  int _otpExpiresInSeconds = 0;
  int _resendCooldownSeconds = 0;
  int _remainingAttempts = 3;
  Timer? _countdownTimer;

  // State
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Biometrics
  BiometricCapabilities _biometricCaps = const BiometricCapabilities();

  // Animations & Services
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

    // Check biometrics and existing session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometrics();
      if (_authService.isLoggedIn) {
        _navigateToDashboard();
      }
    });

    _authService.addListener(_onAuthServiceChanged);
  }

  void _onAuthServiceChanged() {
    if (mounted) {
      _checkBiometrics();
      setState(() {});
    }
  }

  Future<void> _checkBiometrics() async {
    try {
      final caps = await _authService.checkBiometrics();
      if (mounted) {
        setState(() {
          _biometricCaps = caps;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _otpIdentifierController.dispose();
    _otpIdentifierFocus.dispose();
    _authService.removeListener(_onAuthServiceChanged);
    super.dispose();
  }

  void _navigateToDashboard() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainShellScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  void _useDemoAdmin() {
    HapticFeedback.lightImpact();
    setState(() {
      _usernameOrEmailController.text = 'SuperAdmin';
      _passwordController.text = 'companyAdmin';
      _errorMessage = null;
    });
  }

  void _useDemoCompanyUser() {
    HapticFeedback.lightImpact();
    setState(() {
      _usernameOrEmailController.text = 'DemoUser';
      _passwordController.text = 'userPass123';
      _errorMessage = null;
    });
  }

  void _useDemoPhone() {
    HapticFeedback.lightImpact();
    setState(() {
      _otpIdentifierController.text = '9876543210';
      _errorMessage = null;
    });
  }

  void _useDemoEmail() {
    HapticFeedback.lightImpact();
    setState(() {
      _otpIdentifierController.text = 'admin@corpregistry.com';
      _errorMessage = null;
    });
  }

  // --- PASSWORD LOGIN ---
  Future<void> _handlePasswordLogin() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final usernameOrEmail = _usernameOrEmailController.text.trim();
    final password = _passwordController.text;

    try {
      final response = await _authService.login(usernameOrEmail, password);
      if (!mounted) return;

      HapticFeedback.mediumImpact();
      await _onSuccessfulLogin(response);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _isLoading = false;
        final rawMsg = e.toString().replaceFirst('Exception: ', '').trim();
        if (rawMsg.contains('SocketException') ||
            rawMsg.contains('Connection refused') ||
            rawMsg.contains('Failed host lookup') ||
            rawMsg.contains('timed out') ||
            rawMsg.contains('Unable to reach corporate server') ||
            rawMsg.isEmpty) {
          _errorMessage =
              'Authentication failed. Please verify that the server is online.';
        } else {
          _errorMessage = rawMsg;
        }
      });
    }
  }

  // --- OTP FLOW ---
  Future<void> _handleRequestOtp() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (!_otpFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final identifier = _otpIdentifierController.text.trim();

    try {
      final result = await _authService.requestOtp(identifier);
      if (!mounted) return;

      HapticFeedback.mediumImpact();
      _startOtpTimers(result.expiresInSeconds, result.cooldownSeconds);

      setState(() {
        _isLoading = false;
        _otpStep = OtpStep.verifyOtp;
        _debugOtpCode = result.debugOtpCode;
        _remainingAttempts = 3;
        _successMessage = result.message;
      });
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCooldownSeconds > 0) return;
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isLoading = true;
    });

    final identifier = _otpIdentifierController.text.trim();

    try {
      final result = await _authService.requestOtp(identifier);
      if (!mounted) return;

      HapticFeedback.lightImpact();
      _startOtpTimers(result.expiresInSeconds, result.cooldownSeconds);

      setState(() {
        _isLoading = false;
        _debugOtpCode = result.debugOtpCode;
        _remainingAttempts = 3;
        _successMessage = 'New OTP code dispatched to $identifier';
      });
      _otpBoxesKey.currentState?.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    final otp = _enteredOtp.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit verification code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final identifier = _otpIdentifierController.text.trim();

    try {
      final response = await _authService.verifyOtp(identifier, otp);
      if (!mounted) return;

      _countdownTimer?.cancel();
      HapticFeedback.mediumImpact();
      await _onSuccessfulLogin(response);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _otpBoxesKey.currentState?.clear();
      setState(() {
        _isLoading = false;
        final rawMsg = e.toString().replaceFirst('Exception: ', '');
        _errorMessage = rawMsg;
        if (_remainingAttempts > 1) {
          _remainingAttempts--;
        }
      });
    }
  }

  void _startOtpTimers(int expiresSeconds, int cooldownSeconds) {
    _countdownTimer?.cancel();
    _otpExpiresInSeconds = expiresSeconds;
    _resendCooldownSeconds = cooldownSeconds;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_otpExpiresInSeconds > 0) {
          _otpExpiresInSeconds--;
        }
        if (_resendCooldownSeconds > 0) {
          _resendCooldownSeconds--;
        }
        if (_otpExpiresInSeconds <= 0 && _resendCooldownSeconds <= 0) {
          timer.cancel();
        }
      });
    });
  }

  // --- BIOMETRICS LOGIN ---
  Future<void> _handleBiometricLogin() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (!_biometricCaps.isSupported || !_biometricCaps.canCheckBiometrics) {
      setState(() {
        _errorMessage = 'Biometric hardware is not available on this device.';
      });
      return;
    }

    if (!_biometricCaps.isEnrolled) {
      final bioName = _biometricCaps.displayName;
      setState(() {
        _errorMessage =
            'No biometrics enrolled. Please set up $bioName in device settings.';
      });
      return;
    }

    final boundUser = _biometricCaps.boundUsername;
    final isLinked =
        _biometricCaps.isEnabledByUser &&
        boundUser != null &&
        boundUser.trim().isNotEmpty;

    final isDemoValid =
        !_authService.isDemoMode ||
        (boundUser != null && _authService.isBoundDemoUserValid(boundUser));

    if (!isLinked || !isDemoValid) {
      // Informs user how to enable: shows "Biometrics Not Linked" dialog
      _showBiometricNotEnabledDialog();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _authService.authenticateWithBiometrics();
      if (!mounted) return;

      HapticFeedback.mediumImpact();
      _navigateToDashboard();

      final isFace = _biometricCaps.isFaceOnly;
      final methodTitle = isFace
          ? 'Face ID'
          : (_biometricCaps.isFingerprintOnly ? 'Fingerprint' : 'Biometric');
      final successMsg =
          '$methodTitle login successful for ${response.fullName.isNotEmpty ? response.fullName : response.username}!';
      final successIcon = isFace
          ? Icons.face_rounded
          : Icons.fingerprint_rounded;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(successIcon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  successMsg,
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
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showBiometricNotEnabledDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              _biometricCaps.isFaceOnly
                  ? Icons.face_rounded
                  : Icons.fingerprint_rounded,
              color: const Color(0xFF4F46E5),
              size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              'Biometrics Not Linked',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Biometric login has not yet been linked to an account on this device.\n\nPlease sign in with your password or OTP first, then enable ${_biometricCaps.displayName} when prompted.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            color: const Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Understood',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- POST-LOGIN CONSENT FOR BIOMETRICS ---
  Future<void> _onSuccessfulLogin(AuthResponse response) async {
    final username = response.username;
    final caps = await _authService.checkBiometrics();

    if (caps.isSupported &&
        caps.canCheckBiometrics &&
        caps.isEnrolled &&
        !caps.isEnabledByUser &&
        mounted) {
      // Offer explicit consent to enable biometrics
      final shouldEnable = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  caps.isFaceOnly
                      ? Icons.face_rounded
                      : Icons.fingerprint_rounded,
                  color: const Color(0xFF4F46E5),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enable ${caps.displayName}?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Would you like to enable ${caps.displayName} for "$username" on this device for instant 1-tap sign-in next time?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  color: const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.security_rounded,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stored securely using Hardware KeyStore / Keychain.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Maybe Later',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Enable Now',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldEnable == true && mounted) {
        try {
          final promptReason = caps.isFaceOnly
              ? 'Verify your face to enable quick login for $username'
              : (caps.isFingerprintOnly
                    ? 'Verify your fingerprint to enable quick login for $username'
                    : 'Verify your biometric identity to enable quick login for $username');

          final bioPrompt = await BiometricService().authenticate(
            reason: promptReason,
          );
          if (bioPrompt.success) {
            await _authService.enableBiometricsForUser(
              username,
              biometricType: caps.isFaceOnly
                  ? 'face'
                  : (caps.isFingerprintOnly ? 'fingerprint' : null),
            );
            _biometricCaps = await _authService.checkBiometrics();
            if (mounted) {
              final activeName = _biometricCaps.displayName;
              final activeIcon = _biometricCaps.isFaceOnly
                  ? Icons.face_rounded
                  : Icons.fingerprint_rounded;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(activeIcon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$activeName successfully linked for "$username".',
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
                  duration: const Duration(seconds: 3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          } else if (!bioPrompt.isCancelled && mounted) {
            final errorMsg =
                bioPrompt.errorMessage ??
                'Biometric verification failed. Enrollment skipped.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        errorMsg,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('[LoginScreen] Biometric enrollment error: $e');
          if (mounted) {
            final errorText = e.toString().replaceFirst('Exception: ', '');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Could not enable biometrics: $errorText',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      }
    }

    if (!mounted) return;
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
                'Welcome back, ${response.fullName.isNotEmpty ? response.fullName : response.username}!',
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- DEMO MODE CONFIG DIALOG ---
  void _showDemoModeInfoDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDemo = _authService.isDemoMode;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDemo
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDemo ? Icons.science_rounded : Icons.cloud_done_rounded,
                      color: isDemo
                          ? const Color(0xFFD97706)
                          : const Color(0xFF059669),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDemo ? 'Demo Mode Active' : 'API Mode Active',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        isDemo
                            ? 'Simulated Local Authentication'
                            : 'Connected to Spring Boot Backend',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isDemo
                    ? 'In DEMO mode, OTP generation, verification, and authentication run locally without requiring an active Spring Boot backend. Real native biometric authentication prompts continue to work normally.'
                    : 'In API mode, the application sends live authentication requests to your Spring Boot server. Ensure your backend server is online before attempting login.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  color: const Color(0xFF334155),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final newMode = isDemo ? AuthMode.api : AuthMode.demo;
                    await _authService.setAuthMode(newMode);
                    setState(() {
                      _errorMessage = null;
                      _successMessage = null;
                    });
                  },
                  icon: Icon(
                    isDemo ? Icons.cloud_outlined : Icons.science_outlined,
                  ),
                  label: Text(
                    isDemo
                        ? 'Switch to Spring Boot API Mode'
                        : 'Switch to DEMO Mode',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDemo
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Brand Header
                        _buildBrandHeader(),
                        const SizedBox(height: 14),

                        // Visible DEMO MODE Indicator
                        _buildDemoModePill(),
                        const SizedBox(height: 10),

                        // Main White Login Card
                        _buildLoginCard(isSmallScreen),
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

  /// Brand Header
  Widget _buildBrandHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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

  /// Visible DEMO MODE Indicator Pill
  Widget _buildDemoModePill() {
    final isDemo = _authService.isDemoMode;
    return Center(
      child: InkWell(
        onTap: _showDemoModeInfoDialog,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDemo
                ? const Color(0xFFFEF3C7).withValues(alpha: 0.6)
                : const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDemo ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDemo
                      ? const Color(0xFFD97706)
                      : const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                isDemo ? 'DEMO MODE ACTIVE' : 'API MODE (SPRING BOOT)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDemo
                      ? const Color(0xFF92400E)
                      : const Color(0xFF065F46),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Main White Login Card
  Widget _buildLoginCard(bool isSmallScreen) {
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
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 20 : 28,
        vertical: isSmallScreen ? 24 : 30,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Title & Subtitle
          Text(
            _loginMode == LoginMode.password
                ? 'Sign in to your account'
                : (_otpStep == OtpStep.enterIdentifier
                      ? 'Sign in with OTP'
                      : 'Verify Security Code'),
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
            _loginMode == LoginMode.password
                ? 'Enter your credentials to access your portal'
                : (_otpStep == OtpStep.enterIdentifier
                      ? 'Enter your phone number or email to receive a 6-digit code'
                      : 'Enter the 6-digit code sent to ${_otpIdentifierController.text}'),
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 18),

          // Auth Method Tabs: [ Password ] [ OTP Login ]
          _buildAuthTabs(),
          const SizedBox(height: 18),

          // Messages Banner
          if (_errorMessage != null) _buildErrorMessageBanner(_errorMessage!),
          if (_successMessage != null)
            _buildSuccessMessageBanner(_successMessage!),

          // Form Body based on selected Mode
          if (_loginMode == LoginMode.password)
            _buildPasswordForm()
          else if (_otpStep == OtpStep.enterIdentifier)
            _buildOtpIdentifierForm()
          else
            _buildOtpVerificationView(),

          // Biometric Quick Access (Fingerprint / Face ID)
          _buildBiometricQuickAccess(),
          const SizedBox(height: 16),

          // Switch to Register Link
          _buildSwitchToRegisterLink(),
          const SizedBox(height: 16),

          // Security Trust Badges
          _buildSecurityTrustBadges(),
        ],
      ),
    );
  }

  /// Mode Switch Tabs
  Widget _buildAuthTabs() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              title: 'Password',
              icon: Icons.lock_outline_rounded,
              isSelected: _loginMode == LoginMode.password,
              onTap: () {
                setState(() {
                  _loginMode = LoginMode.password;
                  _errorMessage = null;
                  _successMessage = null;
                });
              },
            ),
          ),
          Expanded(
            child: _buildTabButton(
              title: 'OTP Login',
              icon: Icons.sms_outlined,
              isSelected: _loginMode == LoginMode.otp,
              onTap: () {
                setState(() {
                  _loginMode = LoginMode.otp;
                  _errorMessage = null;
                  _successMessage = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Password Login Form
  Widget _buildPasswordForm() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Username or Email Field
          _buildFieldLabel('Username or Email', isRequired: true),
          const SizedBox(height: 6),
          TextFormField(
            controller: _usernameOrEmailController,
            focusNode: _usernameFocus,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
            ),
            decoration: _buildInputDecoration(
              hintText: 'Enter username or email',
              prefixIcon: Icons.person_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Username or email is required';
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
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handlePasswordLogin(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
            ),
            decoration: _buildInputDecoration(
              hintText: 'Enter your password',
              prefixIcon: Icons.lock_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: const Color(0xFF94A3B8),
                  size: 20,
                ),
                tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Password is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Demo Quick Access Pill
          _buildDemoAccountBox(),
          const SizedBox(height: 18),

          // Submit Button
          _buildPrimaryButton(
            title: 'Sign In to Portal',
            loadingText: 'Signing in...',
            onPressed: _handlePasswordLogin,
          ),
        ],
      ),
    );
  }

  /// OTP Identifier Entry (Step 1)
  Widget _buildOtpIdentifierForm() {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFieldLabel('Phone Number or Email', isRequired: true),
          const SizedBox(height: 6),
          TextFormField(
            controller: _otpIdentifierController,
            focusNode: _otpIdentifierFocus,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.text,
            onFieldSubmitted: (_) => _handleRequestOtp(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
            ),
            decoration: _buildInputDecoration(
              hintText: 'e.g. 9876543210 or admin@corpregistry.com',
              prefixIcon: Icons.contact_phone_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your phone number or email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Demo Quick Fill Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                label: Text(
                  'Demo Phone: 9876543210',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                avatar: const Icon(
                  Icons.flash_on_rounded,
                  size: 14,
                  color: Color(0xFF4F46E5),
                ),
                backgroundColor: const Color(0xFFEEF2FF),
                onPressed: _useDemoPhone,
              ),
              ActionChip(
                label: Text(
                  'Demo Email: admin@corpregistry.com',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                avatar: const Icon(
                  Icons.email_outlined,
                  size: 14,
                  color: Color(0xFF4F46E5),
                ),
                backgroundColor: const Color(0xFFEEF2FF),
                onPressed: _useDemoEmail,
              ),
            ],
          ),
          const SizedBox(height: 18),

          _buildPrimaryButton(
            title: 'Send 6-Digit OTP',
            loadingText: 'Sending OTP...',
            icon: Icons.send_rounded,
            onPressed: _handleRequestOtp,
          ),
        ],
      ),
    );
  }

  /// OTP 6-Digit Verification View (Step 2)
  Widget _buildOtpVerificationView() {
    final minutes = (_otpExpiresInSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_otpExpiresInSeconds % 60).toString().padLeft(2, '0');
    final isOtpExpired = _otpExpiresInSeconds <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Target Identifier Header with Change button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 16,
                color: Color(0xFF4F46E5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _otpIdentifierController.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _otpStep = OtpStep.enterIdentifier;
                    _errorMessage = null;
                  });
                },
                child: Text(
                  'Change',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Debug DEMO OTP Banner (ONLY visible in debug builds during DEMO mode)
        if (kDebugMode && _authService.isDemoMode && _debugOtpCode != null)
          _buildDebugDemoOtpBanner(_debugOtpCode!),

        // 6-Digit Input Boxes
        OtpInputBoxes(
          key: _otpBoxesKey,
          length: 6,
          enabled: !_isLoading && !isOtpExpired,
          hasError: _errorMessage != null,
          onChanged: (val) {
            _enteredOtp = val;
            if (_errorMessage != null) {
              setState(() => _errorMessage = null);
            }
          },
          onCompleted: (code) {
            _enteredOtp = code;
            _handleVerifyOtp();
          },
        ),
        const SizedBox(height: 14),

        // Timer, Cooldown, and Attempt Counter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: isOtpExpired
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      isOtpExpired
                          ? 'Code expired'
                          : 'Expires in $minutes:$seconds',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOtpExpired
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$_remainingAttempts attempt${_remainingAttempts == 1 ? '' : 's'} left',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Resend Button with Cooldown
        Center(
          child: TextButton.icon(
            onPressed: (_resendCooldownSeconds > 0 || _isLoading)
                ? null
                : _handleResendOtp,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              _resendCooldownSeconds > 0
                  ? 'Resend OTP (${_resendCooldownSeconds}s)'
                  : 'Resend OTP Code',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Verify Button
        _buildPrimaryButton(
          title: 'Verify & Sign In',
          loadingText: 'Verifying...',
          onPressed: isOtpExpired ? null : _handleVerifyOtp,
        ),
      ],
    );
  }

  /// Debug DEMO OTP Banner (Never displayed in release builds)
  Widget _buildDebugDemoOtpBanner(String code) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.developer_mode_rounded,
                color: Color(0xFF2563EB),
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'DEMO SIMULATED OTP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1D4ED8),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  _otpBoxesKey.currentState?.setCode(code);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.flash_on_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Auto-Fill',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            code,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: const Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Simulated delivery for local testing. No actual SMS or email sent.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF3B82F6),
            ),
          ),
        ],
      ),
    );
  }

  /// Biometric Quick Access Button
  Widget _buildBiometricQuickAccess() {
    if (!_biometricCaps.isSupported || !_biometricCaps.canCheckBiometrics) {
      return const SizedBox.shrink();
    }

    final isFace = _biometricCaps.isFaceOnly;
    final label = _biometricCaps.quickAccessLabel;
    final icon = isFace ? Icons.face_rounded : Icons.fingerprint_rounded;
    final isEnabled = _biometricCaps.isEnabledByUser;
    final boundUser = _biometricCaps.boundUsername;

    final buttonText = isEnabled && boundUser != null && boundUser.isNotEmpty
        ? '$label ($boundUser)'
        : label;

    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Divider(color: Color(0xFFE2E8F0), thickness: 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR QUICK ACCESS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const Expanded(
              child: Divider(color: Color(0xFFE2E8F0), thickness: 1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _handleBiometricLogin,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: const Color(0xFFEEF2FF).withValues(alpha: 0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: const Color(0xFF4F46E5), size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    buttonText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Primary Submit Button
  Widget _buildPrimaryButton({
    required String title,
    required String loadingText,
    IconData? icon,
    VoidCallback? onPressed,
  }) {
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
          onPressed: _isLoading ? null : onPressed,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        loadingText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      icon ?? Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildErrorMessageBanner(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              msg,
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
    );
  }

  Widget _buildSuccessMessageBanner(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF10B981),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF047857),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildDemoAccountBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 15,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Role-Based Test Accounts',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Super Admin Card
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Text(
                        'SUPER_ADMIN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4338CA),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _useDemoAdmin,
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.flash_on_rounded, size: 11, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                'Auto Fill',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildCredentialRow('Username', 'SuperAdmin'),
                const Divider(height: 8, thickness: 0.6, color: Color(0xFFF1F5F9)),
                _buildCredentialRow('Password', 'companyAdmin'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Company User Card
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        'COMPANY_USER',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _useDemoCompanyUser,
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.flash_on_rounded, size: 11, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                'Auto Fill',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildCredentialRow('Username', 'DemoUser'),
                const Divider(height: 8, thickness: 0.6, color: Color(0xFFF1F5F9)),
                _buildCredentialRow('Password', 'userPass123'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchToRegisterLink() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      runSpacing: 2,
      children: [
        Text(
          "Don't have an account?",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w400,
          ),
        ),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const RegisterScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                transitionDuration: const Duration(milliseconds: 250),
              ),
            );
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Text(
              'Create an account',
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
              icon: _biometricCaps.isFaceOnly
                  ? Icons.face_rounded
                  : Icons.fingerprint_rounded,
              text: _biometricCaps.isFaceOnly
                  ? 'Face ID Keystore'
                  : 'Biometric Keystore',
            ),
            _buildSecurityBadgeItem(
              icon: Icons.verified_user_rounded,
              text: 'JJWT 0.12 Security',
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
