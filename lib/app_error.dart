/// Custom Error type to simplify error messaging
library;

/// Application-specific error class
class AppError extends Error {
  /// Error message
  final String message;

  /// Creates a new AppError with the given message
  AppError(this.message);

  @override
  String toString() => 'AppError: $message';
}