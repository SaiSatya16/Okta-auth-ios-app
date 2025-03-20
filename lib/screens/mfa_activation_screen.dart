// lib/screens/mfa_activation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MFAActivationScreen extends StatefulWidget {
  final String username;
  final String token;
  final Map<String, dynamic> factor;
  final Map<String, dynamic> factorResponse;
  final Function onFactorActivated;

  const MFAActivationScreen({
    Key? key,
    required this.username,
    required this.token,
    required this.factor,
    required this.factorResponse,
    required this.onFactorActivated,
  }) : super(key: key);

  @override
  _MFAActivationScreenState createState() => _MFAActivationScreenState();
}

class _MFAActivationScreenState extends State<MFAActivationScreen> {
  String? _userId;
  bool _isLoading = false;
  String? _error;
  final _codeController = TextEditingController();
  final _answerController = TextEditingController();
  String? _selectedQuestion;
  List<String> _securityQuestions = [
    "What was your childhood nickname?",
    "What is the name of your first pet?",
    "What was your first car?",
    "What is your favorite food?",
    "In what city were you born?",
  ];

  @override
  void dispose() {
    _codeController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _activateFactor() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      //get user info from Okta
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
            final enrolledData = json.decode(enrolledResponse.body);
            if (enrolledData['_embedded'] != null &&
                enrolledData['_embedded']['factors'] != null) {
              final enrolledFactors = enrolledData['_embedded']['factors'];
              final factorType = widget.factor['factorType'];

              // Filter out factors of the same type
              final filteredFactors = enrolledFactors
                  .where((factor) => factor['factorType'] != factorType)
                  .toList();

              if (filteredFactors.isNotEmpty) {
                // Deactivate existing factors
                for (var factor in filteredFactors) {
                  final factorId = factor['id'];
                  var deactivateUrl = Uri.parse(
                      'https://dev-28360987.okta.com/api/v1/users/$_userId/factors/$factorId/lifecycle/deactivate');

                  await http.post(
                    deactivateUrl,
                    headers: {
                      'Accept': 'application/json',
                      'Content-Type': 'application/json',
                      'Authorization':
                          'SSWS 00jPM8qP22_2aNupDC7YpgHJ7zXISpJx7EPwBOmhEo',
                    },
                  );
                }
              }
            }
          }
        }
      }

      final factorId = widget.factorResponse['id'];

      var activateUrl = Uri.parse(
          'https://dev-28360987.okta.com/api/v1/users/$_userId/factors/$factorId/lifecycle/activate');

      Map<String, dynamic> activationData = {};

      // Different payload based on factor type
      if (widget.factor['factorType'] == 'token:software:totp') {
        activationData = {
          "passCode": _codeController.text,
        };
      } else if (widget.factor['factorType'] == 'question') {
        activationData = {
          "answer": _answerController.text,
        };
      }

      final response = await http.post(
        activateUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'SSWS 00jPM8qP22_2aNupDC7YpgHJ7zXISpJx7EPwBOmhEo',
        },
        body: json.encode(activationData),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Successfully activated
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication method activated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        widget.onFactorActivated();
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _error = errorData['errorSummary'] ??
              'Failed to activate: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error: $e';
      });
    }
  }

  Future<void> _setupSecurityQuestion() async {
    if (_selectedQuestion == null || _answerController.text.isEmpty) {
      setState(() {
        _error = 'Please select a question and provide an answer';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final factorId = widget.factorResponse['id'];
      final userId = widget.factorResponse['_embedded']['user']['id'];

      var updateUrl = Uri.parse(
          'https://dev-28360987.okta.com/api/v1/users/$userId/factors/$factorId');

      final updateData = {
        "profile": {
          "question": _selectedQuestion,
          "answer": _answerController.text,
        }
      };

      final response = await http.put(
        updateUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'SSWS 00jPM8qP22_2aNupDC7YpgHJ7zXISpJx7EPwBOmhEo',
        },
        body: json.encode(updateData),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        // Successfully set up question, now activate
        _activateFactor();
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _error = errorData['errorSummary'] ??
              'Failed to set up question: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Activate ${widget.factor['name']}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.factor['provider'] == 'OKTA')
                    _buildOktaVerifyActivation()
                  else if (widget.factor['factorType'] == 'token:software:totp')
                    _buildGoogleAuthenticatorActivation()
                  else if (widget.factor['factorType'] == 'question')
                    _buildSecurityQuestionActivation(),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildOktaVerifyActivation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.phone_android, size: 48, color: Colors.blue),
        const SizedBox(height: 16),
        const Text(
          'Set up Okta Verify',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Follow these steps to set up Okta Verify:',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        _buildStepItem(
          number: 1,
          text: 'Download the Okta Verify app from the App Store',
        ),
        _buildStepItem(
          number: 2,
          text: 'Open the app and tap "Add Account"',
        ),
        _buildStepItem(
          number: 3,
          text: 'Scan this QR code with the app',
        ),
        const SizedBox(height: 24),

        // QR Code display
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
            ),
            child: widget.factorResponse['_embedded']?['activation']?['qrcode']
                        ?['href'] !=
                    null
                ? Image.network(
                    widget.factorResponse['_embedded']['activation']['qrcode']
                        ['href'],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.qr_code,
                      size: 100,
                      color: Colors.grey,
                    ),
                  )
                : const Icon(
                    Icons.qr_code,
                    size: 100,
                    color: Colors.grey,
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Manual setup code
        if (widget.factorResponse['_embedded']?['activation']
                ?['sharedSecret'] !=
            null) ...[
          const Text(
            'Or enter this code manually:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.factorResponse['_embedded']['activation']
                        ['sharedSecret'],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: widget.factorResponse['_embedded']['activation']
                        ['sharedSecret'],
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        ],

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              // For Okta Verify, we just need to confirm it's set up
              widget.onFactorActivated();
            },
            child: const Text('I\'ve Set Up Okta Verify',
                style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleAuthenticatorActivation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.qr_code, size: 48, color: Colors.blue),
        const SizedBox(height: 16),
        const Text(
          'Set up Google Authenticator',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Follow these steps to set up Google Authenticator:',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        _buildStepItem(
          number: 1,
          text: 'Download Google Authenticator from the App Store',
        ),
        _buildStepItem(
          number: 2,
          text: 'Open the app and tap "+" to add an account',
        ),
        _buildStepItem(
          number: 3,
          text: 'Scan this QR code with the app',
        ),
        const SizedBox(height: 24),

        // QR Code display
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
            ),
            child: widget.factorResponse['_embedded']?['activation']?['_links']
                        ?['qrcode']?['href'] !=
                    null
                ? Image.network(
                    widget.factorResponse['_embedded']['activation']['_links']
                        ['qrcode']['href'],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.qr_code,
                      size: 100,
                      color: Colors.grey,
                    ),
                  )
                : const Icon(
                    Icons.qr_code,
                    size: 100,
                    color: Colors.grey,
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Manual setup code
        if (widget.factorResponse['_embedded']?['activation']
                ?['sharedSecret'] !=
            null) ...[
          const Text(
            'Or enter this code manually:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.factorResponse['_embedded']['activation']
                        ['sharedSecret'],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: widget.factorResponse['_embedded']['activation']
                        ['sharedSecret'],
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),
        const Text(
          'Enter the 6-digit code from the app:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _codeController,
          decoration: const InputDecoration(
            hintText: '000000',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 8,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _activateFactor,
            child: const Text('Verify Code', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityQuestionActivation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.help_outline, size: 48, color: Colors.blue),
        const SizedBox(height: 16),
        const Text(
          'Set up Security Question',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a security question and provide an answer that you\'ll remember.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),

        // Question dropdown
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Security Question',
            border: OutlineInputBorder(),
          ),
          value: _selectedQuestion,
          items: _securityQuestions.map((question) {
            return DropdownMenuItem(
              value: question,
              child: Text(
                question,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedQuestion = value;
            });
          },
        ),
        const SizedBox(height: 16),

        // Answer field
        TextFormField(
          controller: _answerController,
          decoration: const InputDecoration(
            labelText: 'Answer',
            border: OutlineInputBorder(),
            hintText: 'Enter your answer',
          ),
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _setupSecurityQuestion,
            child: const Text('Save Security Question',
                style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem({required int number, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
