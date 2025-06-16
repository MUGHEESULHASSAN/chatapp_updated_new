import 'dart:ui';
import 'package:chat_application/chats_page.dart';
import 'package:chat_application/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class SignUpPage extends StatefulWidget {
  final VoidCallback? onTap;

  const SignUpPage({Key? key, this.onTap}) : super(key: key);

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  // Form key and controllers
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Firebase instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // UI state variables
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Animation controller for sign-up form animation
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Email/Password Sign-Up logic
  Future<void> _signUpWithEmailPassword() async {
  if (!_formKey.currentState!.validate()) return;

  if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
    _showErrorSnackBar("Passwords don't match!");
    return;
  }

  setState(() => _isLoading = true);

  try {
    // Create user with email and password
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    final userId = userCredential.user?.uid;

    if (userId != null) {
      // Save email to Firestore under "name" field in "users" collection
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'name': _emailController.text.trim(),
        'email': _emailController.text.trim(), // Optional: also store email explicitly
        'createdAt': FieldValue.serverTimestamp(), // Optional: store creation time
      });

      // Navigate to the personal information page
      _navigateToPersonalInfoPage(userId);
    } else {
      _showErrorSnackBar('User ID is null. Something went wrong.');
    }
  } on FirebaseAuthException catch (e) {
    _showErrorSnackBar(e.message ?? "An unknown error occurred.");
  } catch (e) {
    _showErrorSnackBar('Error: ${e.toString()}');
  } finally {
    setState(() => _isLoading = false);
  }
}

  // Google Sign-In logic
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        _showErrorSnackBar('Google sign-in was cancelled.');
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        final userId = userCredential.user!.uid;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          _navigateToHomeScreen();
        } else {
          _navigateToPersonalInfoPage(userId);
        }
      } else {
        _showErrorSnackBar('Failed to retrieve user data.');
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(e.message ?? 'Authentication error.');
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Navigation helpers
  void _navigateToPersonalInfoPage(String userId) {
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(builder: (context) => PersonalInfoPage(userId: userId)),
    // );
  }

  void _navigateToHomeScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ChatsPage()),
    );
  }

  // Error snackbar helper
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Animated lock icon with pulsating effect
  Widget _buildAnimatedLockIcon() {
    return Hero(
      tag: 'lockIcon',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.6, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 10, end: 20),
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
          builder: (context, glow, child) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orangeAccent.withOpacity(0.3),
                    blurRadius: glow,
                    spreadRadius: glow / 2,
                  ),
                ],
              ),
              child: Material(
                shape: const CircleBorder(),
                elevation: 8,
                color: const Color(0xFF212121),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Icon(
                    Icons.lock_outline,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Branding section
  Widget _buildBrandingSection() {
    return Column(
      children: [
        const SizedBox(height: 60),
        _buildAnimatedLockIcon(),
        const SizedBox(height: 20),
        Text(
          "Get Started",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.orangeAccent,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Sign up to start your journey.",
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.grey.shade400),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Email field with validation
  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.email, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF1F1F1F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  // Password field with toggle visibility and validation
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.lock, color: Colors.grey),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
          ),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
        filled: true,
        fillColor: const Color(0xFF1F1F1F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your password';
        }
        if (value.trim().length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  // Confirm Password field with validation
  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: !_isPasswordVisible,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.lock, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF1F1F1F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please confirm your password';
        }
        if (value.trim() != _passwordController.text.trim()) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  // Google sign-in button
  Widget _buildGoogleButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _signInWithGoogle,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.orange.withOpacity(0.2),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                offset: Offset(0, 3),
                blurRadius: 5,
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("lib/images/google.png", height: 24),
              const SizedBox(width: 12),
              const Text(
                "Sign up with Google",
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Sign-up form card with animation and form fields
  Widget _buildSignUpFormCard() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orangeAccent, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildEmailField(),
                        const SizedBox(height: 15),
                        _buildPasswordField(),
                        const SizedBox(height: 15),
                        _buildConfirmPasswordField(),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _signUpWithEmailPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent.shade200,
                            foregroundColor: Colors.black87,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Sign Up"),
                        ),
                        const SizedBox(height: 20),
                        // Divider with "Or"
                        const SizedBox(height: 20),
                        // Login link prompt
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account? ",
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                            GestureDetector(
                              onTap: (){
                                Navigator.push(context, MaterialPageRoute(builder: (context)=>LoginPage()));
                              },
                              child: const Text(
                                "Login now",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Main build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildBrandingSection(),
                  const SizedBox(height: 40),
                  _buildSignUpFormCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            ),
        ],
      ),
    );
  }
}

// Animated background widget similar to the one used in LoginPage.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({Key? key}) : super(key: key);

  @override
  _AnimatedBackgroundState createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_CircleData> _circles = [
    _CircleData(offset: const Offset(0.1, 0.2), size: 80),
    _CircleData(offset: const Offset(0.8, 0.1), size: 100),
    _CircleData(offset: const Offset(0.3, 0.7), size: 60),
    _CircleData(offset: const Offset(0.7, 0.8), size: 90),
    _CircleData(offset: const Offset(0.05, 0.1), size: 50),
    _CircleData(offset: const Offset(0.9, 0.3), size: 70),
    _CircleData(offset: const Offset(0.4, 0.05), size: 40),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF121212), Color(0xFF1C1C1C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: CustomPaint(
            painter: _BackgroundPainter(
              circles: _circles,
              animationValue: _controller.value,
            ),
          ),
        );
      },
    );
  }
}

class _CircleData {
  final Offset offset;
  final double size;
  const _CircleData({required this.offset, required this.size});
}

class _BackgroundPainter extends CustomPainter {
  final List<_CircleData> circles;
  final double animationValue;

  _BackgroundPainter({required this.circles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.orangeAccent.withOpacity(0.1);
    for (var circle in circles) {
      final dx = circle.offset.dx + 0.05 * (animationValue - 0.5);
      final dy = circle.offset.dy + 0.05 * (0.5 - animationValue);
      final Offset pos = Offset(dx * size.width, dy * size.height);
      canvas.drawCircle(pos, circle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
