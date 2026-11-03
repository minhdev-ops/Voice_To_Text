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

  /// Tim khong dau: go "hop" van tim duoc "họp".
  static String _fold(String s) {
    const map = {
      'a': 'àáảãạăằắẳẵặâầấẩẫậ',
      'e': 'èéẻẽẹêềếểễệ',
      'i': 'ìíỉĩị',
      'o': 'òóỏõọôồốổỗộơờớởỡợ',
      'u': 'ùúủũụưừứửữự',
      'y': 'ỳýỷỹỵ',
      'd': 'đ',
    };
    var out = s.toLowerCase();
    map.forEach((plain, accented) {
      for (final ch in accented.split('')) {
        out = out.replaceAll(ch, plain);
      }
    });
    return out;
  }

  List<Recording> get _results {
    final q = _fold(_query.trim());
    if (q.isEmpty) return widget.recordings;
    return widget.recordings.where((r) {
      return _fold(r.title).contains(q) || _fold(r.transcript).contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc nội dung (không cần dấu)...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (widget.recordings.isEmpty)
            _hint(theme, Icons.mic_none, 'Chưa có bản ghi để tìm')
          else if (results.isEmpty)
            _hint(theme, Icons.search_off, 'Không tìm thấy kết quả cho “$_query”')
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final r = results[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        _snippet(r.transcript, _query),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: false,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => widget.onOpenResult(r),
                      onLongPress: () => _confirmDelete(context, r),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _hint(ThemeData theme, IconData icon, String text) => Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 12),
              Text(text, style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              )),
            ],
          ),
        ),
      );

  String _snippet(String text, String query) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (query.trim().isEmpty) {
      return flat.length > 90 ? '${flat.substring(0, 90)}...' : flat;
    }
    final idx = _fold(flat).indexOf(_fold(query.trim()));
    if (idx < 0) {
      return flat.length > 90 ? '${flat.substring(0, 90)}...' : flat;
    }
    final start = (idx - 30).clamp(0, flat.length);
    final end = (idx + query.length + 40).clamp(0, flat.length);
    return '${start > 0 ? '...' : ''}${flat.substring(start, end)}'
        '${end < flat.length ? '...' : ''}';
  }

  void _confirmDelete(BuildContext context, Recording r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bản ghi?'),
        content: Text('“${r.title}” sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
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
