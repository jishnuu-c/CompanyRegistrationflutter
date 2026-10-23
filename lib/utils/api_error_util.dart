import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../widgets/feedback_toast.dart';

/// Structured API Exception preserving HTTP status code, raw response body,
/// and parsed error messages for human-readable translation.
class ApiException implements Exception {
  final int statusCode;
  final String? body;
  final String? message;
  final dynamic error;

  ApiException({
    required this.statusCode,
    this.body,
    this.message,
    this.error,
  });

  /// Factory constructor to parse standard backend Spring Boot error payloads
  factory ApiException.fromResponse(
    http.Response response, {
    String? fallbackMessage,
  }) {
    String? extractedMsg;
    dynamic parsedError;

    try {
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        parsedError = decoded;
        if (decoded is Map<String, dynamic>) {
          if (decoded['message'] != null &&
              decoded['message'].toString().trim().isNotEmpty) {
            extractedMsg = decoded['message'].toString().trim();
          } else if (decoded['error'] != null &&
              decoded['error'].toString().trim().isNotEmpty) {
            extractedMsg = decoded['error'].toString().trim();
          } else if (decoded['errors'] != null) {
            if (decoded['errors'] is Map) {
              final firstVal = (decoded['errors'] as Map).values.firstOrNull;
              if (firstVal != null) extractedMsg = firstVal.toString();
            } else if (decoded['errors'] is List) {
              final firstItem = (decoded['errors'] as List).firstOrNull;
              if (firstItem != null) extractedMsg = firstItem.toString();
            }
          }
        } else if (decoded is String && decoded.trim().isNotEmpty) {
          extractedMsg = decoded.trim();
        }
      }
    } catch (_) {
      // Body is not JSON
      if (response.body.isNotEmpty && response.body.length < 200) {
        extractedMsg = response.body.trim();
      }
    }

    return ApiException(
      statusCode: response.statusCode,
      body: response.body,
      message: extractedMsg ?? fallbackMessage,
      error: parsedError,
    );
  }

  @override
  String toString() => message ?? 'ApiException (Status: $statusCode)';
}

/// Translates backend HTTP errors and network failures into clear,
/// human-readable explanations with actionable recovery advice.
/// Directly mirrors Angular's getHumanReadableHttpError implementation.
String getHumanReadableHttpError(dynamic err, String fallbackMessage) {
  if (err == null) return fallbackMessage;

  // Handle SocketException / Connection refused / Offline
  if (err is SocketException) {
    return 'Unable to connect to the server. Please verify your internet connection or check that the backend service is running.';
  }

  final errStr = err.toString();
  if (errStr.contains('SocketException') ||
      errStr.contains('Connection refused') ||
      errStr.contains('ClientException') ||
      errStr.contains('Failed host lookup') ||
      errStr.contains('Network is unreachable') ||
      errStr.contains('Connection reset by peer') ||
      errStr.contains('timed out') ||
      errStr.contains('TimeoutException')) {
    return 'Unable to connect to the server. Please verify your internet connection or check that the backend service is running.';
  }

  // Handle ApiException status codes
  if (err is ApiException) {
    final status = err.statusCode;

    // Status 0: Backend server is offline or network disconnected
    if (status == 0) {
      return 'Unable to connect to the server. Please verify your internet connection or check that the backend service is running.';
    }

    // Session / Authentication errors (401)
    if (status == 401) {
      return 'Your login session has expired. Please sign in again to continue.';
    }

    // Authorization / Permission errors (403)
    if (status == 403) {
      return 'Access denied. You do not have permission to modify this company record.';
    }

    // Not found errors (404)
    if (status == 404) {
      return 'The requested record was not found. It may have already been removed.';
    }

    // Conflict / Duplicate errors (409)
    if (status == 409) {
      if (err.message != null && err.message!.trim().isNotEmpty) {
        return err.message!.trim();
      }
      return 'A company with this name or email already exists. Please choose a unique legal name.';
    }

    // Payload too large (413)
    if (status == 413) {
      return 'The uploaded file(s) exceed the server size limit. Please upload smaller attachments.';
    }

    // Client validation error (400)
    if (status == 400) {
      if (err.message != null && err.message!.trim().isNotEmpty) {
        return err.message!.trim();
      }
      return 'The submitted data was incomplete or invalid. Please check your form entries.';
    }

    // Server errors (500, 502, 503)
    if (status >= 500) {
      if (err.message != null &&
          err.message!.trim().isNotEmpty &&
          !err.message!.contains('Exception') &&
          !err.message!.contains('org.springframework') &&
          !err.message!.contains('Internal Server Error')) {
        return err.message!.trim();
      }
      return 'The server encountered an unexpected error while processing your request. Please try again shortly.';
    }

    if (err.message != null && err.message!.trim().isNotEmpty) {
      return err.message!.trim();
    }
  }

  // Fallback string extraction for generic Exceptions
  if (err is Exception) {
    final clean = errStr.replaceFirst('Exception: ', '').trim();
    if (clean.isNotEmpty &&
        !clean.startsWith('{') &&
        !clean.contains('org.springframework') &&
        !clean.contains('NullPointerException')) {
      return clean;
    }
  }

  return fallbackMessage;
}

/// Generates the standard Angular form incomplete feedback message
/// with first invalid control focus advice.
FeedbackData getFormIncompleteFeedback(List<String> missingFieldLabels) {
  if (missingFieldLabels.isEmpty) {
    return FeedbackData(
      type: 'error',
      title: 'Form Incomplete',
      message: 'Please complete all required fields before saving.',
    );
  }

  final firstName = missingFieldLabels.first;
  final String message;
  if (missingFieldLabels.length == 1) {
    message = 'Please fill in or correct "$firstName". We\'ve automatically scrolled to it.';
  } else {
    final firstThree = missingFieldLabels.take(3).join(', ');
    final suffix = missingFieldLabels.length > 3 ? '...' : '';
    message = 'Required fields incomplete ($firstThree$suffix). Scrolled to "$firstName".';
  }

  return FeedbackData(
    type: 'error',
    title: 'Form Incomplete',
    message: message,
  );
}
