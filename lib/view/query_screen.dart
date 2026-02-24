import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:provider/provider.dart';
import 'package:tirocinio_template/model/machineinfo.dart';
import '../utils/graph_builder.dart';
import '../viewmodel/past_viewmodel.dart';

class QueryData extends StatefulWidget {
  final List<MachineInfo> machines;
  final String accessToken;

  const QueryData({super.key, required this.machines, required this.accessToken});


  @override
  State<QueryData> createState() => _QueryDataState();
}

class _QueryDataState extends State<QueryData> {

  bool _bottomSheetOpen = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final vm = PastViewModel();
        vm.accessToken = widget.accessToken;
        return vm;
      },
      child: Consumer<PastViewModel>(
        builder: (context, vm, _) {
          final machineOptions = widget.machines.map((machine) => DropdownMenuItem<String>(
            value: machine.sourceId,
            child: Text(machine.sourceId.split("/").last.split("_").join(" ")),))
              .toList();

          final parameterOptions = const [
            DropdownMenuItem(value: 'temperature', child: Text('Temperature')),
            DropdownMenuItem(value: 'noise_pollution', child: Text('Noise pollution')),
            DropdownMenuItem(value: 'velocity', child: Text('Velocity')),
            DropdownMenuItem(value: 'vibration', child: Text('Vibration')),
          ];

          final aggregationOptions = const [
            DropdownMenuItem(value: 'avg', child: Text('Average')),
            DropdownMenuItem(value: 'max', child: Text('Maximum')),
            DropdownMenuItem(value: 'min', child: Text('Minimum')),
          ];

          if (vm.errorMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Error'),
                  content: Text(vm.errorMessage!),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        vm.errorMessage = null;
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            });
          }
          if (vm.objectSidedAlone != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('One data found'),
                  content: Text(vm.objectSidedAlone!),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        vm.clearObjectSidedAlone();
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            });
          }

          if (vm.groupedResults.isNotEmpty && !vm.hasShownBottomSheet) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              vm.setHasShownBottomSheet(true);
              _bottomSheetOpen = true;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) {
                  bool visiblePieChart = false;
                  bool visibleBarChart = false;
                  bool visibleLinearChart = false;

                  bool isLoadingPie = false;
                  bool isLoadingBar = false;
                  bool isLoadingLinear = false;

                  String? selectedSensorId;

                  return StatefulBuilder(
                    builder: (context, setModalState) {
                      final charts = <Widget>[];

                      if (visibleLinearChart) {
                        if (selectedSensorId == null && vm.groupedResults.length == 1) {
                          selectedSensorId = vm.groupedResults.keys.first;
                        }

                        bool showSensorMenu = true;

                        if (vm.groupedResults.length > 1) {
                          charts.add(
                            ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                              initiallyExpanded: showSensorMenu,
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Select machine',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              onExpansionChanged: (expanded) {
                                setModalState(() {
                                  showSensorMenu = expanded;
                                });
                              },
                              children: [
                                Center(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: vm.groupedResults.keys.map((sensorId) {
                                      final bool isSelected = sensorId == selectedSensorId;

                                      return ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isSelected ? Colors.blueAccent : null,
                                          foregroundColor: isSelected ? Colors.white : null,
                                        ),
                                        onPressed: () {
                                          setModalState(() {
                                            isLoadingLinear = true;
                                            selectedSensorId = sensorId;
                                          });
                                          Future.delayed(const Duration(milliseconds: 300), () {
                                            if (!mounted || !_bottomSheetOpen) return; {
                                              setModalState(() {
                                                isLoadingLinear = false;
                                              });
                                            }
                                          });
                                        },
                                        child: Text(sensorId),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }


                        if (selectedSensorId != null) {
                          if (isLoadingLinear) {
                            charts.add(SizedBox(
                              height: 200,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 12),
                                    Text(
                                      'Loading...',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ));
                          } else {
                            final machineList = vm.groupedResults[selectedSensorId]!;
                            final interval = Map.fromEntries(vm.maxAndMinValues.entries
                                .where((e) => e.key.startsWith('$selectedSensorId-'))
                                .map((e) => MapEntry(
                              e.key.replaceFirst('$selectedSensorId-', ''),
                              e.value,
                            )));

                            final mappedData = machineList
                                .map<MapEntry<Map<String, dynamic>, DateTime>>(
                                  (m) => MapEntry(m, DateTime.fromMillisecondsSinceEpoch(m['timestamp'] ?? 0)),
                            )
                                .toList();


                            final allKeys = <String>{};
                            for (var entry in machineList) {
                              allKeys.addAll(entry.keys);
                            }
                            allKeys.removeWhere((k) => ['sensor_id', 'source_id', 'machine_id', 'timestamp'].contains(k));

                            for (var key in allKeys) {
                              charts.add(GraphBuilder.LinearChartQuery(
                                context,
                                Colors.primaries[allKeys.toList().indexOf(key) % Colors.primaries.length],
                                mappedData,
                                    (m) => (m[key] as num?)?.toDouble() ?? 0.0,
                                interval,
                                vm.fieldDescriptionGetter(selectedSensorId, key, widget.machines),
                                vm.uomSymbolGetter(selectedSensorId, key, widget.machines),
                              ));
                              charts.add(const SizedBox(height: 80));
                            }

                          }
                        }
                      }

                      if (visibleBarChart) {
                        if (isLoadingBar) {
                          charts.add(SizedBox(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text(
                                    'Loading...',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ));
                        } else {
                          final allData = vm.groupedResults.entries.expand((e) => e.value).toList();
                          charts.add(GraphBuilder.ColumnChart(context, allData, widget.machines, vm));
                          charts.add(const SizedBox(height: 80));
                        }
                      }

                      if (visiblePieChart) {
                        if (isLoadingPie) {
                          charts.add(SizedBox(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text(
                                    'Loading...',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ));
                        } else {
                          charts.add(GraphBuilder.PieChartWidget(context, vm.sensorIdCounts));
                          charts.add(const SizedBox(height: 80));
                        }
                      }

                      return DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.85,
                        maxChildSize: 0.95,
                        minChildSize: 0.4,
                        builder: (context, scrollController) => SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text("Results",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  if (vm.showBarChart)
                                    IconButton(
                                      icon: Icon(
                                        Icons.bar_chart,
                                        color: visibleBarChart ? Colors.blue : Colors.grey,
                                      ),
                                      onPressed: () {
                                        setModalState(() {
                                          visibleBarChart = !visibleBarChart;
                                          isLoadingBar = true;
                                        });

                                        Future.delayed(const Duration(milliseconds: 300), () {
                                          if (!mounted || !_bottomSheetOpen) return;

                                          setModalState(() {
                                            isLoadingBar = false;
                                          });
                                        });
                                      },

                                    ),
                                  if (vm.showPieChart)
                                    IconButton(
                                      icon: Icon(
                                        Icons.pie_chart,
                                        color: visiblePieChart ? Colors.orange : Colors.grey,
                                      ),
                                      onPressed: () {
                                        setModalState(() {
                                          visiblePieChart = !visiblePieChart;
                                          isLoadingPie = true;
                                        });

                                        Future.delayed(const Duration(milliseconds: 300), () {
                                          if (!mounted || !_bottomSheetOpen) return;

                                          setModalState(() {
                                            isLoadingPie = false;
                                          });
                                        });
                                      },
                                    ),
                                  if (vm.showLinearChart)
                                    IconButton(
                                      icon: Icon(
                                        Icons.show_chart,
                                        color: visibleLinearChart ? Colors.green : Colors.grey,
                                      ),
                                      onPressed: () {
                                        setModalState(() {
                                          visibleLinearChart = !visibleLinearChart;
                                          isLoadingLinear = true;
                                        });

                                        Future.delayed(const Duration(milliseconds: 300), () {
                                          if (!mounted || !_bottomSheetOpen) return;

                                          setModalState(() {
                                            isLoadingLinear = false;
                                          });
                                        });
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              ...charts,
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ).whenComplete(() {
                if (mounted) _bottomSheetOpen = false;
              });
            });
          }



          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Search using machine'),
                    value: vm.searchChooser,
                    onChanged: vm.toggleSearchMethod,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Insert date manually'),
                    value: vm.manualDateEntry,
                    onChanged: vm.toggleManualDateEntry,
                  ),
                  const SizedBox(height: 16),
                  if (vm.searchChooser)
                    Center(
                      child: SizedBox(
                        width: 300,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: 'Select machine',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: machineOptions,
                                    value: (vm.selectedMachine.isNotEmpty &&
                                        machineOptions.any((item) => item.value == vm.selectedMachine.first))
                                        ? vm.selectedMachine.first
                                        : null,
                                    onChanged: (machineId) {
                                      if (machineId != null) vm.setSingleMachine(machineId);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (vm.machineValidationMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 4),
                                child: Text(
                                  vm.machineValidationMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (vm.searchChooser) const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select parameter',
                            border: OutlineInputBorder(),
                          ),
                          items: parameterOptions,
                          value: vm.selectedParameter,
                          onChanged: (value) {
                            vm.setParameter(value);
                            if (vm.selectedAggregation != null && value == null) {
                              vm.setAggregation(null);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Reset',
                        onPressed: () {
                          vm.setParameter(null);
                          vm.setAggregation(null);
                        },
                      ),
                    ],
                  ),
                  if (!vm.searchChooser && vm.parameterValidationMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        vm.parameterValidationMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (details) {
                      final box = context.findRenderObject() as RenderBox;
                      final localPosition = box.globalToLocal(details.globalPosition);

                      if (localPosition.dx < box.size.width - 48) {
                        if (vm.selectedParameter == null) {
                          vm.showAggregationError();
                        }
                      }
                    },
                    child: AbsorbPointer(
                      absorbing: vm.selectedParameter == null,
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Select aggregation (not required)',
                                border: OutlineInputBorder(),
                              ),
                              items: aggregationOptions,
                              value: vm.selectedAggregation,
                              onChanged: vm.setAggregation,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Reset',
                            onPressed: () => vm.setAggregation(null),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (vm.aggregationValidationMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        vm.aggregationValidationMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (vm.manualDateEntry) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: vm.startController,
                            decoration: const InputDecoration(
                              labelText: 'Start date (yyyy-MM-dd HH:mm[:ss])',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => vm.validateDateInput(value, true),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Reset',
                          onPressed: () => vm.resetStartDate(),
                        ),
                      ],
                    ),
                    if (vm.startDateValidation != null && vm.startDateValidation != "")
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          vm.startDateValidation!,
                          style: TextStyle(color: vm.startDateValidationColor),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: vm.endController,
                            decoration: const InputDecoration(
                              labelText: 'End date (yyyy-MM-dd HH:mm[:ss])',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => vm.validateDateInput(value, false),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Reset',
                          onPressed: () => vm.resetEndDate(),
                        ),
                      ],
                    ),
                    if (vm.endDateValidation != null && vm.endDateValidation != "")
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          vm.endDateValidation!,
                          style: TextStyle(color: vm.endDateValidationColor),
                        ),
                      ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today),
                            label: Text(vm.startDate != null ? 'Start: ${vm.startDate}' : 'Select start date'),
                            onPressed: () => _selectDateTime(context, true),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Reset',
                          onPressed: () => vm.resetStartDate(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today),
                            label: Text(vm.endDate != null ? 'End: ${vm.endDate}' : 'Select end date'),
                            onPressed: () => _selectDateTime(context, false),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Reset',
                          onPressed: () => vm.resetEndDate(),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: vm.limitController,
                          decoration: const InputDecoration(
                            labelText: 'Number of data to be analyzed (not required)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            if (value.isEmpty) {
                              vm.setLimit(null);
                            } else {
                              final parsed = int.tryParse(value);
                              if (parsed != null) {
                                vm.setLimit(parsed);
                              }
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Reset',
                        onPressed: () => vm.setLimit(null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: vm.isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton.icon(
                      onPressed: () {
                        bool valid = true;

                        if (vm.searchChooser && vm.selectedMachine.isEmpty) {
                          vm.showMachineError();
                          valid = false;
                        }

                        if (!vm.searchChooser) {
                          vm.selectedMachine = widget.machines.map((m) => m.sourceId).toList();
                        }

                        if (!vm.searchChooser && vm.selectedParameter == null) {
                          vm.showParameterError();
                          valid = false;
                        }

                        if (vm.manualDateEntry) {
                          if (vm.startDateValidationColor == Colors.red ||
                              vm.endDateValidationColor == Colors.red) {
                            valid = false;
                          }
                        }

                        if (valid) {
                          vm.submitQuery();
                        }
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Data view'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final vm = Provider.of<PastViewModel>(context, listen: false);
    DatePicker.showDateTimePicker(
      context,
      showTitleActions: true,
      currentTime: DateTime.now(),
      maxTime: DateTime.now(),
      onConfirm: (date) {
        isStart ? vm.setStartDate(date) : vm.setEndDate(date);
      },
    );
  }
}
