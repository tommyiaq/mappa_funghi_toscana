import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:csv/csv.dart';
import 'package:flutter_date_pickers/flutter_date_pickers.dart' as dp;
import 'dart:async';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    MapView(key: PageStorageKey('HomeMapView')),
    MapView(key: PageStorageKey('ArchivioMapView'), isArchivio: true),
  ];
  final PageStorageBucket _bucket = PageStorageBucket();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageStorage(
        bucket: _bucket,
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.archive),
            label: 'Archivio',
          ),
        ],
      ),
    );
  }
}

class CloudSpot {
  final LatLng position;
  final double opacity;
  final String info;
  final double cumulatedValue; // Add this field
  final String? index; // Add index field
  CloudSpot(this.position, this.opacity, this.info, this.cumulatedValue, {this.index});
}

class MapView extends StatefulWidget {
  final bool isArchivio;
  const MapView({super.key, this.isArchivio = false});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  List<CloudSpot> spots = [];
  List<Marker> infoMarkers = [];
  List<String> availableDates = [];
  Set<DateTime> selectableDates = {};
  String? startDate;
  String? endDate;
  late DateTime minCsvDate;
  late DateTime maxCsvDate;

  // Mushroom selection state
  final List<String> mushroomTypes = ['Porcini', 'Giallarelle'];
  List<bool> selectedMushrooms = [true, true];

  // Day selection state
  int selectedDayIndex = 0;
  List<String> dayLabels = [];

  // Store overlays and markers for each mushroom type
  Map<String, List<CloudSpot>> mushroomSpots = {};
  Map<String, List<Marker>> mushroomMarkers = {};

