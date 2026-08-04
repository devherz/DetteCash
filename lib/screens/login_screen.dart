import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/user.dart';

class LoginScreen extends StatefulWidget {
  final Function(UserModel) onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  List<UserModel> _users = [];
  UserModel? _selectedUser;
  String _pinCode = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final list = await DatabaseHelper.instance.getAllUsers();
      setState(() {
        _users = list;
        if (list.isNotEmpty) {
          _selectedUser = list.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des utilisateurs: $e';
      });
    }
  }

  void _onNumberPressed(int number) {
    if (_pinCode.length < 4) {
      setState(() {
        _pinCode += number.toString();
        _errorMessage = null;
      });
      if (_pinCode.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_pinCode.isNotEmpty) {
      setState(() {
        _pinCode = _pinCode.substring(0, _pinCode.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _onClearPressed() {
    setState(() {
      _pinCode = '';
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin() async {
    if (_selectedUser == null) return;
    
    // Simulate slight delay for premium feel
    await Future.delayed(const Duration(milliseconds: 200));

    if (_selectedUser!.motDePasse == _pinCode) {
      widget.onLoginSuccess(_selectedUser!);
    } else {
      setState(() {
        _pinCode = '';
        _errorMessage = 'Code PIN incorrect. Veuillez réessayer.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    const Spacer(),
                    
                    // App Logo or Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 48,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      'DetteCash',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saisissez votre code PIN pour vous connecter',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 32),

                    // User selector Dropdown
                    if (_users.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<UserModel>(
                            value: _selectedUser,
                            isExpanded: true,
                            icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                            onChanged: (UserModel? newUser) {
                              setState(() {
                                _selectedUser = newUser;
                                _pinCode = '';
                                _errorMessage = null;
                              });
                            },
                            items: _users.map((UserModel user) {
                              return DropdownMenuItem<UserModel>(
                                value: user,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: primaryColor.withOpacity(0.2),
                                      child: Text(
                                        user.nom[0].toUpperCase(),
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      user.nom,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${user.role == "ADMIN" ? "Admin" : "Employé"})',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      )
                    else
                      const Text(
                        'Aucun utilisateur configuré. Veuillez contacter l\'administrateur.',
                        style: TextStyle(color: Colors.red),
                      ),

                    const SizedBox(height: 32),

                    // PIN display (Circles)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < _pinCode.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? primaryColor : Colors.transparent,
                            border: Border.all(
                              color: isFilled ? primaryColor : Colors.grey[400]!,
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),

                    // Error Message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const Spacer(),

                    // Number Pad
                    _buildNumPad(primaryColor),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNumPad(Color primaryColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumButton(1),
            _buildNumButton(2),
            _buildNumButton(3),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumButton(4),
            _buildNumButton(5),
            _buildNumButton(6),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumButton(7),
            _buildNumButton(8),
            _buildNumButton(9),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Clear Button (left)
            _buildActionButton(
              icon: Icons.clear,
              onPressed: _onClearPressed,
              tooltip: 'Effacer tout',
            ),
            _buildNumButton(0),
            // Backspace Button (right)
            _buildActionButton(
              icon: Icons.backspace_outlined,
              onPressed: _onBackspacePressed,
              tooltip: 'Supprimer',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumButton(int number) {
    return InkWell(
      onTap: () => _onNumberPressed(number),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[200]!, width: 1.5),
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required VoidCallback onPressed, required String tooltip}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        child: Center(
          child: Icon(
            icon,
            size: 24,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
