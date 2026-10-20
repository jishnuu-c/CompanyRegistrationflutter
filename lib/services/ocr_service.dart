import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/ocr_model.dart';
import 'business_card_parser_service.dart';

class PdfRenderResult {
  final Uint8List imageBytes;
  final String extractedText;

  PdfRenderResult({required this.imageBytes, required this.extractedText});
}

class OcrScanOutcome {
  final BusinessCardScanResult result;
  final Uint8List previewImageBytes;
  final bool isPdf;

  OcrScanOutcome({
    required this.result,
    required this.previewImageBytes,
    required this.isPdf,
  });
}

class OcrService {
  static const String _defaultApiKey =
      'AIzaSyBXKybocdaq9vts91d6DFhShlJrR6O-Vh4';
  static const String _defaultReferer = 'http://localhost:4200/';
  final BusinessCardParserService _parser = BusinessCardParserService();

  String get apiKey => _defaultApiKey;

  bool isPdfFile(String? fileName, [Uint8List? bytes]) {
    if (fileName != null && fileName.trim().toLowerCase().endsWith('.pdf')) {
      return true;
    }
    if (bytes != null && bytes.length >= 4) {
      // PDF magic bytes %PDF (0x25, 0x50, 0x44, 0x46)
      if (bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46) {
        return true;
      }
    }
    return false;
  }

  /// Renders Page 1 of a PDF onto high-resolution raster image (150 DPI),
  /// extracts digital text directly via Syncfusion, matching Angular's PDF.js workflow.
  Future<PdfRenderResult> renderPdfPageToImage(
    Uint8List pdfBytes, {
    int pageNumber = 1,
  }) async {
    // 1. Digital text extraction directly from PDF
    String extractedText = '';
    try {
      final document = PdfDocument(inputBytes: pdfBytes);
      try {
        if (document.pages.count > 0) {
          final targetIndex = (pageNumber - 1).clamp(
            0,
            document.pages.count - 1,
          );
          extractedText = PdfTextExtractor(document)
              .extractText(
                startPageIndex: targetIndex,
                endPageIndex: targetIndex,
              )
              .trim();
        }
      } finally {
        document.dispose();
      }
    } catch (e) {
      debugPrint('Syncfusion PDF digital text extraction note: $e');
    }

    // 2. High-resolution rasterization of Page 1 to PNG image for display & Vision OCR
    Uint8List? rasterImageBytes;
    try {
      final targetIndex = pageNumber - 1;
      final rasterStream =
          Printing.raster(pdfBytes, pages: [targetIndex], dpi: 150)
              .timeout(
                const Duration(seconds: 2),
                onTimeout: (sink) {
                  sink.close();
                },
              )
              .handleError((err) {
                debugPrint('Printing raster stream note: $err');
              });
      await for (final page in rasterStream) {
        rasterImageBytes = await page.toPng();
        break;
      }
    } catch (e) {
      debugPrint('Printing rasterization error: $e');
    }

    if (rasterImageBytes == null) {
      if (extractedText.isEmpty) {
        throw Exception('Failed to render PDF page to image.');
      }
      rasterImageBytes = Uint8List(0);
    }

    return PdfRenderResult(
      imageBytes: rasterImageBytes,
      extractedText: extractedText,
    );
  }

