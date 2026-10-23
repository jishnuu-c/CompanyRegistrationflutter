import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:company_reg_flutter/utils/api_error_util.dart';

void main() {
  group('ApiException and getHumanReadableHttpError Tests', () {
    test('Translates Status 0 or Network exceptions to connection advice', () {
      final err0 = ApiException(statusCode: 0);
      expect(
        getHumanReadableHttpError(err0, 'fallback'),
        'Unable to connect to the server. Please verify your internet connection or check that the backend service is running.',
      );

      final socketErr = const SocketException('Connection refused');
      expect(
        getHumanReadableHttpError(socketErr, 'fallback'),
        'Unable to connect to the server. Please verify your internet connection or check that the backend service is running.',
      );

      final clientErr = Exception('ClientException: Connection reset by peer');
      expect(
        getHumanReadableHttpError(clientErr, 'fallback'),
        'Unable to connect to the server. Please verify your internet connection or check that the backend service is running.',
      );
    });

    test('Translates Status 401 to session expired advice', () {
      final err401 = ApiException(statusCode: 401);
      expect(
        getHumanReadableHttpError(err401, 'fallback'),
        'Your login session has expired. Please sign in again to continue.',
      );
    });

    test('Translates Status 403 to permission denied advice', () {
      final err403 = ApiException(statusCode: 403);
      expect(
        getHumanReadableHttpError(err403, 'fallback'),
        'Access denied. You do not have permission to modify this company record.',
      );
    });

    test('Translates Status 404 to not found advice', () {
      final err404 = ApiException(statusCode: 404);
      expect(
        getHumanReadableHttpError(err404, 'fallback'),
        'The requested record was not found. It may have already been removed.',
      );
    });

    test('Translates Status 409 to duplicate conflict advice', () {
      final err409Default = ApiException(statusCode: 409);
      expect(
        getHumanReadableHttpError(err409Default, 'fallback'),
        'A company with this name or email already exists. Please choose a unique legal name.',
      );

      final err409Custom = ApiException(
        statusCode: 409,
        message: 'Product SKU already exists in catalog.',
      );
      expect(
        getHumanReadableHttpError(err409Custom, 'fallback'),
        'Product SKU already exists in catalog.',
      );
    });

    test('Translates Status 413 to file payload too large advice', () {
      final err413 = ApiException(statusCode: 413);
      expect(
        getHumanReadableHttpError(err413, 'fallback'),
        'The uploaded file(s) exceed the server size limit. Please upload smaller attachments.',
      );
    });

    test('Translates Status 400 client validation error', () {
      final err400Default = ApiException(statusCode: 400);
      expect(
        getHumanReadableHttpError(err400Default, 'fallback'),
        'The submitted data was incomplete or invalid. Please check your form entries.',
      );

      final err400Custom = ApiException(
        statusCode: 400,
        message: 'Email address domain is invalid.',
      );
      expect(
        getHumanReadableHttpError(err400Custom, 'fallback'),
        'Email address domain is invalid.',
      );
    });

    test('Translates Status 500 server error sanitizing stack traces', () {
      final err500 = ApiException(
        statusCode: 500,
        message: 'NullPointerException at org.springframework.web...',
      );
      expect(
        getHumanReadableHttpError(err500, 'fallback'),
        'The server encountered an unexpected error while processing your request. Please try again shortly.',
      );

      final err500Clean = ApiException(
        statusCode: 500,
        message: 'Database storage allocation exceeded.',
      );
      expect(
        getHumanReadableHttpError(err500Clean, 'fallback'),
        'Database storage allocation exceeded.',
      );
    });

    test('Parses backend JSON response bodies accurately', () {
      final responseWithMsg = http.Response(
        '{"message": "Custom backend error"}',
        400,
      );
      final apiEx1 = ApiException.fromResponse(responseWithMsg);
      expect(apiEx1.statusCode, 400);
      expect(apiEx1.message, 'Custom backend error');

      final responseWithErrors = http.Response(
        '{"errors": {"email": "Must be a valid corporate email"}}',
        400,
      );
      final apiEx2 = ApiException.fromResponse(responseWithErrors);
      expect(apiEx2.statusCode, 400);
      expect(apiEx2.message, 'Must be a valid corporate email');
    });

    test('Generates Angular Form Incomplete feedback correctly', () {
      final single = getFormIncompleteFeedback(['Company Legal Name']);
      expect(single.type, 'error');
      expect(single.title, 'Form Incomplete');
      expect(
        single.message,
        'Please fill in or correct "Company Legal Name". We\'ve automatically scrolled to it.',
      );

      final multiple = getFormIncompleteFeedback([
        'Company Legal Name',
        'Corporate Email',
        'Country Jurisdiction',
      ]);
      expect(multiple.type, 'error');
      expect(multiple.title, 'Form Incomplete');
      expect(
        multiple.message,
        'Required fields incomplete (Company Legal Name, Corporate Email, Country Jurisdiction). Scrolled to "Company Legal Name".',
      );

      final moreThanThree = getFormIncompleteFeedback([
        'Field 1',
        'Field 2',
        'Field 3',
        'Field 4',
      ]);
      expect(
        moreThanThree.message,
        'Required fields incomplete (Field 1, Field 2, Field 3...). Scrolled to "Field 1".',
      );
    });
  });
}
