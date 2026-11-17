import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS example declares a Flutter scene and registers the implicit engine',
    () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>UIApplicationSceneManifest</key>'));
      expect(plist, contains('<string>FlutterSceneDelegate</string>'));
      expect(plist, contains('<key>UISceneStoryboardFile</key>'));
      expect(plist, contains('<string>Main</string>'));
      final header = File('ios/Runner/AppDelegate.h').readAsStringSync();
      expect(header, contains('<FlutterImplicitEngineDelegate>'));
      final implementation = File(
        'ios/Runner/AppDelegate.m',
      ).readAsStringSync();
      expect(implementation, contains('didInitializeImplicitFlutterEngine:'));
      expect(
        implementation,
        contains('registerWithRegistry:engineBridge.pluginRegistry'),
      );
      expect(implementation, isNot(contains('registerWithRegistry:self')));
      expect('registerWithRegistry:'.allMatches(implementation), hasLength(1));
    },
  );
}
