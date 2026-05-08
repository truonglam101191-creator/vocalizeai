import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/widgets/base_card.dart';
import '../../../../core/widgets/base_button.dart';
import '../controllers/tts_controller.dart';
import '../../../../core/l10n/locale_controller.dart';

class TtsTab extends ConsumerStatefulWidget {
  const TtsTab({super.key});

  @override
  ConsumerState<TtsTab> createState() => _TtsTabState();
}

class _TtsTabState extends ConsumerState<TtsTab> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackRate = 1.0;

  @override
  void initState() {
    super.initState();
    final player = ref.read(audioPlayerProvider);
    player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _isPlaying = false;
        });
      }
    });
  }

  void _seekBackward(AudioPlayer player) {
    final newPos = _position - const Duration(seconds: 10);
    player.seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  void _seekForward(AudioPlayer player) {
    final newPos = _position + const Duration(seconds: 10);
    player.seek(newPos > _duration ? _duration : newPos);
  }

  void _changeSpeed(AudioPlayer player) {
    setState(() {
      if (_playbackRate == 1.0)
        _playbackRate = 1.25;
      else if (_playbackRate == 1.25)
        _playbackRate = 1.5;
      else if (_playbackRate == 1.5)
        _playbackRate = 2.0;
      else
        _playbackRate = 1.0;
    });
    player.setPlaybackRate(_playbackRate);
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ttsControllerProvider);
    final controller = ref.read(ttsControllerProvider.notifier);
    final textCtrl = ref.watch(ttsInputProvider);
    final player = ref.watch(audioPlayerProvider);
    final l10n = ref.watch(l10nProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              BaseCard(
                padding: const EdgeInsets.all(4),
                child: Stack(
                  children: [
                    TextField(
                      controller: textCtrl,
                      maxLines: 6,
                      style:
                          GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: l10n.get('pasteTranslatedSrt'),
                        hintStyle: const TextStyle(color: Colors.white30),
                        contentPadding: const EdgeInsets.only(
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
                        tooltip: l10n.get('copyContent'),
                        onPressed: () {
                          if (textCtrl.text.isNotEmpty) {
                            Clipboard.setData(
                                ClipboardData(text: textCtrl.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.get('copiedToClipboard'),
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
                        tooltip: l10n.get('clearContent'),
                        onPressed: () => textCtrl.clear(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (state.voices.isNotEmpty)
                BaseCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.selectedVoice,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFFF59E0B)),
                      dropdownColor: const Color(0xFF1E1E2C),
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                      onChanged: (v) {
                        if (v != null) controller.setSelectedVoice(v);
                      },
                      items: state.voices.map((v) {
                        return DropdownMenuItem(
                            value: v['id'], child: Text(v['name']!));
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              InkWell(
                onTap: state.isProcessing ? null : () => controller.pickMediaFile(),
                borderRadius: BorderRadius.circular(16),
                child: BaseCard(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Icon(
                        state.selectedMediaFile != null ? Icons.video_file_rounded : Icons.add_photo_alternate_rounded,
                        color: state.selectedMediaFile != null ? const Color(0xFF10B981) : Colors.white54,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.selectedMediaFile != null ? p.basename(state.selectedMediaFile!) : l10n.get('originalMediaOptional'),
                              style: GoogleFonts.inter(
                                color: state.selectedMediaFile != null ? Colors.white : Colors.white54,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              l10n.get('selectOriginalToDub'),
                              style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (state.selectedMediaFile != null && !state.isProcessing)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                          onPressed: () => controller.clearMediaFile(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              BaseButton(
                text: l10n.get('generateAudioTts'),
                icon: Icons.record_voice_over_rounded,
                isLoading: state.isProcessing,
                onPressed: state.isProcessing
                    ? null
                    : () => controller.runTts(textCtrl.text, player),
                gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
              ),
              if (state.outputWavPath != null) ...[
                const SizedBox(height: 24),
                BaseCard(
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
                      Text(l10n.get('studioAudioReady'),
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(p.basename(state.outputWavPath!),
                          style: GoogleFonts.inter(
                              color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 16),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
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
                              player.seek(Duration(seconds: val.toInt())),
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
                          InkWell(
                            onTap: () => _changeSpeed(player),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.05)),
                              child: Text('${_playbackRate}x',
                                  style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.replay_10_rounded,
                                color: Colors.white70, size: 32),
                            onPressed: () => _seekBackward(player),
                          ),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () {
                              if (_isPlaying) {
                                player.pause();
                              } else {
                                if (_position > Duration.zero &&
                                    _position < _duration) {
                                  player.resume();
                                  player.setPlaybackRate(_playbackRate);
                                } else {
                                  player.play(
                                      DeviceFileSource(state.outputWavPath!));
                                  player.setPlaybackRate(_playbackRate);
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: [
                                  Color(0xFF10B981),
                                  Color(0xFF059669)
                                ]),
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFF10B981)
                                          .withOpacity(0.4),
                                      blurRadius: 12,
                                      spreadRadius: 2),
                                ],
                              ),
                              child: Icon(
                                  _isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 36),
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded,
                                color: Colors.white70, size: 32),
                            onPressed: () => _seekForward(player),
                          ),
                          const SizedBox(width: 48),
                        ],
                      )
                    ],
                  ),
                )
              ],
              if (state.outputFiles.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.folder_copy_rounded,
                        color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.get('generatedAudios'),
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
              ]
            ]),
          ),
        ),
        if (state.outputFiles.isNotEmpty)
          SliverPadding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24).copyWith(bottom: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final path = state.outputFiles[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BaseCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.audiotrack_rounded,
                              color: Color(0xFFF59E0B), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.basename(path),
                                    style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14)),
                                Text(path,
                                    style: GoogleFonts.inter(
                                        color: Colors.white30, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.folder_open_rounded,
                                color: Colors.white70, size: 20),
                            tooltip: l10n.get('openFolder'),
                            onPressed: () => controller.openFolder(path),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: state.outputFiles.length,
              ),
            ),
          ),
      ],
    );
  }
}
