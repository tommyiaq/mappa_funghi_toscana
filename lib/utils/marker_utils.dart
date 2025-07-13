import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/cloud_spot.dart';
import '../widgets/rainfall_webview.dart';
import 'package:url_launcher/url_launcher.dart';

/// Builds a list of Marker widgets for the given cloud spots and mushroom type.
List<Marker> buildMarkers({
  required List<CloudSpot> spots,
  required String mushroomType,
  required bool isArchivio,
  required BuildContext context,
}) {
  final iconAsset = isArchivio
      ? null
      : (mushroomType == 'Porcini' ? 'assets/porcino.png' : 'assets/giallarella.png');
  final threshold = mushroomType == 'Porcini' ? 50.0 : 30.0;
  return spots
      .where((spot) => spot.opacity > 0.0 && spot.cumulatedValue > threshold)
      .map((spot) => Marker(
            point: spot.position,
            width: isArchivio ? 25 : 25,  // Same size for both modes
            height: isArchivio ? 25 : 25, // Same size for both modes
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
                        // Station details
                        ..._buildStationInfo(spot),
                        const SizedBox(height: 12),
                        
                        // Action buttons
                        _buildMapButton(spot),
                        if (spot.index != null && spot.index!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildRainfallButton(context, spot),
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
          ))
      .toList();
}

/// Helper method to build station information widgets
List<Widget> _buildStationInfo(CloudSpot spot) {
  final infoLines = spot.info.split('\n');
  final List<Widget> widgets = [];
  
  for (int i = 1; i < infoLines.length; i++) {
    final line = infoLines[i];
    IconData icon;
    Color color = Colors.grey[700]!;
    
    if (line.contains('Quota:')) {
      icon = Icons.height;
    } else if (line.contains('Cumulato:')) {
      icon = Icons.water_drop;
      color = Colors.blue;
    } else if (line.contains('Temp. media')) {
      icon = Icons.thermostat;
      color = Colors.orange;
    } else {
      icon = Icons.info_outline;
    }
    
    widgets.add(
      Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(line)),
        ],
      ),
    );
    
    if (i < infoLines.length - 1) {
      widgets.add(const SizedBox(height: 4));
    }
  }
  
  return widgets;
}

/// Helper method to build the Maps button
Widget _buildMapButton(CloudSpot spot) {
  return GestureDetector(
    onTap: () async {
      final uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${spot.position.latitude},${spot.position.longitude}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map, size: 16, color: Colors.blue),
          SizedBox(width: 8),
          Text(
            'Apri in Maps',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Helper method to build the rainfall data button
Widget _buildRainfallButton(BuildContext context, CloudSpot spot) {
  return GestureDetector(
    onTap: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RainfallWebView(
            url:
                'https://www.sir.toscana.it/monitoraggio/dettaglio.php?id=${spot.index}&title=&type=pluvio_men',
            stationId: spot.index,
          ),
        ),
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 16, color: Colors.green),
          SizedBox(width: 8),
          Text(
            'Cumulato 30 g',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}
