import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final TextEditingController _profileNumberController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _geographicCoordinatesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? _profileData;
  bool _isLoading = false;
  bool _isEditing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _profileNumberController.dispose();
    _linkController.dispose();
    _geographicCoordinatesController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    final profileNumber = _profileNumberController.text.trim();
    
    if (profileNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a profile number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _profileData = null;
    });

    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('profiles')
          .select('id, full_name, address, phone_number, link, geographic_coordinates')
          .eq('profile_number', int.parse(profileNumber))
          .single();

      setState(() {
        _profileData = response;
        _linkController.text = response['link'] ?? '';
        _geographicCoordinatesController.text = response['geographic_coordinates'] ?? '';
        _isLoading = false;
      });

      print('✅ Profile fetched successfully: ${response['full_name']}');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Profile not found or error: $e';
      });
      print('❌ Error fetching profile: $e');
    }
  }

  Future<void> _updateProfile() async {
    if (_profileData == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      
      await supabase
          .from('profiles')
          .update({
            'link': _linkController.text.trim().isEmpty ? null : _linkController.text.trim(),
            'geographic_coordinates': _geographicCoordinatesController.text.trim().isEmpty 
                ? null 
                : _geographicCoordinatesController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _profileData!['id']);

      setState(() {
        _isLoading = false;
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      print('✅ Profile updated successfully');
      
      // Refresh the profile data
      await _fetchProfile();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error updating profile: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      print('❌ Error updating profile: $e');
    }
  }

  String _formatAddress(dynamic address) {
    if (address == null) return 'N/A';
    if (address is String) return address;
    if (address is Map) {
      return address.values.where((v) => v != null && v.toString().isNotEmpty).join(', ');
    }
    return address.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Profile'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search Customer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _profileNumberController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Profile Number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (_) => _fetchProfile(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _fetchProfile,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (_profileData != null) ...[
              const SizedBox(height: 16),
              
              // Profile Information Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Customer Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(_isEditing ? Icons.close : Icons.edit),
                              onPressed: () {
                                setState(() {
                                  if (_isEditing) {
                                    // Cancel editing - restore original values
                                    _linkController.text = _profileData!['link'] ?? '';
                                    _geographicCoordinatesController.text = 
                                        _profileData!['geographic_coordinates'] ?? '';
                                  }
                                  _isEditing = !_isEditing;
                                });
                              },
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Read-only fields
                        _buildInfoRow('Full Name', _profileData!['full_name'] ?? 'N/A'),
                        const SizedBox(height: 12),
                        _buildInfoRow('Phone Number', _profileData!['phone_number'] ?? 'N/A'),
                        const SizedBox(height: 12),
                        _buildInfoRow('Address', _formatAddress(_profileData!['address'])),
                        const SizedBox(height: 16),

                        const Divider(),
                        const SizedBox(height: 16),

                        // Editable fields
                        const Text(
                          'Editable Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _linkController,
                          enabled: _isEditing,
                          decoration: InputDecoration(
                            labelText: 'Link',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.link),
                            filled: !_isEditing,
                            fillColor: _isEditing ? null : Colors.grey[100],
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _geographicCoordinatesController,
                          enabled: _isEditing,
                          decoration: InputDecoration(
                            labelText: 'Geographic Coordinates',
                            hintText: 'e.g., 6.9271, 79.8612',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.location_on),
                            filled: !_isEditing,
                            fillColor: _isEditing ? null : Colors.grey[100],
                          ),
                        ),

                        if (_isEditing) ...[
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _updateProfile,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: const Text('Save Changes'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
