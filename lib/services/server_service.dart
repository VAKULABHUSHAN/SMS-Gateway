import 'dart:convert';
import 'dart:io';
import '../models/config.dart';
import 'sms_service.dart';

class ServerService {
  HttpServer? _server;
  final SmsService _smsService = SmsService();

  Future<void> start({
    required Function(
      String method,
      String path,
      String clientIp,
      String details,
      bool success,
    ) onRequestReceived,
  }) async {
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        AppConfig.defaultPort,
      );

      _server!.listen((HttpRequest request) async {
        final clientIp = request.connectionInfo?.remoteAddress.address ?? "Unknown";

        if (request.method == "GET" && request.uri.path == "/") {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.text
            ..write("${AppConfig.appName} Running 🚀");
          await request.response.close();
          
          onRequestReceived(
            "GET",
            "/",
            clientIp,
            "Health check ping",
            true,
          );
          return;
        }

        if (request.method == "POST" && request.uri.path == "/send") {
          String? details;
          bool isSuccess = false;
          try {
            final body = await utf8.decoder.bind(request).join();
            final data = jsonDecode(body);
            final number = data["number"]?.toString() ?? "";
            final message = data["message"]?.toString() ?? "";

            if (number.isEmpty || message.isEmpty) {
              request.response
                ..statusCode = HttpStatus.badRequest
                ..headers.contentType = ContentType.json
                ..write(jsonEncode({
                  "success": false,
                  "error": "Number or message is empty",
                }));
              details = "Validation failed: Empty number or message";
            } else {
              final result = await _smsService.sendSms(
                number: number,
                message: message,
              );
              
              final isError = result.startsWith("Platform Error") || result.startsWith("Unexpected Error");

              request.response
                ..statusCode = isError ? HttpStatus.internalServerError : HttpStatus.ok
                ..headers.contentType = ContentType.json
                ..write(jsonEncode({
                  "success": !isError,
                  "result": result,
                }));
              
              details = isError ? result : "SMS sent to $number";
              isSuccess = !isError;
            }
          } catch (e) {
            request.response
              ..statusCode = HttpStatus.internalServerError
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({
                "success": false,
                "error": e.toString(),
              }));
            details = "Error: ${e.toString()}";
            isSuccess = false;
          }
          await request.response.close();
          
          onRequestReceived(
            "POST",
            "/send",
            clientIp,
            details,
            isSuccess,
          );
          return;
        }

        if (request.method == "POST" && request.uri.path == "/send_bulk") {
          String? details;
          bool isSuccess = false;
          try {
            final body = await utf8.decoder.bind(request).join();
            final data = jsonDecode(body);
            final numbers = data["numbers"];
            final message = data["message"]?.toString() ?? "";

            if (numbers == null || numbers is! List || numbers.isEmpty || message.isEmpty) {
              request.response
                ..statusCode = HttpStatus.badRequest
                ..headers.contentType = ContentType.json
                ..write(jsonEncode({
                  "success": false,
                  "error": "Numbers array or message is empty/invalid",
                }));
              details = "Validation failed: Invalid numbers array or message";
            } else {
              List<Map<String, dynamic>> results = [];
              int successCount = 0;
              
              for (var num in numbers) {
                final numberStr = num.toString();
                final result = await _smsService.sendSms(
                  number: numberStr,
                  message: message,
                );
                final isError = result.startsWith("Platform Error") || result.startsWith("Unexpected Error");
                if (!isError) successCount++;
                results.add({
                  "number": numberStr,
                  "success": !isError,
                  "result": result,
                });
              }

              request.response
                ..statusCode = HttpStatus.ok
                ..headers.contentType = ContentType.json
                ..write(jsonEncode({
                  "success": successCount > 0,
                  "total": numbers.length,
                  "sent": successCount,
                  "results": results,
                }));
              
              details = "Bulk SMS sent to $successCount/${numbers.length} numbers";
              isSuccess = true;
            }
          } catch (e) {
            request.response
              ..statusCode = HttpStatus.internalServerError
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({
                "success": false,
                "error": e.toString(),
              }));
            details = "Error: ${e.toString()}";
            isSuccess = false;
          }
          await request.response.close();
          
          onRequestReceived(
            "POST",
            "/send_bulk",
            clientIp,
            details,
            isSuccess,
          );
          return;
        }

        request.response
          ..statusCode = HttpStatus.notFound
          ..write("Not Found");
        await request.response.close();

        onRequestReceived(
          request.method,
          request.uri.path,
          clientIp,
          "Route not found (404)",
          false,
        );
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
