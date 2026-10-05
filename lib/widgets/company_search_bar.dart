import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/company_model.dart';
import '../services/company_service.dart';
import '../theme/app_theme.dart';
import 'status_badge_chip.dart';

class CompanySearchBar extends StatefulWidget {
  final List<CompanyResponse> allCompanies;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<CompanyResponse> onCompanyInspect;
  final ValueChanged<CompanyResponse>? onCompanySelected;

  const CompanySearchBar({
    super.key,
    required this.allCompanies,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onCompanyInspect,
    this.onCompanySelected,
  });

  @override
  State<CompanySearchBar> createState() => _CompanySearchBarState();
}

class _CompanySearchBarState extends State<CompanySearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final CompanyService _companyService = CompanyService();

  OverlayEntry? _overlayEntry;
  int _highlightedIndex = 0;
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.searchQuery;
  }

  @override
  void didUpdateWidget(covariant CompanySearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _controller.text) {
      _controller.text = widget.searchQuery;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
    if (_isDropdownOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isDropdownOpen) {
          _updateOverlay();
        }
      });
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<CompanyResponse> _getMatchingCompanies() {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) return [];

    return widget.allCompanies.where((comp) {
      final name = comp.companyName.toLowerCase();
      final contact = (comp.contactName ?? '').toLowerCase();
      final city = (comp.city ?? '').toLowerCase();
      final country = (comp.country ?? '').toLowerCase();
      final email = comp.email.toLowerCase();
      final brands = comp.brands.map((b) => b.brandName.toLowerCase()).join(' ');
      final products = comp.products.map((p) => p.name.toLowerCase()).join(' ');

      return name.contains(query) ||
          contact.contains(query) ||
          city.contains(query) ||
          country.contains(query) ||
          email.contains(query) ||
          brands.contains(query) ||
          products.contains(query);
    }).toList();
  }

  void _showOverlay() {
    _removeOverlay();
    final matching = _getMatchingCompanies();
    if (matching.isEmpty && _controller.text.trim().isEmpty) return;

    final overlay = Overlay.of(context);
    _overlayEntry = _createOverlayEntry();
    overlay.insert(_overlayEntry!);
    _isDropdownOpen = true;
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      if (_overlayEntry!.mounted) {
        _overlayEntry!.remove();
      }
      _overlayEntry = null;
    }
    _isDropdownOpen = false;
  }

  void _selectCompany(CompanyResponse comp) {
    _controller.text = comp.companyName;
    widget.onSearchChanged(comp.companyName);
    widget.onCompanySelected?.call(comp);
    _removeOverlay();
    _focusNode.unfocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final matching = _getMatchingCompanies();
    if (matching.isEmpty || !_isDropdownOpen) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _removeOverlay();
        _focusNode.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightedIndex = (_highlightedIndex + 1) % matching.length;
      });
      _updateOverlay();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightedIndex = (_highlightedIndex - 1 + matching.length) % matching.length;
      });
      _updateOverlay();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_highlightedIndex >= 0 && _highlightedIndex < matching.length) {
        _selectCompany(matching[_highlightedIndex]);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _removeOverlay();
      _focusNode.unfocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(320, 42);

    return OverlayEntry(
      builder: (context) {
        final matching = _getMatchingCompanies();
        final query = _controller.text.trim();
        final screenWidth = MediaQuery.of(context).size.width;
        final dropdownWidth = (screenWidth - 32).clamp(280.0, size.width < 340 ? 340.0 : (size.width > 520 ? 520.0 : size.width));

        return Positioned(
          width: dropdownWidth,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 6),
            child: TapRegion(
              groupId: 'company_search_region',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 380),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Dropdown Header matching Angular screenshot
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF6366F1)),
                            const SizedBox(width: 4),
                            Text(
                              'MATCHING COMPANIES',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Keyboard navigation hints with scroll protection
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildKeyHint('\u2191', null),
                                      _buildKeyHint('\u2193', 'nav'),
                                      const SizedBox(width: 3),
                                      _buildKeyHint('\u21B5', 'select'),
                                      const SizedBox(width: 3),
                                      _buildKeyHint('esc', 'close'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Matching Items List
                      if (matching.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          child: Column(
                            children: [
                              const Icon(Icons.search_off_outlined, size: 28, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 8),
                              Text(
                                'No companies matching "',
 style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
 ),
 const SizedBox(height: 2),
 Text(
 'Try searching by contact name, city, or brand',
 style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
 ),
 ],
 ),
 )
 else
 Flexible(
 child: ListView.separated(
 padding: EdgeInsets.zero,
 shrinkWrap: true,
 itemCount: matching.length,
 separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
 itemBuilder: (context, index) {
 final comp = matching[index];
 final isHighlighted = index == _highlightedIndex;

 return InkWell(
 onTap: () => _selectCompany(comp),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 decoration: BoxDecoration(
 color: isHighlighted ? const Color(0xFFF5F3FF) : Colors.white,
 border: Border(
 left: BorderSide(
 color: isHighlighted ? const Color(0xFF6366F1) : Colors.transparent,
 width: 3.5,
 ),
 ),
 ),
 child: Row(
 children: [
 // Avatar
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: AppTheme.primaryLight,
 borderRadius: BorderRadius.circular(8),
 ),
 clipBehavior: Clip.antiAlias,
 child: comp.businessCard != null && !comp.businessCard!.endsWith('.pdf')
 ? Image.network(
 _companyService.getFileUrl(comp.businessCard),
 fit: BoxFit.cover,
 errorBuilder: (c, e, s) => Center(
 child: Text(
 comp.companyName.isNotEmpty ? comp.companyName.substring(0, 1).toUpperCase() : 'C',
 style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 13),
 ),
 ),
 )
 : Center(
 child: Text(
 comp.companyName.isNotEmpty ? comp.companyName.substring(0, 1).toUpperCase() : 'C',
 style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 13),
 ),
 ),
 ),
 const SizedBox(width: 8),

 // Details column with highlight
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildHighlightedText(comp.companyName, query),
 const SizedBox(height: 2),
 Wrap(
 spacing: 6,
 runSpacing: 2,
 crossAxisAlignment: WrapCrossAlignment.center,
 children: [
 if (comp.contactName != null && comp.contactName!.isNotEmpty)
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.person_outline, size: 10.5, color: Color(0xFF94A3B8)),
 const SizedBox(width: 2),
 Text(
 comp.contactName!,
 style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
 ),
 ],
 ),
 if (comp.city != null && comp.city!.isNotEmpty)
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.location_on_outlined, size: 10.5, color: Color(0xFF94A3B8)),
 const SizedBox(width: 2),
 Text(
 comp.city!,
 style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
 ),
 ],
 ),
 if (comp.brands.isNotEmpty)
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.sell_outlined, size: 10, color: Color(0xFF2563EB)),
 const SizedBox(width: 2),
 Text(
 ' brands',
 style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
 ),
 ],
 ),
 ],
 ),
 ],
 ),
 ),
 const SizedBox(width: 6),

 // Status Badge Chip
 StatusBadgeChip(status: comp.status, isMini: true),
 const SizedBox(width: 4),

 // Quick Inspect / View Button
 InkWell(
 onTap: () {
 _removeOverlay();
 widget.onCompanyInspect(comp);
 },
 borderRadius: BorderRadius.circular(6),
 child: Container(
 padding: const EdgeInsets.all(4),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: const Icon(Icons.visibility_outlined, size: 13, color: Color(0xFF64748B)),
 ),
 ),
 ],
 ),
 ),
 );
 },
 ),
 ),

 // Dropdown Footer matching Angular screenshot
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: const BoxDecoration(
 color: Color(0xFFF8FAFC),
 border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
 ),
 child: Row(
 children: [
 const Icon(Icons.info_outline, size: 11, color: Color(0xFF64748B)),
 const SizedBox(width: 4),
 Expanded(
 child: Wrap(
 crossAxisAlignment: WrapCrossAlignment.center,
 children: [
 Text(
 'Click suggestion to filter directory or press ',
 style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
 decoration: BoxDecoration(
 color: const Color(0xFFE2E8F0),
 borderRadius: BorderRadius.circular(3),
 ),
 child: const Text('\u21B5', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 ),
 );
 },
 );
 }

 Widget _buildKeyHint(String keyLabel, String? desc) {
 return Container(
 margin: const EdgeInsets.only(left: 2.5),
 padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
 decoration: BoxDecoration(
 color: const Color(0xFFF1F5F9),
 borderRadius: BorderRadius.circular(4),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 keyLabel,
 style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
 ),
 if (desc != null) ...[
 const SizedBox(width: 2.5),
 Text(
 desc,
 style: GoogleFonts.inter(fontSize: 8.5, color: const Color(0xFF64748B)),
 ),
 ],
 ],
 ),
 );
 }

 Widget _buildHighlightedText(String fullText, String query) {
 if (query.isEmpty) {
 return Text(
 fullText,
 style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 );
 }

 final lowerText = fullText.toLowerCase();
 final lowerQuery = query.toLowerCase();
 final matchIndex = lowerText.indexOf(lowerQuery);

 if (matchIndex == -1) {
 return Text(
 fullText,
 style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 );
 }

 final before = fullText.substring(0, matchIndex);
 final match = fullText.substring(matchIndex, matchIndex + query.length);
 final after = fullText.substring(matchIndex + query.length);

 return Text.rich(
 TextSpan(
 style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
 children: [
 if (before.isNotEmpty) TextSpan(text: before),
 TextSpan(
 text: match,
 style: GoogleFonts.plusJakartaSans(
 fontSize: 12.5,
 fontWeight: FontWeight.w800,
 backgroundColor: const Color(0xFFFEF08A),
 color: const Color(0xFF854D0E),
 ),
 ),
 if (after.isNotEmpty) TextSpan(text: after),
 ],
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 );
 }

 @override
 Widget build(BuildContext context) {
 return TapRegion(
 groupId: 'company_search_region',
 onTapOutside: (_) {
 _removeOverlay();
 _focusNode.unfocus();
 },
 child: Focus(
 onKeyEvent: _handleKeyEvent,
 child: CompositedTransformTarget(
 link: _layerLink,
 child: Container(
 height: 38,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(
 color: _focusNode.hasFocus ? AppTheme.primary : const Color(0xFFE2E8F0),
 width: _focusNode.hasFocus ? 1.5 : 1.0,
 ),
 boxShadow: _focusNode.hasFocus
 ? [
 BoxShadow(
 color: AppTheme.primary.withValues(alpha: 0.15),
 blurRadius: 6,
 offset: const Offset(0, 0),
 )
 ]
 : null,
 ),
 child: TextField(
 controller: _controller,
 focusNode: _focusNode,
 style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF1E293B)),
 decoration: InputDecoration(
 isDense: true,
 hintText: 'Search by company name, contact, city...',
 hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
 prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF6366F1)),
 contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 border: InputBorder.none,
 suffixIcon: _controller.text.isNotEmpty
 ? IconButton(
 icon: const Icon(Icons.cancel, size: 15, color: Color(0xFF94A3B8)),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 onPressed: () {
 _controller.clear();
 widget.onSearchChanged('');
 setState(() {});
 _removeOverlay();
 },
 )
 : null,
 ),
 onTap: () {
 if (_controller.text.trim().isNotEmpty && !_isDropdownOpen) {
 _showOverlay();
 }
 },
 onChanged: (val) {
 setState(() {});
 widget.onSearchChanged(val);
 if (val.trim().isNotEmpty) {
 if (!_isDropdownOpen) {
 _showOverlay();
 } else {
 _updateOverlay();
 }
 } else {
 _removeOverlay();
 }
 },
 ),
 ),
 ),
 ),
 );
 }
}
