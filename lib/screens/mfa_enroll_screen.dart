// lib/screens/mfa_enroll_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'mfa_activation_screen.dart';

class MFAEnrollScreen extends StatefulWidget {
  final String username;
  final String token;
  final Function onFactorEnrolled;

  const MFAEnrollScreen({
    Key? key,
    required this.username,
    required this.token,
    required this.onFactorEnrolled,
  }) : super(key: key);

  @override
  _MFAEnrollScreenState createState() => _MFAEnrollScreenState();
}

class _MFAEnrollScreenState extends State<MFAEnrollScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableFactors = [];
  String? _error;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchAvailableFactors();
  }

  Future<void> _fetchAvailableFactors() async {
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
          _userId = userData[0]['id'];

          // Get enrolled factors to filter out
          var enrolledUrl = Uri.parse(
              'https://dev-28360987.okta.com/api/v1/users/$_userId/factors');

          final enrolledResponse = await http.get(
            enrolledUrl,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization':
                  'SSWS 00jPM8qP22_2aNupDC7YpgHJ7zXISpJx7EPwBOmhEo',
            },
          );

          if (enrolledResponse.statusCode == 200) {
            final enrolledFactors = json.decode(enrolledResponse.body);
            final enrolledFactorTypes = enrolledFactors
                .map((f) => '${f['provider']}:${f['factorType']}')
                .toSet();

            // Define available factors
            final allFactors = [
              {
                'id': 'okta:totp',
                'name': 'Okta Verify',
                'description': 'Time-based one-time passcode',
                'icon': Icons.phone_android,
                'provider': 'OKTA',
                'factorType': 'token:software:totp'
              },
              {
                'id': 'google:totp',
                'name': 'Google Authenticator',
                'description': 'Time-based one-time passcode',
                'icon': Icons.qr_code,
                'provider': 'GOOGLE',
                'factorType': 'token:software:totp'
              },
              {
                'id': 'okta:question',
                'name': 'Security Question',
                'description': 'Answer your security question',
                'icon': Icons.help_outline,
                'provider': 'OKTA',
                'factorType': 'question'
              },
            ];

            // Filter out already enrolled factors
            _availableFactors = allFactors
                .where((factor) => !enrolledFactorTypes
                    .contains('${factor['provider']}:${factor['factorType']}'))
                .toList();

            // Filter based on subscription level
            final subscription =
                userData[0]['profile']['subscription'] ?? 'basic';
            if (subscription == 'basic') {
              _availableFactors = _availableFactors
                  .where((factor) => factor['id'] == 'okta:totp')
                  .toList();
            } else if (subscription == 'premium') {
              _availableFactors = _availableFactors
                  .where((factor) =>
                      factor['id'] == 'okta:totp' ||
                      factor['id'] == 'google:totp')
                  .toList();
            }

            setState(() {
              _isLoading = false;
            });
          } else {
            setState(() {
              _error =
                  'Failed to load enrolled factors: ${enrolledResponse.statusCode}';
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

  Future<void> _enrollFactor(Map<String, dynamic> factor) async {
    setState(() {
      _isLoading = true;
    });

    try {
      var enrollUrl = Uri.parse(
          'https://dev-28360987.okta.com/api/v1/users/$_userId/factors');

      Map<String, dynamic> factorData = {
        'factorType': factor['factorType'],
        'provider': factor['provider'],
      };

      final response = await http.post(
        enrollUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'SSWS 00jPM8qP22_2aNupDC7YpgHJ7zXISpJx7EPwBOmhEo',
        },
        body: json.encode(factorData),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Navigate to activation screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MFAActivationScreen(
              username: widget.username,
              token: widget.token,
              factor: factor,
              factorResponse: responseData,
              onFactorActivated: () {
                widget.onFactorEnrolled();
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to enroll: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Authentication Method'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)))
              : _availableFactors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'All authentication methods enrolled',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You have already enrolled in all available authentication methods',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _availableFactors.length,
                      itemBuilder: (context, index) {
                        final factor = _availableFactors[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            leading: Icon(factor['icon'],
                                size: 36, color: Colors.blue),
                            title: Text(
                              factor['name'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(factor['description']),
                            trailing: ElevatedButton(
                              onPressed: () => _enrollFactor(factor),
                              child: const Text('Enroll'),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
