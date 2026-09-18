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

  // Heat shortens the lag between the rain and the flush. At or below
  // tempPivotCelsius the base offsets apply unchanged; every degree of the
  // post-rain mean above it brings the flush one day forward. Evaluated per
  // station, because that mean spans ~11 C across the network (coast to
  // Apennines), and per rain day -- see maxWarmthAccelerationDays.
  // 20, not 18: the post-rain mean across the network runs p25 19.5 /
  // median 21.2 in September, so a pivot of 18 made nearly every station
  // "hot" -- 31% saturated the cap and the median acceleration was 3.2 days,
  // which turned a dynamic window into a near-constant -3/-4. At 20 the
  // median drops to 1.2 days and only 2% reach the cap.
  //
  // Bounded by two field observations: Monticiano La Pineta (porcini found
  // 30/08/2026 from rain 10 days earlier) needs at least 2 days of
  // acceleration, and Barberino on 18/09/2026 must NOT show porcini from
  // rain 9 days earlier, which needs under 3. At 20 they come out 3.8 and
  // 1.5 -- comfortably either side.
  static const double tempPivotCelsius = 20.0;

  // Warmth shortens the lag between rain and flush -- but only warmth that
  // fell AFTER the rain and before the target date can do so. The temperature
  // of days before the rain landed is irrelevant: it cannot accelerate a flush
  // from rain that had not yet fallen. So the acceleration is computed per
  // candidate rain day, over the days between that rain and the target.
  //
  // This also makes the model self-limiting. Rain two days ago has almost no
  // post-rain period, so its acceleration is ~0 and its lag stays at the full
  // 12-17 days, which means it cannot masquerade as today's flush. The earlier
  // per-station shift had no such property: it was driven by the last 12 days
  // regardless of when the rain fell, so the 09/09/2026 downpour showed up as
  // fruiting on 11/09 -- two days later.
  //
  // The cap: no amount of heat makes porcini appear a few days after rain.
  // 4 days keeps porcini at 8-13 instead of the base 12-17, and still
  // reproduces the Monticiano La Pineta find of 30/08/2026 (60.7 mm).
  static const int maxWarmthAccelerationDays = 4;

  // Fruiting temperature range per species, tested against the mean of the
  // daily mean temperatures over the fruttificazione window (days -9..-2).
  //
  // Giallarelle (Cantharellus cibarius var. pallens) upper bound lowered from
  // 22 to 20 in Sept 2026. The literature puts ideal fruiting around 10-21 C
  // of ambient air, and reports that hot dry summers suppress fruiting while
  // cool moist ones produce abundant flushes. 21 is an AMBIENT figure, while
  // this range is tested against the mean of daily MEAN temperatures, which
  // sits several degrees below the daytime maximum -- a daily mean of 21 C in
  // Tuscany implies highs near 28 C. So 20 on this metric is still lenient
  // against the sources.
  //
  // Note the 22.5 C often quoted for C. cibarius is the lab optimum for
  // MYCELIAL growth, not for fruiting, and fruiting wants it cooler than the
  // mycelium does -- it is not an upper bound for this filter.
  //
  // The 2 C floor is deliberately generous: chanterelles fruit well into cold
  // Tuscan autumns, and on a daily-mean metric a higher floor would erase the
  // late season.
  static const Map<String, List<double>> mushroomTempRanges = {
    'Porcini': [6.0, 26.0],
    'Giallarelle': [2.0, 20.0],
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
