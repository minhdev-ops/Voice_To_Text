import 'package:flutter/material.dart';

/// Man hinh chao dau tien, gioi thieu cac tinh nang chinh cua NoteX.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final features = [
      _Feature(
        icon: Icons.mic,
        title: 'Ghi âm & Chép lời',
        desc: 'Chuyển giọng nói thành văn bản theo thời gian thực, nhiều ngôn ngữ.',
      ),
      _Feature(
        icon: Icons.auto_awesome,
        title: 'Tóm tắt thông minh',
        desc: 'Biên bản cuộc họp, việc cần làm và ý chính tức thì.',
      ),
      _Feature(
        icon: Icons.account_tree,
        title: 'Sơ đồ tư duy & Thẻ nhớ',
        desc: 'Trực quan hóa ý tưởng và ôn tập với flashcards.',
      ),
      _Feature(
        icon: Icons.translate,
        title: 'Đa ngôn ngữ',
        desc: 'Dịch thuật sang 8 ngôn ngữ khác nhau.',
      ),
      _Feature(
        icon: Icons.quiz,
        title: 'Quiz & Slides',
        desc: 'Tạo câu hỏi trắc nghiệm và slide thuyết trình từ ghi chú.',
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.note_alt,
                        color: theme.colorScheme.onPrimaryContainer, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Text('NoteX',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Ghi chú & Họp AI',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: features.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final f = features[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.secondaryContainer,
                              child: Icon(f.icon,
                                  color: theme.colorScheme.onSecondaryContainer),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.title,
                                      style: theme.textTheme.titleSmall),
                                  const SizedBox(height: 4),
                                  Text(f.desc,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onDone,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Bắt đầu sử dụng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature {
  const _Feature({required this.icon, required this.title, required this.desc});
  final IconData icon;
  final String title;
  final String desc;
}
