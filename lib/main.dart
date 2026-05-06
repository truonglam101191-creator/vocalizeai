import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';

void main() {
  runApp(const VocalizeAIApp());
}

class VocalizeAIApp extends StatelessWidget {
  const VocalizeAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VocalizeAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFF06B6D4),
          surface: Color(0xFF0F0F1A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A14),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const DefaultTabController(
        length: 3,
        child: HomePage(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Backend Process Manager
// ─────────────────────────────────────────────
class BackendManager {
  static Process? _process;
  static const String _baseUrl = 'http://127.0.0.1:5000';

  static Future<void> launch() async {
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      if (r.statusCode == 200) return;
    } catch (_) {}

    final execDir = File(Platform.resolvedExecutable).parent.path;

    // ── Platform-specific binary candidates ──
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

    // ── Fallback: run server.py directly ──
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

        // Detect Python in venv (platform-aware)
        String python;
        if (Platform.isWindows) {
          final venvPython =
              p.join(backendDir, 'venv', 'Scripts', 'python.exe');
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
    _process?.stdout
        .transform(utf8.decoder)
        .listen((d) => debugPrint('[BE] $d'));
    _process?.stderr
        .transform(utf8.decoder)
        .listen((d) => debugPrint('[BE:ERR] $d'));
  }

  static Future<bool> waitReady({int timeoutSec = 60}) async {
    final deadline = DateTime.now().add(Duration(seconds: timeoutSec));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final r = await http
            .get(Uri.parse('$_baseUrl/health'))
            .timeout(const Duration(seconds: 2));
        if (r.statusCode == 200) return true;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  static Future<void> stop() async {
    try {
      await http
          .post(Uri.parse('$_baseUrl/shutdown'))
          .timeout(const Duration(seconds: 2));
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

// ─────────────────────────────────────────────
// Home Page with Animated Background
// ─────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  bool _isBackendReady = false;
  late AnimationController _bgAnimCtrl;

  @override
  void initState() {
    super.initState();
    _bgAnimCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat(reverse: true);
    _initBackend();
  }

  @override
  void dispose() {
    _bgAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _initBackend() async {
    await BackendManager.launch();
    final ready = await BackendManager.waitReady();
    if (mounted) setState(() => _isBackendReady = ready);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0A14),
                  Color(0xFF0D0820),
                  Color(0xFF0A1428)
                ],
              ),
            ),
          ),

          // Floating animated orbs
          AnimatedBuilder(
            animation: _bgAnimCtrl,
            builder: (ctx, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -50 + (_bgAnimCtrl.value * 30),
                    right: -100 - (_bgAnimCtrl.value * 20),
                    child: _buildOrb(
                        const Color(0xFF7C3AED).withOpacity(0.4), 350),
                  ),
                  Positioned(
                    bottom: -100 + (_bgAnimCtrl.value * 40),
                    left: -50 - (_bgAnimCtrl.value * 20),
                    child: _buildOrb(
                        const Color(0xFF0891B2).withOpacity(0.3), 400),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  dividerHeight: 0,
                  tabs: const [
                    Tab(icon: Icon(Icons.mic_none_rounded), text: 'STT'),
                    Tab(icon: Icon(Icons.translate_rounded), text: 'Translate'),
                    Tab(icon: Icon(Icons.graphic_eq_rounded), text: 'TTS'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: !_isBackendReady
                      ? _buildLoadingState()
                      : const TabBarView(
                          physics: BouncingScrollPhysics(),
                          children: [
                            SttTab(),
                            TranslateTab(),
                            TtsTab(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF06B6D4)),
          const SizedBox(height: 20),
          Text(
            'Starting AI Engine...',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
          )
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.graphic_eq, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VocalizeAI',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Offline Media Pipeline',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF06B6D4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.stop_circle_rounded,
                  color: Colors.redAccent),
              tooltip: 'Stop AI Server',
              onPressed: () async {
                setState(() => _isBackendReady = false);
                await BackendManager.stop();
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.restart_alt_rounded, color: Colors.amber),
              tooltip: 'Reset AI Server',
              onPressed: () async {
                setState(() => _isBackendReady = false);
                await BackendManager.restart();
                final ready = await BackendManager.waitReady();
                if (mounted) setState(() => _isBackendReady = ready);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STT Tab
// ─────────────────────────────────────────────
class SttTab extends StatefulWidget {
  const SttTab({super.key});
  @override
  State<SttTab> createState() => _SttTabState();
}

class _SttTabState extends State<SttTab>
    with AutomaticKeepAliveClientMixin<SttTab> {
  @override
  bool get wantKeepAlive => true;

  String? _selectedMp3;
  bool _isProcessing = false;
  String _outputText = "";

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res != null && res.files.single.path != null) {
      setState(() {
        _selectedMp3 = res.files.single.path;
        _outputText = "";
      });
    }
  }

  Future<void> _runStt() async {
    if (_selectedMp3 == null) return;
    setState(() => _isProcessing = true);
    try {
      final req =
          http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:5000/stt'));
      req.files.add(await http.MultipartFile.fromPath('file', _selectedMp3!));
      final res = await req.send().timeout(const Duration(minutes: 30));
      if (res.statusCode == 200) {
        final body = await res.stream.bytesToString();
        final json = jsonDecode(body);
        setState(() => _outputText = json['srt'] ?? '');
      } else {
        setState(() => _outputText = "Error: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => _outputText = "Exception: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: _GlassCard(
              padding: const EdgeInsets.all(0),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _isProcessing ? null : _pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(
                        _selectedMp3 != null
                            ? Icons.library_music_rounded
                            : Icons.cloud_upload_rounded,
                        size: 56,
                        color: _selectedMp3 != null
                            ? const Color(0xFF06B6D4)
                            : Colors.white54,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedMp3 != null
                            ? p.basename(_selectedMp3!)
                            : 'Drop audio here or click to browse',
                        style: GoogleFonts.inter(
                          color: _selectedMp3 != null
                              ? Colors.white
                              : Colors.white54,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_selectedMp3 == null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'MP3, WAV, M4A, FLAC',
                          style: GoogleFonts.inter(
                              color: Colors.white30, fontSize: 12),
                        )
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _AnimatedGradientButton(
            text: 'Extract Text (STT)',
            icon: Icons.auto_awesome_rounded,
            isLoading: _isProcessing,
            onPressed: _selectedMp3 == null || _isProcessing ? null : _runStt,
            gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
          ),
          if (_outputText.isNotEmpty) ...[
            const SizedBox(height: 24),
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.greenAccent, size: 20),
                      const SizedBox(width: 8),
                      Text('Subtitles (SRT)',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            color: Color(0xFF06B6D4), size: 20),
                        tooltip: 'Copy subtitles',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _outputText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Subtitles copied to clipboard!',
                                  style: GoogleFonts.inter()),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    _outputText,
                    style: GoogleFonts.jetBrainsMono(
                        color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Translate Tab
// ─────────────────────────────────────────────
class TranslateTab extends StatefulWidget {
  const TranslateTab({super.key});
  @override
  State<TranslateTab> createState() => _TranslateTabState();
}

class _TranslateTabState extends State<TranslateTab>
    with AutomaticKeepAliveClientMixin<TranslateTab> {
  @override
  bool get wantKeepAlive => true;

  final _inputCtrl = TextEditingController();
  String _fromLang = 'en';
  String _toLang = 'vi';
  bool _isProcessing = false;
  String _translatedText = "";
  List<String> _outputFiles = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${docDir.path}/VocalizeAI/Translations');
      if (await targetDir.exists()) {
        final files = targetDir.listSync().whereType<File>().toList();
        files.sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        if (mounted) {
          setState(() {
            _outputFiles = files.map((f) => f.path).toList();
          });
        }
      }
    } catch (_) {}
  }

  void _openFolder(String filePath) {
    if (Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [File(filePath).parent.path]);
    }
  }

  Future<void> _pickTextFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    if (res != null && res.files.single.path != null) {
      final text = await File(res.files.single.path!).readAsString();
      setState(() => _inputCtrl.text = text);
    }
  }

  Future<void> _runTranslate() async {
    if (_inputCtrl.text.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('http://127.0.0.1:5000/translate'));
      req.fields['text'] = _inputCtrl.text;
      req.fields['from_lang'] = _fromLang;
      req.fields['to_lang'] = _toLang;

      final res = await req.send().timeout(const Duration(minutes: 5));
      final body = await res.stream.bytesToString();
      if (res.statusCode == 200) {
        final json = jsonDecode(body);
        final text = json['translated_text'] ?? '';

        final docDir = await getApplicationDocumentsDirectory();
        final targetDir = Directory('${docDir.path}/VocalizeAI/Translations');
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        final isSrt = _inputCtrl.text.contains('-->');
        final ext = isSrt ? 'srt' : 'txt';
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${targetDir.path}/translation_$timestamp.$ext');
        await file.writeAsString(text);

        setState(() {
          _translatedText = text;
          if (!_outputFiles.contains(file.path)) {
            _outputFiles.insert(0, file.path);
          }
        });
      } else {
        setState(() => _translatedText = "Error: $body");
      }
    } catch (e) {
      setState(() => _translatedText = "Exception: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _fromLang,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E1E2C),
                      style:
                          GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      items: const [
                        DropdownMenuItem(
                            value: 'en', child: Text('English (EN)')),
                        DropdownMenuItem(
                            value: 'vi', child: Text('Vietnamese (VI)')),
                        DropdownMenuItem(
                            value: 'fr', child: Text('French (FR)')),
                        DropdownMenuItem(
                            value: 'es', child: Text('Spanish (ES)')),
                        DropdownMenuItem(
                            value: 'zh', child: Text('Chinese (ZH)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _fromLang = val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white54),
              const SizedBox(width: 16),
              Expanded(
                child: _GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _toLang,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E1E2C),
                      style:
                          GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      items: const [
                        DropdownMenuItem(
                            value: 'en', child: Text('English (EN)')),
                        DropdownMenuItem(
                            value: 'vi', child: Text('Vietnamese (VI)')),
                        DropdownMenuItem(
                            value: 'fr', child: Text('French (FR)')),
                        DropdownMenuItem(
                            value: 'es', child: Text('Spanish (ES)')),
                        DropdownMenuItem(
                            value: 'zh', child: Text('Chinese (ZH)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _toLang = val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _GlassCard(
            padding: const EdgeInsets.all(4),
            child: TextField(
              controller: _inputCtrl,
              maxLines: 8,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Paste SRT or text to translate here...',
                hintStyle: const TextStyle(color: Colors.white30),
                contentPadding: const EdgeInsets.all(20),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.file_upload_rounded,
                      color: Color(0xFF06B6D4)),
                  onPressed: _pickTextFile,
                  tooltip: 'Load from file',
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _AnimatedGradientButton(
            text: 'Translate Text',
            icon: Icons.g_translate_rounded,
            isLoading: _isProcessing,
            onPressed: _isProcessing ? null : _runTranslate,
            gradient: const LinearGradient(
                colors: [Color(0xFF0891B2), Color(0xFF0369A1)]),
          ),
          if (_translatedText.isNotEmpty) ...[
            const SizedBox(height: 24),
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.greenAccent, size: 20),
                      const SizedBox(width: 8),
                      Text('Translated Content',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            color: Color(0xFF06B6D4), size: 20),
                        tooltip: 'Copy translation',
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _translatedText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Translation copied to clipboard!',
                                  style: GoogleFonts.inter()),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    _translatedText,
                    style: GoogleFonts.jetBrainsMono(
                        color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
          if (_outputFiles.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.folder_copy_rounded,
                    color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text('Saved Translations',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _outputFiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final path = _outputFiles[index];
                return _GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.description_rounded,
                          color: Color(0xFF06B6D4), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.basename(path),
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14),
                            ),
                            Text(
                              path,
                              style: GoogleFonts.inter(
                                  color: Colors.white30, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_open_rounded,
                            color: Colors.white70, size: 20),
                        tooltip: 'Open folder',
                        onPressed: () => _openFolder(path),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            color: Colors.white70, size: 20),
                        tooltip: 'Copy file path',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: path));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Path copied!',
                                  style: GoogleFonts.inter()),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ]
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TTS Tab
// ─────────────────────────────────────────────
class TtsTab extends StatefulWidget {
  const TtsTab({super.key});
  @override
  State<TtsTab> createState() => _TtsTabState();
}

class _TtsTabState extends State<TtsTab>
    with AutomaticKeepAliveClientMixin<TtsTab> {
  @override
  bool get wantKeepAlive => true;

  final _textCtrl = TextEditingController();
  String? _selectedVoice;
  List<Map<String, String>> _voices = [];
  bool _isProcessing = false;
  String? _outputWavPath;
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  List<String> _outputFiles = [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackRate = 1.0;

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _fetchVoices();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _isPlaying = false;
        });
      }
    });
  }

  void _seekBackward() {
    final newPos = _position - const Duration(seconds: 10);
    _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  void _seekForward() {
    final newPos = _position + const Duration(seconds: 10);
    _player.seek(newPos > _duration ? _duration : newPos);
  }

  void _changeSpeed() {
    setState(() {
      if (_playbackRate == 1.0) {
        _playbackRate = 1.25;
      } else if (_playbackRate == 1.25) {
        _playbackRate = 1.5;
      } else if (_playbackRate == 1.5) {
        _playbackRate = 2.0;
      } else {
        _playbackRate = 1.0;
      }
    });
    _player.setPlaybackRate(_playbackRate);
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<void> _loadFiles() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${docDir.path}/VocalizeAI/TTS');
      if (await targetDir.exists()) {
        final files = targetDir.listSync().whereType<File>().toList();
        files.sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        if (mounted) {
          setState(() {
            _outputFiles = files.map((f) => f.path).toList();
          });
        }
      }
    } catch (_) {}
  }

  void _openFolder(String filePath) {
    if (Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [File(filePath).parent.path]);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _fetchVoices() async {
    try {
      final res = await http.get(Uri.parse('http://127.0.0.1:5000/voices'));
      if (res.statusCode == 200) {
        final vd = jsonDecode(res.body);
        List<Map<String, String>> vlist = [];
        if (vd.containsKey('categories')) {
          final cats = vd['categories'] as Map<String, dynamic>;
          for (var entry in cats.entries) {
            final lang = entry.key;
            final list = entry.value as List;
            for (var v in list) {
              vlist.add(
                  {'id': v['id'].toString(), 'name': '$lang: ${v['name']}'});
            }
          }
          vlist.sort((a, b) => a['name']!.compareTo(b['name']!));
        }
        if (mounted) {
          setState(() {
            _voices = vlist;
            _selectedVoice = vd['default'];
            if (_voices.isNotEmpty &&
                !_voices.any((v) => v['id'] == _selectedVoice)) {
              _selectedVoice = _voices.first['id'];
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _runTts() async {
    if (_textCtrl.text.isEmpty) return;
    setState(() {
      _isProcessing = true;
      _outputWavPath = null;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    _player.stop();
    try {
      final req =
          http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:5000/tts'));
      req.fields['text'] = _textCtrl.text;
      if (_selectedVoice != null) {
        req.fields['tts_voice'] = _selectedVoice!;
      }
      final res = await req.send().timeout(const Duration(minutes: 10));
      if (res.statusCode == 200) {
        final bytes = await res.stream.toBytes();
        final docDir = await getApplicationDocumentsDirectory();
        final targetDir = Directory('${docDir.path}/VocalizeAI/TTS');
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        final outPath = p.join(
            targetDir.path, 'tts_${DateTime.now().millisecondsSinceEpoch}.wav');
        await File(outPath).writeAsBytes(bytes);
        setState(() {
          _outputWavPath = outPath;
          if (!_outputFiles.contains(outPath)) {
            _outputFiles.insert(0, outPath);
          }
        });
      }
    } catch (e) {
      debugPrint("TTS Error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _GlassCard(
            padding: const EdgeInsets.all(4),
            child: Stack(
              children: [
                TextField(
                  controller: _textCtrl,
                  maxLines: 6,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Paste translated SRT or plain text here...',
                    hintStyle: TextStyle(color: Colors.white30),
                    contentPadding: EdgeInsets.only(
                        left: 20, right: 48, top: 20, bottom: 20),
                    border: InputBorder.none,
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        color: Color(0xFF06B6D4), size: 20),
                    tooltip: 'Copy content',
                    onPressed: () {
                      if (_textCtrl.text.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: _textCtrl.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied to clipboard!',
                                style: GoogleFonts.inter()),
                            backgroundColor: const Color(0xFF10B981),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: IconButton(
                    icon: const Icon(Icons.clear_all_rounded,
                        color: Colors.white30, size: 20),
                    tooltip: 'Clear content',
                    onPressed: () {
                      setState(() => _textCtrl.clear());
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_voices.isNotEmpty)
            _GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedVoice,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFFF59E0B)),
                  dropdownColor: const Color(0xFF1E1E2C),
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedVoice = v);
                  },
                  items: _voices.map((v) {
                    return DropdownMenuItem(
                        value: v['id'], child: Text(v['name']!));
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 24),
          _AnimatedGradientButton(
            text: 'Generate Audio (TTS)',
            icon: Icons.record_voice_over_rounded,
            isLoading: _isProcessing,
            onPressed: _isProcessing ? null : _runTts,
            gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
          ),
          if (_outputWavPath != null) ...[
            const SizedBox(height: 24),
            _GlassCard(
              child: Column(
                children: [
                  Icon(
                    _isPlaying
                        ? Icons.multitrack_audio_rounded
                        : Icons.audio_file_rounded,
                    color: const Color(0xFF10B981),
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Studio Audio Ready',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.basename(_outputWavPath!),
                    style:
                        GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: _position.inSeconds.toDouble().clamp(
                          0.0,
                          _duration.inSeconds.toDouble() > 0
                              ? _duration.inSeconds.toDouble()
                              : 1.0),
                      max: _duration.inSeconds.toDouble() > 0
                          ? _duration.inSeconds.toDouble()
                          : 1.0,
                      onChanged: (val) =>
                          _player.seek(Duration(seconds: val.toInt())),
                      activeColor: const Color(0xFF10B981),
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(_position),
                            style: GoogleFonts.jetBrainsMono(
                                color: Colors.white54, fontSize: 12)),
                        Text(_formatDuration(_duration),
                            style: GoogleFonts.jetBrainsMono(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Speed Control
                      InkWell(
                        onTap: _changeSpeed,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                          ),
                          child: Text('${_playbackRate}x',
                              style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Prev 10s
                      IconButton(
                        icon: const Icon(Icons.replay_10_rounded,
                            color: Colors.white70, size: 32),
                        onPressed: _seekBackward,
                      ),
                      const SizedBox(width: 16),
                      // Play/Pause
                      InkWell(
                        onTap: () {
                          if (_isPlaying) {
                            _player.pause();
                          } else {
                            if (_position > Duration.zero &&
                                _position < _duration) {
                              _player.resume();
                              _player.setPlaybackRate(_playbackRate);
                            } else {
                              _player.play(DeviceFileSource(_outputWavPath!));
                              _player.setPlaybackRate(_playbackRate);
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      const Color(0xFF10B981).withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2),
                            ],
                          ),
                          child: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Next 10s
                      IconButton(
                        icon: const Icon(Icons.forward_10_rounded,
                            color: Colors.white70, size: 32),
                        onPressed: _seekForward,
                      ),
                      const SizedBox(width: 16),
                      // Empty placeholder to balance layout
                      const SizedBox(width: 48),
                    ],
                  )
                ],
              ),
            )
          ],
          if (_outputFiles.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.folder_copy_rounded,
                    color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text('Generated Audios',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _outputFiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final path = _outputFiles[index];
                return _GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.audiotrack_rounded,
                          color: Color(0xFFF59E0B), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.basename(path),
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14),
                            ),
                            Text(
                              path,
                              style: GoogleFonts.inter(
                                  color: Colors.white30, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_open_rounded,
                            color: Colors.white70, size: 20),
                        tooltip: 'Open folder',
                        onPressed: () => _openFolder(path),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            color: Colors.white70, size: 20),
                        tooltip: 'Copy file path',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: path));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Path copied!',
                                  style: GoogleFonts.inter()),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ]
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared UI Custom Widgets
// ─────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  const _GlassCard(
      {required this.child, this.padding = const EdgeInsets.all(24)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;

  const _StyledTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.white54, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _AnimatedGradientButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Gradient gradient;

  const _AnimatedGradientButton({
    required this.text,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : gradient,
        color: onPressed == null ? Colors.white.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon,
                          color:
                              onPressed == null ? Colors.white54 : Colors.white,
                          size: 22),
                      const SizedBox(width: 10),
                      Text(
                        text,
                        style: GoogleFonts.inter(
                          color:
                              onPressed == null ? Colors.white54 : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
