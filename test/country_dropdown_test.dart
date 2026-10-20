import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:company_reg_flutter/screens/company_screen.dart';

void main() {
  group('Section 04 Country Dropdown Tests', () {
    testWidgets('renders Country dropdown with USA - United States and options', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CompanyScreen(),
          ),
        ),
      );

      // Initial pump
      await tester.pump();

      // Find the DropdownButtonFormField for country
      final countryDropdownFinder = find.byType(
        DropdownButtonFormField<String>,
      );
      expect(countryDropdownFinder, findsWidgets);

      // Verify default displayed text has 'USA - United States'
      expect(find.text('USA - United States'), findsWidgets);
    });
  });
}
