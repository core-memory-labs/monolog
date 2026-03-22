import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/search_result.dart';
import '../providers/providers.dart';
import '../screens/entry_list_screen.dart';
import '../utils/date_format.dart';
import '../utils/markdown_parser.dart';

/// Full-text search screen for entries across all topics.
///
/// Uses FTS5 for fast search with BM25 ranking. The query is debounced
/// (300ms) and sanitised before being sent to the database. Each result
/// shows a content snippet, the topic name, and the date. Tapping a
/// result navigates to the topic feed scrolled to the matching entry.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<SearchResult>? _results;
  bool _isSearching = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Search logic
  // ---------------------------------------------------------------------------

  void _onQueryChanged(String query) {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _results = null;
        _isSearching = false;
        _lastQuery = '';
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    final db = ref.read(databaseServiceProvider);

    try {
      final results = await db.searchEntries(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
          _lastQuery = query;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
          _lastQuery = query;
        });
      }
    }
  }

  void _onResultTap(SearchResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryListScreen(
          topicId: result.topicId,
          topicTitle: result.topicTitle,
          scrollToEntryId: result.entryId,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Поиск по записям…',
            border: InputBorder.none,
          ),
          onChanged: _onQueryChanged,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Очистить',
              onPressed: () {
                _controller.clear();
                _onQueryChanged('');
              },
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // Initial state — no query entered yet.
    if (_results == null && !_isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Начните вводить для поиска',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Loading.
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    // No results.
    if (_results != null && _results!.isEmpty) {
      return Center(
        child: Text(
          'Ничего не найдено',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Results list.
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results!.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _results![index];
        return _SearchResultTile(
          result: result,
          query: _lastQuery,
          onTap: () => _onResultTap(result),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Search result tile
// -----------------------------------------------------------------------------

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final String query;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.result,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Strip markdown markers for cleaner snippet display.
    final plainContent = stripMarkdown(result.content);
    final snippet = plainContent.length > 150
        ? '${plainContent.substring(0, 150)}…'
        : plainContent;

    final dateLabel = formatRelativeDate(result.createdAt);

    return ListTile(
      onTap: onTap,
      title: Text(
        result.topicTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            snippet.isEmpty ? '(изображение / файл)' : snippet,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            dateLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
