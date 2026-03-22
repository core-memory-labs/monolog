import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/link_preview_provider.dart';
import '../providers/providers.dart';

/// Displays an OpenGraph link preview card for the given [url].
///
/// Lazily fetches the preview via [linkPreviewProvider]. Shows nothing while
/// loading or if no valid preview is available. Tap opens the URL in the
/// browser. Long press triggers a manual refresh.
class LinkPreviewCard extends ConsumerWidget {
  final String url;

  const LinkPreviewCard({super.key, required this.url});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(linkPreviewProvider(url));

    return previewAsync.when(
      loading: () => _buildLoading(context),
      error: (_, __) => const SizedBox.shrink(),
      data: (preview) {
        if (preview == null || !preview.isValid) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);

        return GestureDetector(
          onTap: () => _openUrl(url),
          onLongPress: () => _refreshPreview(context, ref),
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // OG Image
                if (preview.hasImage)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: Image.file(
                        File(preview.imagePath!),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),

                // Text content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Site name
                      if (preview.siteName != null &&
                          preview.siteName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            preview.siteName!.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                      // Title
                      Text(
                        preview.title!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      // Description
                      if (preview.description != null &&
                          preview.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            preview.description!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Minimal loading placeholder — a thin line to avoid layout jumps.
  Widget _buildLoading(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          minHeight: 2,
          backgroundColor:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _refreshPreview(BuildContext context, WidgetRef ref) async {
    final service = ref.read(linkPreviewServiceProvider);
    await service.refreshPreview(url);
    ref.invalidate(linkPreviewProvider(url));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Превью обновлено'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }
}
