import 'package:flutter/material.dart';
import 'package:flutter_date_pickers/flutter_date_pickers.dart' as dp;

/// Shows a custom date range picker dialog and returns the selected range.
Future<DateTimeRange?> showCustomDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime initialStartDate,
  required DateTime initialEndDate,
}) async {
  DateTimeRange? selectedRange;
  DateTime start = initialStartDate;
  DateTime end = initialEndDate;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Seleziona intervallo"),
          content: SizedBox(
            height: 300,
            child: dp.RangePicker(
              selectedPeriod: dp.DatePeriod(start, end),
              onChanged: (dp.DatePeriod range) {
                setState(() {
                  start = range.start;
                  end = range.end;
                });
              },
              firstDate: firstDate,
              lastDate: lastDate,
              datePickerStyles: dp.DatePickerRangeStyles(),
              datePickerLayoutSettings: const dp.DatePickerLayoutSettings(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Annulla"),
            ),
            ElevatedButton(
              onPressed: () {
                selectedRange = DateTimeRange(start: start, end: end);
                Navigator.of(context).pop();
              },
              child: const Text("Applica"),
            ),
          ],
        ),
      );
    },
  );
  return selectedRange;
}

String formatCsvDate(DateTime date) {
  return "${date.day.toString().padLeft(2, '0')}/"
         "${date.month.toString().padLeft(2, '0')}/"
         "${date.year}";
}

String formatDayLabel(DateTime date) {
  final weekdays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
  return '${weekdays[date.weekday - 1]}  ${date.day}  ${monthName(date.month)}';
}

String monthName(int month) {
  const months = [
    '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
  ];
  return months[month];
}

DateTime parseCsvDate(String dateStr) {
  final parts = dateStr.split('/');
  return DateTime(
    int.parse(parts[2]),
    int.parse(parts[1]),
    int.parse(parts[0]),
  );
}
