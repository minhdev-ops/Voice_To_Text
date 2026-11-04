import 'package:flutter/material.dart';

import '../data/recording.dart';

class SearchScreen extends StatefulWidget {
  final List<Recording> recordings;
  final void Function(Recording) onOpenResult;
  final Future<void> Function(Recording) onDelete;

  const SearchScreen({
    super.key,
    required this.recordings,
    required this.onOpenResult,
    required this.onDelete,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Recording> get _filtered {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return widget.recordings;
    return widget.recordings.where((r) {
      return r.title.toLowerCase().contains(q) ||
          r.transcript.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              controller: _controller,
              hintText: 'Tìm trong bản ghi...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
              ],
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (_query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${results.length} kết quả',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: results.isEmpty
                ? _emptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final r = results[index];
                      return _recordingTile(context, r, theme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    if (_query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text('Không tìm thấy kết quả',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              'Thử từ khóa khác hoặc kiểm tra chính tả.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('Tìm kiếm bản ghi', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            'Nhập từ khóa để tìm trong tiêu đề và nội dung.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _recordingTile(BuildContext context, Recording r, ThemeData theme) {
    final preview = r.transcript.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.graphic_eq,
              color: theme.colorScheme.onPrimaryContainer, size: 20),
        ),
        title: _highlight(r.title, theme),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (preview.isNotEmpty)
              Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              _meta(r),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
        isThreeLine: preview.isNotEmpty,
        onTap: () => widget.onOpenResult(r),
        onLongPress: () => _showActions(context, r),
      ),
    );
  }

  Widget _highlight(String text, ThemeData theme) {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return Text(text, style: theme.textTheme.titleSmall);
    final idx = text.toLowerCase().indexOf(q);
    if (idx < 0) return Text(text, style: theme.textTheme.titleSmall);
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: theme.textTheme.titleSmall,
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + q.length),
            style: TextStyle(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(idx + q.length)),
        ],
      ),
    );
  }

  String _meta(Recording r) {
    final d = r.createdAt;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  void _showActions(BuildContext context, Recording r) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Xóa bản ghi',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, r);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Recording r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bản ghi?'),
        content: Text('"undefined" sẽ bị xóa vĩnh viễn, không thể khôi phục.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete(r);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
