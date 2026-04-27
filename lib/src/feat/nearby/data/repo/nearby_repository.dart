import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:nsd/nsd.dart';
import 'package:path_provider/path_provider.dart';
import 'package:relay_app/pigeons/generated/media_saver.g.dart';

enum NearbyEvent { fileReceived }

class NearbyRepository {
  static const _serviceType = '_relay._tcp';
  static const _headerDelimiter = 10; // \n
  static const _maxHeaderBytes = 1024;
  static const _ackTimeout = Duration(seconds: 30);
  static const _wireProtocolVersion = 1;

  ServerSocket? _server;
  Discovery? _discovery;
  Registration? _registration;
  StreamController<List<Service>>? _ctrl;
  final MediaSaverApi _native = MediaSaverApi();
  void Function()? _listener;
  ServiceListener? _serviceListener;

  final _eventCtrl = StreamController<NearbyEvent>.broadcast();
  Stream<NearbyEvent> get events => _eventCtrl.stream;

  Future<void> startBroadcasting(String myCode) async {
    if (_server != null) {
      return;
    }

    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _registration = await register(
      Service(name: myCode, type: _serviceType, port: _server!.port),
    );

    _server!.listen((sock) {
      unawaited(_handleIncomingSocket(sock));
    });
  }

  Stream<List<Service>> discover() async* {
    await stopDiscoveryScan();
    _discovery = await startDiscovery(_serviceType, autoResolve: true);
    _ctrl = StreamController<List<Service>>.broadcast();
    _listener = () {
      _emitDiscoverySnapshot();
    };
    _serviceListener = (service, status) => _emitDiscoverySnapshot();
    _discovery!.addListener(_listener!);
    _discovery!.addServiceListener(_serviceListener!);
    _listener!();
    yield* _ctrl!.stream;
  }

  Future<bool> sendFile(
    File f,
    Service target, {
    void Function(double progress)? onProgress,
  }) async {
    final resolved = await _resolveForConnection(target);
    final host = resolved.host;
    final port = resolved.port;
    if (host == null || port == null) {
      return false;
    }

    Socket? sock;
    RandomAccessFile? raf;
    try {
      final name = _sanitizeFileName(f.path.split('/').last);
      final totalBytes = await f.length();
      final checksum = await _computeSha256Hex(f);
      final header = jsonEncode({
        'v': _wireProtocolVersion,
        'name': name,
        'size': totalBytes,
        'sha256': checksum,
      });
      final hdr = utf8.encode('$header\n');
      var sentBytes = 0;

      sock = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      sock.add(hdr);
      if (totalBytes == 0) {
        onProgress?.call(1);
      } else {
        raf = await f.open();
        while (true) {
          final chunk = await raf.read(64 * 1024);
          if (chunk.isEmpty) {
            break;
          }
          sock.add(chunk);
          sentBytes += chunk.length;
          onProgress?.call(sentBytes / totalBytes);
        }
      }
      await sock.flush();
      onProgress?.call(1);
      final ack = await sock
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(_ackTimeout, onTimeout: () => 'ERR_TIMEOUT');
      await raf?.close();
      await sock.close();
      return ack == 'OK';
    } catch (_) {
      try {
        await raf?.close();
      } catch (_) {}
      try {
        await sock?.close();
      } catch (_) {}
      return false;
    }
  }

