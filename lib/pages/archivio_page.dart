import 'package:flutter/material.dart';
import '../widgets/map_view.dart';

class ArchivioPage extends StatelessWidget {
  const ArchivioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MapView(
      key: PageStorageKey('ArchivioMapView'),
      isArchivio: true,
    );
  }
}
