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
            width: isArchivio ? 15 : 25,
            height: isArchivio ? 15 : 25,
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
                            final uri = Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=${spot.position.latitude},${spot.position.longitude}');
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
                                    url:
                                        'https://www.sir.toscana.it/monitoraggio/dettaglio.php?id=${spot.index}&title=&type=pluvio_men',
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
          ))
      .toList();
}
