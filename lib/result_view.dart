import 'package:flutter/material.dart';

/// Hien thi ban chep loi va tom tat co cau truc tra ve tu backend.
class ResultView extends StatelessWidget {
  final Map<String, dynamic> transcript;
  final Map<String, dynamic> summary;

  const ResultView({
    super.key,
    required this.transcript,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bản chép lời', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SelectableText((transcript['text'] ?? '').toString()),
          const SizedBox(height: 24),
          _section(context, 'Tóm tắt chung', (summary['summary'] ?? '').toString()),
          _listSection(context, 'Chủ đề chính', summary['topics']),
          _listSection(context, 'Quyết định đã thống nhất', summary['decisions']),
          _actionSection(context, summary['action_items']),
          _listSection(context, 'Câu hỏi / vướng mắc', summary['open_questions']),
          Text(
            'Phương pháp: ${summary['method']}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, String content) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(content),
          const SizedBox(height: 16),
        ],
      );

  Widget _listSection(BuildContext context, String title, dynamic items) {
    final list = (items as List?)?.map((e) => e.toString()).toList() ?? [];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        ...list.map(
          (e) => ListTile(
            leading: const Icon(Icons.circle, size: 8),
            title: Text(e),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _actionSection(BuildContext context, dynamic items) {
    final list = (items as List?) ?? [];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Việc cần làm', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        ...list.map((it) {
          final m = it as Map;
          final task = (m['task'] ?? '').toString();
          final owner = m['owner'];
          final due = m['due'];
          final meta = [
            if (owner != null) 'Người phụ trách: $owner',
            if (due != null) 'Hạn: $due',
          ].join(' · ');
          return ListTile(
            leading: const Icon(Icons.check_box_outline_blank),
            title: Text(task),
            subtitle: meta.isNotEmpty ? Text(meta) : null,
            contentPadding: EdgeInsets.zero,
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}
