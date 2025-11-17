import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

Future<void> downloadCSV(String filename, String content) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsString(content);
  OpenFile.open(file.path);
}

Future<void> downloadPDF(String filename, List<int> bytes) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(bytes);
  OpenFile.open(file.path);
}

Future<String?> downloadFileWithProgress({
  required String filename,
  required String url,
  void Function(int received, int total)? onProgress,
  bool Function()? shouldCancel,
}) async {
  final directory = await getTemporaryDirectory();
  final sanitizedName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final file = File('${directory.path}/$sanitizedName');

  final client = http.Client();
  try {
    final request = http.Request('GET', Uri.parse(url));
    final response = await client.send(request);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Failed to download file (status ${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    final sink = file.openWrite();
    int received = 0;

    await for (final chunk in response.stream) {
      if (shouldCancel?.call() == true) {
        await sink.close();
        if (await file.exists()) {
          await file.delete();
        }
        return null;
      }

      received += chunk.length;
      sink.add(chunk);
      onProgress?.call(received, total);
    }

    await sink.close();
    onProgress?.call(total, total);
    return file.path;
  } finally {
    client.close();
  }
}

Future<String?> downloadFile(String filename, String url) {
  return downloadFileWithProgress(filename: filename, url: url);
}

Future<void> openDownloadedFile(String path, {String? fallbackUrl}) async {
  if (path.isEmpty) {
    if (fallbackUrl != null) {
      await downloadFileWithProgress(filename: fallbackUrl.split('/').last, url: fallbackUrl);
      return;
    }
    throw ArgumentError('No path provided to open downloaded file');
  }
  await OpenFile.open(path);
}
