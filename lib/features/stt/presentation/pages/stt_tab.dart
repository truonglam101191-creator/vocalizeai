import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:vocalizeai/features/models/presentation/controllers/model_manager_controller.dart';
import '../../../../core/widgets/base_card.dart';
import '../../../../core/widgets/base_button.dart';
import '../controllers/stt_controller.dart';
import '../../../translate/presentation/controllers/translate_controller.dart';
import '../../../../core/l10n/locale_controller.dart';
import 'srt_editor_screen.dart';

class SttTab extends ConsumerWidget {
  const SttTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sttControllerProvider);
    final controller = ref.read(sttControllerProvider.notifier);
    final l10n = ref.watch(l10nProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDropZone(state, controller, l10n),
          const SizedBox(height: 24),
          if (state.selectedFiles.isNotEmpty) ...[
            _buildFileList(state, controller, context, l10n, ref),
            const SizedBox(height: 24),
            BaseButton(
              text: state.isProcessing
                  ? 'Processing Batch...'
                  : 'Extract Text (Batch)',
              icon: Icons.auto_awesome_rounded,
              isLoading: state.isProcessing,
              onPressed: state.isProcessing ? null : controller.runStt,
              gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropZone(state, controller, l10n) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: BaseCard(
        padding: const EdgeInsets.all(0),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: state.isProcessing ? null : controller.pickFile,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                vertical: state.selectedFiles.isNotEmpty ? 24 : 48),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_upload_rounded,
                  size: state.selectedFiles.isNotEmpty ? 32 : 56,
                  color: Colors.white54,
                ),
                const SizedBox(height: 16),
                Text(
                  state.selectedFiles.isNotEmpty
                      ? 'Add more files...'
                      : l10n.get('dropAudio'),
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (state.selectedFiles.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'MP3, WAV, M4A, FLAC',
                    style:
                        GoogleFonts.inter(color: Colors.white30, fontSize: 12),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileList(
      state, controller, BuildContext context, l10n, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: state.selectedFiles.map<Widget>((path) {
        final fileName = p.basename(path);
        final isProcessing = state.currentProcessingFile == path;
        final hasOutput = state.outputs.containsKey(path);
        final hasError = state.errors.containsKey(path);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: BaseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasOutput
                          ? Icons.check_circle_rounded
                          : hasError
                              ? Icons.error_rounded
                              : isProcessing
                                  ? Icons.sync_rounded
                                  : Icons.library_music_rounded,
                      color: hasOutput
                          ? Colors.greenAccent
                          : hasError
                              ? Colors.redAccent
                              : isProcessing
                                  ? const Color(0xFF06B6D4)
                                  : Colors.white54,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          String detailText = '';
                          double progressValue = 0.0;
                          if (isProcessing) {
                            final status = ref.watch(backendStatusProvider);
                            if (status.hasValue &&
                                status.value!['phase'] == 'processing_stt') {
                              detailText = status.value!['detail'] ?? '';
                              progressValue =
                                  (status.value!['progress'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (detailText.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  detailText,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF06B6D4),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ]
                            ],
                          );
                        },
                      ),
                    ),
                    if (isProcessing)
                      Consumer(
                        builder: (context, ref, child) {
                          final status = ref.watch(backendStatusProvider);
                          double progressValue = 0.0;
                          String text = '';
                          if (status.hasValue &&
                              status.value!['phase'] == 'processing_stt') {
                            progressValue = (status.value!['progress'] as num?)
                                    ?.toDouble() ??
                                0.0;
                            text = '${(progressValue * 100).toInt()}%';
                          }
                          return Row(
                            children: [
                              if (text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(text,
                                      style: GoogleFonts.inter(
                                          color: const Color(0xFF06B6D4),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ),
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    value: progressValue > 0
                                        ? progressValue
                                        : null,
                                    strokeWidth: 2,
                                    color: const Color(0xFF06B6D4)),
                              ),
                            ],
                          );
                        },
                      ),
                    if (!state.isProcessing && !hasOutput)
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white54, size: 20),
                        onPressed: () => controller.removeFile(path),
                      ),
                  ],
                ),
                if (hasError) ...[
                  const SizedBox(height: 8),
                  Text(state.errors[path]!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                ],
                if (hasOutput) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            color: Color(0xFF06B6D4), size: 20),
                        tooltip: l10n.get('copySubtitles'),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: state.outputs[path]!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.get('subtitlesCopied'),
                                  style: GoogleFonts.inter()),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    SrtEditorScreen(filePath: path)),
                          );
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: Text('Edit',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.read(translateInputProvider).text =
                              state.outputs[path]!;
                          DefaultTabController.of(context).animateTo(1);
                        },
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text('Translate',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ]
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
