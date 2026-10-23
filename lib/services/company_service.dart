import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/company_model.dart';
import '../models/product_model.dart';
import 'api_config.dart';
import 'auth_service.dart';
import '../utils/api_error_util.dart';

class CompanyService {
  final ApiConfig _config = ApiConfig();
  final AuthService _auth = AuthService();

  String get _apiUrl => '${_config.apiUrl}/companies';

  static final List<CompanyResponse> _fallbackCompanies = [
    CompanyResponse(
      id: 1,
      companyName: 'CANADIAN SYSTEMS CONTRACTING COMPANY',
      email: 'khaleedaljundy@yahoo.com',
      contactName: 'Eng. Mohammed Khaled',
      contactDesignation: 'Sales Department',
      contactEmail: 'khaleedaljundy@yahoo.com',
      contactMobileNumber: '+966557020384',
      city: 'Riyadh',
      country: 'KSA',
      address: '2 Address: Riyadh- ksa',
      website: 'https://www.canadiansystems.sa',
      status: 'ACTIVE',
      userId: 1,
      userEmail: 'admin@corpregistry.com',
      userFullName: 'System Administrator',
    ),
    CompanyResponse(
      id: 2,
      companyName: 'Azoo',
      email: 'user@corpregistry.com',
      contactName: 'Eng. Mohamed Sadek',
      contactDesignation: 'Sales Account Manager',
      contactEmail: 'user@corpregistry.com',
      contactMobileNumber: '+966 54 066 6580',
      country: 'KSA',
      status: 'ACTIVE',
      userId: 2,
      userEmail: 'user@corpregistry.com',
      userFullName: 'Enterprise Officer',
    ),
    CompanyResponse(
      id: 3,
      companyName: 'VitrA',
      email: 'tamam.younso@vitra.com.tr',
      contactName: 'Tamam Younso',
      contactDesignation: 'Sales Manager - Wholesale KSA',
      contactEmail: 'tamam.younso@vitra.com.tr',
      contactMobileNumber: '+966-55-033-1235',
      landline: '+971-4-547-8045',
      city: 'Dubai',
      country: 'UAE',
      address: 'ECZACIBASI BUILDING MATERIALS TRADING L.L.C, 2020 Building',
      website: 'https://www.amazon.in/',
      status: 'ACTIVE',
      userId: 99,
      userEmail: 'tamam.younso@vitra.com.tr',
    ),
    CompanyResponse(
      id: 4,
      companyName: 'Apex Global Technologies Inc.',
      email: 'contact@apexglobal.com',
      contactName: 'Sarah Jenkins',
      contactDesignation: 'VP Corporate Relations',
      contactEmail: 's.jenkins@apexglobal.com',
      contactMobileNumber: '+1 555-0199',
      landline: '+1 800-555-0190',
      city: 'San Francisco',
      country: 'United States',
      address: '500 Howard Street, Suite 400',
      website: 'https://apexglobal.example.com',
      description:
          'Enterprise cloud infrastructure and distributed IT systems provider.',
      status: 'ACTIVE',
      userId: 1,
      userEmail: 'admin@corpregistry.com',
      userFullName: 'System Administrator',
    ),
  ];

