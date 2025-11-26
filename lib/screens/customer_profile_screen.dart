import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class CustomerProfileScreen extends StatefulWidget {
  final int? initialProfileNumber;

  const CustomerProfileScreen({super.key, this.initialProfileNumber});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final TextEditingController _profileNumberController =
      TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _geographicCoordinatesController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? _profileData;
  bool _isLoading = false;
  bool _isEditing = false;
  String? _errorMessage;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // If initial profile number is provided, set it and fetch profile
    if (widget.initialProfileNumber != null) {
      _profileNumberController.text = widget.initialProfileNumber.toString();
      // Fetch profile after the widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchProfile();
      });
    }
  }

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

      final response =
          await supabase
              .from('profiles')
              .select(
                'id, full_name, address, phone_number, link, geographic_coordinates, gate_image',
              )
              .eq('profile_number', int.parse(profileNumber))
              .single();

      setState(() {
        _profileData = response;
        _linkController.text = response['link'] ?? '';
        _geographicCoordinatesController.text =
            response['geographic_coordinates'] ?? '';
        _selectedImage = null; // Reset selected image
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
            'link':
                _linkController.text.trim().isEmpty
                    ? null
                    : _linkController.text.trim(),
            'geographic_coordinates':
                _geographicCoordinatesController.text.trim().isEmpty
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

  // Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        print('✅ Image selected: ${pickedFile.path}');
      }
    } catch (e) {
      print('❌ Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Compress image to reduce file size below 100KB
  Future<File?> _compressImage(File file) async {
    try {
      print('🔄 Compressing image...');
      final String targetPath = path.join(
        path.dirname(file.path),
        '${path.basenameWithoutExtension(file.path)}_compressed${path.extension(file.path)}',
      );

      const int maxSizeInBytes = 100 * 1024; // 100KB
      int quality = 85;
      int minWidth = 1200;
      int minHeight = 900;
      File? compressedFile;

      // Iteratively compress until file size is below 100KB
      while (quality >= 10) {
        final XFile? result = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: quality,
          minWidth: minWidth,
          minHeight: minHeight,
        );

        if (result != null) {
          compressedFile = File(result.path);
          final fileSize = await compressedFile.length();

          print(
            '🔄 Compression attempt: quality=$quality, size=${(fileSize / 1024).toStringAsFixed(2)} KB',
          );

          if (fileSize <= maxSizeInBytes) {
            final originalSize = await file.length();
            print(
              '✅ Image compressed successfully: ${(originalSize / 1024).toStringAsFixed(2)} KB → ${(fileSize / 1024).toStringAsFixed(2)} KB',
            );
            return compressedFile;
          }

          // Reduce quality and dimensions for next iteration
          quality -= 15;
          minWidth = (minWidth * 0.8).toInt();
          minHeight = (minHeight * 0.8).toInt();

          // Delete the oversized compressed file
          await compressedFile.delete();
        } else {
          break;
        }
      }

      // If we couldn't compress below 100KB, return the last attempt
      print(
        '⚠️ Warning: Could not compress image below 100KB. Returning best effort.',
      );
      return compressedFile ?? file;
    } catch (e) {
      print('❌ Error compressing image: $e');
      return file; // Return original if compression fails
    }
  }

  // Upload image to Supabase storage
  Future<String?> _uploadImageToStorage(File imageFile) async {
    try {
      print('📤 Uploading image to Supabase storage...');

      final supabase = Supabase.instance.client;
      final String fileName =
          '${_profileData!['id']}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final String filePath = fileName;

      // Upload to Supabase storage
      await supabase.storage
          .from('customer_profile')
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Get public URL
      final String publicUrl = supabase.storage
          .from('customer_profile')
          .getPublicUrl(filePath);

      print('✅ Image uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // Save gate image
  Future<void> _saveGateImage() async {
    if (_selectedImage == null || _profileData == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Compress image
      final compressedImage = await _compressImage(_selectedImage!);
      if (compressedImage == null) {
        throw Exception('Failed to compress image');
      }

      // Upload to storage
      final imageUrl = await _uploadImageToStorage(compressedImage);
      if (imageUrl == null) {
        throw Exception('Failed to upload image');
      }

      // Update database
      final supabase = Supabase.instance.client;
      await supabase
          .from('profiles')
          .update({
            'gate_image': imageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _profileData!['id']);

      setState(() {
        _profileData!['gate_image'] = imageUrl;
        _selectedImage = null;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gate image uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );

      print('✅ Gate image saved successfully');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error uploading image: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );

      print('❌ Error saving gate image: $e');
    }
  }

  // Show image source selection dialog
  Future<void> _showImageSourceDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Show full-size image when tapped
  void _showFullSizeImage(
    BuildContext context, {
    String? imageUrl,
    File? imageFile,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child:
                          imageFile != null
                              ? Image.file(
                                imageFile,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                              )
                              : Image.network(
                                imageUrl!,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 48,
                                          color: Colors.red,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Failed to load image',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                    ),
                  ),
                  SafeArea(
                    child: Positioned(
                      top: 16,
                      left: 16,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  String _formatAddress(dynamic address) {
    if (address == null) return 'N/A';
    if (address is String) return address;
    if (address is Map) {
      return address.values
          .where((v) => v != null && v.toString().isNotEmpty)
          .join(', ');
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
                          child:
                              _isLoading
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
                                    _linkController.text =
                                        _profileData!['link'] ?? '';
                                    _geographicCoordinatesController.text =
                                        _profileData!['geographic_coordinates'] ??
                                        '';
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
                        _buildInfoRow(
                          'Full Name',
                          _profileData!['full_name'] ?? 'N/A',
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Phone Number',
                          _profileData!['phone_number'] ?? 'N/A',
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Address',
                          _formatAddress(_profileData!['address']),
                        ),
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
                              icon:
                                  _isLoading
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
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

                        // Gate Image Section
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'Gate Image',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Display existing gate image or selected image
                        if (_profileData!['gate_image'] != null ||
                            _selectedImage != null) ...[
                          GestureDetector(
                            onTap: () {
                              if (_selectedImage != null) {
                                _showFullSizeImage(
                                  context,
                                  imageFile: _selectedImage,
                                );
                              } else if (_profileData!['gate_image'] != null) {
                                _showFullSizeImage(
                                  context,
                                  imageUrl: _profileData!['gate_image'],
                                );
                              }
                            },
                            child: Container(
                              height: 250,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child:
                                        _selectedImage != null
                                            ? Image.file(
                                              _selectedImage!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            )
                                            : Image.network(
                                              _profileData!['gate_image'],
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                              loadingBuilder: (
                                                context,
                                                child,
                                                loadingProgress,
                                              ) {
                                                if (loadingProgress == null)
                                                  return child;
                                                return Center(
                                                  child: CircularProgressIndicator(
                                                    value:
                                                        loadingProgress
                                                                    .expectedTotalBytes !=
                                                                null
                                                            ? loadingProgress
                                                                    .cumulativeBytesLoaded /
                                                                loadingProgress
                                                                    .expectedTotalBytes!
                                                            : null,
                                                  ),
                                                );
                                              },
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                return const Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.error_outline,
                                                        size: 48,
                                                        color: Colors.red,
                                                      ),
                                                      SizedBox(height: 8),
                                                      Text(
                                                        'Failed to load image',
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                  ),
                                  // Overlay icon to indicate image is tappable
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.zoom_in,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[100],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No gate image uploaded',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Image action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _isLoading ? null : _showImageSourceDialog,
                                icon: const Icon(Icons.add_photo_alternate),
                                label: Text(
                                  _selectedImage != null
                                      ? 'Change Image'
                                      : 'Select Image',
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ),
                            if (_selectedImage != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _saveGateImage,
                                  icon:
                                      _isLoading
                                          ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                          : const Icon(Icons.cloud_upload),
                                  label: const Text('Upload'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(12),
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
