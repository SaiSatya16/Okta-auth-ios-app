// lib/screens/subscription_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SubscriptionScreen extends StatefulWidget {
  final String token;
  final String currentSubscription;
  final Function onSubscriptionUpdated;

  const SubscriptionScreen({
    Key? key,
    required this.token,
    required this.currentSubscription,
    required this.onSubscriptionUpdated,
  }) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _updateSubscription(String newSubscription) async {
    if (newSubscription == widget.currentSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already on this plan')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get user info from Okta
      var userUrl = Uri.parse(
          'https://dev-28360987.okta.com/api/v1/users?filter=profile.login+eq+"${widget.token}"');

      final userResponse = await http.get(
        userUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'SSWS 00jPM8qP22_2aNupDC7YpgHJ7zXISpJx7EPwBOmhEo',
        },
      );

      if (userResponse.statusCode != 200) {
        setState(() {
          _error = 'Failed to get user info: ${userResponse.statusCode}';
          _isLoading = false;
        });
        return;
      }

      final userData = json.decode(userResponse.body);
      if (userData.isEmpty) {
        setState(() {
          _error = 'User not found';
          _isLoading = false;
        });
        return;
      }

      final userId = userData[0]['id'];

      // Update subscription
      var updateUrl =
          Uri.parse('https://dev-28360987.okta.com/api/v1/users/$userId');

      final updateData = {
        "profile": {"subscription": newSubscription}
      };

      final updateResponse = await http.post(
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

      if (updateResponse.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Successfully upgraded to $newSubscription plan')),
        );

        // Call the callback to refresh profile
        widget.onSubscriptionUpdated();

        // Navigate back
        Navigator.pop(context);
      } else {
        setState(() {
          _error =
              'Failed to update subscription: ${updateResponse.statusCode}';
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
        title: const Text('Manage Subscription'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Subscription',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current plan: ${widget.currentSubscription}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
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

                  // Basic Plan
                  _buildSubscriptionPlan(
                    title: 'Basic Plan',
                    price: 'Free',
                    features: [
                      'Okta Verify authentication',
                    ],
                    isCurrentPlan: widget.currentSubscription == 'basic',
                    onSelect: () => _updateSubscription('basic'),
                  ),

                  const SizedBox(height: 16),

                  // Premium Plan
                  _buildSubscriptionPlan(
                    title: 'Premium Plan',
                    price: '\$10/month',
                    features: [
                      'Okta Verify authentication',
                      'Google Authenticator support',
                    ],
                    isCurrentPlan: widget.currentSubscription == 'premium',
                    onSelect: () => _updateSubscription('premium'),
                  ),

                  const SizedBox(height: 16),

                  // Premium+ Plan
                  _buildSubscriptionPlan(
                    title: 'Premium+ Plan',
                    price: '\$20/month',
                    features: [
                      'Okta Verify authentication',
                      'Google Authenticator support',
                      'Security Question Authentication',
                    ],
                    isCurrentPlan: widget.currentSubscription == 'premium+',
                    onSelect: () => _updateSubscription('premium+'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSubscriptionPlan({
    required String title,
    required String price,
    required List<String> features,
    required bool isCurrentPlan,
    required VoidCallback onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentPlan ? Colors.blue.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentPlan ? Colors.blue : Colors.grey[300]!,
          width: isCurrentPlan ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isCurrentPlan)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Current',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(feature),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrentPlan ? null : onSelect,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: Text(
                isCurrentPlan ? 'Current Plan' : 'Select Plan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCurrentPlan ? Colors.grey[600] : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
