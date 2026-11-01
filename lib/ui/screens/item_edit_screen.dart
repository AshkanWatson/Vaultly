import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/import_export/csv_importer.dart';
import '../../core/otp/totp.dart';
import '../../core/security/password_strength.dart';
import '../../data/vault_item.dart';
import '../../state/providers.dart';
import '../actions.dart';
import '../theme/app_theme.dart';
import '../widgets/grouped.dart';
import '../widgets/password_widgets.dart';
import '../widgets/toast.dart';
import '../widgets/vault_page.dart';
import 'generator_screen.dart';

class ItemEditScreen extends ConsumerStatefulWidget {
  const ItemEditScreen({
    super.key,
    this.item,
    this.kind = ItemKind.login,
    this.suggestedPassword,
  });

  final VaultItem? item;
  final ItemKind kind;
  final String? suggestedPassword;

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  late final ItemKind _kind = widget.item?.kind ?? widget.kind;
  late final _title = TextEditingController(text: widget.item?.title);
  late final _user = TextEditingController(text: widget.item?.username);
  late final _pass = TextEditingController(
      text: widget.suggestedPassword ?? widget.item?.password);
  late final _notes = TextEditingController(text: widget.item?.notes);
  late final _otp = TextEditingController(text: widget.item?.otpAuth);
  late final List<TextEditingController> _urls = [
    for (final u in widget.item?.urls ?? const <String>[])
      TextEditingController(text: u),
  ];
  bool _showPassword = true;
  bool _saving = false;
  late final String _initial = _snapshot();

