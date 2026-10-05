class BrandRequest {
  final String brandName;
  final bool isFeatured;

  BrandRequest({
    required this.brandName,
    this.isFeatured = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'brandName': brandName,
      'isFeatured': isFeatured,
      'featured': isFeatured,
    };
  }

  factory BrandRequest.fromJson(Map<String, dynamic> json) {
    return BrandRequest(
      brandName: json['brandName'] ?? json['brand_name'] ?? json['name'] ?? '',
      isFeatured: json['isFeatured'] ?? json['featured'] ?? false,
    );
  }
}

class BrandResponse {
  final int id;
  final String brandName;
  final String? brandLogo;
  final bool isFeatured;

  BrandResponse({
    required this.id,
    required this.brandName,
    this.brandLogo,
    this.isFeatured = false,
  });

  factory BrandResponse.fromJson(Map<String, dynamic> json) {
    return BrandResponse(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      brandName: json['brandName'] ?? json['brand_name'] ?? json['name'] ?? '',
      brandLogo: json['brandLogo'] ?? json['brand_logo'] ?? json['logo'] ?? json['image'],
      isFeatured: json['isFeatured'] ?? json['featured'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brandName': brandName,
      'brandLogo': brandLogo,
      'isFeatured': isFeatured,
      'featured': isFeatured,
    };
  }

  String get initials {
    if (brandName.trim().isEmpty) return 'B';
    final parts = brandName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
