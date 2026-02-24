import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/machineinfo.dart';
import '../service/machine_past_service.dart';

class PastViewModel extends ChangeNotifier {

  String? _accessToken;
  set accessToken(String token) {
    _accessToken = token;
  }

  bool searchChooser = true;

  List<String> selectedMachine = [];
  String? startDate;
  String? endDate;
  int? limit;

  String? selectedParameter;
  String? selectedAggregation;
  double? minValue;
  double? maxValue;

  Map<String, int> sensorIdCounts = {};
  Map<String, List<Map<String, dynamic>>> groupedResults = {};

  String? uomSymbol;

  bool isLoading = false;
  bool hasSubmitted = false;
  bool manualDateEntry = false;

  String? errorMessage;
  String? aggregationValidationMessage;
  String? machineValidationMessage;
  String? parameterValidationMessage;
  String? objectSidedAlone;

  Color get aggregationValidationColor => Colors.red;

  bool showBarChart = false;
  bool showPieChart = false;
  bool showLinearChart = false;

  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();
  final TextEditingController limitController = TextEditingController();

  String? startDateValidation;
  Color startDateValidationColor = Colors.green;

  String? endDateValidation;
  Color endDateValidationColor = Colors.green;

  final Map<String, Map<String, double>> _maxAndMinValues = {};

  Map<String, Map<String, double>> get maxAndMinValues => _maxAndMinValues;

  void _updateMaxAndMin(String sensorId, String key, double value) {
    _maxAndMinValues.putIfAbsent('$sensorId-$key', () => {'max': 0.0, 'min': double.infinity});

    final current = _maxAndMinValues['$sensorId-$key'];
    if (current == null) return;

    if (value > current['max']!) _maxAndMinValues['$sensorId-$key']!['max'] = value;
    if (value < current['min']!) _maxAndMinValues['$sensorId-$key']!['min'] = value;
  }

