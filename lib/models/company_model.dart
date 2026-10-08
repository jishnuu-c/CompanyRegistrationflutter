import 'brand_model.dart';
import 'product_model.dart';

class CompanyRequest {
  final String companyName;
  final String email;
  final String? landline;
  final String? address;
  final String? city;
  final String? country;
  final String? website;
  final String? description;
  final String status;
  final String? contactName;
  final String? contactDesignation;
  final String? contactEmail;
  final String? contactMobileNumber;
  final List<int> brandIds;
  final List<int> productIds;

  CompanyRequest({
    required this.companyName,
    required this.email,
    this.landline,
    this.address,
    this.city,
    this.country,
    this.website,
    this.description,
    this.status = 'ACTIVE',
    this.contactName,
    this.contactDesignation,
    this.contactEmail,
    this.contactMobileNumber,
    this.brandIds = const [],
    this.productIds = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyName,
      'email': email,
      'landline': landline ?? '',
      'address': address ?? '',
      'city': city ?? '',
      'country': country ?? '',
      'website': website ?? '',
      'description': description ?? '',
      'status': status,
      'contactName': contactName ?? '',
      'contactDesignation': contactDesignation ?? '',
      'contactEmail': contactEmail ?? '',
      'contactMobileNumber': contactMobileNumber ?? '',
      'brandIds': brandIds,
      'productIds': productIds,
    };
  }

  factory CompanyRequest.fromJson(Map<String, dynamic> json) {
    return CompanyRequest(
      companyName: json['companyName'] ?? json['company_name'] ?? '',
      email: json['email'] ?? '',
      landline: json['landline'],
      address: json['address'],
      city: json['city'],
      country: json['country'],
      website: json['website'],
      description: json['description'],
      status: json['status'] ?? 'ACTIVE',
      contactName: json['contactName'] ?? json['contact_name'],
      contactDesignation: json['contactDesignation'] ?? json['contact_designation'],
      contactEmail: json['contactEmail'] ?? json['contact_email'],
      contactMobileNumber: json['contactMobileNumber'] ?? json['contact_mobile_number'],
      brandIds: json['brandIds'] != null
          ? List<int>.from(json['brandIds'].map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0))
          : const [],
      productIds: json['productIds'] != null
          ? List<int>.from(json['productIds'].map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0))
          : const [],
    );
  }
}

class CompanyResponse {
  final int id;
  final String companyName;
  final String email;
  final String? landline;
  final String? address;
  final String? city;
  final String? country;
  final String? website;
  final String? description;
  final String status;
  final String? businessCard;
  final List<String> businessCards;
  final String? contactName;
  final String? contactDesignation;
  final String? contactEmail;
  final String? contactMobileNumber;
  final String? createdAt;
  final String? updatedAt;
  final List<int> brandIds;
  final List<BrandResponse> brands;
  final List<int> productIds;
  final List<ProductResponse> products;

  CompanyResponse({
    required this.id,
    required this.companyName,
    required this.email,
    this.landline,
    this.address,
    this.city,
    this.country,
    this.website,
    this.description,
    this.status = 'ACTIVE',
    this.businessCard,
    this.businessCards = const [],
    this.contactName,
    this.contactDesignation,
    this.contactEmail,
    this.contactMobileNumber,
    this.createdAt,
    this.updatedAt,
    this.brandIds = const [],
    this.brands = const [],
    this.productIds = const [],
    this.products = const [],
  });

  List<String> get allCards {
    if (businessCards.isNotEmpty) return businessCards;
    if (businessCard != null && businessCard!.trim().isNotEmpty) {
      return [businessCard!.trim()];
    }
    return const [];
  }

  factory CompanyResponse.fromJson(Map<String, dynamic> json) {
    List<BrandResponse> parsedBrands = [];
    if (json['brands'] != null && json['brands'] is List) {
      parsedBrands = (json['brands'] as List)
          .map((b) => BrandResponse.fromJson(b is Map<String, dynamic> ? b : {}))
          .toList();
    }

    List<int> parsedBrandIds = [];
    if (json['brandIds'] != null && json['brandIds'] is List) {
      parsedBrandIds = (json['brandIds'] as List)
          .map((id) => id is int ? id : int.tryParse(id.toString()) ?? 0)
          .where((id) => id > 0)
          .toList();
    } else if (parsedBrands.isNotEmpty) {
      parsedBrandIds = parsedBrands.map((b) => b.id).toList();
    }

    List<ProductResponse> parsedProducts = [];
    if (json['products'] != null && json['products'] is List) {
      parsedProducts = (json['products'] as List)
          .map((p) => ProductResponse.fromJson(p is Map<String, dynamic> ? p : {}))
          .toList();
    }

    List<int> parsedProductIds = [];
    if (json['productIds'] != null && json['productIds'] is List) {
      parsedProductIds = (json['productIds'] as List)
          .map((id) => id is int ? id : int.tryParse(id.toString()) ?? 0)
          .where((id) => id > 0)
          .toList();
    } else if (parsedProducts.isNotEmpty) {
      parsedProductIds = parsedProducts.map((p) => p.id).toList();
    }

    List<String> parsedCards = [];
    if (json['businessCards'] is List) {
      parsedCards = (json['businessCards'] as List)
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }

    String? extractedBusinessCard;
    if (json['businessCard'] != null && json['businessCard'].toString().isNotEmpty) {
      extractedBusinessCard = json['businessCard'].toString();
    } else if (json['business_card'] != null && json['business_card'].toString().isNotEmpty) {
      extractedBusinessCard = json['business_card'].toString();
    } else if (json['visitingCard'] != null && json['visitingCard'].toString().isNotEmpty) {
      extractedBusinessCard = json['visitingCard'].toString();
    } else if (parsedCards.isNotEmpty) {
      extractedBusinessCard = parsedCards.first;
    }

    if (parsedCards.isEmpty && extractedBusinessCard != null && extractedBusinessCard.isNotEmpty) {
      parsedCards = [extractedBusinessCard];
    }

    return CompanyResponse(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      companyName: json['companyName']?.toString() ?? json['company_name']?.toString() ?? json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      landline: json['landline']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      country: json['country']?.toString(),
      website: json['website']?.toString(),
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      businessCard: extractedBusinessCard,
      businessCards: parsedCards,
      contactName: (json['contactName'] ?? json['contact_name'])?.toString(),
      contactDesignation: (json['contactDesignation'] ?? json['contact_designation'])?.toString(),
      contactEmail: (json['contactEmail'] ?? json['contact_email'])?.toString(),
      contactMobileNumber: (json['contactMobileNumber'] ?? json['contact_mobile_number'])?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      brandIds: parsedBrandIds,
      brands: parsedBrands,
      productIds: parsedProductIds,
      products: parsedProducts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyName': companyName,
      'email': email,
      'landline': landline,
      'address': address,
      'city': city,
      'country': country,
      'website': website,
      'description': description,
      'status': status,
      'businessCard': businessCard,
      'contactName': contactName,
      'contactDesignation': contactDesignation,
      'contactEmail': contactEmail,
      'contactMobileNumber': contactMobileNumber,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'brandIds': brandIds,
      'brands': brands.map((b) => b.toJson()).toList(),
      'productIds': productIds,
      'products': products.map((p) => p.toJson()).toList(),
    };
  }
}
