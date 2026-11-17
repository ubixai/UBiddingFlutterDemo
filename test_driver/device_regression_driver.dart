import 'dart:io';
import 'dart:convert';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      if (data != null) {
        stdout.writeln('QA_RESULTS ${jsonEncode(data['qaResults'])}');
      }
    },
    onScreenshot: (name, bytes, [args]) async {
      final directory = Directory(
        Platform.environment['QA_SCREENSHOT_DIR'] ??
            '/private/tmp/ubidding-device-screenshots',
      );
      await directory.create(recursive: true);
      await File(
        '${directory.path}/${name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.png',
      ).writeAsBytes(bytes);
      return bytes.isNotEmpty;
    },
  );
}
