/// Saudi Arabia Major Cities Definition & Recognition Utility
///
/// Ported from Angular (src/app/core/utils/saudi-cities.util.ts)
/// Provides an authoritative list of major cities in the Kingdom of Saudi Arabia (KSA)
/// and robust matching routines to detect Saudi cities across transliterations,
/// prefixes (e.g. Al-, Ar-, At-), and common alternate spellings.

class SaudiCityInfo {
  final String canonicalName;
  final String arabicName;
  final String region;

  const SaudiCityInfo({
    required this.canonicalName,
    required this.arabicName,
    required this.region,
  });
}

const List<SaudiCityInfo> SAUDI_CITIES_REGISTRY = [
  SaudiCityInfo(canonicalName: 'Riyadh', arabicName: 'الرياض', region: 'Riyadh Province (Capital)'),
  SaudiCityInfo(canonicalName: 'Jeddah', arabicName: 'جدة', region: 'Makkah Province'),
  SaudiCityInfo(canonicalName: 'Mecca', arabicName: 'مكة المكرمة', region: 'Makkah Province'),
  SaudiCityInfo(canonicalName: 'Medina', arabicName: 'المدينة المنورة', region: 'Madinah Province'),
  SaudiCityInfo(canonicalName: 'Dammam', arabicName: 'الدمام', region: 'Eastern Province'),
  SaudiCityInfo(canonicalName: 'Khobar', arabicName: 'الخبر', region: 'Eastern Province'),
  SaudiCityInfo(canonicalName: 'Dhahran', arabicName: 'الظهران', region: 'Eastern Province'),
  SaudiCityInfo(canonicalName: 'Tabuk', arabicName: 'تبوك', region: 'Tabuk Province'),
  SaudiCityInfo(canonicalName: 'Taif', arabicName: 'الطائف', region: 'Makkah Province'),
  SaudiCityInfo(canonicalName: 'Buraidah', arabicName: 'بريدة', region: 'Al-Qassim Province'),
  SaudiCityInfo(canonicalName: 'Jubail', arabicName: 'الجبيل', region: 'Eastern Province'),
  SaudiCityInfo(canonicalName: 'Abha', arabicName: 'أبها', region: 'Asir Province'),
  SaudiCityInfo(canonicalName: 'Khamis Mushait', arabicName: 'خميس مشيط', region: 'Asir Province'),
  SaudiCityInfo(canonicalName: 'Hofuf', arabicName: 'الهفوف', region: 'Eastern Province (Al-Ahsa)'),
  SaudiCityInfo(canonicalName: 'Al-Ahsa', arabicName: 'الأحساء', region: 'Eastern Province'),
  SaudiCityInfo(canonicalName: 'Hail', arabicName: 'حائل', region: 'Hail Province'),
  SaudiCityInfo(canonicalName: 'Najran', arabicName: 'نجران', region: 'Najran Province'),
  SaudiCityInfo(canonicalName: 'Jazan', arabicName: 'جازان', region: 'Jazan Province'),
  SaudiCityInfo(canonicalName: 'Yanbu', arabicName: 'ينبع', region: 'Madinah Province'),
  SaudiCityInfo(canonicalName: 'Qatif', arabicName: 'القطيف', region: 'Eastern Province'),
  SaudiCityInfo(canonicalName: 'Unaizah', arabicName: 'عنيزة', region: 'Al-Qassim Province'),
  SaudiCityInfo(canonicalName: 'Al Kharj', arabicName: 'الخرج', region: 'Riyadh Province'),
  SaudiCityInfo(canonicalName: 'Al Bahah', arabicName: 'الباحة', region: 'Al Bahah Province'),
  SaudiCityInfo(canonicalName: 'Sakaka', arabicName: 'سكاكا', region: 'Al Jawf Province'),
  SaudiCityInfo(canonicalName: 'Arar', arabicName: 'عرعر', region: 'Northern Borders Province'),
  SaudiCityInfo(canonicalName: 'NEOM', arabicName: 'نيوم', region: 'Tabuk Province'),
  SaudiCityInfo(canonicalName: 'King Abdullah Economic City', arabicName: 'مدينة الملك عبدالله الاقتصادية', region: 'Makkah Province'),
  SaudiCityInfo(canonicalName: 'Ras Tanura', arabicName: 'رأس تنورة', region: 'Eastern Province'),
  SaudiCityInfo(canonicalName: 'Zulfi', arabicName: 'الزلفي', region: 'Riyadh Province'),
  SaudiCityInfo(canonicalName: 'Bisha', arabicName: 'بيشة', region: 'Asir Province'),
  SaudiCityInfo(canonicalName: 'Sharurah', arabicName: 'شرورة', region: 'Najran Province'),
  SaudiCityInfo(canonicalName: 'Wadi Al Dawasir', arabicName: 'وادي الدواسر', region: 'Riyadh Province'),
];

