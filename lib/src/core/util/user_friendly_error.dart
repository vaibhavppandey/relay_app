import 'dart:io';

import 'package:dio/dio.dart';

String userFriendlyErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is DioException) {
    if (error.type == DioExceptionType.cancel) {
      return 'Transfer cancelled.';
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Connection is slow right now. Please try again.';
    }
  }

  if (error is SocketException) {
    return 'Connection is unavailable right now. Please try again.';
  }

  final message = error.toString().toLowerCase();
  if (message.contains('timedout') ||
      message.contains('timeout') ||
      message.contains('socketexception') ||
      message.contains('connection refused') ||
      message.contains('connection reset')) {
    return 'Connection is unavailable right now. Please try again.';
  }

  return fallback;
}
