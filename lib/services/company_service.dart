import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/company_model.dart';
import 'api_config.dart';
import 'auth_service.dart';

class CompanyService {
  final ApiConfig _config = ApiConfig();
  final AuthService _auth = AuthService();

  String get _apiUrl => '${_config.apiUrl}/companies';

  Future<List<CompanyResponse>> getAllCompanies() async {
    final response = await http
        .get(
          Uri.parse('$_apiUrl/get-all'),
          headers: _auth.getAuthHeaders({'Accept': 'application/json'}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is List) {
        return decoded
            .map((e) => CompanyResponse.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } else {
      throw Exception(
        'Failed to load companies (status: ${response.statusCode})',
      );
    }
  }

  Future<CompanyResponse> getCompanyById(int id) async {
    final response = await http
        .get(Uri.parse('$_apiUrl/$id'),
            headers: _auth.getAuthHeaders({'Accept': 'application/json'}))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return CompanyResponse.fromJson(decoded as Map<String, dynamic>);
    } else {
      throw Exception(
        'Failed to load company #$id (status: ${response.statusCode})',
      );
    }
  }

  Future<CompanyResponse> createCompany(
    CompanyRequest companyData, {
    Uint8List? fileBytes,
    String? fileName,
    String? filePath,
  }) async {
    final uri = Uri.parse('$_apiUrl/create');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_auth.getAuthHeaders({'Accept': 'application/json'}));

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
    } else {
      final body = response.body;
      throw Exception('Failed to create company: $body');
    }
  }

  Future<CompanyResponse> updateCompany(
    int id,
    CompanyRequest companyData, {
    Uint8List? fileBytes,
    String? fileName,
    String? filePath,
  }) async {
    final uri = Uri.parse('$_apiUrl/update/$id');
    final request = http.MultipartRequest('PUT', uri);
    request.headers.addAll(_auth.getAuthHeaders({'Accept': 'application/json'}));

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
    } else {
      final body = response.body;
      throw Exception('Failed to update company: $body');
    }
  }

  Future<void> deleteCompany(int id) async {
    final response = await http
        .delete(
          Uri.parse('$_apiUrl/delete/$id'),
          headers: _auth.getAuthHeaders({'Accept': 'application/json'}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      throw Exception('Failed to delete company #$id');
    }
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
      throw Exception(
        'Failed to export company PDF profile (status: ${response.statusCode})',
      );
    }
  }

  String getFileUrl(String? path) {
    return _config.getFileUrl(path);
  }
}