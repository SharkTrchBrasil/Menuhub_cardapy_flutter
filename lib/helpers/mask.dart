

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';


final phoneMask = MaskTextInputFormatter(
  mask: '(##) #####-####', // Máscara para números internacionais
  filter: {"#": RegExp(r'[0-9]')},
  type: MaskAutoCompletionType.lazy,
);


final cepMask = MaskTextInputFormatter(
  mask: '##.###-###',
  filter: {"#": RegExp(r'[0-9]')},
  type: MaskAutoCompletionType.lazy,
);

final numberFormat = NumberFormat.currency(locale: 'pt_BR');
final dateFormat = DateFormat('dd/MM/yyyy');


String? formatTime(TimeOfDay? time) {
  if (time == null) return null;
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

TimeOfDay parseTimeOfDay(String timeString) {
  final parts = timeString.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String formatTimeOfDay(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}


class DatePickerField extends StatefulWidget {
  final String title;
  final String? initialValue;
  final void Function(String) onChanged;

  const DatePickerField({
    super.key,
    required this.title,
    this.initialValue,
    required this.onChanged,
  });

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  late TextEditingController _controller;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      _selectedDate = DateFormat('dd/MM/yyyy').parse(widget.initialValue!);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('pt', 'BR'),
    );

    if (picked != null) {
      final formatted = DateFormat('dd/MM/yyyy').format(picked);
      _controller.text = formatted;
      widget.onChanged(formatted);
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: widget.title,
        suffixIcon: const Icon(Icons.calendar_today),
        hintText: 'DD/MM/AAAA',
      ),
      onTap: _pickDate,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Informe a data';
        }
        final regex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
        if (!regex.hasMatch(value)) {
          return 'Data inválida';
        }
        return null;
      },
    );
  }
}