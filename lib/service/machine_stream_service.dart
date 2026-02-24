import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../viewmodel/rt_viewmodel.dart';

class MachineStreamService {
  final String id;
  final String baseUrl = 'http://192.168.104.78:5001/monitoring?source_id=';
  final String? accessToken;
  final StreamController<Map<String, dynamic>> _controller =
  StreamController<Map<String, dynamic>>.broadcast();
  bool _running = false;

  MachineStreamService(this.id, this.accessToken) {
    _start();
  }

  Stream<Map<String, dynamic>> get machineStream => _controller.stream;

  // Avvia uno stream continuo (stile SSE): i messaggi utili arrivano come righe
  // prefissate da "data:" contenenti JSON.
  void _start() async {
    if (_running) return;
    _running = true;

    final client = http.Client();
    final url = '$baseUrl$id';
    final request = http.Request('GET', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $accessToken';
    final streamedResponse = await client.send(request);

    try {
      await for (var line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {

        // Stop condition: interrompe lettura se disabilitato globalmente o via shutdown().
        if (!RTViewModel.streamingEnabled || !_running) {
          break;
        }

        line = line.trim();

        // Ignoriamo righe che non contengono dati.
        if (!line.startsWith('data:')) {
          continue;
        }

        final jsonString = line.replaceFirst('data:', '').trim();

        try {
          final json = jsonDecode(jsonString);

          // Se il server invia un payload con chiave "error", lo propaghiamo come errore.
          if (json is Map<String, dynamic> && json.containsKey('error')) {
            throw Exception('Error stream: ${json['error']}');
          }

          _controller.add(Map<String, dynamic>.from(json));
        } catch (e) {
          _controller.addError('Error parsing stream: $e');
        }
      }
    } catch (e) {
      _controller.addError('Error reading stream: $e');
    } finally {
      client.close();
    }
  }

  // Arresta lo stream: il ciclo in _start() controlla _running e termina.
  void shutdown() {
    _running = false;
  }
}