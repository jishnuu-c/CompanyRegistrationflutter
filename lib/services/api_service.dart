import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/company_model.dart';

class ApiService extends ChangeNotifier {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _initLocalData();
  }

  // Base URL pointing to Laravel backend
  // In the user's screenshot, it is running at 192.168.1.201:8000
  String _baseUrl = 'http://192.168.1.201:8000';
  bool _isOnline = false;
  bool _isCheckingConnection = false;
  String _lastErrorMessage = '';

  String get baseUrl => _baseUrl;
  bool get isOnline => _isOnline;
  bool get isCheckingConnection => _isCheckingConnection;
  String get lastErrorMessage => _lastErrorMessage;

  // In-memory fallback dataset
  final List<Company> _localCompanies = [];
  final List<String> _localBrands = ['Lulu', 'Amazon', 'Apple', 'Samsung', 'Nestle', 'Unilever', 'Sony', 'Zara'];
  final List<String> _localProducts = ['Upp', 'Beverages', 'Electronics', 'Apparel', 'Dairy', 'Smartphones', 'Footwear', 'Groceries'];

  List<Company> get companies => List.unmodifiable(_localCompanies);
  List<String> get brands => List.unmodifiable(_localBrands);
  List<String> get products => List.unmodifiable(_localProducts);

  void setBaseUrl(String newUrl) {
    _baseUrl = newUrl.replaceAll(RegExp(r'/+$'), ''); // trim trailing slash
    notifyListeners();
    checkConnection();
  }

  Future<bool> checkConnection() async {
    _isCheckingConnection = true;
    _lastErrorMessage = '';
    notifyListeners();

    try {
      final endpoint = Uri.parse('$_baseUrl/api/companies');
      final response = await http.get(endpoint).timeout(const Duration(seconds: 3));
      
      if (response.statusCode >= 200 && response.statusCode < 400) {
        _isOnline = true;
        _lastErrorMessage = '';
      } else {
        // Even if 404 or 401, host is reachable
        _isOnline = response.statusCode != 502 && response.statusCode != 503;
      }
    } catch (e) {
      _isOnline = false;
      _lastErrorMessage = e.toString();
    } finally {
      _isCheckingConnection = false;
      notifyListeners();
    }
    return _isOnline;
  }

  // ----------------------------------------------------
  // Companies API
  // ----------------------------------------------------

  Future<List<Company>> getCompanies({String? searchQuery}) async {
    if (_isOnline) {
      try {
        final queryParam = searchQuery != null && searchQuery.isNotEmpty ? '?search=$searchQuery' : '';
        final response = await http.get(
          Uri.parse('$_baseUrl/api/companies$queryParam'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          List listData = [];
          if (data is List) {
            listData = data;
          } else if (data is Map && data['data'] is List) {
            listData = data['data'];
          } else if (data is Map && data['companies'] is List) {
            listData = data['companies'];
          }

          final fetched = listData.map((e) => Company.fromJson(e)).toList();
          _localCompanies.clear();
          _localCompanies.addAll(fetched);
          notifyListeners();
          return _localCompanies;
        }
      } catch (e) {
        debugPrint('API Error getCompanies: $e');
      }
    }

    // Fallback to local store
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      return _localCompanies.where((c) {
        return c.companyName.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q) ||
            c.country.toLowerCase().contains(q) ||
            c.city.toLowerCase().contains(q) ||
            c.brands.any((b) => b.toLowerCase().contains(q)) ||
            c.products.any((p) => p.toLowerCase().contains(q));
      }).toList();
    }
    return _localCompanies;
  }

  Future<Company> createCompany(Company company) async {
    if (_isOnline) {
      try {
        final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/companies'));
        request.headers['Accept'] = 'application/json';

        // Text fields
        request.fields['company_name'] = company.companyName;
        request.fields['email'] = company.email;
        request.fields['landline'] = company.landline;
        request.fields['website'] = company.website;
        request.fields['mobile'] = company.mobile;
        request.fields['country'] = company.country;
        request.fields['city'] = company.city;
        request.fields['full_address'] = company.fullAddress;
        request.fields['summary'] = company.summary;
        request.fields['rating'] = company.rating.toString();

        // Arrays
        for (int i = 0; i < company.brands.length; i++) {
          request.fields['brands[$i]'] = company.brands[i];
        }
        for (int i = 0; i < company.products.length; i++) {
          request.fields['products[$i]'] = company.products[i];
        }

        // Visiting card file
        if (company.visitingCardBytes != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'visiting_card',
            company.visitingCardBytes!,
            filename: company.visitingCardName ?? 'visiting_card.png',
          ));
        } else if (company.visitingCardPath != null && !kIsWeb) {
          request.files.add(await http.MultipartFile.fromPath(
            'visiting_card',
            company.visitingCardPath!,
            filename: company.visitingCardName,
          ));
        }

        // Multiple documents
        for (int i = 0; i < company.documents.length; i++) {
          final doc = company.documents[i];
          if (doc.bytes != null) {
            request.files.add(http.MultipartFile.fromBytes(
              'documents[]',
              doc.bytes!,
              filename: doc.name,
            ));
          } else if (doc.path != null && !kIsWeb) {
            request.files.add(await http.MultipartFile.fromPath(
              'documents[]',
              doc.path!,
              filename: doc.name,
            ));
          }
        }

        final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          final created = Company.fromJson(data is Map && data['data'] != null ? data['data'] : data);
          _localCompanies.insert(0, created);
          notifyListeners();
          return created;
        }
      } catch (e) {
        debugPrint('API Error createCompany: $e');
      }
    }

    // Local fallback creation
    final newId = (_localCompanies.isNotEmpty ? (_localCompanies.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b) + 1) : 1);
    final created = company.copyWith(
      id: newId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _localCompanies.insert(0, created);
    
    // Register any new brands or products
    for (var b in created.brands) {
      if (!_localBrands.contains(b)) _localBrands.add(b);
    }
    for (var p in created.products) {
      if (!_localProducts.contains(p)) _localProducts.add(p);
    }

    notifyListeners();
    return created;
  }

  Future<Company> updateCompany(Company company) async {
    if (company.id == null) return company;

    if (_isOnline) {
      try {
        final response = await http.put(
          Uri.parse('$_baseUrl/api/companies/${company.id}'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(company.toJson()),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final updated = Company.fromJson(data is Map && data['data'] != null ? data['data'] : data);
          final idx = _localCompanies.indexWhere((c) => c.id == updated.id);
          if (idx != -1) {
            _localCompanies[idx] = updated;
          }
          notifyListeners();
          return updated;
        }
      } catch (e) {
        debugPrint('API Error updateCompany: $e');
      }
    }

    final idx = _localCompanies.indexWhere((c) => c.id == company.id);
    if (idx != -1) {
      final updated = company.copyWith(updatedAt: DateTime.now());
      _localCompanies[idx] = updated;
      notifyListeners();
      return updated;
    }
    return company;
  }

  Future<bool> deleteCompany(int id) async {
    if (_isOnline) {
      try {
        final response = await http.delete(
          Uri.parse('$_baseUrl/api/companies/$id'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _localCompanies.removeWhere((c) => c.id == id);
          notifyListeners();
          return true;
        }
      } catch (e) {
        debugPrint('API Error deleteCompany: $e');
      }
    }

    _localCompanies.removeWhere((c) => c.id == id);
    notifyListeners();
    return true;
  }

  // ----------------------------------------------------
  // Dynamic Brands & Products
  // ----------------------------------------------------

  void addBrand(String brand) {
    final trimmed = brand.trim();
    if (trimmed.isNotEmpty && !_localBrands.contains(trimmed)) {
      _localBrands.add(trimmed);
      notifyListeners();
    }
  }

  void addProduct(String product) {
    final trimmed = product.trim();
    if (trimmed.isNotEmpty && !_localProducts.contains(trimmed)) {
      _localProducts.add(trimmed);
      notifyListeners();
    }
  }

  // ----------------------------------------------------
  // Initial Mock / Seed Data
  // ----------------------------------------------------
  void _initLocalData() {
    _localCompanies.addAll([
      Company(
        id: 1,
        companyName: 'Lulu Hypermarket LLC',
        visitingCardName: 'lulu_corp_card.png',
        visitingCardUrl: 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&auto=format&fit=crop&q=80',
        email: 'info@lulugroup.com',
        landline: '+971 2 4182000',
        website: 'https://www.luluhypermarket.com',
        mobile: '+971 50 1234567',
        country: 'United Arab Emirates',
        city: 'Abu Dhabi',
        fullAddress: 'Lulu Group International, Y Tower, Al Nahyan Military Camp Road, Abu Dhabi, UAE',
        brands: ['Lulu', 'Apple', 'Samsung', 'Nestle'],
        products: ['Upp', 'Beverages', 'Electronics', 'Dairy', 'Groceries'],
        documents: [
          DocumentItem(
            id: 'doc_1',
            name: 'Trade_License_2026.pdf',
            size: 1420000,
            extension: 'pdf',
          ),
          DocumentItem(
            id: 'doc_2',
            name: 'Tax_Registration_Certificate.pdf',
            size: 890000,
            extension: 'pdf',
          ),
          DocumentItem(
            id: 'doc_3',
            name: 'ISO_Certification.docx',
            size: 512000,
            extension: 'docx',
          ),
        ],
        summary: 'Lulu Group International is a highly diversified multinational conglomerate company with hypermarkets, retail stores, and food processing facilities across 23 countries.',
        rating: 4.8,
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
      ),
      Company(
        id: 2,
        companyName: 'Apex Apex Digital Solutions',
        visitingCardName: 'apex_card.png',
        visitingCardUrl: 'https://images.unsplash.com/photo-1557804506-669a67965ba0?w=600&auto=format&fit=crop&q=80',
        email: 'contact@apexdigital.io',
        landline: '+1 415 890 1200',
        website: 'https://flutter.dev',
        mobile: '+1 650 555 0199',
        country: 'United States',
        city: 'San Francisco',
        fullAddress: '425 Market Street, Suite 2200, San Francisco, CA 94105',
        brands: ['Amazon', 'Sony'],
        products: ['Electronics', 'Smartphones'],
        documents: [
          DocumentItem(
            id: 'doc_4',
            name: 'Corporate_ByLaws.pdf',
            size: 2100000,
            extension: 'pdf',
          ),
        ],
        summary: 'Leading cloud native software agency specializing in enterprise mobile applications, cloud infrastructures, and digital transformation.',
        rating: 4.5,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ]);
  }
}
