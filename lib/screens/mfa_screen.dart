// lib/screens/mfa_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MfaScreen extends StatefulWidget {
  final String token;
  final String subscription;

  const MfaScreen({
    Key? key,
    required this.token,
    required this.subscription,
  }) : super(key: key);

  @override
  _MfaScreenState createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  bool _isLoading = true;
  List<dynamic> _supportedFactors = [];
  List<dynamic> _enrolledFactors = [];
  String? _error;
  String? _enrollingFactor;
  bool _showSecurityQuestionForm = false;

  // Security question form fields
  final _securityQuestionController = TextEditingController();
  final _securityAnswerController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchMfaFactors();
  }

  @override
  void dispose() {
    _securityQuestionController.dispose();
    _securityAnswerController.dispose();
    super.dispose();
  }

  Future<void> _fetchMfaFactors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      var url =
          Uri.parse('https://dev-28360987.okta.com/api/v1/users/me/factors');

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Get enrolled factors
        setState(() {
          _enrolledFactors = responseData;
          _isLoading = false;
        });

        // Now fetch supported factors
        await _fetchSupportedFactors();
      } else {
        setState(() {
          _error = 'Failed to load MFA factors: ${response.statusCode}';
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

  Future<void> _fetchSupportedFactors() async {
    try {
      var url = Uri.parse(
          'https://dev-28360987.okta.com/api/v1/users/me/factors/catalog');

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Filter factors based on subscription
        List<dynamic> filteredFactors = [];
        for (var factor in responseData) {
          String factorType = factor['factorType'] ?? '';
          String provider = factor['provider'] ?? '';

          // Basic subscription only gets Okta Verify
          if (widget.subscription == 'basic') {
            if (provider == 'OKTA' && factorType == 'token:software:totp') {
              filteredFactors.add(factor);
            }
          }
          // Premium gets Okta Verify and Google Authenticator
          else if (widget.subscription == 'premium') {
            if ((provider == 'OKTA' || provider == 'GOOGLE') &&
                factorType == 'token:software:totp') {
              filteredFactors.add(factor);
            }
          }
          // Premium+ gets everything
          else if (widget.subscription == 'premium+') {
            filteredFactors.add(factor);
          }
        }

        setState(() {
          _supportedFactors = filteredFactors;
        });
      } else {
        setState(() {
          _error = 'Failed to load supported factors: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    }
  }

  Future<void> _enrollFactor(String factorType, String provider) async {
    setState(() {
      _enrollingFactor = '$factorType:$provider';
      _error = null;
    });

    // For security question, show the form instead of directly enrolling
    if (factorType == 'question') {
      setState(() {
        _showSecurityQuestionForm = true;
        _enrollingFactor = null;
      });
      return;
    }

    try {
      var url =
          Uri.parse('https://dev-28360987.okta.com/api/v1/users/me/factors');

      // Prepare factor data based on type
      Map<String, dynamic> factorData = {
        'factorType': factorType,
        'provider': provider
      };

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'
        },
        body: json.encode(factorData),
      );

      setState(() {
        _enrollingFactor = null;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Successfully enrolled
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Successfully enrolled in ${_getFriendlyFactorName(factorType, provider)}')),
        );

        // Refresh factors list
        _fetchMfaFactors();
      } else {
        // Enrollment failed
        final errorData = json.decode(response.body);
        String errorMessage = 'Failed to enroll in factor';

        if (errorData.containsKey('errorCauses') &&
            errorData['errorCauses'].length > 0) {
          errorMessage = errorData['errorCauses'][0]['errorSummary'];
        }

        setState(() {
          _error = errorMessage;
        });
      }
    } catch (e) {
      setState(() {
        _enrollingFactor = null;
        _error = 'Error: $e';
      });
    }
  }

  Future<void> _enrollSecurityQuestion() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _enrollingFactor = 'question:OKTA';
      _error = null;
    });

    try {
      var url =
          Uri.parse('https://dev-28360987.okta.com/api/v1/users/me/factors');

      // Prepare security question data
      Map<String, dynamic> factorData = {
        'factorType': 'question',
        'provider': 'OKTA',
        'profile': {
          'question': _securityQuestionController.text,
          'answer': _securityAnswerController.text
        }
      };

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'
        },
        body: json.encode(factorData),
      );

      setState(() {
        _enrollingFactor = null;
        _showSecurityQuestionForm = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Successfully enrolled
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Security question enrolled successfully')),
        );

        // Clear form
        _securityQuestionController.clear();
        _securityAnswerController.clear();

        // Refresh factors list
        _fetchMfaFactors();
      } else {
        // Enrollment failed
        final errorData = json.decode(response.body);
        String errorMessage = 'Failed to enroll security question';

        if (errorData.containsKey('errorCauses') &&
            errorData['errorCauses'].length > 0) {
          errorMessage = errorData['errorCauses'][0]['errorSummary'];
        }

        setState(() {
          _error = errorMessage;
        });
      }
    } catch (e) {
      setState(() {
        _enrollingFactor = null;
        _error = 'Error: $e';
      });
    }
  }

  String _getFriendlyFactorName(String factorType, String provider) {
    if (factorType == 'question') {
      return 'Security Question';
    } else if (factorType == 'token:software:totp') {
      if (provider == 'OKTA') {
        return 'Okta Verify';
      } else if (provider == 'GOOGLE') {
        return 'Google Authenticator';
      }
    }
    return '$provider $factorType';
  }

  bool _isFactorEnrolled(String factorType, String provider) {
    return _enrolledFactors.any((factor) =>
        factor['factorType'] == factorType && factor['provider'] == provider);
  }

