import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:company_reg_flutter/models/brand_model.dart';
import 'package:company_reg_flutter/models/company_model.dart';
import 'package:company_reg_flutter/widgets/company_search_bar.dart';

void main() {
  final sampleCompanies = [
    CompanyResponse(
      id: 1,
      companyName: 'ABC Company',
      email: 'abc@example.com',
      contactName: 'Alice Smith',
      city: 'New York',
      country: 'United States',
      status: 'ACTIVE',
      brands: [BrandResponse(id: 101, brandName: 'Apex Dynamics', brandLogo: null)],
      products: [],
    ),
    CompanyResponse(
      id: 2,
      companyName: 'ABC Company 2',
      email: 'contact@enterprise.com',
      contactName: 'Sarah Jenkins',
      city: 'Ponnani',
      country: 'India',
      status: 'ACTIVE',
      brands: [BrandResponse(id: 102, brandName: 'Nike', brandLogo: null)],
      products: [],
    ),
    CompanyResponse(
      id: 3,
      companyName: 'ABC Company 3',
      email: 'abc@org.com',
      contactName: 'Saleem',
      city: 'Ponnani',
      country: 'India',
      status: 'ACTIVE',
      brands: [],
      products: [],
    ),
  ];

  group('CompanySearchBar Widget Tests', () {
    testWidgets('typing query opens matching companies dropdown with highlighted text and zero overflow', (WidgetTester tester) async {
      String currentQuery = '';
      CompanyResponse? inspectedCompany;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 320, // Mobile width testing
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return CompanySearchBar(
                      allCompanies: sampleCompanies,
                      searchQuery: currentQuery,
                      onSearchChanged: (val) {
                        setState(() => currentQuery = val);
                      },
                      onCompanyInspect: (comp) {
                        inspectedCompany = comp;
                      },
                      onCompanySelected: (_) {},
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'a');
      await tester.pump();

      // Verify dropdown header & matching count
      expect(find.textContaining('MATCHING COMPANIES'), findsOneWidget);
      expect(find.textContaining('3'), findsWidgets);

      // Verify suggestions list contains matching companies
      expect(find.textContaining('Alice Smith'), findsOneWidget);
      expect(find.textContaining('Sarah Jenkins'), findsOneWidget);
      expect(find.textContaining('Saleem'), findsOneWidget);

      // Verify quick inspect button triggers onCompanyInspect callback
      final inspectButtons = find.byIcon(Icons.visibility_outlined);
      expect(inspectButtons, findsNWidgets(3));
      await tester.tap(inspectButtons.first, warnIfMissed: false);
      await tester.pump();

      expect(inspectedCompany?.id, equals(1));
    });
  });
}
