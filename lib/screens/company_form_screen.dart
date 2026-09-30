import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/company_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_product_selector.dart';
import '../widgets/section_header_badge.dart';
import '../widgets/star_rating_widget.dart';
import '../widgets/website_preview_panel.dart';

class CompanyFormScreen extends StatefulWidget {
  final Company? companyToEdit;

  const CompanyFormScreen({super.key, this.companyToEdit});

  @override
  State<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<CompanyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Text Controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _landlineController;
  late TextEditingController _websiteController;
  late TextEditingController _mobileController;
  late TextEditingController _addressController;
  late TextEditingController _summaryController;

  // State variables
  String? _selectedCountry;
  String? _selectedCity;
  List<String> _selectedBrands = [];
  List<String> _selectedProducts = [];
  double _rating = 0.0;
  bool _isSubmitting = false;

  // Visiting Card
  String? _visitingCardName;
  String? _visitingCardPath;
  Uint8List? _visitingCardBytes;
  String? _visitingCardUrl;

  // Other Documents
  final List<DocumentItem> _documents = [];

  // Live preview URL
  String _previewUrl = '';
  bool _showMobilePreview = false;

  // Country & City data
  final Map<String, List<String>> _countryCities = {
    'United Arab Emirates': ['Abu Dhabi', 'Dubai', 'Sharjah', 'Ajman', 'Ras Al Khaimah', 'Al Ain'],
    'United States': ['New York', 'San Francisco', 'Los Angeles', 'Chicago', 'Austin', 'Seattle'],
    'United Kingdom': ['London', 'Manchester', 'Birmingham', 'Edinburgh', 'Glasgow'],
    'Saudi Arabia': ['Riyadh', 'Jeddah', 'Dammam', 'Mecca', 'Medina'],
    'India': ['Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai', 'Kolkata'],
    'Canada': ['Toronto', 'Vancouver', 'Montreal', 'Calgary', 'Ottawa'],
    'Germany': ['Berlin', 'Munich', 'Frankfurt', 'Hamburg', 'Cologne'],
    'Australia': ['Sydney', 'Melbourne', 'Brisbane', 'Perth'],
    'Singapore': ['Singapore City'],
    'Qatar': ['Doha', 'Al Rayyan', 'Al Wakrah'],
  };

  @override
  void initState() {
    super.initState();
    final c = widget.companyToEdit;

    _nameController = TextEditingController(text: c?.companyName ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _landlineController = TextEditingController(text: c?.landline ?? '');
    _websiteController = TextEditingController(text: c?.website ?? '');
    _mobileController = TextEditingController(text: c?.mobile ?? '');
    _addressController = TextEditingController(text: c?.fullAddress ?? '');
    _summaryController = TextEditingController(text: c?.summary ?? '');

    if (c != null) {
      _selectedCountry = c.country.isNotEmpty ? c.country : null;
      _selectedCity = c.city.isNotEmpty ? c.city : null;
      _selectedBrands = List.from(c.brands);
      _selectedProducts = List.from(c.products);
      _rating = c.rating;
      _visitingCardName = c.visitingCardName;
      _visitingCardPath = c.visitingCardPath;
      _visitingCardUrl = c.visitingCardUrl;
      _visitingCardBytes = c.visitingCardBytes;
      _documents.addAll(c.documents);
      _previewUrl = c.website;
    } else {
      _selectedCountry = 'United Arab Emirates';
      _selectedCity = 'Abu Dhabi';
      _selectedBrands = ['Lulu'];
      _selectedProducts = ['Upp'];
    }

    _websiteController.addListener(() {
      setState(() {
        _previewUrl = _websiteController.text.trim();
      });
    });

    _apiService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _apiService.removeListener(_onServiceUpdate);
    _nameController.dispose();
    _emailController.dispose();
    _landlineController.dispose();
    _websiteController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  // File Picker for Visiting Card
  Future<void> _pickVisitingCard() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
      );

      if (result.isNotEmpty) {
        final file = result.first;
        Uint8List? fileBytes;
        try {
          fileBytes = await file.readAsBytes();
        } catch (_) {}

        setState(() {
          _visitingCardName = file.name;
          _visitingCardPath = file.path;
          _visitingCardBytes = fileBytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking visiting card: $e');
    }
  }

  // File Picker for Multiple Documents
  Future<void> _pickMultipleDocuments() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'xls', 'xlsx'],
      );

