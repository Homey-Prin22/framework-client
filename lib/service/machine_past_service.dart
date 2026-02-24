import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MachinePastService {
  static const String baseUrl = 'http://192.168.104.78:5001/querying';

  // Recupera dati storici per più macchine, gestendo la paginazione con limit/offset
  // e aggregando tutte le pagine in un’unica lista finale.
  static Future<List<Map<String, dynamic>>> searchData({
    required String accessToken,
    required List<String> machineId,
    String? parameter,
    String? aggregation,
    String? startTime,
    String? endTime,
    int? limit,
  }) async {
    final client = http.Client();
    final List<Map<String, dynamic>> allResults = [];

    try {
      for (final id in machineId) {
        int offset = 0;

        while (true) {
          final Map<String, String> queryParams = {
            'source_id': id,
            if (parameter != null) 'param': parameter,
            if (aggregation != null) 'aggr': aggregation,
            if (startTime != null) 'start_time': startTime,
            if (endTime != null) 'stop_time': endTime,
            'limit': (limit ?? 1000).toString(),
            'offset': offset.toString(),
          };

          final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

          try {
            final batchData =
            await fetchData(uri, client, accessToken: accessToken);
            allResults.addAll(batchData);

            // Stop paginazione: se la pagina contiene meno record del limit,
            // significa che non ci sono altre pagine disponibili.
            if (batchData.length < (limit ?? 1000)) break;

            offset += batchData.length;
          } catch (e) {
            break;
          }
        }
      }
    } finally {
      client.close();
    }
    return allResults;
  }

  // GET con retry: ritenta in caso di errore temporaneo e gestisce risposte JSON
  // che possono essere lista (dati) oppure oggetto (es. payload diverso/nessun dato).
  static Future<List<Map<String, dynamic>>> fetchData(
      Uri uri,
      http.Client client, {
        required String accessToken,
        int retries = 3,
      }) async {
    for (int i = 0; i < retries; i++) {
      try {
        final response = await client.get(
          uri,
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);

          if (decoded is List) {
            return decoded.cast<Map<String, dynamic>>();
          } else if (decoded is Map) {
            return [];
          } else {
            throw Exception('Unexpected response: ${response.body}');
          }
        } else {
          final errorJson = jsonDecode(response.body);
          throw Exception(
            'Error ${response.statusCode}: ${errorJson['message'] ?? response.body}',
          );
        }
      } catch (e) {
        // Ultimo tentativo: rilancia l’errore. Altrimenti attende e riprova.
        if (i == retries - 1) rethrow;
        await Future.delayed(Duration(milliseconds: 500));
      }
    }
    return [];
  }
}