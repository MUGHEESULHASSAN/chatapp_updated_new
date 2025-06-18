import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:chat_application/chats_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// Constants
class AppConstants {
  static const String cloudName = 'dufgzsmfq';
  static const String uploadPreset = 'chatapp';
  static const String apiUrl = 'https://api.cloudinary.com/v1_1/$cloudName/upload';
}

class AppColors {
  static const Color primary = Color(0xFF121212);
  static const Color secondary = Color(0xFF1F1F1F);
  static const Color accent = Colors.orangeAccent;
  static const Color cardBackground = Color(0xFF141414);
}

// Validators
class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your password';
    }
    if (value.trim().length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.trim().isEmpty) {
      return 'Please confirm your password';
    }
    if (value.trim() != password.trim()) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    return null;
  }
}

// Models
class UserModel {
  final String email;
  final String name;
  final String? profileUrl;

  UserModel({
    required this.email,
    required this.name,
    this.profileUrl,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'createdAt': FieldValue.serverTimestamp(),
      'email': email,
      'name': name,
      'profile_url': profileUrl,
    };
  }
}

// Services
class ImageUploadService {
  static Future<String?> uploadToCloudinary(XFile imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(AppConstants.apiUrl));
      request.fields['upload_preset'] = AppConstants.uploadPreset;
      
      final fileBytes = await imageFile.readAsBytes();
      final file = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: imageFile.name,
      );
      request.files.add(file);

      final response = await request.send();
      final responseData = await response.stream.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseData);
        return jsonResponse['secure_url'];
      } else {
        debugPrint('Cloudinary upload failed: $responseData');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    }
  }
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    String? profileUrl,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final user = UserModel(
          email: email,
          name: name,
          profileUrl: profileUrl,
        );
        
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(user.toFirestore());
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        final userId = userCredential.user!.uid;
        final userDoc = await _firestore.collection('users').doc(userId).get();
        
        if (!userDoc.exists) {
          final user = UserModel(
            email: googleUser.email,
            name: googleUser.displayName ?? 'Google User',
            profileUrl: googleUser.photoUrl,
          );
          
          await _firestore
              .collection('users')
              .doc(userId)
              .set(user.toFirestore());
        }
      }
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }
}

// Custom Widgets
class CustomTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const CustomTextFormField({
    Key? key,
    required this.controller,
    required this.labelText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(prefixIcon, color: Colors.grey),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.secondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }
}

class ProfileImagePicker extends StatelessWidget {
  final XFile? selectedImage;
  final Uint8List? imageBytes;
  final VoidCallback onImagePick;
  final bool isUploading;

  const ProfileImagePicker({
    Key? key,
    this.selectedImage,
    this.imageBytes,
    required this.onImagePick,
    this.isUploading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: isUploading
                    ? const CircularProgressIndicator(color: AppColors.accent)
                    : _buildImageWidget(),
              ),
            ),
            if (!isUploading)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onImagePick,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Add Profile Photo',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        if (isUploading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Uploading...',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
      ],
    );
  }

  Widget _buildImageWidget() {
    if (imageBytes != null) {
      return Image.memory(imageBytes!, fit: BoxFit.cover);
    } else {
      return Icon(
        Icons.person,
        size: 60,
        color: Colors.grey[400],
      );
    }
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({
    Key? key,
    required this.isLoading,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black45,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          ),
      ],
    );
  }
}

// Main SignUp Page
class SignUpPage extends StatefulWidget {
  final VoidCallback? onTap;

  const SignUpPage({Key? key, this.onTap}) : super(key: key);

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  // Form controllers
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // Image picker
  final ImagePicker _picker = ImagePicker();

  // State variables
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isUploadingImage = false;
  XFile? _selectedImage;
  Uint8List? _imageBytes;

  // Animation controller
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImage = pickedFile;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _signUpWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? profileUrl;
      
      if (_selectedImage != null) {
        setState(() => _isUploadingImage = true);
        profileUrl = await ImageUploadService.uploadToCloudinary(_selectedImage!);
        setState(() => _isUploadingImage = false);

        if (profileUrl == null) {
          _showErrorSnackBar('Failed to upload profile image. Please try again.');
          return;
        }
      }

      final userCredential = await AuthService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        profileUrl: profileUrl,
      );

      if (userCredential != null) {
        _navigateToHomeScreen();
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(e.message ?? "Authentication failed");
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    
    try {
      final userCredential = await AuthService.signInWithGoogle();
      
      if (userCredential == null) {
        _showErrorSnackBar('Google sign-in was cancelled.');
        return;
      }

      if (userCredential.user != null) {
        _navigateToHomeScreen();
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

  void _navigateToHomeScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ChatsPage()),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildBrandingSection() {
    return Column(
      children: [
        const SizedBox(height: 30),
        ProfileImagePicker(
          selectedImage: _selectedImage,
          imageBytes: _imageBytes,
          onImagePick: _pickImage,
          isUploading: _isUploadingImage,
        ),
        const SizedBox(height: 20),
        Text(
          "Create Account",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
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

  Widget _buildSignUpForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          CustomTextFormField(
            controller: _nameController,
            labelText: 'Full Name',
            prefixIcon: Icons.person,
            validator: Validators.validateName,
          ),
          const SizedBox(height: 15),
          CustomTextFormField(
            controller: _emailController,
            labelText: 'Email',
            prefixIcon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.validateEmail,
          ),
          const SizedBox(height: 15),
          CustomTextFormField(
            controller: _passwordController,
            labelText: 'Password',
            prefixIcon: Icons.lock,
            obscureText: !_isPasswordVisible,
            validator: Validators.validatePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
          const SizedBox(height: 15),
          CustomTextFormField(
            controller: _confirmPasswordController,
            labelText: 'Confirm Password',
            prefixIcon: Icons.lock,
            obscureText: !_isPasswordVisible,
            validator: (value) => Validators.validateConfirmPassword(
              value,
              _passwordController.text,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _signUpWithEmailPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black87,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Sign Up"),
          ),
          const SizedBox(height: 20),
          _buildGoogleButton(),
        ],
      ),
    );
  }

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
                    color: AppColors.cardBackground.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _buildSignUpForm(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Stack(
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
          ],
        ),
      ),
    );
  }
}

// Animated Background
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
              colors: [AppColors.primary, Color(0xFF1C1C1C)],
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
    final Paint paint = Paint()..color = AppColors.accent.withOpacity(0.1);
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