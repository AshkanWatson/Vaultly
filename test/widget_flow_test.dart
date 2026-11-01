import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/data/vault_service.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('onboarding → add password → search → lock → unlock',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final storage = MemoryVaultStorage();
    final service = VaultService(storage);
    await tester.pumpWidget(testApp(service));
    await settle(tester);

    expect(find.text('Welcome to Vaultly'), findsOneWidget);
    await tester.tap(find.text('Create Vault'));
    await settle(tester);

    // Weak master passwords are refused.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'password');
    await tester.enterText(fields.at(1), 'password');
    await tester.pump();
    final createButton = find.widgetWithText(TextButton, 'Create Vault');
    await tester.scrollUntilVisible(createButton, 200,
        scrollable: find.byType(Scrollable).last);
    expect(tester.widget<TextButton>(createButton).onPressed, isNull);

    const master = 'Correct-Horse-Battery-Staple-42';
    await tester.enterText(fields.at(0), master);
    await tester.enterText(fields.at(1), master);
    await tester.pump();
    await tester.tap(createButton);
    await waitReal(tester);
    await settle(tester);

    expect(service.isUnlocked, isTrue);
    expect(find.text('Passwords'), findsWidgets);
    expect(find.text('Passkeys'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);

    // Add a password via "+" → New Password.
    await tester.tap(find.byIcon(CupertinoIcons.plus));
    await settle(tester);
    await tester.tap(find.text('New Password'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'GitHub');
    await tester.enterText(
        find.widgetWithText(TextField, 'User Name or Email'), 'octocat');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'hunter2');
    await tester.pump();
    expect(find.textContaining('Weak'), findsWidgets);
    await tester.tap(find.text('Save'));
    await settle(tester, 30);

    expect(service.activeItems.single.title, 'GitHub');
    expect(storage.vault, isNot(contains('octocat')));

    // The weak password is reported by the Security tile.
    await tester.tap(find.text('Security'));
    await settle(tester);
    expect(find.text('1 Security Recommendation'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    await tester.tap(find.text('GitHub'));
    await settle(tester);
    expect(find.text('Weak Password'), findsOneWidget);
    expect(find.text('octocat'), findsOneWidget);

    // Lock from Settings.
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.popUntil((r) => r.isFirst);
    await settle(tester);
    await tester.tap(find.text('Settings'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Lock Now'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Lock Now'));
    await settle(tester);
    expect(service.isUnlocked, isFalse);
    expect(find.text('Vaultly is Locked'), findsOneWidget);

    // Wrong password, then the right one.
    await tester.enterText(find.byType(TextField), 'nope');
    await tester.tap(find.widgetWithText(TextButton, 'Unlock'));
    await waitReal(tester);
    await settle(tester);
    expect(find.text('Incorrect password'), findsOneWidget);

    await tester.enterText(find.byType(TextField), master);
    await tester.tap(find.widgetWithText(TextButton, 'Unlock'));
    await waitReal(tester);
    await settle(tester);
    expect(service.isUnlocked, isTrue);
    expect(find.text('Passwords'), findsWidgets);

    // Tear down so no timers stay pending.
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 30);
  });
}
