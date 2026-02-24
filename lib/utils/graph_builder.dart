import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tirocinio_template/model/machineinfo.dart';
import 'package:tirocinio_template/viewmodel/past_viewmodel.dart';

class GraphBuilder {

  // Grafico realtime: converte la lista di campioni in punti (FlSpot) usando l’indice come asse X,
  // crea label per asse/tooltip e mostra tooltip con data completa + unità di misura.
  static Widget LinearChartRT(
      BuildContext context,
      FieldInfo spec,
      Color color,
      List<MapEntry<Map<String, dynamic>, DateTime>> data,
      double Function(Map<String, dynamic>) extractor,
      Map<String, Map<String, double>> interval,
      ) {
    if (data.isEmpty) {
      return const Text("No data available");
    }

    final spots = <FlSpot>[];
    final xLabels = <int, String>{};
    final fullLabels = <int, String>{};

    // Trasformazione dati → grafico:
    // - x = indice (0..n-1)
    // - y = valore estratto dal payload
    // - label corta per asse X e label completa per tooltip
    for (int i = 0; i < data.length; i++) {
      final date = data[i].value;
      final value = extractor(data[i].key);
      spots.add(FlSpot(i.toDouble(), value));
      xLabels[i] = DateFormat('mm:ss').format(date);
      fullLabels[i] = DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
    }

    final min = interval[spec.fieldPath]?['min'] ?? 0;
    final max = interval[spec.fieldPath]?['max'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text(spec.fieldDescription, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.black54,
                    // Tooltip: usa fullLabels per mostrare timestamp completo del punto selezionato
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        final value = spot.y;
                        return LineTooltipItem(
                          'Date: ${fullLabels[index]}\n'
                              'Value: ${value.toStringAsFixed(2)} ${spec.uomSymbol}',
                          const TextStyle(color: Colors.white),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(spec.uomSymbol),
                    axisNameSize: 16,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: null,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text("mins:secs"),
                    axisNameSize: 16,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: (spots.length / 5).floorToDouble().clamp(1, double.infinity),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        return Text(
                          xLabels[index] ?? '',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    left: BorderSide(),
                    bottom: BorderSide(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: color,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    "Min: ${min.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    "Max: ${max.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Grafico a colonne: sceglie automaticamente un campo numerico dai dati,
  // gestisce paginazione e mostra dettagli al tap su una barra.
  static Widget ColumnChart(
      BuildContext context,
      List<Map<String, dynamic>> data,
      List<MachineInfo> machines,
      PastViewModel vm,
      ) {
    final random = Random();
    bool _dialogOpen = false;

    // Selezione automatica del campo da visualizzare:
    // prendo la prima chiave numerica disponibile.
    String? valueKey;
    for (var entry in data.first.entries) {
      if (entry.key != 'machine_id' &&
          entry.key != 'source_id' &&
          entry.value is num) {
        valueKey = entry.key;
        break;
      }
    }

    if (valueKey == null) {
      return const Center(child: Text('No valid numeric field found.'));
    }

    final normalizedKey = valueKey.contains('_')
        ? valueKey.substring(valueKey.indexOf('_') + 1)
        : valueKey;

    String abbreviateLabel(String sourceId) {
      final parts = sourceId.split('_');
      String short = '';
      for (var p in parts) {
        if (RegExp(r'^\d+$').hasMatch(p)) {
          short += p;
        } else {
          short += p[0].toUpperCase();
        }
      }
      return short;
    }

    // Paginazione: limita il numero di barre per pagina per mantenere leggibilità su mobile.
    const int itemsPerPage = 3;
    final int totalPages = (data.length / itemsPerPage).ceil();
    final ValueNotifier<int> currentPage = ValueNotifier<int>(0);

    List<Map<String, dynamic>> getCurrentPageData() {
      final start = currentPage.value * itemsPerPage;
      final end = (start + itemsPerPage) > data.length
          ? data.length
          : start + itemsPerPage;
      return data.sublist(start, end);
    }

    return StatefulBuilder(
      builder: (context, setState) {
        final currentData = getCurrentPageData();

        final barSpots = <BarChartGroupData>[];
        for (int i = 0; i < currentData.length; i++) {
          final value = (currentData[i][valueKey] as num?)?.toDouble() ?? 0;
          final barColor = Color.fromARGB(
            255,
            random.nextInt(256),
            random.nextInt(256),
            random.nextInt(256),
          );

          barSpots.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: value,
                  color: barColor,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
              showingTooltipIndicators: [0],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            children: [
              SizedBox(
                height: 220,
                width: double.infinity,
                child: BarChart(
                  BarChartData(
                    barGroups: barSpots,
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) {
                            final index = value.toInt();
                            if (index >= 0 && index < currentData.length) {
                              final rawSourceId =
                              currentData[index]['source_id'].toString();
                              final label =
                              abbreviateLabel(rawSourceId.split('/').last);
                              return Text(label,
                                  style: const TextStyle(fontSize: 10));
                            }
                            return const Text('');
                          },
                          reservedSize: 48,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) => Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10),
                          ),
                          reservedSize: 32,
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: Colors.black,
                        // Tooltip: calcola unità di misura dal metadata (vm) in base a sourceId + key normalizzata
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final entry = currentData[group.x.toInt()];
                          final rawSourceId = entry['source_id'] as String;
                          final sourceId =
                          rawSourceId.split('/').last.replaceAll('_', ' ');
                          final value = (entry[valueKey] as num?)?.toDouble();

                          final uomSymbol = vm.uomSymbolGetter(
                              sourceId, normalizedKey, machines);

                          return BarTooltipItem(
                            '${value?.toStringAsFixed(2) ?? '-'} ${uomSymbol ?? ''}',
                            const TextStyle(color: Colors.white),
                          );
                        },
                      ),
                      touchCallback: (event, response) {
                        // Tap su una barra: apre un dialog con dettagli (id macchina + descrizione + unità).
                        // _dialogOpen evita apertura multipla di dialog su tocchi ripetuti.
                        if (event.isInterestedForInteractions &&
                            response != null &&
                            response.spot != null &&
                            !_dialogOpen) {
                          _dialogOpen = true;
                          final groupIndex =
                              response.spot!.touchedBarGroupIndex;
                          final entry = currentData[groupIndex];
                          final rawSourceId = entry['source_id'] as String;
                          final sourceId =
                          rawSourceId.split('/').last.replaceAll('_', ' ');
                          final machineId = entry['machine_id'];
                          final value = (entry[valueKey] as num?)?.toDouble();

                          final fieldPath = normalizedKey;
                          final uomSymbol = vm.uomSymbolGetter(
                              sourceId, normalizedKey, machines);
                          final fieldDescription = vm.fieldDescriptionGetter(
                              sourceId, normalizedKey, machines);

                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Details'),
                              content: Text(
                                'Machine ID: $machineId\n'
                                    '$fieldDescription ($fieldPath): ${value?.toStringAsFixed(2) ?? '-'} ${uomSymbol ?? ''}',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    _dialogOpen = false;
                                  },
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (totalPages > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: currentPage.value > 0
                          ? () {
                        currentPage.value--;
                        setState(() {});
                      }
                          : null,
                      child: const Text("Prev"),
                    ),
                    const SizedBox(width: 10),
                    Text("Page ${currentPage.value + 1} of $totalPages"),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: currentPage.value < totalPages - 1
                          ? () {
                        currentPage.value++;
                        setState(() {});
                      }
                          : null,
                      child: const Text("Next"),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  // Pie chart: trasforma conteggi in percentuali sul totale e costruisce sezioni + legenda.
  static Widget PieChartWidget(BuildContext context, Map<String, int> data) {
    final entries = data.entries.toList();
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);

    final List<Color> colorPalette = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.cyan,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
      Colors.brown,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 0,
              sections: List.generate(entries.length, (index) {
                final entry = entries[index];
                final value = entry.value.toDouble();
                final percent = (value / total * 100);
                final color = colorPalette[index % colorPalette.length];

                return PieChartSectionData(
                  color: color,
                  value: value,
                  title: '${percent.toStringAsFixed(1)}%',
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  radius: 60,
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(entries.length, (index) {
              final entry = entries[index];
              final percent = (entry.value / total * 100).toStringAsFixed(1);
              final color = colorPalette[index % colorPalette.length];
              final textColor = Colors.white;

              return Card(
                color: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Center(
                    child: Text(
                      '${entry.key} — ${entry.value} elements ($percent%)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // Grafico query/storico con paginazione: prepara i punti, permette di scegliere batchSize,
  // mostra una pagina per volta e consente lo switch pagina con swipe o pulsanti.
  // Calcola anche min/max e date min/max sia locali (pagina) che globali (dataset completo).
  static Widget LinearChartQuery(
      BuildContext context,
      Color color,
      List<MapEntry<Map<String, dynamic>, DateTime>> data,
      double Function(Map<String, dynamic>) extractor,
      Map<String, Map<String, double>> interval,
      String? fieldDescription,
      String? uomSymbol,
      ) {
    if (data.isEmpty) {
      return const Text("No data available");
    }

    //rendo uniforme la struttura dei punti per gestire paging e tooltip
    final rawPoints = data.map((entry) {
      final date = entry.value;
      return {
        'datetime': date,
        'xLabel': DateFormat('mm:ss').format(date),
        'fullLabel': DateFormat('yyyy-MM-dd HH:mm:ss').format(date),
        'value': extractor(entry.key),
      };
    }).toList();

    int batchSize = 10;

    // Divide rawPoints in pagine di dimensione batchSize
    List<List<Map<String, dynamic>>> getPages(int size) {
      return [
        for (int i = 0; i < rawPoints.length; i += size)
          rawPoints.skip(i).take(size).toList()
      ];
    }

    final controller = TextEditingController(text: batchSize.toString());
    final ValueNotifier<int> currentPageIndex = ValueNotifier<int>(0);

    double getMin(List<Map<String, dynamic>> points) =>
        points.map((e) => e['value'] as double).reduce((a, b) => a < b ? a : b);

    double getMax(List<Map<String, dynamic>> points) =>
        points.map((e) => e['value'] as double).reduce((a, b) => a > b ? a : b);

    DateTime getDateMin(List<Map<String, dynamic>> points) =>
        points.map((e) => e['datetime'] as DateTime).reduce((a, b) => a.isBefore(b) ? a : b);

    DateTime getDateMax(List<Map<String, dynamic>> points) =>
        points.map((e) => e['datetime'] as DateTime).reduce((a, b) => a.isAfter(b) ? a : b);

    // Statistiche globali
    final globalMin = getMin(rawPoints);
    final globalMax = getMax(rawPoints);
    final globalDateMin = getDateMin(rawPoints);
    final globalDateMax = getDateMax(rawPoints);

    return StatefulBuilder(
      builder: (context, setState) {
        List<List<Map<String, dynamic>>> pages = getPages(batchSize);
        final currentPage = pages.isNotEmpty
            ? pages[currentPageIndex.value]
            : <Map<String, dynamic>>[];

        final localMin = currentPage.isEmpty ? 0 : getMin(currentPage);
        final localMax = currentPage.isEmpty ? 0 : getMax(currentPage);
        final localDateMin = currentPage.isEmpty ? null : getDateMin(currentPage);
        final localDateMax = currentPage.isEmpty ? null : getDateMax(currentPage);

        final spots = currentPage.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), e.value['value'] as double);
        }).toList();

        final fullLabels = currentPage.asMap().map((i, e) => MapEntry(i, e['fullLabel'] as String));

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(fieldDescription!, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Size number",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final newSize = int.tryParse(controller.text);
                      if (newSize != null && newSize > 0) {
                        batchSize = newSize;
                        currentPageIndex.value = 0;
                        setState(() {});
                      }
                    },
                    child: const Text("Confirm"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onHorizontalDragEnd: (details) {
                  // Swipe: cambia pagina (destra/sinistra) senza scroll classico
                  if (details.primaryVelocity != null) {
                    if (details.primaryVelocity! < 0 &&
                        currentPageIndex.value < pages.length - 1) {
                      currentPageIndex.value++;
                    } else if (details.primaryVelocity! > 0 &&
                        currentPageIndex.value > 0) {
                      currentPageIndex.value--;
                    }
                    setState(() {});
                  }
                },
                child: SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          axisNameWidget: Text((uomSymbol!)),
                          axisNameSize: 16,
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, _) => Text(
                              value.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          axisNameWidget: const Text("Mins:Secs"),
                          axisNameSize: 16,
                          sideTitles: SideTitles(
                            showTitles: false,
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: const Border(
                          left: BorderSide(),
                          bottom: BorderSide(),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: Colors.black54,
                          getTooltipItems: (spots) {
                            return spots.map((spot) {
                              final index = spot.x.toInt();
                              final value = spot.y;
                              return LineTooltipItem(
                                'Date: ${fullLabels[index]}\n'
                                    'Value: ${value.toStringAsFixed(2)} ${(uomSymbol)}',
                                const TextStyle(color: Colors.white),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: false,
                          color: color,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Min: ${localMin.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Max: ${localMax.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (localDateMin != null && localDateMax != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Date Min: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(localDateMin)}",
                              style: const TextStyle(fontSize: 12)),
                          Text("Date Max: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(localDateMax)}",
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ),
              Text(
                "Global Min: ${globalMin.toStringAsFixed(2)} | Max: ${globalMax.toStringAsFixed(2)}",
                style: const TextStyle(color: Colors.grey),
              ),
              Text(
                "Global Date Min: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(globalDateMin)}\n"
                    "Global Date Max: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(globalDateMax)}",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              if (pages.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "Page ${currentPageIndex.value + 1} di ${pages.length}",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              if (pages.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: currentPageIndex.value > 0
                            ? () {
                          currentPageIndex.value--;
                          setState(() {});
                        }
                            : null,
                        child: const Text("Back"),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: currentPageIndex.value < pages.length - 1
                            ? () {
                          currentPageIndex.value++;
                          setState(() {});
                        }
                            : null,
                        child: const Text("Next"),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}