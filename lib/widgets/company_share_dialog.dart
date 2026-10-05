// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/company_model.dart';
import '../services/company_service.dart';
import '../theme/app_theme.dart';
import 'status_badge_chip.dart';

class CompanyShareDialog extends StatefulWidget {
  final CompanyResponse company;

  const CompanyShareDialog({super.key, required this.company});

  static Future<void> show(BuildContext context, CompanyResponse company) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CompanyShareDialog(company: company),
    );
  }

  /// Exact Angular formatting for WhatsApp / Clipboard / Email sharing
  static String formatCompanyContactText(CompanyResponse c) {
    final buffer = StringBuffer();
    buffer.writeln('🏢 *${c.companyName}*');
    buffer.writeln('--------------------------------');

    if (c.contactName != null && c.contactName!.isNotEmpty) {
      buffer.write('👤 Contact: ${c.contactName}');
      if (c.contactDesignation != null && c.contactDesignation!.isNotEmpty) {
        buffer.write(' (${c.contactDesignation})');
      }
      buffer.writeln();
    }

    if (c.contactMobileNumber != null && c.contactMobileNumber!.isNotEmpty) {
      buffer.writeln('📱 Mobile: ${c.contactMobileNumber}');
    }

    if (c.landline != null && c.landline!.isNotEmpty) {
      buffer.writeln('☎️ Phone: ${c.landline}');
    }

    if (c.email.isNotEmpty) {
      buffer.writeln('✉️ Email: ${c.email}');
    }

    if (c.website != null && c.website!.isNotEmpty) {
      buffer.writeln('🌐 Website: ${c.website}');
    }

    final locParts = [
      c.address,
      c.city,
      c.country,
    ].where((p) => p != null && p.isNotEmpty).toList();
    if (locParts.isNotEmpty) {
      buffer.writeln('📍 Location: ${locParts.join(', ')}');
    }

    if (c.brands.isNotEmpty) {
      final brandNames = c.brands.map((b) => b.brandName).join(', ');
      buffer.writeln('🏷️ Brands: $brandNames');
    }

    if (c.products.isNotEmpty) {
      final prodNames = c.products.map((p) => p.name).join(', ');
      buffer.writeln('📦 Products: $prodNames');
    }

    buffer.writeln('--------------------------------');
    buffer.write('Shared via Company Registration Portal');
    return buffer.toString();
  }

  /// Generates standard vCard 3.0 content
  static String generateVCard(CompanyResponse c) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');
    buffer.writeln('FN:${c.contactName ?? c.companyName}');
    buffer.writeln('ORG:${c.companyName}');
    if (c.contactDesignation != null && c.contactDesignation!.isNotEmpty) {
      buffer.writeln('TITLE:${c.contactDesignation}');
    }
    if (c.contactMobileNumber != null && c.contactMobileNumber!.isNotEmpty) {
      buffer.writeln('TEL;TYPE=CELL,VOICE:${c.contactMobileNumber}');
    }
    if (c.landline != null && c.landline!.isNotEmpty) {
      buffer.writeln('TEL;TYPE=WORK,VOICE:${c.landline}');
    }
    if (c.email.isNotEmpty) {
      buffer.writeln('EMAIL;TYPE=WORK,INTERNET:${c.email}');
    }
    if (c.website != null && c.website!.isNotEmpty) {
      buffer.writeln('URL:${c.website}');
    }
    if (c.address != null || c.city != null || c.country != null) {
      buffer.writeln(
        'ADR;TYPE=WORK:;;${c.address ?? ''};${c.city ?? ''};;;${c.country ?? ''}',
      );
    }
    buffer.writeln('END:VCARD');
    return buffer.toString();
  }

  @override
  State<CompanyShareDialog> createState() => _CompanyShareDialogState();
}

class _CompanyShareDialogState extends State<CompanyShareDialog> {
  final CompanyService _companyService = CompanyService();
  bool _isCopied = false;
  bool _isExportingPdf = false;

