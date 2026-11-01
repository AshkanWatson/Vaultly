import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/otp/totp.dart';
import '../../core/security/password_strength.dart';
import '../theme/app_theme.dart';

/// Monospaced password with digits and symbols coloured (easy to read aloud
/// or type on another device).
class PasswordText extends StatelessWidget {
  const PasswordText(this.password,
      {super.key, this.fontSize = 17, this.textAlign = TextAlign.start});

  final String password;
  final double fontSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spans = password.characters.map((ch) {
      final Color color;
      if (RegExp(r'[0-9]').hasMatch(ch)) {
        color = c.blue;
      } else if (RegExp(r'[a-zA-Z]').hasMatch(ch)) {
        color = c.label;
      } else {
        color = c.orange;
      }
      return TextSpan(text: ch, style: TextStyle(color: color));
    }).toList();
    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      style: TextStyle(
        fontSize: fontSize,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Menlo', 'SF Mono', 'Courier New', 'Roboto Mono'],
        letterSpacing: 0.5,
        height: 1.35,
      ),
    );
  }
}

Color strengthColor(BuildContext context, StrengthLevel l) {
  final c = context.colors;
  return switch (l) {
    StrengthLevel.veryWeak => c.red,
    StrengthLevel.weak => c.orange,
    StrengthLevel.fair => c.yellow,
    StrengthLevel.strong => c.green,
    StrengthLevel.veryStrong => c.green,
  };
}

/// Five-segment strength meter.
class StrengthMeter extends StatelessWidget {
  const StrengthMeter(
      {super.key, required this.level, this.label, this.compact = false});

  final StrengthLevel level;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = strengthColor(context, level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: List.generate(5, (i) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: compact ? 3 : 4,
                margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                decoration: BoxDecoration(
                  color: i <= level.index ? color : c.fill,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label!,
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

/// Live TOTP code with a countdown ring.
class OtpCodeView extends StatefulWidget {
  const OtpCodeView({super.key, required this.config, this.fontSize = 22});

  final TotpConfig config;
  final double fontSize;

  @override
  State<OtpCodeView> createState() => _OtpCodeViewState();
}

class _OtpCodeViewState extends State<OtpCodeView> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(milliseconds: 500), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  static String format(String code) {
    final mid = code.length ~/ 2;
    return '${code.substring(0, mid)} ${code.substring(mid)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final code = widget.config.codeAt(now);
    final remaining = widget.config.secondsRemaining(now);
    final urgent = remaining <= 5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(format(code),
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w600,
              color: urgent ? c.red : c.label,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 1,
            )),
        const SizedBox(width: 10),
        SizedBox(
          width: 20,
          height: 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: remaining / widget.config.period,
                strokeWidth: 2.5,
                color: urgent ? c.red : c.blue,
                backgroundColor: c.fill,
              ),
              Text('$remaining',
                  style: TextStyle(fontSize: 8, color: c.secondaryLabel)),
            ],
          ),
        ),
      ],
    );
  }
}
