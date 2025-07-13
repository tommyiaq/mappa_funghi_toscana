import 'package:flutter/material.dart';
import '../widgets/map_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MapView(
      key: PageStorageKey('HomeMapView'),
      isArchivio: false,
    );
  }
}