  // Funzione principale di query: chiama il servizio, gestisce casi speciali (0/1 risultati),
  // ordina per timestamp, raggruppa per sensore e decide quale grafico mostrare in base ai parametri selezionati.
  Future<void> submitQuery() async {
    clearResults();
    isLoading = true;
    _hasShownBottomSheet = false;
    errorMessage = null;
    hasSubmitted = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> results =
      await MachinePastService.searchData(
        accessToken: _accessToken!,
        machineId: selectedMachine,
        parameter: selectedParameter,
        aggregation: selectedAggregation,
        startTime: startDate,
        endTime: endDate,
        limit: limit,
      ).then((r) => r.cast<Map<String, dynamic>>());

      showPieChart = false;
      showLinearChart = false;
      showBarChart = false;

      if (results.isEmpty) throw Exception('No data found');

      // Caso particolare: un solo record → lo mostriamo “testuale” escludendo i campi identificativi
      if (results.length == 1) {
        final item = results.first;
        final buffer = StringBuffer('');

        for (var entry in item.entries) {
          final key = entry.key;
          final value = entry.value;
          if (value != null &&
              key != 'source_id' &&
              key != 'sensor_id' &&
              key != 'machine_id') {
            buffer.writeln('  $key: $value');
          }
        }

        objectSidedAlone = buffer.toString();
        notifyListeners();
        return;
      }

      // Se presente timestamp, ordiniamo per costruire serie temporali coerenti (grafico lineare)
      if (results.first['timestamp'] != null) {
        results.sort((a, b) =>
            (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));
      }

      // Raggruppamento per sensore (source_id normalizzato) + conteggio elementi per pie chart.
      // Se non c'è aggregazione, calcoliamo anche min/max per ogni chiave numerica (per range e tooltip).
      for (var item in results) {
        final sid = item['source_id'].split('/').last.split('_').join(" ").toString();

        sensorIdCounts[sid] = (sensorIdCounts[sid] ?? 0) + 1;
        groupedResults.putIfAbsent(sid, () => []).add(item);

        if (selectedAggregation == null) {
          for (var key in item.keys) {
            if (key != 'sensor_id' &&
                key != 'source_id' &&
                key != 'machine_id' &&
                key != 'timestamp') {
              final value = (item[key] as num?)?.toDouble();
              if (value != null) _updateMaxAndMin(sid, key, value);
            }
          }
        }
      }

      // Scelta grafico:
      // - Pie chart solo se ci sono più macchine e non c'è aggregazione (mostra distribuzione per sensore)
      // - Linear chart quando non c'è aggregazione (serie temporale)
      // - Bar chart quando c'è aggregazione (confronto valori aggregati)
      if (selectedMachine.length != 1 && selectedAggregation == null) {
        showPieChart = true;
      }
      if (selectedAggregation == null) {
        showLinearChart = true;
      } else {
        showBarChart = true;
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void toggleSearchMethod(bool value) {
    searchChooser = value;
    startDate = null;
    endDate = null;
    limit = null;
    selectedParameter = null;
    selectedAggregation = null;
    limitController.clear();
    startController.clear();
    endController.clear();
    clearResults();
    notifyListeners();
  }

  void toggleManualDateEntry(bool value) {
    manualDateEntry = value;
    startDate = null;
    endDate = null;
    startController.clear();
    endController.clear();
    startDateValidation = null;
    endDateValidation = null;
    notifyListeners();
  }

  void setSingleMachine(String machineId) {
    selectedMachine = [machineId];
    machineValidationMessage = null;
    notifyListeners();
  }

  void setStartDate(DateTime date) {
    startDate = _formatDate(date);
    startController.text = startDate!;
    notifyListeners();
  }

  void setEndDate(DateTime date) {
    endDate = _formatDate(date);
    endController.text = endDate!;
    notifyListeners();
  }

  String _formatDate(DateTime date) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return formatter.format(date);
  }

  void setLimit(int? value) {
    limit = value;
    if (value == null) {
      limitController.clear();
    }
    notifyListeners();
  }

  void setParameter(String? value) {
    selectedParameter = value;
    parameterValidationMessage = null;
    if (value != null) {
      aggregationValidationMessage = null;
    }
    notifyListeners();
  }

  void setAggregation(String? aggregation) {
    selectedAggregation = aggregation;
    notifyListeners();
  }

  void showAggregationError() {
    aggregationValidationMessage = 'Parameter is needed!';
    notifyListeners();
  }

  void showMachineError() {
    machineValidationMessage = 'Machine is needed!';
    notifyListeners();
  }

  void showParameterError() {
    parameterValidationMessage = 'Parameter is needed!';
    notifyListeners();
  }

  // Validazione input data inserita manualmente:
  // completa automaticamente parti mancanti (es. solo data o solo HH o HH:mm) e poi fa parseStrict.
  // Aggiorna messaggio e colore di validazione e salva startDate/endDate solo se il formato è corretto.
  void validateDateInput(String input, bool isStart) {
    try {
      final cleaned = _completeDateString(input.trim());
      final parsedDate = DateFormat('yyyy-MM-dd HH:mm:ss').parseStrict(cleaned);

      final formatted = _formatDate(parsedDate);
      if (isStart) {
        startDate = formatted;
        startDateValidation = '✓ Correct pattern';
        startDateValidationColor = Colors.green;
      } else {
        endDate = formatted;
        endDateValidation = '✓ Correct pattern';
        endDateValidationColor = Colors.green;
      }
    } catch (e) {
      if (isStart) {
        startDate = null;
        startDateValidation = '✗ Invalid pattern (yyyy-MM-dd HH:mm[:ss])';
        startDateValidationColor = Colors.red;
      } else {
        endDate = null;
        endDateValidation = '✗ Invalid pattern (yyyy-MM-dd HH:mm[:ss])';
        endDateValidationColor = Colors.red;
      }
      if (input == "") {
        startDateValidation = "";
        endDateValidation = "";
        startDateValidationColor = Colors.green;
        startDateValidationColor = Colors.green;
      }
    }
    notifyListeners();
  }

  // Normalizza l’input data/ora permettendo formati “brevi”:
  // - solo data -> aggiunge 00:00:00
  // - data + HH -> aggiunge :00:00
  // - data + HH:mm -> aggiunge :00
  String _completeDateString(String input) {
    final parts = input.split(' ');
    if (parts.length == 1) return '$input 00:00:00';
    if (parts.length == 2) {
      final t = parts[1].split(':');
      if (t.length == 1) return '${parts[0]} ${t[0]}:00:00';
      if (t.length == 2) return '${parts[0]} ${t[0]}:${t[1]}:00';
      return input;
    }
    throw FormatException('Invalid pattern');
  }

  // dato un sensore (sourceId normalizzato) e una key (fieldPath),
  // cerca la macchina corrispondente e poi il FieldInfo per ricavare unità di misura.
  String? uomSymbolGetter(String? selectedSensorId, String key, List<MachineInfo> machines) {
    final MachineInfo? machine = machines.firstWhere(
          (m) {
        final normalizedSourceId = m.sourceId.split('/').last.replaceAll('_', ' ');
        return normalizedSourceId == selectedSensorId;
      },
      orElse: () => MachineInfo(sourceId: '', location: '', smartObject: '', topic: '', fields: []),
    );

    if (machine!.fields.isEmpty) return "";

    final FieldInfo? field = machine.fields.firstWhere(
          (f) => f.fieldPath == key,
      orElse: () => FieldInfo(
        fieldDescription: '',
        fieldPath: '',
        property: '',
        uomLabel: '',
        uomSymbol: '',
      ),
    );

    return field?.uomSymbol;
  }

  // come sopra, ma restituisce la descrizione del campo.
  String? fieldDescriptionGetter(String? selectedSensorId, String key, List<MachineInfo> machines, ) {
    final MachineInfo? machine = machines.firstWhere(
          (m) {
        final normalizedSourceId = m.sourceId.split('/').last.replaceAll('_', ' ');
        return normalizedSourceId == selectedSensorId;
      },
      orElse: () => MachineInfo(sourceId: '', location: '', smartObject: '', topic: '', fields: []),
    );

    if (machine!.fields.isEmpty) return "";

    final FieldInfo? field = machine.fields.firstWhere(
          (f) => f.fieldPath == key,
      orElse: () => FieldInfo(
        fieldDescription: '',
        fieldPath: '',
        property: '',
        uomLabel: '',
        uomSymbol: '',
      ),
    );

    return field?.fieldDescription;
  }

  void clearResults() {
    sensorIdCounts.clear();
    groupedResults.clear();
    isLoading = false;
    hasSubmitted = false;
    errorMessage = null;
    hasSubmitted = false;
    notifyListeners();
  }

  bool _hasShownBottomSheet = false;

  bool get hasShownBottomSheet => _hasShownBottomSheet;

  void setHasShownBottomSheet(bool value) {
    _hasShownBottomSheet = value;
    notifyListeners();
  }

  void toggleBarChart() {
    showBarChart = !showBarChart;
    notifyListeners();
  }

  void togglePieChart() {
    showPieChart = !showPieChart;
    notifyListeners();
  }

  void toggleLinearChart() {
    showLinearChart = !showLinearChart;
    notifyListeners();
  }

  void clearObjectSidedAlone() {
    objectSidedAlone = null;
    notifyListeners();
  }

  void resetStartDate() {
    startDate = null;
    startDateValidation = null;
    startDateValidationColor = Colors.green;
    startController.clear();
    notifyListeners();
  }

  void resetEndDate() {
    endDate = null;
    endDateValidation = null;
    endDateValidationColor = Colors.green;
    endController.clear();
    notifyListeners();
  }
}