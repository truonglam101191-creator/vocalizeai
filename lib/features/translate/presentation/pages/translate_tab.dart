import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import '../../../../core/widgets/base_card.dart';
import '../../../../core/widgets/base_button.dart';
import '../controllers/translate_controller.dart';
import '../../../tts/presentation/controllers/tts_controller.dart';
import '../../../../core/l10n/locale_controller.dart';

class TranslateTab extends ConsumerWidget {
  const TranslateTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateControllerProvider);
    final controller = ref.read(translateControllerProvider.notifier);
    final inputCtrl = ref.watch(translateInputProvider);
    final l10n = ref.watch(l10nProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Expanded(
                    child: BaseCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: state.fromLang,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E1E2C),
                          style: GoogleFonts.inter(
                              color: Colors.white, fontSize: 14),
                          items: const [
                            DropdownMenuItem(
                                value: 'en', child: Text('🇺🇸 English (EN)')),
                            DropdownMenuItem(
                                value: 'vi',
                                child: Text('🇻🇳 Vietnamese (VI)')),
                            DropdownMenuItem(
                                value: 'fr', child: Text('🇫🇷 French (FR)')),
                            DropdownMenuItem(
                                value: 'es', child: Text('🇪🇸 Spanish (ES)')),
                            DropdownMenuItem(
                                value: 'zh', child: Text('🇨🇳 Chinese (ZH)')),
                          ],
                          onChanged: (val) {
                            if (val != null) controller.setFromLang(val);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white54),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BaseCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: state.toLang,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E1E2C),
                          style: GoogleFonts.inter(
                              color: Colors.white, fontSize: 14),
                          items: const [
                            DropdownMenuItem(
                                value: 'en', child: Text('🇺🇸 English (EN)')),
                            DropdownMenuItem(
                                value: 'vi',
                                child: Text('🇻🇳 Vietnamese (VI)')),
                            DropdownMenuItem(
                                value: 'fr', child: Text('🇫🇷 French (FR)')),
                            DropdownMenuItem(
                                value: 'es', child: Text('🇪🇸 Spanish (ES)')),
                            DropdownMenuItem(
                                value: 'zh', child: Text('🇨🇳 Chinese (ZH)')),
                          ],
                          onChanged: (val) {
                            if (val != null) controller.setToLang(val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              BaseCard(
                padding: const EdgeInsets.all(4),
                child: TextField(
                  controller: inputCtrl,
                  maxLines: 8,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: l10n.get('pasteSrtToTranslate'),
                    hintStyle: const TextStyle(color: Colors.white30),
                    contentPadding: const EdgeInsets.all(20),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.file_upload_rounded,
                          color: Color(0xFF06B6D4)),
                      onPressed: () => controller.pickTextFile(inputCtrl),
                      tooltip: l10n.get('loadFromFile'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              BaseButton(
                text: l10n.get('translateText'),
                icon: Icons.g_translate_rounded,
                isLoading: state.isProcessing,
                onPressed: state.isProcessing
                    ? null
                    : () => controller.runTranslate(inputCtrl.text),
                gradient: const LinearGradient(
                    colors: [Color(0xFF0891B2), Color(0xFF0369A1)]),
              ),
              if (state.error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(state.error,
                    style: const TextStyle(color: Colors.redAccent)),
              ],
              if (state.translatedText.isNotEmpty) ...[
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
                          Text(l10n.get('translatedContent'),
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded,
                                color: Color(0xFF06B6D4), size: 20),
                            tooltip: l10n.get('copyTranslation'),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: state.translatedText));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.get('translationCopied'),
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
                        state.translatedText,
                        style: GoogleFonts.jetBrainsMono(
                            color: Colors.white70, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref.read(ttsInputProvider).text =
                                state.translatedText;
                            DefaultTabController.of(context).animateTo(2);
                          },
                          icon: const Icon(Icons.send_rounded),
                          label: Text(l10n.get('sendToTts'),
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (state.outputFiles.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.folder_copy_rounded,
                        color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.get('savedTranslations'),
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
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
                            tooltip: l10n.get('openFolder'),
                            onPressed: () => controller.openFolder(path),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded,
                                color: Colors.white70, size: 20),
                            tooltip: l10n.get('copyFilePath'),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: path));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.get('pathCopied'),
                                      style: GoogleFonts.inter()),
                                  backgroundColor: const Color(0xFF10B981),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
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
