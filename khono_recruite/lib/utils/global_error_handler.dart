import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Global error handler for consistent error management across the app
class GlobalErrorHandler {
  static final GlobalErrorHandler _instance = GlobalErrorHandler._internal();
  factory GlobalErrorHandler() => _instance;
  GlobalErrorHandler._internal();

  /// Handle and log errors consistently
  void handleError(
    Object error, {
    StackTrace? stackTrace,
    String? errorContext,
    VoidCallback? onRetry,
  }) {
    // Log error in debug mode
    if (kDebugMode) {
      debugPrint('=== ERROR ===');
      if (errorContext != null) debugPrint('Context: $errorContext');
      debugPrint('Error: $error');
      if (stackTrace != null) debugPrint('Stack Trace: $stackTrace');
      debugPrint('============');
    }

    // In production, you would send this to a logging service
    // like Firebase Crashlytics, Sentry, etc.
  }

  /// Get user-friendly error message
  String getErrorMessage(Object error) {
    if (error is Exception) {
      final message = error.toString();

      // Common error patterns
      if (message.contains('Failed to load')) {
        return 'Unable to load data. Please check your connection and try again.';
      }
      if (message.contains('Network')) {
        return 'Network error. Please check your internet connection.';
      }
      if (message.contains('timeout')) {
        return 'Request timed out. Please try again.';
      }
      if (message.contains('Unauthorized') || message.contains('401')) {
        return 'Your session has expired. Please log in again.';
      }
      if (message.contains('Forbidden') || message.contains('403')) {
        return 'You don\'t have permission to perform this action.';
      }
      if (message.contains('Not Found') || message.contains('404')) {
        return 'The requested resource was not found.';
      }
      if (message.contains('Server Error') || message.contains('500')) {
        return 'Server error. Please try again later.';
      }

      // Return the original message if it's user-friendly
      if (message.length < 100 && !message.contains('Exception')) {
        return message;
      }
    }

    return 'An unexpected error occurred. Please try again.';
  }

  /// Show error snackbar with consistent styling
  void showErrorSnackBar(
    BuildContext context,
    Object error, {
    String? errorContext,
    VoidCallback? onRetry,
  }) {
    handleError(error, errorContext: errorContext);

    final message = getErrorMessage(error);
    final snackBar = SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 4),
      action: onRetry != null
          ? SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
      behavior: SnackBarBehavior.floating,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Show success snackbar with consistent styling
  void showSuccessSnackBar(
    BuildContext context,
    String message, {
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 3),
      action: onAction != null && actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction,
            )
          : null,
      behavior: SnackBarBehavior.floating,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Show info snackbar with consistent styling
  void showInfoSnackBar(
    BuildContext context,
    String message, {
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.blue,
      duration: const Duration(seconds: 3),
      action: onAction != null && actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction,
            )
          : null,
      behavior: SnackBarBehavior.floating,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}

/// Extension to make error handling easier
extension ErrorHandling on BuildContext {
  void showError(
    Object error, {
    String? context,
    VoidCallback? onRetry,
  }) {
    GlobalErrorHandler().showErrorSnackBar(
      this,
      error,
      errorContext: context,
      onRetry: onRetry,
    );
  }

  void showSuccess(
    String message, {
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    GlobalErrorHandler().showSuccessSnackBar(
      this,
      message,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  void showInfo(
    String message, {
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    GlobalErrorHandler().showInfoSnackBar(
      this,
      message,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }
}
