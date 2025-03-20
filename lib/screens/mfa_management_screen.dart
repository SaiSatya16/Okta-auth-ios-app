// lib/screens/mfa_management_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'mfa_enroll_screen.dart';

class MFAManagementScreen extends StatefulWidget {
  final String username;
  final String token;

  const MFAManagementScreen({
    Key? key,
    required this.username,
    required this.token,
  }) : super(key: key);

  @override
  _MFAManagementScreenState createState() => _MFAManagementScreenState();
}

class _MFAManagementScreenState extends State<MFAManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _enrolledFactors = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchEnrolledFactors();
  }

  Future<void> _fetchEnrolledFactors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get user info from Okta
      var url = Uri.parse(
          'https://dev-28360987.okta.com/api/v1/users?filter=profile.login+eq+"${widget.username}"');

      final userResponse = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'SSWS 00jPM8qP22_2aNupDC7YpgHJ7zXISpJx7EPwBOmhEo',
        },
      );

      if (userResponse.statusCode == 200) {
        final userData = json.decode(userResponse.body);
        if (userData.isNotEmpty) {
          final userId = userData[0]['id'];

          // Get enrolled factors
          var factorsUrl = Uri.parse(
              'https://dev-28360987.okta.com/api/v1/users/$userId/factors');

          final factorsResponse = await http.get(
            factorsUrl,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization':
                  'SSWS 00jPM8qP22_2aNupDC7YpgHJ7zXISpJx7EPwBOmhEo',
            },
          );

          if (factorsResponse.statusCode == 200) {
            setState(() {
              _enrolledFactors = json.decode(factorsResponse.body);
              _isLoading = false;
            });
          } else {
            setState(() {
              _error = 'Failed to load factors: ${factorsResponse.statusCode}';
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _error = 'User not found';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Failed to load user: ${userResponse.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MFA Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _fetchEnrolledFactors,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Multi-Factor Authentication',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Secure your account with additional verification methods',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Enrolled factors
                        if (_enrolledFactors.isNotEmpty) ...[
                          const Text(
                            'Your Enrolled Factors',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._enrolledFactors
                              .map((factor) => _buildFactorItem(factor)),
                          const SizedBox(height: 24),
                        ],

                        // Add new factor button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MFAEnrollScreen(
                                    username: widget.username,
                                    token: widget.token,
                                    onFactorEnrolled: _fetchEnrolledFactors,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Add Authentication Method',
                                style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildFactorItem(dynamic factor) {
    IconData icon;
    String factorName;
    String factorDescription;

    switch (factor['provider']) {
      case 'OKTA':
        icon = Icons.phone_android;
        factorName = 'Okta Verify';
        factorDescription = 'Push notification to your device';
        break;
      case 'GOOGLE':
        icon = Icons.qr_code;
        factorName = 'Google Authenticator';
        factorDescription = 'Time-based one-time passcode';
        break;
      // case 'question':
      //   icon = Icons.help_outline;
      //   factorName = 'Security Question';
      //   factorDescription = 'Answer your security question';
      //   break;
      default:
        icon = Icons.security;
        factorName = factor['factorType'] ?? 'Unknown';
        factorDescription = 'Authentication factor';
    }

    if (factor['provider'] == 'OKTA' && factor['factorType'] == 'question') {
      icon = Icons.help_outline;
      factorName = 'Security Question';
      factorDescription = 'Answer your security question';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, size: 28, color: Colors.blue),
        title: Text(factorName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(factorDescription),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _showDeleteConfirmation(factor),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(dynamic factor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Factor'),
        content: const Text(
            'Are you sure you want to remove this authentication method? '
            'This will reduce the security of your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFactor(factor['id']);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFactor(String factorId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      var url = Uri.parse(
          'https://dev-28360987.okta.com/api/v1/users?filter=profile.login+eq+"${widget.username}"');

      final userResponse = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'SSWS 00jPM8qP22_2aNupDC7YpgHJ7zXISpJx7EPwBOmhEo',
        },
      );

      if (userResponse.statusCode == 200) {
        final userData = json.decode(userResponse.body);
        if (userData.isNotEmpty) {
          final userId = userData[0]['id'];

          // Delete factor
          var deleteUrl = Uri.parse(
              'https://dev-28360987.okta.com/api/v1/users/$userId/factors/$factorId');

          final deleteResponse = await http.delete(
            deleteUrl,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization':
                  'SSWS 00jPM8qP22_2aNupDC7YpgHJ7zXISpJx7EPwBOmhEo',
            },
          );

          if (deleteResponse.statusCode == 204) {
            // Successfully deleted
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication method removed successfully'),
                backgroundColor: Colors.green,
              ),
            );
            _fetchEnrolledFactors();
          } else {
            setState(() {
              _isLoading = false;
              _error = 'Failed to remove factor: ${deleteResponse.statusCode}';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Failed to remove factor: ${deleteResponse.statusCode}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
