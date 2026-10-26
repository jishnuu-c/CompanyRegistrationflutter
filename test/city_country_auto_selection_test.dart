import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:company_reg_flutter/screens/company_screen.dart';
import 'package:company_reg_flutter/widgets/city_autocomplete_field.dart';
import 'package:company_reg_flutter/widgets/country_dropdown.dart';

void main() {
  group('City & Country Auto-Selection Tests (Matching Angular Behavior)', () {
    testWidgets('CityAutocompleteField renders with label, placeholder, and suggestions', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController();
      String? selectedCity;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: CityAutocompleteField(
                controller: controller,
                onCitySelected: (val) => selectedCity = val,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify label and placeholder
      expect(find.text('City'), findsOneWidget);
      expect(find.text('e.g. Riyadh, Jeddah...'), findsOneWidget);

      // Tap on the text field to trigger suggestions dropdown
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      // Check that prominent Saudi cities from SAUDI_CITIES_REGISTRY appear in the overlay
      expect(find.text('Riyadh'), findsOneWidget);
      expect(find.text('الرياض'), findsOneWidget);
      expect(find.text('Jeddah'), findsOneWidget);
      expect(find.text('جدة'), findsOneWidget);

      // Tap on Riyadh
      await tester.tap(find.text('Riyadh'));
      await tester.pumpAndSettle();

      expect(controller.text, 'Riyadh');
      expect(selectedCity, 'Riyadh');

      controller.dispose();
    });

    testWidgets('SearchableCountryDropdown displays auto-country badge when isAutoCountrySelected is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchableCountryDropdown(
              value: 'KSA - Saudi Arabia',
              isAutoCountrySelected: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Auto-selected Saudi Arabia badge is visible
      expect(find.text('Auto-selected Saudi Arabia based on city'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets('SearchableCountryDropdown hides auto-country badge when isAutoCountrySelected is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchableCountryDropdown(
              value: 'USA - United States',
              isAutoCountrySelected: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Auto-selected Saudi Arabia based on city'), findsNothing);
    });

    testWidgets('Full CompanyScreen: typing a Saudi city auto-selects Saudi Arabia and shows badge', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CompanyScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the City field by placeholder
      final cityFinder = find.widgetWithText(TextFormField, 'e.g. Riyadh, Jeddah...');
      expect(cityFinder, findsOneWidget);

      // Initially, Country Jurisdiction placeholder is 'Select Country...' and no auto badge
      expect(find.text('Select Country...'), findsOneWidget);
      expect(find.text('Auto-selected Saudi Arabia based on city'), findsNothing);

      // Type "Riyadh" into the City field
      await tester.enterText(cityFinder, 'Riyadh');
      await tester.pumpAndSettle();

      // Country Jurisdiction should automatically become KSA - Saudi Arabia
      expect(find.text('KSA'), findsOneWidget);
      expect(find.text('Saudi Arabia'), findsOneWidget);

      // The auto-selected badge is rendered
      expect(find.text('Auto-selected Saudi Arabia based on city'), findsOneWidget);

      // Now clear the city field
      await tester.enterText(cityFinder, '');
      await tester.pumpAndSettle();

      // Badge disappears when city is cleared
      expect(find.text('Auto-selected Saudi Arabia based on city'), findsNothing);

      // Re-type "Jeddah"
      await tester.enterText(cityFinder, 'Jeddah');
      await tester.pumpAndSettle();

      expect(find.text('Saudi Arabia'), findsOneWidget);
      expect(find.text('Auto-selected Saudi Arabia based on city'), findsOneWidget);

      // Manually click the Country dropdown and change to United States
      await tester.tap(find.text('Saudi Arabia'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('United States'));
      await tester.pumpAndSettle();

      // Country is now United States and the auto badge is cleared
      expect(find.text('United States'), findsOneWidget);
      expect(find.text('Auto-selected Saudi Arabia based on city'), findsNothing);
    });

    testWidgets('Full CompanyScreen: typing a non-Saudi city does not auto-select country', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CompanyScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final cityFinder = find.widgetWithText(TextFormField, 'e.g. Riyadh, Jeddah...');
      expect(cityFinder, findsOneWidget);

      // Type non-Saudi city "London"
      await tester.enterText(cityFinder, 'London');
      await tester.pumpAndSettle();

      // Country jurisdiction remains unselected placeholder
      expect(find.text('Select Country...'), findsOneWidget);
      expect(find.text('Auto-selected Saudi Arabia based on city'), findsNothing);
    });
  });
}
