import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/generator/password_generator.dart';
import '../../core/security/password_strength.dart';
import '../../state/providers.dart';
import '../actions.dart';
import '../theme/app_theme.dart';
import '../widgets/grouped.dart';
import '../widgets/password_widgets.dart';
import '../widgets/vault_page.dart';

class GeneratorScreen extends StatelessWidget {
  const GeneratorScreen({super.key});

  @override
  Widget build(BuildContext context) => const VaultPage(
        title: 'Generator',
        slivers: [SliverToBoxAdapter(child: GeneratorPanel())],
      );
}

/// Opens the generator as a sheet and returns the chosen password.
Future<String?> showGeneratorSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => SingleChildScrollView(
          controller: scroll,
          child: GeneratorPanel(onUse: (p) => Navigator.pop(ctx, p)),
        ),
      ),
    );

class GeneratorPanel extends ConsumerStatefulWidget {
  const GeneratorPanel({super.key, this.onUse});

  /// When set, shows a "Use Password" button (editor sheet mode).
  final ValueChanged<String>? onUse;

  @override
  ConsumerState<GeneratorPanel> createState() => _GeneratorPanelState();
}

class _GeneratorPanelState extends ConsumerState<GeneratorPanel> {
  late String _password;

  GeneratorOptions get _opts => ref.read(settingsProvider).generator;

  @override
  void initState() {
    super.initState();
    _password = PasswordGenerator.generate(_opts);
  }

  void _regen() =>
      setState(() => _password = PasswordGenerator.generate(_opts));

