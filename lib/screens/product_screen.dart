import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/brand_model.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../services/api_config.dart';
import '../services/brand_service.dart';
import '../services/category_service.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/feedback_toast.dart';
import '../widgets/file_upload_box.dart';

class ProductScreen extends StatefulWidget {
  final Function(int tabIndex)? onSwitchTab;

  const ProductScreen({super.key, this.onSwitchTab});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ProductService _productService = ProductService();
  final CategoryService _categoryService = CategoryService();
  final BrandService _brandService = BrandService();
  final ApiConfig _apiConfig = ApiConfig();

  // State
  String _activeTab = 'register'; // 'register' or 'directory'
  bool _isLoadingList = false;
  bool _isLoadingPrereqs = false;
  bool _isSubmitting = false;
  FeedbackData? _feedback;

  // Edit Mode
  int? _editingProductId;

  // Form Fields
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _selectedCategoryId;
  int? _selectedSubCategoryId;
  int? _selectedBrandId;
  bool _isFeatured = false;

  // File Upload State
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  int? _selectedFileSize;
  String? _selectedFilePath;
  String? _existingFileUrl;

  // Prerequisites Data
  List<CategoryResponse> _categories = [];
  List<BrandResponse> _brands = [];

  // Directory State
  List<ProductResponse> _products = [];
  String _searchQuery = '';
  String _filterCategory = 'all';
  String _filterSubCategory = 'all';
  String _filterBrand = 'all';
  String _filterFeatured = 'all'; // 'all', 'featured', 'standard'
  final TextEditingController _searchController = TextEditingController();

  // Modal State
  ProductResponse? _selectedProduct;

  // Live preview toggle for mobile
  bool _showLivePreview = false;

  @override
  void initState() {
    super.initState();
    _apiConfig.addListener(_onConfigChanged);
    _fetchPrerequisites();
    _fetchProducts();
  }

  void _onConfigChanged() {
    if (mounted) {
      _fetchPrerequisites();
      _fetchProducts();
    }
  }

