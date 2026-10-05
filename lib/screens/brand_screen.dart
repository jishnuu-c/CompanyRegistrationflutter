import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/brand_model.dart';
import '../services/api_config.dart';
import '../services/brand_service.dart';
import '../theme/app_theme.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/feedback_toast.dart';
import '../widgets/file_upload_box.dart';
import '../widgets/status_badge_chip.dart';

class BrandScreen extends StatefulWidget {
  const BrandScreen({super.key});

  @override
  State<BrandScreen> createState() => _BrandScreenState();
}

class _BrandScreenState extends State<BrandScreen> {
  final BrandService _brandService = BrandService();
  final ApiConfig _apiConfig = ApiConfig();

  // State
  String _activeTab = 'register'; // 'register' or 'directory'
  bool _isLoadingList = false;
  bool _isSubmitting = false;
  FeedbackData? _feedback;

  // Edit Mode
  int? _editingBrandId;

  // Form Fields
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isFeatured = false;

  // File Upload State
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  int? _selectedFileSize;
  String? _selectedFilePath;
  String? _existingFileUrl;

  // Directory State
  List<BrandResponse> _brands = [];
  String _searchQuery = '';
  String _filterMode = 'all'; // 'all', 'featured', 'standard'
  final TextEditingController _searchController = TextEditingController();

  // Live preview toggle
  bool _showLivePreview = false;

  @override
  void initState() {
    super.initState();
    _apiConfig.addListener(_onConfigChanged);
    _fetchBrands();
  }

  void _onConfigChanged() {
    if (mounted) {
      _fetchBrands();
    }
  }

