import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditViewModel extends ChangeNotifier {
  final Map<String, List<String>> machineParamsMap;
  final Map<String, Map<String, Color>> _visibleCharts = {};

  EditViewModel(this.machineParamsMap) {
    _loadPreferences();
  }

  Map<String, Map<String, Color>> get visibleCharts => _visibleCharts;

  bool isChartVisible(String machineId, String param) {
    return _visibleCharts[machineId]?.containsKey(param) ?? false;
  }

  Color getChartColor(String machineId, String param) {
    return _visibleCharts[machineId]?[param] ?? Colors.blue;
  }

  void toggleVisibility(String machineId, String param) {
    final visible = _visibleCharts[machineId];
    if (visible != null) {
      if (visible.containsKey(param)) {
        visible.remove(param);
      } else {
        visible[param] = _generateRandomColor();
      }
      _savePreferences();
      notifyListeners();
    }
  }

  void setChartColor(String machineId, String param, Color color) {
    _visibleCharts[machineId]?[param] = color;
    _savePreferences();
    notifyListeners();
  }

  // Salva le preferenze in SharedPreferences serializzando una mappa del tipo:
  // { machineId: { param: "colorHex" } }
  // dove il colore viene salvato come stringa esadecimale (value.toRadixString(16)).
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> dataToSave = {};

    for (var machine in _visibleCharts.entries) {
      final params = {
        for (var entry in machine.value.entries)
          entry.key: entry.value.value.toRadixString(16),
      };
      dataToSave[machine.key] = params;
    }

    prefs.setString('visibleCharts', jsonEncode(dataToSave));
  }

  // Carica e ricostruisce _visibleCharts da SharedPreferences:
  // - Converte le stringhe esadecimali in Color
  // - Rimuove eventuali macchine presenti nelle preferenze ma non più presenti in machineParamsMap
  // - Assicura che ogni macchina abbia tutti i parametri inizializzati (default = colore random)
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('visibleCharts');

    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      for (final machineId in decoded.keys) {
        // se una macchina salvata non esiste più nella mappa attuale,
        // la ignoriamo e proviamo a rimuoverla dalle preferenze.
        if (!machineParamsMap.containsKey(machineId)) {
          await prefs.remove(machineId);
          continue;
        }

        // Ricostruzione mappa parametri->Color partendo dalle stringhe hex salvate
        final paramMap = <String, Color>{};
        final paramColors = decoded[machineId] as Map<String, dynamic>;
        for (var paramEntry in paramColors.entries) {
          paramMap[paramEntry.key] =
              Color(int.parse(paramEntry.value, radix: 16));
        }
        _visibleCharts[machineId] = paramMap;
      }
    }

    // Inizializzazione default: per ogni macchina attuale garantiamo che esista una mappa
    // (se non era presente nelle preferenze, assegniamo un colore random a ogni parametro).
    for (final machineId in machineParamsMap.keys) {
      _visibleCharts.putIfAbsent(machineId, () {
        return {
          for (var param in machineParamsMap[machineId]!)
            param: _generateRandomColor(),
        };
      });
    }

    await _savePreferences();
    notifyListeners();
  }

  Color _generateRandomColor() {
    final Random random = Random();
    return Color.fromARGB(
      255,
      random.nextInt(200) + 30,
      random.nextInt(200) + 30,
      random.nextInt(200) + 30,
    );
  }
}