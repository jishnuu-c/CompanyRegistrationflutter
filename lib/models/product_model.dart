class ProductRequest {
  final String name;
  final String? description;
  final bool isFeatured;
  final int brandId;
  final int categoryId;
  final int? subCategoryId;

  ProductRequest({
    required this.name,
    this.description,
    this.isFeatured = false,
    required this.brandId,
    required this.categoryId,
    this.subCategoryId,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null && description!.isNotEmpty) 'description': description,
      'isFeatured': isFeatured,
      'featured': isFeatured,
      'brandId': brandId,
      'categoryId': categoryId,
      if (subCategoryId != null) 'subCategoryId': subCategoryId,
    };
  }

  factory ProductRequest.fromJson(Map<String, dynamic> json) {
    return ProductRequest(
      name: json['name'] ?? '',
      description: json['description'],
      isFeatured: json['isFeatured'] ?? json['featured'] ?? false,
      brandId: json['brandId'] is int ? json['brandId'] : int.tryParse(json['brandId']?.toString() ?? '0') ?? 0,
      categoryId: json['categoryId'] is int ? json['categoryId'] : int.tryParse(json['categoryId']?.toString() ?? '0') ?? 0,
      subCategoryId: json['subCategoryId'] is int
          ? json['subCategoryId']
          : int.tryParse(json['subCategoryId']?.toString() ?? ''),
    );
  }
}

class ProductResponse {
  final int id;
  final String name;
  final String? description;
  final String? image;
  final bool isFeatured;
  final int brandId;
  final String? brandName;
  final int categoryId;
  final String? categoryName;
  final int? subCategoryId;
  final String? subCategoryName;
  final String? createdAt;
  final String? updatedAt;

  ProductResponse({
    required this.id,
    required this.name,
    this.description,
    this.image,
    this.isFeatured = false,
    required this.brandId,
    this.brandName,
    required this.categoryId,
    this.categoryName,
    this.subCategoryId,
    this.subCategoryName,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductResponse.fromJson(Map<String, dynamic> json) {
    return ProductResponse(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      image: json['image'] ?? json['product_image'],
      isFeatured: json['isFeatured'] ?? json['featured'] ?? false,
      brandId: json['brandId'] is int
          ? json['brandId']
          : (json['brand'] != null && json['brand']['id'] != null
              ? (json['brand']['id'] as int)
              : int.tryParse(json['brandId']?.toString() ?? '0') ?? 0),
      brandName: json['brandName'] ?? (json['brand'] != null ? json['brand']['brandName'] : null),
      categoryId: json['categoryId'] is int
          ? json['categoryId']
          : (json['category'] != null && json['category']['id'] != null
              ? (json['category']['id'] as int)
              : int.tryParse(json['categoryId']?.toString() ?? '0') ?? 0),
      categoryName: json['categoryName'] ?? (json['category'] != null ? json['category']['name'] : null),
      subCategoryId: json['subCategoryId'] is int
          ? json['subCategoryId']
          : (json['subCategory'] != null && json['subCategory']['id'] != null
              ? (json['subCategory']['id'] as int)
              : int.tryParse(json['subCategoryId']?.toString() ?? '')),
      subCategoryName: json['subCategoryName'] ?? (json['subCategory'] != null ? json['subCategory']['name'] : null),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image': image,
      'isFeatured': isFeatured,
      'featured': isFeatured,
      'brandId': brandId,
      'brandName': brandName,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'subCategoryId': subCategoryId,
      'subCategoryName': subCategoryName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
