import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tokens.dart';

/// `TextFormField` dengan label di atas. Semua parameter fungsional
/// `TextFormField` diteruskan apa adanya (controller, validator, onChanged,
/// formatter, dll) supaya tidak ada fitur input lama yang hilang.
class AppInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldSetter<String>? onSaved;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const AppInput({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onSaved,
    this.onTap,
    this.readOnly = false,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLines,
    this.minLines,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.xs + 2),
        ],
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          focusNode: focusNode,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          onSaved: onSaved,
          onTap: onTap,
          readOnly: readOnly,
          obscureText: obscureText,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          maxLines: maxLines ?? 1,
          minLines: minLines,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            counterText: '',
          ),
        ),
      ],
    );
  }
}
