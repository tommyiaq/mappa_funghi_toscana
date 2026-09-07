import 'package:latlong2/latlong.dart';

class CloudSpot {
  final LatLng position;
  final double opacity;
  final String info;
  final double cumulatedValue;
  final String? index;
  final double? avgTemperature; // Average temperature for the selected date range

  /// True when this station has no thermometer and its temperature was
  /// interpolated from neighbours. Such stations are judged against a wider
  /// temperature band, see AppConstants.estimatedTempMargin.
  final bool isEstimatedTemperature;

  /// Days the rain window was slid later because of recent heat. 0 in cool
  /// weather and in Archivio, where the window is the range the user picked.
  final int windowShiftDays;

  CloudSpot(
    this.position,
    this.opacity,
    this.info,
    this.cumulatedValue, {
    this.index,
    this.avgTemperature,
    this.isEstimatedTemperature = false,
    this.windowShiftDays = 0,
  });
}
