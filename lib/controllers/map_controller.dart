import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/cloud_spot.dart';
import '../services/csv_service.dart';
import '../utils/date_utils.dart';

class MapController extends ChangeNotifier {
  // Data state
  List<String> _availableDates = [];
  String? _startDate;
  String? _endDate;
  DateTime? _minCsvDate;
  DateTime? _maxCsvDate;
  
  // Selection state
  List<bool> _selectedMushrooms = [true, true];
  int _selectedDayIndex = 0;
  
  // Map data
  Map<String, List<CloudSpot>> _mushroomSpots = {};
  bool _isLoading = false;
  
  // Getters
  List<String> get availableDates => _availableDates;
  String? get startDate => _startDate;
  String? get endDate => _endDate;
  DateTime? get minCsvDate => _minCsvDate;
  DateTime? get maxCsvDate => _maxCsvDate;
  List<bool> get selectedMushrooms => _selectedMushrooms;
  int get selectedDayIndex => _selectedDayIndex;
  Map<String, List<CloudSpot>> get mushroomSpots => _mushroomSpots;
  bool get isLoading => _isLoading;
  
  // Initialize data
  Future<void> initialize() async {
    _setLoading(true);
    try {
      final dateInfo = await CsvService.getAvailableDatesAndRange();
      _availableDates = dateInfo.availableDates;
      _minCsvDate = dateInfo.minDate;
      _maxCsvDate = dateInfo.maxDate;
      _startDate = dateInfo.availableDates.first;
      _endDate = dateInfo.availableDates.first;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }
  
  // Update mushroom selection
  void updateMushroomSelection(List<bool> newSelection) {
    _selectedMushrooms = List.from(newSelection);
    notifyListeners();
  }
  
  // Update day selection
  void updateDaySelection(int dayIndex) {
    _selectedDayIndex = dayIndex;
    notifyListeners();
  }
  
  // Update date range
  void updateDateRange(String start, String end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }
  
  // Load cloud data based on current selections
  Future<void> loadCloudData({required bool isArchivio}) async {
    if (_isLoading) return;
    
    _setLoading(true);
    try {
      if (isArchivio) {
        await _loadArchivioData();
      } else {
        await _loadHomeData();
      }
    } finally {
      _setLoading(false);
    }
  }
  
  Future<void> _loadArchivioData() async {
    if (_startDate == null || _endDate == null) return;
    
    final cloudSpots = await CsvService.loadCloudSpots(_startDate!, _endDate!, 'Porcini');
    _mushroomSpots = {'Porcini': cloudSpots};
    notifyListeners();
  }
  
  Future<void> _loadHomeData() async {
    final now = DateTime.now();
    final selectedDate = now.add(Duration(days: _selectedDayIndex));
    final Map<String, List<CloudSpot>> newSpots = {};
    
    for (int i = 0; i < AppConstants.mushroomTypes.length; i++) {
      if (!_selectedMushrooms[i]) continue;
      
      final type = AppConstants.mushroomTypes[i];
      final dateRange = _calculateDateRange(type, selectedDate);
      
      if (!_isValidDateRange(dateRange.start, dateRange.end)) continue;
      
      final spots = await CsvService.loadCloudSpots(
        dateRange.start,
        dateRange.end,
        type,
      );
      
      newSpots[type] = spots;
    }
    
    _mushroomSpots = newSpots;
    notifyListeners();
  }
  
  DateRange _calculateDateRange(String mushroomType, DateTime selectedDate) {
    if (mushroomType == 'Porcini') {
      return DateRange(
        start: formatCsvDate(selectedDate.subtract(Duration(days: AppConstants.porciniDateOffsetStart))),
        end: formatCsvDate(selectedDate.subtract(Duration(days: AppConstants.porciniDateOffsetEnd))),
      );
    } else {
      return DateRange(
        start: formatCsvDate(selectedDate.subtract(Duration(days: AppConstants.giallarelleeDateOffsetStart))),
        end: formatCsvDate(selectedDate.subtract(Duration(days: AppConstants.giallarelleeDateOffsetEnd))),
      );
    }
  }
  
  bool _isValidDateRange(String start, String end) {
    return _availableDates.contains(start) && _availableDates.contains(end);
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

class DateRange {
  final String start;
  final String end;
  
  DateRange({required this.start, required this.end});
}
