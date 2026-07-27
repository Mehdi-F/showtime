/// Base exception for the application.
abstract class AppException implements Exception {
  final String message;

  AppException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when TMDB API requests fail.
class TmdbException extends AppException {
  final int? statusCode;

  TmdbException(
    String message, {
    this.statusCode,
  }) : super(message);

  @override
  String toString() => statusCode != null
      ? 'TmdbException ($statusCode): $message'
      : 'TmdbException: $message';
}

/// Exception thrown for network connectivity issues.
class NetworkException extends AppException {
  NetworkException(String message) : super(message);

  @override
  String toString() => 'NetworkException: $message';
}

/// Exception thrown for authentication failures.
class AuthException extends AppException {
  AuthException(String message) : super(message);

  @override
  String toString() => 'AuthException: $message';
}

/// Exception thrown for invalid data format or parsing errors.
class DataException extends AppException {
  final String? details;

  DataException(String message, {this.details}) : super(message);

  @override
  String toString() => details != null
      ? 'DataException: $message ($details)'
      : 'DataException: $message';
}

/// Exception thrown when required data is not found.
class NotFoundException extends AppException {
  NotFoundException(String message) : super(message);

  @override
  String toString() => 'NotFoundException: $message';
}
