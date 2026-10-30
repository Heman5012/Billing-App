import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _currency = '₹';
  List<double> _taxRates = [0.0, 5.0, 12.0, 18.0, 28.0];
  bool _isSaving = false;
  bool _isLoaded = false;

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile(BusinessProfile profile) {
    if (!_isLoaded) {
      _businessNameCtrl.text = profile.businessName;
      _addressCtrl.text = profile.address;
      _phoneCtrl.text = profile.phone;
      _currency = profile.currency;
      _taxRates = List.from(profile.configuredTaxRates);
      _isLoaded = true;
    }
  }

  Future<void> _saveSettings(String uid) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updatedProfile = BusinessProfile(
        businessName: _businessNameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        currency: _currency,
        configuredTaxRates: _taxRates,
      );

      await FirebaseService.instance.saveBusinessProfile(uid, updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business settings updated successfully.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save settings: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to access settings.'));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<BusinessProfile>(
        stream: FirebaseService.instance.streamBusinessProfile(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasData && !_isLoaded) {
            _initFromProfile(snapshot.data!);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Business & Invoice Settings',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customize business branding, currency, and tax configurations appearing on PDF invoices',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Card(
                        elevation: 1,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Store Profile',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _businessNameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Store / Business Name *',
                                  prefixIcon: Icon(Icons.storefront_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Business name is required'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _addressCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Physical Address',
                                  prefixIcon: Icon(Icons.location_on_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Business Contact Phone',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Card(
                        elevation: 1,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Financial Preferences',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: _currency,
                                decoration: const InputDecoration(
                                  labelText: 'Default Currency Symbol',
                                  prefixIcon: Icon(Icons.currency_exchange),
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: '₹',
                                    child: Text('₹ (INR - Indian Rupee)'),
                                  ),
                                  DropdownMenuItem(
                                    value: '\$',
                                    child: Text('\$ (USD - US Dollar)'),
                                  ),
                                  DropdownMenuItem(
                                    value: '€',
                                    child: Text('€ (EUR - Euro)'),
                                  ),
                                  DropdownMenuItem(
                                    value: '£',
                                    child: Text('£ (GBP - British Pound)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'AED ',
                                    child: Text('AED (UAE Dirham)'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _currency = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Configured Tax Rates (%)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'These rates are available when adding products or creating bills.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                children: [0.0, 5.0, 12.0, 18.0, 28.0].map((
                                  rate,
                                ) {
                                  final isChecked = _taxRates.contains(rate);
                                  return FilterChip(
                                    label: Text('${rate.toStringAsFixed(0)}%'),
                                    selected: isChecked,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _taxRates.add(rate);
                                        } else {
                                          if (_taxRates.length > 1) {
                                            _taxRates.remove(rate);
                                          }
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () => _saveSettings(user.uid),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save Settings',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
