import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_config.dart';
import '../services/media_picker_helper.dart';

class FileUploadBox extends StatelessWidget {
  final String title;
  final String hint;
  final List<String> allowedExtensions;
  final Uint8List? fileBytes;
  final String? fileName;
  final int? fileSize;
  final String? existingFileUrl;
  final Function(Uint8List bytes, String name, int size, String? path)
  onFileSelected;
  final VoidCallback onFileRemoved;
  final VoidCallback? onOcrScan;

  const FileUploadBox({
    super.key,
    required this.title,
    this.hint = 'Drop your file here or tap to browse',
    this.allowedExtensions = const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf'],
    this.fileBytes,
    this.fileName,
    this.fileSize,
    this.existingFileUrl,
    required this.onFileSelected,
    required this.onFileRemoved,
    this.onOcrScan,
  });

  bool get hasSelectedFile => fileBytes != null;
  bool get hasExistingFile =>
      existingFileUrl != null && existingFileUrl!.isNotEmpty;
  bool get hasFile => hasSelectedFile || hasExistingFile;

  bool get isPdf {
    if (fileName != null && fileName!.toLowerCase().endsWith('.pdf'))
      return true;
    if (existingFileUrl != null &&
        existingFileUrl!.toLowerCase().endsWith('.pdf'))
      return true;
    return false;
  }

  Future<void> _pickFile(BuildContext context) async {
    final picked = await MediaPickerHelper.showMediaPickerSheet(
      context,
      title: title,
      subtitle: hint,
      allowedExtensions: allowedExtensions,
      allowDocuments:
          allowedExtensions.contains('pdf') || allowedExtensions.contains('*'),
    );

    if (picked != null) {
      onFileSelected(picked.bytes, picked.name, picked.size, picked.path);
    }
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _pickFile(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: hasFile ? AppTheme.bgSurface : AppTheme.bgPage,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasFile ? AppTheme.primaryLight : AppTheme.borderMedium,
                width: hasFile ? 1.5 : 1,
              ),
              boxShadow: hasFile ? AppTheme.shadowSm : null,
            ),
            child: hasFile
                ? _buildFilePreview(context, isMobile)
                : _buildEmptyState(context, isMobile),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isMobile) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: isMobile ? 44 : 52,
          height: isMobile ? 44 : 52,
          decoration: const BoxDecoration(
            color: AppTheme.primaryLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.cloud_upload_rounded,
            color: AppTheme.primary,
            size: isMobile ? 24 : 28,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: isMobile ? 13 : 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: isMobile ? 11.5 : 12,
              color: AppTheme.textMuted,
            ),
            children: const [
              TextSpan(text: 'or '),
              TextSpan(
                text: 'browse files',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
              TextSpan(text: ' from your device'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            ...allowedExtensions
                .take(4)
                .map(
                  (ext) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSubtle,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Text(
                      ext.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.bgSubtle,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Max 20MB',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (onOcrScan != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOcrScan,
            icon: const Icon(
              Icons.document_scanner_rounded,
              size: 15,
              color: Color(0xFF4F46E5),
            ),
            label: Text(
              'Scan Card with OCR to Auto-Fill Form',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4F46E5),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: const BorderSide(color: Color(0xFF818CF8), width: 1.2),
              backgroundColor: const Color(0xFFEEF2FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilePreview(BuildContext context, bool isMobile) {
    final resolvedUrl = ApiConfig().getFileUrl(existingFileUrl);

    return Row(
      children: [
        // Thumbnail or PDF icon
        Container(
          width: isMobile ? 50 : 58,
          height: isMobile ? 50 : 58,
          decoration: BoxDecoration(
            color: AppTheme.bgSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderLight),
          ),
          clipBehavior: Clip.antiAlias,
          child: isPdf
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppTheme.error,
                      size: isMobile ? 24 : 28,
                    ),
                    Text(
                      'PDF',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.error,
                      ),
                    ),
                  ],
                )
              : fileBytes != null
              ? Image.memory(fileBytes!, fit: BoxFit.cover)
              : resolvedUrl.isNotEmpty
              ? Image.network(
                  resolvedUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.image_outlined,
                    color: AppTheme.textMuted,
                  ),
                )
              : const Icon(Icons.image_outlined, color: AppTheme.textMuted),
        ),
        SizedBox(width: isMobile ? 10 : 12),

        // File Information
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fileName ??
                    (existingFileUrl != null
                        ? existingFileUrl!.split('/').last
                        : 'Attached File'),
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 12.5 : 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              if (fileSize != null)
                Text(
                  _formatSize(fileSize),
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 10.5 : 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasSelectedFile
                        ? Icons.check_circle_rounded
                        : Icons.cloud_done_rounded,
                    size: 13,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      hasSelectedFile
                          ? 'Ready to upload'
                          : 'Currently saved on file',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 10.5 : 11,
                        fontWeight: FontWeight.w600,
                        color: hasSelectedFile
                            ? AppTheme.success
                            : const Color(0xFF0369A1),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // OCR Scan action on existing file (image or PDF)
        if (onOcrScan != null)
          IconButton(
            onPressed: onOcrScan,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: const EdgeInsets.all(5),
            icon: const Icon(
              Icons.document_scanner_rounded,
              color: Color(0xFF6366F1),
              size: 19,
            ),
            tooltip: isPdf
                ? 'Auto-fill form by scanning this PDF document'
                : 'Auto-fill form using this visiting card',
          ),

        // Remove button
        IconButton(
          onPressed: onFileRemoved,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          padding: const EdgeInsets.all(5),
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppTheme.error,
            size: 20,
          ),
          tooltip: 'Remove file',
        ),
      ],
    );
  }
}
