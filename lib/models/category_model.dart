class CategoryRequest {
  final String name;
  final int? parentId;

  CategoryRequest({
    required this.name,
    this.parentId,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (parentId != null) 'parentId': parentId,
    };
  }

  factory CategoryRequest.fromJson(Map<String, dynamic> json) {
    return CategoryRequest(
      name: json['name'] ?? '',
      parentId: json['parentId'] is int
          ? json['parentId']
          : int.tryParse(json['parentId']?.toString() ?? ''),
    );
  }
}

class CategoryResponse {
  final int id;
  final String name;
  final String? categoryImage;
  final int? parentId;
  final String? parentName;

  CategoryResponse({
    required this.id,
    required this.name,
    this.categoryImage,
    this.parentId,
    this.parentName,
  });

  factory CategoryResponse.fromJson(Map<String, dynamic> json) {
    return CategoryResponse(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? '',
      categoryImage: json['categoryImage'] ?? json['category_image'] ?? json['image'],
      parentId: json['parentId'] is int
          ? json['parentId']
          : int.tryParse(json['parentId']?.toString() ?? ''),
      parentName: json['parentName'] ?? (json['parent'] != null ? json['parent']['name'] : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'categoryImage': categoryImage,
      'parentId': parentId,
      'parentName': parentName,
    };
  }

  CategoryResponse copyWith({
    int? id,
    String? name,
    String? categoryImage,
    int? parentId,
    String? parentName,
  }) {
    return CategoryResponse(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryImage: categoryImage ?? this.categoryImage,
      parentId: parentId ?? this.parentId,
      parentName: parentName ?? this.parentName,
    );
  }
}
