import 'package:flutter_test/flutter_test.dart';
import 'package:company_reg_flutter/main.dart';

void main() {
  testWidgets('App loads company portal shell properly', (WidgetTester tester) async {
    await tester.pumpWidget(const CompanyRegistrationApp());
    expect(find.text('Company Portal'), findsOneWidget);
  });
}