  String _formatCsvDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/"
           "${date.month.toString().padLeft(2, '0')}/"
           "${date.year}";
  }

  String _formatDayLabel(DateTime date) {
  final weekdays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
  return '${weekdays[date.weekday - 1]} ${date.day} ${_monthName(date.month)}';
}

  String _monthName(int month) {
    const months = [
      '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ];
    return months[month];
  }

  DateTime _parseCsvDate(String dateStr) {
    final parts = dateStr.split('/');
    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }

  @override
  void initState() {
    super.initState();
    loadAvailableDates().then((dates) {
      setState(() {
        availableDates = dates;
        startDate = dates.first;
        endDate = dates.first;
        // Prepare day labels for Home picker
        if (!widget.isArchivio) {
          final now = DateTime.now();
          dayLabels = List.generate(7, (i) {
            if (i == 0) return 'Oggi';
            if (i == 1) return 'Domani';
            return _formatDayLabel(now.add(Duration(days: i)));
          });
        }
      });
      loadAndSetClouds();
    });
  }

  Future<void> loadAndSetClouds() async {
    if (widget.isArchivio) {
      // Archivio: use selected date range
      if (startDate == null || endDate == null) return;
      final cloudSpots = await loadCloudSpots(startDate!, endDate!, 'Porcini');
      setState(() {
        mushroomSpots['Porcini'] = cloudSpots;
        // Only Porcini logic for Archivio for now
        mushroomMarkers['Porcini'] = buildMarkers(cloudSpots, 'Porcini');
      });
      return;
    }
    // Home: for each selected mushroom, compute correct window and load
    final now = DateTime.now();
    final selectedDate = now.add(Duration(days: selectedDayIndex));
    Map<String, List<CloudSpot>> newSpots = {};
    Map<String, List<Marker>> newMarkers = {};
    for (int i = 0; i < mushroomTypes.length; i++) {
      if (!selectedMushrooms[i]) continue;
      final type = mushroomTypes[i];
      DateTime from, to;
      if (type == 'Porcini') {
        from = selectedDate.subtract(const Duration(days: 17));
        to = selectedDate.subtract(const Duration(days: 12));
      } else {
        // Giallarelle
        from = selectedDate.subtract(const Duration(days: 12));
        to = selectedDate.subtract(const Duration(days: 8));
      }
      // Clamp to availableDates
      final fromStr = _formatCsvDate(from);
      final toStr = _formatCsvDate(to);
      if (!availableDates.contains(fromStr) || !availableDates.contains(toStr)) continue;
      final spots = await loadCloudSpots(fromStr, toStr, type);
      newSpots[type] = spots;
      newMarkers[type] = buildMarkers(spots, type);
    }
    setState(() {
      mushroomSpots = newSpots;
      mushroomMarkers = newMarkers;
    });
  }

  // Overload loadCloudSpots to take mushroom type and use correct overlay color/icon
  Future<List<CloudSpot>> loadCloudSpots(String start, String end, String mushroomType) async {
    await _ensureCsvLoaded();
    final rows = _csvRowsCache!;
    final header = _csvHeaderCache!;
    final latIndex = header.indexOf("LAT [°]");
    final lonIndex = header.indexOf("LON [°]");
    final quotaIndex = header.indexOf("Quota");
    final nameIndex = header.indexOf("Nome");
    final indexIndex = header.indexOf("index"); // Add index column
    final startIdx = header.indexOf(start);
    final endIdx = header.indexOf(end);
    final dateIndices = startIdx == endIdx
        ? [startIdx]
        : List.generate(endIdx - startIdx + 1, (i) => startIdx + i);

    // Use compute to run in background isolate
    final List<Map<String, dynamic>> rawSpots = await compute(computeCloudSpots, {
      'rows': rows,
      'header': header,
      'latIndex': latIndex,
      'lonIndex': lonIndex,
      'quotaIndex': quotaIndex,
      'nameIndex': nameIndex,
      'indexIndex': indexIndex, // Pass index column
      'dateIndices': dateIndices,
      'mushroomType': mushroomType,
    });

    // Map to CloudSpot and compute opacity on main thread
    return rawSpots.map((data) {
      final double opacity = computeOpacity(data['sumValue']);
      return CloudSpot(
        LatLng(data['lat'], data['lon']),
        opacity,
        '${data['name']}\nQuota: ${data['quota'].toStringAsFixed(1)} m\nCumulato: ${data['sumValue'].toStringAsFixed(1)} mm',
        data['sumValue'],
        index: data['index'], // Pass index
      );
    }).toList();
  } 

  List<Marker> buildMarkers(List<CloudSpot> spots, String mushroomType) {
    // Use default marker icon in Archivio, custom icon in Home
    final bool isArchivio = widget.isArchivio;
    final iconAsset = isArchivio
        ? null
        : (mushroomType == 'Porcini' ? 'assets/porcino.png' : 'assets/giallarella.png');
    final threshold = mushroomType == 'Porcini' ? 50.0 : 30.0;
    return spots.where((spot) => spot.opacity > 0.0 && spot.cumulatedValue > threshold).map((spot) =>
      Marker(
        point: spot.position,
        width: isArchivio ? 15 : (mushroomType == 'Porcini' ? 25 : 25),
        height: isArchivio ? 15 : (mushroomType == 'Porcini' ? 25 : 25),
        child: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(spot.info.split('\n').first),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spot.info.replaceFirst(RegExp(r'^.*\n'), '')),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${spot.position.latitude},${spot.position.longitude}');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: const Text(
                        'Apri in Maps',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    if (spot.index != null && spot.index!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => RainfallWebView(
                                url: 'https://www.sir.toscana.it/monitoraggio/dettaglio.php?id=${spot.index}&title=&type=pluvio_men',
                                stationId: spot.index,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Cumulato 30 g',
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
          child: iconAsset == null
              ? const Icon(Icons.location_on, color: Colors.red, size: 30)
              : Image.asset(iconAsset),
        ),
      )
    ).toList();
  }

  double computeOpacity(double value) {
    if (value >= 100) return 0.5;
    if (value <= 10) return 0.0;
    return ((value - 10) / 90 * 0.5).clamp(0.0, 0.5);
  }

  Future<DateTimeRange?> showCustomDateRangePicker({
    required BuildContext context,
    required DateTime firstDate,
    required DateTime lastDate,
    required DateTime initialStartDate,
    required DateTime initialEndDate,
  }) async {
    DateTimeRange? selectedRange;
    DateTime start = initialStartDate;
    DateTime end = initialEndDate;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text("Seleziona intervallo"),
            content: SizedBox(
              height: 300,
              child: dp.RangePicker(
                selectedPeriod: dp.DatePeriod(start, end),
                onChanged: (dp.DatePeriod range) {
                  setState(() {
                    start = range.start;
                    end = range.end;
                  });
                },
                firstDate: minCsvDate,
                lastDate: maxCsvDate,
                datePickerStyles: dp.DatePickerRangeStyles(),
                datePickerLayoutSettings: const dp.DatePickerLayoutSettings(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Annulla"),
              ),
              ElevatedButton(
                onPressed: () {
                  selectedRange = DateTimeRange(start: start, end: end);
                  Navigator.of(context).pop();
                },
                child: const Text("Applica"),
              ),
            ],
          ),
        );
      },
    );
    return selectedRange;
  }

  // Add this method to load available dates from the CSV header
  Future<List<String>> loadAvailableDates() async {
    await _ensureCsvLoaded();
    final header = _csvHeaderCache!;
    final dateRegExp = RegExp(r'\d{2}/\d{2}/\d{4}');
    final dateColumns = header.where((h) => h is String && dateRegExp.hasMatch(h)).cast<String>().toList();
    if (dateColumns.isNotEmpty) {
      minCsvDate = _parseCsvDate(dateColumns.first);
      maxCsvDate = _parseCsvDate(dateColumns.last);
    }
    return dateColumns;
  }

  static List<List<dynamic>>? _csvRowsCache;
  static List<dynamic>? _csvHeaderCache;

  // Add a helper to load and cache the CSV
  Future<void> _ensureCsvLoaded() async {
    if (_csvRowsCache != null && _csvHeaderCache != null) return;
    final response = await http.get(Uri.parse(
      'https://raw.githubusercontent.com/tommyiaq/privacy-policy/main/assets/pluvio_completi.csv',
    ));
    if (response.statusCode != 200) {
      throw Exception('Failed to load CSV');
    }
    final raw = response.body;
    final rows = const CsvToListConverter(fieldDelimiter: ',', eol: '\n').convert(raw);
    _csvRowsCache = rows;
    _csvHeaderCache = rows[0];
  }

  Timer? _debounceDayPicker;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            if (!widget.isArchivio)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    // Mushroom multi-select
                    Expanded(
                      child: Builder(
                        builder: (context) => GestureDetector(
                          onTap: () async {
                            final List<bool> tempSelection = List.from(selectedMushrooms);
                            final result = await showDialog<List<bool>>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Seleziona tipi di fungo'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (int i = 0; i < mushroomTypes.length; i++)
                                        CheckboxListTile(
                                          value: tempSelection[i],
                                          onChanged: (val) {
                                            tempSelection[i] = val!;
                                            (context as Element).markNeedsBuild();
                                          },
                                          title: Text(mushroomTypes[i]),
                                          controlAffinity: ListTileControlAffinity.leading,
                                        ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, null),
                                      child: const Text('Annulla'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, tempSelection),
                                      child: const Text('Applica'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (result != null && result != selectedMushrooms) {
                              setState(() {
                                selectedMushrooms.setAll(0, result);
                              });
                              await loadAndSetClouds();
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Tipi di fungo',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Row(
                              children: [
                                for (int i = 0; i < mushroomTypes.length; i++)
                                  if (selectedMushrooms[i])
                                    Row(children: [
                                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                                      const SizedBox(width: 4),
                                      Text(mushroomTypes[i]),
                                      const SizedBox(width: 8),
                                    ])
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Day dropdown
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedDayIndex,
                        decoration: const InputDecoration(
                          labelText: 'Giorno',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: List.generate(7, (i) {
                          final now = DateTime.now();
                          final date = now.add(Duration(days: i));
                          String label;
                          if (i == 0) {
                            label = 'Oggi';
                          } else if (i == 1) {
                            label = 'Domani';
                          } else {
                            label = _formatDayLabel(date);
                          }
                          return DropdownMenuItem(
                            value: i,
                            child: Text(label),
                          );
                        }),
                        onChanged: (val) {
                          setState(() {
                            selectedDayIndex = val!;
                          });
                          _debounceDayPicker?.cancel();
                          _debounceDayPicker = Timer(const Duration(milliseconds: 350), () {
                            loadAndSetClouds();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.isArchivio)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Builder(
                  builder: (context) => ElevatedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      startDate == null || endDate == null
                          ? "Seleziona intervallo date"
                          : startDate == endDate
                              ? "Data: $startDate"
                              : "Dal $startDate al $endDate",
                    ),
                    onPressed: () async {
                      final range = await showCustomDateRangePicker(
                        context: context,
                        firstDate: minCsvDate,
                        lastDate: maxCsvDate,
                        initialStartDate: _parseCsvDate(startDate!),
                        initialEndDate: _parseCsvDate(endDate!),
                      );
                      if (range != null) {
                        final selectedStart = _formatCsvDate(range.start);
                        final selectedEnd = _formatCsvDate(range.end);
                        if (availableDates.contains(selectedStart) &&
                            availableDates.contains(selectedEnd)) {
                          setState(() {
                            startDate = selectedStart;
                            endDate = selectedEnd;
                          });
                          await loadAndSetClouds();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Le date selezionate non sono presenti nel file CSV.'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: const LatLng(43.47, 11.14),
                  initialZoom: 8.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.mappa_funghi',
                  ),
                  // Single OverlayImageLayer for all overlays
                  OverlayImageLayer(
                    overlayImages: [
                      for (final entry in mushroomSpots.entries)
                        for (final spot in entry.value)
                          OverlayImage(
                            bounds: LatLngBounds(
                              LatLng(spot.position.latitude - 0.2, spot.position.longitude - 0.2),
                              LatLng(spot.position.latitude + 0.2, spot.position.longitude + 0.2),
                            ),
                            opacity: 1.0,
                            imageProvider: GradientCloudImage(
                              opacity: spot.opacity,
                              color: entry.key == 'Porcini' ? Colors.red : Colors.blue,
                            ),
                          ),
                    ],
                  ),
                  // Combine all markers into a single MarkerLayer
                  MarkerLayer(
                    markers: mushroomMarkers.values.expand((markers) => markers).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return MapView();
  }
}

class ArchivioPage extends StatelessWidget {
  const ArchivioPage({super.key});
  @override
  Widget build(BuildContext context) {
    return MapView(isArchivio: true);
  }
}

// Update GradientCloudImage to accept a color parameter
class GradientCloudImage extends ImageProvider<GradientCloudImage> {
  final double opacity;
  final Color color;
  const GradientCloudImage({required this.opacity, this.color = Colors.red});

  @override
  Future<GradientCloudImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<GradientCloudImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      GradientCloudImage key, ImageDecoderCallback decode) {
    const int size = 512;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    final center = Offset(size / 2, size / 2);
    final radius = size / 2;

    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          Color.alphaBlend(color.withAlpha((opacity * 255).toInt()), Colors.transparent),
          Color.alphaBlend(color.withAlpha(0), Colors.transparent),
        ],
        [0.0, 1.0],
        ui.TileMode.clamp,
      );

    canvas.drawCircle(center, radius, paint);
    final picture = recorder.endRecording();
    final imageFuture = picture.toImage(size, size);
    return OneFrameImageStreamCompleter(
      imageFuture.then((img) => ImageInfo(image: img, scale: 1.0)),
    );
  }

  @override
  bool operator ==(Object other) => other is GradientCloudImage && opacity == other.opacity && color == other.color;

  @override
  int get hashCode => opacity.hashCode ^ color.hashCode;
}

// Top-level function for compute()
List<Map<String, dynamic>> computeCloudSpots(Map<String, dynamic> args) {
  final List<List<dynamic>> rows = args['rows'];
  final int latIndex = args['latIndex'];
  final int lonIndex = args['lonIndex'];
  final int quotaIndex = args['quotaIndex'];
  final int nameIndex = args['nameIndex'];
  final int indexIndex = args['indexIndex']; // Add index column
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

class RainfallWebView extends StatefulWidget {
  final String url;
  final String? stationId;
  const RainfallWebView({super.key, required this.url, this.stationId});

  @override
  State<RainfallWebView> createState() => _RainfallWebViewState();
}

class _RainfallWebViewState extends State<RainfallWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cumulato 30 g'),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}