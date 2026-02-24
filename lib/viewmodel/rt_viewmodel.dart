import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/machineinfo.dart';
import '../service/machine_stream_service.dart';

class RTViewModel extends ChangeNotifier {
  final String topic;
  final String location;
  final String smartObject;
  final String sensorId;
  final List<FieldInfo> fields;
  late MachineStreamService _service;
  static bool streamingEnabled = true;

  late final Map<String, FieldInfo> specGetter;

  final List<MapEntry<Map<String, dynamic>, DateTime>> _machineList = [];
  final Map<String, Map<String, double>> _maxAndMinValues = {};

  List<MapEntry<Map<String, dynamic>, DateTime>> get machineList => _machineList;
  Map<String, Map<String, double>> get maxAndMinValues => _maxAndMinValues;

  Map<String, bool> _visibleChartMap = {};
  Map<String, bool> get visibleChartMap => _visibleChartMap;

  Map<String, Color> _chartColors = {};
  Map<String, Color> get chartColors => _chartColors;

  VoidCallback? onFirstData;
  bool _firstDataReceived = false;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  bool _streamActive = false;
  bool get streamActive => _streamActive;

  final String accessToken;

  RTViewModel(this.topic, this.location, this.smartObject, this.sensorId, this.fields, this.accessToken) {
    _service = MachineStreamService(sensorId, accessToken);
    specGetter = {
      for (final f in fields) f.fieldPath: f,
    };
  }

  void loadPreferences() {
    loadVisibilityPreferences();
  }

  void _updateMinMax(String key, double value) {
    _maxAndMinValues.putIfAbsent(key, () => {'min': double.infinity, 'max': 0.0});
    if (value > _maxAndMinValues[key]!['max']!) _maxAndMinValues[key]!['max'] = value;
    if (value < _maxAndMinValues[key]!['min']!) _maxAndMinValues[key]!['min'] = value;
  }

  // Si sottoscrive allo stream realtime e aggiorna lo stato:
  // - mantiene un buffer limitato degli ultimi campioni (per non far crescere la memoria)
  // - aggiorna min/max per ogni chiave numerica
  // - al primo dato ricevuto inizializza preferenze (grafici visibili + colori)
  void startStream() {
    if (!streamingEnabled || _subscription != null) return;

    _service = MachineStreamService(sensorId, accessToken);
    _streamActive = true;

    _subscription = _service.machineStream.listen((data) {
      final timestamp = DateTime.now().toUtc().add(const Duration(hours: 2));
      _machineList.add(MapEntry(data, timestamp));

      const maxLength = 12;
      if (_machineList.length > maxLength) {
        _machineList.removeAt(0);
      }

      for (final entry in data.entries) {
        final value = entry.value;
        if (value is num) {
          _updateMinMax(entry.key, value.toDouble());
        }
      }

      if (!_firstDataReceived) {
        _firstDataReceived = true;
        loadVisibilityPreferences();
        onFirstData?.call();
      }

      notifyListeners();
    },
        onDone: () {
          _subscription = null;
        },
        cancelOnError: true);
  }

  void stopStream() {
    _subscription?.cancel();
    _subscription = null;
    _streamActive = false;
  }

  Set<String> getAllAvailableKeys() {
    final latest = _machineList.isNotEmpty ? _machineList.last.key : {};
    return latest.keys.whereType<String>().toSet();
  }

  // Carica preferenze da SharedPreferences per questo sensore (sensorId).
  // Se non esistono preferenze per questo sensore, inizializza usando le chiavi del primo payload ricevuto.
  Future<void> loadVisibilityPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('visibleCharts');
    _visibleChartMap.clear();
    _chartColors.clear();

    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final machineMap = decoded[sensorId] as Map<String, dynamic>?;

      if (machineMap != null) {
        for (var entry in machineMap.entries) {
          final key = entry.key;
          final colorHex = entry.value as String;
          _visibleChartMap[key] = true;
          _chartColors[key] = Color(int.parse(colorHex, radix: 16));
        }
      } else {
        _initializeFromFirstData(prefs, decoded);
      }
    } else {
      _initializeFromFirstData(prefs, {});
    }

    notifyListeners();
  }

  // Prima inizializzazione: crea una configurazione di default (tutti i campi visibili),
  // assegna un colore random a ogni chiave e salva subito la struttura in SharedPreferences.
  void _initializeFromFirstData(SharedPreferences prefs, Map<String, dynamic> existingData) {
    if (_machineList.isEmpty) return;

    final latest = _machineList.last.key;
    final keys = latest.keys.where((k) => k != 'machine_id');

    final machineMap = <String, String>{};
    for (final key in keys) {
      final color = _generateRandomColor();
      _visibleChartMap[key] = true;
      _chartColors[key] = color;
      machineMap[key] = color.value.toRadixString(16);
    }

    existingData[sensorId] = machineMap;
    prefs.setString('visibleCharts', jsonEncode(existingData));
  }

  Color _generateRandomColor() {
    final random = Random();
    return Color.fromARGB(
      255,
      random.nextInt(200) + 30,
      random.nextInt(200) + 30,
      random.nextInt(200) + 30,
    );
  }

  void refreshUI() {
    notifyListeners();
  }

}