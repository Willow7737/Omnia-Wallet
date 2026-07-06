import 'package:dio/dio.dart';

/// Turn a raw exception (usually a Dio error) into a short, human message.
///
/// Pure and dependency-light so it can be unit-tested and reused everywhere we
/// surface a failure. Also classifies whether the failure looks like a
/// connectivity problem so the UI can show an offline banner.
class FriendlyError {
  const FriendlyError(this.message, {this.isOffline = false});

  final String message;
  final bool isOffline;

  @override
  String toString() => message;
}

FriendlyError friendlyError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const FriendlyError(
          'The node took too long to respond. Check your connection and try again.',
          isOffline: true,
        );
      case DioExceptionType.connectionError:
        return const FriendlyError(
          "Can't reach the node. You may be offline, or the node URL is wrong.",
          isOffline: true,
        );
      case DioExceptionType.badCertificate:
        return const FriendlyError(
            'The node presented an invalid certificate.');
      case DioExceptionType.cancel:
        return const FriendlyError('Request cancelled.');
      case DioExceptionType.badResponse:
        return _fromStatus(error);
      case DioExceptionType.unknown:
      default:
        return const FriendlyError(
          "Something went wrong reaching the node. You may be offline.",
          isOffline: true,
        );
    }
  }
  // Non-Dio errors: surface a trimmed message.
  final text = error.toString().replaceFirst('Exception: ', '');
  return FriendlyError(text.isEmpty ? 'Unexpected error.' : text);
}

FriendlyError _fromStatus(DioException error) {
  final status = error.response?.statusCode ?? 0;
  // Prefer the server's own message when present: the node uses
  // `{ "error": ... }`, the Supabase edge function `{ "message": ... }`.
  final data = error.response?.data;
  String? serverMsg;
  if (data is Map) {
    if (data['error'] is String) {
      serverMsg = data['error'] as String;
    } else if (data['message'] is String) {
      serverMsg = data['message'] as String;
    }
  }
  switch (status) {
    case 400:
      return FriendlyError(serverMsg ?? 'The request was rejected as invalid.');
    case 401:
      return const FriendlyError('Your session expired. Please try again.');
    case 403:
      return FriendlyError(serverMsg ?? 'You are not allowed to do that.');
    case 404:
      return FriendlyError(serverMsg ?? 'Not found on the node.');
    case 409:
      return FriendlyError(serverMsg ?? 'That already exists.');
    case 429:
      return const FriendlyError('Too many requests. Slow down and try again.');
    case >= 500:
      return const FriendlyError(
          'The node had an internal error. Try again shortly.');
    default:
      return FriendlyError(serverMsg ?? 'Request failed ($status).');
  }
}
