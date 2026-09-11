// Utility functions for cloud spot computation

/// Computes cloud spots from CSV data for use with compute().
///
/// Two modes:
///  * fixed window   - args['dateIndices'] holds the columns to sum. Used by
///                     Archivio, where the window is the range the user picked.
///  * per-station    - args['daysByStation'] maps each station to the rain
///                     columns that qualify for it. Used by Home, where every
///                     rain day is judged by how warm it has been SINCE that
///                     rain, so the qualifying days differ station by station.
///                     Built by CsvService.computeQualifyingDays.
List<Map<String, dynamic>> computeCloudSpots(Map<String, dynamic> args) {
  final List<List<dynamic>> rows = args['rows'];
  final int latIndex = args['latIndex'];
  final int lonIndex = args['lonIndex'];
  final int quotaIndex = args['quotaIndex'];
  final int nameIndex = args['nameIndex'];
  final int indexIndex = args['indexIndex'];

  final Map<String, List<int>>? daysByStation =
      (args['daysByStation'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), (v as List).cast<int>()));
  // Days of acceleration actually applied, kept only for display.
  final Map<String, int> accelByStation =
      ((args['accelByStation'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), v as int));

  final List<int> fixedDateIndices =
      (args['dateIndices'] as List?)?.cast<int>() ?? const [];

  final bool perStation = daysByStation != null;

  /// Column indices to sum for one station.
  List<int> windowFor(String? station) {
    if (!perStation) return fixedDateIndices;
    return daysByStation[station] ?? const [];
  }

  final int fixedMax = [
    latIndex,
    lonIndex,
    quotaIndex,
    nameIndex,
    indexIndex,
    ...fixedDateIndices,
    if (daysByStation != null)
      for (final days in daysByStation.values) ...days,
  ].fold(0, (a, b) => a > b ? a : b);

  final List<Map<String, dynamic>> result = [];
  for (final row in rows.skip(1)) {
    if (row.length <= fixedMax) {
      continue;
    }
    if (row[latIndex] is! num) {
      // Skip rows where lat is not a number (e.g., header or malformed row)
      continue;
    }
    final String? index = indexIndex >= 0 ? row[indexIndex]?.toString() : null;

    final dateIndices = windowFor(index);
    if (dateIndices.isEmpty) continue;

    final double lat = (row[latIndex] as num).toDouble();
    final double lon = (row[lonIndex] as num).toDouble();
    final String name = row[nameIndex].toString();
    final double quota = (row[quotaIndex] as num?)?.toDouble() ?? 0.0;
    final sumValue = dateIndices.fold<double>(
        0, (sum, i) => sum + ((row[i] as num?)?.toDouble() ?? 0.0));

    result.add({
      'lat': lat,
      'lon': lon,
      'name': name,
      'quota': quota,
      'sumValue': sumValue,
      'index': index,
      'shift': perStation ? (accelByStation[index] ?? 0) : 0,
    });
  }
  return result;
}

/// Whether rain that fell [ageDays] before the target can have fruited by it.
///
/// [postRainMeanTemp] is the mean daily temperature over the days BETWEEN that
/// rain and the target -- the only stretch that can accelerate this particular
/// flush. Null (or no data) means no acceleration, which is the conservative
/// answer: the rain keeps its full base lag.
///
/// [baseLo]/[baseHi] are the base lag bounds in days, both positive
/// (porcini 12..17, giallarelle 8..12).
bool rainDayQualifies({
  required int ageDays,
  required double? postRainMeanTemp,
  required int baseLo,
  required int baseHi,
  required double pivot,
  required int maxAccel,
}) {
  // Rain on or after the target cannot have produced anything by it.
  if (ageDays < 1) return false;
  final double accel = postRainMeanTemp == null
      ? 0.0
      : (postRainMeanTemp - pivot).clamp(0.0, maxAccel.toDouble());
  return ageDays >= baseLo - accel && ageDays <= baseHi - accel;
}

/// Days of acceleration applied, for display alongside a spot.
int warmthAcceleration({
  required double? postRainMeanTemp,
  required double pivot,
  required int maxAccel,
}) {
  if (postRainMeanTemp == null) return 0;
  return (postRainMeanTemp - pivot).clamp(0.0, maxAccel.toDouble()).round();
}

/// Computes the opacity for a cloud spot based on its value.
double computeOpacity(double value) {
  if (value >= 100) return 0.5;
  if (value <= 10) return 0.0;
  return ((value - 10) / 90 * 0.5).clamp(0.0, 0.5);
}
