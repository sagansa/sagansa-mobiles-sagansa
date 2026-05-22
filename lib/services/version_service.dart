import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

class VersionService {
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      // 1. Dapatkan info versi APK saat ini dari sistem HP
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final int currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 2. Fetch versi terbaru dari API backend
      final response = await http.get(Uri.parse(ApiConstants.appVersion));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final int latestVersionCode = data['version_code'] ?? 0;
        final bool forceUpdate = data['force_update'] ?? false;
        final String downloadUrl = data['download_url'] ?? '';
        final String releaseNotes = data['release_notes'] ?? 'Versi baru tersedia!';

        // 3. Bandingkan versi
        if (latestVersionCode > currentVersionCode) {
          _showUpdateDialog(
            context,
            forceUpdate,
            downloadUrl,
            releaseNotes,
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking app version: $e');
    }
  }

  void _showUpdateDialog(
    BuildContext context,
    bool forceUpdate,
    String downloadUrl,
    String releaseNotes,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate, // Jika force update, user tidak bisa tutup dialog sembarangan
      builder: (BuildContext context) {
        return PopScope(
          canPop: !forceUpdate,
          child: AlertDialog(
            title: const Text('Pembaruan Tersedia'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text(releaseNotes),
                ],
              ),
            ),
            actions: <Widget>[
              if (!forceUpdate)
                TextButton(
                  child: const Text('Nanti'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              TextButton(
                child: const Text('Update Sekarang'),
                onPressed: () async {
                  final Uri url = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    debugPrint('Could not launch $downloadUrl');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
