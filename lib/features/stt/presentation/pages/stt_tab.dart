import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import '../../../../core/widgets/base_card.dart';
import '../../../../core/widgets/base_button.dart';
import '../controllers/stt_controller.dart';

class SttTab extends ConsumerWidget {
  const SttTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sttControllerProvider);
    final controller = ref.read(sttControllerProvider.notifier);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: BaseCard(
              padding: const EdgeInsets.all(0),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: state.isProcessing ? null : controller.pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(
                        state.selectedMp3 != null
                            ? Icons.library_music_rounded
                            : Icons.cloud_upload_rounded,
                        size: 56,
                        color: state.selectedMp3 != null
                            ? const Color(0xFF06B6D4)
                            : Colors.white54,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.selectedMp3 != null
                            ? p.basename(state.selectedMp3!)
                            : 'Drop audio here or click to browse',
                        style: GoogleFonts.inter(
                          color: state.selectedMp3 != null
                              ? Colors.white
                              : Colors.white54,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (state.selectedMp3 == null) ...[
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
          BaseButton(
            text: 'Extract Text (STT)',
            icon: Icons.auto_awesome_rounded,
            isLoading: state.isProcessing,
            onPressed: state.selectedMp3 == null || state.isProcessing
                ? null
                : controller.runStt,
            gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
          ),
          if (state.error.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(state.error, style: const TextStyle(color: Colors.redAccent)),
          ],
          if (state.outputText.isNotEmpty) ...[
            const SizedBox(height: 24),
            BaseCard(
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
                          Clipboard.setData(ClipboardData(text: state.outputText));
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
                    state.outputText,
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
