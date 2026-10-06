// ignore_for_file: deprecated_member_use
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/brand_model.dart';
import '../models/category_model.dart';
import '../models/company_model.dart';
import '../models/product_model.dart';
import '../services/api_config.dart';
import '../services/brand_service.dart';
import '../services/category_service.dart';
import '../services/company_service.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/feedback_toast.dart';
import '../widgets/file_upload_box.dart';
import '../widgets/status_badge_chip.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/company_share_dialog.dart';
import '../widgets/company_search_bar.dart';


class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key});

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  final CompanyService _companyService = CompanyService();
  final BrandService _brandService = BrandService();
  final ProductService _productService = ProductService();
  final CategoryService _categoryService = CategoryService();

  // Navigation & Loading State
  String _activeTab = 'register'; // 'register' or 'directory'
  bool _isLoadingList = false;
  bool _isLoadingBrands = false;
  bool _isLoadingProducts = false;
  bool _isLoadingCategories = false;
  bool _isSubmitting = false;
  bool _isExportingExcel = false;
  bool _isExportingPdf = false;
  FeedbackData? _feedback;

  // Edit Mode
  int? _editingCompanyId;

  // Form Field Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _landlineController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController(text: 'United States');
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactDesignationController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactMobileController = TextEditingController();
  String _status = 'ACTIVE';

  // Section 05: Brands Dealt With State
  List<BrandResponse> _availableBrands = [];
  List<int> _selectedBrandIds = [];
  final Set<int> _manuallySelectedBrandIds = {};
  String _brandSearchQuery = '';

  // Section 06: Products Catalog State
  List<ProductResponse> _availableProducts = [];
  List<CategoryResponse> _availableCategories = [];
  List<int> _selectedProductIds = [];
  String _productSearchQuery = '';
  String _activeProductBrandFilter = 'all';
  String _activeProductCategoryFilter = 'all';
  String _activeProductSubCategoryFilter = 'all';

  // Section 07: File Upload State
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  int? _selectedFileSize;
  String? _selectedFilePath;
  String? _existingFileUrl;

  // Directory State
  List<CompanyResponse> _companies = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Modal State
  CompanyResponse? _selectedCompany;

  // Live preview toggle for mobile
  bool _showLivePreview = false;

  final ApiConfig _apiConfig = ApiConfig();

  @override
  void initState() {
    super.initState();
    _apiConfig.addListener(_onConfigChanged);
    _fetchAllData();
  }

  void _onConfigChanged() {
    if (mounted) {
      _fetchAllData();
    }
  }

  void _fetchAllData() {
    _fetchCompanies();
    _fetchBrands();
    _fetchProducts();
    _fetchCategories();
  }

  @override
  void dispose() {
    _apiConfig.removeListener(_onConfigChanged);
    _nameController.dispose();
    _emailController.dispose();
    _landlineController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _contactNameController.dispose();
    _contactDesignationController.dispose();
    _contactEmailController.dispose();
    _contactMobileController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Hierarchy Computations ---
  List<CategoryResponse> get _parentCategories {
    return _availableCategories.where((c) => c.parentId == null).toList();
  }

  List<CategoryResponse> get _subCategories {
    final parents = _parentCategories;
    return _availableCategories.where((c) => c.parentId != null).map((sub) {
      final parent = parents.cast<CategoryResponse?>().firstWhere(
            (p) => p?.id == sub.parentId,
            orElse: () => null,
          );
      return sub.copyWith(parentName: parent?.name ?? 'None');
    }).toList();
  }

  List<BrandResponse> get _filteredAvailableBrands {
    final query = _brandSearchQuery.toLowerCase().trim();
    if (query.isEmpty) return _availableBrands;
    return _availableBrands.where((b) => b.brandName.toLowerCase().contains(query)).toList();
  }

  List<BrandResponse> get _selectedBrandsList {
    final ids = _selectedBrandIds.toSet();
    return _availableBrands.where((b) => ids.contains(b.id)).toList();
  }

  // Brands with Product Counts
  List<Map<String, dynamic>> get _brandsWithProducts {
    return _availableBrands.map((b) {
      final count = _availableProducts.where((p) => p.brandId == b.id).length;
      return {
        'brand': b,
        'count': count,
      };
    }).toList();
  }

  // Categories available for current brand filter
  List<CategoryResponse> get _availableCategoriesForBrand {
    var prods = _availableProducts;
    if (_activeProductBrandFilter != 'all') {
      final bId = int.tryParse(_activeProductBrandFilter);
      if (bId != null) prods = prods.where((p) => p.brandId == bId).toList();
    }
    final catIds = prods.map((p) => p.categoryId).toSet();
    return _parentCategories.where((c) => catIds.contains(c.id)).toList();
  }

  // Subcategories available under selected brand & category
  List<CategoryResponse> get _availableSubCategoriesForSelection {
    var prods = _availableProducts;
    if (_activeProductBrandFilter != 'all') {
      final bId = int.tryParse(_activeProductBrandFilter);
      if (bId != null) prods = prods.where((p) => p.brandId == bId).toList();
    }
    if (_activeProductCategoryFilter != 'all') {
      final cId = int.tryParse(_activeProductCategoryFilter);
      if (cId != null) prods = prods.where((p) => p.categoryId == cId).toList();
    }
    final subCatIds = prods
        .where((p) => p.subCategoryId != null)
        .map((p) => p.subCategoryId!)
        .toSet();
    return _subCategories.where((s) => subCatIds.contains(s.id)).toList();
  }

  // Filtered Products for Selection Grid
  List<ProductResponse> get _filteredAvailableProducts {
    final query = _productSearchQuery.toLowerCase().trim();
    final bFilter = _activeProductBrandFilter;
    final cFilter = _activeProductCategoryFilter;
    final sFilter = _activeProductSubCategoryFilter;

    return _availableProducts.where((p) {
      if (bFilter != 'all' && p.brandId.toString() != bFilter) return false;
      if (cFilter != 'all' && p.categoryId.toString() != cFilter) return false;
      if (sFilter != 'all' && p.subCategoryId?.toString() != sFilter) return false;

      if (query.isNotEmpty) {
        final matches = p.name.toLowerCase().contains(query) ||
            (p.brandName ?? '').toLowerCase().contains(query) ||
            (p.categoryName ?? '').toLowerCase().contains(query) ||
            (p.subCategoryName ?? '').toLowerCase().contains(query) ||
            p.id.toString().contains(query);
        if (!matches) return false;
      }
      return true;
    }).toList();
  }

  List<ProductResponse> get _selectedProductsList {
    final ids = _selectedProductIds.toSet();
    return _availableProducts.where((p) => ids.contains(p.id)).toList();
  }

  List<CompanyResponse> get _filteredCompanies {
    final query = _searchQuery.toLowerCase().trim();
    if (query.isEmpty) return _companies;
    return _companies.where((c) {
      final matchesName = c.companyName.toLowerCase().contains(query);
      final matchesContact = (c.contactName ?? '').toLowerCase().contains(query);
      final matchesContactEmail = (c.contactEmail ?? '').toLowerCase().contains(query);
      final matchesEmail = c.email.toLowerCase().contains(query);
      final matchesCity = (c.city ?? '').toLowerCase().contains(query);
      final matchesCountry = (c.country ?? '').toLowerCase().contains(query);
      final matchesBrands = c.brands.any((b) => b.brandName.toLowerCase().contains(query));
      final matchesProducts = c.products.any((p) => p.name.toLowerCase().contains(query));
      return matchesName || matchesContact || matchesContactEmail || matchesEmail ||
          matchesCity || matchesCountry || matchesBrands || matchesProducts;
    }).toList();
  }

  // --- Fetching Data ---
  Future<void> _fetchCompanies() async {
    setState(() => _isLoadingList = true);
    try {
      final data = await _companyService.getAllCompanies();
      if (mounted) setState(() { _companies = data; _isLoadingList = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  Future<void> _fetchBrands() async {
    setState(() => _isLoadingBrands = true);
    try {
      final data = await _brandService.getAllBrands();
      if (mounted) setState(() { _availableBrands = data; _isLoadingBrands = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingBrands = false);
    }
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final data = await _productService.getAllProducts();
      if (mounted) setState(() { _availableProducts = data; _isLoadingProducts = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final data = await _categoryService.getAllCategories();
      if (mounted) setState(() { _availableCategories = data; _isLoadingCategories = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  // --- Brand Selection Handlers ---
  void _toggleBrand(int brandId) {
    setState(() {
      if (_selectedBrandIds.contains(brandId)) {
        // 1. Unselect brand
        _selectedBrandIds.remove(brandId);
        _manuallySelectedBrandIds.remove(brandId);
        // 2. Cascade: automatically unselect all products belonging to this brand
        final prodsOfBrand = _availableProducts
            .where((p) => p.brandId == brandId)
            .map((p) => p.id)
            .toSet();
        _selectedProductIds.removeWhere((id) => prodsOfBrand.contains(id));
      } else {
        // User explicitly selected this brand
        _selectedBrandIds.add(brandId);
        _manuallySelectedBrandIds.add(brandId);
      }
    });
  }

  void _selectAllBrands() {
    setState(() {
      final allIds = _availableBrands.map((b) => b.id).toList();
      _selectedBrandIds = allIds;
      _manuallySelectedBrandIds.addAll(allIds);
    });
  }

  void _clearSelectedBrands() {
    setState(() {
      _selectedBrandIds.clear();
      _manuallySelectedBrandIds.clear();
      _selectedProductIds.clear();
    });
  }

  // --- Product Selection Handlers ---
  void _toggleProduct(ProductResponse product) {
    setState(() {
      if (_selectedProductIds.contains(product.id)) {
        _removeProductAndCheckBrand(product.id, product.brandId);
      } else {
        _selectedProductIds.add(product.id);
        if (!_selectedBrandIds.contains(product.brandId)) {
          _selectedBrandIds.add(product.brandId);
        }
      }
    });
  }

  void _removeProductAndCheckBrand(int productId, int? brandId) {
    _selectedProductIds.remove(productId);
    final bId = brandId ?? _availableProducts.cast<ProductResponse?>().firstWhere((p) => p?.id == productId, orElse: () => null)?.brandId;
    if (bId != null) {
      final hasOtherProds = _availableProducts.any(
        (p) => p.brandId == bId && _selectedProductIds.contains(p.id),
      );
      if (!hasOtherProds && !_manuallySelectedBrandIds.contains(bId)) {
        _selectedBrandIds.remove(bId);
      }
    }
  }

  void _selectAllFilteredProducts() {
    setState(() {
      for (final p in _filteredAvailableProducts) {
        if (!_selectedProductIds.contains(p.id)) _selectedProductIds.add(p.id);
        if (!_selectedBrandIds.contains(p.brandId)) _selectedBrandIds.add(p.brandId);
      }
    });
  }

  void _deselectFilteredProducts() {
    setState(() {
      final filteredIds = _filteredAvailableProducts.map((p) => p.id).toSet();
      _selectedProductIds.removeWhere((id) => filteredIds.contains(id));

      final remainingProds = _availableProducts.where((p) => _selectedProductIds.contains(p.id));
      final activeBrandIds = remainingProds.map((p) => p.brandId).toSet();

      _selectedBrandIds.removeWhere((bId) =>
          !_manuallySelectedBrandIds.contains(bId) && !activeBrandIds.contains(bId));
    });
  }

  void _clearSelectedProducts() {
    setState(() {
      _selectedProductIds.clear();
      _selectedBrandIds.removeWhere((bId) => !_manuallySelectedBrandIds.contains(bId));
    });
  }


  // --- Edit & Form Reset Handlers ---
  void _startEdit(CompanyResponse company) {
    setState(() {
      _editingCompanyId = company.id;
      _activeTab = 'register';
      _feedback = null;

      _nameController.text = company.companyName;
      _emailController.text = company.email;
      _landlineController.text = company.landline ?? '';
      _addressController.text = company.address ?? '';
      _cityController.text = company.city ?? '';
      _countryController.text = company.country ?? 'United States';
      _websiteController.text = company.website ?? '';
      _descriptionController.text = company.description ?? '';
      _status = company.status;
      _contactNameController.text = company.contactName ?? '';
      _contactDesignationController.text = company.contactDesignation ?? '';
      _contactEmailController.text = company.contactEmail ?? '';
      _contactMobileController.text = company.contactMobileNumber ?? '';

      final bIds = company.brandIds.isNotEmpty
          ? List<int>.from(company.brandIds)
          : company.brands.map((b) => b.id).toList();
      _selectedBrandIds = bIds;
      _manuallySelectedBrandIds.clear();
      _manuallySelectedBrandIds.addAll(bIds);

      final pIds = company.productIds.isNotEmpty
          ? List<int>.from(company.productIds)
          : company.products.map((p) => p.id).toList();
      _selectedProductIds = pIds;

      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedFileSize = null;
      _selectedFilePath = null;
      _existingFileUrl = company.businessCard != null && company.businessCard!.isNotEmpty
          ? _companyService.getFileUrl(company.businessCard)
          : null;

      if (_selectedCompany != null) _selectedCompany = null;
    });
  }

  void _resetFormFields() {
    _editingCompanyId = null;
    _nameController.clear();
    _emailController.clear();
    _landlineController.clear();
    _addressController.clear();
    _cityController.clear();
    _countryController.text = 'United States';
    _websiteController.clear();
    _descriptionController.clear();
    _status = 'ACTIVE';
    _contactNameController.clear();
    _contactDesignationController.clear();
    _contactEmailController.clear();
    _contactMobileController.clear();

    _selectedBrandIds.clear();
    _manuallySelectedBrandIds.clear();
    _selectedProductIds.clear();
    _brandSearchQuery = '';
    _productSearchQuery = '';
    _activeProductBrandFilter = 'all';
    _activeProductCategoryFilter = 'all';
    _activeProductSubCategoryFilter = 'all';

    _selectedFileBytes = null;
    _selectedFileName = null;
    _selectedFileSize = null;
    _selectedFilePath = null;
    _existingFileUrl = null;
  }

  void _resetForm() {
    setState(() {
      _resetFormFields();
    });
  }

  void _switchToRegister() {
    setState(() {
      _resetFormFields();
      _activeTab = 'register';
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _feedback = FeedbackData(
          type: 'error',
          title: 'Validation Error',
          message: 'Please fill in all mandatory fields correctly before proceeding.',
        );
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedback = null;
    });

    final allBrandIds = {
      ..._selectedBrandIds,
      ..._selectedProductsList.map((p) => p.brandId),
    }.toList();

    final request = CompanyRequest(
      companyName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      landline: _landlineController.text.trim().isNotEmpty ? _landlineController.text.trim() : null,
      address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
      city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
      country: _countryController.text.trim().isNotEmpty ? _countryController.text.trim() : null,
      website: _websiteController.text.trim().isNotEmpty ? _websiteController.text.trim() : null,
      description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      status: _status,
      contactName: _contactNameController.text.trim().isNotEmpty ? _contactNameController.text.trim() : null,
      contactDesignation: _contactDesignationController.text.trim().isNotEmpty ? _contactDesignationController.text.trim() : null,
      contactEmail: _contactEmailController.text.trim().isNotEmpty ? _contactEmailController.text.trim() : null,
      contactMobileNumber: _contactMobileController.text.trim().isNotEmpty ? _contactMobileController.text.trim() : null,
      brandIds: allBrandIds,
      productIds: _selectedProductIds,
    );

    try {
      if (_editingCompanyId != null) {
        final response = await _companyService.updateCompany(
          _editingCompanyId!,
          request,
          fileBytes: _selectedFileBytes,
          fileName: _selectedFileName,
          filePath: _selectedFilePath,
        );
        setState(() {
          _isSubmitting = false;
          _feedback = FeedbackData(
            type: 'success',
            title: 'Company Updated Successfully!',
            message: 'Changes for "${response.companyName}" (ID #${response.id}) have been saved.',
          );
          _resetFormFields();
          _activeTab = 'directory';
        });
        _fetchCompanies();
      } else {
        final response = await _companyService.createCompany(
          request,
          fileBytes: _selectedFileBytes,
          fileName: _selectedFileName,
          filePath: _selectedFilePath,
        );
        setState(() {
          _isSubmitting = false;
          _feedback = FeedbackData(
            type: 'success',
            title: 'Company Registered Successfully!',
            message: '"${response.companyName}" has been established with ID #${response.id}.',
          );
          _resetFormFields();
          _activeTab = 'directory';
        });
        _fetchCompanies();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _feedback = FeedbackData(
          type: 'error',
          title: _editingCompanyId != null ? 'Update Failed' : 'Registration Failed',
          message: e.toString().replaceAll('Exception: ', ''),
        );
      });
    }
  }

  Future<void> _exportToExcel() async {
    if (_isExportingExcel) return;
    setState(() => _isExportingExcel = true);
    try {
      final bytes = await _companyService.exportCompaniesToExcel();
      if (mounted) {
        setState(() {
          _isExportingExcel = false;
          _feedback = FeedbackData(
            type: 'success',
            title: 'Excel Export Successful',
            message: 'Generated companies directory spreadsheet (${(bytes.length / 1024).toStringAsFixed(1)} KB).',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExportingExcel = false;
          _feedback = FeedbackData(
            type: 'error',
            title: 'Export Failed',
            message: 'Could not generate the Excel file. Please ensure the backend is reachable.',
          );
        });
      }
    }
  }

  Future<void> _exportToPdf() async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);
    try {
      final bytes = await _companyService.exportCompaniesToPdf();
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
          _feedback = FeedbackData(
            type: 'success',
            title: 'PDF Export Successful',
            message: 'Generated companies directory official PDF document (${(bytes.length / 1024).toStringAsFixed(1)} KB).',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
          _feedback = FeedbackData(
            type: 'error',
            title: 'Export Failed',
            message: 'Could not generate the PDF file. Please ensure the backend is reachable.',
          );
        });
      }
    }
  }


  Future<void> _downloadCompanyPdf(CompanyResponse company) async {
    try {
      setState(() {
        _feedback = FeedbackData(
          type: 'info',
          title: 'Generating PDF',
          message: 'Generating executive PDF profile for ${company.companyName}...',
        );
      });
      final bytes = await _companyService.exportCompanyProfilePdf(company.id);
      final safeName = company.companyName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = '${safeName}_Profile_with_Cards.pdf';
      final xFile = XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf');
      await Share.shareXFiles([xFile], text: '${company.companyName} Profile');
      if (mounted) {
        setState(() {
          _feedback = FeedbackData(
            type: 'success',
            title: 'PDF Export Ready',
            message: 'Exported executive PDF profile for ${company.companyName}.',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedback = FeedbackData(
            type: 'error',
            title: 'Export Failed',
            message: 'Could not generate company PDF profile: $e',
          );
        });
      }
    }
  }

  void _shareCurrentPreview() {
    final previewCompany = CompanyResponse(
      id: _editingCompanyId ?? 0,
      companyName: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'Untitled Company',
      email: _emailController.text.trim(),
      landline: _landlineController.text.trim().isNotEmpty ? _landlineController.text.trim() : null,
      address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
      city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
      country: _countryController.text.trim().isNotEmpty ? _countryController.text.trim() : null,
      website: _websiteController.text.trim().isNotEmpty ? _websiteController.text.trim() : null,
      description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      contactName: _contactNameController.text.trim().isNotEmpty ? _contactNameController.text.trim() : null,
      contactDesignation: _contactDesignationController.text.trim().isNotEmpty ? _contactDesignationController.text.trim() : null,
      contactEmail: _contactEmailController.text.trim().isNotEmpty ? _contactEmailController.text.trim() : null,
      contactMobileNumber: _contactMobileController.text.trim().isNotEmpty ? _contactMobileController.text.trim() : null,
      status: _status,
      businessCard: _selectedFileName,
      brands: _availableBrands.where((b) => _selectedBrandIds.contains(b.id)).toList(),
      products: _availableProducts.where((p) => _selectedProductIds.contains(p.id)).toList(),
    );
    CompanyShareDialog.show(context, previewCompany);
  }

  void _promptDelete(CompanyResponse company) {
    showDialog(
      context: context,
      builder: (_) => DeleteConfirmDialog(
        title: 'Delete Company Record?',
        itemName: company.companyName,
        itemId: company.id,
        onConfirm: () async {
          await _companyService.deleteCompany(company.id);
          if (mounted) {
            setState(() {
              _feedback = FeedbackData(
                type: 'success',
                title: 'Company Deleted',
                message: '"${company.companyName}" has been successfully deleted.',
              );
              if (_selectedCompany?.id == company.id) {
                _selectedCompany = null;
              }
              if (_editingCompanyId == company.id) {
                _resetFormFields();
              }
            });
            _fetchCompanies();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopNavTabs(),
              if (_feedback != null)
                FeedbackToast(
                  feedback: _feedback!,
                  onClose: () => setState(() => _feedback = null),
                ),
              Expanded(
                child: _activeTab == 'register'
                    ? (isDesktop ? _buildDesktopRegisterView() : _buildMobileRegisterView())
                    : _buildDirectoryView(),
              ),
            ],
          ),

          // View Detail Modal Dialog
          if (_selectedCompany != null)
            _buildCompanyDetailModal(_selectedCompany!),
        ],
      ),
    );
  }

  // --- Top Navigation Tabs Bar ---
  Widget _buildTopNavTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.bgSurface,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderLight, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Register Company Button
            InkWell(
              onTap: _switchToRegister,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _activeTab == 'register' && _editingCompanyId == null
                      ? AppTheme.primaryLight
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _activeTab == 'register' && _editingCompanyId == null
                        ? AppTheme.primary.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle,
                      size: 15,
                      color: _activeTab == 'register' && _editingCompanyId == null
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Register Company',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _activeTab == 'register' && _editingCompanyId == null
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Edit Company Pill
            if (_editingCompanyId != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warningBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _activeTab = 'register'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit, size: 13, color: AppTheme.warning),
                          const SizedBox(width: 4),
                          Text(
                            'Edit #$_editingCompanyId',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    InkWell(
                      onTap: _switchToRegister,
                      borderRadius: BorderRadius.circular(10),
                      child: const Icon(Icons.close, size: 13, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Directory Tab Button
            InkWell(
              onTap: () => setState(() => _activeTab = 'directory'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _activeTab == 'directory' ? AppTheme.primaryLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _activeTab == 'directory'
                        ? AppTheme.primary.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 15,
                      color: _activeTab == 'directory' ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Directory',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _activeTab == 'directory' ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: _activeTab == 'directory'
                            ? AppTheme.primary
                            : AppTheme.bgSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_companies.length}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _activeTab == 'directory'
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
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
  }

  // --- TAB 1: REGISTRATION / EDIT VIEW (DESKTOP) ---
  Widget _buildDesktopRegisterView() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildFormContent(),
          ),
        ),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
            child: _buildLivePreviewSidebar(),
          ),
        ),
      ],
    );
  }

  // --- TAB 1: REGISTRATION / EDIT VIEW (MOBILE) ---
  Widget _buildMobileRegisterView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Preview Toggle for mobile
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () => setState(() => _showLivePreview = !_showLivePreview),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _showLivePreview ? AppTheme.primaryLight : AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _showLivePreview ? AppTheme.primary : AppTheme.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _showLivePreview ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _showLivePreview ? 'Hide Live Card Preview' : 'Show Live Card Preview',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showLivePreview ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_showLivePreview) ...[
            _buildLivePreviewSidebar(),
            const SizedBox(height: 20),
          ],

          _buildFormContent(),
        ],
      ),
    );
  }

  // --- Form Content ---
  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderBanner(),
        const SizedBox(height: 16),

        if (_editingCompanyId != null) ...[
          _buildEditingNoticeBanner(),
          const SizedBox(height: 16),
        ],

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 01: Corporate Identity & Status
              _buildFormCard(
                stepNum: '01',
                title: 'Corporate Information',
                subtitle: 'Official registered enterprise identity & operational status',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Company Name *',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Apex Global Technologies Inc.',
                        prefixIcon: const Icon(Icons.apartment, size: 18, color: AppTheme.textMuted),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (val) {
                        if (val == null || val.trim().length < 2) {
                          return 'Valid company name is required (min 2 characters)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Company Operational Status',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatusRadioCard('ACTIVE', AppTheme.success),
                        const SizedBox(width: 6),
                        _buildStatusRadioCard('PENDING', AppTheme.warning),
                        const SizedBox(width: 6),
                        _buildStatusRadioCard('INACTIVE', AppTheme.textMuted),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 02: Primary Contact Person
              _buildFormCard(
                stepNum: '02',
                title: 'Contact Person & Representative',
                subtitle: 'Key executive or point-of-contact details for this enterprise',
                child: LayoutBuilder(builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 500;
                  return Column(
                    children: [
                      Flex(
                        direction: isNarrow ? Axis.vertical : Axis.horizontal,
                        children: [
                          Expanded(
                            flex: isNarrow ? 0 : 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Contact Person Name', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _contactNameController,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Sarah Jenkins',
                                    prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: AppTheme.textMuted),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isNarrow ? 0 : 12, height: isNarrow ? 12 : 0),
                          Expanded(
                            flex: isNarrow ? 0 : 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Designation / Role', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _contactDesignationController,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Managing Director / CTO',
                                    prefixIcon: const Icon(Icons.work_outline, size: 18, color: AppTheme.textMuted),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Flex(
                        direction: isNarrow ? Axis.vertical : Axis.horizontal,
                        children: [
                          Expanded(
                            flex: isNarrow ? 0 : 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Contact Person Email', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _contactEmailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'sarah.jenkins@company.com',
                                    prefixIcon: const Icon(Icons.email_outlined, size: 18, color: AppTheme.textMuted),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isNarrow ? 0 : 12, height: isNarrow ? 12 : 0),
                          Expanded(
                            flex: isNarrow ? 0 : 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Mobile Number', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _contactMobileController,
                                  keyboardType: TextInputType.phone,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: '+1 (555) 987-6543',
                                    prefixIcon: const Icon(Icons.phone_iphone, size: 18, color: AppTheme.textMuted),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Section 03: Corporate Communication & Web
              _buildFormCard(
                stepNum: '03',
                title: 'Corporate Communication & Web',
                subtitle: 'Official company-wide channels and public web portal',
                child: LayoutBuilder(builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 500;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flex(
                        direction: isNarrow ? Axis.vertical : Axis.horizontal,
                        children: [
                          Expanded(
                            flex: isNarrow ? 0 : 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Corporate Email *', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'contact@enterprise.com',
                                    prefixIcon: const Icon(Icons.alternate_email, size: 18, color: AppTheme.textMuted),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (val) {
                                    if (val == null || !val.contains('@')) {
                                      return 'Valid corporate email is required';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isNarrow ? 0 : 12, height: isNarrow ? 12 : 0),
                          Expanded(
                            flex: isNarrow ? 0 : 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Landline Number', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _landlineController,
                                  keyboardType: TextInputType.phone,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: '+1 (555) 019-2834',
                                    prefixIcon: const Icon(Icons.phone_in_talk, size: 18, color: AppTheme.textMuted),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Official Website', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _websiteController,
                            keyboardType: TextInputType.url,
                            style: GoogleFonts.inter(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'https://company.example.com',
                              prefixIcon: const Icon(Icons.language, size: 18, color: AppTheme.textMuted),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Section 04: Headquarters Address
              _buildFormCard(
                stepNum: '04',
                title: 'Corporate Headquarters',
                subtitle: 'Registered office address and country jurisdiction',
                child: LayoutBuilder(builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 500;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Street Address', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressController,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Suite 500, 100 Innovation Way',
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.textMuted),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Flex(
                        direction: isNarrow ? Axis.vertical : Axis.horizontal,
                        children: [
                          Expanded(
                            flex: isNarrow ? 0 : 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('City', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _cityController,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  decoration: const InputDecoration(hintText: 'San Francisco'),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isNarrow ? 0 : 12, height: isNarrow ? 12 : 0),
                          Expanded(
                            flex: isNarrow ? 0 : 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Country', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _countryController,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  decoration: const InputDecoration(hintText: 'United States'),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Section 05: Brands Dealt With & Partner Dealerships
              _buildFormCard(
                stepNum: '05',
                title: 'Brands Dealt With & Partner Dealerships',
                subtitle: 'Select the manufacturer brands this enterprise deals with, represents, or distributes',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter & Helper Action Bar
                    LayoutBuilder(builder: (context, constraints) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 36,
                            child: TextField(
                              style: GoogleFonts.inter(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Filter brands by name...',
                                prefixIcon: const Icon(Icons.search, size: 15, color: AppTheme.textMuted),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) => setState(() => _brandSearchQuery = val),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${_selectedBrandIds.length}/${_availableBrands.length} selected',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                              ),
                              OutlinedButton(
                                onPressed: _availableBrands.isEmpty ? null : _selectAllBrands,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Select All'),
                              ),
                              OutlinedButton(
                                onPressed: _selectedBrandIds.isEmpty ? null : _clearSelectedBrands,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 12),

                    if (_isLoadingBrands)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    else if (_availableBrands.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSubtle,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'No brands registered in the system yet. Register brands first so companies can select them.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      )
                    else
                      LayoutBuilder(builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth > 650 ? 3 : 2;
                        final brands = _filteredAvailableBrands;

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 64,
                          ),
                          itemCount: brands.length,
                          itemBuilder: (context, index) {
                            final b = brands[index];
                            final isSelected = _selectedBrandIds.contains(b.id);

                            return InkWell(
                              onTap: () => _toggleBrand(b.id),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.primaryLight : AppTheme.bgSurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primary : AppTheme.borderLight,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppTheme.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isSelected ? AppTheme.primary : AppTheme.borderMedium,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    if (b.brandLogo != null && b.brandLogo!.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          _brandService.getFileUrl(b.brandLogo),
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 24,
                                            height: 24,
                                            color: AppTheme.bgSubtle,
                                            alignment: Alignment.center,
                                            child: Text(b.initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: AppTheme.bgSubtle,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(b.initials, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                                      ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            b.brandName,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                              color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (b.isFeatured)
                                            Row(
                                              children: [
                                                const Icon(Icons.star, size: 10, color: Color(0xFFF59E0B)),
                                                const SizedBox(width: 2),
                                                Text('Featured', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFD97706), fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 06: Authorized Products Catalog (From Brands through Categories)
              _buildFormCard(
                stepNum: '06',
                title: 'Authorized Products Catalog',
                subtitle: 'Choose products from brands through categories that this enterprise offers or distributes',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drilldown Filter Grid
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Filter by Brand
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _activeProductBrandFilter,
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textPrimary),
                              items: [
                                DropdownMenuItem(value: 'all', child: Text('All Brands (${_availableProducts.length} total)')),
                                ..._brandsWithProducts.map((item) {
                                  final BrandResponse b = item['brand'] as BrandResponse;
                                  final int count = item['count'] as int;
                                  return DropdownMenuItem(
                                    value: b.id.toString(),
                                    child: Text('${b.brandName} ($count prods)'),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _activeProductBrandFilter = val;
                                    _activeProductCategoryFilter = 'all';
                                    _activeProductSubCategoryFilter = 'all';
                                  });
                                }
                              },
                            ),
                          ),
                        ),

                        // Filter by Category
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _activeProductCategoryFilter,
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textPrimary),
                              items: [
                                DropdownMenuItem(value: 'all', child: Text(_isLoadingCategories ? 'Loading Categories...' : 'All Categories')),
                                ..._availableCategoriesForBrand.map((c) {
                                  return DropdownMenuItem(value: c.id.toString(), child: Text(c.name));
                                }),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _activeProductCategoryFilter = val;
                                    _activeProductSubCategoryFilter = 'all';
                                  });
                                }
                              },
                            ),
                          ),
                        ),

                        // Filter by Subcategory
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _activeProductSubCategoryFilter,
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textPrimary),
                              items: [
                                const DropdownMenuItem(value: 'all', child: Text('All Subcategories')),
                                ..._availableSubCategoriesForSelection.map((s) {
                                  return DropdownMenuItem(value: s.id.toString(), child: Text(s.name));
                                }),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _activeProductSubCategoryFilter = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Product Search Input & Selection Actions Bar
                    LayoutBuilder(builder: (context, constraints) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 36,
                            child: TextField(
                              style: GoogleFonts.inter(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Search product name, code...',
                                prefixIcon: const Icon(Icons.search, size: 15, color: AppTheme.textMuted),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) => setState(() => _productSearchQuery = val),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${_selectedProductIds.length}/${_availableProducts.length} chosen',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                              ),
                              OutlinedButton(
                                onPressed: _filteredAvailableProducts.isEmpty ? null : _selectAllFilteredProducts,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Select (${_filteredAvailableProducts.length})'),
                              ),
                              OutlinedButton(
                                onPressed: _filteredAvailableProducts.isEmpty ? null : _deselectFilteredProducts,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Deselect'),
                              ),
                              OutlinedButton(
                                onPressed: _selectedProductIds.isEmpty ? null : _clearSelectedProducts,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 10),

                    // Selected Products Pills Strip
                    if (_selectedProductIds.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSubtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Selected (${_selectedProductIds.length}):',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                            ),
                            ..._selectedProductsList.map((p) {
                              return Container(
                                padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.borderMedium),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      p.name,
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${p.brandName ?? ''})',
                                      style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _removeProductAndCheckBrand(p.id, p.brandId);
                                        });
                                      },
                                      child: const Icon(Icons.close, size: 14, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Products Selection Grid
                    if (_isLoadingProducts)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    else if (_availableProducts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppTheme.bgSubtle, borderRadius: BorderRadius.circular(12)),
                        child: Text('No products available yet. Register products first.', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                      )
                    else if (_filteredAvailableProducts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppTheme.bgSubtle, borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Icon(Icons.filter_alt_off, size: 28, color: AppTheme.textMuted),
                            const SizedBox(height: 6),
                            Text('No products match current filters.', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      )
                    else
                      LayoutBuilder(builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth > 650 ? 3 : 2;
                        final prods = _filteredAvailableProducts;

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 80,
                          ),
                          itemCount: prods.length,
                          itemBuilder: (context, index) {
                            final p = prods[index];
                            final isSelected = _selectedProductIds.contains(p.id);

                            return InkWell(
                              onTap: () => _toggleProduct(p),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.primaryLight : AppTheme.bgSurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primary : AppTheme.borderLight,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppTheme.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.borderMedium),
                                      ),
                                      child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                    ),
                                    const SizedBox(width: 8),
                                    if (p.image != null && p.image!.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          _productService.getFileUrl(p.image),
                                          width: 36,
                                          height: 36,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 36,
                                            height: 36,
                                            color: AppTheme.bgSubtle,
                                            child: const Icon(Icons.inventory_2, size: 18, color: AppTheme.textMuted),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(color: AppTheme.bgSubtle, borderRadius: BorderRadius.circular(6)),
                                        child: const Icon(Icons.inventory_2, size: 18, color: AppTheme.textMuted),
                                      ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            children: [
                                              if (p.brandName != null)
                                                Flexible(
                                                  child: Text(
                                                    p.brandName!,
                                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          Text(
                                            p.name,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                              color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${p.categoryName ?? ''}${p.subCategoryName != null ? ' > ${p.subCategoryName}' : ''}',
                                            style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 07: Business Card & Brand Asset Upload
              _buildFormCard(
                stepNum: '07',
                title: 'Business Card & Brand Asset',
                subtitle: 'Upload company logo, digital visiting card, or certificate (JPEG, PNG, WEBP, PDF)',
                child: FileUploadBox(
                  title: 'Drop your business card or company logo here',
                  hint: 'or browse files from your computer',
                  allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf'],
                  fileName: _selectedFileName,
                  fileSize: _selectedFileSize,
                  existingFileUrl: _existingFileUrl,
                  fileBytes: _selectedFileBytes,
                  onFileSelected: (bytes, name, size, path) {
                    setState(() {
                      _selectedFileBytes = bytes;
                      _selectedFileName = name;
                      _selectedFileSize = size;
                      _selectedFilePath = path;
                    });
                  },
                  onFileRemoved: () {
                    setState(() {
                      _selectedFileBytes = null;
                      _selectedFileName = null;
                      _selectedFileSize = null;
                      _selectedFilePath = null;
                      _existingFileUrl = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Section 08: Corporate Overview & Profile
              _buildFormCard(
                stepNum: '08',
                title: 'Corporate Overview & Profile',
                subtitle: 'Summary of company activities, mission, and scope',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Company Summary', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      maxLength: 1000,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Briefly describe your company\'s core business, services, products, and mission...',
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form Actions
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : _resetForm,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      side: const BorderSide(color: AppTheme.borderMedium),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_editingCompanyId != null ? Icons.cancel_outlined : Icons.restart_alt, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        Text(_editingCompanyId != null ? 'Cancel Edit' : 'Reset Form', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_editingCompanyId != null ? Icons.check_circle_outline : Icons.add_circle, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                _editingCompanyId != null ? 'Update Company Details' : 'Complete Company Registration',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeaderBanner() {
    final isEdit = _editingCompanyId != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: isEdit
                  ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                  : AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: (isEdit ? const Color(0xFFF59E0B) : AppTheme.primary).withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isEdit ? Icons.edit_note_rounded : Icons.apartment_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isEdit ? 'Update Company Record' : 'Company Registration',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isEdit) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.warningBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'ID #$_editingCompanyId',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isEdit
                      ? 'Modify official details for this registered entity.'
                      : 'Register your enterprise with official records and contacts.',
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isEdit) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: _switchToRegister,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_circle, size: 13, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'New',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditingNoticeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Editing company #$_editingCompanyId.',
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500, color: const Color(0xFF92400E)),
            ),
          ),
          TextButton(
            onPressed: _switchToRegister,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              'Cancel / New',
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRadioCard(String val, Color color) {
    final isSelected = _status == val;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _status = val),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppTheme.borderLight,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    val,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? color : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard({
    required String stepNum,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  stepNum,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  // --- Live Preview Sidebar ---
  Widget _buildLivePreviewSidebar() {
    final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Your Company Name';
    final email = _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : 'contact@company.com';
    final landline = _landlineController.text.trim();
    final city = _cityController.text.trim();
    final country = _countryController.text.trim();
    final website = _websiteController.text.trim();
    final desc = _descriptionController.text.trim();
    final contactName = _contactNameController.text.trim();
    final contactDesignation = _contactDesignationController.text.trim();
    final contactMobile = _contactMobileController.text.trim();
    final contactEmail = _contactEmailController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Text('Live Preview', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                ],
              ),
            ),
            Row(
              children: [
                InkWell(
                  onTap: _shareCurrentPreview,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.share, size: 13, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          'Share',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Real-time card', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Business Card Display
        Container(
          decoration: BoxDecoration(
            gradient: AppTheme.cardGlossGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppTheme.shadowLg,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Top Header
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Logo
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _selectedFileBytes != null
                          ? Image.memory(_selectedFileBytes!, fit: BoxFit.cover)
                          : (_existingFileUrl != null
                              ? Image.network(_existingFileUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.apartment, color: Colors.white70)))
                              : const Center(child: Icon(Icons.apartment, color: Colors.white70))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (contactName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '$contactName${contactDesignation.isNotEmpty ? ' â€¢ $contactDesignation' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    StatusBadgeChip(status: _status, isMini: true),
                  ],
                ),
              ),

              // Card Details Body
              Container(
                padding: const EdgeInsets.all(18),
                color: Colors.black.withValues(alpha: 0.2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Key Contact Box (if present)
                    if (contactMobile.isNotEmpty || contactEmail.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Key Contact', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white54)),
                            const SizedBox(height: 4),
                            if (contactMobile.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.phone_iphone, size: 12, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(contactMobile, style: GoogleFonts.inter(fontSize: 11, color: Colors.white)),
                                ],
                              ),
                            if (contactEmail.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.email_outlined, size: 12, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(contactEmail, style: GoogleFonts.inter(fontSize: 11, color: Colors.white)),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Corporate email
                    _buildPreviewDetailRow(Icons.email_outlined, email),

                    if (landline.isNotEmpty)
                      _buildPreviewDetailRow(Icons.phone_in_talk_outlined, landline),

                    // Location
                    _buildPreviewDetailRow(
                      Icons.location_on_outlined,
                      city.isNotEmpty || country.isNotEmpty ? '${city.isNotEmpty ? '$city, ' : ''}$country' : 'Headquarters Location',
                    ),

                    if (website.isNotEmpty)
                      _buildPreviewDetailRow(Icons.language, website, isAccent: true),

                    // Brands Dealt With in Preview
                    if (_selectedBrandIds.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Brands Dealt With (${_selectedBrandIds.length}):',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _selectedBrandsList.map((b) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (b.brandLogo != null && b.brandLogo!.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: Image.network(
                                      _brandService.getFileUrl(b.brandLogo),
                                      width: 14,
                                      height: 14,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.verified, size: 12, color: Colors.white),
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                Text(b.brandName, style: GoogleFonts.inter(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // Products Portfolio in Preview
                    if (_selectedProductIds.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Products Portfolio (${_selectedProductIds.length}):',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _selectedProductsList.map((p) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${p.name} (${p.brandName ?? ''})',
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.white),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        desc,
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70, height: 1.35),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Card Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CORPORATE PROFILE IDENTIFIER', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 0.5)),
                    Row(
                      children: [
                        const Icon(Icons.shield, size: 12, color: Color(0xFF34D399)),
                        const SizedBox(width: 4),
                        Text('VERIFIED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF34D399))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewDetailRow(IconData icon, String text, {bool isAccent = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.white60),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isAccent ? const Color(0xFF38BDF8) : Colors.white,
                fontWeight: isAccent ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: DIRECTORY VIEW ---
  Widget _buildDirectoryView() {
    final companies = _filteredCompanies;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Action Bar
          _buildDirectoryHeader(),
          const SizedBox(height: 16),

          if (_isLoadingList) ...[
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          ] else if (companies.isEmpty) ...[
            _buildEmptyState(),
          ] else ...[
            _buildCompaniesGrid(companies),
          ],
        ],
      ),
    );
  }

  Widget _buildDirectoryHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.shadowSm,
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registered Companies Directory', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text('Manage, view, edit, and delete company records in the system.', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CompanySearchBar(
                    allCompanies: _companies,
                    searchQuery: _searchQuery,
                    onSearchChanged: (val) => setState(() => _searchQuery = val),
                    onCompanyInspect: (comp) => setState(() => _selectedCompany = comp),
                    onCompanySelected: (comp) => setState(() => _searchQuery = comp.companyName),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _fetchCompanies,
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh Database',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.bgSubtle,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Excel Export Button
                ElevatedButton.icon(
                  onPressed: _isExportingExcel || _companies.isEmpty ? null : _exportToExcel,
                  icon: _isExportingExcel
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.file_download, size: 15),
                  label: Text(_isExportingExcel ? 'Exporting...' : 'Export Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                // PDF Export Button
                ElevatedButton.icon(
                  onPressed: _isExportingPdf || _companies.isEmpty ? null : _exportToPdf,
                  icon: _isExportingPdf
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf, size: 15),
                  label: Text(_isExportingPdf ? 'Generating...' : 'Export PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _switchToRegister,
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('New Company'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.apartment, size: 32, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text('No Companies Found', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Text('No records match your criteria or none have been registered yet.', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _switchToRegister,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Register New Company'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompaniesGrid(List<CompanyResponse> companies) {
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 1100 ? 3 : (constraints.maxWidth > 650 ? 2 : 1);

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 360,
        ),
        itemCount: companies.length,
        itemBuilder: (context, index) {
          final comp = companies[index];
          return _buildCompanyCard(comp);
        },
      );
    });
  }

  Widget _buildCompanyCard(CompanyResponse comp) {
    return InkWell(
      onTap: () => setState(() => _selectedCompany = comp),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
          boxShadow: AppTheme.shadowSm,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: comp.businessCard != null && !comp.businessCard!.endsWith('.pdf')
                        ? Image.network(
                            _companyService.getFileUrl(comp.businessCard),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Text(
                                comp.companyName.isNotEmpty ? comp.companyName.substring(0, 1).toUpperCase() : 'C',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 16),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              comp.companyName.isNotEmpty ? comp.companyName.substring(0, 1).toUpperCase() : 'C',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 16),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comp.companyName,
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (comp.contactName != null && comp.contactName!.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 12, color: Color(0xFF2563EB)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  comp.contactName!,
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      '#${comp.id}',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  StatusBadgeChip(status: comp.status, isMini: true),
                ],
              ),
            ),

            // Description & Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comp.description != null && comp.description!.isNotEmpty ? comp.description! : 'No corporate summary provided.',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary, height: 1.35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Contact Details Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.mail_outline, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  comp.email.isNotEmpty ? comp.email : 'N/A',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (comp.landline != null && comp.landline!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    comp.landline!,
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  [comp.city, comp.country].where((p) => p != null && p.isNotEmpty).join(', ').isNotEmpty
                                      ? [comp.city, comp.country].where((p) => p != null && p.isNotEmpty).join(', ')
                                      : 'Global',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Brands row
                    if (comp.brands.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.military_tech_outlined, size: 12, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 4),
                          Text(
                            'Brands (${comp.brands.length}):',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: comp.brands.map((b) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEA580C),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          b.brandName,
                                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Products row
                    if (comp.products.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 12, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 4),
                          Text(
                            'Products (${comp.products.length}):',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: comp.products.map((p) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFA7F3D0)),
                                    ),
                                    child: Text(
                                      p.name,
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF065F46)),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions Footer (Fixed, zero-shift static layout)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  // View Button
                  Expanded(
                    flex: 10,
                    child: _buildCardActionButton(
                      label: 'View',
                      icon: Icons.visibility_outlined,
                      bgColor: const Color(0xFFF1F5F9),
                      borderColor: const Color(0xFFCBD5E1),
                      textColor: const Color(0xFF334155),
                      onTap: () => setState(() => _selectedCompany = comp),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Share Button
                  Expanded(
                    flex: 11,
                    child: _buildCardActionButton(
                      label: 'Share',
                      icon: Icons.share_rounded,
                      bgColor: const Color(0xFFECFDF5),
                      borderColor: const Color(0xFFA7F3D0),
                      textColor: const Color(0xFF059669),
                      onTap: () => CompanyShareDialog.show(context, comp),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // PDF Button
                  Expanded(
                    flex: 9,
                    child: _buildCardActionButton(
                      label: 'PDF',
                      icon: Icons.picture_as_pdf_rounded,
                      bgColor: const Color(0xFFFEF2F2),
                      borderColor: const Color(0xFFFECACA),
                      textColor: const Color(0xFFDC2626),
                      onTap: () => _downloadCompanyPdf(comp),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Edit Button
                  Expanded(
                    flex: 9,
                    child: _buildCardActionButton(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      bgColor: const Color(0xFFEFF6FF),
                      borderColor: const Color(0xFFBFDBFE),
                      textColor: const Color(0xFF2563EB),
                      onTap: () => _startEdit(comp),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Delete Button
                  InkWell(
                    onTap: () => _promptDelete(comp),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardActionButton({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- View Detail Modal Dialog ---
  Widget _buildCompanyDetailModal(CompanyResponse comp) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: screenHeight * 0.88,
          ),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.shadowLg,
            border: Border.all(color: AppTheme.borderLight),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // FIXED Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppTheme.bgSubtle,
                  border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enterprise Profile • ID #${comp.id}',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 0.2),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            comp.companyName,
                            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadgeChip(status: comp.status, isMini: true),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => setState(() => _selectedCompany = null),
                      icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
              ),

              // SCROLLABLE Body (Header & Footer stay permanently fixed)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Meta Bar (2x2 structured grid)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildModalMetaItem('Corporate Email', comp.email, icon: Icons.mail_outline)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildModalMetaItem('Landline', comp.landline?.isNotEmpty == true ? comp.landline! : 'Not Specified', icon: Icons.phone_outlined)),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Divider(height: 1, thickness: 1, color: AppTheme.borderLight.withValues(alpha: 0.6)),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildModalMetaItem('Contact Person', '${comp.contactName ?? 'N/A'}${comp.contactDesignation != null ? ' (${comp.contactDesignation})' : ''}', icon: Icons.person_outline)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildModalMetaItem('Contact Mobile', comp.contactMobileNumber?.isNotEmpty == true ? comp.contactMobileNumber! : 'N/A', icon: Icons.smartphone_outlined)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Registered Address Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'REGISTERED ADDRESS',
                                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    comp.address ?? 'Not Specified',
                                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                  ),
                                  if ((comp.city != null && comp.city!.isNotEmpty) || (comp.country != null && comp.country!.isNotEmpty)) ...[
                                    const SizedBox(height: 1),
                                    Text(
                                      [comp.city, comp.country].where((s) => s != null && s.isNotEmpty).join(', '),
                                      style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Online Presence / Website Card
                      if (comp.website != null && comp.website!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.language_outlined, size: 13, color: Color(0xFF2563EB)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ONLINE PRESENCE',
                                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF1E40AF), letterSpacing: 0.5),
                                    ),
                                    const SizedBox(height: 2),
                                    InkWell(
                                      onTap: () async {
                                        final uri = Uri.tryParse(comp.website!);
                                        if (uri != null) launchUrl(uri);
                                      },
                                      child: Text(
                                        comp.website!,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF2563EB),
                                          decoration: TextDecoration.underline,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.open_in_new, size: 13, color: Color(0xFF3B82F6)),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      // Brands Dealt With
                      if (comp.brands.isNotEmpty) ...[
                        Text(
                          'Brands Dealt With (${comp.brands.length})',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: comp.brands.map((b) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                b.brandName,
                                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.primary),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Products Portfolio
                      if (comp.products.isNotEmpty) ...[
                        Text(
                          'Products Portfolio (${comp.products.length})',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: comp.products.map((p) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: Text(
                                '${p.name}${p.brandName != null ? ' (${p.brandName})' : ''}',
                                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF6B21A8)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Description
                      if (comp.description != null && comp.description!.trim().isNotEmpty) ...[
                        Text(
                          'Description',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSubtle,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Text(
                            comp.description!,
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary, height: 1.35),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Attachment / Business Card
                      if (comp.businessCard != null && comp.businessCard!.trim().isNotEmpty) ...[
                        Text(
                          'Business Card / Attachment',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        if (comp.businessCard!.toLowerCase().endsWith('.pdf'))
                          InkWell(
                            onTap: () {
                              final url = _companyService.getFileUrl(comp.businessCard);
                              final uri = Uri.tryParse(url);
                              if (uri != null) launchUrl(uri);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.picture_as_pdf, color: AppTheme.error, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'View Business Card (PDF Document)',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.error),
                                    ),
                                  ),
                                  const Icon(Icons.open_in_new, size: 13, color: AppTheme.error),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 125,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.borderLight),
                              color: AppTheme.bgSubtle,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              _companyService.getFileUrl(comp.businessCard),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Icon(Icons.broken_image, size: 32, color: AppTheme.textMuted),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              // FIXED Footer Actions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppTheme.bgSubtle,
                  border: Border(top: BorderSide(color: AppTheme.borderLight)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Primary Actions Row: Share Contact & PDF Profile
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => CompanyShareDialog.show(context, comp),
                            icon: const Icon(Icons.share_rounded, size: 15),
                            label: Text(
                              'Share Contact',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _downloadCompanyPdf(comp),
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                            label: Text(
                              'PDF Profile',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),

                    // Secondary Actions Row: Delete, Edit, Close
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final target = comp;
                              setState(() => _selectedCompany = null);
                              _promptDelete(target);
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppTheme.error),
                            label: Text(
                              'Delete',
                              style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.error, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFFEF2F2),
                              side: const BorderSide(color: Color(0xFFFECACA)),
                              padding: const EdgeInsets.symmetric(vertical: 8.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _startEdit(comp),
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            label: Text(
                              'Edit',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 8.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _selectedCompany = null),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.borderLight),
                              backgroundColor: AppTheme.bgSurface,
                              padding: const EdgeInsets.symmetric(vertical: 8.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              'Close',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalMetaItem(String label, String value, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 10, color: AppTheme.textMuted),
              const SizedBox(width: 3),
            ],
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
