// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/company_model.dart';

class FastAutofillBanner extends StatefulWidget {
  final List<CompanyResponse> companies;
  final ValueChanged<CompanyResponse> onAutofill;

  const FastAutofillBanner({
    super.key,
    required this.companies,
    required this.onAutofill,
  });

  @override
  State<FastAutofillBanner> createState() => _FastAutofillBannerState();
}

class _FastAutofillBannerState extends State<FastAutofillBanner> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isFocused = _focusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<CompanyResponse> get _suggestions {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return widget.companies.where((c) {
      final name = c.companyName.toLowerCase();
      final contact = (c.contactName ?? '').toLowerCase();
      final email = c.email.toLowerCase();
      return name.contains(q) || contact.contains(q) || email.contains(q);
    }).take(5).toList();
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    final showDropdown =
        (_isFocused || _controller.text.trim().isNotEmpty) &&
            suggestions.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 14,
                color: Color(0xFF7C3AED),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Fast Autofill / Copy from Registered Company:',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5B21B6),
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Search Input
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isFocused
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFFC4B5FD),
                width: 1.5,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.15),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 10, right: 8),
                  child: Icon(
                    Icons.search,
                    size: 17,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: const Color(0xFF1E1B4B),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 0,
                      ),
                      hintText:
                          'Search an existing company to pre-fill details (e.g. Apex Global)...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_controller.text.trim().isNotEmpty)
                  GestureDetector(
                    onTap: _clearSearch,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.cancel,
                        size: 17,
                        color: Color(0xFFA78BFA),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Autofill Suggestions Dropdown
          if (showDropdown) ...[
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFC4B5FD),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5B21B6).withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dropdown Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    color: const Color(0xFFF5F3FF),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bolt,
                          size: 14,
                          color: Color(0xFF6D28D9),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Choose company to copy details into form:',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6D28D9),
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFEDE9FE),
                  ),

                  // Suggestion Items
                  ...suggestions.map((c) {
                    final subtitle = [
                      c.city?.isNotEmpty == true
                          ? c.city
                          : (c.country?.isNotEmpty == true ? c.country : 'Global'),
                      if (c.contactName?.isNotEmpty == true)
                        c.contactName
                      else if (c.email.isNotEmpty)
                        c.email,
                    ].whereType<String>().join(' • ');

                    return InkWell(
                      onTap: () {
                        widget.onAutofill(c);
                        _clearSearch();
                        _focusNode.unfocus();
                      },
                      hoverColor: const Color(0xFFFBF7FF),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFFF5F3FF),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.companyName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E1B4B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: const Color(0xFF6B7280),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.arrow_forward,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 3.5),
                                    Text(
                                      'Autofill Form',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
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
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
