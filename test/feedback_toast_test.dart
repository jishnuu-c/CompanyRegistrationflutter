import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:company_reg_flutter/widgets/feedback_toast.dart';

void main() {
  group('FeedbackToast Widget Tests', () {
    testWidgets('Renders success feedback with title, message and badges', (tester) async {
      bool closed = false;

      final feedback = FeedbackData(
        type: 'success',
        title: 'Company Registered Successfully!',
        message: '"Apex Global Corp" has been established with ID #1.',
        badges: [
          const FeedbackBadge(icon: Icons.check, label: 'Active'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedbackToast(
              feedback: feedback,
              onClose: () => closed = true,
              animate: false,
            ),
          ),
        ),
      );

      expect(find.text('Company Registered Successfully!'), findsOneWidget);
      expect(
        find.text('"Apex Global Corp" has been established with ID #1.'),
        findsOneWidget,
      );
      expect(find.text('Active'), findsOneWidget);

      // Verify close button tap
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });

    testWidgets('Renders error feedback with Form Incomplete title', (tester) async {
      final feedback = FeedbackData(
        type: 'error',
        title: 'Form Incomplete',
        message:
            'Please fill in or correct "Company Legal Name". We\'ve automatically scrolled to it.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedbackToast(
              feedback: feedback,
              onClose: () {},
              animate: false,
            ),
          ),
        ),
      );

      expect(find.text('Form Incomplete'), findsOneWidget);
      expect(
        find.text(
          'Please fill in or correct "Company Legal Name". We\'ve automatically scrolled to it.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });
}
