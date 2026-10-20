import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Interactive 6-digit OTP Input Boxes with automatic focus progression,
/// backspace regression, paste handling, and active border feedback.
class OtpInputBoxes extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool hasError;

  const OtpInputBoxes({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.enabled = true,
    this.hasError = false,
  });

  @override
  State<OtpInputBoxes> createState() => OtpInputBoxesState();
}

class OtpInputBoxesState extends State<OtpInputBoxes> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(
      widget.length,
      (i) => FocusNode(debugLabel: 'otp_box_$i'),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  /// Programmatically fill OTP digits (e.g., from quick-paste or demo banner)
  void setCode(String code) {
    final sanitized = code.replaceAll(RegExp(r'\D'), '').trim();
    for (int i = 0; i < widget.length; i++) {
      if (i < sanitized.length) {
        _controllers[i].text = sanitized[i];
      } else {
        _controllers[i].clear();
      }
    }
    if (sanitized.length >= widget.length) {
      final fullCode = sanitized.substring(0, widget.length);
      widget.onCompleted(fullCode);
      widget.onChanged?.call(fullCode);
      _focusNodes.last.unfocus();
    } else if (sanitized.isNotEmpty) {
      _focusNodes[sanitized.length.clamp(0, widget.length - 1)].requestFocus();
      widget.onChanged?.call(_getCurrentCode());
    }
  }

  /// Clear all boxes and return focus to first box
  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty && mounted) {
      _focusNodes.first.requestFocus();
    }
    widget.onChanged?.call('');
  }

  String _getCurrentCode() {
    return _controllers.map((c) => c.text).join();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Pasted multi-character string
      setCode(value);
      return;
    }

    if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    final code = _getCurrentCode();
    widget.onChanged?.call(code);

    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        const double gap = 8;
        final double boxWidth =
            ((availableWidth - (widget.length - 1) * gap) / widget.length)
                .clamp(32.0, 48.0);
        final double boxHeight = (boxWidth * 1.22).clamp(44.0, 56.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(widget.length, (index) {
            return _buildDigitBox(index, boxWidth, boxHeight);
          }),
        );
      },
    );
  }

  Widget _buildDigitBox(int index, double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_controllers[index].text.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
              _controllers[index - 1].clear();
              widget.onChanged?.call(_getCurrentCode());
            }
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: widget.hasError
                ? const Color(0xFFDC2626)
                : const Color(0xFF0F172A),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: widget.enabled ? Colors.white : const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: widget.hasError
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFCBD5E1),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: widget.hasError
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF4F46E5),
                width: 2.0,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.0,
              ),
            ),
          ),
          onChanged: (val) => _onDigitChanged(index, val),
        ),
      ),
    );
  }
}
