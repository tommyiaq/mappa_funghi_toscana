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
  
  // Date calculation constants
  static const int porciniDateOffsetStart = 17;
  static const int porciniDateOffsetEnd = 12;
  static const int giallarelleeDateOffsetStart = 12;
  static const int giallarelleeDateOffsetEnd = 8;
  
  // UI constants
  static const Duration debounceDelay = Duration(milliseconds: 350);
  static const EdgeInsets defaultPadding = EdgeInsets.all(8.0);
  static const EdgeInsets controlPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  static const double iconSize = 18.0;
  static const double spacingSmall = 4.0;
  static const double spacingMedium = 8.0;
  static const double spacingLarge = 12.0;
}
