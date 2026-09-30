import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/company_model.dart';
import '../theme/app_theme.dart';
import '../widgets/section_header_badge.dart';
import '../widgets/star_rating_widget.dart';
import '../widgets/website_preview_panel.dart';
import 'company_form_screen.dart';

class CompanyDetailScreen extends StatelessWidget {
  final Company company;

  const CompanyDetailScreen({super.key, required this.company});

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final formatted = url.startsWith('http://') || url.startsWith('https://') ? url : 'https://$url';
    final uri = Uri.tryParse(formatted);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchCall(String phone) async {
    final uri = Uri.tryParse('tel:$phone');
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.tryParse('mailto:$email');
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryNavy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          company.companyName,
          style: GoogleFonts.lora(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryNavy,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppTheme.primaryNavy),
            tooltip: 'Edit Company',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => CompanyFormScreen(companyToEdit: company)),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Details Container
                  SizedBox(
                    width: 580,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildDetailsCard(context),
                    ),
                  ),
                  // Right Column: Live Website Preview Panel
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 20, 20, 20),
                      child: WebsitePreviewPanel(
                        url: company.website,
                        companyName: company.companyName,
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      children: [
                        _buildDetailsCard(context),
                        if (company.website.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 480,
                            child: WebsitePreviewPanel(
                              url: company.website,
                              companyName: company.companyName,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryNavy.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    company.companyName.isNotEmpty ? company.companyName[0].toUpperCase() : 'C',
                    style: GoogleFonts.lora(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
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
                      company.companyName,
                      style: GoogleFonts.lora(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 13, color: AppTheme.buttonNavy),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${company.city.isNotEmpty ? '${company.city}, ' : ''}${company.country}',
                            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Rating
          if (company.rating > 0) ...[
            Row(
              children: [
                StarRatingWidget(
                  rating: company.rating,
                  size: 20,
                  readOnly: true,
                  onRatingChanged: (_) {},
                ),
                const SizedBox(width: 6),
                Text(
                  '${company.rating.toStringAsFixed(1)} / 5.0 Rating',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Quick Action Buttons (Call, Email, Website)
          Row(
            children: [
              if (company.mobile.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchCall(company.mobile),
                    icon: const Icon(Icons.phone, size: 14),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryNavy,
                      side: const BorderSide(color: AppTheme.primaryNavy),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              if (company.mobile.isNotEmpty && company.email.isNotEmpty) const SizedBox(width: 6),
              if (company.email.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchEmail(company.email),
                    icon: const Icon(Icons.email, size: 14),
                    label: const Text('Email'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryNavy,
                      side: const BorderSide(color: AppTheme.primaryNavy),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              if (company.website.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchUrl(company.website),
                    icon: const Icon(Icons.language, size: 14),
                    label: const Text('Website'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.buttonNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Visiting Card preview
          if (company.visitingCardUrl != null || company.visitingCardName != null) ...[
            const SectionHeaderBadge(title: 'Visiting Card'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.credit_card, size: 16, color: AppTheme.buttonNavy),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          company.visitingCardName ?? 'Corporate Card',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (company.visitingCardUrl != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        company.visitingCardUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 50,
                          color: Colors.grey.shade100,
                          alignment: Alignment.center,
                          child: const Text('Visiting card preview unavailable', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Contact Details
          const SectionHeaderBadge(title: 'Contact Information'),
          const SizedBox(height: 8),
          _buildInfoRow('Email', company.email),
          _buildInfoRow('Landline', company.landline.isNotEmpty ? company.landline : 'N/A'),
          _buildInfoRow('Mobile', company.mobile.isNotEmpty ? company.mobile : 'N/A'),
          _buildInfoRow('Website', company.website.isNotEmpty ? company.website : 'N/A'),
          _buildInfoRow('Address', company.fullAddress.isNotEmpty ? company.fullAddress : 'N/A'),
          const SizedBox(height: 14),

          // Brands & Products
          const SectionHeaderBadge(title: 'Brands & Products'),
          const SizedBox(height: 8),
          if (company.brands.isNotEmpty) ...[
            Text('Brands:', style: GoogleFonts.lora(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: company.brands.map((b) => Chip(
                label: Text(b, style: GoogleFonts.outfit(fontSize: 11)),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (company.products.isNotEmpty) ...[
            Text('Products:', style: GoogleFonts.lora(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: company.products.map((p) => Chip(
                label: Text(p, style: GoogleFonts.outfit(fontSize: 11)),
                backgroundColor: Colors.teal.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),

          // Summary
          if (company.summary.isNotEmpty) ...[
            const SectionHeaderBadge(title: 'Company Summary'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                company.summary,
                style: GoogleFonts.outfit(fontSize: 12.5, height: 1.4, color: AppTheme.textDark),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Documents
          if (company.documents.isNotEmpty) ...[
            const SectionHeaderBadge(title: 'Uploaded Documents'),
            const SizedBox(height: 8),
            Column(
              children: company.documents.map((doc) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.file_present_rounded, size: 18, color: AppTheme.buttonNavy),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          doc.name,
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (doc.formattedSize.isNotEmpty)
                        Text(
                          doc.formattedSize,
                          style: GoogleFonts.outfit(fontSize: 10.5, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 75,
            child: Text(
              '$label:',
              style: GoogleFonts.lora(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
