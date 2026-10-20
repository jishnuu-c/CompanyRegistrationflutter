class BusinessCardScanResult {
  String? companyName;
  String? contactName;
  String? contactDesignation;
  String? email;
  String? contactEmail;
  String? contactMobileNumber;
  String? landline;
  String? website;
  String? address;
  String? city;
  String? country;
  String? description;
  int confidenceScore;
  String rawText;
  List<String> lines;
  bool isLowConfidence;

  BusinessCardScanResult({
    this.companyName,
    this.contactName,
    this.contactDesignation,
    this.email,
    this.contactEmail,
    this.contactMobileNumber,
    this.landline,
    this.website,
    this.address,
    this.city,
    this.country,
    this.description,
    this.confidenceScore = 0,
    this.rawText = '',
    this.lines = const [],
    this.isLowConfidence = false,
  });

  bool get hasAnyExtractedFields {
    return (companyName != null && companyName!.trim().isNotEmpty) ||
        (contactName != null && contactName!.trim().isNotEmpty) ||
        (contactDesignation != null && contactDesignation!.trim().isNotEmpty) ||
        (email != null && email!.trim().isNotEmpty) ||
        (contactEmail != null && contactEmail!.trim().isNotEmpty) ||
        (contactMobileNumber != null &&
            contactMobileNumber!.trim().isNotEmpty) ||
        (landline != null && landline!.trim().isNotEmpty) ||
        (website != null && website!.trim().isNotEmpty) ||
        (address != null && address!.trim().isNotEmpty) ||
        (city != null && city!.trim().isNotEmpty) ||
        (country != null && country!.trim().isNotEmpty);
  }

  BusinessCardScanResult copyWith({
    String? companyName,
    String? contactName,
    String? contactDesignation,
    String? email,
    String? contactEmail,
    String? contactMobileNumber,
    String? landline,
    String? website,
    String? address,
    String? city,
    String? country,
    String? description,
    int? confidenceScore,
    String? rawText,
    List<String>? lines,
    bool? isLowConfidence,
  }) {
    return BusinessCardScanResult(
      companyName: companyName ?? this.companyName,
      contactName: contactName ?? this.contactName,
      contactDesignation: contactDesignation ?? this.contactDesignation,
      email: email ?? this.email,
      contactEmail: contactEmail ?? this.contactEmail,
      contactMobileNumber: contactMobileNumber ?? this.contactMobileNumber,
      landline: landline ?? this.landline,
      website: website ?? this.website,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      description: description ?? this.description,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      rawText: rawText ?? this.rawText,
      lines: lines ?? this.lines,
      isLowConfidence: isLowConfidence ?? this.isLowConfidence,
    );
  }
}
