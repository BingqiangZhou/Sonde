import 'package:share_plus/share_plus.dart';

/// Adaptive share service that provides platform-aware sharing.
///
/// Uses share_plus which automatically calls the native share sheet:
/// - iOS: UIActivityViewController (circular icons, horizontal layout)
/// - Android: Intent Chooser (list layout)
class AdaptiveShare {
  AdaptiveShare._();

  /// Share plain text content.
  static Future<void> shareText(
    String text, {
    String? subject,
  }) {
    return SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
  }

  /// Share a podcast episode.
  static Future<void> shareEpisode({
    required String title,
    required String url,
    String? podcastName,
    String? description,
  }) {
    final buffer = StringBuffer();

    if (podcastName != null) {
      buffer.writeln(podcastName);
    }

    buffer.writeln(title);
    buffer.writeln(url);

    if (description != null && description.isNotEmpty) {
      buffer.writeln();
      buffer.write(description);
    }

    return SharePlus.instance.share(
      ShareParams(text: buffer.toString().trim(), subject: title),
    );
  }

  /// Share a podcast/show.
  static Future<void> sharePodcast({
    required String name,
    required String url,
    String? description,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(name);
    buffer.writeln(url);

    if (description != null && description.isNotEmpty) {
      buffer.writeln();
      buffer.write(description);
    }

    return SharePlus.instance.share(
      ShareParams(text: buffer.toString().trim(), subject: name),
    );
  }
}
