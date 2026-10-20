import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

class PickedMediaResult {
  final Uint8List bytes;
  final String name;
  final int size;
  final String? path;

  PickedMediaResult({
    required this.bytes,
    required this.name,
    required this.size,
    this.path,
  });
}

enum MediaPickSource { camera, gallery, file, drive }

class MediaPickerHelper {
  static final ImagePicker _imagePicker = ImagePicker();

  /// Shows the media selection bottom sheet matching Angular/Mobile native options
  static Future<PickedMediaResult?> showMediaPickerSheet(
    BuildContext context, {
    String title = 'Upload Visiting Card',
    String subtitle = 'Choose how you want to upload or capture your image',
    List<String> allowedExtensions = const [
      'jpg',
      'jpeg',
      'png',
      'webp',
      'pdf',
    ],
    bool allowDocuments = true,
  }) async {
    final MediaPickSource? source = await showModalBottomSheet<MediaPickSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MediaSourceBottomSheet(
        title: title,
        subtitle: subtitle,
        allowDocuments: allowDocuments,
      ),
    );

    if (source == null || !context.mounted) return null;

    return await pickMedia(
      context,
      source: source,
      allowedExtensions: allowedExtensions,
    );
  }

  /// Picks media directly given a source
  static Future<PickedMediaResult?> pickMedia(
    BuildContext? context, {
    required MediaPickSource source,
    List<String> allowedExtensions = const [
      'jpg',
      'jpeg',
      'png',
      'webp',
      'pdf',
    ],
  }) async {
    try {
      switch (source) {
        case MediaPickSource.camera:
          final XFile? photo = await _imagePicker.pickImage(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.rear,
            imageQuality: 92,
          );
          if (photo == null) return null;
          final bytes = await photo.readAsBytes();
          final size = await photo.length();
          final name = photo.name.isNotEmpty
              ? photo.name
              : 'card_camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
          return PickedMediaResult(
            bytes: bytes,
            name: name,
            size: size,
            path: photo.path,
          );

        case MediaPickSource.gallery:
          final XFile? image = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 95,
          );
          if (image == null) return null;
          final bytes = await image.readAsBytes();
          final size = await image.length();
          final name = image.name.isNotEmpty
              ? image.name
              : 'card_gallery_${DateTime.now().millisecondsSinceEpoch}.jpg';
          return PickedMediaResult(
            bytes: bytes,
            name: name,
            size: size,
            path: image.path,
          );

        case MediaPickSource.file:
        case MediaPickSource.drive:
          final result = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: allowedExtensions,
          );
          if (result.isEmpty) return null;
          final file = result.first;
          final bytes = await file.xFile.readAsBytes();
          final size = await file.xFile.length();
          return PickedMediaResult(
            bytes: bytes,
            name: file.name,
            size: size,
            path: file.path,
          );
      }
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error selecting photo: ${e.toString().replaceAll('Exception:', '').trim()}',
                    style: GoogleFonts.inter(fontSize: 12.5),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return null;
    }
  }
}

class _MediaSourceBottomSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool allowDocuments;

  const _MediaSourceBottomSheet({
    required this.title,
    required this.subtitle,
    required this.allowDocuments,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sheet Title & Description
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_rounded,
                    color: Colors.white,
                    size: 22,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Option 1: Take Photo (Camera)
            _buildOptionTile(
              context: context,
              source: MediaPickSource.camera,
              icon: Icons.camera_alt_rounded,
              iconColor: const Color(0xFF4F46E5),
              iconBgColor: const Color(0xFFEEF2FF),
              title: 'Take photo',
              subtitle:
                  'Capture a visiting card directly using your device camera',
            ),
            const SizedBox(height: 10),

            // Option 2: Photo Library (Gallery)
            _buildOptionTile(
              context: context,
              source: MediaPickSource.gallery,
              icon: Icons.photo_library_rounded,
              iconColor: const Color(0xFF059669),
              iconBgColor: const Color(0xFFECFDF5),
              title: 'Photo library',
              subtitle: 'Select an existing image from your gallery',
            ),
            const SizedBox(height: 10),

            // Option 3: Choose File (Storage)
            if (allowDocuments) ...[
              _buildOptionTile(
                context: context,
                source: MediaPickSource.file,
                icon: Icons.folder_open_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBgColor: const Color(0xFFEFF6FF),
                title: 'Choose file',
                subtitle: 'Browse phone storage, downloads, or PDF files',
              ),
              const SizedBox(height: 10),

              // Option 4: Google Drive / Cloud
              _buildOptionTile(
                context: context,
                source: MediaPickSource.drive,
                icon: Icons.cloud_outlined,
                iconColor: const Color(0xFFD97706),
                iconBgColor: const Color(0xFFFFFBEB),
                title: 'Google Drive / Cloud',
                subtitle: 'Pick documents or cards saved in cloud storage',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required MediaPickSource source,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(source),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
