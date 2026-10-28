/// Phone and Email validator utilities replicating Angular's validation logic
/// (phone.validator.ts and standard Angular Validators).
class PhoneValidator {
  /// Validates contact mobile numbers matching Angular's phoneValidator()
  /// and error message in company-register.component.html:
  /// 'Mobile number cannot contain letters (numbers, +, -, and () only)'
  static String? validateMobileNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    final trimmed = value.trim();

    // Strictly reject any letters or words
    if (RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return 'Mobile number cannot contain letters (numbers, +, -, and () only)';
    }

    // Only allow digits and phone format symbols: +, -, (), spaces, .
    if (!RegExp(r'^[+]?[0-9\s\-().]{5,30}$').hasMatch(trimmed)) {
      return 'Mobile number cannot contain letters (numbers, +, -, and () only)';
    }

    // Must contain at least 5 numeric digits
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 5) {
      return 'Mobile number cannot contain letters (numbers, +, -, and () only)';
    }

    return null;
  }

  /// Validates landline numbers matching Angular's phoneValidator()
  /// and error message in company-register.component.html:
  /// 'Landline cannot contain letters'
  static String? validateLandline(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    final trimmed = value.trim();

    // Strictly reject any letters or words
    if (RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return 'Landline cannot contain letters';
    }

    // Only allow digits and phone format symbols: +, -, (), spaces, .
    if (!RegExp(r'^[+]?[0-9\s\-().]{5,30}$').hasMatch(trimmed)) {
      return 'Landline cannot contain letters';
    }

    // Must contain at least 5 numeric digits
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 5) {
      return 'Landline cannot contain letters';
    }

    return null;
  }

  /// Validates executive/contact email matching Angular's
  /// 'Please enter a valid email address' (optional field)
  static String? validateExecutiveEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    final trimmed = value.trim();
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates corporate email matching Angular's
  /// 'Valid corporate email is required'
  static String? validateCorporateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Valid corporate email is required';
    }
    final trimmed = value.trim();
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Valid corporate email is required';
    }
    return null;
  }
}