  @override
  void dispose() {
    _apiConfig.removeListener(_onConfigChanged);
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchBrands() async {
    setState(() => _isLoadingList = true);
    try {
      final data = await _brandService.getAllBrands();
      if (mounted) {
        setState(() {
          _brands = data;
          _isLoadingList = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingList = false);
      }
    }
  }

  void _startEdit(BrandResponse brand) {
    setState(() {
      _editingBrandId = brand.id;
      _activeTab = 'register';
      _feedback = null;
      _nameController.text = brand.brandName;
      _isFeatured = brand.isFeatured;

      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedFileSize = null;
      _selectedFilePath = null;
      _existingFileUrl = brand.brandLogo != null && brand.brandLogo!.isNotEmpty
          ? _brandService.getFileUrl(brand.brandLogo)
          : null;
    });
  }

  void _resetForm() {
    setState(() {
      _editingBrandId = null;
      _nameController.clear();
      _isFeatured = false;
      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedFileSize = null;
      _selectedFilePath = null;
      _existingFileUrl = null;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _feedback = FeedbackData(
          type: 'error',
          title: 'Validation Error',
          message: 'Please provide a valid brand name (min 2 characters).',
        );
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedback = null;
    });

    final request = BrandRequest(
      brandName: _nameController.text.trim(),
      isFeatured: _isFeatured,
    );

    try {
      if (_editingBrandId != null) {
        final response = await _brandService.updateBrand(
          _editingBrandId!,
          request,
          fileBytes: _selectedFileBytes,
          fileName: _selectedFileName,
          filePath: _selectedFilePath,
        );
        setState(() {
          _isSubmitting = false;
          _feedback = FeedbackData(
            type: 'success',
            title: 'Brand Updated Successfully!',
            message: 'Brand "${response.brandName}" (ID #${response.id}) has been updated.',
          );
          _resetForm();
          _activeTab = 'directory';
        });
        _fetchBrands();
      } else {
        final response = await _brandService.createBrand(
          request,
          fileBytes: _selectedFileBytes,
          fileName: _selectedFileName,
          filePath: _selectedFilePath,
        );
        setState(() {
          _isSubmitting = false;
          _feedback = FeedbackData(
            type: 'success',
            title: 'Brand Registered Successfully!',
            message: 'Brand "${response.brandName}" has been created with ID #${response.id}.',
          );
          _resetForm();
          _activeTab = 'directory';
        });
        _fetchBrands();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _feedback = FeedbackData(
          type: 'error',
          title: _editingBrandId != null ? 'Update Failed' : 'Registration Failed',
          message: e.toString().replaceAll('Exception: ', ''),
        );
      });
    }
  }

  void _promptDelete(BrandResponse brand) {
    showDialog(
      context: context,
      builder: (_) => DeleteConfirmDialog(
        title: 'Delete Brand?',
        itemName: brand.brandName,
        itemId: brand.id,
        onConfirm: () async {
          await _brandService.deleteBrand(brand.id);
          if (mounted) {
            setState(() {
              _feedback = FeedbackData(
                type: 'success',
                title: 'Brand Deleted',
                message: 'Brand "${brand.brandName}" has been removed.',
              );
              if (_editingBrandId == brand.id) {
                _resetForm();
              }
            });
            _fetchBrands();
          }
        },
      ),
    );
  }

  List<BrandResponse> get _filteredBrands {
    final query = _searchQuery.toLowerCase().trim();
    return _brands.where((b) {
      final matchesQuery = query.isEmpty ||
          b.brandName.toLowerCase().contains(query) ||
          b.id.toString().contains(query);
      if (!matchesQuery) return false;

      if (_filterMode == 'featured') return b.isFeatured;
      if (_filterMode == 'standard') return !b.isFeatured;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Sub-Navigation Tabs Bar
          _buildSubNavTabs(),

          // Feedback Alert Toast
          if (_feedback != null)
            FeedbackToast(
              feedback: _feedback!,
              onClose: () => setState(() => _feedback = null),
            ),

          // Main View Content
          Expanded(
            child: _activeTab == 'register'
                ? _buildRegisterView()
                : _buildDirectoryView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubNavTabs() {
    return Container(
      color: AppTheme.bgSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Add Brand Tab
          Expanded(
            child: InkWell(
              onTap: () {
                if (_editingBrandId != null) {
                  _resetForm();
                }
                setState(() => _activeTab = 'register');
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeTab == 'register' && _editingBrandId == null
                      ? AppTheme.primaryLight
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _activeTab == 'register' && _editingBrandId == null
                        ? AppTheme.primary
                        : AppTheme.borderLight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_rounded,
                      size: 16,
                      color: _activeTab == 'register' && _editingBrandId == null
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Add Brand',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _activeTab == 'register' && _editingBrandId == null
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Edit Tab Pill (if in edit mode)
          if (_editingBrandId != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, size: 14, color: Color(0xFFB45309)),
                  const SizedBox(width: 4),
                  Text(
                    'Edit #$_editingBrandId',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: _resetForm,
                    child: const Icon(Icons.close, size: 14, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Directory Tab
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 'directory'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeTab == 'directory'
                      ? AppTheme.primaryLight
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _activeTab == 'directory'
                        ? AppTheme.primary
                        : AppTheme.borderLight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 16,
                      color: _activeTab == 'directory'
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Directory',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _activeTab == 'directory'
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
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
                        '${_brands.length}',
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
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: REGISTRATION / EDIT VIEW
  // ==========================================
  Widget _buildRegisterView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _editingBrandId != null
                    ? [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)]
                    : [AppTheme.primaryLight, const Color(0xFFF5F3FF)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _editingBrandId != null ? const Color(0xFFFDE68A) : const Color(0xFFC7D2FE),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _editingBrandId != null ? const Color(0xFFF59E0B) : AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _editingBrandId != null ? Icons.edit_note_rounded : Icons.verified_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editingBrandId != null ? 'Update Brand Record' : 'Brand Registration',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _editingBrandId != null
                            ? 'Modify brand identity, toggle featured promotion, or update logo.'
                            : 'Register a new brand into the centralized enterprise catalog.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Live Preview Toggle Button
          InkWell(
            onTap: () => setState(() => _showLivePreview = !_showLivePreview),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderMedium),
              ),
              child: Row(
                children: [
                  const Icon(Icons.remove_red_eye_rounded, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _showLivePreview ? 'Hide Brand Badge Preview' : 'Show Brand Badge Preview',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showLivePreview ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),

          if (_showLivePreview) ...[
            const SizedBox(height: 12),
            _buildLiveBrandPreviewCard(),
          ],

          const SizedBox(height: 16),

          // Form Sections
          Form(
            key: _formKey,
            child: Column(
              children: [
                // 01: Brand Identity
                _buildFormCard(
                  stepNum: '01',
                  title: 'Brand Identity',
                  subtitle: 'Official registered enterprise brand naming and promotion tier',
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Brand Name *',
                        hintText: 'e.g. Sony, Apple, Samsung, Logitech',
                        prefixIcon: Icon(Icons.branding_watermark_rounded, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 2) {
                          return 'Brand name is required (min 2 characters)';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Featured Brand Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isFeatured ? AppTheme.primaryLight : AppTheme.bgPage,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isFeatured ? AppTheme.primary : AppTheme.borderLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isFeatured ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: _isFeatured ? AppTheme.warning : AppTheme.textMuted,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Featured Brand Status',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Highlight this brand prominently in catalogs and directory',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isFeatured,
                            activeThumbColor: AppTheme.primary,
                            onChanged: (val) => setState(() => _isFeatured = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 02: Brand Logo
                _buildFormCard(
                  stepNum: '02',
                  title: 'Brand Logo & Asset',
                  subtitle: 'Upload brand mark icon or vector logo (JPEG, PNG, WEBP, SVG)',
                  children: [
                    FileUploadBox(
                      title: 'Drop brand logo image here',
                      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'svg'],
                      fileBytes: _selectedFileBytes,
                      fileName: _selectedFileName,
                      fileSize: _selectedFileSize,
                      existingFileUrl: _existingFileUrl,
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
                  ],
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : _resetForm,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_editingBrandId != null ? Icons.close : Icons.refresh_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text(_editingBrandId != null ? 'Cancel Edit' : 'Reset Form'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_editingBrandId != null ? Icons.check_circle_outline : Icons.verified_rounded, size: 18),
                                    const SizedBox(width: 6),
                                    Text(_editingBrandId != null ? 'Update Brand' : 'Register Brand'),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
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
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stepNum,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // Live Brand Preview Widget (matching Angular brand badge appearance)
  Widget _buildLiveBrandPreviewCard() {
    final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Brand Name';
    final initials = name.isNotEmpty
        ? (name.length > 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase())
        : 'BR';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.bgSubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                clipBehavior: Clip.antiAlias,
                child: _selectedFileBytes != null
                    ? Image.memory(_selectedFileBytes!, fit: BoxFit.cover)
                    : _existingFileUrl != null && _existingFileUrl!.isNotEmpty
                        ? Image.network(_existingFileUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => Center(child: Text(initials, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary))))
                        : Center(child: Text(initials, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primary))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (_isFeatured) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.warningBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 12, color: AppTheme.warning),
                                const SizedBox(width: 2),
                                Text(
                                  'Featured',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Official Manufacturer Brand',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SPRING BOOT ENTITY: Brand',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
              ),
              StatusBadgeChip(status: _isFeatured ? 'FEATURED' : 'ACTIVE', isMini: true),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: DIRECTORY VIEW
  // ==========================================
  Widget _buildDirectoryView() {
    return Column(
      children: [
        // Directory Header Bar with Search & Filter
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.bgSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Brands Directory',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Explore, filter, edit, and delete manufacturer brands.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchBrands,
                    icon: _isLoadingList
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded, color: AppTheme.primary),
                    tooltip: 'Refresh Brands',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search brands by name or ID...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 10),

              // Filter Mode Selector (All, Featured, Standard)
              Row(
                children: [
                  _buildFilterChip('All Brands', 'all', _brands.length),
                  const SizedBox(width: 8),
                  _buildFilterChip('Featured', 'featured', _brands.where((b) => b.isFeatured).length),
                  const SizedBox(width: 8),
                  _buildFilterChip('Standard', 'standard', _brands.where((b) => !b.isFeatured).length),
                ],
              ),
            ],
          ),
        ),

        // List of Brands
        Expanded(
          child: _isLoadingList
              ? const Center(child: CircularProgressIndicator())
              : _filteredBrands.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
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
                              child: const Icon(Icons.verified_outlined, color: AppTheme.primary, size: 32),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Brands Found',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No records match your filters or none have been added yet.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                _resetForm();
                                setState(() => _activeTab = 'register');
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Register New Brand'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchBrands,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredBrands.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final brand = _filteredBrands[index];
                          return _buildBrandCardItem(brand);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String mode, int count) {
    final isSelected = _filterMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filterMode = mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryLight : AppTheme.bgPage,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.borderLight,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.bgSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandCardItem(BrandResponse brand) {
    return Card(
      child: InkWell(
        onTap: () => _showBrandDetailModal(brand),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Logo
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.bgSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                clipBehavior: Clip.antiAlias,
                child: brand.brandLogo != null && brand.brandLogo!.isNotEmpty
                    ? Image.network(
                        _brandService.getFileUrl(brand.brandLogo),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: Text(
                            brand.initials,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          brand.initials,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 14),

              // Brand Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            brand.brandName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (brand.isFeatured) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded, size: 16, color: AppTheme.warning),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ID: #${brand.id}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0369A1)),
                    onPressed: () => _startEdit(brand),
                    tooltip: 'Edit Brand',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                    onPressed: () => _promptDelete(brand),
                    tooltip: 'Delete Brand',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBrandDetailModal(BrandResponse brand) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BRAND DETAIL • ID #${brand.id}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          brand.brandName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (brand.isFeatured)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.warningBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: AppTheme.warning),
                          const SizedBox(width: 4),
                          Text('Featured Brand', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFB45309))),
                        ],
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (brand.brandLogo != null && brand.brandLogo!.isNotEmpty)
                Center(
                  child: Container(
                    height: 140,
                    width: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      _brandService.getFileUrl(brand.brandLogo),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image, size: 40)),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _promptDelete(brand);
                    },
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                    label: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _startEdit(brand);
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Brand'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
