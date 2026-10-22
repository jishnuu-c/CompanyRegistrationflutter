import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Country model representing a code badge and country name
class CountryOption {
  final String code;
  final String name;

  const CountryOption({
    required this.code,
    required this.name,
  });

  String get formatted => '$code - $name';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountryOption &&
          runtimeType == other.runtimeType &&
          code.toLowerCase() == other.code.toLowerCase() &&
          name.toLowerCase() == other.name.toLowerCase();

  @override
  int get hashCode => code.toLowerCase().hashCode ^ name.toLowerCase().hashCode;
}

/// A custom, highly-polished country dropdown widget that matches the Angular design
class SearchableCountryDropdown extends StatefulWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String hintText;
  final String searchHint;
  final bool isRequired;
  final String label;
  final FormFieldValidator<String>? validator;

  /// Full list of countries, defaults to matching Angular items exactly
  final List<CountryOption>? countries;

  const SearchableCountryDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Country Jurisdiction',
    this.hintText = 'Select Country...',
    this.searchHint = 'Search country by code or name...',
    this.isRequired = true,
    this.validator,
    this.countries,
  });

  /// Default country options matching the Angular application
  static const List<CountryOption> defaultCountries = [
    // Top featured countries matching Angular UI order:
    CountryOption(code: 'USA', name: 'United States'),
    CountryOption(code: 'KSA', name: 'Saudi Arabia'),
    CountryOption(code: 'IND', name: 'India'),
    CountryOption(code: 'UAE', name: 'United Arab Emirates'),
    CountryOption(code: 'UK', name: 'United Kingdom'),
    CountryOption(code: 'AFG', name: 'Afghanistan'),

    // Extended global countries in alphabetical order:
    CountryOption(code: 'ALB', name: 'Albania'),
    CountryOption(code: 'DZA', name: 'Algeria'),
    CountryOption(code: 'ARG', name: 'Argentina'),
    CountryOption(code: 'AUS', name: 'Australia'),
    CountryOption(code: 'AUT', name: 'Austria'),
    CountryOption(code: 'BHR', name: 'Bahrain'),
    CountryOption(code: 'BGD', name: 'Bangladesh'),
    CountryOption(code: 'BEL', name: 'Belgium'),
    CountryOption(code: 'BRA', name: 'Brazil'),
    CountryOption(code: 'CAN', name: 'Canada'),
    CountryOption(code: 'CHL', name: 'Chile'),
    CountryOption(code: 'CHN', name: 'China'),
    CountryOption(code: 'COL', name: 'Colombia'),
    CountryOption(code: 'DNK', name: 'Denmark'),
    CountryOption(code: 'EGY', name: 'Egypt'),
    CountryOption(code: 'FIN', name: 'Finland'),
    CountryOption(code: 'FRA', name: 'France'),
    CountryOption(code: 'DEU', name: 'Germany'),
    CountryOption(code: 'IDN', name: 'Indonesia'),
    CountryOption(code: 'IRL', name: 'Ireland'),
    CountryOption(code: 'ITA', name: 'Italy'),
    CountryOption(code: 'JPN', name: 'Japan'),
    CountryOption(code: 'JOR', name: 'Jordan'),
    CountryOption(code: 'KEN', name: 'Kenya'),
    CountryOption(code: 'KOR', name: 'South Korea'),
    CountryOption(code: 'KWT', name: 'Kuwait'),
    CountryOption(code: 'LBN', name: 'Lebanon'),
    CountryOption(code: 'MYS', name: 'Malaysia'),
    CountryOption(code: 'MEX', name: 'Mexico'),
    CountryOption(code: 'NLD', name: 'Netherlands'),
    CountryOption(code: 'NZL', name: 'New Zealand'),
    CountryOption(code: 'NGA', name: 'Nigeria'),
    CountryOption(code: 'NOR', name: 'Norway'),
    CountryOption(code: 'OMN', name: 'Oman'),
    CountryOption(code: 'PAK', name: 'Pakistan'),
    CountryOption(code: 'PHL', name: 'Philippines'),
    CountryOption(code: 'POL', name: 'Poland'),
    CountryOption(code: 'QAT', name: 'Qatar'),
    CountryOption(code: 'SGP', name: 'Singapore'),
    CountryOption(code: 'ZAF', name: 'South Africa'),
    CountryOption(code: 'ESP', name: 'Spain'),
    CountryOption(code: 'SWE', name: 'Sweden'),
    CountryOption(code: 'CHE', name: 'Switzerland'),
    CountryOption(code: 'THA', name: 'Thailand'),
    CountryOption(code: 'TUR', name: 'Turkey'),
    CountryOption(code: 'VNM', name: 'Vietnam'),
  ];

  /// Normalize a country string into a standard CountryOption
  static CountryOption? findCountry(String? input, [List<CountryOption>? list]) {
    if (input == null || input.trim().isEmpty) return null;
    final trimmed = input.trim();
    final countries = list ?? defaultCountries;

    // Check exact formatted match (e.g. "USA - United States")
    for (final c in countries) {
      if (c.formatted.toLowerCase() == trimmed.toLowerCase() ||
          c.name.toLowerCase() == trimmed.toLowerCase() ||
          c.code.toLowerCase() == trimmed.toLowerCase()) {
        return c;
      }
    }

    // Check if input is formatted as "CODE - Name"
    if (trimmed.contains(' - ')) {
      final parts = trimmed.split(' - ');
      final code = parts[0].trim();
      final name = parts.sublist(1).join(' - ').trim();
      for (final c in countries) {
        if (c.name.toLowerCase() == name.toLowerCase() ||
            c.code.toLowerCase() == code.toLowerCase()) {
          return c;
        }
      }
      return CountryOption(code: code.toUpperCase(), name: name);
    }

    // Common aliases mapping
    final lower = trimmed.toLowerCase();
    if (lower == 'us' || lower == 'usa' || lower == 'united states of america') {
      return const CountryOption(code: 'USA', name: 'United States');
    }
    if (lower == 'uk' || lower == 'gbr' || lower == 'great britain' || lower == 'britain') {
      return const CountryOption(code: 'UK', name: 'United Kingdom');
    }
    if (lower == 'uae' || lower == 'are' || lower == 'united arab emirates') {
      return const CountryOption(code: 'UAE', name: 'United Arab Emirates');
    }
    if (lower == 'ksa' || lower == 'sau' || lower == 'saudi' || lower == 'saudi arabia') {
      return const CountryOption(code: 'KSA', name: 'Saudi Arabia');
    }

    // Fallback: create dynamic CountryOption
    final code = trimmed.length >= 3
        ? trimmed.substring(0, 3).toUpperCase()
        : trimmed.toUpperCase();
    return CountryOption(code: code, name: trimmed);
  }

  @override
  State<SearchableCountryDropdown> createState() =>
      _SearchableCountryDropdownState();
}