/// Clean list of canonical city names for dropdown suggestions
final List<String> SAUDI_MAJOR_CITIES =
    SAUDI_CITIES_REGISTRY.map((c) => c.canonicalName).toList();

/// Normalizes city string for lookup: lowercase, trims, removes punctuation,
/// and strips common Arabic article prefixes (al-, ar-, at-, ad-, az-, as-, ash-, an-).
String normalizeCityKey(String? val) {
  if (val == null || val.trim().isEmpty) return '';
  return val
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'''['"`\-_.,()]'''), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Pre-computed mapping of all known variants to canonical city names
final Map<String, String> CITY_ALIASES_MAP = _buildCityAliasesMap();

Map<String, String> _buildCityAliasesMap() {
  final map = <String, String>{};

  void register(String canonical, List<String> aliases) {
    final normCanonical = normalizeCityKey(canonical);
    map[normCanonical] = canonical;

    final prefixRegex = RegExp(r'^(al|ar|at|ad|az|as|ash|an)\s+');

    for (final alias in aliases) {
      final normAlias = normalizeCityKey(alias);
      map[normAlias] = canonical;

      final stripped = normAlias.replaceFirst(prefixRegex, '');
      if (stripped.isNotEmpty && stripped.length > 2) {
        map[stripped] = canonical;
      }
    }
  }

  // 1. Riyadh
  register('Riyadh', [
    'riyadh', 'ar riyadh', 'ar-riyadh', 'al riyadh', 'riyad', 'الرياض'
  ]);

  // 2. Jeddah
  register('Jeddah', [
    'jeddah', 'jiddah', 'jidda', 'jedda', 'جدة'
  ]);

  // 3. Mecca / Makkah
  register('Mecca', [
    'mecca', 'makkah', 'makkah al mukarramah', 'mecca al mukarramah',
    'macca', 'makkah almukarramah', 'مكة', 'مكة المكرمة'
  ]);

  // 4. Medina / Madinah
  register('Medina', [
    'medina', 'madinah', 'al madinah', 'al-madinah',
    'madinah al munawwarah', 'al madinah al munawwarah', 'المدينة', 'المدينة المنورة'
  ]);

  // 5. Dammam
  register('Dammam', [
    'dammam', 'ad dammam', 'ad-dammam', 'al dammam', 'الدمام'
  ]);

  // 6. Khobar
  register('Khobar', [
    'khobar', 'al khobar', 'al-khobar', 'alkhobar', 'al khobor', 'الخبر'
  ]);

  // 7. Dhahran
  register('Dhahran', [
    'dhahran', 'az zahran', 'ad dhahran', 'al dhahran', 'aldhahran', 'الظهران'
  ]);

  // 8. Tabuk
  register('Tabuk', [
    'tabuk', 'tabouk', 'تبوك'
  ]);

  // 9. Taif
  register('Taif', [
    'taif', 'al taif', 'at taif', 'at-taif', 'altaif', 'attaif', 'الطائف'
  ]);

  // 10. Buraidah
  register('Buraidah', [
    'buraidah', 'buraydah', 'buraida', 'al buraidah', 'بريدة'
  ]);

  // 11. Jubail
  register('Jubail', [
    'jubail', 'al jubail', 'al-jubail', 'aljubail', 'jubail industrial city', 'الجبيل'
  ]);

  // 12. Abha
  register('Abha', [
    'abha', 'أبها'
  ]);

  // 13. Khamis Mushait
  register('Khamis Mushait', [
    'khamis mushait', 'khamis mushayt', 'khamis mushate', 'khamis', 'خميس مشيط'
  ]);

  // 14. Hofuf & Al-Ahsa
  register('Hofuf', [
    'hofuf', 'al hofuf', 'al-hofuf', 'alhofuf', 'hufuf', 'الهفوف'
  ]);
  register('Al-Ahsa', [
    'al ahsa', 'al-ahsa', 'alahsa', 'al hasa', 'alhasa', 'al ahsaa', 'الأحساء'
  ]);

  // 15. Hail
  register('Hail', [
    'hail', "ha'il", 'hayil', 'حائل'
  ]);

  // 16. Najran
  register('Najran', [
    'najran', 'نجران'
  ]);

  // 17. Jazan
  register('Jazan', [
    'jazan', 'jizan', 'gizan', 'جازان', 'جيزان'
  ]);

  // 18. Yanbu
  register('Yanbu', [
    'yanbu', 'yanbu al bahr', 'yanbu industrial', 'ينبع'
  ]);

  // 19. Qatif
  register('Qatif', [
    'qatif', 'al qatif', 'al-qatif', 'alqatif', 'القطيف'
  ]);

  // 20. Unaizah
  register('Unaizah', [
    'unaizah', 'unayzah', 'onaizah', 'عنيزة'
  ]);

  // 21. Al Kharj
  register('Al Kharj', [
    'al kharj', 'al-kharj', 'alkharj', 'kharj', 'الخرج'
  ]);

  // 22. Al Bahah
  register('Al Bahah', [
    'al bahah', 'al-bahah', 'baha', 'al baha', 'albahah', 'albaha', 'الباحة'
  ]);

  // 23. Sakaka
  register('Sakaka', [
    'sakaka', 'sakakah', 'سكاكا'
  ]);

  // 24. Arar
  register('Arar', [
    'arar', "'ar'ar", 'عرعر'
  ]);

  // 25. NEOM
  register('NEOM', [
    'neom', 'نيوم'
  ]);

  // 26. King Abdullah Economic City
  register('King Abdullah Economic City', [
    'king abdullah economic city', 'kaec', 'مدينة الملك عبدالله الاقتصادية'
  ]);

  // 27. Ras Tanura
  register('Ras Tanura', [
    'ras tanura', 'ras tanurah', 'rastanura', 'رأس تنورة'
  ]);

  // 28. Zulfi
  register('Zulfi', [
    'zulfi', 'al zulfi', 'al-zulfi', 'alzulfi', 'الزلفي'
  ]);

  // 29. Bisha
  register('Bisha', [
    'bisha', 'bishah', 'بيشة'
  ]);

  // 30. Sharurah
  register('Sharurah', [
    'sharurah', 'sharorah', 'شرورة'
  ]);

  // 31. Wadi Al Dawasir
  register('Wadi Al Dawasir', [
    'wadi al dawasir', 'wadi al-dawasir', 'wadi addawasir', 'وادي الدواسر'
  ]);

  return map;
}

