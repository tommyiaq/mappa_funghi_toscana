import 'package:flutter_test/flutter_test.dart';
import 'package:mappa_funghi_toscana/utils/cloud_utils.dart';
import 'package:mappa_funghi_toscana/constants/app_constants.dart';

/// Real rainfall at Monticiano La Pineta (TOS03002742), 08/08 - 30/08/2026,
/// the station where porcini were found on 30/08. Verified offline against
/// the live data:
///   no acceleration      13/08..18/08 = 21.2 mm  -> below the 50 mm bar
///   accelerated 4 days   17/08..22/08 = 60.7 mm  -> found
///   accelerated 6 days   19/08..24/08 = 59.5 mm  -> found
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

/// Column index of a date in the fixture header.
int _col(String date) => _leading.length + _rain.keys.toList().indexOf(date);

/// Column indices for an inclusive range of dates.
List<int> _cols(String from, String to) {
  final keys = _rain.keys.toList();
  return [
    for (int i = keys.indexOf(from); i <= keys.indexOf(to); i++)
      _leading.length + i,
  ];
}

Map<String, dynamic> _args(List<int> days, {int accel = 0}) {
  final rows = _rows();
  final header = rows[0];
  return {
    'rows': rows,
    'header': header,
    'latIndex': header.indexOf('LAT [°]'),
    'lonIndex': header.indexOf('LON [°]'),
    'quotaIndex': header.indexOf('Quota'),
    'nameIndex': header.indexOf('Nome'),
    'indexIndex': header.indexOf('index'),
    'daysByStation': {_station: days},
    'accelByStation': {_station: accel},
  };
}

const _pivot = 18.0;

bool _porcini(int age, double? temp, {int maxAccel = 4}) => rainDayQualifies(
      ageDays: age,
      postRainMeanTemp: temp,
      baseLo: 12,
      baseHi: 17,
      pivot: _pivot,
      maxAccel: maxAccel,
    );

void main() {
  group('rainDayQualifies: only post-rain warmth accelerates', () {
    test('at or below the pivot the base lag applies unchanged', () {
      for (final t in <double?>[null, 12.0, 18.0]) {
        expect(_porcini(11, t), isFalse, reason: 'too recent at $t');
        expect(_porcini(12, t), isTrue);
        expect(_porcini(17, t), isTrue);
        expect(_porcini(18, t), isFalse, reason: 'too old at $t');
      }
    });

    test('four degrees of post-rain warmth brings the flush forward 4 days', () {
      expect(_porcini(8, 22.0), isTrue);
      expect(_porcini(13, 22.0), isTrue);
      expect(_porcini(7, 22.0), isFalse);
      expect(_porcini(14, 22.0), isFalse);
    });

    test('acceleration is capped, so extreme heat does not collapse the lag', () {
      // 30 C would be +12 days uncapped; the cap holds the window at 8..13.
      expect(_porcini(8, 30.0), isTrue);
      expect(_porcini(7, 30.0), isFalse);
      expect(_porcini(2, 30.0), isFalse);
    });

    test('rain on or after the target never qualifies', () {
      for (final age in [0, -1, -5]) {
        expect(_porcini(age, 30.0), isFalse);
      }
    });

    // The production bug of 11/09/2026: a downpour on 09/09 was shown as that
    // day's flush. Under this rule it cannot be, at any temperature -- and in
    // practice a two-day-old rain has almost no post-rain period to average.
    test('REGRESSION: two-day-old rain is never today\'s flush', () {
      for (final t in <double?>[null, 18.0, 25.0, 35.0]) {
        expect(_porcini(2, t), isFalse, reason: 'age 2 qualified at temp $t');
      }
    });

    test('giallarelle use their own, shorter base lag', () {
      bool g(int age, double? t) => rainDayQualifies(
          ageDays: age, postRainMeanTemp: t,
          baseLo: 8, baseHi: 12, pivot: _pivot, maxAccel: 4);
      expect(g(8, null), isTrue);
      expect(g(12, null), isTrue);
      expect(g(7, null), isFalse);
      expect(g(4, 30.0), isTrue);   // capped acceleration
      expect(g(3, 30.0), isFalse);
    });
  });

  group('warmthAcceleration', () {
    test('reports whole days, floored at zero and capped', () {
      int a(double? t) => warmthAcceleration(
          postRainMeanTemp: t, pivot: _pivot, maxAccel: 4);
      expect(a(null), 0);
      expect(a(15.0), 0);
      expect(a(20.4), 2);
      expect(a(40.0), 4);
    });
  });

  group('per-station summation', () {
    test('the Monticiano find is reproduced by the accelerated window', () {
      // 4 days of acceleration -> 17/08..22/08
      final out = computeCloudSpots(_args(_cols('17/08/2026', '22/08/2026'), accel: 4));
      expect(out, hasLength(1));
      expect(out.first['sumValue'], closeTo(60.7, 0.001));
      expect(out.first['shift'], 4);
    });

    test('without acceleration the same station falls below the bar', () {
      final out = computeCloudSpots(_args(_cols('13/08/2026', '18/08/2026')));
      expect(out.first['sumValue'], closeTo(21.2, 0.001));
      expect(out.first['sumValue'], lessThan(50.0));
    });

    test('sums exactly the days given, contiguous or not', () {
      final out = computeCloudSpots(
          _args([_col('20/08/2026'), _col('25/08/2026')]));
      expect(out.first['sumValue'], closeTo(56.5 + 20.9, 0.001));
    });

    test('a station with no qualifying day produces no spot', () {
      final out = computeCloudSpots(_args(const []));
      expect(out, isEmpty);
    });
  });

  group('fixed window (Archivio path unchanged)', () {
    test('sums exactly the columns handed to it', () {
      final rows = _rows();
      final header = rows[0];
      final out = computeCloudSpots({
        'rows': rows,
        'header': header,
        'latIndex': header.indexOf('LAT [°]'),
        'lonIndex': header.indexOf('LON [°]'),
        'quotaIndex': header.indexOf('Quota'),
        'nameIndex': header.indexOf('Nome'),
        'indexIndex': header.indexOf('index'),
        'dateIndices': _cols('20/08/2026', '24/08/2026'),
      });
      expect(out.first['sumValue'], closeTo(59.5, 0.001));
      expect(out.first['shift'], 0);
    });
  });

  group('constants', () {
    test('the acceleration cap keeps porcini at a plausible minimum lag', () {
      final minLag =
          AppConstants.porciniDateOffsetEnd - AppConstants.maxWarmthAccelerationDays;
      expect(minLag, greaterThanOrEqualTo(8),
          reason: 'porcini should not be predicted within a week of the rain');
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
