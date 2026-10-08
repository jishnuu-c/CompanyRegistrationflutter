import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header_bar.dart';
import 'brand_screen.dart';
import 'category_screen.dart';
import 'company_screen.dart';
import 'product_screen.dart';

class MainShellScreen extends StatefulWidget {
  final int initialTabIndex;

  const MainShellScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _currentIndex;
  final List<int> _tabHistory = [0];
  DateTime? _lastBackPressTime;

  final GlobalKey<CompanyScreenState> _companyScreenKey = GlobalKey<CompanyScreenState>();
  final GlobalKey<CategoryScreenState> _categoryScreenKey = GlobalKey<CategoryScreenState>();
  final GlobalKey<BrandScreenState> _brandScreenKey = GlobalKey<BrandScreenState>();
  final GlobalKey<ProductScreenState> _productScreenKey = GlobalKey<ProductScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _tabHistory.clear();
    _tabHistory.add(_currentIndex);
  }

  void _switchTab(int index) {
    if (_currentIndex != index) {
      setState(() {
        _tabHistory.remove(index);
        _tabHistory.add(index);
        _currentIndex = index;
      });
    }
  }

  Future<void> _handleBackPress() async {
    // 1. Delegate back press to the active screen's internal state (detail modal, edit mode, directory tab)
    bool handledByScreen = false;
    switch (_currentIndex) {
      case 0:
        handledByScreen = _companyScreenKey.currentState?.handleBackPress() ?? false;
        break;
      case 1:
        handledByScreen = _categoryScreenKey.currentState?.handleBackPress() ?? false;
        break;
      case 2:
        handledByScreen = _brandScreenKey.currentState?.handleBackPress() ?? false;
        break;
      case 3:
        handledByScreen = _productScreenKey.currentState?.handleBackPress() ?? false;
        break;
    }

    if (handledByScreen) return;

    // 2. Delegate to Tab History if user navigated across tabs
    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
        _currentIndex = _tabHistory.last;
      });
      return;
    }

    // 3. If currently on a non-home tab, return to Companies (index 0)
    if (_currentIndex != 0) {
      _switchTab(0);
      return;
    }

    // 4. On root screen (Companies): Double-tap to exit protection
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                'Press back again to exit',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      );
      return;
    }

    // User pressed back twice within 2s -> exit the application cleanly
    SystemNavigator.pop();
  }

  String get _currentModuleTitle {
    switch (_currentIndex) {
      case 0:
        return 'Company Portal';
      case 1:
        return 'Category Portal';
      case 2:
        return 'Brand Portal';
      case 3:
        return 'Product Portal';
      default:
        return 'Company Portal';
    }
  }

  IconData get _currentModuleIcon {
    switch (_currentIndex) {
      case 0:
        return Icons.apartment_rounded;
      case 1:
        return Icons.label_rounded;
      case 2:
        return Icons.verified_rounded;
      case 3:
        return Icons.inventory_2_rounded;
      default:
        return Icons.apartment_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      CompanyScreen(key: _companyScreenKey),
      CategoryScreen(key: _categoryScreenKey),
      BrandScreen(key: _brandScreenKey),
      ProductScreen(key: _productScreenKey, onSwitchTab: _switchTab),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        appBar: AppHeaderBar(
          title: _currentModuleTitle,
          icon: _currentModuleIcon,
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppTheme.bgSurface,
            border: Border(
              top: BorderSide(color: AppTheme.borderLight, width: 1),
            ),
            boxShadow: AppTheme.shadowSm,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    index: 0,
                    label: 'Companies',
                    icon: Icons.apartment_outlined,
                    activeIcon: Icons.apartment_rounded,
                  ),
                  _buildNavItem(
                    index: 1,
                    label: 'Categories',
                    icon: Icons.label_outline_rounded,
                    activeIcon: Icons.label_rounded,
                  ),
                  _buildNavItem(
                    index: 2,
                    label: 'Brands',
                    icon: Icons.verified_outlined,
                    activeIcon: Icons.verified_rounded,
                  ),
                  _buildNavItem(
                    index: 3,
                    label: 'Products',
                    icon: Icons.inventory_2_outlined,
                    activeIcon: Icons.inventory_2_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => _switchTab(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
