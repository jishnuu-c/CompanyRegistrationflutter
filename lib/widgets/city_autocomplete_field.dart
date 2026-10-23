import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/saudi_cities_util.dart';

/// A sleek city input field with datalist autocomplete matching the Angular implementation.
///
/// Allows entering any custom city freely, while providing suggestions for major
/// Saudi cities (e.g. Riyadh, Jeddah, Dammam, Khobar, Mecca, Medina, etc.).
class CityAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCitySelected;
  final String label;
  final String hintText;
  final FormFieldValidator<String>? validator;
  final List<SaudiCityInfo> cities;

  const CityAutocompleteField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onCitySelected,
    this.label = 'City',
    this.hintText = 'e.g. Riyadh, Jeddah...',
    this.validator,
    this.cities = SAUDI_CITIES_REGISTRY,
  });

  @override
  State<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<CityAutocompleteField> {
  final LayerLink _layerLink = LayerLink();
  late final FocusNode _focusNode;
  bool _internalFocusNode = false;

  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  int _highlightedIndex = -1;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _internalFocusNode = true;
    }

    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _removeOverlay(notify: false);
    _focusNode.removeListener(_handleFocusChange);
    if (_internalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _openOverlay();
    } else {
      _closeOverlay();
    }
  }

  List<SaudiCityInfo> _getMatchingCities() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) {
      // When field is empty, suggest the major economic & regional hubs
      return widget.cities;
    }

    final query = normalizeCityKey(text);
    return widget.cities.where((city) {
      final canonicalNorm = normalizeCityKey(city.canonicalName);
      final arabicNorm = normalizeCityKey(city.arabicName);
      final regionNorm = normalizeCityKey(city.region);

      if (canonicalNorm.contains(query) ||
          arabicNorm.contains(query) ||
          regionNorm.contains(query)) {
        return true;
      }

      // Check aliases
      for (final entry in CITY_ALIASES_MAP.entries) {
        if (entry.value.toLowerCase() == city.canonicalName.toLowerCase() &&
            entry.key.contains(query)) {
          return true;
        }
      }

      return false;
    }).toList();
  }

  void _openOverlay() {
    if (_isOpen || !mounted) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _isOpen = true;
    _highlightedIndex = -1;
  }

  void _closeOverlay() {
    if (!_isOpen) return;
    _removeOverlay(notify: true);
  }

  void _removeOverlay({bool notify = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
    if (notify && mounted) {
      setState(() {});
    }
  }

  void _updateOverlay() {
    if (_isOpen && _overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _selectCity(SaudiCityInfo city) {
    widget.controller.text = city.canonicalName;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: city.canonicalName.length),
    );

    widget.onChanged?.call(city.canonicalName);
    widget.onCitySelected?.call(city.canonicalName);

    _closeOverlay();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final matching = _getMatchingCities();
    if (matching.isEmpty) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (!_isOpen) {
        _openOverlay();
        return KeyEventResult.handled;
      }
      setState(() {
        _highlightedIndex = (_highlightedIndex + 1) % matching.length;
      });
      _updateOverlay();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (!_isOpen) {
        _openOverlay();
        return KeyEventResult.handled;
      }
      setState(() {
        _highlightedIndex =
            (_highlightedIndex - 1 + matching.length) % matching.length;
      });
      _updateOverlay();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_isOpen &&
          _highlightedIndex >= 0 &&
          _highlightedIndex < matching.length) {
        _selectCity(matching[_highlightedIndex]);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _closeOverlay();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(200, 44);

    return OverlayEntry(
      builder: (context) {
        final matching = _getMatchingCities();

        if (matching.isEmpty) {
          return const SizedBox.shrink();
        }

        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4),
            child: TapRegion(
              groupId: 'city_autocomplete_region',
              onTapOutside: (_) => _closeOverlay(),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.borderMedium,
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: matching.length,
                    itemBuilder: (context, index) {
                      final city = matching[index];
                      final isHighlighted = index == _highlightedIndex;

                      return _CitySuggestionTile(
                        city: city,
                        isHighlighted: isHighlighted,
                        onTap: () => _selectCity(city),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        CompositedTransformTarget(
          link: _layerLink,
          child: TapRegion(
            groupId: 'city_autocomplete_region',
            child: Focus(
              onKeyEvent: _handleKeyEvent,
              child: TextFormField(
                controller: widget.controller,
                focusNode: _focusNode,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppTheme.borderMedium,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppTheme.borderLight,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppTheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: widget.validator,
                onTap: () {
                  if (!_isOpen) {
                    _openOverlay();
                  }
                },
                onChanged: (val) {
                  widget.onChanged?.call(val);
                  if (!_isOpen && _focusNode.hasFocus) {
                    _openOverlay();
                  } else {
                    _updateOverlay();
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CitySuggestionTile extends StatefulWidget {
  final SaudiCityInfo city;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _CitySuggestionTile({
    required this.city,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  State<_CitySuggestionTile> createState() => _CitySuggestionTileState();
}

class _CitySuggestionTileState extends State<_CitySuggestionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isHighlighted || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
          color: active ? const Color(0xFFF1F5F9) : Colors.transparent,
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 15,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.city.canonicalName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Arabic name badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 0.7,
                  ),
                ),
                child: Text(
                  widget.city.arabicName,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
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
