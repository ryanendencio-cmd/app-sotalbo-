import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. FULL-SCREEN BACKGROUND PICTURE (cs.jpg)
          Positioned.fill(
            child: Image.asset(
              'assets/construction_bg.jpg',
              fit: BoxFit.cover, // Para sakop ang buong screen
            ),
          ),

          // 2. DARK GRADIENT OVERLAY (Para mabasa ang white text sa ibaba)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4), // Nagsisimulang dumilim sa gitna
                    Colors.black.withValues(alpha: 0.9), // Pinakaitim sa ilalim
                  ],
                  stops: const [0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // 3. MAIN CONTENT
          SafeArea(
            child: Column(
              children: [
                // Top area with centered logo
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Image.asset(
                        'assets/logo.png',
                        height: 75, // Same size as login screen
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Bottom Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TITLE: BUILD TRACK
                    Text(
                      'BUILD TRACK',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // Puting text base sa reference
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 5),

                    // PROJECT-BASED MOTTO
                    const Text(
                      'Track daily expenses, manpower, and equipment — right from the field.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70, // Medyo grayish-white
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // SIGN UP BUTTON (Puting Button na may Dark Text)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/walkthrough');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, // Kulay puti
                          foregroundColor: Colors.black, // Itim na text
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30), // Pill-shaped
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Get started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // LOGIN LINK (Kulay puti)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white70,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
 }
}