  Future<void> _set(GeneratorOptions o) async {
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(generator: o));
    _regen();
  }

  Future<void> _copy() async {
    await copySecret(context, ref, _password, what: 'Password copied');
    await ref.read(vaultProvider.notifier).rememberGenerated(_password);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final o = ref.watch(settingsProvider.select((s) => s.generator));
    final bits = PasswordGenerator.entropyBits(o);
    final level = PasswordStrength.levelForBits(bits);
    final history = ref.watch(vaultProvider.select((s) => s.generated));

    Widget slider(String label, int value, int min, int max,
            ValueChanged<int> onChanged) =>
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            children: [
              Row(children: [
                Text(label, style: const TextStyle(fontSize: 17)),
                const Spacer(),
                Text('$value',
                    style: TextStyle(
                        fontSize: 17,
                        color: c.secondaryLabel,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
              const SizedBox(height: 10),
              Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max - min,
                onChanged: (v) {
                  if (v.round() != value) onChanged(v.round());
                },
              ),
            ],
          ),
        );

    Widget toggle(String label, bool value, ValueChanged<bool> onChanged) =>
        InsetRow(
          title: Text(label),
          trailing: CupertinoSwitch(
              value: value, activeTrackColor: c.green, onChanged: onChanged),
          onTap: () => onChanged(!value),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Result card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: GestureDetector(
                        key: ValueKey(_password),
                        onTap: _copy,
                        child: PasswordText(_password,
                            fontSize: _password.length > 32 ? 18 : 22,
                            textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                StrengthMeter(
                    level: level,
                    label: '${level.label} · ${bits.round()} bits of entropy'),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: PillButton(
                      label: widget.onUse != null ? 'Use Password' : 'Copy',
                      icon: widget.onUse != null
                          ? CupertinoIcons.checkmark_alt
                          : CupertinoIcons.doc_on_doc,
                      onPressed: () async {
                        if (widget.onUse != null) {
                          await ref
                              .read(vaultProvider.notifier)
                              .rememberGenerated(_password);
                          widget.onUse!(_password);
                        } else {
                          await _copy();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 64,
                    child: PillButton(
                      label: '',
                      icon: CupertinoIcons.arrow_clockwise,
                      tinted: true,
                      onPressed: _regen,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: CupertinoSlidingSegmentedControl<GeneratorMode>(
            groupValue: o.mode,
            backgroundColor: c.fill,
            thumbColor: c.surfaceHigh,
            children: {
              for (final m in GeneratorMode.values)
                m: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(m.label,
                      style: TextStyle(fontSize: 13, color: c.label)),
                ),
            },
            onValueChanged: (m) => _set(o.copyWith(mode: m)),
          ),
        ),

        if (o.mode == GeneratorMode.random) ...[
          InsetSection(children: [
            slider('Length', o.length, GeneratorOptions.minLength,
                GeneratorOptions.maxLength, (v) => _set(o.copyWith(length: v))),
          ]),
          InsetSection(
            footer: const Text(
                'Avoiding ambiguous characters (like l, 1, O and 0) makes passwords easier to read and type.'),
            children: [
              toggle('Uppercase (A–Z)', o.uppercase,
                  (v) => _set(o.copyWith(uppercase: v))),
              toggle('Lowercase (a–z)', o.lowercase,
                  (v) => _set(o.copyWith(lowercase: v))),
              toggle('Numbers (0–9)', o.digits, (v) => _set(o.copyWith(digits: v))),
              toggle('Symbols (!@#\$…)', o.symbols,
                  (v) => _set(o.copyWith(symbols: v))),
              toggle('Avoid Ambiguous', o.avoidAmbiguous,
                  (v) => _set(o.copyWith(avoidAmbiguous: v))),
            ],
          ),
        ],

        if (o.mode == GeneratorMode.memorable) ...[
          InsetSection(children: [
            slider('Words', o.wordCount, GeneratorOptions.minWords,
                GeneratorOptions.maxWords, (v) => _set(o.copyWith(wordCount: v))),
          ]),
          InsetSection(
            footer: const Text(
                'Words are picked at random from the EFF’s 7,776-word list. Five or more words make a strong master password.'),
            children: [
              InsetRow(
                title: const Text('Separator'),
                trailing: CupertinoSlidingSegmentedControl<String>(
                  groupValue: o.separator,
                  backgroundColor: c.fill,
                  thumbColor: c.surfaceHigh,
                  children: {
                    for (final s in ['-', '.', '_', ' '])
                      s: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(s == ' ' ? '␣' : s,
                            style: TextStyle(fontSize: 15, color: c.label)),
                      ),
                  },
                  onValueChanged: (s) => _set(o.copyWith(separator: s)),
                ),
              ),
              toggle('Capitalize', o.capitalize,
                  (v) => _set(o.copyWith(capitalize: v))),
              toggle('Include Number', o.includeNumber,
                  (v) => _set(o.copyWith(includeNumber: v))),
            ],
          ),
        ],

        if (o.mode == GeneratorMode.pin)
          InsetSection(
            footer: const Text('PINs are only suitable where the number of attempts is limited.'),
            children: [
              slider('Digits', o.pinLength, GeneratorOptions.minPin,
                  GeneratorOptions.maxPin, (v) => _set(o.copyWith(pinLength: v))),
            ],
          ),

        if (o.mode == GeneratorMode.apple)
          const InsetSection(
            footer: Text(
                'Three groups of six letters and numbers, like Apple’s suggested passwords. Accepted by almost every website and easy to type on a phone keyboard.'),
            children: [],
          ),

        if (widget.onUse == null)
          InsetSection(
            footer: const Text(
                'Copied passwords are remembered (encrypted) so you never lose one created for a sign-up form.'),
            children: [
              InsetRow(
                leading: SettingsIcon(CupertinoIcons.clock_fill, c.gray),
                title: const Text('Generated Password History'),
                value: Text('${history.length}'),
                showChevron: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const GeneratedHistoryScreen())),
              ),
            ],
          ),
      ],
    );
  }
}

class GeneratedHistoryScreen extends ConsumerWidget {
  const GeneratedHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(vaultProvider.select((s) => s.generated));
    return VaultPage(
      title: 'History',
      previousPageTitle: 'Generator',
      largeTitle: false,
      trailing: history.isEmpty
          ? null
          : CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                final ok = await confirmDestructive(context,
                    title: 'Clear History?', action: 'Clear History');
                if (ok) await ref.read(vaultProvider.notifier).clearGenerated();
              },
              child: const Text('Clear'),
            ),
      slivers: [
        SliverToBoxAdapter(
          child: history.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('No generated passwords yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.secondaryLabel)),
                )
              : InsetSection(children: [
                  for (final g in history)
                    InsetRow(
                      title: PasswordText(g.value),
                      subtitle: Text(formatRelative(g.createdAt)),
                      onTap: () => copySecret(context, ref, g.value,
                          what: 'Password copied'),
                    ),
                ]),
        ),
      ],
    );
  }
}