/// Checks if the given city name matches a recognized major city of Saudi Arabia.
///
/// Ported exactly from Angular `isSaudiCity`:
/// Returns true if recognized as a Saudi city, false otherwise.
bool isSaudiCity(String? city) {
  if (city == null) return false;
  final normalized = normalizeCityKey(city);
  if (normalized.isEmpty) return false;

  // Direct alias check
  if (CITY_ALIASES_MAP.containsKey(normalized)) {
    return true;
  }

  // Strip prefix (al, ar, at, ad, etc.) check
  final prefixRegex = RegExp(r'^(al|ar|at|ad|az|as|ash|an)\s+');
  final stripped = normalized.replaceFirst(prefixRegex, '');
  if (stripped.isNotEmpty && CITY_ALIASES_MAP.containsKey(stripped)) {
    return true;
  }

  // Partial/compound check if starts with a recognized city (e.g. "Riyadh, Central")
  for (final key in CITY_ALIASES_MAP.keys) {
    if (key.length >= 4 &&
        (normalized == key ||
            normalized.startsWith('$key ') ||
            normalized.endsWith(' $key'))) {
      return true;
    }
  }

  return false;
}

/// Returns the canonical Saudi city name if matched, or null if not a recognized Saudi city.
///
/// Ported exactly from Angular `getCanonicalSaudiCity`.
String? getCanonicalSaudiCity(String? city) {
  if (city == null) return null;
  final normalized = normalizeCityKey(city);
  if (normalized.isEmpty) return null;

  if (CITY_ALIASES_MAP.containsKey(normalized)) {
    return CITY_ALIASES_MAP[normalized];
  }

  final prefixRegex = RegExp(r'^(al|ar|at|ad|az|as|ash|an)\s+');
  final stripped = normalized.replaceFirst(prefixRegex, '');
  if (stripped.isNotEmpty && CITY_ALIASES_MAP.containsKey(stripped)) {
    return CITY_ALIASES_MAP[stripped];
  }

  for (final entry in CITY_ALIASES_MAP.entries) {
    if (entry.key.length >= 4 &&
        (normalized == entry.key ||
            normalized.startsWith('${entry.key} ') ||
            normalized.endsWith(' ${entry.key}'))) {
      return entry.value;
    }
  }

  return null;
}
