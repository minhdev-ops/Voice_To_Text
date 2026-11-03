import 'package:flutter/material.dart';
import '../api_service.dart';
import 'models_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ApiService api;
  final String baseUrl;
  final String language;
  final String model;
  final void Function(String) onBaseUrlChanged;
  final void Function(String) onLanguageChanged;
  final void Function(String) onModelChanged;

  const SettingsScreen({
    super.key,
    required this.api,
    required this.baseUrl,
    required this.language,
    required this.model,
    required this.onBaseUrlChanged,
    required this.onLanguageChanged,
    required this.onModelChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<String> _models = const ['tiny', 'base', 'small', 'medium', 'large-v3'];
  Map<String, dynamic>? _health;
  bool _healthLoading = true;
  Map<String, dynamic>? _llm;
  bool _savingLlm = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final models = await widget.api.listModels();
      final health = await widget.api.checkHealth();
      final llm = await widget.api.getSummarySettings();
      if (mounted) {
        setState(() {
          if (models.isNotEmpty) _models = models;
          _health = health;
          _llm = llm;
          _healthLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _healthLoading = false);
    }
  }

  Future<void> _editLlm() async {
    final keyCtrl = TextEditingController();
    final urlCtrl = TextEditingController(
        text: (_llm?['base_url'] ?? 'https://api.openai.com/v1').toString());
    final modelCtrl = TextEditingController(
        text: (_llm?['model'] ?? 'gpt-4o-mini').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cấu hình AI tóm tắt'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API key',
                  hintText: 'sk-...',
                  helperText: 'Lưu trên máy chủ backend, không gửi lên đâu khác',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.openai.com/v1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'gpt-4o-mini',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _savingLlm = true);
    final res = await widget.api.setSummarySettings(
      apiKey: keyCtrl.text.trim().isEmpty ? null : keyCtrl.text.trim(),
      baseUrl: urlCtrl.text.trim(),
      model: modelCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _savingLlm = false;
      if (res != null) _llm = res;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res?['configured'] == true
            ? 'Đã bật tóm tắt bằng AI'
            : 'Chưa cấu hình được AI, kiểm tra lại key/URL'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        children: [
          _serverSection(theme),
          _asrSection(theme),
          _aiSection(theme),
          _aboutSection(theme),
        ],
      ),
    );
  }

  Widget _serverSection(ThemeData theme) => _section(
        theme,
        'Máy chủ',
        Icons.dns,
        [
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Backend URL'),
            subtitle: Text(widget.baseUrl),
            trailing: const Icon(Icons.edit, size: 18),
            onTap: () => _editBaseUrl(context),
          ),
          ListTile(
            leading: Icon(
              _healthLoading
                  ? Icons.hourglass_empty
                  : (_health != null ? Icons.check_circle : Icons.error),
              color: _healthLoading
                  ? Colors.grey
                  : (_health != null ? Colors.green : Colors.red),
            ),
            title: const Text('Trạng thái'),
            subtitle: Text(
              _healthLoading
                  ? 'Đang kiểm tra...'
                  : (_health != null
                      ? 'Sẵn sàng · ${_health!['model']} · LLM: ${_health!['llm']}'
                      : 'Không kết nối được'),
            ),
          ),
        ],
      );

  Widget _asrSection(ThemeData theme) => _section(
        theme,
        'Nhận dạng giọng nói',
        Icons.record_voice_over,
        [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              key: ValueKey('model-${widget.model}'),
              initialValue: widget.model,
              decoration: const InputDecoration(
                labelText: 'Mô hình Whisper',
                border: OutlineInputBorder(),
              ),
              items: _models
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) {
                if (v != null) widget.onModelChanged(v);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              key: ValueKey('lang-${widget.language}'),
              initialValue: widget.language,
              decoration: const InputDecoration(
                labelText: 'Ngôn ngữ',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: '', child: Text('Tự nhận')),
              ],
              onChanged: (v) {
                if (v != null) widget.onLanguageChanged(v);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Mô hình lớn = chính xác hơn nhưng chậm hơn'),
            subtitle: Text('Đang dùng: ${widget.model}'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download),
            title: const Text('Quản lý mô hình'),
            subtitle: const Text('Tải về / xóa mô hình Whisper trên máy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ModelsScreen(api: widget.api),
              ),
            ),
          ),
        ],
      );

  Widget _aiSection(ThemeData theme) {
    final configured = _llm?['configured'] == true;
    return _section(
      theme,
      'Tóm tắt bằng AI',
      Icons.auto_awesome,
      [
        ListTile(
          leading: Icon(
            configured ? Icons.check_circle : Icons.info_outline,
            color: configured ? Colors.green : Colors.orange,
          ),
          title: Text(configured ? 'Đang bật' : 'Đang tắt (dùng quy tắc)'),
          subtitle: Text(
            configured
                ? '${_llm?['model']} · key ${_llm?['key_hint']}'
                : 'Nhập API key để tóm tắt/biên bản chất lượng cao',
          ),
          trailing: _savingLlm
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.edit, size: 18),
          onTap: _savingLlm ? null : _editLlm,
        ),
        const ListTile(
          leading: Icon(Icons.info_outline, size: 20),
          title: Text(
            'Hỗ trợ mọi API tương thích OpenAI (OpenAI, Groq, Together, Ollama...)',
            style: TextStyle(fontSize: 13),
          ),
          dense: true,
        ),
      ],
    );
  }

  Widget _aboutSection(ThemeData theme) => _section(
        theme,
        'Giới thiệu',
        Icons.info,
        [
          const ListTile(
            leading: Icon(Icons.apps),
            title: Text('VietVoice'),
            subtitle: Text('Phiên bản 1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Giấy phép mô hình'),
            subtitle: const Text('Whisper (MIT) · faster-whisper'),
            onTap: () => _showLicense(context),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Chính sách quyền riêng tư'),
            subtitle: const Text('Dữ liệu lưu trên thiết bị'),
            onTap: () => _showPrivacy(context),
          ),
        ],
      );

  Widget _section(ThemeData theme, String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }

  void _editBaseUrl(BuildContext context) {
    final ctrl = TextEditingController(text: widget.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend URL'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'http://127.0.0.1:8000',
            helperText: 'Android emulator: 10.0.2.2 · Máy thật qua USB: 127.0.0.1',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              widget.onBaseUrlChanged(ctrl.text.trim());
              Navigator.pop(ctx);
              setState(() => _healthLoading = true);
              _loadData();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showLicense(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Giấy phép'),
        content: const SingleChildScrollView(
          child: Text(
            'Whisper: MIT License (OpenAI)\n'
            'faster-whisper: MIT License\n'
            'Flutter: BSD 3-Clause License\n\n'
            'Mô hình ASR được tải xuống và chạy cục bộ trên thiết bị.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showPrivacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chính sách quyền riêng tư'),
        content: const SingleChildScrollView(
          child: Text(
            'VietVoice là ứng dụng offline-first.\n\n'
            '· Bản ghi âm và văn bản được lưu trên thiết bị.\n'
            '· Nhận dạng giọng nói chạy cục bộ, không gửi âm thanh lên máy chủ.\n'
            '· Tính năng AI Summary tùy chọn có thể gọi API trực tuyến nếu được cấu hình.\n'
            '· Người dùng chịu trách nhiệm xin sự đồng ý của người bị ghi âm theo quy định pháp luật.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
