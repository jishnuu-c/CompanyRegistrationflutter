import 'dart:convert';
import 'dart:typed_data';

class DocumentItem {
  final String id;
  final String name;
  final String? path;
  final Uint8List? bytes;
  final String? url;
  final int? size;
  final String? extension;

  DocumentItem({
    required this.id,
    required this.name,
    this.path,
    this.bytes,
    this.url,
    this.size,
    this.extension,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'url': url,
      'size': size,
      'extension': extension,
    };
  }

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    return DocumentItem(
      id: json['id']?.toString() ?? UniqueIdGenerator.generate(),
      name: json['name'] ?? json['file_name'] ?? 'Document',
      path: json['path'] ?? json['file_path'],
      url: json['url'] ?? json['file_url'],
      size: json['size'] is int ? json['size'] : int.tryParse(json['size']?.toString() ?? ''),
      extension: json['extension'] ?? json['ext'],
    );
  }

  String get formattedSize {
    if (size == null) return '';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class Company {
  final int? id;
  final String companyName;
  final String? visitingCardPath;
  final String? visitingCardUrl;
  final String? visitingCardName;
  final Uint8List? visitingCardBytes;
  final String email;
  final String landline;
  final String website;
  final String mobile;
  final String country;
  final String city;
  final String fullAddress;
  final List<String> brands;
  final List<String> products;
  final List<DocumentItem> documents;
  final String summary;
  final double rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Company({
    this.id,
    required this.companyName,
    this.visitingCardPath,
    this.visitingCardUrl,
    this.visitingCardName,
    this.visitingCardBytes,
    required this.email,
    required this.landline,
    required this.website,
    required this.mobile,
    required this.country,
    required this.city,
    required this.fullAddress,
    required this.brands,
    required this.products,
    required this.documents,
    required this.summary,
    required this.rating,
    this.createdAt,
    this.updatedAt,
  });

  Company copyWith({
    int? id,
    String? companyName,
    String? visitingCardPath,
    String? visitingCardUrl,
    String? visitingCardName,
    Uint8List? visitingCardBytes,
    String? email,
    String? landline,
    String? website,
    String? mobile,
    String? country,
    String? city,
    String? fullAddress,
    List<String>? brands,
    List<String>? products,
    List<DocumentItem>? documents,
    String? summary,
    double? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Company(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      visitingCardPath: visitingCardPath ?? this.visitingCardPath,
      visitingCardUrl: visitingCardUrl ?? this.visitingCardUrl,
      visitingCardName: visitingCardName ?? this.visitingCardName,
      visitingCardBytes: visitingCardBytes ?? this.visitingCardBytes,
      email: email ?? this.email,
      landline: landline ?? this.landline,
      website: website ?? this.website,
      mobile: mobile ?? this.mobile,
      country: country ?? this.country,
      city: city ?? this.city,
      fullAddress: fullAddress ?? this.fullAddress,
      brands: brands ?? this.brands,
      products: products ?? this.products,
      documents: documents ?? this.documents,
      summary: summary ?? this.summary,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_name': companyName,
      'visiting_card': visitingCardUrl ?? visitingCardPath,
      'visiting_card_name': visitingCardName,
      'email': email,
      'landline': landline,
      'website': website,
      'mobile': mobile,
      'country': country,
      'city': city,
      'full_address': fullAddress,
      'brands': brands,
      'products': products,
      'documents': documents.map((doc) => doc.toJson()).toList(),
      'summary': summary,
      'rating': rating,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Company.fromJson(Map<String, dynamic> json) {
    List<String> parsedBrands = [];
    if (json['brands'] != null) {
      if (json['brands'] is List) {
        parsedBrands = (json['brands'] as List)
            .map((e) => e is Map ? (e['name']?.toString() ?? e.toString()) : e.toString())
            .toList();
      } else if (json['brands'] is String) {
        try {
          final decoded = jsonDecode(json['brands']);
          if (decoded is List) {
            parsedBrands = decoded.map((e) => e.toString()).toList();
          } else {
            parsedBrands = json['brands'].toString().split(',').map((e) => e.trim()).toList();
          }
        } catch (_) {
          parsedBrands = json['brands'].toString().split(',').map((e) => e.trim()).toList();
        }
      }
    }

    List<String> parsedProducts = [];
    if (json['products'] != null) {
      if (json['products'] is List) {
        parsedProducts = (json['products'] as List)
            .map((e) => e is Map ? (e['name']?.toString() ?? e.toString()) : e.toString())
            .toList();
      } else if (json['products'] is String) {
        try {
          final decoded = jsonDecode(json['products']);
          if (decoded is List) {
            parsedProducts = decoded.map((e) => e.toString()).toList();
          } else {
            parsedProducts = json['products'].toString().split(',').map((e) => e.trim()).toList();
          }
        } catch (_) {
          parsedProducts = json['products'].toString().split(',').map((e) => e.trim()).toList();
        }
      }
    }

    List<DocumentItem> parsedDocs = [];
    if (json['documents'] != null) {
      if (json['documents'] is List) {
        parsedDocs = (json['documents'] as List)
            .map((doc) => doc is Map<String, dynamic>
                ? DocumentItem.fromJson(doc)
                : DocumentItem(id: UniqueIdGenerator.generate(), name: doc.toString()))
            .toList();
      }
    }

    return Company(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      companyName: json['company_name'] ?? json['companyName'] ?? json['name'] ?? '',
      visitingCardPath: json['visiting_card_path'],
      visitingCardUrl: json['visiting_card_url'] ?? json['visiting_card'],
      visitingCardName: json['visiting_card_name'],
      email: json['email'] ?? '',
      landline: json['landline'] ?? '',
      website: json['website'] ?? '',
      mobile: json['mobile'] ?? '',
      country: json['country'] ?? '',
      city: json['city'] ?? '',
      fullAddress: json['full_address'] ?? json['address'] ?? '',
      brands: parsedBrands,
      products: parsedProducts,
      documents: parsedDocs,
      summary: json['summary'] ?? json['description'] ?? '',
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}

class UniqueIdGenerator {
  static int _counter = 0;
  static String generate() => 'item_${DateTime.now().millisecondsSinceEpoch}_${++_counter}';
}
