import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/core/errors.dart';

RequestOptions _req() => RequestOptions(path: '/x');

void main() {
  group('friendlyError', () {
    test('connection error is flagged offline', () {
      final e = DioException(
        requestOptions: _req(),
        type: DioExceptionType.connectionError,
      );
      final f = friendlyError(e);
      expect(f.isOffline, isTrue);
      expect(f.message.toLowerCase(), contains('offline'));
    });

    test('timeouts are flagged offline', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final f = friendlyError(
          DioException(requestOptions: _req(), type: t),
        );
        expect(f.isOffline, isTrue, reason: '$t should be offline');
      }
    });

    test('prefers the server error message on 400', () {
      final e = DioException(
        requestOptions: _req(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _req(),
          statusCode: 400,
          data: {'error': 'Transfer amount must be greater than zero'},
        ),
      );
      final f = friendlyError(e);
      expect(f.isOffline, isFalse);
      expect(f.message, 'Transfer amount must be greater than zero');
    });

    test('falls back to the edge function `message` field', () {
      final e = DioException(
        requestOptions: _req(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _req(),
          statusCode: 404,
          data: {'code': 'NO_DID', 'message': 'No DID linked to this account'},
        ),
      );
      expect(friendlyError(e).message, 'No DID linked to this account');
    });

    test('401 gives a session-expired message', () {
      final e = DioException(
        requestOptions: _req(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: _req(), statusCode: 401),
      );
      expect(friendlyError(e).message.toLowerCase(), contains('session'));
    });

    test('5xx gives an internal-error message', () {
      final e = DioException(
        requestOptions: _req(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: _req(), statusCode: 503),
      );
      expect(friendlyError(e).message.toLowerCase(), contains('internal'));
    });

    test('non-Dio errors are trimmed', () {
      expect(friendlyError(Exception('boom')).message, 'boom');
    });
  });
}
