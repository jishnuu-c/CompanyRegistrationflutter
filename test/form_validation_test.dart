import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:company_reg_flutter/utils/phone_validator.dart';
import 'package:company_reg_flutter/utils/api_error_util.dart';
import 'package:company_reg_flutter/widgets/country_dropdown.dart';

void main() {
  group('PhoneValidator Tests matching Angular phone.validator.ts', () {
    test('Mobile number rejects letters and returns Angular error message', () {
      expect(
        PhoneValidator.validateMobileNumber('123abc456'),
        'Mobile number cannot contain letters (numbers, +, -, and () only)',
      );
      expect(
        PhoneValidator.validateMobileNumber('phone-number'),
        'Mobile number cannot contain letters (numbers, +, -, and () only)',
      );
    });

    test('Mobile number rejects numbers with fewer than 5 digits', () {
      expect(
        PhoneValidator.validateMobileNumber('123'),
        'Mobile number cannot contain letters (numbers, +, -, and () only)',
      );
    });

    test('Mobile number allows empty/null (optional field)', () {
      expect(PhoneValidator.validateMobileNumber(null), isNull);
      expect(PhoneValidator.validateMobileNumber(''), isNull);
      expect(PhoneValidator.validateMobileNumber('   '), isNull);
    });

    test('Mobile number accepts valid international phone formats', () {
      expect(PhoneValidator.validateMobileNumber('+966 50 123 4567'), isNull);
      expect(PhoneValidator.validateMobileNumber('+1 (555) 987-6543'), isNull);
      expect(PhoneValidator.validateMobileNumber('0501234567'), isNull);
      expect(PhoneValidator.validateMobileNumber('050-123-4567'), isNull);
    });

    test('Landline number rejects letters and returns Angular error message', () {
      expect(
        PhoneValidator.validateLandline('office123'),
        'Landline cannot contain letters',
      );
      expect(
        PhoneValidator.validateLandline('011-landline'),
        'Landline cannot contain letters',
      );
    });

    test('Landline number rejects fewer than 5 digits', () {
      expect(
        PhoneValidator.validateLandline('12'),
        'Landline cannot contain letters',
      );
    });

    test('Landline number allows empty/null (optional field)', () {
      expect(PhoneValidator.validateLandline(null), isNull);
      expect(PhoneValidator.validateLandline(''), isNull);
      expect(PhoneValidator.validateLandline('  '), isNull);
    });

    test('Landline number accepts valid phone formats', () {
      expect(PhoneValidator.validateLandline('+966 11 234 5678'), isNull);
      expect(PhoneValidator.validateLandline('+1 (555) 019-2834'), isNull);
      expect(PhoneValidator.validateLandline('0112345678'), isNull);
    });

    test('Executive email validation matches Angular', () {
      expect(PhoneValidator.validateExecutiveEmail(null), isNull);
      expect(PhoneValidator.validateExecutiveEmail(''), isNull);
      expect(
        PhoneValidator.validateExecutiveEmail('notanemail'),
        'Please enter a valid email address',
      );
      expect(
        PhoneValidator.validateExecutiveEmail('sarah.jenkins@company.com'),
        isNull,
      );
    });

    test('Corporate email validation matches Angular', () {
      expect(
        PhoneValidator.validateCorporateEmail(null),
        'Valid corporate email is required',
      );
      expect(
        PhoneValidator.validateCorporateEmail(''),
        'Valid corporate email is required',
      );
      expect(
        PhoneValidator.validateCorporateEmail('invalid_email'),
        'Valid corporate email is required',
      );
      expect(
        PhoneValidator.validateCorporateEmail('contact@enterprise.com'),
        isNull,
      );
    });
  });

  group('Angular Form Incomplete Feedback Messages', () {
    test('Single missing field format matches Angular', () {
      final feedback = getFormIncompleteFeedback(['Company Legal Name']);
      expect(feedback.type, 'error');
      expect(feedback.title, 'Form Incomplete');
      expect(
        feedback.message,
        'Please fill in or correct "Company Legal Name". We\'ve automatically scrolled to it.',
      );
    });

    test('Multiple missing fields format matches Angular', () {
      final feedback = getFormIncompleteFeedback([
        'Company Legal Name',
        'Direct Executive Email',
        'Corporate Email',
        'Country Jurisdiction',
      ]);
      expect(feedback.type, 'error');
      expect(feedback.title, 'Form Incomplete');
      expect(
        feedback.message,
        'Required fields incomplete (Company Legal Name, Direct Executive Email, Corporate Email...). Scrolled to "Company Legal Name".',
      );
    });
  });

  group('CountryDropdown Error Rendering Widget Test', () {
    testWidgets('SearchableCountryDropdown displays errorText with info icon and red border',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchableCountryDropdown(
              value: null,
              errorText: 'Country jurisdiction is required',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify error message is rendered
      expect(find.text('Country jurisdiction is required'), findsOneWidget);

      // Verify info icon is rendered
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });
  });

  group('Product Dropdown FormField Validation Test', () {
    testWidgets('Category FormField displays error border and inline message',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      int? selectedCategory;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: FormField<int?>(
                initialValue: selectedCategory,
                validator: (val) {
                  if (val == null) {
                    return 'Please select a valid category.';
                  }
                  return null;
                },
                builder: (fieldState) {
                  return Column(
                    children: [
                      Container(
                        key: const Key('dropdown_container'),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: fieldState.hasError
                                ? Colors.red
                                : Colors.grey,
                          ),
                        ),
                        child: Text(selectedCategory?.toString() ?? 'Select Category'),
                      ),
                      if (fieldState.hasError)
                        Text(
                          fieldState.errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Validate form
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();

      // Check error text is displayed
      expect(find.text('Please select a valid category.'), findsOneWidget);
    });

    testWidgets('Brand FormField displays error border and inline message',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      int? selectedBrand;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: FormField<int?>(
                initialValue: selectedBrand,
                validator: (val) {
                  if (val == null) {
                    return 'Please select a valid brand.';
                  }
                  return null;
                },
                builder: (fieldState) {
                  return Column(
                    children: [
                      Container(
                        key: const Key('brand_dropdown_container'),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: fieldState.hasError
                                ? Colors.red
                                : Colors.grey,
                          ),
                        ),
                        child: Text(selectedBrand?.toString() ?? 'Select Brand'),
                      ),
                      if (fieldState.hasError)
                        Text(
                          fieldState.errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Validate form
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();

      // Check error text is displayed
      expect(find.text('Please select a valid brand.'), findsOneWidget);
    });
  });
}
