import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../logic/providers/app_providers.dart';
import '../dashboard/dashboard_screen.dart';

const secureStorage = FlutterSecureStorage();

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});
  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _passwordController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _canCheckBiometrics = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await auth.canCheckBiometrics;
      final isDeviceSupported = await auth.isDeviceSupported();
      setState(() => _canCheckBiometrics = canCheck && isDeviceSupported);

      if (_canCheckBiometrics) {
        final storedPass = await secureStorage.read(key: 'vault_master_pass');
        if (storedPass != null) {
          _authenticateWithBiometrics(storedPass);
        }
      }
    } catch (e) {
      log("Bio Check Error: $e");
    }
  }

  Future<void> _authenticateWithBiometrics(String password) async {
    try {
      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Unlock your vault securely',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (didAuthenticate) {
        _passwordController.text = password;
        _unlock(saveToSecureStorage: false);
      }
    } catch (e) {
      log("Bio Auth Error: $e");
    }
  }

  void _unlock({bool saveToSecureStorage = true}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      repo.deriveKey(_passwordController.text);
      await repo.initDB();

      if (saveToSecureStorage && _canCheckBiometrics) {
        await secureStorage.write(
            key: 'vault_master_pass', value: _passwordController.text);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()));
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.teal),
              const SizedBox(height: 20),
              const Text("Vaultly Locked",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Master Password',
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  errorText: _errorMessage,
                ),
                onSubmitted: (_) => _unlock(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _unlock,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.teal,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "UNLOCK",
                        style: TextStyle(color: Colors.black),
                      ),
              ),
              if (_canCheckBiometrics) ...[
                const SizedBox(height: 20),
                TextButton.icon(
                  icon: const Icon(Icons.fingerprint, size: 28),
                  label: const Text("Unlock with Biometrics"),
                  onPressed: () async {
                    final storedPass =
                        await secureStorage.read(key: 'vault_master_pass');
                    if (storedPass != null) {
                      _authenticateWithBiometrics(storedPass);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Unlock once with password first!")));
                    }
                  },
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}
