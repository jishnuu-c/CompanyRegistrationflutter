import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  final ApiConfig _apiConfig = ApiConfig();
  late TextEditingController _hostController;
  bool _isTesting = false;
  String? _testResult;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: _apiConfig.host);
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    _apiConfig.setHost(_hostController.text.trim());
    final success = await _apiConfig.checkConnection();

    if (mounted) {
      setState(() {
        _isTesting = false;
        _isSuccess = success;
        _testResult = success
            ? 'Connected successfully to Spring Boot backend!'
            : 'Connection failed: ${_apiConfig.lastError.isNotEmpty ? _apiConfig.lastError : 'Host unreachable.'}';
      });
    }
  }

  void _applyQuickPreset(String url) {
    _hostController.text = url;
    _testConnection();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.bgSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dns_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backend Server Config',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Spring Boot REST API endpoint',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Spring Boot Host URL',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _hostController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.link_rounded, size: 20),
                hintText: 'e.g. http://localhost:8080',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Test Connection',
                  onPressed: _isTesting ? null : _testConnection,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Quick Presets
            Text(
              'Quick Presets:',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildPresetChip('Android Emulator (10.0.2.2)', 'http://10.0.2.2:8080'),
                _buildPresetChip('Localhost (8080)', 'http://localhost:8080'),
              ],
            ),

            if (_testResult != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isSuccess ? AppTheme.successBg : AppTheme.errorBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _isSuccess ? AppTheme.successBorder : AppTheme.errorBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                      size: 18,
                      color: _isSuccess ? AppTheme.success : AppTheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _isSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    _apiConfig.setHost(_hostController.text.trim());
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save Host'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String url) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 11)),
      onPressed: () => _applyQuickPreset(url),
      backgroundColor: AppTheme.bgSubtle,
      side: const BorderSide(color: AppTheme.borderLight),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }
}
