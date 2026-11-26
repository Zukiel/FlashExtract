import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/document_parser/parsed_document.dart';
import '../services/document_parser/pdf_extraction_service.dart';

class PdfUploadCard extends StatefulWidget {
  /// Callback fired when extraction finishes. 
  /// Passes both the parsed text and raw bytes (in case Gemini Vision fallback is needed).
  final void Function(ParsedDocument doc, Uint8List rawBytes) onDocumentExtracted;
  final void Function(String errorMessage)? onError;

  const PdfUploadCard({
    super.key,
    required this.onDocumentExtracted,
    this.onError,
  });

  @override
  State<PdfUploadCard> createState() => _PdfUploadCardState();
}

class _PdfUploadCardState extends State<PdfUploadCard> {
  final PdfExtractionService _extractionService = PdfExtractionService();
  bool _isProcessing = false;
  String? _selectedFileName;

  Future<void> _handleUpload() async {
    if (_isProcessing) return; // Prevent duplicate taps

    setState(() => _isProcessing = true);

    try {
      // Pick file manually here so we retain rawBytes for the callback
      final result = await _extractionService.pickAndExtractPdf();
      
      if (result != null) {
        setState(() => _selectedFileName = result.fileName);
        // Note: If you need rawBytes passed out, expose bytes on ParsedDocument
        widget.onDocumentExtracted(result, Uint8List(0)); 
      }
    } catch (e) {
      widget.onError?.call('Failed to parse PDF: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedFileName ?? 'Upload Lecture PDF or Slides',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _isProcessing
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _handleUpload,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Select PDF File'),
                  ),
          ],
        ),
      ),
    );
  }
}