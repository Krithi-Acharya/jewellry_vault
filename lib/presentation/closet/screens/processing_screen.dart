import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../../../core/config/app_config.dart';
import '../../../services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/jv_app_shell.dart';
import '../../../core/widgets/jv_button.dart';

class ProcessingScreen extends StatefulWidget {
  final int jobId;
  final int itemId;

  const ProcessingScreen({
    super.key,
    required this.jobId,
    required this.itemId,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final Dio _dio = Dio();
  int _currentStep = 0;
  Timer? _pollingTimer;
  Timer? _uiTimer;
  int _secondsPassed = 0;
  bool _hasError = false;
  String _errorMessage = '';

  final List<String> _steps = [
    'Analyzing your garment',
    'Optimizing image',
    'Detecting garment type',
    'Understanding style',
    'Saving metadata',
  ];

  @override
  void initState() {
    super.initState();
    _startUiAnimation();
    _startExponentialPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _uiTimer?.cancel();
    super.dispose();
  }

  void _startUiAnimation() {
    _uiTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      if (_currentStep < _steps.length - 1) { 
        setState(() {
          _currentStep++;
        });
      }
    });
  }

  Future<void> _startExponentialPolling() async {
    while (mounted && !_hasError) {
      bool isComplete = await _checkJobStatus();
      if (isComplete) break;

      _secondsPassed += _getDelayForCurrentTime();
      await Future.delayed(Duration(seconds: _getDelayForCurrentTime()));
    }
  }

  int _getDelayForCurrentTime() {
    if (_secondsPassed < 10) return 2; 
    if (_secondsPassed < 30) return 5; 
    return 10; 
  }

  Future<bool> _checkJobStatus() async {
    try {
      final token = await AuthService.instance.getIdToken();
      final url = '${AppConfig.apiBaseUrl}/jobs/${widget.jobId}';
      
      final response = await _dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data['data'];
      final status = data['status'];

      if (status == 'COMPLETED') {
        _finishProcessing();
        return true;
      } else if (status == 'FAILED') {
        setState(() {
          _hasError = true;
          _errorMessage = data['lastError'] ?? 'AI processing failed.';
        });
        return true; // Stop polling
      }
      return false; // Continue polling
    } catch (e) {
      print('Polling error: $e');
      return false; 
    }
  }

  void _finishProcessing() {
    if (!mounted) return;
    _uiTimer?.cancel();
    setState(() {
      _currentStep = _steps.length; // All complete
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/metadata-review', arguments: widget.itemId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return JVAppShell(
      title: '',
      showBackButton: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hasError) ...[
                const Icon(Icons.error_outline, color: AppColors.error, size: 64),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Processing Failed',
                  style: AppTypography.headingLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(_errorMessage, style: AppTypography.bodyLarge.copyWith(color: AppColors.error)),
                const SizedBox(height: AppSpacing.xl),
                JVButton(
                  text: 'Go Back',
                  onPressed: () => Navigator.pop(context),
                  isFullWidth: false,
                )
              ] else ...[
                Text('AI Analysis', style: AppTypography.headingLarge),
                const SizedBox(height: AppSpacing.xl),
                ...List.generate(_steps.length, (index) {
                  bool isCompleted = index < _currentStep || _currentStep == _steps.length;
                  bool isCurrent = index == _currentStep;
                  bool isPending = index > _currentStep;
                  
                  Widget icon;
                  if (isCompleted) {
                    icon = const Icon(Icons.check, color: AppColors.primaryEmerald, size: 24);
                  } else if (isCurrent) {
                    icon = const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryEmerald)),
                    );
                  } else {
                    icon = const Icon(Icons.radio_button_unchecked, color: AppColors.border, size: 24);
                  }

                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isPending ? 0.3 : 1.0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Row(
                        children: [
                          SizedBox(width: 32, child: Center(child: icon)),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            _steps[index],
                            style: AppTypography.bodyLarge.copyWith(
                              color: isCompleted ? AppColors.primaryText : AppColors.secondaryText,
                              fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
