import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/link_preview.dart';
import 'providers.dart';

/// Lazily fetches and caches a link preview for the given URL.
///
/// Returns `null` if the URL has no valid preview (fetch failed, no OG tags,
/// or previously marked as failed). The provider is keyed by URL, so each
/// unique link has its own cache entry.
///
/// To manually refresh a preview:
/// ```dart
/// await ref.read(linkPreviewServiceProvider).refreshPreview(url);
/// ref.invalidate(linkPreviewProvider(url));
/// ```
final linkPreviewProvider =
    FutureProvider.family<LinkPreview?, String>((ref, url) async {
  final service = ref.read(linkPreviewServiceProvider);
  return service.getOrFetchPreview(url);
});
