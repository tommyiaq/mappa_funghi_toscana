import 'package:flutter/material.dart';

class AppConstants {
  // App configuration
  static const String appTitle = 'Mappa Funghi Toscana';
  static const String userAgentPackageName = 'com.example.mappa_funghi';
  
  // Map configuration
  static const double defaultMapLatitude = 43.47;
  static const double defaultMapLongitude = 11.14;
  static const double defaultMapZoom = 8.0;
  static const String mapTileUrlTemplate = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  
  // Mushroom types
  static const List<String> mushroomTypes = ['Porcini', 'Giallarelle'];
  
  // Colors for different mushroom types
  static const Map<String, Color> mushroomColors = {
    'Porcini': Colors.red,
    'Giallarelle': Colors.blue,
  };
  
  // Cloud overlay configuration
  static const double cloudOverlayOffset = 0.2;
  
  // Date calculation constants.
  // These are the BASE rain window, valid in cool weather. See the shift below.
  static const int porciniDateOffsetStart = 17;
  static const int porciniDateOffsetEnd = 12;
  static const int giallarelleeDateOffsetStart = 12;
  static const int giallarelleeDateOffsetEnd = 8;

  // Heat shortens the lag between the rain and the flush, so the window slides.
  // At or below tempPivotCelsius the base offsets apply unchanged; every degree
  // of the station's recent mean above it moves the window one day later, i.e.
  // closer to the target date. Computed per station, because the reference
  // temperature spans ~11 C across the network (coast to Apennines).
  static const double tempPivotCelsius = 18.0;
  static const int refTempDays = 12;
  static const int maxWindowShiftDays = 12;

  // Fruiting temperature range per species, tested against the mean of the
  // daily mean temperatures over the fruttificazione window (days -9..-2).
  static const Map<String, List<double>> mushroomTempRanges = {
    'Porcini': [6.0, 26.0],
    'Giallarelle': [2.0, 22.0],
  };

  // Stations without a thermometer get an interpolated temperature, which
  // carries about a degree of error (RMSE 1.0 C, p95 2.0 C), so they are
  // judged against a correspondingly wider band.
  static const double estimatedTempMargin = 2.0;
  
  // UI constants
  static const Duration debounceDelay = Duration(milliseconds: 350);
  static const EdgeInsets defaultPadding = EdgeInsets.all(8.0);
  static const EdgeInsets controlPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  static const double iconSize = 18.0;
  static const double spacingSmall = 4.0;
  static const double spacingMedium = 8.0;
  static const double spacingLarge = 12.0;
}
