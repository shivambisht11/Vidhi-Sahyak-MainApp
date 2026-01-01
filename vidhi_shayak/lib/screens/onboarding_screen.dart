import 'package:flutter/material.dart';
import 'language_selection_screen.dart';
import 'category_screen.dart';

import '../core/app_theme.dart';
import '../widgets/custom_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();
  int _pageIndex = 0;

  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  final List<Map<String, String>> onboardingData = [
    {
      "title": "Your AI Legal Friend",
      "desc": "Get instant help for legal, study, or AI support needs.",
      "image": "assets/ai_law.png",
    },
    {
      "title": "Choose Your Mode",
      "desc":
          "Select your category and chat instantly with the right assistant.",
      "image": "assets/select_mode.png",
    },
  ];

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _arrowAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(_arrowController);
  }

  @override
  void dispose() {
    _controller.dispose();
    _arrowController.dispose();
    super.dispose();
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        onboardingData.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: _pageIndex == index ? 24 : 10,
          height: 8,
          decoration: BoxDecoration(
            color: _pageIndex == index
                ? AppTheme.primaryColor
                : Colors.white.withValues(alpha: 0.4), // White inactive dots
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // 🖼️ Background Image
          Positioned.fill(
            child: Image.asset("assets/vidhi_bg.png", fit: BoxFit.cover),
          ),
          // 🌑 Overlay for readability
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(
                alpha: 0.6,
              ), // Adjust opacity as needed
            ),
          ),
          // 📄 Main Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Expanded(
                  flex: 4,
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (index) =>
                        setState(() => _pageIndex = index),
                    itemCount: onboardingData.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 🖼️ Image Removed as per request
                          const SizedBox(height: 24),
                          Text(
                            onboardingData[index]["title"]!,
                            textAlign: TextAlign.center,
                            style: AppTheme.textTheme.displayMedium?.copyWith(
                              color: Colors
                                  .white, // Ensure text is white on dark bg
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            onboardingData[index]["desc"]!,
                            textAlign: TextAlign.center,
                            style: AppTheme.textTheme.bodyLarge?.copyWith(
                              color:
                                  Colors.white70, // Lighter white for subtext
                            ),
                          ),

                          // 👇 Only show arrow on the first page
                          if (index == 0) ...[
                            const SizedBox(height: 40),
                            AnimatedBuilder(
                              animation: _arrowAnimation,
                              builder: (context, child) => Transform.translate(
                                offset: Offset(_arrowAnimation.value, 0),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white, // White arrow
                                    size: 40,
                                  ),
                                  onPressed: () {
                                    _controller.nextPage(
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildDotsIndicator(),
                const SizedBox(height: 40),
                if (_pageIndex == onboardingData.length - 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                    child: CustomButton(
                      text: "Get Started",
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LanguageSelectionScreen(),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(
                    height: 104,
                  ), // Placeholder to keep layout stable
              ],
            ),
          ),
        ],
      ),
    );
  }
}
