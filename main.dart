import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  runApp(const WoundSenseApp());
}

class WoundSenseApp extends StatelessWidget {
  const WoundSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WoundSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE1306C),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFDBDBDB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFDBDBDB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF8E8E8E)),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const _nameKey = 'registered_name';
  static const _emailKey = 'registered_email';
  static const _passwordKey = 'registered_password';
  static const _loggedInKey = 'is_logged_in';

  SharedPreferences? _preferences;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String _registeredName = '';
  String _registeredEmail = '';

  bool get _hasRegisteredUser => _registeredEmail.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    final preferences = await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      _preferences = preferences;
      _registeredName = preferences.getString(_nameKey) ?? '';
      _registeredEmail = preferences.getString(_emailKey) ?? '';
      _isLoggedIn = preferences.getBool(_loggedInKey) ?? false;
      _isLoading = false;
    });
  }

  Future<String?> _register({
    required String name,
    required String email,
    required String password,
  }) async {
    final preferences = _preferences;
    if (preferences == null) return 'Please wait while WoundSense starts.';

    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanName.length < 2) return 'Enter your full name.';
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      return 'Enter a valid email address.';
    }
    if (cleanPassword.length < 6) {
      return 'Use at least 6 characters for your password.';
    }

    await preferences.setString(_nameKey, cleanName);
    await preferences.setString(_emailKey, cleanEmail);
    await preferences.setString(_passwordKey, cleanPassword);
    await preferences.setBool(_loggedInKey, true);

    if (!mounted) return null;
    setState(() {
      _registeredName = cleanName;
      _registeredEmail = cleanEmail;
      _isLoggedIn = true;
    });
    return null;
  }

  Future<String?> _login({
    required String email,
    required String password,
  }) async {
    final preferences = _preferences;
    if (preferences == null) return 'Please wait while WoundSense starts.';

    final savedEmail = preferences.getString(_emailKey) ?? '';
    final savedPassword = preferences.getString(_passwordKey) ?? '';

    if (email.trim().toLowerCase() != savedEmail ||
        password.trim() != savedPassword) {
      return 'Email or password is incorrect.';
    }

    await preferences.setBool(_loggedInKey, true);

    if (!mounted) return null;
    setState(() {
      _isLoggedIn = true;
    });
    return null;
  }

  Future<void> _logout() async {
    await _preferences?.setBool(_loggedInKey, false);

    if (!mounted) return;
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isLoggedIn) {
      return HomeScreen(
        userName: _registeredName,
        onLogout: _logout,
      );
    }

    return AuthScreen(
      hasRegisteredUser: _hasRegisteredUser,
      registeredEmail: _registeredEmail,
      onLogin: _login,
      onRegister: _register,
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.hasRegisteredUser,
    required this.registeredEmail,
    required this.onLogin,
    required this.onRegister,
  });

  final bool hasRegisteredUser;
  final String registeredEmail;
  final Future<String?> Function({
    required String email,
    required String password,
  }) onLogin;
  final Future<String?> Function({
    required String name,
    required String email,
    required String password,
  }) onRegister;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late bool _isRegistering;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _isRegistering = !widget.hasRegisteredUser;
    _emailController.text = widget.registeredEmail;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    final error = _isRegistering
        ? await widget.onRegister(
            name: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          )
        : await widget.onLogin(
            email: _emailController.text,
            password: _passwordController.text,
          );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorMessage = error ?? '';
    });
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _errorMessage = '';
      _passwordController.clear();
      if (!_isRegistering) {
        _emailController.text = widget.registeredEmail;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 34, 24, 26),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDBDBDB)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'WoundSense',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isRegistering
                                ? 'Sign up to start your private wound screening feed.'
                                : 'Log in to continue your wound screening feed.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF737373),
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (_isRegistering) ...[
                            TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'Full name',
                                isDense: true,
                              ),
                              validator: (value) =>
                                  (value?.trim().length ?? 0) < 2
                                      ? 'Enter your full name'
                                      : null,
                            ),
                            const SizedBox(height: 8),
                          ],
                          TextFormField(
                            controller: _emailController,
                            enabled:
                                _isRegistering || !widget.hasRegisteredUser,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'Email address',
                              isDense: true,
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (!email.contains('@') ||
                                  !email.contains('.')) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              isDense: true,
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) =>
                                (value?.trim().length ?? 0) < 6
                                    ? 'Use at least 6 characters'
                                    : null,
                          ),
                          if (_errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFC13584),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _isSubmitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0095F6),
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isRegistering ? 'Sign up' : 'Log in',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.hasRegisteredUser) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFDBDBDB)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isRegistering
                                ? 'Have an account?'
                                : 'Need a fresh account?',
                          ),
                          TextButton(
                            onPressed: _isSubmitting ? null : _toggleMode,
                            child: Text(
                              _isRegistering ? 'Log in' : 'Sign up',
                              style: const TextStyle(
                                color: Color(0xFF0095F6),
                                fontWeight: FontWeight.w800,
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
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.userName,
    required this.onLogout,
  });

  final String userName;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  Interpreter? _interpreter;
  File? _image;

  bool _isAnalyzing = false;
  bool _modelLoaded = false;

  String _result = '';
  String _confidence = '';
  String _riskLevel = '';
  String _advice = '';
  String _modelStatus = 'Preparing AI model...';
  String _errorMessage = '';

  bool get _canAnalyze =>
      _image != null && _modelLoaded && !_isAnalyzing && _interpreter != null;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');

      if (!mounted) return;
      setState(() {
        _modelLoaded = true;
        _modelStatus = 'AI model ready';
        _errorMessage = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _modelLoaded = false;
        _modelStatus = 'AI model could not be loaded';
        _errorMessage =
            'The scan model is not ready. Please check that assets/model.tflite is available.';
      });
      debugPrint('Error loading model: $e');
    }
  }

  Future<void> analyzeImage() async {
    if (_image == null) {
      _showSnackBar('Please select a wound image first.');
      return;
    }

    if (_interpreter == null || !_modelLoaded) {
      _showSnackBar('The AI model is still loading. Please try again shortly.');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _result = '';
      _confidence = '';
      _riskLevel = '';
      _advice = '';
      _errorMessage = '';
    });

    try {
      final bytes = await _image!.readAsBytes();
      final original = img.decodeImage(bytes);

      if (original == null) {
        throw const FormatException('Unable to read the selected image.');
      }

      final resized = img.copyResize(original, width: 224, height: 224);
      final input = List.generate(
        1,
        (_) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );
      final output = List.generate(1, (_) => List.filled(1, 0.0));

      _interpreter!.run(input, output);

      final probability = output[0][0];
      final isDfu = probability > 0.5;
      final confidenceScore = isDfu ? probability : 1 - probability;

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _result = isDfu ? 'DFU Detected' : 'No DFU Found';
        _confidence = '${(confidenceScore * 100).toStringAsFixed(1)}%';
        _riskLevel = isDfu ? 'Possible Risk' : 'Low Risk';
        _advice = isDfu
            ? 'Possible diabetic foot ulcer signs detected. Please consult a healthcare professional as soon as possible.'
            : 'No ulcer signs detected by the model. Continue monitoring foot health and seek care if symptoms appear.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage =
            'The selected image could not be analyzed. Please try another clear image.';
      });
      debugPrint('Analyze image error: $e');
    }
  }

  Future<void> pickCamera() async {
    await _pickImage(ImageSource.camera);
  }

  Future<void> pickGallery() async {
    await _pickImage(ImageSource.gallery);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final photo = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (photo == null) return;

      setState(() {
        _image = File(photo.path);
        _result = '';
        _confidence = '';
        _riskLevel = '';
        _advice = '';
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}. Please check app permissions.';
      });
      debugPrint('Image picker error: $e');
    }
  }

  void _removeImage() {
    setState(() {
      _image = null;
      _result = '';
      _confidence = '';
      _riskLevel = '';
      _advice = '';
      _errorMessage = '';
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.userName.isEmpty ? 'woundsense_user' : widget.userName;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        title: const Text(
          'WoundSense',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New scan',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: pickCamera,
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFDBDBDB)),
        ),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            SizedBox(
              height: 104,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                children: [
                  StoryBubble(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: pickCamera,
                  ),
                  StoryBubble(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: pickGallery,
                  ),
                  StoryBubble(
                    icon: _modelLoaded
                        ? Icons.verified_outlined
                        : Icons.hourglass_top_outlined,
                    label: _modelLoaded ? 'AI ready' : 'Loading',
                    onTap: () => _showSnackBar(_modelStatus),
                  ),
                  StoryBubble(
                    icon: Icons.info_outline,
                    label: 'Care note',
                    onTap: () => _showSnackBar(
                      'WoundSense is a screening aid, not a diagnosis.',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFDBDBDB)),
            _ScanPost(
              image: _image,
              userName: displayName,
              modelStatus: _modelStatus,
              isAnalyzing: _isAnalyzing,
              canAnalyze: _canAnalyze,
              result: _result,
              confidence: _confidence,
              riskLevel: _riskLevel,
              advice: _advice,
              errorMessage: _errorMessage,
              onCameraTap: pickCamera,
              onGalleryTap: pickGallery,
              onAnalyzeTap: analyzeImage,
              onRemoveTap: _removeImage,
            ),
            const SizedBox(height: 74),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 66,
        selectedIndex: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        indicatorColor: Colors.transparent,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ScanPost extends StatelessWidget {
  const _ScanPost({
    required this.image,
    required this.userName,
    required this.modelStatus,
    required this.isAnalyzing,
    required this.canAnalyze,
    required this.result,
    required this.confidence,
    required this.riskLevel,
    required this.advice,
    required this.errorMessage,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onAnalyzeTap,
    required this.onRemoveTap,
  });

  final File? image;
  final String userName;
  final String modelStatus;
  final bool isAnalyzing;
  final bool canAnalyze;
  final String result;
  final String confidence;
  final String riskLevel;
  final String advice;
  final String errorMessage;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onAnalyzeTap;
  final VoidCallback onRemoveTap;

  @override
  Widget build(BuildContext context) {
    final hasResult = result.isNotEmpty;
    final isDfu = result == 'DFU Detected';
    final accent = isDfu ? const Color(0xFFE1306C) : const Color(0xFF00A86B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const GradientAvatar(
                size: 38,
                icon: Icons.monitor_heart_outlined,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      modelStatus,
                      style: const TextStyle(
                        color: Color(0xFF737373),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More',
                icon: const Icon(Icons.more_horiz),
                onPressed: () {},
              ),
            ],
          ),
        ),
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            color: const Color(0xFFFAFAFA),
            child: image == null
                ? _EmptyPost(onCameraTap: onCameraTap, onGalleryTap: onGalleryTap)
                : Image.file(image!, fit: BoxFit.cover),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Analyze',
                icon: Icon(
                  hasResult ? Icons.favorite : Icons.favorite_border,
                  color: hasResult ? accent : Colors.black,
                ),
                onPressed: canAnalyze ? onAnalyzeTap : null,
              ),
              IconButton(
                tooltip: 'Camera',
                icon: const Icon(Icons.mode_comment_outlined),
                onPressed: onCameraTap,
              ),
              IconButton(
                tooltip: 'Gallery',
                icon: const Icon(Icons.send_outlined),
                onPressed: onGalleryTap,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Remove image',
                icon: const Icon(Icons.bookmark_border),
                onPressed: image == null ? null : onRemoveTap,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FilledButton(
            onPressed: canAnalyze ? onAnalyzeTap : null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFFDBDBDB),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isAnalyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Analyze Wound',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasResult) ...[
                Text(
                  '$result  $confidence confidence',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  riskLevel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$userName ',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      TextSpan(text: advice),
                    ],
                  ),
                  style: const TextStyle(height: 1.35),
                ),
              ] else ...[
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$userName ',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const TextSpan(
                        text:
                            'Add a clear wound image, then tap Analyze Wound for AI-assisted DFU screening.',
                      ),
                    ],
                  ),
                  style: const TextStyle(height: 1.35),
                ),
              ],
              if (errorMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  errorMessage,
                  style: const TextStyle(
                    color: Color(0xFFC13584),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                'WoundSense is a screening aid, not a medical diagnosis.',
                style: TextStyle(
                  color: Color(0xFF737373),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyPost extends StatelessWidget {
  const _EmptyPost({
    required this.onCameraTap,
    required this.onGalleryTap,
  });

  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GradientAvatar(
              size: 88,
              icon: Icons.add_photo_alternate_outlined,
            ),
            const SizedBox(height: 16),
            const Text(
              'Share a wound image',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Capture or upload a clear, well-lit foot wound photo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF737373),
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onCameraTap,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onGalleryTap,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StoryBubble extends StatelessWidget {
  const StoryBubble({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(44),
        onTap: onTap,
        child: SizedBox(
          width: 74,
          child: Column(
            children: [
              GradientAvatar(size: 62, icon: icon),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GradientAvatar extends StatelessWidget {
  const GradientAvatar({
    super.key,
    required this.size,
    required this.icon,
  });

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFFFEDA75),
            Color(0xFFFA7E1E),
            Color(0xFFD62976),
            Color(0xFF962FBF),
            Color(0xFF4F5BD5),
          ],
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.black, size: size * 0.42),
      ),
    );
  }
}