class _SearchableCountryDropdownState extends State<SearchableCountryDropdown>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _isHovered = false;
  String _searchQuery = '';
  String? _errorText;

  List<CountryOption> get _countryList =>
      widget.countries ?? SearchableCountryDropdown.defaultCountries;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _removeOverlay(notify: false);
    _animCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _validate() {
    if (widget.validator != null) {
      setState(() {
        _errorText = widget.validator!(widget.value);
      });
    }
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    if (_isOpen) return;
    _searchQuery = '';
    _searchCtrl.clear();

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
    });

    _animCtrl.forward(from: 0.0);

    // Request search field focus after frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isOpen) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeDropdown() {
    if (!_isOpen) return;
    _animCtrl.reverse().then((_) {
      _removeOverlay(notify: true);
      _validate();
    });
  }

  void _removeOverlay({bool notify = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (notify && mounted) {
      setState(() {
        _isOpen = false;
      });
    } else {
      _isOpen = false;
    }
  }

  void _selectCountry(CountryOption option) {
    widget.onChanged(option.formatted);
    _closeDropdown();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(200, 44);
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    // Check available screen height
    final screenHeight = MediaQuery.of(context).size.height;
    final spaceBelow = screenHeight - (offset.dy + size.height);
    final showAbove = spaceBelow < 270 && offset.dy > spaceBelow;

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Fullscreen backdrop to dismiss on outside click
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeDropdown,
                child: const SizedBox.expand(),
              ),
            ),

            // Dropdown panel anchored to trigger button
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor:
                  showAbove ? Alignment.topLeft : Alignment.bottomLeft,
              followerAnchor:
                  showAbove ? Alignment.bottomLeft : Alignment.topLeft,
              offset: Offset(0, showAbove ? -5.0 : 5.0),
              child: Align(
                alignment:
                    showAbove ? Alignment.bottomLeft : Alignment.topLeft,
                child: SizedBox(
                  width: size.width,
                  child: Material(
                    color: Colors.transparent,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: StatefulBuilder(
                          builder: (context, setOverlayState) {
                            final filtered = _countryList.where((c) {
                              if (_searchQuery.trim().isEmpty) return true;
                              final q = _searchQuery.toLowerCase().trim();
                              return c.name.toLowerCase().contains(q) ||
                                  c.code.toLowerCase().contains(q);
                            }).toList();

                            return Container(
                              constraints:
                                  const BoxConstraints(maxHeight: 255),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x140F172A),
                                    blurRadius: 18,
                                    offset: Offset(0, 8),
                                    spreadRadius: -2,
                                  ),
                                  BoxShadow(
                                    color: Color(0x0A0F172A),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. Search Box matching Angular
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 9.5,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Color(0xFFF1F5F9),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.search_rounded,
                                            size: 17,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: _searchCtrl,
                                              focusNode: _searchFocusNode,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    const Color(0xFF0F172A),
                                              ),
                                              cursorColor:
                                                  const Color(0xFF6366F1),
                                              cursorWidth: 1.5,
                                              cursorHeight: 16,
                                              decoration: InputDecoration(
                                                isDense: true,
                                                hintText: widget.searchHint,
                                                hintStyle: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w400,
                                                  color:
                                                      const Color(0xFF94A3B8),
                                                ),
                                                border: InputBorder.none,
                                                contentPadding:
                                                    EdgeInsets.zero,
                                              ),
                                              onChanged: (text) {
                                                setOverlayState(() {
                                                  _searchQuery = text;
                                                });
                                              },
                                              onSubmitted: (_) {
                                                if (filtered.isNotEmpty) {
                                                  _selectCountry(
                                                      filtered.first);
                                                }
                                              },
                                            ),
                                          ),
                                          if (_searchQuery.isNotEmpty)
                                            InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () {
                                                _searchCtrl.clear();
                                                setOverlayState(() {
                                                  _searchQuery = '';
                                                });
                                              },
                                              child: const Padding(
                                                padding: EdgeInsets.all(2.0),
                                                child: Icon(
                                                  Icons.close_rounded,
                                                  size: 16,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // 2. Filtered Country List
                                    Flexible(
                                      child: filtered.isEmpty
                                          ? Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 24,
                                                horizontal: 16,
                                              ),
                                              alignment: Alignment.center,
                                              child: Column(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.search_off_rounded,
                                                    size: 26,
                                                    color:
                                                        Color(0xFFCBD5E1),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'No countries found',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: const Color(
                                                          0xFF94A3B8),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Theme(
                                              data:
                                                  Theme.of(context).copyWith(
                                                scrollbarTheme:
                                                    ScrollbarThemeData(
                                                  thumbColor:
                                                      WidgetStateProperty
                                                          .all(
                                                    const Color(
                                                        0xFF94A3B8),
                                                  ),
                                                  thickness:
                                                      WidgetStateProperty
                                                          .all(4),
                                                  radius:
                                                      const Radius.circular(
                                                          4),
                                                  thumbVisibility:
                                                      WidgetStateProperty
                                                          .all(true),
                                                ),
                                              ),
                                              child: Scrollbar(
                                                controller: _scrollCtrl,
                                                child: ListView.builder(
                                                  controller: _scrollCtrl,
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    vertical: 4,
                                                  ),
                                                  shrinkWrap: true,
                                                  itemCount: filtered.length,
                                                  itemBuilder:
                                                      (context, idx) {
                                                    final country =
                                                        filtered[idx];
                                                    final currentSelected =
                                                        SearchableCountryDropdown
                                                            .findCountry(
                                                                widget
                                                                    .value,
                                                                _countryList);
                                                    final isSelected =
                                                        currentSelected !=
                                                                null &&
                                                            currentSelected ==
                                                                country;

                                                    return _DropdownItemTile(
                                                      country: country,
                                                      isSelected:
                                                          isSelected,
                                                      onTap: () =>
                                                          _selectCountry(
                                                              country),
                                                    );
                                                  },
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
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCountry =
        SearchableCountryDropdown.findCountry(widget.value, _countryList);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label with red asterisk
        Row(
          children: [
            Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            if (widget.isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),

        // Dropdown Trigger Field
        CompositedTransformTarget(
          link: _layerLink,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _toggleDropdown,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _errorText != null
                        ? AppTheme.error
                        : _isOpen
                            ? const Color(0xFF6366F1) // Active indigo border
                            : _isHovered
                                ? AppTheme.borderMedium
                                : AppTheme.borderLight,
                    width: _isOpen ? 1.5 : 1.0,
                  ),
                  boxShadow: _isOpen
                      ? const [
                          BoxShadow(
                            color: Color(0x1F6366F1),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: selectedCountry != null
                          ? Row(
                              children: [
                                // Country Code Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFDBEAFE),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    selectedCountry.code,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF2563EB),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    selectedCountry.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              widget.hintText,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF818CF8), // subtle indigo placeholder matching screenshot
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    const SizedBox(width: 8),

                    // Chevron Indicator (Points UP when open, DOWN when closed)
                    Icon(
                      _isOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: _isOpen
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (_errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _errorText!,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Dropdown Item Tile matching the Angular layout
class _DropdownItemTile extends StatefulWidget {
  final CountryOption country;
  final bool isSelected;
  final VoidCallback onTap;

  const _DropdownItemTile({
    required this.country,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DropdownItemTile> createState() => _DropdownItemTileState();
}

class _DropdownItemTileState extends State<_DropdownItemTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isSelected
        ? const Color(0xFFEEF2FF)
        : _isHovered
            ? const Color(0xFFF8FAFC)
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: bg,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          child: Row(
            children: [
              // Badge for Country Code
              Container(
                constraints: const BoxConstraints(minWidth: 40),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF), // soft blue background
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFFDBEAFE),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  widget.country.code,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB), // vibrant blue
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Country Name
              Expanded(
                child: Text(
                  widget.country.name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: widget.isSelected
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              if (widget.isSelected)
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Color(0xFF4F46E5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
