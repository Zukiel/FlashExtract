import 'package:flutter/material.dart';
import '../models/question_answer.dart';
import '../services/ai_service.dart';
import '../services/document_parser/parsed_document.dart';
import '../services/document_parser/pdf_extraction_service.dart';

class PipelineTestScreen extends StatefulWidget {
  const PipelineTestScreen({super.key});

  @override
  State<PipelineTestScreen> createState() => _PipelineTestScreenState();
}

class _PipelineTestScreenState extends State<PipelineTestScreen> {
  final PdfExtractionService _parserService = PdfExtractionService();
  final TextEditingController _apiKeyController = TextEditingController(
    text: const String.fromEnvironment('GEMINI_API_KEY'),
  );

  final List<ParsedDocument> _queuedDocs = [];
  List<QuestionAnswer> _generatedCards = [];
  double _targetCardCount = 15;
  bool _isExtracting = false;
  bool _isGenerating = false;
  String _statusMessage = 'Add one or more PDFs to begin.';
  String? _error;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  /// Step 1: Pick multiple PDFs and append them to the staging queue
  Future<void> _addFiles() async {
    setState(() {
      _isExtracting = true;
      _error = null;
      _statusMessage = 'Extracting text from selected PDF(s)...';
    });

    try {
      final newDocs = await _parserService.pickAndExtractMultiplePdfs();
      if (newDocs.isEmpty) {
        setState(() {
          _isExtracting = false;
          _statusMessage = 'File selection canceled.';
        });
        return;
      }

      setState(() {
        for (final doc in newDocs) {
          // Avoid duplicate filenames in the queue
          final alreadyExists = _queuedDocs.any((d) => d.fileName == doc.fileName);
          if (!alreadyExists) {
            _queuedDocs.add(doc);
          }
        }
        _statusMessage =
            'Queued ${_queuedDocs.length} file(s). Adjust card count and click Generate.';
      });
    } catch (e, stack) {
      debugPrint('Extraction Error: $e\n$stack');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  void _removeFile(int index) {
    setState(() {
      final removedName = _queuedDocs[index].fileName;
      _queuedDocs.removeAt(index);
      _statusMessage = _queuedDocs.isEmpty
          ? 'All files removed. Add PDFs to begin.'
          : 'Removed "$removedName". ${_queuedDocs.length} file(s) remaining.';
    });
  }

  void _clearAllFiles() {
    setState(() {
      _queuedDocs.clear();
      _generatedCards.clear();
      _error = null;
      _statusMessage = 'Queue cleared.';
    });
  }

  /// Step 2: Feed all queued PDFs + desired card count to Gemini
  Future<void> _generateFlashcards() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _error = 'Please enter a valid Gemini API key first.');
      return;
    }
    if (_queuedDocs.isEmpty) {
      setState(() => _error = 'Add at least one PDF before generating.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
      _generatedCards = [];
      _statusMessage =
          'Generating ~${_targetCardCount.round()} flashcards across ${_queuedDocs.length} PDF(s)...';
    });

    try {
      final aiService = AiService(apiKey: apiKey);
      final cards = await aiService.generateFlashcardsFromBatch(
        _queuedDocs,
        targetTotalCards: _targetCardCount.round(),
      );

      setState(() {
        _generatedCards = cards;
        _statusMessage =
            'Done! Generated ${cards.length} flashcards from ${_queuedDocs.length} file(s).';
      });
    } catch (e, stack) {
      debugPrint('Pipeline Error: $e\n$stack');
      setState(() {
        _error = e.toString();
        _statusMessage = 'Generation failed.';
      });
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBusy = _isExtracting || _isGenerating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FlashExtract — Multi-PDF Pipeline Sandbox'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. API Key + Add PDFs + Generate Controls
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Gemini API Key',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : _addFiles,
                  icon: _isExtracting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.note_add),
                  label: const Text('Add PDFs'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: (isBusy || _queuedDocs.isEmpty) ? null : _generateFlashcards,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_isGenerating ? 'Generating...' : 'Generate Deck'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Target Flashcard Count Selector
            Row(
              children: [
                const Icon(Icons.style, size: 20, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  'Target Flashcards: ${_targetCardCount.round()}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: Slider(
                    value: _targetCardCount,
                    min: 5,
                    max: 50,
                    divisions: 9, // Steps of 5: 5, 10, 15, 20, 25, 30, 35, 40, 45, 50
                    label: '${_targetCardCount.round()} cards',
                    onChanged: isBusy
                        ? null
                        : (val) => setState(() => _targetCardCount = val),
                  ),
                ),
              ],
            ),

            // 3. Status Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _error != null ? Colors.red.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _error != null ? Colors.red.shade300 : Colors.blue.shade200,
                ),
              ),
              child: Text(
                _error ?? _statusMessage,
                style: TextStyle(
                  color: _error != null ? Colors.red.shade900 : Colors.blue.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // 4. Staged PDFs List (Add more or remove individual files)
            if (_queuedDocs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Staged PDFs (${_queuedDocs.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: isBusy ? null : _clearAllFiles,
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('Clear All'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_queuedDocs.length, (index) {
                  final doc = _queuedDocs[index];
                  return InputChip(
                    avatar: Icon(
                      doc.requiresVisionFallback ? Icons.image_search : Icons.picture_as_pdf,
                      size: 18,
                      color: doc.requiresVisionFallback ? Colors.orange : Colors.red,
                    ),
                    label: Text(
                      '${doc.fileName} (${doc.pageCount}p • ${doc.requiresVisionFallback ? "Vision" : "${doc.chunks.length} chunk"})',
                    ),
                    onDeleted: isBusy ? null : () => _removeFile(index),
                  );
                }),
              ),
            ],
            const Divider(height: 24),

            // 5. Generated Flashcards List
            Expanded(
              child: _generatedCards.isEmpty
                  ? const Center(
                      child: Text(
                        'Click "Add PDFs" to select one or multiple lecture files,\nset your desired flashcard count, and click "Generate Deck".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _generatedCards.length,
                      itemBuilder: (context, index) {
                        return _FlippableTestCard(
                          index: index + 1,
                          qa: _generatedCards[index],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlippableTestCard extends StatefulWidget {
  final int index;
  final QuestionAnswer qa;

  const _FlippableTestCard({required this.index, required this.qa});

  @override
  State<_FlippableTestCard> createState() => _FlippableTestCardState();
}

class _FlippableTestCardState extends State<_FlippableTestCard> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: _showAnswer ? Colors.green.shade50 : Colors.white,
      child: InkWell(
        onTap: () => setState(() => _showAnswer = !_showAnswer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _showAnswer
                        ? 'CARD #${widget.index} • ANSWER'
                        : 'CARD #${widget.index} • QUESTION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _showAnswer ? Colors.green.shade800 : Colors.blue.shade800,
                    ),
                  ),
                  const Icon(Icons.flip, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _showAnswer ? widget.qa.answer : widget.qa.question,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}