// Renders marketing/review screenshots of the main screens.
// Skipped unless VAULTLY_SCREENSHOTS=<output dir> is set:
//   VAULTLY_SCREENSHOTS="$PWD/build/screenshots" \
//     flutter test --update-goldens test/screenshots_test.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/data/app_settings.dart';
import 'package:vaultly/data/vault_item.dart';
import 'package:vaultly/data/vault_service.dart';

import 'support/test_app.dart';

final _out = Platform.environment['VAULTLY_SCREENSHOTS'];

Future<void> _shot(WidgetTester tester, String name) async {
  await settle(tester, 8);
  await expectLater(
      find.byType(MaterialApp), matchesGoldenFile('$_out/$name.png'));
}

Future<VaultService> _seed(WidgetTester tester) async =>
    (await tester.runAsync(_seedReal))!;

Future<VaultService> _seedReal() async {
  final service = VaultService(MemoryVaultStorage());
  await service.create('Correct-Horse-Battery-42');
  final now = DateTime.now();
  var n = 0;
  Future<void> add(String title, String user, String pw,
      {String? url, String? otp, ItemKind kind = ItemKind.login,
      String notes = '', bool fav = false}) async {
    await service.save(VaultItem(
          id: 'id${n++}',
          kind: kind,
          title: title,
          username: user,
          password: pw,
          urls: url == null ? [] : [url],
          otpAuth: otp,
          notes: notes,
          favorite: fav,
          createdAt: now,
          updatedAt: now.subtract(Duration(days: n * 3)),
        ));
  }

  await add('Apple', 'jane@icloud.com', 'kibvoq-7ruxzy-Wefnyp',
      url: 'https://appleid.apple.com', fav: true);
  await add('Amazon', 'jane.doe@gmail.com', 'Summer2024!', url: 'amazon.com');
  await add('Bank of Nowhere', 'jdoe', 'X9#vL2@qR8!mP4\$kT7',
      url: 'https://bank.example', otp: 'JBSWY3DPEHPK3PXP');
  await add('Discord', 'janedoe', 'Summer2024!', url: 'discord.com');
  await add('GitHub', 'janedoe', 'Tq7!vR2#pL9@wX4\$', url: 'github.com',
      otp: 'otpauth://totp/GitHub:janedoe?secret=GEZDGNBVGY3TQOJQ&issuer=GitHub',
      fav: true);
  await add('Netflix', 'jane@icloud.com', 'password1', url: 'netflix.com');
  await add('Notion', 'jane@icloud.com', 'Glacier-Pudding-Sly-Overtake7', url: 'notion.so');
  await add('Spotify', 'janedoe', 'aN8\$fK2!pQ7@zR3#', url: 'spotify.com');
  await add('Home Wi-Fi', 'Doe-Family-5G', 'correct-staple-orbit', kind: ItemKind.wifi);
  await add('Recovery codes', '', '', kind: ItemKind.note,
      notes: 'GitHub: 1a2b-3c4d, 5e6f-7g8h\nGoogle: 1234 5678');
  await service.registerPasskey(
        '{"rp":{"id":"github.com","name":"GitHub"},"user":{"id":"dXNlcg","name":"janedoe","displayName":"Jane"},"challenge":"AA","pubKeyCredParams":[{"type":"public-key","alg":-7}]}',
        origin: 'https://github.com',
      );
  await service.registerPasskey(
        '{"rp":{"id":"google.com","name":"Google"},"user":{"id":"dXNlcjI","name":"jane.doe@gmail.com","displayName":"Jane"},"challenge":"AA","pubKeyCredParams":[{"type":"public-key","alg":-7}]}',
        origin: 'https://google.com',
      );
  await service.rememberGenerated('Tq7!vR2#pL9@wX4\$');
  return service;
}

void main() {
  final skip = _out == null ? 'Set VAULTLY_SCREENSHOTS to render' : null;

  for (final dark in [false, true]) {
    final suffix = dark ? '-dark' : '';
    testWidgets('phone screenshots$suffix', skip: skip != null, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
      tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
      final settings =
          AppSettings(themeMode: dark ? ThemeMode.dark : ThemeMode.light);

      if (!dark) {
        await tester.pumpWidget(testApp(VaultService(MemoryVaultStorage()),
            settings: settings));
        await _shot(tester, '01-welcome');
        await tester.tap(find.text('Create Vault'));
        await settle(tester);
        await tester.enterText(find.byType(TextField).at(0), 'Glacier-Pudding-Sly-Overtake7');
        await tester.pump();
        await _shot(tester, '02-create-master-password');
        await tester.pumpWidget(const SizedBox());
      }

      final service = await _seed(tester);
      service.lock();
      await tester.pumpWidget(
          testApp(service, exists: true, settings: settings));
      await _shot(tester, '03-locked$suffix');
      await tester.enterText(find.byType(TextField), 'Correct-Horse-Battery-42');
      await tester.tap(find.widgetWithText(TextButton, 'Unlock'));
      await waitReal(tester, 1500);
      await settle(tester);
      await _shot(tester, '04-home$suffix');

      await tester.tap(find.text('All'));
      await settle(tester);
      await _shot(tester, '05-all-passwords$suffix');

      await tester.tap(find.text('GitHub'));
      await settle(tester);
      await _shot(tester, '06-detail$suffix');

      await tester.tap(find.text('Edit'));
      await settle(tester);
      await _shot(tester, '07-edit$suffix');
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.popUntil((r) => r.isFirst);
      await settle(tester);

      await tester.tap(find.text('Security'));
      await settle(tester);
      await _shot(tester, '08-security$suffix');
      nav.popUntil((r) => r.isFirst);
      await settle(tester);

      await tester.tap(find.text('Passkeys'));
      await settle(tester);
      await _shot(tester, '09-passkeys$suffix');
      nav.popUntil((r) => r.isFirst);
      await settle(tester);

      await tester.tap(find.text('Generator'));
      await settle(tester);
      await _shot(tester, '10-generator$suffix');
      await tester.tap(find.text('Memorable'));
      await settle(tester);
      await _shot(tester, '11-generator-memorable$suffix');

      await tester.tap(find.text('Settings'));
      await settle(tester);
      await _shot(tester, '12-settings$suffix');

      await tester.pumpWidget(const SizedBox());
      await settle(tester, 30);
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    });
  }

  testWidgets('tablet screenshot', skip: skip != null, (tester) async {
    tester.view.physicalSize = const Size(2732, 2048);
    tester.view.devicePixelRatio = 2;
    final service = await _seed(tester);
    service.lock();
    await tester.pumpWidget(testApp(service, exists: true));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Correct-Horse-Battery-42');
    await tester.tap(find.widgetWithText(TextButton, 'Unlock'));
    await waitReal(tester, 1500);
    await settle(tester);
    await _shot(tester, '13-tablet');
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 30);
    tester.view.reset();
  });
}
