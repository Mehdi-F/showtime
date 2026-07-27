/// Base exception for all app-specific errors.
/// Provides structured error information instead of relying on toString().
abstract class AppException implements Exception {
  final String message;
  final Exception? originalException;
  final StackTrace? stackTrace;

  AppException(this.message, {this.originalException, this.stackTrace});

  @override
  String toString() => message;
}

/// Network-related errors (connection timeouts, no internet, etc.)
class NetworkException extends AppException {
  NetworkException(
    String message, {
    Exception? originalException,
    StackTrace? stackTrace,
  }) : super(message, originalException: originalException, stackTrace: stackTrace);
}

/// TMDB API errors with HTTP status code information.
/// Distinguishes between client errors (4xx), server errors (5xx), and rate limiting.
class TmdbException extends AppException {
  final int? statusCode;

  TmdbException(
    String message, {
    this.statusCode,
    Exception? originalException,
    StackTrace? stackTrace,
  }) : super(message, originalException: originalException, stackTrace: stackTrace);

  /// True if this is a rate limit error (HTTP 429).
  bool get isRateLimited => statusCode == 429;

  /// True if this is an authorization error (HTTP 401/403).
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  /// True if this is a not-found error (HTTP 404).
  bool get isNotFound => statusCode == 404;

  /// True if this is a server error (5xx).
  bool get isServerError => statusCode != null && statusCode! >= 500;

  @override
  String toString() {
    if (statusCode != null) {
      return '$message (HTTP $statusCode)';
    }
    return message;
  }
}

/// Authentication/authorization errors.
class AuthException extends AppException {
  AuthException(
    String message, {
    Exception? originalException,
    StackTrace? stackTrace,
  }) : super(message, originalException: originalException, stackTrace: stackTrace);
}

/// Data parsing or validation errors.
class DataException extends AppException {
  final String? field;

  DataException(
    String message, {
    this.field,
    Exception? originalException,
    StackTrace? stackTrace,
  }) : super(message, originalException: originalException, stackTrace: stackTrace);

  @override
  String toString() {
    if (field != null) {
      return '$message (field: $field)';
    }
    return message;
  }
}

/// Resource not found errors (e.g., a movie/show ID doesn't exist in TMDB).
class NotFoundException extends AppException {
  final String? resourceType;
  final dynamic resourceId;

  NotFoundException(
    String message, {
    this.resourceType,
    this.resourceId,
    Exception? originalException,
    StackTrace? stackTrace,
  }) : super(message, originalException: originalException, stackTrace: stackTrace);

  @override
  String toString() {
    if (resourceType != null && resourceId != null) {
      return '$message ($resourceType: $resourceId)';
    }
    return message;
  }
}

/// Timeout errors.
class TimeoutException extends AppException {
  final Duration? timeout;

  TimeoutException(
    String message, {
    this.timeout,
    Exception? originalException,
    StackTrace? stackTrace,
  }) : super(message, originalException: originalException, stackTrace: stackTrace);

  @override
  String toString() {
    if (timeout != null) {
      return '$message (after ${timeout!.inSeconds}s)';
    }
    return message;
  }
}
