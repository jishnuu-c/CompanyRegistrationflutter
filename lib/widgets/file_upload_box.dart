import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class FileUploadBox extends StatelessWidget {
  final String title;
  final String hint;
  final List<String> allowedExtensions;
  final Uint8List? fileBytes;
  final String? fileName;
  final int? fileSize;
  final String? existingFileUrl;
  final Function(Uint8List bytes, String name, int size, String? path) onFileSelected;
  final VoidCallback onFileRemoved;

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
  });

  bool get hasSelectedFile => fileBytes != null;
  bool get hasExistingFile => existingFileUrl != null && existingFileUrl!.isNotEmpty;
  bool get hasFile => hasSelectedFile || hasExistingFile;

  bool get isPdf {
    if (fileName != null && fileName!.toLowerCase().endsWith('.pdf')) return true;
    if (existingFileUrl != null && existingFileUrl!.toLowerCase().endsWith('.pdf')) return true;
    return false;
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.xFile.readAsBytes();
        final size = await file.xFile.length();
        onFileSelected(bytes, file.name, size, file.path);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File selection error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _pickFile(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasFile ? AppTheme.bgSurface : AppTheme.bgPage,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasFile ? AppTheme.primaryLight : AppTheme.borderMedium,
                width: hasFile ? 1.5 : 1,
              ),
              boxShadow: hasFile ? AppTheme.shadowSm : null,
            ),
            child: hasFile ? _buildFilePreview(context) : _buildEmptyState(context),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: AppTheme.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.cloud_upload_rounded,
            color: AppTheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
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
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            ...allowedExtensions.take(4).map(
                  (ext) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      ],
    );
  }

  Widget _buildFilePreview(BuildContext context) {
    return Row(
      children: [
        // Thumbnail or PDF icon
        Container(
          width: 60,
          height: 60,
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
                    const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.error, size: 28),
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
                  : existingFileUrl != null && existingFileUrl!.isNotEmpty
                      ? Image.network(
                          existingFileUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, color: AppTheme.textMuted),
                        )
                      : const Icon(Icons.image_outlined, color: AppTheme.textMuted),
        ),
        const SizedBox(width: 12),

        // File Information
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName ?? 'Attached File',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              if (fileSize != null)
                Text(
                  _formatSize(fileSize),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    hasSelectedFile ? Icons.check_circle : Icons.cloud_done,
                    size: 13,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasSelectedFile ? 'Ready to upload' : 'Currently saved on file',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasSelectedFile ? AppTheme.success : const Color(0xFF0369A1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Remove button
        IconButton(
          onPressed: onFileRemoved,
          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
          tooltip: 'Remove file',
        ),
      ],
    );
  }
}
