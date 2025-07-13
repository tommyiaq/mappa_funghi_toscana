import 'package:latlong2/latlong.dart';

class CloudSpot {
  final LatLng position;
  final double opacity;
  final String info;
  final double cumulatedValue;
  final String? index;
  final double? avgTemperature; // Average temperature for the selected date range

  CloudSpot(
    this.position, 
    this.opacity, 
    this.info, 
    this.cumulatedValue, {
    this.index,
    this.avgTemperature,
  });
}
