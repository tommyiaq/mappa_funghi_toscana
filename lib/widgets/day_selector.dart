import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../utils/date_utils.dart';

class DaySelector extends StatelessWidget {
  final int selectedDayIndex;
  final Function(int) onDayChanged;

  const DaySelector({
    super.key,
    required this.selectedDayIndex,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    
    return DropdownButtonFormField<int>(
      value: selectedDayIndex,
      decoration: const InputDecoration(
        labelText: 'Giorno',
        border: OutlineInputBorder(),
        contentPadding: AppConstants.controlPadding,
      ),
      items: List.generate(7, (i) {
        final date = now.add(Duration(days: i));
        String label;
        if (i == 0) {
          label = 'Oggi';
        } else if (i == 1) {
          label = 'Domani';
        } else {
          label = formatDayLabel(date);
        }
        return DropdownMenuItem(
          value: i,
          child: Text(label),
        );
      }),
      onChanged: (val) {
        if (val != null) {
          onDayChanged(val);
        }
      },
    );
  }
}
