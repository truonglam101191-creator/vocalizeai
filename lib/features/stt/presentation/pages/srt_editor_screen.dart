import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../domain/models/srt_segment.dart';
import '../../../../core/widgets/animated_background.dart';
import '../controllers/stt_controller.dart';

class SrtEditorScreen extends ConsumerStatefulWidget {
  final String filePath;

  const SrtEditorScreen({super.key, required this.filePath});

  @override
  ConsumerState<SrtEditorScreen> createState() => _SrtEditorScreenState();
}

class _SrtEditorScreenState extends ConsumerState<SrtEditorScreen> {
  List<SrtSegment> _segments = [];
  bool _isModified = false;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to safely read state after init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(sttControllerProvider);
      final srtContent = state.outputs[widget.filePath] ?? '';
      setState(() {
        _segments = SrtSegment.parse(srtContent);
      });
    });
  }

  void _saveAndClose() {
    final updatedContent = SrtSegment.serialize(_segments);
    ref.read(sttControllerProvider.notifier).updateOutput(widget.filePath, updatedContent);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SRT Editor', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(p.basename(widget.filePath), style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            if (_isModified) {
              _showDiscardDialog();
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveAndClose,
            icon: const Icon(Icons.save_rounded, color: Color(0xFF06B6D4), size: 20),
            label: Text('Save', style: GoogleFonts.inter(color: const Color(0xFF06B6D4), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: _segments.isEmpty 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _segments.length,
                itemBuilder: (context, index) {
                  final seg = _segments[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(seg.index.toString(), style: GoogleFonts.jetBrainsMono(color: const Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(seg.startTime, style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 12)),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Icon(Icons.arrow_forward_rounded, color: Colors.white30, size: 14),
                                    ),
                                    Text(seg.endTime, style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: seg.text,
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                                  maxLines: null,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) {
                                    seg.text = val;
                                    _isModified = true;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text('Discard Changes?', style: GoogleFonts.outfit(color: Colors.white)),
        content: Text('You have unsaved changes. Do you want to save them before leaving?', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              context.pop(); // Close screen
            },
            child: const Text('Discard', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _saveAndClose(); // Save and close screen
            },
            child: const Text('Save', style: TextStyle(color: const Color(0xFF06B6D4))),
          ),
        ],
      ),
    );
  }
}
