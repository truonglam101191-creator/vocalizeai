class SrtSegment {
  final int index;
  final String startTime;
  final String endTime;
  String text;

  SrtSegment({
    required this.index,
    required this.startTime,
    required this.endTime,
    required this.text,
  });

  static List<SrtSegment> parse(String srtContent) {
    final List<SrtSegment> segments = [];
    final lines = srtContent.replaceAll('\r\n', '\n').split('\n');
    
    int? currentIndex;
    String? currentStart;
    String? currentEnd;
    List<String> currentText = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.isEmpty) {
        if (currentIndex != null && currentStart != null && currentEnd != null) {
          segments.add(SrtSegment(
            index: currentIndex,
            startTime: currentStart,
            endTime: currentEnd,
            text: currentText.join('\n').trim(),
          ));
        }
        currentIndex = null;
        currentStart = null;
        currentEnd = null;
        currentText = [];
        continue;
      }

      if (currentIndex == null && int.tryParse(line) != null) {
        currentIndex = int.parse(line);
      } else if (currentStart == null && line.contains('-->')) {
        final parts = line.split('-->');
        if (parts.length >= 2) {
          currentStart = parts[0].trim();
          currentEnd = parts[1].trim();
        }
      } else {
        currentText.add(line);
      }
    }

    // Add the last one if it doesn't end with an empty line
    if (currentIndex != null && currentStart != null && currentEnd != null) {
      segments.add(SrtSegment(
        index: currentIndex,
        startTime: currentStart,
        endTime: currentEnd,
        text: currentText.join('\n').trim(),
      ));
    }

    return segments;
  }

  static String serialize(List<SrtSegment> segments) {
    final buffer = StringBuffer();
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      buffer.writeln('${i + 1}');
      buffer.writeln('${seg.startTime} --> ${seg.endTime}');
      buffer.writeln(seg.text);
      buffer.writeln(); // Empty line between segments
    }
    return buffer.toString();
  }
}
