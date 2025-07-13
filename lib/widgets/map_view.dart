import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_constants.dart';
import '../models/cloud_spot.dart';
import '../services/csv_service.dart';
import '../utils/date_utils.dart';
import '../utils/marker_utils.dart';
import '../widgets/mushroom_selector.dart';
import '../widgets/day_selector.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/gradient_cloud_image.dart';

class MapView extends StatefulWidget {
  final bool isArchivio;
  
  const MapView({
    super.key,
    this.isArchivio = false,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  // Data state
  List<String> availableDates = [];
  String? startDate;
  String? endDate;
  late DateTime minCsvDate;
  late DateTime maxCsvDate;

  // Mushroom selection state
  final List<String> mushroomTypes = AppConstants.mushroomTypes;
  List<bool> selectedMushrooms = [true, true];

  // Day selection state for Home
  int selectedDayIndex = 0;

  // Map data
  Map<String, List<CloudSpot>> mushroomSpots = {};
  Map<String, List<Marker>> mushroomMarkers = {};

  // Debounce timer
  Timer? _debounceDayPicker;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _debounceDayPicker?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    final dateInfo = await CsvService.getAvailableDatesAndRange();
    setState(() {
      availableDates = dateInfo.availableDates;
      minCsvDate = dateInfo.minDate;
      maxCsvDate = dateInfo.maxDate;
      startDate = dateInfo.availableDates.first;
      endDate = dateInfo.availableDates.first;
    });
    await _loadAndSetClouds();
  }

  Future<void> _loadAndSetClouds() async {
    if (widget.isArchivio) {
      await _loadArchivioData();
    } else {
      await _loadHomeData();
    }
  }

  Future<void> _loadArchivioData() async {
    if (startDate == null || endDate == null) return;
    
    final cloudSpots = await CsvService.loadCloudSpots(startDate!, endDate!, 'Porcini');
    setState(() {
      mushroomSpots['Porcini'] = cloudSpots;
      mushroomMarkers['Porcini'] = buildMarkers(
        spots: cloudSpots,
        mushroomType: 'Porcini',
        isArchivio: widget.isArchivio,
        context: context,
      );
    });
  }

  Future<void> _loadHomeData() async {
    final now = DateTime.now();
    final selectedDate = now.add(Duration(days: selectedDayIndex));
    Map<String, List<CloudSpot>> newSpots = {};
    Map<String, List<Marker>> newMarkers = {};

    for (int i = 0; i < mushroomTypes.length; i++) {
      if (!selectedMushrooms[i]) continue;
      
      final type = mushroomTypes[i];
      final dateRange = _calculateDateRange(type, selectedDate);
      
      if (!_isValidDateRange(dateRange.start, dateRange.end)) continue;
      
      final spots = await CsvService.loadCloudSpots(
        dateRange.start,
        dateRange.end,
        type,
      );
      
      newSpots[type] = spots;
      if (mounted) {
        newMarkers[type] = buildMarkers(
          spots: spots,
          mushroomType: type,
          isArchivio: widget.isArchivio,
          context: context,
        );
      }
    }

    if (mounted) {
      setState(() {
        mushroomSpots = newSpots;
        mushroomMarkers = newMarkers;
      });
    }
  }

  DateRange _calculateDateRange(String mushroomType, DateTime selectedDate) {
    if (mushroomType == 'Porcini') {
      return DateRange(
        start: formatCsvDate(selectedDate.subtract(Duration(days: AppConstants.porciniDateOffsetStart))),
        end: formatCsvDate(selectedDate.subtract(Duration(days: AppConstants.porciniDateOffsetEnd))),
      );
    } else {
      // Giallarelle
      return DateRange(
        start: formatCsvDate(selectedDate.subtract(Duration(days: AppConstants.giallarelleeDateOffsetStart))),
        end: formatCsvDate(selectedDate.subtract(Duration(days: AppConstants.giallarelleeDateOffsetEnd))),
      );
    }
  }

  bool _isValidDateRange(String start, String end) {
    return availableDates.contains(start) && availableDates.contains(end);
  }

  void _onMushroomSelectionChanged(List<bool> newSelection) {
    setState(() {
      selectedMushrooms.setAll(0, newSelection);
    });
    _loadAndSetClouds();
  }

  void _onDayChanged(int dayIndex) {
    setState(() {
      selectedDayIndex = dayIndex;
    });
    
    _debounceDayPicker?.cancel();
    _debounceDayPicker = Timer(AppConstants.debounceDelay, () {
      _loadAndSetClouds();
    });
  }

  void _onDateRangeChanged(String newStartDate, String newEndDate) {
    setState(() {
      startDate = newStartDate;
      endDate = newEndDate;
    });
    _loadAndSetClouds();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            _buildControls(),
            _buildMap(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (!widget.isArchivio) {
      return _buildHomeControls();
    } else {
      return _buildArchivioControls();
    }
  }

  Widget _buildHomeControls() {
    return Padding(
      padding: AppConstants.defaultPadding,
      child: Row(
        children: [
          Expanded(
            child: MushroomSelector(
              mushroomTypes: mushroomTypes,
              selectedMushrooms: selectedMushrooms,
              onSelectionChanged: _onMushroomSelectionChanged,
            ),
          ),
          const SizedBox(width: AppConstants.spacingLarge),
          Expanded(
            child: DaySelector(
              selectedDayIndex: selectedDayIndex,
              onDayChanged: _onDayChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivioControls() {
    return Padding(
      padding: AppConstants.defaultPadding,
      child: DateRangeSelector(
        startDate: startDate,
        endDate: endDate,
        minCsvDate: minCsvDate,
        maxCsvDate: maxCsvDate,
        availableDates: availableDates,
        onDateRangeChanged: _onDateRangeChanged,
      ),
    );
  }

  Widget _buildMap() {
    return Expanded(
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(AppConstants.defaultMapLatitude, AppConstants.defaultMapLongitude),
          initialZoom: AppConstants.defaultMapZoom,
        ),
        children: [
          TileLayer(
            urlTemplate: AppConstants.mapTileUrlTemplate,
            userAgentPackageName: AppConstants.userAgentPackageName,
          ),
          _buildOverlayLayer(),
          _buildMarkerLayer(),
        ],
      ),
    );
  }

  Widget _buildOverlayLayer() {
    return OverlayImageLayer(
      overlayImages: [
        for (final entry in mushroomSpots.entries)
          for (final spot in entry.value)
            OverlayImage(
              bounds: LatLngBounds(
                LatLng(
                  spot.position.latitude - AppConstants.cloudOverlayOffset,
                  spot.position.longitude - AppConstants.cloudOverlayOffset,
                ),
                LatLng(
                  spot.position.latitude + AppConstants.cloudOverlayOffset,
                  spot.position.longitude + AppConstants.cloudOverlayOffset,
                ),
              ),
              opacity: 1.0,
              imageProvider: GradientCloudImage(
                opacity: spot.opacity,
                color: AppConstants.mushroomColors[entry.key] ?? Colors.grey,
              ),
            ),
      ],
    );
  }

  Widget _buildMarkerLayer() {
    return MarkerLayer(
      markers: mushroomMarkers.values.expand((markers) => markers).toList(),
    );
  }
}

class DateRange {
  final String start;
  final String end;
  
  DateRange({required this.start, required this.end});
}