      if (result.isNotEmpty) {
        for (var file in result) {
          Uint8List? fileBytes;
          int? fileSize;
          try {
            fileBytes = await file.readAsBytes();
            fileSize = await file.length();
          } catch (_) {}

          final ext = file.name.contains('.') ? file.name.split('.').last : null;
          setState(() {
            _documents.add(DocumentItem(
              id: UniqueIdGenerator.generate(),
              name: file.name,
              path: file.path,
              bytes: fileBytes,
              size: fileSize,
              extension: ext,
            ));
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking documents: $e');
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields correctly.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final companyData = Company(
        id: widget.companyToEdit?.id,
        companyName: _nameController.text.trim(),
        visitingCardName: _visitingCardName,
        visitingCardPath: _visitingCardPath,
        visitingCardBytes: _visitingCardBytes,
        visitingCardUrl: _visitingCardUrl,
        email: _emailController.text.trim(),
        landline: _landlineController.text.trim(),
        website: _websiteController.text.trim(),
        mobile: _mobileController.text.trim(),
        country: _selectedCountry ?? '',
        city: _selectedCity ?? '',
        fullAddress: _addressController.text.trim(),
        brands: _selectedBrands,
        products: _selectedProducts,
        documents: _documents,
        summary: _summaryController.text.trim(),
        rating: _rating,
      );

      if (widget.companyToEdit == null) {
        await _apiService.createCompany(companyData);
      } else {
        await _apiService.updateCompany(companyData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.companyToEdit == null
                  ? 'Company "${companyData.companyName}" registered successfully!'
                  : 'Company updated successfully!',
            ),
            backgroundColor: AppTheme.primaryNavy,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMobilePreviewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionHeaderBadge(title: 'Website Preview'),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: WebsitePreviewPanel(
                url: _previewUrl,
                companyName: _nameController.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;
    final isMobile = screenWidth < 650;

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
          widget.companyToEdit == null ? 'Add New Company' : 'Edit Company',
          style: GoogleFonts.lora(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryNavy,
          ),
        ),
        actions: [
          if (isMobile && _previewUrl.isNotEmpty)
            TextButton.icon(
              onPressed: _showMobilePreviewSheet,
              icon: const Icon(Icons.visibility_outlined, size: 16, color: AppTheme.primaryNavy),
              label: Text('Preview', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: The Form Card
                  SizedBox(
                    width: 560,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildFormContainer(isMobile: false),
                    ),
                  ),

                  // Right Column: Website Preview Panel
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 20, 20, 20),
                      child: WebsitePreviewPanel(
                        url: _previewUrl,
                        companyName: _nameController.text,
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Mobile View
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      children: [
                        _buildFormContainer(isMobile: true),
                        if (_showMobilePreview && _previewUrl.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 480,
                            child: WebsitePreviewPanel(
                              url: _previewUrl,
                              companyName: _nameController.text,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildFormContainer({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg, // Exact soft cyan/blue background from the images
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryNavy.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Add New Company
            Text(
              widget.companyToEdit == null ? 'Add New Company' : 'Edit Company Details',
              style: GoogleFonts.lora(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(height: 16),

            // ----------------------------------------------------
            // SECTION 1: Basic Information
            // ----------------------------------------------------
            const SectionHeaderBadge(title: 'Basic Information'),
            const SizedBox(height: 12),

            _buildResponsiveRow(
              isMobile: isMobile,
              children: [
                // Company Name Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Company Name:'),
                    TextFormField(
                      controller: _nameController,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter company name' : null,
                      decoration: const InputDecoration(
                        hintText: 'Enter company name',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),

                // Visiting Card File Picker
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Visiting Card:'),
                    _buildVisitingCardPicker(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ----------------------------------------------------
            // SECTION 2: Contact Details
            // ----------------------------------------------------
            const SectionHeaderBadge(title: 'Contact Details'),
            const SizedBox(height: 12),

            _buildResponsiveRow(
              isMobile: isMobile,
              children: [
                // Email
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Email:'),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter email';
                        if (!v.contains('@')) return 'Enter valid email';
                        return null;
                      },
                      decoration: const InputDecoration(hintText: 'e.g. info@company.com'),
                    ),
                  ],
                ),

                // Landline
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Landline:'),
                    TextFormField(
                      controller: _landlineController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: 'e.g. +971 2 1234567'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            _buildResponsiveRow(
              isMobile: isMobile,
              children: [
                // Website
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Website:'),
                    TextFormField(
                      controller: _websiteController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(hintText: 'e.g. https://company.com'),
                    ),
                  ],
                ),

                // Mobile
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Mobile:'),
                    TextFormField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter mobile' : null,
                      decoration: const InputDecoration(hintText: 'e.g. +971 50 1234567'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ----------------------------------------------------
            // SECTION 3: Address
            // ----------------------------------------------------
            const SectionHeaderBadge(title: 'Address'),
            const SizedBox(height: 12),

            _buildResponsiveRow(
              isMobile: isMobile,
              children: [
                // Country Dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Country:'),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.inputBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.inputBorder),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCountry,
                          isExpanded: true,
                          hint: Text('Select Country', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500)),
                          icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppTheme.primaryNavy),
                          items: _countryCities.keys.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(c, style: GoogleFonts.outfit(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCountry = val;
                              final availableCities = _countryCities[val] ?? [];
                              _selectedCity = availableCities.isNotEmpty ? availableCities.first : null;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // City Dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('City:'),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.inputBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.inputBorder),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCity,
                          isExpanded: true,
                          hint: Text('Select City', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500)),
                          icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppTheme.primaryNavy),
                          items: (_countryCities[_selectedCountry] ?? ['Abu Dhabi', 'Dubai', 'Other']).map((city) {
                            return DropdownMenuItem(
                              value: city,
                              child: Text(city, style: GoogleFonts.outfit(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCity = val),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Full Address Textarea
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel('Full Address:'),
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter complete office or building address...',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ----------------------------------------------------
            // SECTION 4: Brands & Products
            // ----------------------------------------------------
            const SectionHeaderBadge(title: 'Brands & Products'),
            const SizedBox(height: 12),

            _buildResponsiveRow(
              isMobile: isMobile,
              children: [
                // Brands selector box
                BrandProductSelector(
                  title: 'Brands',
                  searchHint: 'Search brand...',
                  addHint: 'Add new brand',
                  allItems: _apiService.brands,
                  selectedItems: _selectedBrands,
                  onSelectionChanged: (items) => setState(() => _selectedBrands = items),
                  onAddNewItem: (item) => _apiService.addBrand(item),
                ),

                // Products selector box
                BrandProductSelector(
                  title: 'Products',
                  searchHint: 'Search product...',
                  addHint: 'Add new product',
                  allItems: _apiService.products,
                  selectedItems: _selectedProducts,
                  onSelectionChanged: (items) => setState(() => _selectedProducts = items),
                  onAddNewItem: (item) => _apiService.addProduct(item),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Preview Website Button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _previewUrl = _websiteController.text.trim();
                    _showMobilePreview = !_showMobilePreview;
                  });
                  if (isMobile && _previewUrl.isNotEmpty) {
                    _showMobilePreviewSheet();
                  }
                },
                icon: const Icon(Icons.open_in_browser, size: 14),
                label: Text('Preview Website', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.buttonNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ----------------------------------------------------
            // SECTION 5: Uploads
            // ----------------------------------------------------
            const SectionHeaderBadge(title: 'Uploads'),
            const SizedBox(height: 12),

            // Other Documents Picker
            _buildFieldLabel('Other Documents:'),
            _buildMultiDocPicker(),
            const SizedBox(height: 4),
            Text(
              'You can select multiple files (PDF, JPG, PNG, DOC, DOCX, etc.)',
              style: GoogleFonts.lora(
                fontSize: 11,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 14),

            // Summary Field
            _buildFieldLabel('Summary:'),
            TextFormField(
              controller: _summaryController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter company summary or profile description...',
              ),
            ),
            const SizedBox(height: 14),

            // Rating
            _buildFieldLabel('Rating:'),
            StarRatingWidget(
              rating: _rating,
              size: 26,
              onRatingChanged: (val) => setState(() => _rating = val),
            ),
            const SizedBox(height: 24),

            // Add / Update Company Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.buttonNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: Colors.white, width: 1.2),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        widget.companyToEdit == null ? 'Add Company' : 'Update Company',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveRow({required bool isMobile, required List<Widget> children}) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children.map((w) => Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: w,
        )).toList(),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((child) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: child,
        ),
      )).toList(),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Text(
        label,
        style: GoogleFonts.lora(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryNavy,
        ),
      ),
    );
  }

  Widget _buildVisitingCardPicker() {
    final hasFile = _visitingCardName != null || _visitingCardUrl != null;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.inputBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.inputBorder),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _pickVisitingCard,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                border: Border(right: BorderSide(color: Colors.grey.shade400)),
              ),
              child: Text(
                'Choose File',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasFile ? (_visitingCardName ?? 'Card attached') : 'No file chosen',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: hasFile ? AppTheme.textDark : Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasFile)
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.grey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  _visitingCardName = null;
                  _visitingCardPath = null;
                  _visitingCardBytes = null;
                  _visitingCardUrl = null;
                });
              },
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildMultiDocPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.inputBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.inputBorder),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: _pickMultipleDocuments,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                    border: Border(right: BorderSide(color: Colors.grey.shade400)),
                  ),
                  child: Text(
                    'Choose Files',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _documents.isEmpty
                      ? 'No file chosen'
                      : '${_documents.length} file${_documents.length > 1 ? 's' : ''} chosen',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: _documents.isEmpty ? Colors.grey.shade600 : AppTheme.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Document chips list
        if (_documents.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _documents.map((doc) {
              return Chip(
                avatar: const Icon(Icons.description, size: 14, color: AppTheme.buttonNavy),
                label: Text(
                  doc.name,
                  style: GoogleFonts.outfit(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  setState(() {
                    _documents.removeWhere((d) => d.id == doc.id);
                  });
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
