import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../viewmodel/edit_viewmodel.dart';

class EditScreen extends StatelessWidget {
  const EditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<EditViewModel>();


    return Scaffold(
      appBar: AppBar(
        title: const Text("Modify"),
      ),
      body: ListView(
        children: viewModel.visibleCharts.entries.map((entry) {
          final machineId = entry.key;
          final params = viewModel.machineParamsMap[machineId]!;
          final machineSplit = machineId.split("/").last.split("_");
          final machineName = machineSplit.join(" ");
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Machine: $machineName',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...params.map((param) {
                  final isVisible = viewModel.isChartVisible(machineId, param);
                  final color = viewModel.getChartColor(machineId, param);
                  final paramSplit = param.split("_");
                  final paramName = paramSplit.join(" ");
                  return ListTile(
                    title: Text(paramName),
                    leading: Checkbox(
                      value: isVisible,
                      onChanged: (_) {
                        viewModel.toggleVisibility(machineId, param);
                      },
                    ),
                    trailing: isVisible
                        ? GestureDetector(
                      onTap: () => _showColorPicker(context, viewModel, machineId, param, color),
                      child: CircleAvatar(backgroundColor: color),
                    )
                        : null,
                  );
                }),
                const Divider(),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showColorPicker(
      BuildContext context,
      EditViewModel viewModel,
      String machineId,
      String param,
      Color currentColor,
      ) {
    Color tempColor = currentColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Select color for $param"),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) => tempColor = color,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              viewModel.setChartColor(machineId, param, tempColor);
              Navigator.of(context).pop();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
