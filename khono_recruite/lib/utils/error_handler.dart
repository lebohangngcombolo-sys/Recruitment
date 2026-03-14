import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global error handler for admin screens
class GlobalErrorHandler {
  static final GlobalErrorHandler _instance = GlobalErrorHandler._internal();
  factory GlobalErrorHandler() => _instance;
  GlobalErrorHandler._internal();

  static void initialize() {
    // Set up Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      _logFlutterError(details);
      _showUserFriendlyError(details);
    };

    // Set up platform error handling
    PlatformDispatcher.instance.onError = (error, stack) {
      _logPlatformError(error, stack);
      _showUserFriendlyError(null, error: error);
      return true;
    };
  }

  static void _logFlutterError(FlutterErrorDetails details) {
    if (kDebugMode) {
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    }

    // In production, send to crash reporting service
    if (!kDebugMode) {
      _sendToCrashReporting(details.exception, details.stack);
    }
  }

  static void _logPlatformError(Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('Platform Error: $error');
      debugPrint('Stack trace: $stack');
    }

    // In production, send to crash reporting service
    if (!kDebugMode) {
      _sendToCrashReporting(error, stack);
    }
  }

  static void _sendToCrashReporting(Object error, StackTrace? stack) {
    // TODO: Implement crash reporting integration
    // This could be Firebase Crashlytics, Sentry, or similar service
    debugPrint('Sending error to crash reporting: $error');
  }

  static void _showUserFriendlyError(FlutterErrorDetails? details,
      {Object? error}) {
    // Get the current context from navigator key if available
    final context = _getNavigatorContext();
    if (context != null) {
      _showErrorDialog(
          context, details?.exception ?? error ?? Exception('Unknown error'));
    }
  }

  static BuildContext? _getNavigatorContext() {
    // This would need to be set up in your app's navigator key
    // For now, we'll return null and handle errors differently
    return null;
  }

  static void _showErrorDialog(BuildContext context, Object error) {
    final errorMessage = _getUserFriendlyMessage(error);

    showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        title: 'Something went wrong',
        message: errorMessage,
        onRetry: () {
          Navigator.of(context).pop();
          // Implement retry logic if needed
        },
      ),
    );
  }

  static String _getUserFriendlyMessage(Object error) {
    if (error is SocketException) {
      return 'Unable to connect to the server. Please check your internet connection.';
    } else if (error is HttpException) {
      return 'Server error occurred. Please try again later.';
    } else if (error is FormatException) {
      return 'Data format error. Please try again.';
    } else if (error.toString().contains('401')) {
      return 'Your session has expired. Please log in again.';
    } else if (error.toString().contains('403')) {
      return 'You don\'t have permission to perform this action.';
    } else if (error.toString().contains('404')) {
      return 'The requested resource was not found.';
    } else if (error.toString().contains('500')) {
      return 'Server error occurred. Please try again later.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  static void handleError(Object error, StackTrace? stackTrace) {
    if (kDebugMode) {
      debugPrint('Handled Error: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }

    // Send to crash reporting in production
    if (!kDebugMode) {
      _sendToCrashReporting(error, stackTrace);
    }
  }

  static void logError(String message,
      {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('Error Log: $message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }

    // Store error logs locally for debugging
    _storeErrorLog(message, error: error, stackTrace: stackTrace);
  }

  static Future<void> _storeErrorLog(String message,
      {Object? error, StackTrace? stackTrace}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final errorLogs = prefs.getStringList('error_logs') ?? [];

      final timestamp = DateTime.now().toIso8601String();
      final logEntry =
          '[$timestamp] $message${error != null ? ': $error' : ''}';

      errorLogs.add(logEntry);

      // Keep only the last 100 error logs
      if (errorLogs.length > 100) {
        errorLogs.removeRange(0, errorLogs.length - 100);
      }

      await prefs.setStringList('error_logs', errorLogs);
    } catch (e) {
      debugPrint('Failed to store error log: $e');
    }
  }

  static Future<List<String>> getErrorLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('error_logs') ?? [];
    } catch (e) {
      debugPrint('Failed to get error logs: $e');
      return [];
    }
  }

  static Future<void> clearErrorLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('error_logs');
    } catch (e) {
      debugPrint('Failed to clear error logs: $e');
    }
  }
}

/// Custom error dialog widget
class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade600,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (onRetry != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can try again or contact support if the problem persists.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        TextButton(
          onPressed: onDismiss ?? () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Error boundary widget for catching errors in widget trees
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, VoidCallback retry)? errorBuilder;
  final void Function(Object error)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _resetError();
  }

  void _resetError() {
    setState(() {
      _error = null;
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error!, _resetError);
      }

      return _DefaultErrorWidget(
        error: _error!,
        onRetry: _resetError,
      );
    }

    return widget.child;
  }
}

/// Default error widget for error boundary
class _DefaultErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _DefaultErrorWidget({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade600,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'An unexpected error occurred while rendering this component.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC10D00),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// API error handler for consistent API error handling
class ApiErrorHandler {
  static void handleApiError(dynamic error, {String? context}) {
    if (context != null) {
      GlobalErrorHandler.logError('API Error in $context', error: error);
    } else {
      GlobalErrorHandler.logError('API Error', error: error);
    }
  }

  static String getErrorMessage(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    } else if (error is HttpException) {
      return 'Server error: ${error.message}';
    } else if (error is FormatException) {
      return 'Invalid data format received from server.';
    } else if (error.toString().contains('401')) {
      return 'Session expired. Please log in again.';
    } else if (error.toString().contains('403')) {
      return 'Access denied. You don\'t have permission to perform this action.';
    } else if (error.toString().contains('404')) {
      return 'Requested resource not found.';
    } else if (error.toString().contains('500')) {
      return 'Internal server error. Please try again later.';
    } else if (error is TimeoutException) {
      return 'Request timed out. Please check your connection and try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
}

/// Utility class for showing consistent error messages
class ErrorSnackBar {
  static void show(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        duration: duration ?? const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message,
      {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
