import 'package:flutter/material.dart';
import '../services/document_parser/parsed_document.dart';
import '../services/document_parser/pdf_extraction_service.dart';

class ParserTestScreen extends StatefulWidget {
  const ParserTestScreen({super.key});

  @override
  State<ParserTestScreen> createState() => _ParserTestScreenState();
}

class _ParserTestScreenState extends State<ParserTestScreen> {
  final PdfExtractionService _parserService = PdfExtractionService();

  ParsedDocument? _parsedDoc;
  bool _isLoading = false;
  String? _error;
  int _selectedChunkIndex = 0;
  Duration? _extractionTime;

  Future<void> _pickAndTestPdf() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedChunkIndex = 0;
    });

    final stopwatch = Stopwatch()..start();

    try {
      final result = await _parserService.pickAndExtractPdf();
      stopwatch.stop();

      if (result != null) {
        setState(() {
          _parsedDoc = result;
          _extractionTime = stopwatch.elapsed;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FlashExtract — OCR & Parser Sandbox'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickAndTestPdf,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Test PDF'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Extracting & cleaning PDF text...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Extraction Error:\n$_error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    if (_parsedDoc == null) {
      return const Center(
        child: Text(
          'Click "Upload Test PDF" in the top right to inspect extracted text, chunks, and Vision-fallback flags.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final doc = _parsedDoc!;
    final wordCount = doc.cleanedText.isEmpty
        ? 0
        : doc.cleanedText.split(RegExp(r'\s+')).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Diagnostic Metadata Bar
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _MetricChip(label: 'File', value: doc.fileName, icon: Icons.description),
            _MetricChip(label: 'Pages', value: '${doc.pageCount}', icon: Icons.layers),
            _MetricChip(label: 'Words', value: '$wordCount', icon: Icons.text_fields),
            _MetricChip(label: 'Chunks', value: '${doc.chunks.length}', icon: Icons.segment),
            if (_extractionTime != null)
              _MetricChip(
                label: 'Speed',
                value: '${_extractionTime!.inMilliseconds} ms',
                icon: Icons.speed,
              ),
            Chip(
              avatar: Icon(
                doc.requiresVisionFallback ? Icons.image_search : Icons.check_circle,
                color: Colors.white,
                size: 18,
              ),
              backgroundColor:
                  doc.requiresVisionFallback ? Colors.orange.shade700 : Colors.green.shade700,
              label: Text(
                doc.requiresVisionFallback
                    ? 'Route: Gemini Vision (Image/Scan Heavy)'
                    : 'Route: Standard Text Chunks',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            if (doc.hasAnyImagePages)
              _MetricChip(
                label: 'Image Pages',
                value: doc.imageHeavyPageNumbers.join(', '),
                icon: Icons.photo_library,
              ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Chunk Selector Tabs (Simulates what Gab's AI service receives per API call)
        if (doc.chunks.isNotEmpty) ...[
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: doc.chunks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = index == _selectedChunkIndex;
                return ChoiceChip(
                  label: Text('Chunk ${index + 1}'),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedChunkIndex = index),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 3. Extracted & Preprocessed Text Preview Box
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                doc.chunks.isEmpty
                    ? '[No selectable text extracted — this file will be handled by Gemini Vision fallback.]'
                    : doc.chunks[_selectedChunkIndex],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label: $value'),
    );
  }
}