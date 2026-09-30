import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  final ApiService _apiService = ApiService();
  late TextEditingController _urlController;
  bool _testing = false;
  String? _testResult;
  bool? _isSuccess;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _apiService.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
      _isSuccess = null;
    });

    _apiService.setBaseUrl(_urlController.text.trim());
    final isOnline = await _apiService.checkConnection();

    if (mounted) {
      setState(() {
        _testing = false;
        _isSuccess = isOnline;
        _testResult = isOnline
            ? 'Connected to Laravel Backend successfully!'
            : 'Could not reach ${_urlController.text.trim()}. Using offline store.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.dns_rounded, color: AppTheme.primaryNavy, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laravel Backend',
                          style: GoogleFonts.lora(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        Text(
                          'Configure API endpoint URL',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'Server Base URL (IP / Host & Port):',
                style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'http://192.168.1.201:8000',
                  prefixIcon: const Icon(Icons.link, size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Reset to default IP',
                    onPressed: () {
                      _urlController.text = 'http://192.168.1.201:8000';
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: GoogleFonts.outfit(fontSize: 13),
              ),
              const SizedBox(height: 10),

              // Quick preset chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildPresetChip('192.168.1.201:8000', 'http://192.168.1.201:8000'),
                  _buildPresetChip('127.0.0.1:8000', 'http://127.0.0.1:8000'),
                  _buildPresetChip('10.0.2.2:8000', 'http://10.0.2.2:8000'),
                ],
              ),
              const SizedBox(height: 14),

              // Test Result Box
              if (_testResult != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: _isSuccess == true ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isSuccess == true ? Colors.green.shade300 : Colors.orange.shade300,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _isSuccess == true ? Icons.check_circle : Icons.info_outline,
                        color: _isSuccess == true ? Colors.green.shade800 : Colors.orange.shade800,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: _isSuccess == true ? Colors.green.shade900 : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Action Buttons Row (Responsive Full-Width Expanded)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _testing ? null : _testConnection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryNavy,
                        side: const BorderSide(color: AppTheme.primaryNavy),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: _testing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('Test', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _apiService.setBaseUrl(_urlController.text.trim());
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Server endpoint: ${_urlController.text.trim()}'),
                            backgroundColor: AppTheme.primaryNavy,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.buttonNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text('Save & Apply', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String url) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.outfit(fontSize: 10.5)),
      onPressed: () {
        _urlController.text = url;
      },
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
