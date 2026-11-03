import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> recordings;
  final void Function(Map<String, dynamic>) onOpenResult;

  const SearchScreen({
    super.key,
    required this.recordings,
    required this.onOpenResult,
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

  List<Map<String, dynamic>> get _results {
    if (_query.isEmpty) return widget.recordings;
    final q = _query.toLowerCase();
    return widget.recordings.where((r) {
      final text = ((r['transcript'] as Map)['text'] ?? '').toString().toLowerCase();
      return text.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
                hintText: 'Tìm trong bản ghi...',
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
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('Chưa có bản ghi để tìm',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            )
          else if (results.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('Không tìm thấy kết quả cho "$_query"',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final r = results[i];
                  final transcript = r['transcript'] as Map<String, dynamic>;
                  final text = (transcript['text'] ?? '').toString();
                  final date = r['date'] as DateTime;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.audio_file, color: Colors.indigo),
                      title: Text(
                        _highlight(text, _query),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${date.day}/${date.month}/${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => widget.onOpenResult(r),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _highlight(String text, String query) {
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return text.length > 80 ? '${text.substring(0, 80)}...' : text;
    }
    final idx = text.toLowerCase().indexOf(query.toLowerCase());
    final start = (idx - 20).clamp(0, text.length);
    final end = (idx + query.length + 20).clamp(0, text.length);
    return '...${text.substring(start, end)}...';
  }
}
