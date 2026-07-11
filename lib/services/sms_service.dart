import 'package:flutter/services.dart';

class SmsService {
  static const MethodChannel _channel = MethodChannel('sms_gateway');

  Future<String> sendSms({
    required String number,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'sendSms',
        {
          'number': number.trim(),
          'message': message.trim(),
        },
      );

      return result ?? "SMS Sent Successfully";
    } on PlatformException catch (e) {
      return "Platform Error: ${e.message}";
    } catch (e) {
      return "Unexpected Error: $e";
    }
  }
}