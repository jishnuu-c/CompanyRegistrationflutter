import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
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
      const CompanyScreen(),
      const CategoryScreen(),
      const BrandScreen(),
      ProductScreen(onSwitchTab: _switchTab),
    ];

    return Scaffold(
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
