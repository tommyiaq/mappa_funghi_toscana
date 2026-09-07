import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_constants.dart';
import '../models/cloud_spot.dart';
import '../services/csv_service.dart';
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
  DateTime? minCsvDate;
  DateTime? maxCsvDate;

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

  /// True while a load is in flight. Without this the "no spots" message would
  /// flash on every reload, because the marker map is empty until the fetch
  /// and filtering finish.
  bool _isLoading = true;

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
    if (mounted) setState(() => _isLoading = true);
    try {
      if (widget.isArchivio) {
        await _loadArchivioData();
      } else {
        await _loadHomeData();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Home only. An empty map there is a real prediction -- nowhere in Tuscany
  /// currently satisfies the rain and temperature windows -- so it is worth
  /// saying out loud instead of leaving the user on a bare map. Archivio stays
  /// silent: an empty result there just means the range the user chose had
  /// little rain, which is an answer in itself.
  bool get _showNoSpotsMessage {
    if (widget.isArchivio || _isLoading) return false;
    // Unchecking every mushroom is not a prediction of absence.
    if (!selectedMushrooms.contains(true)) return false;
    return mushroomMarkers.values.every((markers) => markers.isEmpty);
  }

  Future<void> _loadArchivioData() async {
    if (startDate == null || endDate == null) return;
    
    final cloudSpots = await CsvService.loadCloudSpots(
      startDate!, 
      endDate!, 
      'Porcini',
      isArchivio: true,
    );
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

      // The rain window is now per station (heat slides it later), so there is
      // no single range to validate up front. The target day itself need not be
      // in the data either -- the selector offers six days ahead -- so the
      // service locates it by date arithmetic and clamps the window.
      final spots = await CsvService.loadCloudSpotsForDate(selectedDate, type);

      newSpots[type] = spots;
      if (mounted) {
        newMarkers[type] = buildMarkers(
          spots: spots,
          mushroomType: type,
          isArchivio: widget.isArchivio,
          context: context,
          applyTemperatureFilter: true,
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
    if (minCsvDate == null || maxCsvDate == null) {
      return const Padding(
        padding: AppConstants.defaultPadding,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Padding(
      padding: AppConstants.defaultPadding,
      child: DateRangeSelector(
        startDate: startDate,
        endDate: endDate,
        minCsvDate: minCsvDate!,
        maxCsvDate: maxCsvDate!,
        availableDates: availableDates,
        onDateRangeChanged: _onDateRangeChanged,
      ),
    );
  }

  Widget _buildMap() {
    return Expanded(
      child: Stack(
        children: [
          _buildFlutterMap(),
          if (_showNoSpotsMessage) _buildNoSpotsMessage(),
        ],
      ),
    );
  }

  Widget _buildNoSpotsMessage() {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: AppConstants.defaultPadding,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            'Il modello non predice presenza di funghi in Toscana',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildFlutterMap() {
    return FlutterMap(
      options: const MapOptions(
        initialCenter:
            LatLng(AppConstants.defaultMapLatitude, AppConstants.defaultMapLongitude),
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
