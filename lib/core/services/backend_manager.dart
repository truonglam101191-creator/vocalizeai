import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class BackendManager {
  static Process? _process;
  static const String baseUrl = 'http://127.0.0.1:5055';

  static Future<void> launch() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      if (r.statusCode == 200) return;
    } catch (_) {}

    final execDir = File(Platform.resolvedExecutable).parent.path;

    final List<String> exeCandidates;
    if (Platform.isWindows) {
      exeCandidates = [
        p.join(execDir, 'backend', 'vocalizeai_backend.exe'),
        p.join(execDir, 'data', 'backend', 'vocalizeai_backend.exe'),
        p.join(Directory.current.path, 'backend', 'vocalizeai_backend.exe'),
      ];
    } else {
      exeCandidates = [
        p.join(execDir, '..', 'Resources', 'backend', 'vocalizeai_backend'),
        p.join(execDir, 'backend', 'vocalizeai_backend'),
        p.join(Directory.current.path, 'backend', 'vocalizeai_backend'),
      ];
    }

    for (final c in exeCandidates) {
      final f = File(c);
      if (await f.exists()) {
        _process = await Process.start(c, [], mode: ProcessStartMode.normal);
        _listenProcess();
        return;
      }
    }

    final projectCandidates = <String>[];
    var dir = Directory(execDir);
    for (var i = 0; i < 12; i++) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
        projectCandidates.insert(0, dir.path);
        break;
      }
      dir = dir.parent;
    }
    projectCandidates.add(Directory.current.path);
    if (Platform.isMacOS) {
      projectCandidates.add('/Users/macbook/Desktop/project/AI/vocalizeai');
    }

    for (final projectRoot in projectCandidates) {
      final scriptPath = p.join(projectRoot, 'backend', 'server.py');
      final f = File(scriptPath);
      if (await f.exists()) {
        final backendDir = f.parent.path;

        String python;
        if (Platform.isWindows) {
          final venvPython = p.join(backendDir, 'venv', 'Scripts', 'python.exe');
          python = await File(venvPython).exists() ? venvPython : 'python';
        } else {
          final venvPython = p.join(backendDir, 'venv', 'bin', 'python');
          python = await File(venvPython).exists() ? venvPython : 'python3';
        }

        try {
          _process = await Process.start(python, [scriptPath],
              workingDirectory: backendDir, mode: ProcessStartMode.normal);
          _listenProcess();
          return;
        } catch (_) {
          return;
        }
      }
    }
  }

  static void _listenProcess() {
    _process?.stdout.transform(utf8.decoder).listen((d) => debugPrint('[BE] $d'));
    _process?.stderr.transform(utf8.decoder).listen((d) => debugPrint('[BE:ERR] $d'));
  }

  static Future<bool> waitReady({int timeoutSec = 60}) async {
    final deadline = DateTime.now().add(Duration(seconds: timeoutSec));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final r = await http
            .get(Uri.parse('$baseUrl/health'))
            .timeout(const Duration(seconds: 2));
        if (r.statusCode == 200) return true;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  static Future<void> stop() async {
    try {
      await http.post(Uri.parse('$baseUrl/shutdown')).timeout(const Duration(seconds: 2));
    } catch (_) {}
    _process?.kill();
    _process = null;
    debugPrint('🛑 Backend stopped.');
  }

  static Future<void> restart() async {
    debugPrint('🔄 Restarting backend...');
    await stop();
    await Future.delayed(const Duration(seconds: 1));
    await launch();
  }
}
