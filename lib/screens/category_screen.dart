import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category_model.dart';
import '../services/api_config.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/feedback_toast.dart';
import '../widgets/file_upload_box.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final CategoryService _categoryService = CategoryService();
  final ApiConfig _apiConfig = ApiConfig();

  // State
  String _activeTab = 'register'; // 'register' or 'directory'
  bool _isLoadingList = false;
  bool _isSubmitting = false;
  FeedbackData? _feedback;

  // Edit Mode
  int? _editingCategoryId;

  // Form Fields
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int? _selectedParentId;

  // File Upload State
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  int? _selectedFileSize;
  String? _selectedFilePath;
  String? _existingFileUrl;

  // Directory State
  List<CategoryResponse> _categories = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Directory View Mode: 'main' (Main Categories) or 'sub' (Subcategories)
  String _categoryViewTab = 'main';
  String _selectedParentFilter = 'all'; // 'all' or specific parent id as string

  // Modal State
  CategoryResponse? _selectedCategory;

  // Live Preview Toggle for mobile
  bool _showLivePreview = false;

  @override
  void initState() {
    super.initState();
    _apiConfig.addListener(_onConfigChanged);
    _fetchCategories();
  }

  void _onConfigChanged() {
    if (mounted) {
      _fetchCategories();
    }
  }

  @override
  void dispose() {
    _apiConfig.removeListener(_onConfigChanged);
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Computed Hierarchy Lists ---
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

  List<CategoryResponse> get _availableParentsForForm {
    if (_editingCategoryId == null) return _parentCategories;
    return _parentCategories.where((p) => p.id != _editingCategoryId).toList();
  }

  List<CategoryResponse> get _filteredParentCategories {
    final query = _searchQuery.toLowerCase().trim();
    if (query.isEmpty) return _parentCategories;
    return _parentCategories.where((c) {
      return c.name.toLowerCase().contains(query) || c.id.toString().contains(query);
    }).toList();
  }

  List<CategoryResponse> get _filteredSubCategories {
    final query = _searchQuery.toLowerCase().trim();
    final parentFilter = _selectedParentFilter;

    return _subCategories.where((sub) {
      if (parentFilter != 'all' && sub.parentId?.toString() != parentFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchesName = sub.name.toLowerCase().contains(query);
        final matchesParent = (sub.parentName ?? '').toLowerCase().contains(query);
        final matchesId = sub.id.toString().contains(query);
        if (!matchesName && !matchesParent && !matchesId) return false;
      }
      return true;
    }).toList();
  }

  int _getSubCount(int parentId) {
    return _subCategories.where((s) => s.parentId == parentId).length;
  }

  String _getParentName(int? parentId) {
    if (parentId == null) return 'None';
    final parent = _parentCategories.cast<CategoryResponse?>().firstWhere(
          (p) => p?.id == parentId,
          orElse: () => null,
        );
    return parent?.name ?? 'None';
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoadingList = true);
    try {
      final data = await _categoryService.getAllCategories();
      if (mounted) {
        setState(() {
          _categories = data;
          _isLoadingList = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingList = false);
      }
    }
  }

  void _startEdit(CategoryResponse cat) {
    setState(() {
      _editingCategoryId = cat.id;
      _activeTab = 'register';
      _feedback = null;
      _nameController.text = cat.name;
      _selectedParentId = cat.parentId;

      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedFileSize = null;
      _selectedFilePath = null;
      _existingFileUrl = cat.categoryImage != null && cat.categoryImage!.isNotEmpty
          ? _categoryService.getFileUrl(cat.categoryImage)
          : null;

      if (_selectedCategory != null) {
        _selectedCategory = null;
      }
    });
  }

  void _addSubCategoryForParent(CategoryResponse parent) {
    setState(() {
      _editingCategoryId = null;
      _resetFormFields();
      _selectedParentId = parent.id;
      _activeTab = 'register';
      _feedback = null;

      if (_selectedCategory != null) {
        _selectedCategory = null;
      }
    });
  }

  void _resetFormFields() {
    _editingCategoryId = null;
    _nameController.clear();
    _selectedParentId = null;
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
          message: 'Please provide a valid category name (min 2 characters).',
        );
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedback = null;
    });

    final request = CategoryRequest(
      name: _nameController.text.trim(),
      parentId: _selectedParentId,
    );

    try {
      if (_editingCategoryId != null) {
        final response = await _categoryService.updateCategory(
          _editingCategoryId!,
          request,
          fileBytes: _selectedFileBytes,
          fileName: _selectedFileName,
          filePath: _selectedFilePath,
        );
        setState(() {
          _isSubmitting = false;
          _feedback = FeedbackData(
            type: 'success',
            title: 'Category Updated Successfully!',
            message: 'Category "${response.name}" (ID #${response.id}) has been updated.',
          );
          _resetFormFields();
          _activeTab = 'directory';
        });
        _fetchCategories();
      } else {
        final response = await _categoryService.createCategory(
          request,
          fileBytes: _selectedFileBytes,
          fileName: _selectedFileName,
          filePath: _selectedFilePath,
        );
        final isSub = response.parentId != null;
        setState(() {
          _isSubmitting = false;
          _feedback = FeedbackData(
            type: 'success',
            title: isSub ? 'Subcategory Registered!' : 'Main Category Registered!',
            message: 'Category "${response.name}" has been created with ID #${response.id}.',
          );
          _resetFormFields();
          _activeTab = 'directory';
          if (isSub) {
            _categoryViewTab = 'sub';
          }
        });
        _fetchCategories();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _feedback = FeedbackData(
          type: 'error',
          title: _editingCategoryId != null ? 'Update Failed' : 'Registration Failed',
          message: e.toString().replaceAll('Exception: ', ''),
        );
      });
    }
  }

  void _promptDelete(CategoryResponse cat) {
    showDialog(
      context: context,
      builder: (_) => DeleteConfirmDialog(
        title: 'Delete Category?',
        itemName: cat.name,
        itemId: cat.id,
        onConfirm: () async {
          await _categoryService.deleteCategory(cat.id);
          if (mounted) {
            setState(() {
              _feedback = FeedbackData(
                type: 'success',
                title: 'Category Deleted',
                message: 'Category "${cat.name}" has been removed.',
              );
              if (_selectedCategory?.id == cat.id) {
                _selectedCategory = null;
              }
              if (_editingCategoryId == cat.id) {
                _resetFormFields();
              }
            });
            _fetchCategories();
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
          if (_selectedCategory != null)
            _buildCategoryDetailModal(_selectedCategory!),
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
            // Add Category Button
            InkWell(
              onTap: _switchToRegister,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _activeTab == 'register' && _editingCategoryId == null
                      ? AppTheme.primaryLight
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _activeTab == 'register' && _editingCategoryId == null
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
                      color: _activeTab == 'register' && _editingCategoryId == null
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Add Category',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _activeTab == 'register' && _editingCategoryId == null
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Edit Category Pill (when in edit mode)
            if (_editingCategoryId != null) ...[
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
                            'Edit #$_editingCategoryId',
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
                        '${_categories.length}',
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
        // Left Column: Form
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildFormContent(),
          ),
        ),
        // Right Column: Live Preview Card
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
        // Section Header Banner
        _buildSectionHeaderBanner(),
        const SizedBox(height: 16),

        // Editing Notice Banner
        if (_editingCategoryId != null) ...[
          _buildEditingNoticeBanner(),
          const SizedBox(height: 16),
        ],

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 01: Category Identity & Hierarchy
              _buildFormCard(
                stepNum: '01',
                title: 'Category Identity & Hierarchy',
                subtitle: 'Set category name and choose an optional parent category',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Parent Category Selector
                    Text(
                      'Parent Category (Optional)',
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
                          value: _selectedParentId,
                          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                          hint: Row(
                            children: [
                              const Icon(Icons.account_tree_outlined, size: 18, color: AppTheme.textMuted),
                              const SizedBox(width: 10),
                              Text(
                                'None (Root / Main Category)',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Row(
                                children: [
                                  const Icon(Icons.folder_outlined, size: 18, color: AppTheme.primary),
                                  const SizedBox(width: 10),
                                  Text(
                                    'None (Root / Main Category)',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ..._availableParentsForForm.map((parent) {
                              return DropdownMenuItem<int?>(
                                value: parent.id,
                                child: Row(
                                  children: [
                                    const Icon(Icons.folder, size: 18, color: AppTheme.textSecondary),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${parent.name} (ID #${parent.id})',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedParentId = val;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select a parent category to create a Subcategory, or leave as None for a top-level Main Category.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Category Name Input
                    Text(
                      'Category Name *',
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
                        hintText: 'e.g. Consumer Electronics, Laptops, Software, Footwear',
                        prefixIcon: const Icon(Icons.label_outline, size: 18, color: AppTheme.textMuted),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return 'Category name is required (min 2 characters)';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 02: Category Icon & Banner Upload
              _buildFormCard(
                stepNum: '02',
                title: 'Category Icon & Banner',
                subtitle: 'Upload a visual thumbnail or banner image for this category (JPG, PNG, WEBP, GIF)',
                child: FileUploadBox(
                  title: 'Drop your category banner or icon here',
                  hint: 'or browse images from your device',
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
                          _editingCategoryId != null ? Icons.cancel_outlined : Icons.restart_alt,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _editingCategoryId != null ? 'Cancel Edit' : 'Reset Form',
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
                                _editingCategoryId != null ? Icons.check_circle_outline : Icons.add_circle,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _editingCategoryId != null ? 'Update Category' : 'Create Category',
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
    final isEdit = _editingCategoryId != null;
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
              isEdit ? Icons.edit_note_rounded : Icons.label_rounded,
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
                        isEdit ? 'Update Category' : 'Create Category',
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
                          'ID #$_editingCategoryId',
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
                      ? 'Update category name, hierarchy, and image.'
                      : 'Define main categories or nested subcategories.',
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are editing category #$_editingCategoryId. Need to create a new category instead?',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
          TextButton(
            onPressed: _switchToRegister,
            child: Text(
              'Switch to Add',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
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
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
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
        : 'Category Name';
    final isSubcategory = _selectedParentId != null;
    final parentName = _getParentName(_selectedParentId);

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
              'Catalog Card Appearance',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Live Preview Card
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
              // Media Banner
              Container(
                height: 150,
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
                        return const Center(child: Icon(Icons.folder, size: 48, color: Colors.white54));
                      })
                    else
                      Center(
                        child: Icon(
                          isSubcategory ? Icons.account_tree_rounded : Icons.folder_rounded,
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
                    // Badges Top Overlay
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSubcategory
                                  ? const Color(0xFF7C3AED).withValues(alpha: 0.9)
                                  : AppTheme.primary.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSubcategory ? Icons.account_tree : Icons.folder_special,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isSubcategory ? 'SUBCATEGORY' : 'MAIN CATEGORY',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _editingCategoryId != null ? '#$_editingCategoryId' : '#NEW',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Card Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (isSubcategory) ...[
                      Row(
                        children: [
                          const Icon(Icons.subdirectory_arrow_right, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Parent: ',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          Text(
                            parentName,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Root Catalog Category • Can contain subcategories',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Card Footer
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
                      isSubcategory ? 'SUBCATEGORY RECORD' : 'MAIN CATEGORY',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ACTIVE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
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
        const SizedBox(height: 16),

        // Hierarchy Stats Info Box
        Container(
          padding: const EdgeInsets.all(16),
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
                  const Icon(Icons.account_tree_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Hierarchy Organization',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Organize your catalog by grouping products into Main Categories and detailed Subcategories for effortless browsing.',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder, size: 13, color: AppTheme.primary),
                        const SizedBox(width: 5),
                        Text(
                          '${_parentCategories.length} Main Categories',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_tree, size: 13, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 5),
                        Text(
                          '${_subCategories.length} Subcategories',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7C3AED),
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

  // --- TAB 2: DIRECTORY VIEW ---
  Widget _buildDirectoryView() {
    final isMain = _categoryViewTab == 'main';
    final items = isMain ? _filteredParentCategories : _filteredSubCategories;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Directory Header
          _buildDirectoryHeader(),
          const SizedBox(height: 16),

          // View Toggle Bar (Main Categories vs Subcategories)
          _buildViewToggleBar(),
          const SizedBox(height: 16),

          // Content States
          if (_isLoadingList) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (items.isEmpty) ...[
            _buildEmptyState(isMain),
          ] else ...[
            _buildCategoriesGrid(items, isMain),
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
            'Categories Directory',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Explore, inspect, edit, and organize product categories.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Search Field
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Search categories...',
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
              // Refresh Button
              IconButton(
                onPressed: _fetchCategories,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh Database',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.bgSubtle,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              // New Category Button
              ElevatedButton.icon(
                onPressed: _switchToRegister,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('New Category'),
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

  Widget _buildViewToggleBar() {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 600;
      return Flex(
        direction: isNarrow ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // View Toggle Tabs (Expanded on mobile so they never overflow)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
              children: [
                // Main Categories Toggle
                Expanded(
                  flex: isNarrow ? 1 : 0,
                  child: InkWell(
                    onTap: () => setState(() => _categoryViewTab = 'main'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: _categoryViewTab == 'main' ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder,
                            size: 14,
                            color: _categoryViewTab == 'main' ? Colors.white : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Main Categories',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _categoryViewTab == 'main' ? Colors.white : AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: _categoryViewTab == 'main'
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : AppTheme.bgSubtle,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_parentCategories.length}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _categoryViewTab == 'main'
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Subcategories Toggle
                Expanded(
                  flex: isNarrow ? 1 : 0,
                  child: InkWell(
                    onTap: () => setState(() => _categoryViewTab = 'sub'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: _categoryViewTab == 'sub' ? const Color(0xFF7C3AED) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_tree,
                            size: 14,
                            color: _categoryViewTab == 'sub' ? Colors.white : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Subcategories',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _categoryViewTab == 'sub' ? Colors.white : AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: _categoryViewTab == 'sub'
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : AppTheme.bgSubtle,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_subCategories.length}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _categoryViewTab == 'sub'
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // In Subcategories View: Filter by Parent Dropdown
          if (_categoryViewTab == 'sub' && _parentCategories.isNotEmpty) ...[
            SizedBox(height: isNarrow ? 8 : 0),
            Container(
              width: isNarrow ? double.infinity : null,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 15, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Parent:',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedParentFilter,
                        isExpanded: true,
                        style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textPrimary),
                        items: [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All Main Categories (${_subCategories.length})'),
                          ),
                          ..._parentCategories.map((p) {
                            return DropdownMenuItem(
                              value: p.id.toString(),
                              child: Text('${p.name} (${_getSubCount(p.id)})'),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedParentFilter = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildEmptyState(bool isMain) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMain ? Icons.folder_off_outlined : Icons.account_tree_outlined,
                size: 32,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isMain ? 'No Main Categories Found' : 'No Subcategories Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isMain
                  ? 'No main categories match your search or none have been created yet.'
                  : 'No subcategories match your selected parent category or search filter.',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _switchToRegister,
              icon: const Icon(Icons.add, size: 16),
              label: Text(isMain ? 'Create First Main Category' : 'Create Subcategory'),
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

  Widget _buildCategoriesGrid(List<CategoryResponse> items, bool isMain) {
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
          mainAxisExtent: 220,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final cat = items[index];
          return _buildCategoryCard(cat, isMain);
        },
      );
    });
  }

  Widget _buildCategoryCard(CategoryResponse cat, bool isMain) {
    final subCount = _getSubCount(cat.id);

    return InkWell(
      onTap: () => setState(() => _selectedCategory = cat),
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
            // Top Media Image / Banner
            Container(
              height: 90,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppTheme.cardGlossGradient,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cat.categoryImage != null && cat.categoryImage!.isNotEmpty)
                    Image.network(
                      _categoryService.getFileUrl(cat.categoryImage),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          isMain ? Icons.folder_rounded : Icons.account_tree_rounded,
                          size: 36,
                          color: Colors.white38,
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Icon(
                        isMain ? Icons.folder_rounded : Icons.account_tree_rounded,
                        size: 36,
                        color: Colors.white30,
                      ),
                    ),
                  // Overlay gradient
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
                  // Badges
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isMain ? AppTheme.primary : const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isMain ? 'Main' : 'Sub',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
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
                        'ID #${cat.id}',
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

            // Card Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (isMain) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_tree, size: 11, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '$subCount Subcategories',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const Icon(Icons.subdirectory_arrow_right, size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              'Parent: ${cat.parentName ?? _getParentName(cat.parentId)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
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
            ),

            // Card Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const BoxDecoration(
                color: AppTheme.bgSubtle,
                border: Border(top: BorderSide(color: AppTheme.borderLight)),
              ),
              child: Row(
                children: [
                  // View
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedCategory = cat),
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

                  // Quick + Sub for Main Categories
                  if (isMain) ...[
                    Expanded(
                      child: InkWell(
                        onTap: () => _addSubCategoryForParent(cat),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_circle_outline, size: 14, color: AppTheme.primary),
                              const SizedBox(width: 3),
                              Text(
                                '+ Sub',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Edit
                  Expanded(
                    child: InkWell(
                      onTap: () => _startEdit(cat),
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

                  // Delete
                  InkWell(
                    onTap: () => _promptDelete(cat),
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

  // --- View Category Detail Modal ---
  Widget _buildCategoryDetailModal(CategoryResponse cat) {
    final isSub = cat.parentId != null;
    final parentName = cat.parentName ?? _getParentName(cat.parentId);
    final nestedSubs = _subCategories.where((s) => s.parentId == cat.id).toList();

    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: 580,
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.shadowLg,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
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
                                'Category Detail • ID #${cat.id}',
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSub ? const Color(0xFFF3E8FF) : AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isSub ? 'Subcategory' : 'Main Category',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isSub ? const Color(0xFF7C3AED) : AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _selectedCategory = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Modal Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta Bar
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildModalMetaItem('Category ID', '#${cat.id}'),
                          _buildModalMetaItem('Name', cat.name),
                          _buildModalMetaItem('Type', isSub ? 'Subcategory' : 'Main Category'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // If Subcategory: Parent Reference
                    if (isSub) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.folder, size: 20, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Parent Category',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                ),
                                Text(
                                  '$parentName (ID #${cat.parentId})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // If Main Category: Nested Subcategories List
                    if (!isSub) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_tree_rounded, size: 16, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Nested Subcategories (${nestedSubs.length})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              _addSubCategoryForParent(cat);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.add, size: 13, color: AppTheme.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Add Subcategory',
                                    style: GoogleFonts.inter(
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
                      ),
                      const SizedBox(height: 8),

                      if (nestedSubs.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSubtle,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'No subcategories created yet under ${cat.name}.',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: nestedSubs.map((sub) {
                            return InkWell(
                              onTap: () {
                                setState(() => _selectedCategory = sub);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E8FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE9D5FF)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.label, size: 12, color: Color(0xFF7C3AED)),
                                    const SizedBox(width: 5),
                                    Text(
                                      sub.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6B21A8),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '#${sub.id}',
                                      style: GoogleFonts.inter(fontSize: 10, color: Color(0xFF9333EA)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 16),
                    ],

                    // Image Display
                    if (cat.categoryImage != null && cat.categoryImage!.isNotEmpty) ...[
                      Text(
                        'Category Banner / Image',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          _categoryService.getFileUrl(cat.categoryImage),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image, size: 40, color: AppTheme.textMuted),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Modal Footer Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                            final target = cat;
                            setState(() => _selectedCategory = null);
                            _promptDelete(target);
                          },
                          icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                          label: Text(
                            'Delete',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.error,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFECACA)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            _startEdit(cat);
                          },
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text('Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton(
                      onPressed: () => setState(() => _selectedCategory = null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Close', style: GoogleFonts.inter(fontSize: 12)),
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
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
