import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../core/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/custom_button.dart';
import 'category_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final bool isFromSettings;
  const LanguageSelectionScreen({super.key, this.isFromSettings = false});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selectedLanguageCode;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguageCode = prefs.getString('language_code') ?? 'en';
    });
  }

  Future<void> _setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);

    // Update the global locale
    if (mounted) {
      localeNotifier.value = Locale(languageCode);
      setState(() {
        _selectedLanguageCode = languageCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Show back button only if coming from settings
              if (widget.isFromSettings)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppTheme.textPrimary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              const Spacer(),
              Text(
                l10n.selectLanguage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 48),

              _buildLanguageOption(
                label: l10n.english,
                subLabel: "English",
                languageCode: "en",
              ),
              const SizedBox(height: 16),
              _buildLanguageOption(
                label: l10n.hindi,
                subLabel: "हिंदी",
                languageCode: "hi",
              ),

              const Spacer(),
              CustomButton(
                text: l10n.continueText,
                onPressed: () {
                  if (_selectedLanguageCode != null) {
                    // Safe navigation wrapper
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!context.mounted) return;
                      if (widget.isFromSettings) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CategoryScreen(),
                          ),
                        );
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required String label,
    required String subLabel,
    required String languageCode,
  }) {
    final isSelected = _selectedLanguageCode == languageCode;

    return GestureDetector(
      onTap: () => _setLanguage(languageCode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.white,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              subLabel,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 16),
              const Icon(Icons.check_circle, color: AppTheme.primaryColor),
            ],
          ],
        ),
      ),
    );
  }
}
