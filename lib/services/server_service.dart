import 'dart:convert';
import 'dart:io';
import '../models/config.dart';
import 'sms_service.dart';

class ServerService {
  HttpServer? _server;
  final SmsService _smsService = SmsService();

  Future<void> start({Function(int)? onRequestReceived}) async {
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        AppConfig.defaultPort,
      );

      _server!.listen((HttpRequest request) async {
        onRequestReceived?.call(1);

        if (request.method == "GET" && request.uri.path == "/") {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.text
            ..write("${AppConfig.appName} Running 🚀");
          await request.response.close();
          return;
        }

        if (request.method == "POST" && request.uri.path == "/send") {
          try {
            final body = await utf8.decoder.bind(request).join();
            final data = jsonDecode(body);

            final result = await _smsService.sendSms(
              number: data["number"],
              message: data["message"],
            );

            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({
                "success": true,
                "result": result,
              }));
          } catch (e) {
            request.response
              ..statusCode = HttpStatus.internalServerError
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({
                "success": false,
                "error": e.toString(),
              }));
          }
          await request.response.close();
          return;
        }

        request.response
          ..statusCode = HttpStatus.notFound
          ..write("Not Found");
        await request.response.close();
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  bool get isRunning => _server != null;
}
