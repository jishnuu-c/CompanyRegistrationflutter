import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import 'api_config.dart';

class ProductService {
  final ApiConfig _config = ApiConfig();

  String get _apiUrl => '${_config.apiUrl}/products';

  Future<List<ProductResponse>> getAllProducts() async {
    final response = await http.get(
      Uri.parse('$_apiUrl/get-all'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is List) {
        return decoded.map((e) => ProductResponse.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } else {
      throw Exception('Failed to load products (status: ${response.statusCode})');
    }
  }

  Future<ProductResponse> getProductById(int id) async {
    final response = await http.get(
      Uri.parse('$_apiUrl/$id'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return ProductResponse.fromJson(decoded as Map<String, dynamic>);
    } else {
      throw Exception('Failed to load product #$id (status: ${response.statusCode})');
    }
  }

  Future<ProductResponse> createProduct(
    ProductRequest productData, {
    Uint8List? fileBytes,
    String? fileName,
    String? filePath,
  }) async {
    final uri = Uri.parse('$_apiUrl/create');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json';

    final jsonStr = jsonEncode(productData.toJson());
    request.files.add(http.MultipartFile.fromString(
      'productRequestDto',
      jsonStr,
      contentType: http.MediaType('application', 'json'),
    ));
    request.files.add(http.MultipartFile.fromString(
      'data',
      jsonStr,
      contentType: http.MediaType('application', 'json'),
    ));

    if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName ?? 'product_image.png',
      ));
    } else if (filePath != null && !kIsWeb) {
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
      ));
    }

    final streamed = await request.send().timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return ProductResponse.fromJson(decoded as Map<String, dynamic>);
    } else {
      final body = response.body;
      throw Exception('Failed to create product: $body');
    }
  }

  Future<ProductResponse> updateProduct(
    int id,
    ProductRequest productData, {
    Uint8List? fileBytes,
    String? fileName,
    String? filePath,
  }) async {
    final uri = Uri.parse('$_apiUrl/update/$id');
    final request = http.MultipartRequest('PUT', uri);
    request.headers['Accept'] = 'application/json';

    final jsonStr = jsonEncode(productData.toJson());
    request.files.add(http.MultipartFile.fromString(
      'productRequestDto',
      jsonStr,
      contentType: http.MediaType('application', 'json'),
    ));
    request.files.add(http.MultipartFile.fromString(
      'data',
      jsonStr,
      contentType: http.MediaType('application', 'json'),
    ));

    if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName ?? 'product_image.png',
      ));
    } else if (filePath != null && !kIsWeb) {
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
      ));
    }

    final streamed = await request.send().timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return ProductResponse.fromJson(decoded as Map<String, dynamic>);
    } else {
      final body = response.body;
      throw Exception('Failed to update product: $body');
    }
  }

  Future<void> deleteProduct(int id) async {
    final response = await http.delete(
      Uri.parse('$_apiUrl/delete/$id'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      throw Exception('Failed to delete product #$id');
    }
  }

  String getFileUrl(String? path) {
    return _config.getFileUrl(path);
  }
}