// lib/screens/mfa_screen.dart (continued)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Factor Authentication'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _showSecurityQuestionForm
              ? _buildSecurityQuestionForm()
              : _buildFactorsList(),
    );
  }

  Widget _buildFactorsList() {
    return RefreshIndicator(
      onRefresh: _fetchMfaFactors,
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
              'Add extra security to your account with multi-factor authentication methods.',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            if (_supportedFactors.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'No MFA factors available for your subscription level.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ..._supportedFactors.map((factor) {
                final factorType = factor['factorType'];
                final provider = factor['provider'];
                final isEnrolled = _isFactorEnrolled(factorType, provider);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getFactorIcon(factorType, provider),
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getFriendlyFactorName(factorType, provider),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getFactorDescription(factorType, provider),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isEnrolled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'Enrolled',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          ElevatedButton(
                            onPressed:
                                _enrollingFactor == '$factorType:$provider'
                                    ? null
                                    : () => _enrollFactor(factorType, provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: _enrollingFactor == '$factorType:$provider'
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Enroll'),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityQuestionForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Up Security Question',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _securityQuestionController,
              decoration: const InputDecoration(
                labelText: 'Security Question',
                hintText: 'What was your first pet\'s name?',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a security question';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _securityAnswerController,
              decoration: const InputDecoration(
                labelText: 'Answer',
                hintText: 'Enter your answer',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your answer';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _enrollingFactor != null
                        ? null
                        : _enrollSecurityQuestion,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _enrollingFactor != null
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Security Question'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _enrollingFactor != null
                  ? null
                  : () {
                      setState(() {
                        _showSecurityQuestionForm = false;
                      });
                    },
              child: const Text('Cancel'),
            ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getFactorIcon(String factorType, String provider) {
    if (factorType == 'question') {
      return Icons.help_outline;
    } else if (factorType == 'token:software:totp') {
      if (provider == 'OKTA') {
        return Icons.security;
      } else if (provider == 'GOOGLE') {
        return Icons.phone_android;
      }
    }
    return Icons.security;
  }

  String _getFactorDescription(String factorType, String provider) {
    if (factorType == 'question') {
      return 'Answer a security question to verify your identity';
    } else if (factorType == 'token:software:totp') {
      if (provider == 'OKTA') {
        return 'Use Okta Verify app to generate verification codes';
      } else if (provider == 'GOOGLE') {
        return 'Use Google Authenticator to generate verification codes';
      }
    }
    return 'Additional security factor';
  }
}
