// The production build must not be able to borrow the preview build's identity.
//
// A store build that ships signed with the committed preview key, or labelled
// "Salapify Preview", or carrying the testing scaffolding, is a trust failure
// and a Play rejection. Some of that can only be proven by BUILDING the prod
// flavor (the prod AAB workflow does that: label, certificate, stripped aids).
// But the CONFIG that decides it is text in build.gradle.kts and a few Dart
// files, and text can be guarded here on every branch, so a regression reddens
// the PR instead of the store submission.
//
// These are STATIC guards. They assert the wiring is right; the prod AAB
// workflow asserts the built artifact matches.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _stripKotlinComments(String s) => s
    .replaceAll(RegExp(r'//.*'), '')
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

void main() {
  final gradle = _stripKotlinComments(
    File('android/app/build.gradle.kts').readAsStringSync(),
  );
  // Only the productFlavors section, so a create("preview") flavor block is
  // never confused with the create("preview") signing-config block above it.
  final flavors = gradle.substring(gradle.indexOf('productFlavors'));
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  group('the two flavors exist and are wired to different keys', () {
    test('a preview and a prod flavor are declared', () {
      expect(gradle.contains('create("preview")'), isTrue);
      expect(gradle.contains('create("prod")'), isTrue);
    });

    test('prod is signed with the upload key, preview with the preview key', () {
      // Scope each assertion to its flavor block so one flavor cannot satisfy
      // the check for the other.
      final prod = RegExp(
        r'create\("prod"\)\s*\{(.*?)\}',
        dotAll: true,
      ).firstMatch(flavors);
      final preview = RegExp(
        r'create\("preview"\)\s*\{(.*?)\}',
        dotAll: true,
      ).firstMatch(flavors);
      expect(prod, isNotNull);
      expect(preview, isNotNull);
      expect(
        prod!.group(1)!.contains('getByName("upload")'),
        isTrue,
        reason: 'the prod flavor must be signed with the upload key',
      );
      expect(
        prod.group(1)!.contains('getByName("preview")'),
        isFalse,
        reason: 'the prod flavor must NOT reference the preview key',
      );
      expect(
        preview!.group(1)!.contains('getByName("preview")'),
        isTrue,
        reason: 'the preview flavor keeps the committed preview key',
      );
    });

    test('the release build type does not force the preview key', () {
      // If buildTypes.release sets signingConfig, it overrides the flavor and
      // would sign prod with whatever it names. It must be silent so the flavor
      // decides. This was the shape before flavors existed.
      final release = RegExp(
        r'buildTypes\s*\{.*?release\s*\{(.*?)\}',
        dotAll: true,
      ).firstMatch(gradle);
      expect(release, isNotNull);
      expect(
        release!.group(1)!.contains('signingConfig'),
        isFalse,
        reason:
            'buildTypes.release must not set signingConfig; it comes from the '
            'flavor, or prod could be signed with the preview key.',
      );
    });
  });

  group('the upload key is loaded from outside the repo', () {
    test('the upload signing config reads the environment, not literals', () {
      final upload = RegExp(
        r'create\("upload"\)\s*\{(.*?)\n\s{8}\}',
        dotAll: true,
      ).firstMatch(gradle);
      expect(upload, isNotNull, reason: 'no upload signing config');
      expect(
        upload!.group(1)!.contains('System.getenv("SALAPIFY_UPLOAD_STORE_FILE")'),
        isTrue,
        reason: 'the upload key must come from the environment (a CI secret)',
      );
      expect(
        upload.group(1)!.contains('salapify-preview'),
        isFalse,
        reason: 'the upload config must not fall back to preview credentials',
      );
    });

    test('no production keystore is committed to the repo', () {
      // The preview keystore is committed on purpose. Any OTHER keystore file
      // would mean a production/upload key leaked into source control.
      final keystores = Directory('android')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.jks') || f.path.endsWith('.keystore'))
          .map((f) => f.path.split('/').last)
          .toList();
      expect(
        keystores,
        ['preview-keystore.jks'],
        reason:
            'only the preview keystore may be committed. A second keystore '
            'means an upload/production key entered the repo: $keystores',
      );
    });
  });

  group('production copy: no "Preview" in the store build', () {
    test('the launcher label is a per-flavor placeholder', () {
      expect(
        manifest.contains(r'android:label="${appLabel}"'),
        isTrue,
        reason: 'the label must be the per-flavor placeholder, not hard-coded',
      );
      final prev = RegExp(
        r'create\("preview"\)\s*\{(.*?)\}',
        dotAll: true,
      ).firstMatch(flavors)!.group(1)!;
      final prod = RegExp(
        r'create\("prod"\)\s*\{(.*?)\}',
        dotAll: true,
      ).firstMatch(flavors)!.group(1)!;
      expect(prev.contains('"Salapify Preview"'), isTrue);
      expect(
        prod.contains('"Salapify"') && !prod.contains('"Salapify Preview"'),
        isTrue,
        reason: 'the prod label must be "Salapify", never "Salapify Preview"',
      );
    });

    test('the in-app title follows the build flag', () {
      final main = _stripKotlinComments(File('lib/main.dart').readAsStringSync());
      expect(
        RegExp(r"title:\s*kPreviewBuild\s*\?").hasMatch(main),
        isTrue,
        reason:
            'the MaterialApp title must be kPreviewBuild-gated so the store '
            'build does not say "Preview".',
      );
    });
  });
}
