import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/animated_background.dart';
import '../controllers/model_manager_controller.dart';
import '../../domain/models/ai_model.dart';
import '../../../../core/l10n/locale_controller.dart';

class ModelManagerScreen extends ConsumerWidget {
  const ModelManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsState = ref.watch(modelManagerProvider);
    final statusState = ref.watch(backendStatusProvider);
    final l10n = ref.watch(l10nProvider);

    String statusText = '';
    double progress = 0.0;
    if (statusState.hasValue) {
      final status = statusState.value!;
      if (status['phase'] != 'idle' && status['phase'] != 'ready') {
        statusText = status['detail'] ?? '';
        progress = (status['progress'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.get('modelManager'),
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () =>
                ref.read(modelManagerProvider.notifier).refreshModels(),
          )
        ],
      ),
      extendBodyBehindAppBar: true,
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              if (statusText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(statusText,
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            color: const Color(0xFF06B6D4),
                            backgroundColor: Colors.white24,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: modelsState.when(
                  data: (data) => _buildLists(context, ref, data, l10n),
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF06B6D4))),
                  error: (err, stack) => Center(
                      child: Text('Error: $err',
                          style: const TextStyle(color: Colors.redAccent))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLists(BuildContext context, WidgetRef ref,
      Map<String, List<AiModel>> data, dynamic l10n) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              indicatorColor: const Color(0xFF06B6D4),
              labelColor: Colors.white,
              indicatorSize: TabBarIndicatorSize.tab,
              unselectedLabelColor: Colors.white54,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
              indicator: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              tabs: [
                Tab(text: l10n.get('whisperStt')),
                Tab(text: l10n.get('piperTts')),
              ],
              dividerHeight: 0,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildModelList(ref, data['whisper'] ?? [], l10n),
                _buildModelList(ref, data['tts'] ?? [], l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelList(WidgetRef ref, List<AiModel> models, dynamic l10n) {
    if (models.isEmpty) {
      return Center(
          child: Text(l10n.get('noModelsAvailable'),
              style: GoogleFonts.inter(color: Colors.white54)));
    }

    final downloading = ref.watch(downloadingModelsProvider);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: models.length,
      itemBuilder: (context, index) {
        final model = models[index];
        final isDownloading = downloading.contains(model.name);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Text(model.name,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            subtitle: Text(model.language ?? l10n.get('multilingual'),
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
            trailing: model.downloaded
                ? IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    tooltip: l10n.get('deleteModelTooltip'),
                    onPressed: () =>
                        _showDeleteConfirm(context, ref, model, l10n),
                  )
                : isDownloading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Color(0xFF06B6D4), strokeWidth: 2))
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(l10n.get('download')),
                        onPressed: () => ref
                            .read(modelManagerProvider.notifier)
                            .downloadModel(model.name, model.type),
                      ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(
      BuildContext context, WidgetRef ref, AiModel model, dynamic l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(l10n.get('deleteModelConfirmTitle'),
            style: GoogleFonts.outfit(color: Colors.white)),
        content: Text(
            l10n
                .get('deleteModelConfirmBody')
                .replaceAll('{modelName}', model.name),
            style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel'),
                style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(modelManagerProvider.notifier)
                  .deleteModel(model.name, model.type);
            },
            child: Text(l10n.get('delete'),
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
