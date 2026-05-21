import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart' as loc;
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/psgc_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _storeDescriptionController = TextEditingController();
  // _vehicleTypeController removed — replaced by _selectedVehicleType dropdown
  final _plateNumberController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _streetController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  final _scrollController = ScrollController();
  int _currentStep = 1;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedGender;
  String? _selectedRole;
  String? _selectedStoreCategory;



  // Document files
  File? _buyerValidIdFile;
  File? _sellerValidIdFile;
  File? _businessPermitFile;
  File? _dtiSecFile;
  File? _driverLicenseFile;
  File? _riderValidIdFile;

  // Location dropdowns - PSGC
  List<Map<String, String>> _regions = [];
  List<Map<String, String>> _provinces = [];
  List<Map<String, String>> _cities = [];
  List<Map<String, String>> _barangays = [];
  String? _selectedRegion;
  String? _selectedProvince;
  String? _selectedCity;
  String? _selectedBarangay;
  bool _locationLoading = false;

  // Map
  final MapController _mapController = MapController();
  Marker? _locationMarker;

  final ImagePicker _picker = ImagePicker();

  // Store categories (matching web app)
  final List<String> _storeCategories = [
    'Dresses & Skirts',
    'Tops & Blouses',
    'Activewear & Yoga Pants',
    'Lingerie & Sleepwear',
    'Jackets & Coats',
    'Shoes & Accessories',
  ];

  // Vehicle types (matching web app register.html <select>)
  final List<String> _vehicleTypes = [
    'Motorcycle',
    'Bicycle',
    'Electric Bike',
    'Scooter',
    'Van',
  ];
  String? _selectedVehicleType;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  // ── PSGC Loading ────────────────────────────────────────────────────────────

  Future<void> _loadRegions() async {
    final regions = await PSGService.getRegions();
    if (mounted) {
      setState(() => _regions = regions);
    }
  }

  Future<void> _loadProvinces(String regionCode) async {
    setState(() => _locationLoading = true);
    final provinces = await PSGService.getProvinces(regionCode);

    if (mounted) {
      if (provinces.isEmpty) {
        // NCR or region without provinces - load cities directly
        _provinces = [];
        _loadCitiesByRegion(regionCode);
      } else {
        setState(() {
          _provinces = provinces;
          _cities = [];
          _barangays = [];
          _selectedProvince = null;
          _selectedCity = null;
          _selectedBarangay = null;
          _locationLoading = false;
        });
      }
    }
  }

  Future<void> _loadCitiesByRegion(String regionCode) async {
    setState(() => _locationLoading = true);
    final cities = await PSGService.getCitiesByRegion(regionCode);
    if (mounted) {
      setState(() {
        _cities = cities;
        _barangays = [];
        _selectedCity = null;
        _selectedBarangay = null;
        _locationLoading = false;
      });
    }
  }

  Future<void> _loadCities(String provinceCode) async {
    setState(() => _locationLoading = true);
    final cities = await PSGService.getCities(provinceCode);
    if (mounted) {
      setState(() {
        _cities = cities;
        _barangays = [];
        _selectedCity = null;
        _selectedBarangay = null;
        _locationLoading = false;
      });
    }
  }

  Future<void> _loadBarangays(String cityCode) async {
    setState(() => _locationLoading = true);
    final barangays = await PSGService.getBarangays(cityCode);
    if (mounted) {
      setState(() {
        _barangays = barangays;
        _selectedBarangay = null;
        _locationLoading = false;
      });
    }
  }

  // ── Map & Geolocation ───────────────────────────────────────────────────────

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _locationMarker = Marker(
        point: point,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
      );
      _latitudeController.text = point.latitude.toStringAsFixed(8);
      _longitudeController.text = point.longitude.toStringAsFixed(8);
    });

    // Reverse geocode to auto-fill address
    PSGService.reverseGeocode(point.latitude, point.longitude).then((address) {
      if (address.isNotEmpty && mounted) {
        setState(() {
          _streetController.text = '${address['house_number'] ?? ''} ${address['road'] ?? ''}'.trim();
          _zipCodeController.text = address['postcode'] ?? '';
        });
      }
    });
  }



  @override
  void dispose() {
    _scrollController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _storeNameController.dispose();
    _storeDescriptionController.dispose();
    _plateNumberController.dispose();
    _licenseNumberController.dispose();
    _streetController.dispose();
    _zipCodeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }



  // ── Image Picker ────────────────────────────────────────────────────────────

  Future<void> _pickImage(String field) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          switch (field) {
            case 'buyer_valid_id':
              _buyerValidIdFile = File(image.path);
              break;
            case 'seller_valid_id':
              _sellerValidIdFile = File(image.path);
              break;
            case 'business_permit':
              _businessPermitFile = File(image.path);
              break;
            case 'dti_sec':
              _dtiSecFile = File(image.path);
              break;
            case 'driver_license':
              _driverLicenseFile = File(image.path);
              break;
            case 'rider_valid_id':
              _riderValidIdFile = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', isError: true);
    }
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  bool _validateStep1() {
    if (_selectedGender == null || _selectedRole == null) {
      _showSnackBar('Please select gender and role', isError: true);
      return false;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnackBar('Please enter a valid email', isError: true);
      return false;
    }

    if (_passwordController.text.length < 8) {
      _showSnackBar('Password must be at least 8 characters', isError: true);
      return false;
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(_passwordController.text)) {
      _showSnackBar('Password must include at least one letter', isError: true);
      return false;
    }

    if (!RegExp(r'[0-9]').hasMatch(_passwordController.text)) {
      _showSnackBar('Password must include at least one number', isError: true);
      return false;
    }

    if (!RegExp(r'[!@#$%^&*()_+={}|;:,.<>?]').hasMatch(_passwordController.text)) {
      _showSnackBar('Password must include a special character (!@#\$%)', isError: true);
      return false;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match', isError: true);
      return false;
    }

    return true;
  }

  bool _validateStep2() {
    final role = _selectedRole!;
    if (role == 'buyer') {
      if (_buyerValidIdFile == null) {
        _showSnackBar('Please upload a valid ID', isError: true);
        return false;
      }
    } else if (role == 'seller') {
      if (_storeNameController.text.trim().isEmpty) {
        _showSnackBar('Store name is required', isError: true);
        return false;
      }
      if (_selectedStoreCategory == null) {
        _showSnackBar('Please select a store category', isError: true);
        return false;
      }
      if (_sellerValidIdFile == null || _businessPermitFile == null || _dtiSecFile == null) {
        _showSnackBar('All 3 seller documents are required', isError: true);
        return false;
      }
    } else if (role == 'rider') {
      if (_selectedVehicleType == null) {
        _showSnackBar('Please select a vehicle type', isError: true);
        return false;
      }
      if (_plateNumberController.text.trim().isEmpty || _licenseNumberController.text.trim().isEmpty) {
        _showSnackBar('Plate number and license number are required', isError: true);
        return false;
      }
      if (_driverLicenseFile == null || _riderValidIdFile == null) {
        _showSnackBar('Rider must upload driver license and valid ID', isError: true);
        return false;
      }
    }
    return true;
  }

  // Location is REQUIRED — user must select region, city, and barangay
  bool _validateStep3() {
    if (_selectedRegion == null) {
      _showSnackBar('Please select your region', isError: true);
      return false;
    }
    if (_selectedCity == null) {
      _showSnackBar('Please select your city/municipality', isError: true);
      return false;
    }
    if (_selectedBarangay == null) {
      _showSnackBar('Please select your barangay', isError: true);
      return false;
    }
    return true;
  }

  // ── Registration ────────────────────────────────────────────────────────────

  Future<void> _submitRegistration() async {
    if (!_validateStep3()) return;

    setState(() => _isLoading = true);

    try {
      final fields = <String, String>{
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text,
        'gender': _selectedGender!,
        'role': _selectedRole!,
      };

      // Optional middle name
      if (_middleNameController.text.trim().isNotEmpty) {
        fields['middle_name'] = _middleNameController.text.trim();
      }

      // Role-specific fields
      if (_selectedRole == 'seller') {
        fields['store_name'] = _storeNameController.text.trim();
        fields['store_category'] = _selectedStoreCategory!;
        fields['store_description'] = _storeDescriptionController.text.trim();
      } else if (_selectedRole == 'rider') {
        fields['vehicle_type'] = _selectedVehicleType!;
        fields['plate_number'] = _plateNumberController.text.trim();
        fields['license_number'] = _licenseNumberController.text.trim();
      }

      // Location fields (optional) - send text names, not codes
      if (_selectedRegion != null) {
        final regionName = _regions.firstWhere(
          (r) => r['code'] == _selectedRegion,
          orElse: () => {'name': ''},
        )['name'];
        if (regionName != null && regionName.isNotEmpty) {
          fields['region'] = regionName;
        }
      }
      if (_selectedProvince != null) {
        final provinceName = _provinces.firstWhere(
          (p) => p['code'] == _selectedProvince,
          orElse: () => {'name': ''},
        )['name'];
        if (provinceName != null && provinceName.isNotEmpty) {
          fields['province'] = provinceName;
        }
      }
      if (_selectedCity != null) {
        final cityName = _cities.firstWhere(
          (c) => c['code'] == _selectedCity,
          orElse: () => {'name': ''},
        )['name'];
        if (cityName != null && cityName.isNotEmpty) {
          fields['city'] = cityName;
        }
      }
      if (_selectedBarangay != null) {
        final barangayName = _barangays.firstWhere(
          (b) => b['code'] == _selectedBarangay,
          orElse: () => {'name': ''},
        )['name'];
        if (barangayName != null && barangayName.isNotEmpty) {
          fields['barangay'] = barangayName;
        }
      }
      if (_streetController.text.trim().isNotEmpty) {
        fields['street'] = _streetController.text.trim();
      }
      if (_zipCodeController.text.trim().isNotEmpty) {
        fields['zip_code'] = _zipCodeController.text.trim();
      }
      if (_latitudeController.text.trim().isNotEmpty) {
        fields['latitude'] = _latitudeController.text.trim();
      }
      if (_longitudeController.text.trim().isNotEmpty) {
        fields['longitude'] = _longitudeController.text.trim();
      }

      // Files
      final files = <String, File>{};
      if (_selectedRole == 'buyer' && _buyerValidIdFile != null) {
        files['valid_id'] = _buyerValidIdFile!;
      } else if (_selectedRole == 'seller') {
        if (_sellerValidIdFile != null) files['valid_id'] = _sellerValidIdFile!;
        if (_businessPermitFile != null) files['business_permit'] = _businessPermitFile!;
        if (_dtiSecFile != null) files['dti_or_sec'] = _dtiSecFile!;
      } else if (_selectedRole == 'rider') {
        if (_driverLicenseFile != null) files['driver_license'] = _driverLicenseFile!;
        if (_riderValidIdFile != null) files['valid_id'] = _riderValidIdFile!;
      }

      final result = await ApiService.registerFlask(fields: fields, files: files)
          .timeout(const Duration(seconds: 30), onTimeout: () => {'success': false, 'message': 'Request timed out. Please check your connection and try again.'});

      if (mounted) {
        if (result['success'] == true) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Registration Submitted!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your account is pending admin approval. You will be notified once approved.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLight,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Go to Login'),
                    ),
                  ),
                ],
              ),
            ),
          );
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        } else {
          _showSnackBar(result['message'] ?? 'Registration failed', isError: true);
        }
      }
    } on TimeoutException {
      if (mounted) {
        _showSnackBar('Request timed out. Please check your connection and try again.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Registration error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── UI Helpers ──────────────────────────────────────────────────────────────

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    // Scroll to top so user sees the snackbar context
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep == 1 && _validateStep1()) {
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2 && _validateStep2()) {
      setState(() => _currentStep = 3);
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep = _currentStep - 1);
    }
  }

  // ── Build Methods ───────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepCircle(1, 'Personal Info'),
        _buildStepLine(),
        _buildStepCircle(2, 'Documents'),
        _buildStepLine(),
        _buildStepCircle(3, 'Location'),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? AppTheme.primaryLight
                : isCompleted
                    ? Colors.green
                    : Colors.grey[300],
          ),
          child: Center(
            child: Text(
              isCompleted ? '✓' : '$step',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive || isCompleted ? AppTheme.textDark : Colors.grey,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine() {
    return Container(
      width: 40,
      height: 2,
      color: Colors.grey[300],
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppTheme.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    _buildLogo(),
                    const SizedBox(height: AppTheme.lg),
                    _buildStepIndicator(),
                    const SizedBox(height: AppTheme.lg),

                    // Form Card
                    _buildFormCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return const Column(
      children: [
        Text(
          'Grande',
          style: TextStyle(
            fontFamily: AppTheme.fontDisplay,
            fontSize: 42,
            fontWeight: FontWeight.w700,
            color: AppTheme.white,
            shadows: [
              Shadow(
                color: Color(0x55000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        Text(
          'MARKETPLACE',
          style: TextStyle(
            fontFamily: AppTheme.fontBody,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.white,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStepContent(),
            const SizedBox(height: AppTheme.lg),
            _buildNavigationButtons(),
            const SizedBox(height: AppTheme.md),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── STEP 1: Personal Info ────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Personal Information',
          style: TextStyle(
            fontFamily: AppTheme.fontDisplay,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: AppTheme.md),

        // Name fields
        Row(
          children: [
            Expanded(child: _buildTextField(_firstNameController, 'First Name', validator: _requiredValidator)),
            const SizedBox(width: AppTheme.sm),
            Expanded(child: _buildTextField(_middleNameController, 'Middle Name (optional)', required: false)),
          ],
        ),
        const SizedBox(height: AppTheme.md),
        _buildTextField(_lastNameController, 'Last Name', validator: _requiredValidator),

        // Email
        const SizedBox(height: AppTheme.md),
        _buildTextField(
          _emailController,
          'Email',
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),

        // Phone
        const SizedBox(height: AppTheme.md),
        _buildTextField(
          _phoneController,
          'Phone Number',
          keyboardType: TextInputType.phone,
          validator: _requiredValidator,
        ),

        // Gender
        const SizedBox(height: AppTheme.md),
        _buildGenderRadio(),

        // Password
        const SizedBox(height: AppTheme.md),
        _buildPasswordField(_passwordController, 'Password', _obscurePassword, (v) {
          setState(() => _obscurePassword = v!);
        }),

        // Confirm Password
        const SizedBox(height: AppTheme.md),
        _buildPasswordField(_confirmPasswordController, 'Confirm Password', _obscureConfirmPassword, (v) {
          setState(() => _obscureConfirmPassword = v!);
        }),

        // Role selection
        const SizedBox(height: AppTheme.md),
        _buildRoleSelection(),
      ],
    );
  }



  Widget _buildGenderRadio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gender *', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Male'),
                value: 'male',
                // ignore: deprecated_member_use
                groupValue: _selectedGender,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _selectedGender = v),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Female'),
                value: 'female',
                // ignore: deprecated_member_use
                groupValue: _selectedGender,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _selectedGender = v),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('I want to join as *', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildRoleCard(
                icon: '🛍️',
                label: 'Buyer',
                value: 'buyer',
                selected: _selectedRole == 'buyer',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRoleCard(
                icon: '🏪',
                label: 'Seller',
                value: 'seller',
                selected: _selectedRole == 'seller',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRoleCard(
                icon: '🏍️',
                label: 'Rider',
                value: 'rider',
                selected: _selectedRole == 'rider',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleCard({required String icon, required String label, required String value, required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryLight.withValues(alpha: 0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primaryLight : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.primaryLight : AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP 2: Documents ───────────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedRole == 'buyer') _buildBuyerDocuments(),
        if (_selectedRole == 'seller') _buildSellerDocuments(),
        if (_selectedRole == 'rider') _buildRiderDocuments(),
      ],
    );
  }

  Widget _buildBuyerDocuments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Identity Verification',
          style: TextStyle(
            fontFamily: AppTheme.fontDisplay,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Please upload a valid government-issued ID.', style: TextStyle(fontSize: 13, color: AppTheme.textLight)),
        const SizedBox(height: AppTheme.md),
        _buildDocumentUploadField(
          label: 'Valid Government ID *',
          file: _buyerValidIdFile,
          onPick: () => _pickImage('buyer_valid_id'),
        ),
      ],
    );
  }

  Widget _buildSellerDocuments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Store Details',
          style: TextStyle(
            fontFamily: AppTheme.fontDisplay,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: AppTheme.md),
        _buildTextField(_storeNameController, 'Store Name *', validator: _requiredValidator),
        const SizedBox(height: AppTheme.md),
        _buildStoreCategorySelector(),
        const SizedBox(height: AppTheme.md),
        _buildTextField(
          _storeDescriptionController,
          'Store Description',
          maxLines: 3,
          required: false,
        ),
        const SizedBox(height: AppTheme.lg),
        const Text(
          'Verification Documents',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTheme.md),
        _buildDocumentUploadField(
          label: 'Valid ID *',
          file: _sellerValidIdFile,
          onPick: () => _pickImage('seller_valid_id'),
        ),
        const SizedBox(height: AppTheme.md),
        _buildDocumentUploadField(
          label: 'Business Permit *',
          file: _businessPermitFile,
          onPick: () => _pickImage('business_permit'),
        ),
        const SizedBox(height: AppTheme.md),
        _buildDocumentUploadField(
          label: 'DTI / SEC Registration *',
          file: _dtiSecFile,
          onPick: () => _pickImage('dti_sec'),
        ),
      ],
    );
  }

  Widget _buildRiderDocuments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Vehicle & License Details',
          style: TextStyle(
            fontFamily: AppTheme.fontDisplay,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: AppTheme.md),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedVehicleType,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type *',
                  border: OutlineInputBorder(),
                ),
                items: _vehicleTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedVehicleType = v),
                validator: (v) => v == null ? 'Please select vehicle type' : null,
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            Expanded(child: _buildTextField(_plateNumberController, 'Plate Number *', validator: _requiredValidator)),
          ],
        ),
        const SizedBox(height: AppTheme.md),
        _buildTextField(_licenseNumberController, 'License Number *', validator: _requiredValidator),
        const SizedBox(height: AppTheme.lg),
        const Text(
          'Verification Documents',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTheme.md),
        _buildDocumentUploadField(
          label: "Driver's License *",
          file: _driverLicenseFile,
          onPick: () => _pickImage('driver_license'),
        ),
        const SizedBox(height: AppTheme.md),
        _buildDocumentUploadField(
          label: 'Valid ID *',
          file: _riderValidIdFile,
          onPick: () => _pickImage('rider_valid_id'),
        ),
      ],
    );
  }

  Widget _buildStoreCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Store Category *', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _storeCategories.map((category) {
            final selected = _selectedStoreCategory == category;
            return ChoiceChip(
              label: Text(category),
              selected: selected,
              onSelected: (selected) {
                setState(() {
                  _selectedStoreCategory = selected ? category : null;
                });
              },
              selectedColor: AppTheme.primaryLight,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppTheme.textDark,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDocumentUploadField({
    required String label,
    required File? file,
    required VoidCallback onPick,
  }) {
    final fileName = file != null ? file.path.split('/').last.split('\\').last : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPick,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: file != null
                  ? Border.all(color: Colors.green)
                  : Border.all(color: Colors.grey[300]!, width: 1),
              borderRadius: BorderRadius.circular(8),
              color: file != null ? Colors.green.withValues(alpha: 0.05) : null,
            ),
            child: file != null
                ? Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fileName ?? 'File selected',
                          style: const TextStyle(color: Colors.green, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: onPick,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                        child: const Text('Change', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  )
                : const Column(
                    children: [
                      Icon(Icons.upload_file, color: AppTheme.primaryLight, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Tap to upload (JPG/PDF)',
                        style: TextStyle(color: AppTheme.textLight),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ── STEP 3: Location ────────────────────────────────────────────────────────

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Your Location',
          style: TextStyle(
            fontFamily: AppTheme.fontDisplay,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Select your address for delivery', style: TextStyle(fontSize: 13, color: AppTheme.textLight)),
        const SizedBox(height: AppTheme.lg),

        // Region dropdown
        _buildPSGCDropdown(
          label: 'Region',
          value: _selectedRegion,
          items: _regions,
          onChanged: (value) {
            setState(() {
              _selectedRegion = value;
              _selectedProvince = null;
              _selectedCity = null;
              _selectedBarangay = null;
              _provinces = [];
              _cities = [];
              _barangays = [];
            });
            if (value != null) {
              _loadProvinces(value);
            }
          },
          hint: 'Select Region',
        ),
        const SizedBox(height: AppTheme.md),

        // Province dropdown
        _buildPSGCDropdown(
          label: 'Province',
          value: _selectedProvince,
          items: _provinces,
          onChanged: _provinces.isEmpty
              ? null
              : (value) {
                  setState(() {
                    _selectedProvince = value;
                    _selectedCity = null;
                    _selectedBarangay = null;
                    _cities = [];
                    _barangays = [];
                  });
                  if (value != null) {
                    _loadCities(value);
                  }
                },
          hint: _provinces.isEmpty ? 'N/A' : 'Select Province',
        ),
        const SizedBox(height: AppTheme.md),

        Row(
          children: [
            Expanded(
              child: _buildPSGCDropdown(
                label: 'City / Municipality',
                value: _selectedCity,
                items: _cities,
                onChanged: _cities.isEmpty
                    ? null
                    : (value) {
                        setState(() {
                          _selectedCity = value;
                          _selectedBarangay = null;
                          _barangays = [];
                        });
                        if (value != null) {
                          _loadBarangays(value);
                        }
                      },
                hint: _cities.isEmpty ? 'N/A' : 'Select City/Municipality',
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: _buildPSGCDropdown(
                label: 'Barangay',
                value: _selectedBarangay,
                items: _barangays,
                onChanged: _barangays.isEmpty ? null : (value) => setState(() => _selectedBarangay = value),
                hint: _barangays.isEmpty ? 'N/A' : 'Select Barangay',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.md),

        Row(
          children: [
            Expanded(
              child: _buildTextField(
                _streetController,
                'Street / House No.',
                required: false,
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            SizedBox(
              width: 120,
              child: _buildTextField(
                _zipCodeController,
                'ZIP Code',
                required: false,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),


        if (_locationLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }



  Widget _buildPSGCDropdown({
    required String label,
    required String? value,
    required List<Map<String, String>> items,
    required ValueChanged<String?>? onChanged,
    required String hint,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items.isNotEmpty
          ? items.map((item) {
              return DropdownMenuItem(
                value: item['code'],
                child: Text(
                  item['name'] ?? '',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              );
            }).toList()
          : [
              const DropdownMenuItem(
                value: null,
                child: Text('N/A', style: TextStyle(color: Colors.grey)),
              ),
            ],
      onChanged: onChanged,
      hint: Text(hint, overflow: TextOverflow.ellipsis),
      dropdownColor: AppTheme.white,
      isExpanded: true,
      icon: const Icon(Icons.arrow_drop_down, size: 20),
      borderRadius: BorderRadius.circular(8),
    );
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  Widget _buildNavigationButtons() {
    if (_currentStep == 1) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryLight,
            foregroundColor: AppTheme.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            minimumSize: const Size.fromHeight(52),
            elevation: 2,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: AppTheme.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  'Next →',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      );
    } else if (_currentStep == 2) {
      return Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _prevStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textDark,
                side: const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text(
                '← Back',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLight,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                minimumSize: const Size.fromHeight(52),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: AppTheme.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Next →',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      );
    } else if (_currentStep == 3) {
      // Step 3 - Row layout matching web: Back (flex:1), Create Account (flex:2)
      return Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _prevStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textDark,
                side: const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text(
                '← Back',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLight,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                minimumSize: const Size.fromHeight(52),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: AppTheme.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildLoginLink() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Already have an account? ",
              style: TextStyle(color: AppTheme.textLight),
            ),
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text(
                'Login',
                style: TextStyle(
                  color: AppTheme.primaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/terms'),
              child: const Text('Terms & Conditions',
                  style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
            ),
            const Text('·', style: TextStyle(color: AppTheme.textLight)),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/privacy'),
              child: const Text('Privacy Policy',
                  style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
            ),
          ],
        ),
      ],
    );
  }

  // ── Reusable Field Builders ─────────────────────────────────────────────────

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool required = true,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator ??
          (required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null),
    );
  }

  Widget _buildPasswordField(
    TextEditingController controller,
    String label,
    bool obscureText,
    ValueChanged<bool?> onToggle,
  ) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: label == 'Password' ? 'Min 8 chars, include letter, number & special (!@#\$%)' : null,
        helperMaxLines: 2,
        suffixIcon: IconButton(
          onPressed: () => onToggle(!obscureText),
          icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a password';
        }
        if (value.length < 8) {
          return 'Password must be at least 8 characters';
        }
        if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
          return 'Password must include at least one letter';
        }
        if (!RegExp(r'[0-9]').hasMatch(value)) {
          return 'Password must include at least one number';
        }
        if (!RegExp(r'[!@#\$%\^&\*\(\)_\+\-=\[\]\{\}\|;:,\.\<\>\?]').hasMatch(value)) {
          return 'Password must include at least one special character';
        }
        return null;
      },
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }
}

