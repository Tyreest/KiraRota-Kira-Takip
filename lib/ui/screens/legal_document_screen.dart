import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../widgets/design_system.dart';
import '../widgets/simple_markdown.dart';

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  String? _body;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(widget.assetPath);
      if (mounted) setState(() => _body = raw);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: _error != null
          ? SafeArea(
              top: false,
              child: Center(child: Text('Belge yüklenemedi: $_error')),
            )
          : _body == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: scrollablePagePadding(context),
              child: SimpleMarkdownView(data: _body!),
            ),
    );
  }
}
