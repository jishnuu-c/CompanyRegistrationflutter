import 'package:flutter_test/flutter_test.dart';
import 'package:company_reg_flutter/main.dart';

void main() {
  testWidgets('App loads welcome screen properly', (WidgetTester tester) async {
    await tester.pumpWidget(const CompanyRegistrationApp());
    expect(find.text('Welcome to Company Registration'), findsOneWidget);
    expect(find.text('Add Company Details'), findsOneWidget);
    expect(find.text('View Companies List'), findsOneWidget);
  });
}
