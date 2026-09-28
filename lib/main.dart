import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: OCRSheetApp()));
}

class OCRSheetApp extends StatefulWidget {
  const OCRSheetApp({super.key});

  @override
  State<OCRSheetApp> createState() => _OCRSheetAppState();
}

class _OCRSheetAppState extends State<OCRSheetApp> {
  File? _selectedImage;
  String _extractedText = "";
  bool _isLoading = false;

  // Replace with your API Keys / Web App URLs
  final String _geminiApiKey = "AIzaSyBjhKjLs2aSzDtb6DJtwu2SP4IPQwH1JPA";
  final String _googleAppScriptUrl = "https://docs.google.com/document/d/1xo29AAqC2EmH3PxNvsIQ1iNBMM9jkH3vAgMLnax0w3o/edit?usp=drivesdk";

  // Pick Image from Gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _extractedText = "";
      });
    }
  }

  // Feature 1: Send Image to Gemini API for OCR
  Future<void> _processImageWithGemini() async {
    if (_selectedImage == null) return;

    setState(() => _isLoading = true);

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey',
      );

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': 'Extract all readable text from this image.'},
                    {
                      'inline_data': {
                        'mime_type': 'image/jpeg',
                        'data': base64Image,
                      }
                    }
                  ]
                }
              ]
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        setState(() => _extractedText = text ?? "No text found.");
      } else {
        setState(() => _extractedText = "Error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _extractedText = "Network Error / Timeout: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Feature 2: Append Extracted Text to Google Sheets
  Future<void> _sendToGoogleSheet() async {
    if (_extractedText.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse(_googleAppScriptUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'parsedText': _extractedText}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 302) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully uploaded to Google Sheet!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed with code: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR & Sheet Integration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_selectedImage != null)
              Image.file(_selectedImage!, height: 200)
            else
              const Container(
                height: 150,
                color: Colors.grey,
                child: Center(child: Text('No Image Selected')),
              ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('1. Pick Image'),
            ),
            ElevatedButton(
              onPressed: _processImageWithGemini,
              child: const Text('2. Extract Text with Gemini'),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator(),
            SelectableText(_extractedText),
            const SizedBox(height: 20),
            if (_extractedText.isNotEmpty)
              ElevatedButton(
                onPressed: _sendToGoogleSheet,
                child: const Text('3. Send to Google Sheet'),
              ),
          ],
        ),
      ),
    );
  }
}

