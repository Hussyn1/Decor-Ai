import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Represents a structured API error with a user-friendly message and error type.
class AppError {
  final String title;
  final String message;
  final AppErrorType type;

  const AppError({
    required this.title,
    required this.message,
    required this.type,
  });

  @override
  String toString() => '$title: $message';
}

enum AppErrorType {
  network,       // No internet, DNS failure, connection refused
  timeout,       // Request took too long
  server,        // 5xx errors
  auth,          // 401 / 403
  notFound,      // 404
  validation,    // 400 / 422
  parsing,       // JSON decode errors
  unknown,       // Catch-all
}

class ApiErrorHandler {
  /// Parses any exception or HTTP response into a user-friendly [AppError].
  static AppError handleException(dynamic error) {
    if (error is SocketException) {
      return const AppError(
        title: 'No Connection',
        message: 'Could not connect to the server. Please check your internet connection and try again.',
        type: AppErrorType.network,
      );
    }

    if (error is TimeoutException) {
      return const AppError(
        title: 'Request Timeout',
        message: 'The server took too long to respond. Please try again later.',
        type: AppErrorType.timeout,
      );
    }

    if (error is FormatException || error is JsonUnsupportedObjectError) {
      return const AppError(
        title: 'Data Error',
        message: 'Received an unexpected response from the server. Please try again.',
        type: AppErrorType.parsing,
      );
    }

    if (error is HandshakeException || error is TlsException) {
      return const AppError(
        title: 'Security Error',
        message: 'Could not establish a secure connection. Please check your network settings.',
        type: AppErrorType.network,
      );
    }

    if (error is HttpException) {
      return AppError(
        title: 'HTTP Error',
        message: error.message,
        type: AppErrorType.server,
      );
    }

    // Generic Exception / Error with a message
    final errorMessage = error.toString();

    if (errorMessage.contains('SocketException') ||
        errorMessage.contains('Connection refused') ||
        errorMessage.contains('Network is unreachable') ||
        errorMessage.contains('No address associated with hostname')) {
      return const AppError(
        title: 'No Connection',
        message: 'Could not reach the server. Please check your internet connection.',
        type: AppErrorType.network,
      );
    }

    if (errorMessage.contains('TimeoutException') ||
        errorMessage.contains('timed out')) {
      return const AppError(
        title: 'Request Timeout',
        message: 'The server took too long to respond. Please try again.',
        type: AppErrorType.timeout,
      );
    }

    if (errorMessage.contains('FormatException') ||
        errorMessage.contains('Unexpected character')) {
      return const AppError(
        title: 'Data Error',
        message: 'Received an invalid response from the server.',
        type: AppErrorType.parsing,
      );
    }

    return AppError(
      title: 'Something Went Wrong',
      message: 'An unexpected error occurred. Please try again.',
      type: AppErrorType.unknown,
    );
  }

