/// Custom application exceptions for error categorization
class BackupException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  BackupException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'BackupException[$code]: $message';
}

class AuthException extends BackupException {
  AuthException(String message, {String? code, dynamic originalError})
      : super(message, code: code ?? 'AUTH_ERROR', originalError: originalError);
}

class DriveQuotaException extends BackupException {
  DriveQuotaException(String message, {dynamic originalError})
      : super(message, code: 'QUOTA_EXCEEDED', originalError: originalError);
}

class NetworkUnavailableException extends BackupException {
  NetworkUnavailableException(String message, {dynamic originalError})
      : super(message, code: 'NETWORK_UNAVAILABLE', originalError: originalError);
}

class BatteryConstraintException extends BackupException {
  BatteryConstraintException(String message)
      : super(message, code: 'BATTERY_CONSTRAINT');
}

class MediaPermissionDeniedException extends BackupException {
  final bool isPermanentlyDenied;
  MediaPermissionDeniedException(String message, {this.isPermanentlyDenied = false})
      : super(message, code: 'PERMISSION_DENIED');
}
