import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class UpdateService {
  static const String githubRepo = 'Homey-Prin22/framework-client';
  static const String githubApiUrl =
      'https://api.github.com/repos/$githubRepo/releases/latest';

  static Future<void> checkForUpdate(BuildContext context) async {
    try {

      final info = await PackageInfo.fromPlatform();
      final localVersion = info.version;

      final resp = await http.get(Uri.parse(githubApiUrl));
      if (resp.statusCode == 404) {
        //It means there are no releases released yet.
        return;
      } else if (resp.statusCode != 200) {
        return;
      }


      final data = jsonDecode(resp.body);
      final remoteVersion = (data['tag_name'] as String).replaceAll('v', '');

      if (_isVersionGreater(remoteVersion, localVersion)) {
        _showUpdateDialog(context, data['assets'], remoteVersion);
      }
    } catch (e) {
      _showError(context, "Errore nel controllo aggiornamento: $e");
    }
  }

  static void _showUpdateDialog(
      BuildContext ctx, List assets, String remoteVersion) {
    final apk = assets.firstWhere(
          (a) => (a['name'] as String).endsWith('.apk'),
      orElse: () => null,
    );

    if (apk == null) {
      _showError(ctx, "No apk file found in the latest release.");
      return;
    }

    final url = apk['browser_download_url'];

    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Update available'),
        content: Text(
            'Newest version: $remoteVersion. Would you like to update?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dCtx).pop();
              await _requestPermissionsAndDownload(ctx, url);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  static Future<void> _requestPermissionsAndDownload(
      BuildContext context, String url) async {
    final status = await Permission.requestInstallPackages.status;

    if (!status.isGranted) {
      final granted = await Permission.requestInstallPackages.request();
      if (!granted.isGranted) {
        _showError(context,
            "No permission");
        return;
      }
    }

    await _downloadAndInstallApk(context, url);
  }

  static Future<void> _downloadAndInstallApk(
      BuildContext context, String url) async {
    double progress = 0.0;
    int total = 0;
    late void Function(void Function()) setStateDialog;
    final navigator = Navigator.of(context);

    final dir = await getExternalStorageDirectory();
    final filePath = '${dir!.path}/update.apk';
    final file = File(filePath);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        return StatefulBuilder(builder: (ctx, setState) {
          setStateDialog = setState;
          return AlertDialog(
            title: const Text('Download Update'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: total > 0 ? progress : null),
                const SizedBox(height: 16),
                Text(total > 0
                    ? ''
                    : 'Downloading...'),
              ],
            ),
          );
        });
      },
    );

    try {
      final client = http.Client();
      final response = await client.get(Uri.parse(url), headers: {
        'User-Agent': 'tirocinio-updater/1.0',
        'Accept': 'application/octet-stream',
      });

      if (response.statusCode != 200) {
        throw Exception("Error HTTP: ${response.statusCode}");
      }

      final bytes = response.bodyBytes;
      total = bytes.length;
      await file.writeAsBytes(bytes);
      progress = 1.0;
      setStateDialog(() {});
      navigator.pop();

      const channel = MethodChannel('tirocinio.updater/install');
      await channel.invokeMethod('installApk', {'filePath': filePath});
    } catch (e) {
      navigator.pop();
      _showError(context, "Error while downloading: $e");
    }
  }

  static void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static bool _isVersionGreater(String remote, String local) {
    List<int> parse(String v) =>
        v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final r = parse(remote), l = parse(local);
    for (int i = 0; i < 3; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }
}
