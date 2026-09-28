import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'services/gemini_service.dart';
import 'services/database_helper.dart';

void main() {
  runApp(const WaybillApp());
}

class WaybillApp extends StatelessWidget {
  const WaybillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waybill Scanner',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final String _apiKey = 'YOUR_GEMINI_API_KEY'; // Insert your API key here
  bool _isLoading = false;
  List<Map<String, dynamic>> _savedWaybills = [];

  @override
  void initState() {
    super.initState();
    _refreshWaybills();
  }

  Future<void> _refreshWaybills() async {
    final data = await DatabaseHelper.instance.getWaybills();
    setState(() {
      _savedWaybills = data;
    });
  }

  Future<void> _processImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() => _isLoading = true);

    final gemini = GeminiService(apiKey: _apiKey);
    final result = await gemini.processWaybillImage(File(image.path));

    if (result != null) {
      await DatabaseHelper.instance.insertWaybill({
        'tracking_number': result['tracking_number'] ?? 'Unknown',
        'customer_phone': result['customer_phone'] ?? 'N/A',
        'cod_amount': result['cod_amount'] ?? 0.0,
        'courier_name': result['courier_name'] ?? 'General',
        'created_at': DateTime.now().toIso8601String(),
      });
      await _refreshWaybills();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to parse waybill data.')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Waybill Entry System')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _savedWaybills.isEmpty
                      ? const Center(child: Text('No waybills recorded yet.'))
                      : ListView.builder(
                          itemCount: _savedWaybills.length,
                          itemBuilder: (context, index) {
                            final item = _savedWaybills[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: const Icon(Icons.receipt_long, color: Colors.deepPurpleAccent),
                                title: Text(item['tracking_number'] ?? 'No Tracking'),
                                subtitle: Text('${item['courier_name']} • ${item['customer_phone']}'),
                                trailing: Text(
                                  '\$${item['cod_amount']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _processImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _processImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
    );
  }
}
