Future<void> downloadCSV(String filename, String content) async {
  throw UnsupportedError("Download CSV is not supported on this platform.");
}

Future<void> downloadPDF(String filename, List<int> bytes) async {
  throw UnsupportedError("Download PDF is not supported on this platform.");
}

Future<void> downloadFile(String filename, String url) async {
  throw UnsupportedError("File downloads are not supported on this platform.");
}

Future<String?> downloadFileWithProgress({
  required String filename,
  required String url,
  void Function(int received, int total)? onProgress,
  bool Function()? shouldCancel,
}) async {
  throw UnsupportedError("File downloads are not supported on this platform.");
}

Future<void> openDownloadedFile(String path, {String? fallbackUrl}) async {
  throw UnsupportedError("Opening downloaded files is not supported on this platform.");
}
