import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ocr_model.dart';
import '../services/ocr_service.dart';
import '../services/media_picker_helper.dart';
import '../theme/app_theme.dart';

class BusinessCardOcrDialogResult {
  final BusinessCardScanResult result;
  final bool attachCardToForm;
  final Uint8List imageBytes;
  final String fileName;
  final int fileSize;
  final String? filePath;

  BusinessCardOcrDialogResult({
    required this.result,
    required this.attachCardToForm,
    required this.imageBytes,
    required this.fileName,
    required this.fileSize,
    this.filePath,
  });
}

class BusinessCardOcrDialog extends StatefulWidget {
  final Uint8List initialImageBytes;
  final String initialFileName;
  final int initialFileSize;
  final String? initialFilePath;
  final void Function(String title, String message)? onUnrecognized;

  const BusinessCardOcrDialog({
    super.key,
    required this.initialImageBytes,
    required this.initialFileName,
    required this.initialFileSize,
    this.initialFilePath,
    this.onUnrecognized,
  });

  static Future<BusinessCardOcrDialogResult?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    required String fileName,
    required int fileSize,
    String? filePath,
    void Function(String title, String message)? onUnrecognized,
  }) {
    return showDialog<BusinessCardOcrDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BusinessCardOcrDialog(
        initialImageBytes: imageBytes,
        initialFileName: fileName,
        initialFileSize: fileSize,
        initialFilePath: filePath,
        onUnrecognized: onUnrecognized,
      ),
    );
  }

  @override
  State<BusinessCardOcrDialog> createState() => _BusinessCardOcrDialogState();
}

