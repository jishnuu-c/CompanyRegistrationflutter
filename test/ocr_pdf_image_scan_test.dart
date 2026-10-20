import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'package:company_reg_flutter/services/ocr_service.dart';
import 'package:company_reg_flutter/services/business_card_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OCR Service - PDF & Image Scanning Tests', () {
    late OcrService ocrService;
    late BusinessCardParserService parser;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('net.nfet.printing'), (
            call,
          ) async {
            if (call.method == 'rasterPdf') {
              return <dynamic>[];
            }
            return null;
          });
      ocrService = OcrService();
      parser = BusinessCardParserService();
    });

    test('isPdfFile correctly identifies PDF files and image files', () {
      expect(ocrService.isPdfFile('business_card.pdf'), isTrue);
      expect(ocrService.isPdfFile('VISITING_CARD.PDF'), isTrue);
      expect(ocrService.isPdfFile('doc.pdf'), isTrue);
      expect(ocrService.isPdfFile('card.jpg'), isFalse);
      expect(ocrService.isPdfFile('card.png'), isFalse);
      expect(ocrService.isPdfFile('card.webp'), isFalse);
      expect(ocrService.isPdfFile(null), isFalse);

      // Test with PDF magic bytes (%PDF)
      final pdfMagicBytes = Uint8List.fromList([
        0x25,
        0x50,
        0x44,
        0x46,
        0x2D,
        0x31,
        0x2E,
        0x34,
      ]);
      expect(ocrService.isPdfFile('unknown_file', pdfMagicBytes), isTrue);

      final pngMagicBytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
      expect(ocrService.isPdfFile('unknown_file', pngMagicBytes), isFalse);
    });

    test(
      'Digital PDF text extraction and parsing matches Angular parser',
      () async {
        // Create a test PDF in-memory with typical business card details
        final document = PdfDocument();
        final page = document.pages.add();
        final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
        final cardText = '''
Apex Technologies Inc.
Elena Rostova
Managing Director
elena@apextech.com
+1 212 555-0199
https://www.apextech.com
1250 Avenue of the Americas, New York, United States
''';
        page.graphics.drawString(cardText, font);
        final pdfBytes = Uint8List.fromList(document.saveSync());
        document.dispose();

        // Scan PDF
        final outcome = await ocrService.scanCard(
          bytes: pdfBytes,
          fileName: 'elena_card.pdf',
        );

        expect(outcome.isPdf, isTrue);
        expect(outcome.result.companyName, contains('Apex Technologies'));
        expect(outcome.result.contactName, equals('Elena Rostova'));
        expect(outcome.result.contactDesignation, equals('Managing Director'));
        expect(outcome.result.email, equals('elena@apextech.com'));
        expect(outcome.result.contactMobileNumber, contains('212 555-0199'));
        expect(outcome.result.confidenceScore, greaterThanOrEqualTo(50));

        // Check rendered preview image object exists
        expect(outcome.previewImageBytes, isNotNull);
      },
    );

    test('Parser extracts fields from raw business card text correctly', () {
      const rawText = '''
Global Logistics Solutions Ltd.
David Miller
Chief Technology Officer
david.miller@globallogistics.com
+44 20 7946 0912
www.globallogistics.com
100 Bishopgate, London, United Kingdom
''';
      final parsed = parser.parse(rawText);

      expect(parsed.companyName, contains('Global Logistics Solutions'));
      expect(parsed.contactName, equals('David Miller'));
      expect(parsed.contactDesignation, equals('Chief Technology Officer'));
      expect(parsed.email, equals('david.miller@globallogistics.com'));
      expect(parsed.website, contains('globallogistics.com'));
      expect(parsed.country, equals('United Kingdom'));
      expect(parsed.confidenceScore, greaterThan(60));
      expect(parsed.isLowConfidence, isFalse);
    });
  });
}
