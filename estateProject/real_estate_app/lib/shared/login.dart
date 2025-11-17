// import 'package:flutter/material.dart';
// import 'package:flutter/animation.dart';
// import 'package:real_estate_app/core/api_service.dart';
// import 'package:real_estate_app/admin/admin_dashboard.dart';
// import 'package:real_estate_app/client/client_dashboard.dart';
// import 'package:real_estate_app/marketer/marketer_dashboard.dart';

// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});

//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _opacityAnimation;
//   late Animation<Offset> _slideAnimation;
//   late Animation<double> _scaleAnimation;
//   final _formKey = GlobalKey<FormState>();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   bool _loading = false;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1000),
//     );

//     _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.easeIn),
//     );

//     _slideAnimation = Tween<Offset>(
//       begin: const Offset(-1, 0),
//       end: Offset.zero,
//     ).animate(
//       CurvedAnimation(
//         parent: _controller,
//         curve: const Interval(0.2, 1.0, curve: Curves.fastOutSlowIn),
//       ),
//     );

//     _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
//     );

//     _controller.forward();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   void _handleLogin() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() {
//         _loading = true;
//       });
//       try {
//         // Use the email field as username.
//         String token = await ApiService()
//             .login(_emailController.text.trim(), _passwordController.text);
//         // Retrieve the user's profile to check their role.
//         Map<String, dynamic> profile = await ApiService().getUserProfile(token);
//         String role = profile['role'] ?? '';
//         // Navigate to the corresponding dashboard based on role.
//         if (role == 'admin') {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//                 builder: (context) => AdminDashboard(token: token)),
//           );
//         } else if (role == 'client') {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//                 builder: (context) => ClientDashboard(token: token)),
//           );
//         } else if (role == 'marketer') {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//                 builder: (context) => MarketerDashboard(token: token)),
//           );
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('User role is not defined.')),
//           );
//         }
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Login failed: $e')),
//         );
//       } finally {
//         setState(() {
//           _loading = false;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: AnimatedBuilder(
//         animation: _controller,
//         builder: (context, child) {
//           return Container(
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//                 colors: [
//                   Colors.blue.shade800,
//                   Colors.purple.shade600,
//                 ],
//               ),
//             ),
//             child: SafeArea(
//               child: Center(
//                 child: FadeTransition(
//                   opacity: _opacityAnimation,
//                   child: SlideTransition(
//                     position: _slideAnimation,
//                     child: ScaleTransition(
//                       scale: _scaleAnimation,
//                       child: Container(
//                         margin: const EdgeInsets.all(24),
//                         padding: const EdgeInsets.all(32),
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.95),
//                           borderRadius: BorderRadius.circular(20),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.2),
//                               blurRadius: 20,
//                               spreadRadius: 5,
//                             ),
//                           ],
//                         ),
//                         child: Form(
//                           key: _formKey,
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Hero(
//                                 tag: 'app-logo',
//                                 child: Image.asset(
//                                   'assets/logo.png',
//                                   height: 80,
//                                   width: 80,
//                                 ),
//                               ),
//                               const SizedBox(height: 30),
//                               TextFormField(
//                                 controller: _emailController,
//                                 decoration: InputDecoration(
//                                   prefixIcon: const Icon(Icons.email),
//                                   labelText: 'Email',
//                                   border: OutlineInputBorder(
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//                                 ),
//                                 validator: (value) {
//                                   if (value == null || value.isEmpty) {
//                                     return 'Please enter your email';
//                                   }
//                                   return null;
//                                 },
//                               ),
//                               const SizedBox(height: 20),
//                               TextFormField(
//                                 controller: _passwordController,
//                                 obscureText: true,
//                                 decoration: InputDecoration(
//                                   prefixIcon: const Icon(Icons.lock),
//                                   labelText: 'Password',
//                                   border: OutlineInputBorder(
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//                                 ),
//                                 validator: (value) {
//                                   if (value == null || value.isEmpty) {
//                                     return 'Please enter your password';
//                                   }
//                                   return null;
//                                 },
//                               ),
//                               const SizedBox(height: 25),
//                               _loading
//                                   ? const CircularProgressIndicator()
//                                   : AnimatedButton(
//                                       onPressed: _handleLogin,
//                                       animation: _controller,
//                                     ),
//                               const SizedBox(height: 20),
//                               TextButton(
//                                 onPressed: () =>
//                                     Navigator.pushNamed(context, '/forgot-password'),
//                                 child: Text(
//                                   'Forgot Password?',
//                                   style: TextStyle(
//                                     color: Colors.blue.shade800,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// class AnimatedButton extends StatelessWidget {
//   final VoidCallback onPressed;
//   final Animation<double> animation;

//   const AnimatedButton({
//     super.key,
//     required this.onPressed,
//     required this.animation,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: animation,
//       builder: (context, child) {
//         return Transform.scale(
//           scale: animation.value,
//           child: ElevatedButton(
//             onPressed: onPressed,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blue.shade800,
//               padding:
//                   const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               elevation: 5,
//               shadowColor: Colors.blue.shade200,
//             ),
//             child: const Text(
//               'Sign In',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.white,
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }



import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:real_estate_app/core/credential_storage.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/admin/admin_dashboard.dart';
import 'package:real_estate_app/client/client_dashboard.dart';
import 'package:real_estate_app/marketer/marketer_dashboard.dart';
import 'package:real_estate_app/services/navigation_service.dart';
import 'package:real_estate_app/services/push_notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  static const Color primaryColor = Color(0xFF5E35B1);
  // Form
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Error holders (for inline display)
  String? _generalError;
  String? _emailError;
  String? _passwordError;

  // Animations
  late final AnimationController _cardController;
  late final Animation<double> _opacityAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _scaleAnim;

  late final AnimationController _bgController; // background + button pulse

  bool _loading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    // Card animations
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacityAnim =
        CurvedAnimation(parent: _cardController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _cardController, curve: Curves.easeOut));
    _scaleAnim = Tween<double>(begin: 0.98, end: 1.0).animate(
        CurvedAnimation(parent: _cardController, curve: Curves.elasticOut));
    _cardController.forward();

    // Background / pulse animation (loop)
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Load saved credentials
    _loadRemembered();
  }

  Future<void> _loadRemembered() async {
    try {
      final remember = await CredentialStorage.read('remember_me');
      if (remember != null && remember == 'true') {
        final savedEmail = await CredentialStorage.read('saved_email');
        final savedPassword = await CredentialStorage.read('saved_password');
        setState(() {
          _rememberMe = true;
          if (savedEmail != null) _emailController.text = savedEmail;
          if (savedPassword != null) _passwordController.text = savedPassword;
        });
      }
    } catch (_) {
      // ignore read errors
    }
  }

  Future<void> _saveRemembered() async {
    try {
      if (_rememberMe) {
        await CredentialStorage.write('remember_me', 'true');
        await CredentialStorage.write(
            'saved_email', _emailController.text.trim());
        await CredentialStorage.write(
            'saved_password', _passwordController.text);
      } else {
        await CredentialStorage.write('remember_me', 'false');
        await CredentialStorage.delete('saved_email');
        await CredentialStorage.delete('saved_password');
      }
    } catch (_) {
      // ignore write errors
    }
  }

  @override
  void dispose() {
    _cardController.dispose();
    _bgController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _parseErrorMessage(Object error) {
    try {
      final s = error.toString();
      final start = s.indexOf('{');
      final end = s.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final jsonStr = s.substring(start, end + 1);
        final data = jsonDecode(jsonStr);
        if (data is Map) {
          if (data.containsKey('non_field_errors')) {
            final v = data['non_field_errors'];
            if (v is List) return v.join(' ');
            return v.toString();
          }
          if (data.containsKey('detail')) return data['detail'].toString();
          final parts = <String>[];
          data.forEach((k, v) {
            if (v is List) parts.addAll(v.map((e) => e.toString()));
            else parts.add(v.toString());
          });
          if (parts.isNotEmpty) return parts.join(' ');
        }
      }
    } catch (_) {}
    return error.toString();
  }

  Future<void> _handleLogin() async {
    // Reset previous errors
    setState(() {
      _generalError = null;
      _emailError = null;
      _passwordError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

    await _saveRemembered();

    try {
      final token = await ApiService()
          .login(_emailController.text.trim(), _passwordController.text);
      final profile = await ApiService().getUserProfile(token);

      await NavigationService.storeUserToken(token);
      await PushNotificationService().syncTokenWithBackend();

      final role = (profile['role'] ?? '').toString().toLowerCase();

      if (role == 'admin_support' || role == 'support') {
        Navigator.pushReplacementNamed(context, '/admin-support-dashboard', arguments: token);
      } else if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminDashboard(token: token)),
        );
      } else if (role == 'client') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ClientDashboard(token: token)),
        );
      } else if (role == 'marketer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MarketerDashboard(token: token)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User role is not defined.')),
        );
      }
    } catch (e) {
      try {
        final s = e.toString();
        final start = s.indexOf('{');
        final end = s.lastIndexOf('}');
        if (start != -1 && end != -1 && end > start) {
          final jsonStr = s.substring(start, end + 1);
          final data = jsonDecode(jsonStr);
          if (data is Map) {
            setState(() {
              if (data.containsKey('email')) {
                final v = data['email'];
                _emailError = v is List ? v.join(' ') : v.toString();
              }
              if (data.containsKey('password')) {
                final v = data['password'];
                _passwordError = v is List ? v.join(' ') : v.toString();
              }
              if (data.containsKey('non_field_errors')) {
                final v = data['non_field_errors'];
                _generalError = v is List ? v.join(' ') : v.toString();
              } else if (_generalError == null) {
                _generalError = _parseErrorMessage(e);
              }
            });
          } else {
            setState(() {
              _generalError = _parseErrorMessage(e);
            });
          }
        } else {
          setState(() {
            _generalError = _parseErrorMessage(e);
          });
        }
      } catch (_) {
        setState(() {
          _generalError = _parseErrorMessage(e);
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_generalError ?? 'Login failed: ${e.toString()}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final _fpController =
        TextEditingController(text: _emailController.text.trim());
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextFormField(
            controller: _fpController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Enter your email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final email = _fpController.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter your email')));
                  return;
                }
                Navigator.pop(context);
                try {
                  await ApiService().requestPasswordReset(email);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Password reset link sent.')));
                } catch (e) {
                  try {
                    Navigator.pushNamed(context, '/forgot-password',
                        arguments: {'email': email});
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to request reset: $e')));
                  }
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedBackground(Size size) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final t = _bgController.value;
        final double x1 =
            (size.width * 0.08) + (size.width * 0.08) * (0.5 + 0.5 * (t));
        final double y1 =
            (size.height * 0.08) + (size.height * 0.04) * (0.5 + 0.5 * (t));
        final double x2 = (size.width * 0.7) - (size.width * 0.1) * (t);
        final double y2 = (size.height * 0.68) - (size.height * 0.06) * (t);

        return Stack(
          children: [
            Positioned(
              left: x1.clamp(0.0, size.width),
              top: y1.clamp(0.0, size.height),
              child: Transform.rotate(
                angle: t * 1.8,
                child: Container(
                  width: size.width * 0.58,
                  height: size.width * 0.58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.teal.shade700.withOpacity(0.14),
                        Colors.cyan.shade600.withOpacity(0.10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(240),
                  ),
                ),
              ),
            ),
            Positioned(
              left: x2.clamp(0.0, size.width),
              top: y2.clamp(0.0, size.height),
              child: Transform.rotate(
                angle: -t * 1.1,
                child: Container(
                  width: size.width * 0.46,
                  height: size.width * 0.46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.indigo.shade600.withOpacity(0.10),
                        Colors.deepPurple.shade600.withOpacity(0.09),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(180),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.18),
                      ],
                      radius: 0.9,
                      center: const Alignment(0.0, 0.0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _animatedSignInButton(
      {required VoidCallback onPressed, required bool loading}) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final sineWave =
            0.5 + 0.5 * math.sin(_bgController.value * 2 * math.pi);
        final glow = 6 + 6 * sineWave;
        final scale = 1.0 + 0.02 * sineWave;

        return Center(
          child: Transform.scale(
            scale: scale,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: loading ? null : onPressed,
                borderRadius: BorderRadius.circular(14),
                splashFactory: InkRipple.splashFactory,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withOpacity(0.98),
                        primaryColor.withOpacity(0.78)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.18),
                        blurRadius: glow,
                        spreadRadius: 0.6,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!loading) ...[
                        const Icon(Icons.login_rounded, color: Colors.white),
                        const SizedBox(width: 12),
                        const Text(
                          'Sign In',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Signing in...',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    // Detect keyboard
    final bottomInset = mq.viewInsets.bottom;
    final keyboardOpen = bottomInset > 0.0;

    return Scaffold(
      // Prevent Scaffold from resizing when keyboard appears to avoid leaving gaps
      resizeToAvoidBottomInset: false,

      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // dark moody gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0B1020),
                  Colors.blueGrey.shade900,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // animated blobs
          _buildAnimatedBackground(size),

          // glass blur layer: reduce / remove blur when keyboard is open to avoid keyboard/blur artifact
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: keyboardOpen ? 4.0 : 12.0,
                sigmaY: keyboardOpen ? 4.0 : 12.0,
              ),
              // Use a fully transparent overlay while keyboard is open to avoid visible banding.
              child: Container(
                color: keyboardOpen
                    ? Colors.transparent
                    : Colors.black.withOpacity(0.02),
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              final maxWidth = constraints.maxWidth > 700
                  ? 560.0
                  : constraints.maxWidth * 0.94;
              return Center(
                child: SingleChildScrollView(
                  // Add bottom padding matching keyboard height so content can scroll above keyboard.
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 26,
                    bottom: 26 + bottomInset,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Back button
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pushNamed(context, '/'),
                            icon: const Icon(Icons.arrow_back_ios_new),
                            color: Colors.white70,
                            tooltip: 'Back',
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // frosted card
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: FadeTransition(
                          opacity: _opacityAnim,
                          child: SlideTransition(
                            position: _slideAnim,
                            child: ScaleTransition(
                              scale: _scaleAnim,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 28, vertical: 26),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.08),
                                        width: 1.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.28),
                                        blurRadius: 24,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Logo + text
                                        Hero(
                                          tag: 'app-logo',
                                          child: Row(
                                            children: [
                                              Image.asset(
                                                'assets/logo.png',
                                                height: 62,
                                                width: 62,
                                              ),
                                              const SizedBox(width: 12),
                                              const Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Welcome Back',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 22,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      'Sign in to continue to your dashboard',
                                                      style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 12),

                                        // General error banner
                                        if (_generalError != null)
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10, horizontal: 12),
                                            margin:
                                                const EdgeInsets.only(bottom: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color:
                                                    Colors.redAccent.withOpacity(0.2),
                                              ),
                                            ),
                                            child: Text(
                                              _generalError!,
                                              style: const TextStyle(
                                                color: Colors.redAccent,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),

                                        const SizedBox(height: 10),

                                        TextFormField(
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor:
                                                Colors.white.withOpacity(0.03),
                                            prefixIcon: const Icon(
                                                Icons.email_outlined,
                                                color: Colors.white70),
                                            labelText: 'Email',
                                            labelStyle: const TextStyle(
                                                color: Colors.white70),
                                            hintText: 'you@email.com',
                                            hintStyle: const TextStyle(
                                                color: Colors.white38),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            errorText: _emailError,
                                          ),
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty)
                                              return 'Please enter your email';
                                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                                .hasMatch(v.trim()))
                                              return 'Enter a valid email';
                                            return null;
                                          },
                                        ),

                                        const SizedBox(height: 16),

                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: _obscurePassword,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor:
                                                Colors.white.withOpacity(0.03),
                                            prefixIcon: const Icon(
                                                Icons.lock_outline,
                                                color: Colors.white70),
                                            labelText: 'Password',
                                            labelStyle: const TextStyle(
                                                color: Colors.white70),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            suffixIcon: IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePassword =
                                                      !_obscurePassword;
                                                });
                                              },
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons.visibility_outlined
                                                    : Icons
                                                        .visibility_off_outlined,
                                                color: Colors.white70,
                                              ),
                                            ),
                                            errorText: _passwordError,
                                          ),
                                          validator: (v) {
                                            if (v == null || v.isEmpty)
                                              return 'Please enter your password';
                                            if (v.length < 6)
                                              return 'Password must be at least 6 characters';
                                            return null;
                                          },
                                        ),

                                        const SizedBox(height: 12),

                                        // remember + forgot
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: _rememberMe,
                                              onChanged: (val) {
                                                setState(() {
                                                  _rememberMe = val ?? false;
                                                });
                                              },
                                              activeColor:
                                                  Color(0xFF5E35B1),
                                            ),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _rememberMe = !_rememberMe;
                                                });
                                              },
                                              child: const Text('Remember me',
                                                  style: TextStyle(
                                                      color: Colors.white70)),
                                            ),
                                            const Spacer(),
                                            TextButton(
                                              onPressed:
                                                  _showForgotPasswordDialog,
                                              child: const Text(
                                                  'Forgot password?',
                                                  style: TextStyle(
                                                      color: Colors.white70,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 16),

                                        // Beautified sign-in button (removed sign-up row)
                                        _animatedSignInButton(
                                          onPressed: _handleLogin,
                                          loading: _loading,
                                        ),

                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