  /// Scans business card file (either image or PDF) and extracts structured contact entities.
  Future<OcrScanOutcome> scanCard({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final isPdf = isPdfFile(fileName, bytes);

    if (isPdf) {
      try {
        final renderResult = await renderPdfPageToImage(bytes, pageNumber: 1);

        // Branch 1A: If rich digital text exists in the PDF, parse it directly
        if (renderResult.extractedText.length > 25) {
          final parsed = _parser.parse(renderResult.extractedText);
          if (parsed.confidenceScore >= 35 ||
              (parsed.email != null && parsed.email!.isNotEmpty) ||
              (parsed.contactMobileNumber != null &&
                  parsed.contactMobileNumber!.isNotEmpty) ||
              (parsed.companyName != null && parsed.companyName!.isNotEmpty)) {
            return OcrScanOutcome(
              result: parsed,
              previewImageBytes: renderResult.imageBytes,
              isPdf: true,
            );
          }
        }

        // Branch 1B: Scanned PDF or sparse digital text -> Send rendered page image to Google Vision
        if (apiKey.isEmpty) {
          if (renderResult.extractedText.isNotEmpty) {
            return OcrScanOutcome(
              result: _parser.parse(renderResult.extractedText),
              previewImageBytes: renderResult.imageBytes,
              isPdf: true,
            );
          }
          throw Exception(
            'Business card scanning service is currently not configured.',
          );
        }

        if (renderResult.imageBytes.isEmpty) {
          throw Exception('Unable to render PDF page image for OCR scanning.');
        }

        final base64Image = base64Encode(renderResult.imageBytes);
        final visionResult = await _callGoogleVisionApi(base64Image);
        return OcrScanOutcome(
          result: visionResult,
          previewImageBytes: renderResult.imageBytes,
          isPdf: true,
        );
      } catch (e) {
        debugPrint('PDF OCR processing error: $e');
        final msg = e.toString().replaceAll('Exception:', '').trim();
        throw Exception(
          msg.isNotEmpty
              ? msg
              : 'Unable to scan PDF document. Please verify the file is not corrupted.',
        );
      }
    }

    // Branch 2: Standard Image Files (JPG, PNG, WEBP)
    if (apiKey.isEmpty) {
      throw Exception(
        'Business card scanning service is currently not configured.',
      );
    }

    try {
      final base64Image = base64Encode(bytes);
      final visionResult = await _callGoogleVisionApi(base64Image);
      return OcrScanOutcome(
        result: visionResult,
        previewImageBytes: bytes,
        isPdf: false,
      );
    } catch (e) {
      final errMsg = e.toString();
      if (errMsg.toLowerCase().contains('no readable text')) {
        throw Exception(
          'No readable text detected on this image. Please upload a clear, focused photo of a business card.',
        );
      }
      debugPrint('Image OCR service error: $e');
      throw Exception(
        'Unable to scan business card at this moment. Please enter details manually.',
      );
    }
  }

  /// Backward compatibility helper
  Future<BusinessCardScanResult> scanBusinessCard(
    Uint8List imageBytes, [
    String fileName = 'card.jpg',
  ]) async {
    final outcome = await scanCard(bytes: imageBytes, fileName: fileName);
    return outcome.result;
  }

  Future<BusinessCardScanResult> _callGoogleVisionApi(String base64Data) async {
    final url = Uri.parse(
      'https://vision.googleapis.com/v1/images:annotate?key=$apiKey',
    );

    final payload = {
      'requests': [
        {
          'image': {'content': base64Data},
          'features': [
            {'type': 'DOCUMENT_TEXT_DETECTION', 'maxResults': 1},
          ],
        },
      ],
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Referer': _defaultReferer},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      try {
        final errJson = jsonDecode(response.body);
        final msg =
            errJson['error']?['message'] ??
            'Vision API error (${response.statusCode})';
        throw Exception(msg);
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
        throw Exception(
          'Failed to communicate with OCR service (HTTP ${response.statusCode})',
        );
      }
    }

    final data = jsonDecode(response.body);
    final responses = data['responses'] as List<dynamic>?;
    if (responses == null || responses.isEmpty) {
      throw Exception('No readable text found on the business card image.');
    }

    final responseItem = responses.first as Map<String, dynamic>;
    if (responseItem.containsKey('error')) {
      final errMsg =
          responseItem['error']?['message'] ?? 'Vision API returned an error';
      throw Exception(errMsg);
    }

    String rawText = '';
    if (responseItem['fullTextAnnotation'] != null &&
        responseItem['fullTextAnnotation']['text'] != null) {
      rawText = responseItem['fullTextAnnotation']['text'] as String;
    } else if (responseItem['textAnnotations'] != null &&
        (responseItem['textAnnotations'] as List).isNotEmpty) {
      rawText =
          (responseItem['textAnnotations'] as List).first['description']
              as String? ??
          '';
    }

    if (rawText.trim().isEmpty) {
      throw Exception('No readable text found on the business card image.');
    }

    return _parser.parse(rawText);
  }
}