  /// Parses an HTTP status code (and optional response body) into a user-friendly [AppError].
  static AppError handleStatusCode(int statusCode, [dynamic responseBody]) {
    String serverMessage = '';
    if (responseBody != null) {
      try {
        final body = responseBody is String ? jsonDecode(responseBody) : responseBody;
        if (body is Map) {
          serverMessage = body['message'] ?? body['error'] ?? '';
        }
      } catch (_) {
        // Could not parse body, use default message
      }
    }

    switch (statusCode) {
      case 400:
        return AppError(
          title: 'Bad Request',
          message: serverMessage.isNotEmpty
              ? serverMessage
              : 'The request was invalid. Please check your input and try again.',
          type: AppErrorType.validation,
        );
      case 401:
        return AppError(
          title: 'Unauthorized',
          message: serverMessage.isNotEmpty
              ? serverMessage
              : 'Your session has expired. Please log in again.',
          type: AppErrorType.auth,
        );
      case 403:
        return AppError(
          title: 'Access Denied',
          message: serverMessage.isNotEmpty
              ? serverMessage
              : 'You do not have permission to perform this action.',
          type: AppErrorType.auth,
        );
      case 404:
        return AppError(
          title: 'Not Found',
          message: serverMessage.isNotEmpty
              ? serverMessage
              : 'The requested resource could not be found.',
          type: AppErrorType.notFound,
        );
      case 408:
        return const AppError(
          title: 'Request Timeout',
          message: 'The server took too long to respond. Please try again.',
          type: AppErrorType.timeout,
        );
      case 409:
        return AppError(
          title: 'Conflict',
          message: serverMessage.isNotEmpty
              ? serverMessage
              : 'A conflict occurred with your request.',
          type: AppErrorType.validation,
        );
      case 422:
        return AppError(
          title: 'Validation Error',
          message: serverMessage.isNotEmpty
              ? serverMessage
              : 'Please check your input and try again.',
          type: AppErrorType.validation,
        );
      case 429:
        return const AppError(
          title: 'Too Many Requests',
          message: 'You are making too many requests. Please wait a moment.',
          type: AppErrorType.server,
        );
      case 500:
        return AppError(
          title: 'Server Error',
          message: serverMessage.isNotEmpty
              ? serverMessage
              : 'An internal server error occurred. Please try again later.',
          type: AppErrorType.server,
        );
      case 502:
        return const AppError(
          title: 'Bad Gateway',
          message: 'The server received an invalid response. Please try again later.',
          type: AppErrorType.server,
        );
      case 503:
        return const AppError(
          title: 'Service Unavailable',
          message: 'The server is temporarily unavailable. Please try again later.',
          type: AppErrorType.server,
        );
      case 504:
        return const AppError(
          title: 'Gateway Timeout',
          message: 'The server gateway timed out. Please try again later.',
          type: AppErrorType.timeout,
        );
      default:
        if (statusCode >= 500) {
          return AppError(
            title: 'Server Error ($statusCode)',
            message: serverMessage.isNotEmpty
                ? serverMessage
                : 'A server error occurred. Please try again later.',
            type: AppErrorType.server,
          );
        }
        return AppError(
          title: 'Error ($statusCode)',
          message: serverMessage.isNotEmpty
              ? serverMessage
              : 'An unexpected error occurred (HTTP $statusCode).',
          type: AppErrorType.unknown,
        );
    }
  }

  /// Returns the appropriate icon for an error type.
  static IconData getErrorIcon(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:
        return Icons.wifi_off_rounded;
      case AppErrorType.timeout:
        return Icons.timer_off_rounded;
      case AppErrorType.server:
        return Icons.cloud_off_rounded;
      case AppErrorType.auth:
        return Icons.lock_outline_rounded;
      case AppErrorType.notFound:
        return Icons.search_off_rounded;
      case AppErrorType.validation:
        return Icons.warning_amber_rounded;
      case AppErrorType.parsing:
        return Icons.broken_image_rounded;
      case AppErrorType.unknown:
        return Icons.error_outline_rounded;
    }
  }

  /// Returns the appropriate color for an error type.
  static Color getErrorColor(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:
      case AppErrorType.timeout:
        return const Color(0xFFFF9800); // Orange
      case AppErrorType.server:
        return const Color(0xFFF44336); // Red
      case AppErrorType.auth:
        return const Color(0xFFE91E63); // Pink
      case AppErrorType.notFound:
        return const Color(0xFF9C27B0); // Purple
      case AppErrorType.validation:
        return const Color(0xFFFF5722); // Deep Orange
      case AppErrorType.parsing:
      case AppErrorType.unknown:
        return const Color(0xFFF44336); // Red
    }
  }

  /// Shows a styled error snackbar using GetX.
  static void showError(AppError error) {
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    Get.snackbar(
      error.title,
      error.message,
      icon: Icon(
        getErrorIcon(error.type),
        color: Colors.white,
        size: 28,
      ),
      backgroundColor: getErrorColor(error.type).withOpacity(0.95),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: const Duration(seconds: 4),
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      animationDuration: const Duration(milliseconds: 400),
      snackStyle: SnackStyle.FLOATING,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  /// Shows a styled success snackbar using GetX.
  static void showSuccess(String title, String message) {
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    Get.snackbar(
      title,
      message,
      icon: const Icon(
        Icons.check_circle_rounded,
        color: Colors.white,
        size: 28,
      ),
      backgroundColor: const Color(0xFF4CAF50).withOpacity(0.95),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      animationDuration: const Duration(milliseconds: 400),
      snackStyle: SnackStyle.FLOATING,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }
}
