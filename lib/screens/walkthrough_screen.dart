import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';

class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Sotalbo Construction',
      'subtitle': 'Your strategic partner for construction and infrastructure solutions.\n\nBringing complex projects to life through dedicated craftsmanship and day-to-day accountability.',
      'icon': Icons.business,
    },
    {
      'title': 'Our Expertise',
      'subtitle': 'From Concept to Completion, We Build their Blessings.\n\n• Pre & General Construction\n• Renovation & Extension\n• Fabrication & Fitouts',
      'icon': Icons.engineering_outlined,
    },
    {
      'title': 'Strategic Clarity',
      'subtitle': 'Built around the true needs of Sotalbo Construction.\n\nReplace scattered paper receipts with digital records. Track expenses, manpower, and equipment right from the field.',
      'icon': Icons.analytics_outlined,
    },
    {
      'title': 'Seamless Process',
      'subtitle': 'Staff seamlessly input data on-site, and the system syncs instantly.\n\nAdmins can monitor expenses, budgets, and workforce activity efficiently from the web portal.',
      'icon': Icons.cloud_sync_outlined,
    },
  ];



  void _nextPage() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/construction_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          
          // Dark Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),
          
          // Foreground Content
          SafeArea(
            child: Column(
              children: [
                // Skip Button
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
                // Fixed Logo at the top
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                  child: Image.asset(
                    'assets/logo.png',
                    height: 50,
                    color: Colors.white,
                  ),
                ),
                
                // Glassmorphism Card containing the Slideshow
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              // Swipable Content
                              Expanded(
                                child: PageView.builder(
                                  controller: _pageController,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentIndex = index;
                                    });
                                  },
                                  itemCount: _slides.length,
                                  itemBuilder: (context, index) {
                                    final slide = _slides[index];
                                    return Padding(
                                      padding: const EdgeInsets.all(32.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            height: 120,
                                            width: 120,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white.withOpacity(0.1),
                                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.1),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 10),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              slide['icon'],
                                              size: 60,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 32),
                                          Text(
                                            slide['title']!,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            slide['subtitle']!,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: Colors.white70,
                                              height: 1.6,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              
                              // Bottom Controls (Dots & Button)
                              Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    // Dot Indicators
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(
                                        _slides.length,
                                        (index) => AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          height: 8,
                                          width: _currentIndex == index ? 24 : 8,
                                          decoration: BoxDecoration(
                                            color: _currentIndex == index
                                                ? const Color(0xFFFF5252) // Bright red for visibility
                                                : Colors.white38,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    
                                    // Next / Continue Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: _nextPage,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          _currentIndex == _slides.length - 1
                                              ? 'Continue to Login'
                                              : 'Next',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
