import 'package:flutter/material.dart';
import '../services/network_service.dart';
import '../utils/constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'package:http/http.dart' as http;

class ConnectionTestWidget extends StatefulWidget {
  const ConnectionTestWidget({super.key});

  @override
  State<ConnectionTestWidget> createState() => _ConnectionTestWidgetState();
}

class _ConnectionTestWidgetState extends State<ConnectionTestWidget> {
  bool _isTestingConnection = false;
  final List<String> _testResults = [];

  Future<void> _runConnectionTest() async {
    setState(() {
      _isTestingConnection = true;
      _testResults.clear();
    });

    _addResult('🔍 Memulai test koneksi...');

    // Test 1: Basic internet connectivity
    _addResult('\n📡 Test 1: Koneksi Internet');
    try {
      final hasInternet = await NetworkService.hasInternetConnection();
      _addResult(hasInternet ? '✅ Internet: OK' : '❌ Internet: GAGAL');
    } catch (e) {
      _addResult('❌ Internet: ERROR - $e');
    }

    // Test 2: DNS Resolution
    _addResult('\n🌐 Test 2: DNS Resolution');
    try {
      final apiIP = await NetworkService.resolveApiDomain();
      _addResult(apiIP != null
          ? '✅ DNS api.sagansa.id: $apiIP'
          : '❌ DNS api.sagansa.id: GAGAL');
    } catch (e) {
      _addResult('❌ DNS: ERROR - $e');
    }

    // Test 3: API Server Reachability
    _addResult('\n🖥️ Test 3: Server API');
    try {
      final canReachApi = await NetworkService.isApiServerReachable();
      _addResult(canReachApi ? '✅ Server API: OK' : '❌ Server API: GAGAL');
    } catch (e) {
      _addResult('❌ Server API: ERROR - $e');
    }

    // Test 4: Direct API Call
    _addResult('\n🔗 Test 4: Direct API Call');
    await _testDirectApiCall();

    // Test 5: Fallback IP Call
    _addResult('\n🔄 Test 5: Fallback IP Call');
    await _testFallbackApiCall();

    _addResult('\n✅ Test selesai!');

    setState(() {
      _isTestingConnection = false;
    });
  }

  Future<void> _testDirectApiCall() async {
    try {
      final response = await http.head(
        Uri.parse(ApiConstants.login),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      _addResult('✅ Direct API: ${response.statusCode}');
    } catch (e) {
      _addResult('❌ Direct API: $e');
    }
  }

  Future<void> _testFallbackApiCall() async {
    try {
      final response = await http.head(
        Uri.parse('${ApiConstants.fallbackBaseUrl}/login'),
        headers: {
          'Accept': 'application/json',
          'Host': 'api.sagansa.id',
        },
      ).timeout(const Duration(seconds: 10));

      _addResult('✅ Fallback IP: ${response.statusCode}');
    } catch (e) {
      _addResult('❌ Fallback IP: $e');
    }
  }

  void _addResult(String result) {
    setState(() {
      _testResults.add(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: AppSpacing.paddingMD,
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.network_check,
                  color: AppColors.primary,
                ),
                AppSpacing.gapHorizontalSM,
                Text(
                  'Test Koneksi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isTestingConnection ? null : _runConnectionTest,
                  child: _isTestingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Test'),
                ),
              ],
            ),
            if (_testResults.isNotEmpty) ...[
              AppSpacing.gapVerticalMD,
              Container(
                width: double.infinity,
                padding: AppSpacing.paddingMD,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  borderRadius: AppSpacing.borderRadiusSM,
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hasil Test:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    AppSpacing.gapVerticalSM,
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: Text(
                          _testResults.join('\n'),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
