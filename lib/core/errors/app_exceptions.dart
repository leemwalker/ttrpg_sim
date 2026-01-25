class AppBaseException implements Exception {
  final String message;
  final dynamic originalError;

  AppBaseException(this.message, [this.originalError]);

  @override
  String toString() =>
      'AppBaseException: $message ${originalError != null ? "($originalError)" : ""}';
}

class ApiKeyException extends AppBaseException {
  ApiKeyException([String message = 'Invalid API Key', dynamic originalError])
      : super(message, originalError);
}

class NetworkException extends AppBaseException {
  NetworkException([String message = 'Network Error', dynamic originalError])
      : super(message, originalError);
}

class AIFormatException extends AppBaseException {
  AIFormatException(
      [String message = 'AI Response Format Error', dynamic originalError])
      : super(message, originalError);
}
