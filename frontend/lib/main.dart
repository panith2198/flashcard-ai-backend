import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const FlashCardApp());
}

// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------

class FlashCardApp extends StatelessWidget {
  const FlashCardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlashCard AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C6BC0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class FlashCard {
  final String question;
  final String answer;

  const FlashCard({required this.question, required this.answer});

  factory FlashCard.fromJson(Map<String, dynamic> json) {
    return FlashCard(
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// Home page
// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _backendUrl = 'http://localhost:8000/upload-pdf';

  List<FlashCard> _cards = [];
  bool _isLoading = false;
  String? _selectedFileName;

  // ---- file picking + upload ---------------------------------------------

  Future<void> _pickAndUpload() async {
    // Open file picker filtered to PDFs only
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // needed for web
    );

    if (result == null || result.files.isEmpty) return; // user cancelled

    final pickedFile = result.files.first;

    setState(() {
      _isLoading = true;
      _selectedFileName = pickedFile.name;
      _cards = [];
    });

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_backendUrl));

      if (kIsWeb) {
        // On web, bytes are available directly
        final bytes = pickedFile.bytes;
        if (bytes == null) throw Exception('Could not read file bytes.');
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: pickedFile.name,
          ),
        );
      } else {
        // On native (macOS / iOS / Android), use the file path
        final filePath = pickedFile.path;
        if (filePath == null) throw Exception('Could not get file path.');
        request.files.add(
          await http.MultipartFile.fromPath('file', filePath),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception(
          'Request timed out. Is the backend running on port 8000?',
        ),
      );

      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(responseBody);
        final List<dynamic> rawCards = json['cards'] as List<dynamic>? ?? [];
        setState(() {
          _cards = rawCards
              .map((c) => FlashCard.fromJson(c as Map<String, dynamic>))
              .toList();
        });
      } else {
        // Try to parse error detail from FastAPI
        String detail = 'Server error (${streamedResponse.statusCode}).';
        try {
          final errJson = jsonDecode(responseBody) as Map<String, dynamic>;
          detail = errJson['detail'] as String? ?? detail;
        } catch (_) {}
        _showError(detail);
      }
    } on SocketException {
      _showError(
        'Connection refused. Make sure the backend is running:\n'
        'cd backend && python main.py',
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ---- helpers ------------------------------------------------------------

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showAnswerDialog(FlashCard card) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Answer', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(card.answer),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: const Text(
          'FlashCard AI',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        centerTitle: true,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Upload button ----------------------------------------
            _UploadButton(
              isLoading: _isLoading,
              selectedFileName: _selectedFileName,
              onPressed: _isLoading ? null : _pickAndUpload,
            ),

            const SizedBox(height: 24),

            // ---- Loading indicator ------------------------------------
            if (_isLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Generating flashcards…'),
                  ],
                ),
              ),

            // ---- Empty state ------------------------------------------
            if (!_isLoading && _cards.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.picture_as_pdf_outlined,
                          size: 72, color: colorScheme.primary.withOpacity(0.35)),
                      const SizedBox(height: 16),
                      Text(
                        'Upload a PDF to generate\nyour flashcards',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ---- Card list -------------------------------------------
            if (!_isLoading && _cards.isNotEmpty) ...[
              Text(
                '${_cards.length} flashcard${_cards.length == 1 ? '' : 's'} generated — tap a card to see the answer',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _cards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final card = _cards[index];
                    return _FlashCardTile(
                      index: index + 1,
                      card: card,
                      onTap: () => _showAnswerDialog(card),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upload button widget
// ---------------------------------------------------------------------------

class _UploadButton extends StatelessWidget {
  final bool isLoading;
  final String? selectedFileName;
  final VoidCallback? onPressed;

  const _UploadButton({
    required this.isLoading,
    required this.selectedFileName,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onPrimary,
              ),
            )
          : const Icon(Icons.upload_file_rounded),
      label: Text(
        isLoading
            ? 'Processing…'
            : selectedFileName != null
                ? 'Re-upload PDF'
                : 'Upload PDF & Generate Flashcards',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual flashcard tile
// ---------------------------------------------------------------------------

class _FlashCardTile extends StatelessWidget {
  final int index;
  final FlashCard card;
  final VoidCallback onTap;

  const _FlashCardTile({
    required this.index,
    required this.card,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Index badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Question text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.question,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to reveal answer',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.touch_app_rounded,
                  color: colorScheme.primary.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
