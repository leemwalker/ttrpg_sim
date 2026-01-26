class AppBaseException implements Exception {
  final String message;
  final dynamic originalError;

  AppBaseException(this.message, [this.originalError]);

  @override
  String toString() =>
      'AppBaseException: $message ${originalError != null ? "($originalError)" : ""}';
}

class ApiKeyException extends AppBaseException {
  ApiKeyException([super.message = 'Invalid API Key', super.originalError]);
}

class NetworkException extends AppBaseException {
  NetworkException([super.message = 'Network Error', super.originalError]);
}

class AIFormatException extends AppBaseException {
  AIFormatException(
      [super.message = 'AI Response Format Error', super.originalError]);
}