  @override
  void dispose() {
    _apiConfig.removeListener(_onConfigChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Hierarchy Computations ---
  List<CategoryResponse> get _parentCategories {
    return _categories.where((c) => c.parentId == null).toList();
  }

  List<CategoryResponse> get _subCategories {
    final parents = _parentCategories;
    return _categories.where((c) => c.parentId != null).map((sub) {
      final parent = parents.cast<CategoryResponse?>().firstWhere(
            (p) => p?.id == sub.parentId,
            orElse: () => null,
          );
      return sub.copyWith(parentName: parent?.name ?? 'None');
    }).toList();
  }

  List<CategoryResponse> get _availableFormSubCategories {
    if (_selectedCategoryId == null) return [];
    return _subCategories.where((s) => s.parentId == _selectedCategoryId).toList();
  }

  List<CategoryResponse> get _filterSubCategoriesList {
    if (_filterCategory == 'all') return _subCategories;
    final catId = int.tryParse(_filterCategory);
    if (catId == null) return _subCategories;
    return _subCategories.where((s) => s.parentId == catId).toList();
  }

  String _getCategoryName(int? id) {
    if (id == null) return '';
    final cat = _categories.cast<CategoryResponse?>().firstWhere(
          (c) => c?.id == id,
          orElse: () => null,
        );
    return cat?.name ?? 'Category #$id';
  }

  String _getSubCategoryName(int? id) {
    if (id == null) return '';
    final sub = _subCategories.cast<CategoryResponse?>().firstWhere(
          (s) => s?.id == id,
          orElse: () => null,
        );
    return sub?.name ?? 'Subcategory #$id';
  }

  String _getBrandName(int? id) {
    if (id == null) return '';
    final brand = _brands.cast<BrandResponse?>().firstWhere(
          (b) => b?.id == id,
          orElse: () => null,
        );
    return brand?.brandName ?? 'Brand #$id';
  }

  Future<void> _fetchPrerequisites() async {
    setState(() => _isLoadingPrereqs = true);
    try {
      final cats = await _categoryService.getAllCategories();
      final brs = await _brandService.getAllBrands();
      if (mounted) {
        setState(() {
          _categories = cats;
          _brands = brs;
          _isLoadingPrereqs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPrereqs = false);
    }
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoadingList = true);
    try {
      final data = await _productService.getAllProducts();
      if (mounted) {
        setState(() {
          _products = data;
          _isLoadingList = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  void _startEdit(ProductResponse product) {
    setState(() {
      _editingProductId = product.id;
      _activeTab = 'register';
      _feedback = null;
      _nameController.text = product.name;
      _descriptionController.text = product.description ?? '';
      _selectedCategoryId = product.categoryId;
      _selectedSubCategoryId = product.subCategoryId;
      _selectedBrandId = product.brandId;
      _isFeatured = product.isFeatured;

      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedFileSize = null;
      _selectedFilePath = null;
      _existingFileUrl = product.image != null && product.image!.isNotEmpty
          ? _productService.getFileUrl(product.image)
          : null;

      if (_selectedProduct != null) {
        _selectedProduct = null;
      }
    });
  }

  void _resetFormFields() {
    _editingProductId = null;
    _nameController.clear();
    _descriptionController.clear();
    _selectedCategoryId = null;
    _selectedSubCategoryId = null;
    _selectedBrandId = null;
    _isFeatured = false;
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
          message: 'Please fill in all required fields (Product Name, Category, and Brand).',
        );
      });
      return;
    }

    if (_selectedCategoryId == null) {
      setState(() {
        _feedback = FeedbackData(
          type: 'error',
          title: 'Validation Error',
          message: 'Please select a Main Category for this product.',
        );
      });
      return;
    }

    if (_selectedBrandId == null) {
      setState(() {
        _feedback = FeedbackData(
          type: 'error',
          title: 'Validation Error',
          message: 'Please select a Brand for this product.',
        );
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedback = null;
    });

    final request = ProductRequest(
      name: _nameController.text.trim(),
      categoryId: _selectedCategoryId!,
      subCategoryId: _selectedSubCategoryId,
      brandId: _selectedBrandId!,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      isFeatured: _isFeatured,
    );

    try {
      if (_editingProductId != null) {
        final response = await _productService.updateProduct(
          _editingProductId!,
          request,
          fileBytes: _selectedFileBytes,
          fileName: _selectedFileName,
          filePath: _selectedFilePath,
        );
        setState(() {
          _isSubmitting = false;
          _feedback = FeedbackData(
            type: 'success',
            title: 'Product Updated Successfully!',
            message: 'Product "${response.name}" (ID #${response.id}) has been updated.',
          );
          _resetFormFields();
          _activeTab = 'directory';
        });
        _fetchProducts();
      } else {
        final response = await _productService.createProduct(
          request,
          fileBytes: _selectedFileBytes,
          fileName: _selectedFileName,
          filePath: _selectedFilePath,
        );
        setState(() {
          _isSubmitting = false;
          _feedback = FeedbackData(
            type: 'success',
            title: 'Product Registered Successfully!',
            message: 'Product "${response.name}" has been registered with ID #${response.id}.',
          );
          _resetFormFields();
          _activeTab = 'directory';
        });
        _fetchProducts();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _feedback = FeedbackData(
          type: 'error',
          title: _editingProductId != null ? 'Update Failed' : 'Registration Failed',
          message: e.toString().replaceAll('Exception: ', ''),
        );
      });
    }
  }

  void _promptDelete(ProductResponse product) {
    showDialog(
      context: context,
      builder: (_) => DeleteConfirmDialog(
        title: 'Delete Product?',
        itemName: product.name,
        itemId: product.id,
        onConfirm: () async {
          await _productService.deleteProduct(product.id);
          if (mounted) {
            setState(() {
              _feedback = FeedbackData(
                type: 'success',
                title: 'Product Deleted',
                message: 'Product "${product.name}" has been permanently deleted.',
              );
              if (_selectedProduct?.id == product.id) {
                _selectedProduct = null;
              }
              if (_editingProductId == product.id) {
                _resetFormFields();
              }
            });
            _fetchProducts();
          }
        },
      ),
    );
  }

  List<ProductResponse> get _filteredProducts {
    final query = _searchQuery.toLowerCase().trim();
    return _products.where((p) {
      // Search match
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.id.toString().contains(query) ||
          (p.brandName ?? '').toLowerCase().contains(query) ||
          (p.categoryName ?? '').toLowerCase().contains(query) ||
          (p.subCategoryName ?? '').toLowerCase().contains(query) ||
          (p.description ?? '').toLowerCase().contains(query);
      if (!matchesQuery) return false;

      // Category filter
      if (_filterCategory != 'all' && p.categoryId.toString() != _filterCategory) {
        return false;
      }

      // Subcategory filter
      if (_filterSubCategory != 'all' && p.subCategoryId?.toString() != _filterSubCategory) {
        return false;
      }

      // Brand filter
      if (_filterBrand != 'all' && p.brandId.toString() != _filterBrand) {
        return false;
      }

      // Featured filter
      if (_filterFeatured == 'featured') return p.isFeatured;
      if (_filterFeatured == 'standard') return !p.isFeatured;

      return true;
    }).toList();
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
          if (_selectedProduct != null)
            _buildProductDetailModal(_selectedProduct!),
        ],
      ),
    );
  }

  // --- Top Navigation Tabs Bar ---
  Widget _buildTopNavTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.bgSurface,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderLight, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add Product Button
            InkWell(
              onTap: _switchToRegister,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _activeTab == 'register' && _editingProductId == null
                      ? AppTheme.primaryLight
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _activeTab == 'register' && _editingProductId == null
                        ? AppTheme.primary.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle,
                      size: 16,
                      color: _activeTab == 'register' && _editingProductId == null
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Add Product',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _activeTab == 'register' && _editingProductId == null
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Edit Product Pill
            if (_editingProductId != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          const Icon(Icons.edit, size: 14, color: AppTheme.warning),
                          const SizedBox(width: 4),
                          Text(
                            'Edit #$_editingProductId',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _switchToRegister,
                      borderRadius: BorderRadius.circular(10),
                      child: const Icon(Icons.close, size: 14, color: Color(0xFFB45309)),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                      size: 16,
                      color: _activeTab == 'directory' ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Directory',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _activeTab == 'directory' ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _activeTab == 'directory'
                            ? AppTheme.primary
                            : AppTheme.bgSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_products.length}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
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
                      _showLivePreview ? 'Hide Live Preview' : 'Show Live Card Preview',
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

        if (_editingProductId != null) ...[
          _buildEditingNoticeBanner(),
          const SizedBox(height: 16),
        ],

        // Prerequisites Alert (if missing categories or brands)
        if (_parentCategories.isEmpty || _brands.isEmpty) ...[
          _buildPrerequisitesAlert(),
          const SizedBox(height: 16),
        ],

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step 01: Core Specifications Card
              _buildFormCard(
                stepNum: '01',
                title: 'Core Specifications',
                subtitle: 'Product title, taxonomy hierarchy assignment, and details',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      'Product Name *',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. MacBook Pro M3, Air Max 90, Galaxy S24 Ultra...',
                        prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18, color: AppTheme.textMuted),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return 'Product name is required (min 2 characters, max 200)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Main Category & Subcategory Row
                    LayoutBuilder(builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 600;
                      return Flex(
                        direction: isNarrow ? Axis.vertical : Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main Category Selector
                          Expanded(
                            flex: isNarrow ? 0 : 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Main Category *',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.borderLight),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int?>(
                                      isExpanded: true,
                                      value: _selectedCategoryId,
                                      icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                                      hint: Row(
                                        children: [
                                          const Icon(Icons.folder_open, size: 18, color: AppTheme.textMuted),
                                          const SizedBox(width: 8),
                                          Text(
                                            (_isLoadingPrereqs ? 'Loading Categories...' : '-- Select Main Category --'),
                                            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                      items: _parentCategories.map((cat) {
                                        return DropdownMenuItem<int?>(
                                          value: cat.id,
                                          child: Row(
                                            children: [
                                              const Icon(Icons.folder, size: 16, color: AppTheme.primary),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${cat.name} (ID #${cat.id})',
                                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedCategoryId = val;
                                          // Check if current subcategory is still valid under new parent
                                          if (_selectedSubCategoryId != null) {
                                            final isValid = _availableFormSubCategories
                                                .any((s) => s.id == _selectedSubCategoryId);
                                            if (!isValid) _selectedSubCategoryId = null;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isNarrow ? 0 : 14, height: isNarrow ? 14 : 0),

                          // Subcategory Selector
                          Expanded(
                            flex: isNarrow ? 0 : 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Subcategory (Optional)',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _selectedCategoryId == null ? AppTheme.bgSubtle : AppTheme.bgSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.borderLight),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int?>(
                                      isExpanded: true,
                                      value: _selectedSubCategoryId,
                                      icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                                      hint: Row(
                                        children: [
                                          const Icon(Icons.account_tree_outlined, size: 18, color: AppTheme.textMuted),
                                          const SizedBox(width: 8),
                                          Text(
                                            _selectedCategoryId == null
                                                ? 'Select Main Category first'
                                                : 'None (Main Category Only)',
                                            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                      items: [
                                        DropdownMenuItem<int?>(
                                          value: null,
                                          child: Text(
                                            'None (Main Category Only)',
                                            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                                          ),
                                        ),
                                        ..._availableFormSubCategories.map((sub) {
                                          return DropdownMenuItem<int?>(
                                            value: sub.id,
                                            child: Row(
                                              children: [
                                                const Icon(Icons.label, size: 15, color: Color(0xFF7C3AED)),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${sub.name} (ID #${sub.id})',
                                                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                      onChanged: _selectedCategoryId == null
                                          ? null
                                          : (val) {
                                              setState(() {
                                                _selectedSubCategoryId = val;
                                              });
                                            },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),

                    // Brand Selector
                    Text(
                      'Brand *',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          isExpanded: true,
                          value: _selectedBrandId,
                          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                          hint: Row(
                            children: [
                              const Icon(Icons.verified_outlined, size: 18, color: AppTheme.textMuted),
                              const SizedBox(width: 8),
                              Text(
                                '-- Select Brand --',
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                          items: _brands.map((b) {
                            return DropdownMenuItem<int?>(
                              value: b.id,
                              child: Row(
                                children: [
                                  if (b.brandLogo != null && b.brandLogo!.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        _brandService.getFileUrl(b.brandLogo),
                                        width: 20,
                                        height: 20,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.verified, size: 16, color: AppTheme.primary),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        b.initials,
                                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.primary),
                                      ),
                                    ),
                                  const SizedBox(width: 10),
                                  Text(
                                    b.brandName,
                                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
                                  ),
                                  if (b.isFeatured) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.star, size: 13, color: Color(0xFFF59E0B)),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedBrandId = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Featured Product Toggle Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isFeatured ? const Color(0xFFFFFBEB) : AppTheme.bgSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isFeatured ? const Color(0xFFFDE68A) : AppTheme.borderLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _isFeatured ? const Color(0xFFFEF3C7) : AppTheme.bgSurface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.star_rounded,
                              color: _isFeatured ? const Color(0xFFD97706) : AppTheme.textMuted,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Featured Product Promotion',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _isFeatured ? const Color(0xFF92400E) : AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Promote this product with a gold showcase star in directories and company portfolios.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: _isFeatured ? const Color(0xFFB45309) : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isFeatured,
                            activeThumbColor: const Color(0xFFD97706),
                            onChanged: (val) => setState(() => _isFeatured = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description Textarea
                    Text(
                      'Product Description (Optional)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Enter technical specifications, highlights, features, or product summary...',
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Step 02: Image & Showcase Asset Upload
              _buildFormCard(
                stepNum: '02',
                title: 'Product Showcase Image',
                subtitle: 'Upload a product photograph or graphic thumbnail (JPG, PNG, WEBP, GIF)',
                child: FileUploadBox(
                  title: 'Drop your product photo or asset here',
                  hint: 'or browse files from your device',
                  allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
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
              const SizedBox(height: 24),

              // Form Action Buttons
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
                        Icon(
                          _editingProductId != null ? Icons.cancel_outlined : Icons.restart_alt,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _editingProductId != null ? 'Cancel Edit' : 'Reset Form',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
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
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _editingProductId != null ? Icons.check_circle_outline : Icons.add_circle,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _editingProductId != null ? 'Update Product Details' : 'Complete Product Registration',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
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
    final isEdit = _editingProductId != null;
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
              isEdit ? Icons.edit_note_rounded : Icons.inventory_2_rounded,
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
                        isEdit ? 'Update Product Record' : 'Product Registration',
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
                          'ID #$_editingProductId',
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
                      ? 'Modify product specifications, category, brand, or image.'
                      : 'Register enterprise product linked with Category and Brand.',
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
              'Editing product #$_editingProductId.',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF92400E),
              ),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrerequisitesAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prerequisite Setup Required',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Products require both a Main Category and a Brand before they can be registered in the catalog.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB91C1C)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    if (_parentCategories.isEmpty)
                      ElevatedButton.icon(
                        onPressed: () => widget.onSwitchTab?.call(1),
                        icon: const Icon(Icons.folder_open, size: 14),
                        label: const Text('Register a Category'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (_brands.isEmpty)
                      ElevatedButton.icon(
                        onPressed: () => widget.onSwitchTab?.call(2),
                        icon: const Icon(Icons.verified, size: 14),
                        label: const Text('Register a Brand'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  stepNum,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          child,
        ],
      ),
    );
  }

  // --- Live Preview Sidebar ---
  Widget _buildLivePreviewSidebar() {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Your Product Name';
    final desc = _descriptionController.text.trim();
    final catName = _getCategoryName(_selectedCategoryId);
    final subCatName = _getSubCategoryName(_selectedSubCategoryId);
    final brandName = _getBrandName(_selectedBrandId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview Header
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
                  Text(
                    'Live Preview',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Showcase Card Appearance',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Live Preview Showcase Card
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
            boxShadow: AppTheme.shadowMd,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image Display
              Container(
                height: 160,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: AppTheme.cardGlossGradient,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_selectedFileBytes != null)
                      Image.memory(_selectedFileBytes!, fit: BoxFit.cover)
                    else if (_existingFileUrl != null)
                      Image.network(_existingFileUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Icon(Icons.inventory_2, size: 48, color: Colors.white54));
                      })
                    else
                      Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 52,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                    // Featured Star Badge
                    if (_isFeatured)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Featured',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // ID Badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _editingProductId != null ? '#$_editingProductId' : '#NEW',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Body Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand & Subcategory tags
                    Row(
                      children: [
                        if (brandName.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified, size: 11, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  brandName,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (subCatName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              subCatName,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Title
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Hierarchy Breadcrumb
                    if (catName.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.folder_open, size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(catName, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                          if (subCatName.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 14, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(subCatName, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ],
                      ),

                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        desc,
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppTheme.bgSubtle,
                  border: Border(top: BorderSide(color: AppTheme.borderLight)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PRODUCT SPECIFICATION',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 13, color: AppTheme.success),
                        const SizedBox(width: 4),
                        Text(
                          'CATALOG READY',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success,
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
      ],
    );
  }

  // --- TAB 2: DIRECTORY VIEW ---
  Widget _buildDirectoryView() {
    final products = _filteredProducts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildDirectoryHeader(),
          const SizedBox(height: 16),

          // Drilldown Filters Bar
          _buildDrilldownFilterBar(),
          const SizedBox(height: 16),

          if (_isLoadingList) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (products.isEmpty) ...[
            _buildEmptyState(),
          ] else ...[
            _buildProductsGrid(products),
          ],
        ],
      ),
    );
  }

  Widget _buildDirectoryHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Products Directory',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Manage, inspect, filter, edit, and organize product catalog records.',
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _fetchProducts,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh Database',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.bgSubtle,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _switchToRegister,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('New Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrilldownFilterBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Filter by Main Category
          _buildFilterDropdown(
            icon: Icons.folder_open,
            label: 'Main Category:',
            value: _filterCategory,
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All Main Categories')),
              ..._parentCategories.map((c) => DropdownMenuItem(value: c.id.toString(), child: Text(c.name))),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _filterCategory = val;
                  _filterSubCategory = 'all';
                });
              }
            },
          ),

          // Filter by Subcategory
          _buildFilterDropdown(
            icon: Icons.account_tree_outlined,
            label: 'Subcategory:',
            value: _filterSubCategory,
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All Subcategories')),
              ..._filterSubCategoriesList.map((s) => DropdownMenuItem(value: s.id.toString(), child: Text(s.name))),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _filterSubCategory = val);
            },
          ),

          // Filter by Brand
          _buildFilterDropdown(
            icon: Icons.verified_outlined,
            label: 'Brand:',
            value: _filterBrand,
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All Brands')),
              ..._brands.map((b) => DropdownMenuItem(value: b.id.toString(), child: Text(b.brandName))),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _filterBrand = val);
            },
          ),

          // Promotion Filter Chips
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPromotionFilterChip('all', 'All'),
              const SizedBox(width: 4),
              _buildPromotionFilterChip('featured', 'Featured'),
              const SizedBox(width: 4),
              _buildPromotionFilterChip('standard', 'Standard'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required IconData icon,
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.bgSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionFilterChip(String mode, String label) {
    final isSelected = _filterFeatured == mode;
    return InkWell(
      onTap: () => setState(() => _filterFeatured = mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.bgSubtle,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
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
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_outlined, size: 32, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No Products Found',
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'No product records match your selected filters or search query.',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _switchToRegister,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Register New Product'),
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

  Widget _buildProductsGrid(List<ProductResponse> products) {
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 1100
          ? 3
          : (constraints.maxWidth > 650 ? 2 : 1);

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 250,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final prod = products[index];
          return _buildProductCard(prod);
        },
      );
    });
  }

  Widget _buildProductCard(ProductResponse prod) {
    return InkWell(
      onTap: () => setState(() => _selectedProduct = prod),
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
            // Top Media Image
            Container(
              height: 95,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppTheme.cardGlossGradient,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (prod.image != null && prod.image!.isNotEmpty)
                    Image.network(
                      _productService.getFileUrl(prod.image),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.inventory_2, size: 36, color: Colors.white38),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.inventory_2, size: 36, color: Colors.white30),
                    ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                  // Featured Badge
                  if (prod.isFeatured)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              'Featured',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // ID Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ID #${prod.id}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (prod.brandName != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              prod.brandName!,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (prod.subCategoryName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              prod.subCategoryName!,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prod.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Hierarchy path breadcrumb
                    Row(
                      children: [
                        const Icon(Icons.folder_open, size: 11, color: AppTheme.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          prod.categoryName ?? 'Category',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        if (prod.subCategoryName != null) ...[
                          const SizedBox(width: 3),
                          const Icon(Icons.chevron_right, size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              prod.subCategoryName!,
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const BoxDecoration(
                color: AppTheme.bgSubtle,
                border: Border(top: BorderSide(color: AppTheme.borderLight)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedProduct = prod),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.visibility_outlined, size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              'View',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _startEdit(prod),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                            const SizedBox(width: 3),
                            Text(
                              'Edit',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _promptDelete(prod),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Icon(Icons.delete_outline, size: 15, color: AppTheme.error),
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

  // --- View Detail Modal ---
  Widget _buildProductDetailModal(ProductResponse prod) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
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
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          Row(
                            children: [
                              Text(
                                'Product Detail • ID #${prod.id}',
                                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 0.2),
                              ),
                              if (prod.isFeatured) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, size: 10, color: Color(0xFFD97706)),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Featured',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            prod.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _selectedProduct = null),
                      icon: const Icon(Icons.close, size: 20, color: AppTheme.textSecondary),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _buildModalMetaItem('Brand', prod.brandName ?? 'N/A')),
                          Container(width: 1, height: 28, color: AppTheme.borderLight),
                          Expanded(child: _buildModalMetaItem('Category', prod.categoryName ?? 'N/A')),
                          if (prod.subCategoryName != null && prod.subCategoryName!.isNotEmpty) ...[
                            Container(width: 1, height: 28, color: AppTheme.borderLight),
                            Expanded(child: _buildModalMetaItem('Subcategory', prod.subCategoryName!)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Hierarchy Breadcrumb Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_tree_outlined, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Taxonomy: ',
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                          ),
                          Text(
                            prod.categoryName ?? 'Category',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          ),
                          if (prod.subCategoryName != null && prod.subCategoryName!.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 12, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              prod.subCategoryName!,
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    if (prod.description != null && prod.description!.trim().isNotEmpty) ...[
                      Text(
                        'Description',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Text(
                          prod.description!,
                          style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Image Display
                    if (prod.image != null && prod.image!.trim().isNotEmpty) ...[
                      Text(
                        'Product Photograph',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderLight),
                          color: AppTheme.bgSubtle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          _productService.getFileUrl(prod.image),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image, size: 36, color: AppTheme.textMuted),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppTheme.bgSubtle,
                  border: Border(top: BorderSide(color: AppTheme.borderLight)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            final target = prod;
                            setState(() => _selectedProduct = null);
                            _promptDelete(target);
                          },
                          icon: const Icon(Icons.delete_outline, size: 14, color: AppTheme.error),
                          label: Text('Delete', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.error, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFECACA)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            _startEdit(prod);
                          },
                          icon: const Icon(Icons.edit, size: 13),
                          label: Text('Edit', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton(
                      onPressed: () => setState(() => _selectedProduct = null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text('Close', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
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

  Widget _buildModalMetaItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
