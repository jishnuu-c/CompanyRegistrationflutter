import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/company_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'company_detail_screen.dart';
import 'company_form_screen.dart';

class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({super.key});

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Company> _filteredList = [];
  String _selectedFilter = 'All';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _searchController.addListener(_onSearchChanged);
    _apiService.addListener(_onApiUpdated);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _apiService.removeListener(_onApiUpdated);
    super.dispose();
  }

  void _onApiUpdated() {
    if (mounted) {
      _applyFilter();
    }
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoading = true);
    await _apiService.getCompanies();
    if (mounted) {
      _applyFilter();
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    _applyFilter();
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredList = _apiService.companies.where((c) {
        final matchesQuery = query.isEmpty ||
            c.companyName.toLowerCase().contains(query) ||
            c.email.toLowerCase().contains(query) ||
            c.country.toLowerCase().contains(query) ||
            c.city.toLowerCase().contains(query) ||
            c.brands.any((b) => b.toLowerCase().contains(query)) ||
            c.products.any((p) => p.toLowerCase().contains(query));

        if (!matchesQuery) return false;

        if (_selectedFilter == 'High Rating') {
          return c.rating >= 4.0;
        } else if (_selectedFilter == 'With Documents') {
          return c.documents.isNotEmpty;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final formatted = url.startsWith('http://') || url.startsWith('https://') ? url : 'https://$url';
    final uri = Uri.tryParse(formatted);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmDelete(Company company) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('Delete Company', style: GoogleFonts.lora(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${company.companyName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && company.id != null) {
      await _apiService.deleteCompany(company.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${company.companyName}" deleted.'),
            backgroundColor: AppTheme.primaryNavy,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryNavy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Companies List',
          style: GoogleFonts.lora(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryNavy,
          ),
        ),
        actions: [
          if (isMobile)
            IconButton(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CompanyFormScreen()),
                );
                if (result == true) _loadCompanies();
              },
              icon: const Icon(Icons.add_circle, color: AppTheme.buttonNavy, size: 24),
              tooltip: 'Add Company',
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CompanyFormScreen()),
                  );
                  if (result == true) _loadCompanies();
                },
                icon: const Icon(Icons.add, size: 16),
                label: Text('Add New Company', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.buttonNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search & Filter Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Search bar input
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search companies, brands, products...',
                            prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.primaryNavy),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          style: GoogleFonts.outfit(fontSize: 13),
                        ),
                        const SizedBox(height: 8),

                        // Quick Filter Chips
                        Row(
                          children: [
                            Text(
                              'Filter:',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: ['All', 'High Rating', 'With Documents'].map((f) {
                                    final isSelected = _selectedFilter == f;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6.0),
                                      child: FilterChip(
                                        label: Text(f, style: GoogleFonts.outfit(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                        selected: isSelected,
                                        onSelected: (_) {
                                          setState(() => _selectedFilter = f);
                                          _applyFilter();
                                        },
                                        selectedColor: AppTheme.cardBg,
                                        checkmarkColor: AppTheme.primaryNavy,
                                        backgroundColor: Colors.grey.shade100,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: BorderSide(color: isSelected ? AppTheme.primaryNavy : Colors.grey.shade300),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18, color: AppTheme.primaryNavy),
                              tooltip: 'Refresh',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _loadCompanies,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Companies List
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy))
                        : _filteredList.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                itemCount: _filteredList.length,
                                separatorBuilder: (context, idx) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final company = _filteredList[index];
                                  return _buildCompanyCard(company);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No Companies Found',
              style: GoogleFonts.lora(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search query or register a new company.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CompanyFormScreen()),
                );
                if (result == true) _loadCompanies();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add New Company'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyCard(Company company) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CompanyDetailScreen(company: company)),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Center(
                    child: Text(
                      company.companyName.isNotEmpty ? company.companyName[0].toUpperCase() : 'C',
                      style: GoogleFonts.lora(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Name & Rating
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              company.companyName,
                              style: GoogleFonts.lora(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryNavy,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (company.rating > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 13, color: AppTheme.starGold),
                                  const SizedBox(width: 3),
                                  Text(
                                    company.rating.toStringAsFixed(1),
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${company.city.isNotEmpty ? '${company.city}, ' : ''}${company.country}',
                              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Contact Info
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                if (company.email.isNotEmpty)
                  _buildContactItem(Icons.email_outlined, company.email),
                if (company.mobile.isNotEmpty)
                  _buildContactItem(Icons.phone_iphone_outlined, company.mobile),
                if (company.website.isNotEmpty)
                  InkWell(
                    onTap: () => _launchUrl(company.website),
                    child: _buildContactItem(Icons.language_outlined, company.website, isLink: true),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Brands & Products Badges
            if (company.brands.isNotEmpty || company.products.isNotEmpty) ...[
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [
                  ...company.brands.map((b) => _buildBadgeChip('Brand: $b', Colors.blue.shade50, Colors.blue.shade900)),
                  ...company.products.map((p) => _buildBadgeChip('Product: $p', Colors.teal.shade50, Colors.teal.shade900)),
                  if (company.documents.isNotEmpty)
                    _buildBadgeChip('${company.documents.length} Docs', Colors.orange.shade50, Colors.orange.shade900),
                ],
              ),
              const SizedBox(height: 8),
            ],

            const Divider(height: 1),
            const SizedBox(height: 4),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CompanyDetailScreen(company: company)),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('View'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryNavy,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CompanyFormScreen(companyToEdit: company)),
                    );
                    if (result == true) _loadCompanies();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade800,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 17, color: Colors.red.shade700),
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(company),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text, {bool isLink = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: isLink ? Colors.blue.shade700 : Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            color: isLink ? Colors.blue.shade800 : Colors.grey.shade700,
            decoration: isLink ? TextDecoration.underline : TextDecoration.none,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildBadgeChip(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w600, color: text),
      ),
    );
  }
}
