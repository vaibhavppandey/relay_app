import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nsd/nsd.dart';
import 'package:path_provider/path_provider.dart';
import 'package:relay_app/pigeons/generated/media_saver.g.dart';

class NearbyRepository {
  ServerSocket? _server;
  Discovery? _discovery;
  Registration? _registration;
  StreamController<List<Service>>? _ctrl;
  final MediaSaverApi _native = MediaSaverApi();
  void Function()? _listener;

  Future<void> startBroadcasting(String myCode) async {
    if (_server != null) {
      return;
    }

    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _registration = await register(
      Service(name: myCode, type: '_relay._tcp', port: _server!.port),
    );

    _server!.listen((sock) async {
      final dir = await getApplicationDocumentsDirectory();
      List<int> buf = [];
      var hdrRead = false;
      IOSink? sink;
      String? savePath;
      String? name;

      sock.listen(
        (chunk) {
          if (!hdrRead) {
            final idx = chunk.indexOf(10);
            if (idx == -1) {
              buf.addAll(chunk);
              return;
            }

            buf.addAll(chunk.sublist(0, idx));
            name = utf8.decode(buf);
            hdrRead = true;
            savePath = '${dir.path}/$name';
            sink = File(savePath!).openWrite();
            if (idx + 1 < chunk.length) {
              sink?.add(chunk.sublist(idx + 1));
            }
            return;
          }

          sink?.add(chunk);
        },
        onDone: () async {
          await sink?.close();
          final p = savePath;
          final n = name;
          if (p != null && n != null && n.isNotEmpty) {
            await _native.saveFile(p, n, 'application/octet-stream');
            try {
              await File(p).delete();
            } catch (_) {}
          }
          await sock.close();
        },
        onError: (_) async {
          await sink?.close();
          await sock.close();
        },
      );
    });
  }

  Stream<List<Service>> discover() async* {
    await stopDiscoveryScan();
    _discovery = await startDiscovery('_relay._tcp');
    _ctrl = StreamController<List<Service>>();
    _listener = () {
      _ctrl?.add(List<Service>.from(_discovery?.services ?? const []));
    };
    _discovery!.addListener(_listener!);
    _listener!();
    yield* _ctrl!.stream;
  }

  Future<bool> sendFile(File f, Service target) async {
    final host = target.host;
    final port = target.port;
    if (host == null || port == null) {
      return false;
    }

    try {
      final name = f.path.split('/').last;
      final hdr = utf8.encode('$name\n');
      final sock = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      sock.add(hdr);
      await sock.addStream(f.openRead());
      await sock.flush();
      sock.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopDiscoveryScan() async {
    final d = _discovery;
    final l = _listener;
    if (d != null && l != null) {
      d.removeListener(l);
    }
    _listener = null;
    _discovery = null;
    if (d != null) {
      try {
        await stopDiscovery(d);
      } catch (_) {}
    }

    final c = _ctrl;
    _ctrl = null;
    if (c != null && !c.isClosed) {
      await c.close();
    }
  }

  Future<void> stopBroadcasting() async {
    final s = _server;
    _server = null;
    await s?.close();
    final r = _registration;
    _registration = null;
    if (r != null) {
      try {
        await unregister(r);
      } catch (_) {}
    }
  }
}