  @override
  void initState() {
    super.initState();
    if (_kind == ItemKind.login && _urls.isEmpty) {
      _urls.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _user, _pass, _notes, _otp, ..._urls]) {
      c.dispose();
    }
    super.dispose();
  }

  String _snapshot() => [
        _title.text, _user.text, _pass.text, _notes.text, _otp.text,
        ..._urls.map((u) => u.text),
      ].join('\u0000');

  bool get _dirty => _snapshot() != _initial || widget.suggestedPassword != null;

  bool get _canSave => switch (_kind) {
        ItemKind.login => _title.text.trim().isNotEmpty ||
            _urls.any((u) => u.text.trim().isNotEmpty) ||
            _user.text.isNotEmpty,
        ItemKind.wifi => _user.text.trim().isNotEmpty,
        ItemKind.note => _title.text.trim().isNotEmpty || _notes.text.isNotEmpty,
      };

  String get _heading => widget.item == null
      ? 'New ${_kind.label}'
      : 'Edit ${_kind.label}';

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    final otp = _otp.text.trim();
    if (otp.isNotEmpty && TotpConfig.tryParse(otp) == null) {
      showToast(context, 'The verification code setup key is not valid', error: true);
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final urls = _urls.map((u) => u.text.trim()).where((u) => u.isNotEmpty).toList();
    final base = widget.item ??
        VaultItem(id: newItemId(), kind: _kind, createdAt: now, updatedAt: now);
    final oldSite = widget.item?.urls.isEmpty ?? true ? null : widget.item!.urls.first;
    final newSite = urls.isEmpty ? null : urls.first;
    final item = base.copyWith(
      clearIcon: oldSite != newSite,
      title: _title.text.trim(),
      username: _user.text.trim(),
      password: _pass.text,
      urls: urls,
      notes: _notes.text,
      otpAuth: otp.isEmpty ? null : otp,
      clearOtp: otp.isEmpty,
    );
    final ctrl = ref.read(vaultProvider.notifier);
    final saved = await ctrl.save(item);
    // Fetch the website icon in the background; the list updates when done.
    unawaited(ctrl.fetchIcon(saved));
    if (!mounted) return;
    Navigator.pop(context);
    showToast(context, 'Saved');
  }

  Future<void> _cancel() async {
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final discard = await confirmDestructive(context,
        title: 'Discard Changes?',
        message: 'Your changes will be lost.',
        action: 'Discard Changes');
    if (discard && mounted) Navigator.pop(context);
  }

  Future<void> _generate() async {
    final p = await showGeneratorSheet(context);
    if (p != null) setState(() => _pass.text = p);
  }

  Future<void> _pasteOtp() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) setState(() => _otp.text = data!.text!.trim());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final strength = PasswordStrength.evaluate(_pass.text);
    final otpConfig = TotpConfig.tryParse(_otp.text);
    void changed(String _) => setState(() {});

    final passwordRow = InputRow(
      controller: _pass,
      placeholder: 'Password',
      obscure: !_showPassword,
      monospace: true,
      autofillHints: const [AutofillHints.newPassword],
      onChanged: changed,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(_showPassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
              size: 20, color: c.gray),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Generate Password',
          icon: Icon(CupertinoIcons.wand_stars, size: 20, color: c.blue),
          onPressed: _generate,
        ),
      ]),
    );

    final sections = <Widget>[
      if (_kind == ItemKind.login) ...[
        InsetSection(children: [
          InputRow(
            controller: _title,
            placeholder: 'Title',
            textCapitalization: TextCapitalization.words,
            onChanged: changed,
            autofocus: widget.item == null,
          ),
        ]),
        InsetSection(
          footer: _pass.text.isEmpty
              ? null
              : StrengthMeter(
                  level: strength.level,
                  compact: true,
                  label: strength.warning == null
                      ? strength.level.label
                      : '${strength.level.label} — ${strength.warning}'),
          children: [
            InputRow(
              controller: _user,
              placeholder: 'User Name or Email',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              onChanged: changed,
            ),
            passwordRow,
          ],
        ),
        if (_pass.text.isEmpty)
          InsetSection(children: [
            InsetRow(
              leading: Icon(CupertinoIcons.wand_stars, color: c.blue),
              title: const Text('Suggest Strong Password'),
              accent: true,
              onTap: _generate,
            ),
          ]),
        InsetSection(
          header: 'Websites',
          children: [
            for (var i = 0; i < _urls.length; i++)
              InputRow(
                controller: _urls[i],
                placeholder: 'example.com',
                keyboardType: TextInputType.url,
                onChanged: changed,
                trailing: _urls.length > 1 || _urls[i].text.isNotEmpty
                    ? IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(CupertinoIcons.minus_circle_fill, color: c.red, size: 22),
                        onPressed: () => setState(() {
                          _urls.removeAt(i).dispose();
                          if (_urls.isEmpty) _urls.add(TextEditingController());
                        }),
                      )
                    : null,
              ),
            InsetRow(
              leading: Icon(CupertinoIcons.plus_circle_fill, color: c.green, size: 22),
              title: const Text('Add Website'),
              onTap: () => setState(() => _urls.add(TextEditingController())),
            ),
          ],
        ),
        InsetSection(
          header: 'Verification Code',
          footer: otpConfig != null
              ? Row(children: [
                  const Text('Current code: '),
                  OtpCodeView(config: otpConfig, fontSize: 15),
                ])
              : Text(_otp.text.trim().isEmpty
                  ? 'Paste the setup key or otpauth:// link shown when you enable two-factor authentication on a website. Codes are generated offline.'
                  : 'This doesn’t look like a valid setup key.'),
          children: [
            InputRow(
              controller: _otp,
              placeholder: 'Setup Key',
              monospace: true,
              onChanged: changed,
              trailing: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Paste',
                icon: Icon(CupertinoIcons.doc_on_clipboard, size: 20, color: c.blue),
                onPressed: _pasteOtp,
              ),
            ),
          ],
        ),
        InsetSection(header: 'Notes', children: [
          InputRow(controller: _notes, placeholder: 'Add Notes', maxLines: null, onChanged: changed),
        ]),
      ],
      if (_kind == ItemKind.wifi) ...[
        InsetSection(children: [
          InputRow(
            controller: _user,
            placeholder: 'Network Name (SSID)',
            onChanged: changed,
            autofocus: widget.item == null,
          ),
          passwordRow,
        ]),
        InsetSection(header: 'Notes', children: [
          InputRow(controller: _notes, placeholder: 'Router, location, security type…', maxLines: null, onChanged: changed),
        ]),
      ],
      if (_kind == ItemKind.note) ...[
        InsetSection(children: [
          InputRow(
            controller: _title,
            placeholder: 'Title',
            textCapitalization: TextCapitalization.sentences,
            onChanged: changed,
            autofocus: widget.item == null,
          ),
        ]),
        InsetSection(children: [
          InputRow(controller: _notes, placeholder: 'Note', maxLines: null, onChanged: changed),
        ]),
      ],
    ];

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: CupertinoNavigationBar(
          backgroundColor: c.background,
          border: null,
          automaticallyImplyLeading: false,
          leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _cancel,
              child: const Text('Cancel')),
          middle: Text(_heading),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _canSave && !_saving ? _save : null,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
            child: ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 40),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: sections,
            ),
          ),
        ),
      ),
    );
  }
}
