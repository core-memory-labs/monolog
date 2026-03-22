import 'dart:io';
import 'dart:math';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/link_preview.dart';
import 'database_service.dart';

/// Fetches, parses, and caches OpenGraph link previews.
///
/// Uses the [DatabaseService] for persistent cache and stores OG images
/// on disk for full offline access.
class LinkPreviewService {
  final DatabaseService _db;

  /// Directory name for cached OG images (shares with attachments for
  /// simplicity and backward compatibility).
  static const _imagesDirName = 'images';

  static const _htmlTimeout = Duration(seconds: 10);
  static const _imageTimeout = Duration(seconds: 15);
  static const _userAgent = 'Mozilla/5.0 (compatible; Monolog/1.0)';

  LinkPreviewService({required DatabaseService db}) : _db = db;

  /// Returns a cached preview if available, otherwise fetches from network.
  ///
  /// Returns `null` if the fetch failed (or previously failed and was cached
  /// with `title == null`). Only returns previews with [LinkPreview.isValid].
  Future<LinkPreview?> getOrFetchPreview(String url) async {
    // 1. Check DB cache.
    final cached = await _db.getLinkPreview(url);
    if (cached != null) {
      return cached.isValid ? cached : null;
    }

    // 2. Fetch from network.
    return _fetchAndCache(url);
  }

  /// Deletes the cached preview for [url] and re-fetches from network.
  ///
  /// Used for manual refresh (long press on preview card).
  Future<LinkPreview?> refreshPreview(String url) async {
    // Delete old cache entry and its image.
    final existing = await _db.getLinkPreview(url);
    if (existing != null) {
      if (existing.imagePath != null) {
        await _deleteFileIfExists(existing.imagePath!);
      }
      await _db.deleteLinkPreview(url);
    }

    return _fetchAndCache(url);
  }

  // ---------------------------------------------------------------------------
  // Network fetching
  // ---------------------------------------------------------------------------

  Future<LinkPreview?> _fetchAndCache(String url) async {
    try {
      final ogData = await _fetchOgTags(url);

      if (ogData == null || ogData.title == null) {
        // Store a failed-attempt marker so we don't retry on every scroll.
        await _db.insertLinkPreview(
          url: url,
          title: null,
          description: null,
          imageUrl: null,
          imagePath: null,
          siteName: null,
        );
        return null;
      }

      // Download OG image if available.
      String? localImagePath;
      if (ogData.imageUrl != null && ogData.imageUrl!.isNotEmpty) {
        localImagePath = await _downloadImage(ogData.imageUrl!);
      }

      final preview = await _db.insertLinkPreview(
        url: url,
        title: ogData.title,
        description: ogData.description,
        imageUrl: ogData.imageUrl,
        imagePath: localImagePath,
        siteName: ogData.siteName,
      );

      return preview.isValid ? preview : null;
    } catch (e) {
      // Network error, timeout, etc. Store failed marker.
      try {
        await _db.insertLinkPreview(
          url: url,
          title: null,
          description: null,
          imageUrl: null,
          imagePath: null,
          siteName: null,
        );
      } catch (_) {
        // DB error — ignore, we'll retry next time.
      }
      return null;
    }
  }

  /// Fetches the HTML page at [url] and extracts OpenGraph meta tags.
  Future<_OgData?> _fetchOgTags(String url) async {
    final response = await http
        .get(
          Uri.parse(url),
          headers: {'User-Agent': _userAgent},
        )
        .timeout(_htmlTimeout);

    if (response.statusCode != 200) return null;

    // Ensure we got HTML, not a binary file.
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('text/html') &&
        !contentType.contains('application/xhtml')) {
      return null;
    }

    final document = html_parser.parse(response.body);
    final metaTags = document.getElementsByTagName('meta');

    String? ogTitle;
    String? ogDescription;
    String? ogImage;
    String? ogSiteName;
    String? metaDescription;

    for (final meta in metaTags) {
      final property = meta.attributes['property'] ?? '';
      final name = meta.attributes['name'] ?? '';
      final content = meta.attributes['content'] ?? '';

      if (content.isEmpty) continue;

      // OpenGraph tags
      if (property == 'og:title') ogTitle = content;
      if (property == 'og:description') ogDescription = content;
      if (property == 'og:image') ogImage = content;
      if (property == 'og:site_name') ogSiteName = content;

      // Fallback: standard meta description
      if (name == 'description' && metaDescription == null) {
        metaDescription = content;
      }
    }

    // Fallback: page <title>
    final titleElement = document.getElementsByTagName('title');
    final pageTitle =
        titleElement.isNotEmpty ? titleElement.first.text.trim() : null;

    final title = ogTitle ?? pageTitle;
    if (title == null || title.isEmpty) return null;

    // Resolve relative image URL to absolute.
    String? absoluteImageUrl;
    if (ogImage != null && ogImage.isNotEmpty) {
      absoluteImageUrl = _resolveUrl(url, ogImage);
    }

    return _OgData(
      title: title,
      description: ogDescription ?? metaDescription,
      imageUrl: absoluteImageUrl,
      siteName: ogSiteName,
    );
  }

  // ---------------------------------------------------------------------------
  // Image downloading
  // ---------------------------------------------------------------------------

  /// Downloads the image at [imageUrl] and saves it to the app's images
  /// directory. Returns the local file path, or `null` on failure.
  Future<String?> _downloadImage(String imageUrl) async {
    try {
      final response = await http
          .get(
            Uri.parse(imageUrl),
            headers: {'User-Agent': _userAgent},
          )
          .timeout(_imageTimeout);

      if (response.statusCode != 200) return null;

      // Verify it's actually an image.
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.startsWith('image/')) return null;

      // Determine extension from content type.
      final ext = _extensionFromContentType(contentType);

      final dir = await _ensureImagesDir();
      final fileName = _generateFileName(ext);
      final filePath = p.join(dir.path, fileName);

      await File(filePath).writeAsBytes(response.bodyBytes);
      return filePath;
    } catch (e) {
      // Image download failed — not critical, preview can show without image.
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Resolves a potentially relative [imageUrl] against the page [pageUrl].
  static String _resolveUrl(String pageUrl, String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    try {
      final base = Uri.parse(pageUrl);
      return base.resolve(imageUrl).toString();
    } catch (_) {
      return imageUrl;
    }
  }

  static String _extensionFromContentType(String contentType) {
    if (contentType.contains('png')) return '.png';
    if (contentType.contains('gif')) return '.gif';
    if (contentType.contains('webp')) return '.webp';
    if (contentType.contains('svg')) return '.svg';
    return '.jpg'; // default for jpeg and unknown
  }

  Future<Directory> _ensureImagesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _imagesDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _generateFileName(String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'og_${timestamp}_$random$extension';
  }

  Future<void> _deleteFileIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore deletion errors.
    }
  }
}

// ---------------------------------------------------------------------------
// Internal data class for parsed OG tags
// ---------------------------------------------------------------------------

class _OgData {
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  const _OgData({
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });
}
