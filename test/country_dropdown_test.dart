import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:company_reg_flutter/widgets/country_dropdown.dart';
import 'package:company_reg_flutter/screens/company_screen.dart';

void main() {
  group('SearchableCountryDropdown Angular Styling & Functionality Tests', () {
    testWidgets('renders SearchableCountryDropdown with Country Jurisdiction label and placeholder', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchableCountryDropdown(
              value: '',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check label and required asterisk
      expect(find.text('Country Jurisdiction'), findsOneWidget);
      expect(find.text('*'), findsOneWidget);

      // Check placeholder
      expect(find.text('Select Country...'), findsOneWidget);

      // Chevron down when closed
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('displays selected country badge and name in trigger field', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchableCountryDropdown(
              value: 'USA - United States',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('USA'), findsOneWidget);
      expect(find.text('United States'), findsOneWidget);
    });

    testWidgets('opens popup with search bar and countries matching Angular screenshot', (
      WidgetTester tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchableCountryDropdown(
              value: '',
              onChanged: (val) => selected = val,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap trigger to open dropdown popup
      await tester.tap(find.text('Select Country...'));
      await tester.pumpAndSettle();

      // Chevron flips to up
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

      // Search field is present with matching placeholder
      expect(find.text('Search country by code or name...'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      // Verify the Angular screenshot top countries and badges are rendered
      expect(find.text('USA'), findsWidgets);
      expect(find.text('United States'), findsWidgets);
      expect(find.text('KSA'), findsWidgets);
      expect(find.text('Saudi Arabia'), findsWidgets);
      expect(find.text('IND'), findsWidgets);
      expect(find.text('India'), findsWidgets);
      expect(find.text('UAE'), findsWidgets);
      expect(find.text('United Arab Emirates'), findsWidgets);
      expect(find.text('UK'), findsWidgets);
      expect(find.text('United Kingdom'), findsWidgets);
      expect(find.text('AFG'), findsWidgets);
      expect(find.text('Afghanistan'), findsWidgets);

      // Test searching/filtering by code: e.g. "KSA"
      await tester.enterText(find.byType(TextField), 'KSA');
      await tester.pumpAndSettle();

      expect(find.text('Saudi Arabia'), findsOneWidget);
      expect(find.text('United States'), findsNothing);

      // Tap Saudi Arabia to select
      await tester.tap(find.text('Saudi Arabia'));
      await tester.pumpAndSettle();

      // Popup is closed and value selected
      expect(selected, 'KSA - Saudi Arabia');
    });

    testWidgets('renders SearchableCountryDropdown within CompanyScreen Section 04', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CompanyScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // SearchableCountryDropdown is present
      expect(find.byType(SearchableCountryDropdown), findsOneWidget);
      expect(find.text('Country Jurisdiction'), findsOneWidget);
      expect(find.text('Select Country...'), findsOneWidget);
    });
  });
}
