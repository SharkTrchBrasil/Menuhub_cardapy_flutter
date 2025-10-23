class AppError {
  final String message;
  final int? statusCode;

  AppError(this.message, {this.statusCode});

  @override
  String toString() => 'AppError: $message (code: $statusCode)';
}
