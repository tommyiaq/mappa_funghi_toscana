import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class MushroomSelector extends StatelessWidget {
  final List<String> mushroomTypes;
  final List<bool> selectedMushrooms;
  final Function(List<bool>) onSelectionChanged;

  const MushroomSelector({
    super.key,
    required this.mushroomTypes,
    required this.selectedMushrooms,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final List<bool> tempSelection = List.from(selectedMushrooms);
        final result = await showDialog<List<bool>>(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Seleziona tipi di fungo'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < mushroomTypes.length; i++)
                        CheckboxListTile(
                          value: tempSelection[i],
                          onChanged: (val) {
                            setState(() {
                              tempSelection[i] = val!;
                            });
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
          },
        );
        
        if (result != null && result != selectedMushrooms) {
          onSelectionChanged(result);
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Tipi di fungo',
          border: OutlineInputBorder(),
          contentPadding: AppConstants.controlPadding,
        ),
        child: Row(
          children: [
            for (int i = 0; i < mushroomTypes.length; i++)
              if (selectedMushrooms[i])
                Row(children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: AppConstants.iconSize),
                  const SizedBox(width: AppConstants.spacingSmall),
                  Text(mushroomTypes[i]),
                  const SizedBox(width: AppConstants.spacingMedium),
                ])
          ],
        ),
      ),
    );
  }
}