  Future<List<CompanyResponse>> getAllCompanies() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_apiUrl/get-all'),
            headers: _auth.getAuthHeaders({'Accept': 'application/json'}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          final list = decoded
              .map((e) => CompanyResponse.fromJson(e as Map<String, dynamic>))
              .toList();
          if (list.isNotEmpty) return list;
        }
      }
    } catch (_) {}

    return List.from(_fallbackCompanies);
  }

  Future<CompanyResponse> getCompanyById(int id) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_apiUrl/$id'),
            headers: _auth.getAuthHeaders({'Accept': 'application/json'}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return CompanyResponse.fromJson(decoded as Map<String, dynamic>);
      }
    } catch (_) {}

    return _fallbackCompanies.firstWhere(
      (c) => c.id == id,
      orElse: () => throw Exception('Failed to load company #$id'),
    );
  }

  Future<CompanyResponse> createCompany(
    CompanyRequest companyData, {
    Uint8List? fileBytes,
    String? fileName,
    String? filePath,
  }) async {
    try {
      final uri = Uri.parse('$_apiUrl/create');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(
        _auth.getAuthHeaders({'Accept': 'application/json'}),
      );

      final jsonStr = jsonEncode(companyData.toJson());
      request.files.add(
        http.MultipartFile.fromString(
          'data',
          jsonStr,
          contentType: http.MediaType('application', 'json'),
        ),
      );

      if (fileBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName ?? 'business_card.png',
          ),
        );
      } else if (filePath != null && !kIsWeb) {
        request.files.add(
          await http.MultipartFile.fromPath('file', filePath, filename: fileName),
        );
      }

      final streamed = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return CompanyResponse.fromJson(decoded as Map<String, dynamic>);
      } else if (!_auth.isDemoSession) {
        throw ApiException.fromResponse(
          response,
          fallbackMessage: 'Failed to create company (status: ${response.statusCode})',
        );
      }
    } catch (e) {
      if (!_auth.isDemoSession) rethrow;
    }

    // Demo / offline fallback simulation
    final newId = (_fallbackCompanies.isNotEmpty
        ? _fallbackCompanies.map((c) => c.id).reduce((a, b) => a > b ? a : b)
        : 0) + 1;
    final created = CompanyResponse(
      id: newId,
      companyName: companyData.companyName,
      email: companyData.email,
      landline: companyData.landline,
      address: companyData.address,
      city: companyData.city,
      country: companyData.country,
      website: companyData.website,
      description: companyData.description,
      status: companyData.status,
      contactName: companyData.contactName,
      contactDesignation: companyData.contactDesignation,
      contactEmail: companyData.contactEmail,
      contactMobileNumber: companyData.contactMobileNumber,
      brandIds: companyData.brandIds,
      productIds: companyData.productIds,
      userId: companyData.userId ?? _auth.currentUser?.id,
      userEmail: _auth.currentUser?.email,
      userFullName: _auth.currentUser?.fullName,
      businessCard: fileName,
      businessCards: fileName != null ? [fileName] : [],
    );
    _fallbackCompanies.insert(0, created);
    return created;
  }

  Future<CompanyResponse> updateCompany(
    int id,
    CompanyRequest companyData, {
    Uint8List? fileBytes,
    String? fileName,
    String? filePath,
  }) async {
    try {
      final uri = Uri.parse('$_apiUrl/update/$id');
      final request = http.MultipartRequest('PUT', uri);
      request.headers.addAll(
        _auth.getAuthHeaders({'Accept': 'application/json'}),
      );

      final jsonStr = jsonEncode(companyData.toJson());
      request.files.add(
        http.MultipartFile.fromString(
          'data',
          jsonStr,
          contentType: http.MediaType('application', 'json'),
        ),
      );

      if (fileBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName ?? 'business_card.png',
          ),
        );
      } else if (filePath != null && !kIsWeb) {
        request.files.add(
          await http.MultipartFile.fromPath('file', filePath, filename: fileName),
        );
      }

      final streamed = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return CompanyResponse.fromJson(decoded as Map<String, dynamic>);
      } else if (!_auth.isDemoSession) {
        throw ApiException.fromResponse(
          response,
          fallbackMessage: 'Failed to update company (status: ${response.statusCode})',
        );
      }
    } catch (e) {
      if (!_auth.isDemoSession) rethrow;
    }

    // Demo / offline fallback simulation
    final existingIndex = _fallbackCompanies.indexWhere((c) => c.id == id);
    final existing = existingIndex >= 0 ? _fallbackCompanies[existingIndex] : null;

    final updated = CompanyResponse(
      id: id,
      companyName: companyData.companyName,
      email: companyData.email,
      landline: companyData.landline,
      address: companyData.address,
      city: companyData.city,
      country: companyData.country,
      website: companyData.website,
      description: companyData.description,
      status: companyData.status,
      contactName: companyData.contactName,
      contactDesignation: companyData.contactDesignation,
      contactEmail: companyData.contactEmail,
      contactMobileNumber: companyData.contactMobileNumber,
      brandIds: companyData.brandIds,
      productIds: companyData.productIds,
      userId: companyData.userId ?? existing?.userId ?? _auth.currentUser?.id,
      userEmail: existing?.userEmail ?? _auth.currentUser?.email,
      userFullName: existing?.userFullName ?? _auth.currentUser?.fullName,
      businessCard: fileName ?? existing?.businessCard,
      businessCards: fileName != null
          ? [fileName]
          : (existing?.businessCards ?? []),
    );

    if (existingIndex >= 0) {
      _fallbackCompanies[existingIndex] = updated;
    } else {
      _fallbackCompanies.insert(0, updated);
    }
    return updated;
  }

  Future<void> deleteCompany(int id) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_apiUrl/delete/$id'),
            headers: _auth.getAuthHeaders({'Accept': 'application/json'}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _fallbackCompanies.removeWhere((c) => c.id == id);
        return;
      } else if (!_auth.isDemoSession) {
        throw ApiException.fromResponse(
          response,
          fallbackMessage: 'Failed to delete company #$id',
        );
      }
    } catch (e) {
      if (!_auth.isDemoSession) rethrow;
    }

    _fallbackCompanies.removeWhere((c) => c.id == id);
  }

  Future<Uint8List> exportCompaniesToExcel() async {
    final response = await http
        .get(
          Uri.parse('$_apiUrl/export/excel'),
          headers: _auth.getAuthHeaders({
            'Accept':
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/octet-stream, */*',
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    } else {
      throw Exception(
        'Failed to export companies to Excel (status: ${response.statusCode})',
      );
    }
  }

  Future<Uint8List> exportCompaniesToPdf() async {
    final response = await http
        .get(
          Uri.parse('$_apiUrl/export/pdf'),
          headers: _auth.getAuthHeaders({
            'Accept': 'application/pdf, application/octet-stream, */*',
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    } else {
      throw Exception(
        'Failed to export companies to PDF (status: ${response.statusCode})',
      );
    }
  }

  Future<Uint8List> exportCompanyProfilePdf(int id) async {
    final response = await http
        .get(
          Uri.parse('$_apiUrl/$id/export/pdf'),
          headers: _auth.getAuthHeaders({
            'Accept': 'application/pdf, application/octet-stream, */*',
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    } else {
      throw ApiException.fromResponse(
        response,
        fallbackMessage: 'Failed to export company PDF profile (status: ${response.statusCode})',
      );
    }
  }

  /// Scrape and discover products sold by a company from its official website
  Future<ScrapeProductsResponse> scrapeProductsFromWebsite(String url) async {
    final encoded = Uri.encodeQueryComponent(url);
    final endpoint = Uri.parse('$_apiUrl/scrape-products?url=$encoded');
    final response = await http
        .post(
          endpoint,
          headers: _auth.getAuthHeaders({'Accept': 'application/json'}),
        )
        .timeout(const Duration(seconds: 40));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return ScrapeProductsResponse.fromJson(decoded as Map<String, dynamic>);
    } else {
      String errMsg =
          'Failed to scrape products from website (status: ${response.statusCode})';
      try {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['message'] != null) {
          errMsg = decoded['message'].toString();
        }
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  String getFileUrl(String? path) {
    return _config.getFileUrl(path);
  }
}
