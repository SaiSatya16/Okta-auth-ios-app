// lib/screens/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditProfileScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> profile;
  final Function onProfileUpdated;

  const EditProfileScreen({
    Key? key,
    required this.token,
    required this.profile,
    required this.onProfileUpdated,
  }) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _mobilePhoneController;
  late TextEditingController _secondEmailController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late String _countryCode;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile['profile'] ?? {};

    _firstNameController =
        TextEditingController(text: profile['firstName'] ?? '');
    _lastNameController =
        TextEditingController(text: profile['lastName'] ?? '');
    _mobilePhoneController =
        TextEditingController(text: profile['mobilePhone'] ?? '');
    _secondEmailController =
        TextEditingController(text: profile['secondEmail'] ?? '');
    _cityController = TextEditingController(text: profile['city'] ?? '');
    _stateController = TextEditingController(text: profile['state'] ?? '');
    _countryCode = profile['countryCode'] ?? '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobilePhoneController.dispose();
    _secondEmailController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final userId = widget.profile['id'];
        var url =
            Uri.parse('https://dev-28360987.okta.com/api/v1/users/$userId');

        // Prepare updated profile data
        final updatedProfile = {
          "profile": {
            "firstName": _firstNameController.text,
            "lastName": _lastNameController.text,
            "mobilePhone": _mobilePhoneController.text,
            "secondEmail": _secondEmailController.text,
            "city": _cityController.text,
            "state": _stateController.text,
            "countryCode": _countryCode,
          }
        };

        final response = await http.post(
          url,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'SSWS 00jPM8qP22_2aNupDC7YpgHJ7zXISpJx7EPwBOmhEo',
          },
          body: json.encode(updatedProfile),
        );

        setState(() {
          _isLoading = false;
        });

        if (response.statusCode == 200) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Refresh profile data
          widget.onProfileUpdated();

          // Navigate back
          Navigator.pop(context);
        } else {
          // Handle error
          final errorData = json.decode(response.body);
          setState(() {
            _error = errorData['errorSummary'] ??
                'Failed to update profile: ${response.statusCode}';
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _error = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // First Name
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Last Name
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mobile Phone
                    TextFormField(
                      controller: _mobilePhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Phone',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Secondary Email
                    TextFormField(
                      controller: _secondEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Secondary Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // City
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // State
                    TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        labelText: 'State/Province',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Country
                    DropdownButtonFormField<String>(
                      value: _countryCode.isNotEmpty ? _countryCode : null,
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'US', child: Text('United States')),
                        DropdownMenuItem(value: 'CA', child: Text('Canada')),
                        DropdownMenuItem(
                            value: 'UK', child: Text('United Kingdom')),
                        DropdownMenuItem(value: 'AU', child: Text('Australia')),
                        DropdownMenuItem(value: 'IN', child: Text('India')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _countryCode = value ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Error message
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Update button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateProfile,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Save Changes',
                                style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
