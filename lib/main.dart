import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:csv/csv.dart';
import 'package:flutter_date_pickers/flutter_date_pickers.dart' as dp;

void main() {
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
      home: const MapScreen(),
    );
  }
}

class CloudSpot {
  final LatLng position;
  final double opacity;
  final String info;
  CloudSpot(this.position, this.opacity, this.info);
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<CloudSpot> spots = [];
  List<Marker> infoMarkers = [];
  List<String> availableDates = [];
  Set<DateTime> selectableDates = {};
  String? startDate;
  String? endDate;
  late DateTime minCsvDate;
  late DateTime maxCsvDate;

  String _formatCsvDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/"
           "${date.month.toString().padLeft(2, '0')}/"
           "${date.year}";
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
      });
      loadAndSetClouds();
    });
  }

  Future<void> loadAndSetClouds() async {
    if (startDate == null || endDate == null) return;
    final cloudSpots = await loadCloudSpots(startDate!, endDate!);
    setState(() {
      spots = cloudSpots;
    });
  }

  Future<List<String>> loadAvailableDates() async {
    // final raw = await rootBundle.loadString('assets/dati_completi.csv');
    final response = await http.get(Uri.parse(
      'https://raw.githubusercontent.com/tommyiaq/mappa_funghi_toscana/main/assets/dati_completi.csv',
    ));

    if (response.statusCode != 200) {
    throw Exception('Failed to load CSV');
    }

    final raw = response.body;

    final rows = const CsvToListConverter(fieldDelimiter: ',', eol: '\n')
        .convert(raw)
        .map((row) => row.cast<String>())
        .toList();
    final header = rows[0];
    final dates = header.where((h) => RegExp(r'\d{2}/\d{2}/\d{4}').hasMatch(h)).toList();
    selectableDates = dates.map(_parseCsvDate).toSet();
    final sortedDates = selectableDates.toList()..sort();
    minCsvDate = sortedDates.first;
    maxCsvDate = sortedDates.last;
    return dates;
  }

  Future<List<CloudSpot>> loadCloudSpots(String start, String end) async {
    //final raw = await rootBundle.loadString('assets/dati_completi.csv');
    final response = await http.get(Uri.parse(
      'https://raw.githubusercontent.com/tommyiaq/mappa_funghi_toscana/main/assets/dati_completi.csv',
    ));

    if (response.statusCode != 200) {
    throw Exception('Failed to load CSV');
    }

    final raw = response.body;

    final rows = const CsvToListConverter(fieldDelimiter: ',', eol: '\n').convert(raw);
    final header = rows[0];
    final latIndex = header.indexOf("LAT [°]");
    final lonIndex = header.indexOf("LON [°]");
    final quotaIndex = header.indexOf("Quota");
    final nameIndex = header.indexOf("Nome");
    final startIdx = header.indexOf(start);
    final endIdx = header.indexOf(end);
    final dateIndices = startIdx == endIdx
        ? [startIdx]
        : List.generate(endIdx - startIdx + 1, (i) => startIdx + i);

    List<CloudSpot> result = [];
    infoMarkers.clear();

    for (final row in rows.skip(1)) {
      final double lat = row[latIndex] as double;
      final double lon = row[lonIndex] as double;
      final String name = row[nameIndex].toString();
      final double quota = (row[quotaIndex] as num?)?.toDouble() ?? 0.0;

      final sumValue = dateIndices.fold<double>(
          0, (sum, i) => sum + ((row[i] as num?)?.toDouble() ?? 0.0));
      final double opacity = computeOpacity(sumValue);

      result.add(CloudSpot(LatLng(lat, lon), opacity, '$name\nLat: $lat\nLon: $lon\nQuota: ${quota.toStringAsFixed(1)} m\nRain: ${sumValue.toStringAsFixed(1)} mm'));

      if (sumValue > 20) {
        infoMarkers.add(
          Marker(
            point: LatLng(lat, lon),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                  title: Text(name),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cumulato: ${sumValue.toStringAsFixed(1)} mm'),
                    const SizedBox(height: 8),
                    Text('Quota: ${quota.toStringAsFixed(0)} mslm'),
                    const SizedBox(height: 8),      
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Text(
                        'Open in Maps',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),                  ),
                );
              },
              child: const Icon(Icons.location_on, color: Colors.blue, size: 30),
            ),
          ),
        );
      }
    }
    return result;
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            if (true)
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
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.mappa_funghi',
                  ),
                  OverlayImageLayer(
                    overlayImages: spots.map((spot) {
                      const radius = 0.2;
                      return OverlayImage(
                        bounds: LatLngBounds(
                          LatLng(spot.position.latitude - radius, spot.position.longitude - radius),
                          LatLng(spot.position.latitude + radius, spot.position.longitude + radius),
                        ),
                        opacity: 1.0,
                        imageProvider: GradientCloudImage(opacity: spot.opacity),
                      );
                    }).toList(),
                  ),
                  MarkerLayer(markers: infoMarkers),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GradientCloudImage extends ImageProvider<GradientCloudImage> {
  final double opacity;
  const GradientCloudImage({required this.opacity});

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
          Colors.red.withOpacity(opacity),
          Colors.red.withOpacity(0.0),
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
  bool operator ==(Object other) => other is GradientCloudImage && opacity == other.opacity;

  @override
  int get hashCode => opacity.hashCode;
}