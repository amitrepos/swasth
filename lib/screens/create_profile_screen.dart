import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _profileService = ProfileService();
  final StorageService _storageService = StorageService();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _otherConditionController = TextEditingController();

  String? _selectedGender;
  String? _selectedBloodGroup;
  final List<String> _selectedConditions = [];
  bool _isLoading = false;

  final List<String> _genderOptions = ["Male", "Female", "Other"];
  final List<String> _bloodGroupOptions = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];
  // Medical condition values are API keys — do NOT translate
  final List<String> _medicalConditionOptions = [
    "Diabetes T1", "Diabetes T2", "Hypertension", "Heart Disease", "None", "Other"
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _medicationsController.dispose();
    _otherConditionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception("Not authenticated");

      final data = {
        'name': _nameController.text,
        'age': int.tryParse(_ageController.text),
        'gender': _selectedGender,
        'height': double.tryParse(_heightController.text),
        'blood_group': _selectedBloodGroup,
        'medical_conditions': _selectedConditions,
        'other_medical_condition': _selectedConditions.contains('Other')
            ? _otherConditionController.text
            : null,
        'current_medications': _medicationsController.text,
      };

      await _profileService.createProfile(token, data);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addHealthProfileTitle),
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
                    Text(
                      l10n.createProfileSubtitle,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.profileNameLabel,
                        hintText: l10n.profileNameHint,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.ageLabel,
                              prefixIcon: const Icon(Icons.calendar_today_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: InputDecoration(labelText: l10n.genderLabel),
                            items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (v) => setState(() => _selectedGender = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.heightLabel,
                              prefixIcon: const Icon(Icons.height),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedBloodGroup,
                            decoration: InputDecoration(labelText: l10n.bloodGroupLabel),
                            items: _bloodGroupOptions.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                            onChanged: (v) => setState(() => _selectedBloodGroup = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(l10n.medicalConditionsSection, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _medicalConditionOptions.map((condition) {
                        final isSelected = _selectedConditions.contains(condition);
                        return FilterChip(
                          label: Text(condition),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedConditions.add(condition);
                              } else {
                                _selectedConditions.remove(condition);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    if (_selectedConditions.contains('Other')) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _otherConditionController,
                        decoration: InputDecoration(labelText: l10n.specifyOtherCondition),
                      ),
                    ],
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _medicationsController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: l10n.medicationsLabel,
                        hintText: 'List medications separated by commas',
                      ),
                    ),

                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: Text(l10n.createProfile, style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
