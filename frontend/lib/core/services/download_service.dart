import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_html/html.dart' as html;

class DownloadService {
  static Future<void> downloadVideo(String url, String fileName) async {
    if (kIsWeb) {
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
    } else {
      final notificationStatus = await Permission.notification.request();
      final storageStatus = await Permission.storage.request();
      
      // if permission is granted or not permanently denied, proceed
      if (notificationStatus.isGranted || storageStatus.isGranted) {
         Directory? dir;
         if (Platform.isIOS) {
            dir = await getApplicationDocumentsDirectory();
         } else if (Platform.isAndroid) {
            dir = await getExternalStorageDirectory();
         }

         if (dir != null) {
            await FlutterDownloader.enqueue(
               url: url,
               savedDir: dir.path,
               fileName: fileName,
               showNotification: true,
               openFileFromNotification: true,
               saveInPublicStorage: true,
            );
         }
      }
    }
  }
}