class _BusinessCardOcrDialogState extends State<BusinessCardOcrDialog>
    with SingleTickerProviderStateMixin {
  final OcrService _ocrService = OcrService();

  late Uint8List _fileBytes;
  Uint8List? _previewImageBytes;
  late String _fileName;
  late int _fileSize;
  String? _filePath;

  bool get _isPdf => _ocrService.isPdfFile(_fileName, _fileBytes);

  bool _isScanning = true;
  String? _errorMessage;
  BusinessCardScanResult? _scanResult;
  bool _attachCard = true;

  late AnimationController _laserAnimCtrl;

  // Form controllers
  final _companyNameCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _landlineCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fileBytes = widget.initialImageBytes;
    _fileName = widget.initialFileName;
    _fileSize = widget.initialFileSize;
    _filePath = widget.initialFilePath;
    if (!_isPdf) {
      _previewImageBytes = _fileBytes;
    }

    _laserAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _startOcrProcess();
  }

  @override
  void dispose() {
    _laserAnimCtrl.dispose();
    _companyNameCtrl.dispose();
    _contactNameCtrl.dispose();
    _designationCtrl.dispose();
    _mobileCtrl.dispose();
    _landlineCtrl.dispose();
    _emailCtrl.dispose();
    _contactEmailCtrl.dispose();
    _websiteCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _startOcrProcess() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      // If it's a PDF, kick off raster preview render immediately in parallel
      // so the preview appears as fast as possible while parsing runs:
      if (_isPdf && _previewImageBytes == null) {
        _ocrService
            .renderPdfPageToImage(_fileBytes, pageNumber: 1)
            .then((res) {
              if (mounted && _previewImageBytes == null) {
                setState(() {
                  _previewImageBytes = res.imageBytes;
                });
              }
            })
            .catchError((err) {
              debugPrint('Parallel PDF preview error: $err');
            });
      }

      final outcome = await _ocrService.scanCard(
        bytes: _fileBytes,
        fileName: _fileName,
      );
      if (!mounted) return;

      setState(() {
        _previewImageBytes = outcome.previewImageBytes;
        final res = outcome.result;
        _scanResult = res;
        _isScanning = false;

        _companyNameCtrl.text = res.companyName ?? '';
        _contactNameCtrl.text = res.contactName ?? '';
        _designationCtrl.text = res.contactDesignation ?? '';
        _mobileCtrl.text = res.contactMobileNumber ?? '';
        _landlineCtrl.text = res.landline ?? '';
        _emailCtrl.text = res.email ?? '';
        _contactEmailCtrl.text = res.contactEmail ?? res.email ?? '';
        _websiteCtrl.text = res.website ?? '';
        _addressCtrl.text = res.address ?? '';
        _cityCtrl.text = res.city ?? '';
        _countryCtrl.text = res.country ?? 'United States';
      });

      if ((outcome.result.confidenceScore == 0 ||
              outcome.result.isLowConfidence) &&
          widget.onUnrecognized != null) {
        widget.onUnrecognized!(
          _isPdf ? 'Unrecognized PDF Document' : 'Unrecognized Image',
          'No contact or corporate details could be recognized on this file. Please review or try a clearer business card.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  Future<void> _pickAnotherCard() async {
    final picked = await MediaPickerHelper.showMediaPickerSheet(
      context,
      title: 'Select Card Image or PDF',
      subtitle: 'Take a photo, choose an image, or select a PDF document',
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      allowDocuments: true,
    );

    if (picked != null) {
      setState(() {
        _fileBytes = picked.bytes;
        _fileName = picked.name;
        _fileSize = picked.size;
        _filePath = picked.path;
        if (!_ocrService.isPdfFile(picked.name, picked.bytes)) {
          _previewImageBytes = picked.bytes;
        } else {
          _previewImageBytes = null;
        }
      });

      _startOcrProcess();
    }
  }

  bool get _hasAnyFieldFilled {
    return _companyNameCtrl.text.trim().isNotEmpty ||
        _contactNameCtrl.text.trim().isNotEmpty ||
        _designationCtrl.text.trim().isNotEmpty ||
        _mobileCtrl.text.trim().isNotEmpty ||
        _landlineCtrl.text.trim().isNotEmpty ||
        _emailCtrl.text.trim().isNotEmpty ||
        _contactEmailCtrl.text.trim().isNotEmpty ||
        _websiteCtrl.text.trim().isNotEmpty ||
        _addressCtrl.text.trim().isNotEmpty ||
        _cityCtrl.text.trim().isNotEmpty ||
        _countryCtrl.text.trim().isNotEmpty;
  }

  void _applyResult() {
    final updatedResult = BusinessCardScanResult(
      companyName: _companyNameCtrl.text.trim().isEmpty
          ? null
          : _companyNameCtrl.text.trim(),
      contactName: _contactNameCtrl.text.trim().isEmpty
          ? null
          : _contactNameCtrl.text.trim(),
      contactDesignation: _designationCtrl.text.trim().isEmpty
          ? null
          : _designationCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      contactEmail: _contactEmailCtrl.text.trim().isEmpty
          ? null
          : _contactEmailCtrl.text.trim(),
      contactMobileNumber: _mobileCtrl.text.trim().isEmpty
          ? null
          : _mobileCtrl.text.trim(),
      landline: _landlineCtrl.text.trim().isEmpty
          ? null
          : _landlineCtrl.text.trim(),
      website: _websiteCtrl.text.trim().isEmpty
          ? null
          : _websiteCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      country: _countryCtrl.text.trim().isEmpty
          ? null
          : _countryCtrl.text.trim(),
      confidenceScore: _scanResult?.confidenceScore ?? 50,
      rawText: _scanResult?.rawText ?? '',
      lines: _scanResult?.lines ?? [],
    );

    Navigator.of(context).pop(
      BusinessCardOcrDialogResult(
        result: updatedResult,
        attachCardToForm: _attachCard,
        imageBytes: _fileBytes,
        fileName: _fileName,
        fileSize: _fileSize,
        filePath: _filePath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 850;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 10,
        vertical: isDesktop ? 40 : 12,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 980,
          maxHeight: isDesktop ? 780 : screenSize.height * 0.94,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isDesktop),
            Flexible(
              child: isDesktop ? _buildDesktopBody() : _buildMobileBody(),
            ),
            _buildFooter(isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    final score = _scanResult?.confidenceScore;

    if (isDesktop) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.credit_card_rounded,
                color: Color(0xFF4F46E5),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isScanning
                        ? 'Scanning Visiting Card...'
                        : 'Review Visiting Card Details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isScanning
                        ? 'Reading company and contact details from card...'
                        : 'Confirm or refine the recognized details below before applying to your form',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isScanning && score != null) ...[
              _buildConfidenceBadge(score, true),
              const SizedBox(width: 12),
            ],
            IconButton(
              onPressed: _isScanning ? null : () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFF64748B),
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Close',
            ),
          ],
        ),
      );
    }

    // Mobile Header Layout: Clean 2-row layout where Title, Subtitle, and Badge are fully displayed without cut-off
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Card Icon + Full Title ("Review Visiting Card Details") + Close Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.credit_card_rounded,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isScanning
                      ? 'Scanning Visiting Card...'
                      : 'Review Visiting Card Details',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.2,
                  ),
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _isScanning
                    ? null
                    : () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Row 2: Descriptive Subtitle on left + Confidence Badge on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _isScanning
                      ? 'Reading company and contact details...'
                      : 'Confirm or refine recognized details below before applying',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ),
              if (!_isScanning && score != null) ...[
                const SizedBox(width: 8),
                _buildConfidenceBadge(score, false),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(int score, bool isDesktop) {
    Color bg;
    Color text;
    Color border;

    if (score >= 70) {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF15803D);
      border = const Color(0xFF86EFAC);
    } else if (score >= 40) {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFB45309);
      border = const Color(0xFFFDE68A);
    } else {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFFB91C1C);
      border = const Color(0xFFFCA5A5);
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 10 : 8,
        vertical: isDesktop ? 4 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: isDesktop ? 13 : 11, color: text),
          const SizedBox(width: 4),
          Text(
            '$score% Confidence',
            style: GoogleFonts.inter(
              fontSize: isDesktop ? 11.5 : 10,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Image Preview
          SizedBox(width: 340, child: _buildPreviewPane(isCompact: false)),
          const SizedBox(width: 20),
          // Right Column: Extracted Fields
          Expanded(child: _buildFieldsCard(isDesktop: true)),
        ],
      ),
    );
  }

  Widget _buildMobileBody() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          children: [
            _buildPreviewPane(isCompact: true),
            const SizedBox(height: 10),
            _buildFieldsCard(isDesktop: false),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPane({required bool isCompact}) {
    return Column(
      mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Container(
          height: isCompact ? 135 : 230,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_previewImageBytes != null)
                Image.memory(_previewImageBytes!, fit: BoxFit.contain)
              else if (_isPdf)
                Container(
                  color: const Color(0xFF0F172A),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Color(0xFFEF4444),
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rendering PDF Page 1...',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  color: const Color(0xFF0F172A),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_outlined,
                    color: Colors.white54,
                    size: 40,
                  ),
                ),

              // PDF Badge matching Angular
              if (_isPdf)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PDF Page 1',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_isScanning) ...[
                // Laser scan line animation
                AnimatedBuilder(
                  animation: _laserAnimCtrl,
                  builder: (context, child) {
                    return Positioned(
                      left: 0,
                      right: 0,
                      top: _laserAnimCtrl.value * (isCompact ? 125 : 220),
                      child: Container(
                        height: 3,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFF38BDF8),
                              Color(0xFFEC4899),
                              Color(0xFF38BDF8),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(color: Color(0xFF38BDF8), blurRadius: 10),
                            BoxShadow(color: Color(0xFFEC4899), blurRadius: 6),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  color: Colors.black.withValues(alpha: 0.40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Recognizing Text...',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isScanning ? null : _pickAnotherCard,
              icon: const Icon(
                Icons.sync_rounded,
                size: 13,
                color: Color(0xFF334155),
              ),
              label: Text(
                _previewImageBytes != null
                    ? 'Change Card / PDF'
                    : 'Select Card / PDF',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _fileName,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFieldsCard({required bool isDesktop}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isDesktop ? 18 : 12),
      child: _buildFieldsContent(isDesktop),
    );
  }

  Widget _buildFieldsContent(bool isDesktop) {
    if (_isScanning) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Column(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Extracting company, contacts, phone numbers, and address...',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppTheme.error,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Scanning Failed',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.error,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _startOcrProcess,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isLowConfidence =
        (_scanResult?.confidenceScore ?? 0) < 40 ||
        (_scanResult?.isLowConfidence ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Low confidence warning box (Matching Screenshot 2 from Angular)
        if (isLowConfidence) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD97706),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Low Confidence / Unrecognized Card',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Could not detect standard business card contact entities (contact person, phone, or email). You can fill in fields manually or try uploading a clearer, higher-contrast image.',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: const Color(0xFFB45309),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Info notice banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Color(0xFF4F46E5),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Fields detected by OCR. You can refine any value below before applying:',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Fields Layout: 2-column on desktop, spacious 1-column on mobile to prevent overflow!
        if (isDesktop) ...[
          // Desktop 2-column layout
          _buildFieldInput(
            label: 'COMPANY NAME',
            controller: _companyNameCtrl,
            icon: Icons.apartment_rounded,
            hint: 'e.g. Apex Global Corp',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFieldInput(
                  label: 'CONTACT NAME',
                  controller: _contactNameCtrl,
                  icon: Icons.person_rounded,
                  hint: 'e.g. Elena Rostova',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFieldInput(
                  label: 'DESIGNATION / TITLE',
                  controller: _designationCtrl,
                  icon: Icons.badge_outlined,
                  hint: 'e.g. Managing Director',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFieldInput(
                  label: 'MOBILE NUMBER',
                  controller: _mobileCtrl,
                  icon: Icons.phone_android_rounded,
                  hint: 'e.g. +1 917 433-2890',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFieldInput(
                  label: 'LANDLINE / OFFICE',
                  controller: _landlineCtrl,
                  icon: Icons.phone_rounded,
                  hint: 'e.g. +1 212 650-8910',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFieldInput(
                  label: 'EMAIL ADDRESS',
                  controller: _emailCtrl,
                  icon: Icons.email_rounded,
                  hint: 'e.g. info@apexgroup.com',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFieldInput(
                  label: 'DIRECT CONTACT EMAIL',
                  controller: _contactEmailCtrl,
                  icon: Icons.alternate_email_rounded,
                  hint: 'e.g. elena@apexgroup.com',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildFieldInput(
            label: 'WEBSITE URL',
            controller: _websiteCtrl,
            icon: Icons.language_rounded,
            hint: 'e.g. https://www.apexgroup.com',
          ),
          const SizedBox(height: 10),
          _buildFieldInput(
            label: 'ADDRESS',
            controller: _addressCtrl,
            icon: Icons.location_on_rounded,
            hint: 'e.g. 1250 Avenue of the Americas, 18th Floor',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFieldInput(
                  label: 'CITY',
                  controller: _cityCtrl,
                  icon: Icons.location_city_rounded,
                  hint: 'e.g. New York',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFieldInput(
                  label: 'COUNTRY',
                  controller: _countryCtrl,
                  icon: Icons.flag_rounded,
                  hint: 'e.g. United States',
                ),
              ),
            ],
          ),
        ] else ...[
          // Mobile Single Column: Clean, spacious, perfectly sized, zero overflows!
          _buildFieldInput(
            label: 'COMPANY NAME',
            controller: _companyNameCtrl,
            icon: Icons.apartment_rounded,
            hint: 'e.g. Apex Global Corp',
          ),
          const SizedBox(height: 9),
          _buildFieldInput(
            label: 'CONTACT NAME',
            controller: _contactNameCtrl,
            icon: Icons.person_rounded,
            hint: 'e.g. Elena Rostova',
          ),
          const SizedBox(height: 9),
          _buildFieldInput(
            label: 'DESIGNATION / TITLE',
            controller: _designationCtrl,
            icon: Icons.badge_outlined,
            hint: 'e.g. Managing Director',
          ),
          const SizedBox(height: 9),
          _buildFieldInput(
            label: 'MOBILE NUMBER',
            controller: _mobileCtrl,
            icon: Icons.phone_android_rounded,
            hint: 'e.g. +1 917 433-2890',
          ),
          const SizedBox(height: 9),
          _buildFieldInput(
            label: 'LANDLINE / OFFICE',
            controller: _landlineCtrl,
            icon: Icons.phone_rounded,
            hint: 'e.g. +1 212 650-8910',
          ),
          const SizedBox(height: 9),
          _buildFieldInput(
            label: 'EMAIL ADDRESS',
            controller: _emailCtrl,
            icon: Icons.email_rounded,
            hint: 'e.g. info@apexgroup.com',
          ),
          const SizedBox(height: 9),
          _buildFieldInput(
            label: 'DIRECT CONTACT EMAIL',
            controller: _contactEmailCtrl,
            icon: Icons.alternate_email_rounded,
            hint: 'e.g. elena@apexgroup.com',
          ),
          const SizedBox(height: 9),
          _buildFieldInput(
            label: 'WEBSITE URL',
            controller: _websiteCtrl,
            icon: Icons.language_rounded,
            hint: 'e.g. https://www.apexgroup.com',
          ),
          const SizedBox(height: 9),
          _buildFieldInput(
            label: 'ADDRESS',
            controller: _addressCtrl,
            icon: Icons.location_on_rounded,
            hint: 'e.g. 1250 Avenue of the Americas, 18th Floor',
          ),
          const SizedBox(height: 9),
          _buildFieldInput(
            label: 'CITY',
            controller: _cityCtrl,
            icon: Icons.location_city_rounded,
            hint: 'e.g. New York',
          ),
          const SizedBox(height: 9),
          _buildFieldInput(
            label: 'COUNTRY',
            controller: _countryCtrl,
            icon: Icons.flag_rounded,
            hint: 'e.g. United States',
          ),
        ],

        const SizedBox(height: 12),

        // Auto-Attach Checkbox
        InkWell(
          onTap: () {
            setState(() {
              _attachCard = !_attachCard;
            });
          },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _attachCard,
                    activeColor: const Color(0xFF4F46E5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) {
                      setState(() {
                        _attachCard = val ?? true;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isPdf
                        ? 'Attach this card PDF to Section 07 (Visiting Cards) on form apply'
                        : 'Attach this card image to Section 07 (Visiting Cards) on form apply',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: const Color(0xFF6366F1)),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 9.5,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF6366F1),
                width: 1.5,
              ),
            ),
            fillColor: const Color(0xFFF8FAFC),
            filled: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 22 : 12,
        vertical: isDesktop ? 14 : 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          if (isDesktop) const Spacer(),
          Expanded(
            flex: isDesktop ? 0 : 1,
            child: OutlinedButton(
              onPressed: _isScanning ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : 12,
                  vertical: 11,
                ),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: isDesktop ? 0 : 2,
            child: ElevatedButton.icon(
              onPressed: (_isScanning || !_hasAnyFieldFilled)
                  ? null
                  : _applyResult,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
              label: Text(
                'Apply Details to Form',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : 12,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
