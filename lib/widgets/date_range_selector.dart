import 'package:flutter/material.dart';
import '../utils/date_utils.dart';

class DateRangeSelector extends StatelessWidget {
  final String? startDate;
  final String? endDate;
  final DateTime minCsvDate;
  final DateTime maxCsvDate;
  final List<String> availableDates;
  final Function(String, String) onDateRangeChanged;

  const DateRangeSelector({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.minCsvDate,
    required this.maxCsvDate,
    required this.availableDates,
    required this.onDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.date_range),
      label: Text(
        startDate == null || endDate == null
            ? "Seleziona intervallo date"
            : startDate == endDate
                ? "Data: $startDate"
                : "Dal $startDate al $endDate",
      ),
      onPressed: () async {
        final range = await showCustomDateRangePicker(
          context: context,
          firstDate: minCsvDate,
          lastDate: maxCsvDate,
          initialStartDate: parseCsvDate(startDate!),
          initialEndDate: parseCsvDate(endDate!),
        );
        
        if (range != null && context.mounted) {
          final selectedStart = formatCsvDate(range.start);
          final selectedEnd = formatCsvDate(range.end);
          
          if (availableDates.contains(selectedStart) &&
              availableDates.contains(selectedEnd)) {
            onDateRangeChanged(selectedStart, selectedEnd);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Le date selezionate non sono presenti nel file CSV.'),
              ),
            );
          }
        }
      },
    );
  }
}
