// Utility functions for cloud spot computation
import 'package:latlong2/latlong.dart';

/// Computes cloud spots from CSV data for use with compute().
List<Map<String, dynamic>> computeCloudSpots(Map<String, dynamic> args) {
  final List<List<dynamic>> rows = args['rows'];
  final int latIndex = args['latIndex'];
  final int lonIndex = args['lonIndex'];
  final int quotaIndex = args['quotaIndex'];
  final int nameIndex = args['nameIndex'];
  final int indexIndex = args['indexIndex'];
  final List<int> dateIndices = args['dateIndices'];
  // final String mushroomType = args['mushroomType']; // not used

  List<Map<String, dynamic>> result = [];
  final minRequiredIndex = [latIndex, lonIndex, quotaIndex, nameIndex, indexIndex, ...dateIndices].fold(0, (a, b) => a > b ? a : b);
  for (final row in rows.skip(1)) {
    if (row.length <= minRequiredIndex) {
      continue;
    }
    if (row[latIndex] is! num) {
      // Skip rows where lat is not a number (e.g., header or malformed row)
      continue;
    }
    final double lat = row[latIndex] as double;
    final double lon = row[lonIndex] as double;
    final String name = row[nameIndex].toString();
    final double quota = (row[quotaIndex] as num?)?.toDouble() ?? 0.0;
    final String? index = indexIndex >= 0 ? row[indexIndex]?.toString() : null;
    final sumValue = dateIndices.fold<double>(
        0, (sum, i) => sum + ((row[i] as num?)?.toDouble() ?? 0.0));
    result.add({
      'lat': lat,
      'lon': lon,
      'name': name,
      'quota': quota,
      'sumValue': sumValue,
      'index': index, // Add index
    });
  }
  return result;
}

/// Computes the opacity for a cloud spot based on its value.
double computeOpacity(double value) {
  if (value >= 100) return 0.5;
  if (value <= 10) return 0.0;
  return ((value - 10) / 90 * 0.5).clamp(0.0, 0.5);
}
