import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class DeleteConfirmDialog extends StatefulWidget {
  final String title;
  final String itemName;
  final int itemId;
  final Future<void> Function() onConfirm;

  const DeleteConfirmDialog({
    super.key,
    required this.title,
    required this.itemName,
    required this.itemId,
    required this.onConfirm,
  });

  @override
  State<DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<DeleteConfirmDialog> {
  bool _isDeleting = false;
  String? _errorMessage;

  Future<void> _handleDelete() async {
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.bgSurface,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.errorBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.errorBorder, width: 1.5),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.error,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              widget.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Description
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
                children: [
                  const TextSpan(text: 'Are you sure you want to permanently delete '),
                  TextSpan(
                    text: '"${widget.itemName}"',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  TextSpan(text: ' (ID #${widget.itemId})? This action cannot be undone.'),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.errorBorder),
                ),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isDeleting ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isDeleting ? null : _handleDelete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.delete_forever_rounded, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                'Yes, Delete',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