  void _copyContactDetails() {
    final text = CompanyShareDialog.formatCompanyContactText(widget.company);
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _isCopied = true);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  Future<void> _shareViaWhatsApp() async {
    final text = CompanyShareDialog.formatCompanyContactText(widget.company);
    final encoded = Uri.encodeComponent(text);
    final url = 'https://api.whatsapp.com/send?text=$encoded';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _shareNative();
    }
  }

  Future<void> _shareViaEmail() async {
    final text = CompanyShareDialog.formatCompanyContactText(widget.company);
    final subject = Uri.encodeComponent(
      'Company Contact Details: ${widget.company.companyName}',
    );
    final body = Uri.encodeComponent(text);
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _shareNative();
    }
  }

  Future<void> _downloadVCard() async {
    final vcard = CompanyShareDialog.generateVCard(widget.company);
    final safeName = widget.company.companyName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .toLowerCase();
    final fileName = '$safeName.vcf';

    try {
      final xFile = XFile.fromData(
        Uint8List.fromList(vcard.codeUnits),
        name: fileName,
        mimeType: 'text/vcard',
      );
      await Share.shareXFiles([xFile], text: 'Contact Card for ${widget.company.companyName}');
    } catch (_) {
      // Fallback to clipboard
      _copyContactDetails();
    }
  }

  Future<void> _downloadPdfProfile() async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);

    try {
      final bytes = await _companyService.exportCompanyProfilePdf(
        widget.company.id,
      );
      final safeName = widget.company.companyName
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = '${safeName}_Profile_with_Cards.pdf';

      final xFile = XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'application/pdf',
      );
      await Share.shareXFiles([xFile], text: '${widget.company.companyName} Profile');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download PDF profile: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  void _shareNative() {
    final text = CompanyShareDialog.formatCompanyContactText(widget.company);
    Share.share(
      text,
      subject: 'Enterprise Contact: ${widget.company.companyName}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final comp = widget.company;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                color: AppTheme.bgSubtle,
                border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Icon(
                      Icons.share,
                      size: 18,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ENTERPRISE CONTACT SHARING',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          comp.companyName,
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
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Modal Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preview Card
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bgSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Avatar, Name, Location, Status
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF4F46E5),
                                      Color(0xFF7C3AED),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    comp.companyName.isNotEmpty
                                        ? comp.companyName
                                            .substring(0, 1)
                                            .toUpperCase()
                                        : 'C',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      comp.companyName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 12,
                                          color: AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            [
                                              comp.city,
                                              comp.country,
                                            ]
                                                .where(
                                                  (p) =>
                                                      p != null && p.isNotEmpty,
                                                )
                                                .join(', '),
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppTheme.textMuted,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadgeChip(status: comp.status, isMini: true),
                            ],
                          ),
                          const Divider(
                            height: 20,
                            thickness: 1,
                            color: AppTheme.borderLight,
                          ),

                          // Contact details rows
                          if (comp.contactName != null &&
                              comp.contactName!.isNotEmpty)
                            _buildDetailRow(
                              Icons.person_outline,
                              'Contact',
                              '${comp.contactName!}${comp.contactDesignation != null ? ' • ${comp.contactDesignation}' : ''}',
                            ),

                          if (comp.contactMobileNumber != null &&
                              comp.contactMobileNumber!.isNotEmpty)
                            _buildDetailRow(
                              Icons.phone_iphone,
                              'Mobile',
                              comp.contactMobileNumber!,
                              isLink: true,
                              onTap: () => launchUrl(
                                Uri.parse('tel:${comp.contactMobileNumber}'),
                              ),
                            ),

                          if (comp.landline != null && comp.landline!.isNotEmpty)
                            _buildDetailRow(
                              Icons.phone_outlined,
                              'Landline',
                              comp.landline!,
                              isLink: true,
                              onTap: () =>
                                  launchUrl(Uri.parse('tel:${comp.landline}')),
                            ),

                          if (comp.email.isNotEmpty)
                            _buildDetailRow(
                              Icons.email_outlined,
                              'Email',
                              comp.email,
                              isLink: true,
                              onTap: () =>
                                  launchUrl(Uri.parse('mailto:${comp.email}')),
                            ),

                          if (comp.website != null && comp.website!.isNotEmpty)
                            _buildDetailRow(
                              Icons.language,
                              'Website',
                              comp.website!,
                              isLink: true,
                              onTap: () {
                                final u = Uri.tryParse(comp.website!);
                                if (u != null) launchUrl(u);
                              },
                            ),

                          if (comp.brands.isNotEmpty)
                            _buildDetailRow(
                              Icons.verified_outlined,
                              'Brands',
                              comp.brands.map((b) => b.brandName).join(', '),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      'SELECT SHARING METHOD',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Grid of 6 Share Options
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 400;
                        return GridView.count(
                          crossAxisCount: isNarrow ? 1 : 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: isNarrow ? 3.8 : 2.5,
                          children: [
                            // 1. Copy Details
                            _buildShareChannelButton(
                              icon: _isCopied
                                  ? Icons.check_circle
                                  : Icons.content_copy_outlined,
                              title: _isCopied
                                  ? 'Copied to Clipboard!'
                                  : 'Copy Contact Details',
                              subtitle: _isCopied
                                  ? 'Ready to paste anywhere'
                                  : 'Full formatted summary',
                              circleBg: const Color(0xFFEFF6FF),
                              circleColor: const Color(0xFF2563EB),
                              isCopied: _isCopied,
                              onTap: _copyContactDetails,
                            ),

                            // 2. WhatsApp
                            _buildShareChannelButton(
                              icon: Icons.chat_bubble_outline,
                              title: 'Share on WhatsApp',
                              subtitle: 'Direct chat message',
                              circleBg: const Color(0xFFECFDF5),
                              circleColor: const Color(0xFF059669),
                              onTap: _shareViaWhatsApp,
                            ),

                            // 3. Email
                            _buildShareChannelButton(
                              icon: Icons.mark_email_read_outlined,
                              title: 'Send via Email',
                              subtitle: 'Pre-filled email draft',
                              circleBg: const Color(0xFFEFF6FF),
                              circleColor: const Color(0xFF2563EB),
                              onTap: _shareViaEmail,
                            ),

                            // 4. vCard (.vcf)
                            _buildShareChannelButton(
                              icon: Icons.badge_outlined,
                              title: 'Download vCard (.vcf)',
                              subtitle: 'Import to phone contacts',
                              circleBg: const Color(0xFFF5F3FF),
                              circleColor: const Color(0xFF7C3AED),
                              onTap: _downloadVCard,
                            ),

                            // 5. Download PDF Profile
                            _buildShareChannelButton(
                              icon: _isExportingPdf
                                  ? Icons.hourglass_top
                                  : Icons.picture_as_pdf,
                              title: _isExportingPdf
                                  ? 'Exporting PDF...'
                                  : 'Download PDF Profile',
                              subtitle: 'With business cards images',
                              circleBg: const Color(0xFFFEF2F2),
                              circleColor: const Color(0xFFDC2626),
                              isLoading: _isExportingPdf,
                              onTap: _downloadPdfProfile,
                            ),

                            // 6. Device Share Sheet
                            _buildShareChannelButton(
                              icon: Icons.share_outlined,
                              title: 'Device Share Sheet',
                              subtitle: 'System native share',
                              circleBg: const Color(0xFFF1F5F9),
                              circleColor: const Color(0xFF475569),
                              onTap: _shareNative,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer
            const Divider(height: 1, color: AppTheme.borderLight),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    bool isLink = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          SizedBox(
            width: 65,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isLink ? const Color(0xFF2563EB) : AppTheme.textPrimary,
                  decoration: isLink
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareChannelButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color circleBg,
    required Color circleColor,
    required VoidCallback onTap,
    bool isCopied = false,
    bool isLoading = false,
  }) {
    return Material(
      color: isCopied ? const Color(0xFFF0FDF4) : AppTheme.bgSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCopied ? const Color(0xFF10B981) : AppTheme.borderLight,
              width: isCopied ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCopied ? const Color(0xFF10B981) : circleBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: circleColor,
                          ),
                        )
                      : Icon(
                          icon,
                          size: 18,
                          color: isCopied ? Colors.white : circleColor,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isCopied
                            ? const Color(0xFF047857)
                            : AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}