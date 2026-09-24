import 'dart:io';

void main() async {
  final urls = [
    'https://github.com/tekartik/sqflite/releases/download/sqflite_common_ffi_web-v0.4.5%2B4/sqflite_sw.js',
    'https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-2.4.6/sqlite3.wasm',
  ];
  final targets = [
    'web/sqflite_sw.js',
    'web/sqlite3.wasm',
  ];

  final client = HttpClient();

  for (int i = 0; i < urls.length; i++) {
    final url = urls[i];
    final target = targets[i];
    print('Downloading $target from $url ...');
    try {
      var uri = Uri.parse(url);
      // Follow redirects manually
      HttpClientRequest req = await client.getUrl(uri);
      HttpClientResponse resp = await req.close();
      // Follow up to 5 redirects
      int redirects = 0;
      while ((resp.statusCode == 301 || resp.statusCode == 302 || resp.statusCode == 307 || resp.statusCode == 308) && redirects < 5) {
        final location = resp.headers.value(HttpHeaders.locationHeader)!;
        uri = uri.resolve(location);
        req = await client.getUrl(uri);
        resp = await req.close();
        redirects++;
      }
      if (resp.statusCode == 200) {
        final file = File(target);
        await file.parent.create(recursive: true);
        await resp.pipe(file.openWrite());
        print('  -> OK (${file.lengthSync()} bytes)');
      } else {
        print('  -> ERROR: HTTP ${resp.statusCode}');
      }
    } catch (e) {
      print('  -> FAILED: $e');
    }
  }

  client.close();
  print('Done!');
}
