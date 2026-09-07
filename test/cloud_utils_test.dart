import 'package:flutter_test/flutter_test.dart';
import 'package:mappa_funghi_toscana/utils/cloud_utils.dart';

/// Real rainfall at Monticiano La Pineta (TOS03002742), 08/08 - 30/08/2026,
/// the station where porcini were found on 30/08. Used to pin the sliding
/// window arithmetic against the values verified offline:
///   static  window (shift 0) = 13/08..18/08 = 21.2 mm  -> below the 50 mm bar
///   dynamic window (shift 6) = 19/08..24/08 = 59.5 mm  -> above it
const _rain = <String, double>{
  '08/08/2026': 14.0,
  '09/08/2026': 0.0,
  '10/08/2026': 0.0,
  '11/08/2026': 0.0,
  '12/08/2026': 3.2,
  '13/08/2026': 0.0,
  '14/08/2026': 0.0,
  '15/08/2026': 0.0,
  '16/08/2026': 20.0,
  '17/08/2026': 1.0,
  '18/08/2026': 0.2,
  '19/08/2026': 0.0,
  '20/08/2026': 56.5,
  '21/08/2026': 3.0,
  '22/08/2026': 0.0,
  '23/08/2026': 0.0,
  '24/08/2026': 0.0,
  '25/08/2026': 20.9,
  '26/08/2026': 0.0,
  '27/08/2026': 0.0,
  '28/08/2026': 0.0,
  '29/08/2026': 0.0,
  '30/08/2026': 0.0,
};

const _station = 'TOS03002742';
const _leading = ['index', 'Nome', "Unita' Misura", 'LAT [°]', 'LON [°]', 'GB E [m]', 'GB N [m]', 'Quota'];

List<List<dynamic>> _rows() {
  final header = <dynamic>[..._leading, ..._rain.keys];
  final row = <dynamic>[_station, 'Monticiano La Pineta', 'mm', 43.134, 11.242, 0, 0, 450.0, ..._rain.values];
  return [header, row];
}

Map<String, dynamic> _args({
  required int shift,
  int baseStart = -17,
  int baseEnd = -12,
  String target = '30/08/2026',
}) {
  final rows = _rows();
  final header = rows[0];
  final orderedDateIndices = <int>[];
  final orderedDates = <String>[];
  for (int i = 0; i < header.length; i++) {
    final h = header[i];
    if (h is String && RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(h)) {
      orderedDateIndices.add(i);
      orderedDates.add(h);
    }
  }
  return {
    'rows': rows,
    'header': header,
    'latIndex': header.indexOf('LAT [°]'),
    'lonIndex': header.indexOf('LON [°]'),
    'quotaIndex': header.indexOf('Quota'),
    'nameIndex': header.indexOf('Nome'),
    'indexIndex': header.indexOf('index'),
    'shiftByStation': {_station: shift},
    'orderedDateIndices': orderedDateIndices,
    'targetPos': orderedDates.indexOf(target),
    'baseStart': baseStart,
    'baseEnd': baseEnd,
  };
}

void main() {
  group('sliding rain window', () {
    test('shift 0 reproduces the base window and misses the 20/08 event', () {
      final out = computeCloudSpots(_args(shift: 0));
      expect(out, hasLength(1));
      expect(out.first['sumValue'], closeTo(21.2, 0.001));
      expect(out.first['shift'], 0);
    });

    test('shift 6 slides onto the 20/08 event, as the ground truth requires', () {
      final out = computeCloudSpots(_args(shift: 6));
      expect(out.first['sumValue'], closeTo(59.5, 0.001));
      expect(out.first['shift'], 6);
    });

    test('window moves exactly one day per unit of shift', () {
      // 13/08..18/08 = 21.2; sliding one day drops 13/08 (0.0) and adds
      // 19/08 (0.0), so the total is unchanged; two days adds 20/08.
      expect(computeCloudSpots(_args(shift: 1)).first['sumValue'], closeTo(21.2, 0.001));
      expect(computeCloudSpots(_args(shift: 2)).first['sumValue'], closeTo(77.7, 0.001));
    });

    test('a shift past the end of the data clamps instead of throwing', () {
      final out = computeCloudSpots(_args(shift: 12));
      expect(out, hasLength(1));
      final sum = out.first['sumValue'] as double;
      expect(sum, greaterThanOrEqualTo(0.0));
    });

    test('a target BEYOND the last column still produces a window', () {
      // The day selector offers today plus six days ahead, so targetPos can
      // sit past the end of the data. 30/08 is the last column here, so a
      // target of 30/08 + 3 puts the base window at 16/08..21/08.
      final args = _args(shift: 0);
      args['targetPos'] = (args['targetPos'] as int) + 3;
      final out = computeCloudSpots(args);
      expect(out, hasLength(1), reason: 'forecast days must not be dropped');
      // 16/08..21/08 = 20.0 + 1.0 + 0.2 + 0.0 + 56.5 + 3.0
      expect(out.first['sumValue'], closeTo(80.7, 0.001));
    });

    test('a target so far ahead the window leaves the data clamps, not crashes', () {
      final args = _args(shift: 0);
      args['targetPos'] = (args['targetPos'] as int) + 60;
      final out = computeCloudSpots(args);
      expect(out, hasLength(1));
      expect(out.first['sumValue'], isA<double>());
    });

    test('giallarelle base offsets use their own window', () {
      // -12..-8 from 30/08 = 18/08..22/08 = 0.2 + 0 + 56.5 + 3 + 0
      final out = computeCloudSpots(_args(shift: 0, baseStart: -12, baseEnd: -8));
      expect(out.first['sumValue'], closeTo(59.7, 0.001));
    });
  });

  group('fixed window (Archivio path unchanged)', () {
    test('sums exactly the columns handed to it', () {
      final rows = _rows();
      final header = rows[0];
      final from = header.indexOf('20/08/2026');
      final to = header.indexOf('24/08/2026');
      final out = computeCloudSpots({
        'rows': rows,
        'header': header,
        'latIndex': header.indexOf('LAT [°]'),
        'lonIndex': header.indexOf('LON [°]'),
        'quotaIndex': header.indexOf('Quota'),
        'nameIndex': header.indexOf('Nome'),
        'indexIndex': header.indexOf('index'),
        'dateIndices': [for (int i = from; i <= to; i++) i],
      });
      // 20-24 August, the period from the Archivio example
      expect(out.first['sumValue'], closeTo(59.5, 0.001));
      expect(out.first['shift'], 0);
    });
  });

  group('opacity', () {
    test('below 10 mm is invisible, above 100 mm is capped', () {
      expect(computeOpacity(0), 0.0);
      expect(computeOpacity(10), 0.0);
      expect(computeOpacity(100), 0.5);
      expect(computeOpacity(250), 0.5);
      expect(computeOpacity(55), closeTo(0.25, 0.001));
    });
  });
}
