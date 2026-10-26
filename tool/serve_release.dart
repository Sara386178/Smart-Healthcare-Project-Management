import 'dart:io';

import 'package:path/path.dart' as path;

Future<void> main(List<String> args) async {
  final defaultRoot = path.join(
    path.dirname(Platform.script.toFilePath()),
    '..',
    'build',
    'web',
  );
  final root = path.normalize(
    path.absolute(args.length > 1 ? args[1] : defaultRoot),
  );
  if (!await File(path.join(root, 'index.html')).exists()) {
    stderr.writeln(
      'Release files are missing. Run flutter build web --release first.',
    );
    exitCode = 1;
    return;
  }

  final port = args.isEmpty ? 8080 : int.tryParse(args.first);
  if (args.length > 2 || port == null || port < 1024 || port > 65535) {
    stderr.writeln(
      'Usage: dart run tool/serve_release.dart [port from 1024 to 65535] [web build directory]',
    );
    exitCode = 64;
    return;
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Serving HealthPM from $root at http://127.0.0.1:$port/');
  await for (final request in server) {
    if (request.method != 'GET' && request.method != 'HEAD') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      continue;
    }

    final relative = Uri.decodeComponent(
      request.uri.path,
    ).replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    final resolved = path.normalize(
      path.join(root, relative.isEmpty ? 'index.html' : relative),
    );
    if (resolved != root && !path.isWithin(root, resolved)) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      continue;
    }

    final file = File(resolved);
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    request.response.headers.set(
      HttpHeaders.contentTypeHeader,
      _contentType(resolved),
    );
    if (request.method == 'GET') {
      await request.response.addStream(file.openRead());
    }
    await request.response.close();
  }
}

String _contentType(String file) =>
    switch (path.extension(file).toLowerCase()) {
      '.html' => 'text/html; charset=utf-8',
      '.js' => 'text/javascript; charset=utf-8',
      '.json' => 'application/json; charset=utf-8',
      '.wasm' => 'application/wasm',
      '.css' => 'text/css; charset=utf-8',
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.svg' => 'image/svg+xml',
      '.ico' => 'image/x-icon',
      _ => 'application/octet-stream',
    };
