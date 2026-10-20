import '../models/ocr_model.dart';

class BusinessCardParserService {
  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );
  static final RegExp _urlRegex = RegExp(
    r'(?:https?:\/\/)?(?:www\.)?([a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:\/[^\s]*)?)',
    caseSensitive: false,
  );
  static final RegExp _phoneRegex = RegExp(
    r'(?:(?:\+|00)\d{1,4}[-.\s]*)?(?:\(?\d{2,5}\)?[-.\s]*)?\d{3,4}[-.\s]*\d{3,4}',
  );

  // Specific job titles / designations have higher priority
  static const List<String> _highPriorityDesignations = [
    'chief executive officer',
    'ceo',
    'chief technology officer',
    'cto',
    'chief operating officer',
    'coo',
    'chief financial officer',
    'cfo',
    'managing director',
    'director',
    'general manager',
    'vice president',
    'vp',
    'president',
    'founder',
    'co-founder',
    'owner',
    'partner',
    'principal',
    'realtor',
    'real estate agent',
    'real estate broker',
    'broker',
    'attorney',
    'lawyer',
    'physician',
    'doctor',
    'accountant',
    'lead engineer',
    'software engineer',
    'senior engineer',
    'engineer',
    'project manager',
    'product manager',
    'marketing manager',
    'sales manager',
    'account manager',
    'business development manager',
    'creative director',
    'consultant',
    'senior consultant',
    'specialist',
    'architect',
  ];

  static const List<String> _commonDesignations = [
    ..._highPriorityDesignations,
    'manager',
    'executive',
    'supervisor',
    'agent',
    'representative',
    'sales representative',
    'associate',
    'advisor',
    'coordinator',
    'developer',
    'designer',
    'analyst',
    'real estate',
    'sales',
  ];

  static const List<String> _companySuffixes = [
    'inc',
    'inc.',
    'llc',
    'ltd',
    'ltd.',
    'corp',
    'corp.',
    'corporation',
    'technologies',
    'technology',
    'solutions',
    'systems',
    'group',
    'enterprises',
    'industries',
    'holdings',
    'services',
    'consulting',
    'global',
    'international',
    'pvt ltd',
    'pvt. ltd.',
    'co.',
    'company',
    'studios',
    'labs',
    'ventures',
    'professionals',
    'realty',
    'properties',
    'agency',
    'associates',
    'partners',
    'clinic',
    'center',
    'centre',
    'network',
  ];

  static const List<String> _nonPersonWords = [
    'catalogue',
    'catalog',
    'pages',
    'page',
    'screenshot',
    'settings',
    'battery',
    'menu',
    'deals',
    'weekly',
    'daily',
    'total',
    'header',
    'footer',
    'price',
    'product',
    'products',
    'items',
    'item',
    'details',
    'home',
    'search',
    'notification',
    'notifications',
    'order',
    'orders',
    'profile',
    'account',
    'status',
    'wifi',
    'bluetooth',
    'camera',
    'photo',
  ];

  static const List<String> _countries = [
    'united states',
    'usa',
    'us',
    'united kingdom',
    'uk',
    'canada',
    'australia',
    'india',
    'germany',
    'france',
    'singapore',
    'united arab emirates',
    'uae',
    'japan',
    'netherlands',
    'switzerland',
    'saudi arabia',
    'qatar',
    'malaysia',
  ];

  BusinessCardScanResult parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return BusinessCardScanResult(
        confidenceScore: 0,
        rawText: '',
        lines: const [],
        isLowConfidence: true,
      );
    }

    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim().replaceAll(RegExp(r'[®©™]'), ''))
        .where((l) => l.isNotEmpty)
        .toList();

    final result = BusinessCardScanResult(rawText: rawText, lines: lines);

    final claimedIndices = <int>{};

    // 1. Extract Emails
    final foundEmails = <String>[];
    for (int i = 0; i < lines.length; i++) {
      final matches = _emailRegex.allMatches(lines[i]);
      if (matches.isNotEmpty) {
        for (final m in matches) {
          final email = m.group(0)?.trim();
          if (email != null && email.isNotEmpty) {
            foundEmails.add(email);
          }
        }
        claimedIndices.add(i);
      }
    }

    if (foundEmails.isNotEmpty) {
      result.email = foundEmails.first;
      result.contactEmail = foundEmails.length > 1
          ? foundEmails[1]
          : foundEmails.first;
    }

    // 2. Extract Website
    for (int i = 0; i < lines.length; i++) {
      if (result.website != null) break;
      if (lines[i].contains('@')) continue;

      final match = _urlRegex.firstMatch(lines[i]);
      if (match != null) {
        final matchedStr = match.group(0)?.trim() ?? '';
        if (!matchedStr.toLowerCase().startsWith('mailto:')) {
          var url = matchedStr;
          if (!url.startsWith('http://') && !url.startsWith('https://')) {
            url = 'https://$url';
          }
          result.website = url;
          claimedIndices.add(i);
        }
      }
    }

    // 3. Extract Phone & Landline
    final phoneCandidates = <_PhoneCandidate>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Skip lines that look like pure timestamps (e.g. 15:34 or 10:46)
      if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(line)) continue;

      final hasMobileCue = RegExp(
        r'\b(m|mob|mobile|cell|c)\b[:.]?',
        caseSensitive: false,
      ).hasMatch(line);
      final hasLandlineCue = RegExp(
        r'\b(t|tel|phone|office|ph|fax|landline|o)\b[:.]?',
        caseSensitive: false,
      ).hasMatch(line);

      final matches = _phoneRegex.allMatches(line);
      for (final m in matches) {
        final phoneStr = m.group(0)?.trim() ?? '';
        final cleanPhone = phoneStr
            .replaceAll(RegExp(r'[^\d+()\-\s]'), '')
            .trim();
        final digitsOnly = cleanPhone.replaceAll(RegExp(r'\D'), '');
        if (digitsOnly.length >= 7) {
          phoneCandidates.add(
            _PhoneCandidate(
              phone: cleanPhone,
              isMobile:
                  hasMobileCue ||
                  (!hasLandlineCue && cleanPhone.startsWith('+')),
              lineIdx: i,
            ),
          );
          claimedIndices.add(i);
        }
      }
    }

    if (phoneCandidates.isNotEmpty) {
      final mobile = phoneCandidates.firstWhere(
        (p) => p.isMobile,
        orElse: () => phoneCandidates.first,
      );
      result.contactMobileNumber = mobile.phone;

      final landlines = phoneCandidates
          .where((p) => p.phone != mobile.phone)
          .toList();
      if (landlines.isNotEmpty) {
        result.landline = landlines.first.phone;
      }
    }

    // 4. Extract Designation / Job Title (High Priority first)
    int designationLineIdx = -1;
    for (final desig in _highPriorityDesignations) {
      for (int i = 0; i < lines.length; i++) {
        if (claimedIndices.contains(i)) continue;
        final lower = lines[i].toLowerCase().trim();
        if (lower == desig ||
            RegExp(
              '\\b${RegExp.escape(desig)}\\b',
              caseSensitive: false,
            ).hasMatch(lower)) {
          result.contactDesignation = lines[i].trim();
          designationLineIdx = i;
          claimedIndices.add(i);
          break;
        }
      }
      if (result.contactDesignation != null) break;
    }

    if (result.contactDesignation == null) {
      for (final desig in _commonDesignations) {
        for (int i = 0; i < lines.length; i++) {
          if (claimedIndices.contains(i)) continue;
          final lower = lines[i].toLowerCase().trim();
          if (lower == desig ||
              RegExp(
                '\\b${RegExp.escape(desig)}\\b',
                caseSensitive: false,
              ).hasMatch(lower)) {
            result.contactDesignation = lines[i].trim();
            designationLineIdx = i;
            claimedIndices.add(i);
            break;
          }
        }
        if (result.contactDesignation != null) break;
      }
    }

    // 5. Extract Contact Name
    // A) Line directly above designation
    if (designationLineIdx > 0 &&
        !claimedIndices.contains(designationLineIdx - 1)) {
      final candidateAbove = lines[designationLineIdx - 1];
      if (_isValidPersonName(candidateAbove)) {
        result.contactName = candidateAbove;
        claimedIndices.add(designationLineIdx - 1);
      }
    }

    // B) Line directly below designation
    if (result.contactName == null &&
        designationLineIdx >= 0 &&
        designationLineIdx + 1 < lines.length) {
      if (!claimedIndices.contains(designationLineIdx + 1)) {
        final candidateBelow = lines[designationLineIdx + 1];
        if (_isValidPersonName(candidateBelow)) {
          result.contactName = candidateBelow;
          claimedIndices.add(designationLineIdx + 1);
        }
      }
    }

    // C) Scan all lines for prominent person name (2-3 words)
    if (result.contactName == null) {
      for (int i = 0; i < lines.length; i++) {
        if (claimedIndices.contains(i)) continue;
        if (_isValidPersonName(lines[i])) {
          result.contactName = lines[i];
          claimedIndices.add(i);
          break;
        }
      }
    }

    // 6. Extract Company Name
    bool hasCompanyWithSuffix = false;
    for (int i = 0; i < lines.length; i++) {
      if (claimedIndices.contains(i)) continue;
      final lower = lines[i].toLowerCase();

      final hasSuffix = _companySuffixes.any(
        (s) => RegExp(
          '\\b${RegExp.escape(s)}\\b',
          caseSensitive: false,
        ).hasMatch(lower),
      );
      if (hasSuffix) {
        result.companyName = lines[i].trim();
        hasCompanyWithSuffix = true;
        claimedIndices.add(i);
        break;
      }
    }

    final hasAnyCardCues =
        result.email != null ||
        result.contactMobileNumber != null ||
        result.landline != null ||
        result.contactName != null ||
        result.contactDesignation != null ||
        result.website != null;

    if (result.companyName == null && hasAnyCardCues) {
      for (int i = 0; i < lines.length; i++) {
        if (!claimedIndices.contains(i)) {
          final text = lines[i].trim();
          // Skip timestamps (e.g. 15:34) or strings without letters
          if (RegExp(r':').hasMatch(text) ||
              !RegExp(r'[A-Za-z]').hasMatch(text)) {
            continue;
          }
          if (!RegExp(r'\d{3,}').hasMatch(text) &&
              text.length > 2 &&
              text.length < 60) {
            result.companyName = text;
            claimedIndices.add(i);
            break;
          }
        }
      }
    }

    // 7. Extract Address, City, Country
    final remainingLines = <String>[];
    for (int i = 0; i < lines.length; i++) {
      if (!claimedIndices.contains(i)) {
        remainingLines.add(lines[i]);
      }
    }

    if (remainingLines.isNotEmpty && hasAnyCardCues) {
      // Find Country
      for (final line in remainingLines) {
        final lower = line.toLowerCase();
        for (final country in _countries) {
          if (RegExp(
            '\\b${RegExp.escape(country)}\\b',
            caseSensitive: false,
          ).hasMatch(lower)) {
            result.country = _formatCountryName(country);
            break;
          }
        }
        if (result.country != null) break;
      }

      // City heuristics (e.g. "Anytown, US 12345" or "New York, NY 10001")
      for (final line in remainingLines) {
        final parts = line.split(',').map((p) => p.trim()).toList();
        if (parts.length >= 2) {
          result.city = parts[0].replaceAll(RegExp(r'\d+'), '').trim();
          if (result.country == null &&
              (line.toLowerCase().contains('us') ||
                  line.toLowerCase().contains('usa'))) {
            result.country = 'United States';
          }
          break;
        }
      }

      // Address: look for street/suite/lane/box or digit+word
      final addressLines = remainingLines
          .where(
            (l) =>
                RegExp(
                  r'\b(st|street|ave|avenue|rd|road|blvd|boulevard|suite|ste|floor|fl|building|bldg|box|po box|lane|ln|drive|dr|way|plaza|tower)\b',
                  caseSensitive: false,
                ).hasMatch(l) ||
                RegExp(r'\d+\s+[A-Za-z]+').hasMatch(l),
          )
          .toList();

      if (addressLines.isNotEmpty) {
        result.address = addressLines.first;
      } else if (remainingLines.isNotEmpty &&
          result.city != remainingLines.first) {
        result.address = remainingLines.first;
      }
    }

    // 8. Strict Confidence Score (0 to 100)
    int score = 0;
    if (result.email != null) score += 25;
    if (result.contactMobileNumber != null) score += 20;
    if (result.landline != null) score += 10;
    if (result.contactName != null) score += 15;
    if (result.contactDesignation != null) score += 10;
    if (result.website != null) score += 10;
    if (result.address != null || result.city != null || result.country != null)
      score += 10;

    if (hasCompanyWithSuffix) {
      score += 20;
    } else if (result.companyName != null && hasAnyCardCues) {
      score += 10;
    }

    // If an image had no phone, no email, and no person name, it's not a recognizable business card
    if (result.email == null &&
        result.contactMobileNumber == null &&
        result.landline == null &&
        result.contactName == null) {
      score = hasCompanyWithSuffix ? 25 : 0;
    }

    result.confidenceScore = score.clamp(0, 100);
    result.isLowConfidence = result.confidenceScore < 40;

    return result;
  }

  bool _isValidPersonName(String? str) {
    if (str == null || str.trim().isEmpty) return false;
    final clean = str.trim().replaceAll(RegExp(r'[®©™]'), '');
    if (clean.length < 3 || clean.length > 40) return false;
    // Reject digits, timestamps, and special characters
    if (RegExp(r'\d').hasMatch(clean)) return false;
    if (RegExp(r'[@#$%^&*()_+={}\[\]:;"\x27<>?/\\|]').hasMatch(clean))
      return false;

    final lower = clean.toLowerCase();
    // Reject if it contains common company suffixes
    if (_companySuffixes.any(
      (s) => RegExp(
        '\\b${RegExp.escape(s)}\\b',
        caseSensitive: false,
      ).hasMatch(lower),
    )) {
      return false;
    }

    // Reject common generic non-name words (e.g. Catalogue Pages, Screenshot, Deals, etc.)
    if (_nonPersonWords.any(
      (w) => RegExp(
        '\\b${RegExp.escape(w)}\\b',
        caseSensitive: false,
      ).hasMatch(lower),
    )) {
      return false;
    }

    final words = clean
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    return words.length >= 2 && words.length <= 4;
  }

  String _formatCountryName(String country) {
    if (country == 'usa' || country == 'us') return 'United States';
    if (country == 'uk') return 'United Kingdom';
    if (country == 'uae') return 'United Arab Emirates';
    return country
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class _PhoneCandidate {
  final String phone;
  final bool isMobile;
  final int lineIdx;

  _PhoneCandidate({
    required this.phone,
    required this.isMobile,
    required this.lineIdx,
  });
}