  Future<void> stopDiscoveryScan() async {
    final d = _discovery;
    final l = _listener;
    final sl = _serviceListener;
    if (d != null && sl != null) {
      d.removeServiceListener(sl);
    }
    if (d != null && l != null) {
      d.removeListener(l);
    }
    _listener = null;
    _serviceListener = null;
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

  Future<Service> _resolveForConnection(Service service) async {
    try {
      // nsd docs mention resolving close to connection time on some platforms.
      return await resolve(service);
    } catch (_) {
      return service;
    }
  }

  void _emitDiscoverySnapshot() {
    final ctrl = _ctrl;
    final discovery = _discovery;
    if (ctrl == null || ctrl.isClosed || discovery == null) {
      return;
    }

    final services = List<Service>.from(discovery.services)
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    ctrl.add(services);
  }

  String _sanitizeFileName(String raw) {
    var name = raw.trim();
    if (name.contains('/')) {
      name = name.split('/').last;
    }
    if (name.contains(r'\')) {
      name = name.split(r'\').last;
    }
    name = name.replaceAll(RegExp(r'[\u0000-\u001F]'), '_');
    if (name.isEmpty) {
      name = 'incoming_${DateTime.now().millisecondsSinceEpoch}';
    }
    if (name.length > 180) {
      name = name.substring(0, 180);
    }
    return name;
  }

  String _nextAvailablePath(String dirPath, String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    final hasExt = dotIndex > 0 && dotIndex < fileName.length - 1;
    final stem = hasExt ? fileName.substring(0, dotIndex) : fileName;
    final ext = hasExt ? fileName.substring(dotIndex) : '';

    var candidate = '$dirPath/$fileName';
    var suffix = 1;
    while (File(candidate).existsSync()) {
      candidate = '$dirPath/$stem ($suffix)$ext';
      suffix++;
    }
    return candidate;
  }

  Future<void> _handleIncomingSocket(Socket sock) async {
    IOSink? sink;
    final dir = await getApplicationDocumentsDirectory();
    List<int> headerBuffer = [];
    _IncomingHeader? header;
    var receivedBytes = 0;
    String? savePath;
    var done = false;

    try {
      await for (final chunk in sock) {
        if (done) {
          break;
        }

        List<int> payload = chunk;
        if (header == null) {
          final idx = chunk.indexOf(_headerDelimiter);
          if (idx == -1) {
            headerBuffer.addAll(chunk);
            if (headerBuffer.length > _maxHeaderBytes) {
              await _sendAck(sock, 'ERR_HEADER_TOO_LARGE');
              return;
            }
            continue;
          }

          headerBuffer.addAll(chunk.sublist(0, idx));
          header = _parseIncomingHeader(headerBuffer);
          if (header == null) {
            await _sendAck(sock, 'ERR_BAD_HEADER');
            return;
          }

          savePath = _nextAvailablePath(
            dir.path,
            _sanitizeFileName(header.fileName),
          );
          try {
            sink = File(savePath).openWrite();
          } catch (_) {
            await _sendAck(sock, 'ERR_OPEN_FILE');
            return;
          }

          payload = idx + 1 < chunk.length ? chunk.sublist(idx + 1) : const [];

          if (header.fileSize == 0) {
            await sink.close();
            final computed = await _computeSha256Hex(File(savePath));
            if (computed != header.sha256Hex) {
              try {
                await File(savePath).delete();
              } catch (_) {}
              await _sendAck(sock, 'ERR_HASH');
              return;
            }
            if (!await _saveIncomingFile(savePath, header.fileName)) {
              await _sendAck(sock, 'ERR_SAVE');
              return;
            }
            await _sendAck(sock, 'OK');
            _eventCtrl.add(NearbyEvent.fileReceived);
            done = true;
            return;
          }
        }

        if (payload.isEmpty || sink == null) {
          continue;
        }

        final remaining = header.fileSize - receivedBytes;
        if (remaining <= 0) {
          await _sendAck(sock, 'ERR_EXTRA_DATA');
          return;
        }

        final toWriteLength = payload.length > remaining
            ? remaining
            : payload.length;
        final dataPart = toWriteLength == payload.length
            ? payload
            : payload.sublist(0, toWriteLength);

        sink.add(dataPart);
        receivedBytes += dataPart.length;

        if (payload.length > remaining) {
          await _sendAck(sock, 'ERR_EXTRA_DATA');
          return;
        }

        if (receivedBytes == header.fileSize) {
          final path = savePath;
          if (path == null) {
            await _sendAck(sock, 'ERR_INTERNAL');
            return;
          }
          await sink.close();
          final computed = await _computeSha256Hex(File(path));
          if (computed != header.sha256Hex) {
            try {
              await File(path).delete();
            } catch (_) {}
            await _sendAck(sock, 'ERR_HASH');
            return;
          }

          if (!await _saveIncomingFile(path, header.fileName)) {
            await _sendAck(sock, 'ERR_SAVE');
            return;
          }

          await _sendAck(sock, 'OK');
          _eventCtrl.add(NearbyEvent.fileReceived);
          done = true;
          return;
        }
      }

      if (header == null) {
        await _sendAck(sock, 'ERR_NO_HEADER');
        return;
      }

      if (receivedBytes != header.fileSize) {
        await _sendAck(sock, 'ERR_INCOMPLETE');
      }
    } catch (_) {
      await _sendAck(sock, 'ERR_INTERNAL');
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      await sock.close();
    }
  }

  _IncomingHeader? _parseIncomingHeader(List<int> rawHeader) {
    try {
      final decoded = utf8.decode(rawHeader, allowMalformed: false);
      final obj = jsonDecode(decoded);
      if (obj is! Map<String, dynamic>) {
        return null;
      }
      final name = obj['name'];
      final size = obj['size'];
      final sha = obj['sha256'];
      final version = obj['v'];

      if (version != _wireProtocolVersion) {
        return null;
      }
      if (name is! String || name.trim().isEmpty) {
        return null;
      }
      if (size is! int || size < 0) {
        return null;
      }
      if (sha is! String) {
        return null;
      }
      final normalizedSha = sha.trim().toLowerCase();
      final isValidSha = RegExp(r'^[0-9a-f]{64}$').hasMatch(normalizedSha);
      if (!isValidSha) {
        return null;
      }

      return _IncomingHeader(
        fileName: name,
        fileSize: size,
        sha256Hex: normalizedSha,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _saveIncomingFile(String path, String fileName) async {
    try {
      await _native.saveFile(path, fileName, 'application/octet-stream');
      try {
        await File(path).delete();
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendAck(Socket sock, String message) async {
    try {
      sock.add(utf8.encode('$message\n'));
      await sock.flush();
    } catch (_) {}
  }

  Future<String> _computeSha256Hex(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}

class _IncomingHeader {
  const _IncomingHeader({
    required this.fileName,
    required this.fileSize,
    required this.sha256Hex,
  });

  final String fileName;
  final int fileSize;
  final String sha256Hex;
}
