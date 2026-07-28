import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../services/auth_service.dart';

class RecommendationsScreen extends StatefulWidget {
  final int itemId;

  const RecommendationsScreen({super.key, required this.itemId});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final Dio _dio = Dio();
  bool _isLoading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    try {
      final token = await AuthService.instance.getIdToken();
      final url = '${AppConfig.apiBaseUrl}/recommendations/${widget.itemId}';
      
      final response = await _dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      setState(() {
        _data = response.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching recommendations: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTopMatchCard(Map<String, dynamic> rec, int index) {
    final itemData = rec['itemData'];
    final score = rec['score'];
    final reason = rec['reason'];
    
    String emoji;
    if (index == 0) emoji = '🥇';
    else if (index == 1) emoji = '🥈';
    else if (index == 2) emoji = '🥉';
    else emoji = '🔹';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$emoji ${itemData['categoryName'] ?? 'Item'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '$score%',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Reason', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(reason ?? '', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 16),
        const Divider(color: Color(0xFFE5DDD0), thickness: 1),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F4),
      appBar: AppBar(
        title: const Text('Recommendations', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B4332)))
          : _data == null || _data!['recommendations'] == null
              ? const Center(child: Text('Failed to load recommendations'))
              : ListView(
                  padding: const EdgeInsets.all(32.0),
                  children: [
                    const Center(
                      child: Text('Your Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    const SizedBox(height: 16),
                    const Center(child: Icon(Icons.arrow_downward, color: Colors.grey)),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text('Best Matches', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1B4332))),
                    ),
                    const SizedBox(height: 32),
                    ...(_data!['recommendations'] as List).asMap().entries.map((entry) {
                      return _buildTopMatchCard(entry.value, entry.key);
                    }),
                  ],
                ),
    );
  }
}
