import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/mizani_theme.dart';

/// One form question, drawn from its API `type`. An unknown type falls back
/// to a text field, so a new server type can't break an older app.
class QuestionField extends StatelessWidget {
  const QuestionField({
    super.key,
    required this.question,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final FormQuestion question;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String? errorText;

  String get _label => question.required ? question.label : '${question.label} (optional)';

  @override
  Widget build(BuildContext context) => switch (question.type) {
        'select' => _select(),
        'multiselect' => _multiselect(),
        'boolean' => _boolean(),
        'date' => _date(context),
        _ => _text(),
      };

  Widget _text() {
    final isNumeric = question.type == 'number' || question.type == 'currency';
    return TextFormField(
      initialValue: _display(value),
      maxLines: question.type == 'textarea' ? 4 : 1,
      keyboardType: switch (question.type) {
        'number' || 'currency' => const TextInputType.numberWithOptions(decimal: true),
        'phone' => TextInputType.phone,
        'email' => TextInputType.emailAddress,
        'textarea' => TextInputType.multiline,
        _ => TextInputType.text,
      },
      decoration: InputDecoration(
        labelText: _label,
        prefixText: question.type == 'currency' ? 'KES ' : null,
        errorText: errorText,
        errorMaxLines: 3,
      ),
      onChanged: (text) {
        final trimmed = text.trim();
        if (trimmed.isEmpty) {
          onChanged(null);
        } else if (isNumeric) {
          onChanged(num.tryParse(trimmed.replaceAll(',', '')) ?? trimmed);
        } else {
          onChanged(text);
        }
      },
    );
  }

  Widget _select() {
    final selected = question.options.contains(value) ? value as String : null;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: _label, errorText: errorText),
      items: question.options
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _multiselect() {
    final selected = value is List ? (value as List).map((v) => v.toString()).toList() : <String>[];
    return _Labelled(
      label: _label,
      errorText: errorText,
      child: Column(
        children: question.options
            .map(
              (option) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(option),
                value: selected.contains(option),
                onChanged: (checked) {
                  final next = checked == true
                      ? [...selected, option]
                      : selected.where((item) => item != option).toList();
                  onChanged(next.isEmpty ? null : next);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _boolean() {
    return _Labelled(
      label: _label,
      errorText: errorText,
      child: Row(
        children: [
          ChoiceChip(label: const Text('Yes'), selected: value == true, onSelected: (_) => onChanged(true)),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('No'), selected: value == false, onSelected: (_) => onChanged(false)),
        ],
      ),
    );
  }

  Widget _date(BuildContext context) {
    final current = value is String ? DateTime.tryParse(value as String) : null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: current ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onChanged(picked.toIso8601String().substring(0, 10));
        }
      },
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: _label,
          errorText: errorText,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(value is String ? value as String : ''),
      ),
    );
  }

  String _display(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is num && value == value.truncate()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child, this.errorText});

  final String label;
  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(errorText!, style: const TextStyle(color: MizaniColors.bad, fontSize: 12)),
          ),
      ],
    );
  }
}

/// A local check before going to the next step. The server has the last
/// word at submit, and its errors come back against the same fields.
String? validateAnswer(FormQuestion question, Object? value) {
  if (value == null || value == '' || (value is List && value.isEmpty)) {
    return question.required ? 'Please answer this question.' : null;
  }

  return switch (question.type) {
    'number' || 'currency' when value is! num => 'Enter a number.',
    'number' || 'currency' when (value as num) < 0 => 'Enter a number that is not negative.',
    'phone' when !RegExp(r'^\+?[0-9 \-]{9,20}$').hasMatch(value.toString().trim()) =>
      'Enter a phone number like +254712345678.',
    'email' when !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.toString().trim()) =>
      'Enter a valid email address.',
    _ => null,
  };
}
