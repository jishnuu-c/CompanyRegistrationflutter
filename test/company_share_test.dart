import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:company_reg_flutter/models/brand_model.dart';
import 'package:company_reg_flutter/models/company_model.dart';
import 'package:company_reg_flutter/models/product_model.dart';
import 'package:company_reg_flutter/widgets/company_share_dialog.dart';

void main() {
  final sampleCompany = CompanyResponse(
    id: 1,
    companyName: 'ABC Company',
    email: 'abc@example.com',
    landline: '+1 555-0199',
    address: '123 Business Way',
    city: 'New York',
    country: 'United States',
    website: 'https://abc.example.com',
    description: 'Premier enterprise distributor',
    contactName: 'Alice Smith',
    contactDesignation: 'Managing Director',
    contactEmail: 'alice@abc.example.com',
    contactMobileNumber: '+1 555-0100',
    status: 'ACTIVE',
    businessCard: null,
    brands: [
      BrandResponse(id: 101, brandName: 'Apex Dynamics', brandLogo: null),
      BrandResponse(id: 102, brandName: 'Nike', brandLogo: null),
    ],
    products: [
      ProductResponse(id: 201, name: 'Mixer', brandId: 101, brandName: 'Apex Dynamics', categoryId: 1),
      ProductResponse(id: 202, name: 'MP', brandId: 102, brandName: 'Nike', categoryId: 1),
    ],
  );

  group('CompanyShareDialog text & vCard generators', () {
    test('formatCompanyContactText formats accurately like Angular', () {
      final text = CompanyShareDialog.formatCompanyContactText(sampleCompany);
      expect(text, contains('🏢 *ABC Company*'));
      expect(text, contains('👤 Contact: Alice Smith (Managing Director)'));
      expect(text, contains('📱 Mobile: +1 555-0100'));
      expect(text, contains('☎️ Phone: +1 555-0199'));
      expect(text, contains('✉️ Email: abc@example.com'));
      expect(text, contains('🌐 Website: https://abc.example.com'));
      expect(text, contains('🏷️ Brands: Apex Dynamics, Nike'));
      expect(text, contains('📦 Products: Mixer, MP'));
      expect(text, contains('Shared via Company Registration Portal'));
    });

    test('generateVCard generates valid vCard 3.0 string', () {
      final vcard = CompanyShareDialog.generateVCard(sampleCompany);
      expect(vcard, contains('BEGIN:VCARD'));
      expect(vcard, contains('VERSION:3.0'));
      expect(vcard, contains('FN:Alice Smith'));
      expect(vcard, contains('ORG:ABC Company'));
      expect(vcard, contains('TITLE:Managing Director'));
      expect(vcard, contains('TEL;TYPE=CELL,VOICE:+1 555-0100'));
      expect(vcard, contains('TEL;TYPE=WORK,VOICE:+1 555-0199'));
      expect(vcard, contains('EMAIL;TYPE=WORK,INTERNET:abc@example.com'));
      expect(vcard, contains('URL:https://abc.example.com'));
      expect(vcard, contains('END:VCARD'));
    });
  });

  group('CompanyShareDialog Widget Test', () {
    testWidgets('renders modal header, preview card and all 6 share channel buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CompanyShareDialog.show(context, sampleCompany),
                child: const Text('Open Share'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Share'));
      await tester.pumpAndSettle();

      expect(find.text('ENTERPRISE CONTACT SHARING'), findsOneWidget);
      expect(find.text('ABC Company'), findsNWidgets(2));
      expect(find.text('Copy Contact Details'), findsOneWidget);
      expect(find.text('Share on WhatsApp'), findsOneWidget);
      expect(find.text('Send via Email'), findsOneWidget);
      expect(find.text('Download vCard (.vcf)'), findsOneWidget);
      expect(find.text('Download PDF Profile'), findsOneWidget);
      expect(find.text('Device Share Sheet'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}