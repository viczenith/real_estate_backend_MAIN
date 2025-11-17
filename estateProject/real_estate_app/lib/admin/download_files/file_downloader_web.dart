import 'dart:convert';
import 'dart:html' as html;

Future<void> downloadCSV(String filename, String content) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..style.display = 'none'
    ..download = filename;
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<void> downloadPDF(String filename, List<int> bytes) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..style.display = 'none'
    ..download = filename;
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<void> downloadFile(String filename, String url) async {
  final anchor = html.AnchorElement(href: url)
    ..style.display = 'none'
    ..download = filename;
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}

Future<String?> downloadFileWithProgress({
  required String filename,
  required String url,
  void Function(int received, int total)? onProgress,
  bool Function()? shouldCancel,
}) async {
  if (shouldCancel?.call() == true) {
    return null;
  }
  onProgress?.call(0, 1);
  await downloadFile(filename, url);
  onProgress?.call(1, 1);
  return 'web:$url';
}

Future<void> openDownloadedFile(String path, {String? fallbackUrl}) async {
  final targetUrl = path.startsWith('web:') ? path.substring(4) : (fallbackUrl ?? path);
  if (targetUrl.isEmpty) {
    throw ArgumentError('No URL available to open file');
  }
  html.window.open(targetUrl, '_blank');
}
