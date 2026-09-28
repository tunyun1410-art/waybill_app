import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GeminiService {
  final String apiKey;

  GeminiService({required this.apiKey});

  Future<Map<String, dynamic>?> processWaybillImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final prompt = '''
Extract waybill info from image.
Return JSON with EXACT keys:
- "tracking_number" (string)
- "customer_phone" (string)
- "cod_amount" (number)
- "courier_name" (string)
Return ONLY raw JSON block without markdown code fences.
''';

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            }
          ]
        }
      ]
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawText = data['candidates'][0]['content']['parts'][0]['text'];
        final cleanJson = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleanJson);
      }
    } catch (e) {
      print('OCR Processing Error: $e');
    }
    return null;
  }
}
