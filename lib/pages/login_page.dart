import 'package:flutter/material.dart';
import 'home_page.dart';
import '../services/auth_service.dart';
import '../widgets/modern_text_field.dart';
import '../widgets/modern_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool _passwordVisible = false;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    
    if (savedEmail != null) {
      setState(() {
        emailController.text = savedEmail;
      });
    }
    if (savedPassword != null) {
      setState(() {
        passwordController.text = savedPassword;
      });
    }
  }

  Future<void> _login() async {
    setState(() {
      isLoading = true;
    });

    try {
      final result = await _authService.login(
        emailController.text.trim(),
        passwordController.text,
      );

      print('Login response: $result');

      setState(() {
        isLoading = false;
      });

      if (result['message'] == 'Login successful') {
        print('Login berhasil, navigating to HomePage...');
        
        // Simpan email dan password agar tidak perlu mengetik ulang
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_email', emailController.text.trim());
        await prefs.setString('saved_password', passwordController.text);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      print('Error in _login: $e');
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('Terjadi kesalahan saat login');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo dan form fields
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 32),
                          Image.asset(
                            'assets/images/new-logo.png',
                            height: 120,
                            width: 120,
                            color: Theme.of(context).primaryColor,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          AutofillGroup(
                            child: Column(
                              children: [
                                ModernTextField(
                                  controller: emailController,
                                  labelText: 'Email',
                                  prefixIcon: Icons.email,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                ),
                                const SizedBox(height: 16),
                                ModernTextField(
                                  controller: passwordController,
                                  labelText: 'Password',
                                  prefixIcon: Icons.lock,
                                  obscureText: !_passwordVisible,
                                  autofillHints: const [AutofillHints.password],
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _passwordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _passwordVisible = !_passwordVisible;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                print('Forgot password clicked');
                              },
                              child: Text(
                                'Lupa Password?',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Bottom section dengan login button dan register text
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Belum punya akun? ',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  print('Register clicked');
                                },
                                child: Text(
                                  'Daftar Sekarang',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ModernButton(
                            text: 'Login',
                            onPressed: _login,
                            isLoading: isLoading,
                          ),
                          const SizedBox(height: 16), // Tambahan padding di bawah
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
