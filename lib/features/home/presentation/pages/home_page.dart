import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/animated_background.dart';
import '../../../stt/presentation/pages/stt_tab.dart';
import '../../../translate/presentation/pages/translate_tab.dart';
import '../../../tts/presentation/pages/tts_tab.dart';
import '../controllers/home_controller.dart';
import '../../../../core/l10n/locale_controller.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeControllerProvider).initBackend();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isReady = ref.watch(isBackendReadyProvider);
    final controller = ref.read(homeControllerProvider);

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                _buildHeader(controller),
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
                  tabs: [
                    Tab(
                        icon: const Icon(Icons.mic_none_rounded),
                        text: ref.watch(l10nProvider).get('tabStt')),
                    Tab(
                        icon: const Icon(Icons.translate_rounded),
                        text: ref.watch(l10nProvider).get('tabTranslate')),
                    Tab(
                        icon: const Icon(Icons.graphic_eq_rounded),
                        text: ref.watch(l10nProvider).get('tabTts')),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: !isReady
                      ? _buildLoadingState(ref)
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
        ),
      ),
    );
  }

  Widget _buildLoadingState(WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF06B6D4)),
          const SizedBox(height: 20),
          Text(
            ref.watch(l10nProvider).get('startingAiEngine'),
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
          )
        ],
      ),
    );
  }

  Widget _buildHeader(HomeController controller) {
    final l10n = ref.watch(l10nProvider);
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
                    spreadRadius: 2),
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
                    letterSpacing: -0.5),
              ),
              Text(
                l10n.get('offlineMediaPipeline'),
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF06B6D4),
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: Text(
                ref.watch(localeProvider).languageCode == 'en'
                    ? '🇺🇸 EN'
                    : '🇻🇳 VI',
                style: GoogleFonts.inter(
                  color: ref.watch(localeProvider).languageCode == 'en'
                      ? Colors.white
                      : Colors.greenAccent,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              tooltip: l10n.get('switchLanguage'),
              onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: const Icon(Icons.stop_circle_rounded,
                  color: Colors.redAccent),
              tooltip: l10n.get('stopAiServer'),
              onPressed: () => controller.stopBackend(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: const Icon(Icons.restart_alt_rounded, color: Colors.amber),
              tooltip: l10n.get('resetAiServer'),
              onPressed: () => controller.restartBackend(),
            ),
          ),
        ],
      ),
    );
  }
}
