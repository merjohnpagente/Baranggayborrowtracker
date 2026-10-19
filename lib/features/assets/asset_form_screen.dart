import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/models/asset.dart';
import '../../data/repositories/asset_repository.dart';
import '../../state/inventory_provider.dart';
import '../../core/widgets/common.dart';

/// Create or edit a barangay asset. Officials only.
class AssetFormScreen extends StatefulWidget {
  const AssetFormScreen({super.key, this.assetId});

  final String? assetId;

  @override
  State<AssetFormScreen> createState() => _AssetFormScreenState();
}

class _AssetFormScreenState extends State<AssetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _depositController = TextEditingController();
  final _notesController = TextEditingController();

  String? _categoryId;
  AssetStatus _status = AssetStatus.available;
  AssetCondition _condition = AssetCondition.good;
  bool _requiresApproval = true;
  String? _imageUrl;
  bool _saving = false;
  bool _loading = true;
  bool _uploading = false;

  bool get _isEditing => widget.assetId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _depositController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final inventory = context.read<InventoryProvider>();
    await inventory.loadCategories();
    final id = widget.assetId;
    if (id != null) {
      final repository = context.read<AssetRepository>();
      final asset = await repository.fetchAsset(id);
      if (!mounted) return;
      if (asset != null) {
        setState(() {
          _nameController.text = asset.name;
          _codeController.text = asset.code;
          _descriptionController.text = asset.description ?? '';
          _locationController.text = asset.location ?? '';
          _depositController.text = asset.depositAmount == 0
              ? ''
              : asset.depositAmount.toStringAsFixed(2);
          _notesController.text = asset.notes ?? '';
          _categoryId = asset.categoryId;
          _status = asset.status;
          _condition = asset.condition;
          _requiresApproval = asset.requiresApproval;
          _imageUrl = asset.imageUrl;
        });
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1400,
      imageQuality: 82,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await context
          .read<AssetRepository>()
          .uploadPhoto(Uint8List.fromList(bytes), picked.name);
      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _uploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      AppToast.error(context, 'Could not upload the photo.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final inventory = context.read<InventoryProvider>();
    final repository = context.read<AssetRepository>();
    final deposit = double.tryParse(_depositController.text.trim()) ?? 0;

    final asset = Asset(
      id: widget.assetId ?? '',
      code: _codeController.text.trim().toUpperCase(),
      name: _nameController.text.trim(),
      categoryId: _categoryId,
      description: _descriptionController.text.trim(),
      imageUrl: _imageUrl,
      status: _status,
      condition: _condition,
      location: _locationController.text.trim(),
      requiresApproval: _requiresApproval,
      depositAmount: deposit,
      notes: _notesController.text.trim(),
    );

    try {
      if (_isEditing) {
        final updated = await repository.updateAsset(widget.assetId!, asset);
        inventory.upsertLocally(updated);
      } else {
        final created = await repository.createAsset(asset);
        inventory.upsertLocally(created);
      }
      if (!mounted) return;
      AppToast.success(
        context,
        _isEditing ? 'Asset updated.' : 'Asset added to the catalogue.',
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message = error.toString();
      AppToast.error(
        context,
        message.contains('duplicate key')
            ? 'That asset code is already in use.'
            : message,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inventory = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit asset' : 'New asset'),
      ),
      body: _loading
          ? const LoadingView()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          backgroundImage:
                              _imageUrl == null ? null : NetworkImage(_imageUrl!),
                          child: _imageUrl == null
                              ? Icon(Icons.add_a_photo_outlined,
                                  size: 28, color: theme.colorScheme.primary)
                              : null,
                        ),
                        if (_uploading)
                          const CircularProgressIndicator(strokeWidth: 2.5),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () => _pickPhoto(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Camera'),
                      ),
                      TextButton.icon(
                        onPressed: () => _pickPhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Gallery'),
                      ),
                    ],
                  ),
                  const SectionHeader(title: 'BASIC INFORMATION'),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Item name',
                      hintText: 'e.g. Sound System with 2 Wireless Mics',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().length < 3)
                            ? 'Enter a clear item name'
                            : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Asset code',
                      hintText: 'BRGY-AUD-001',
                    ),
                    validator: (value) => (value == null || value.trim().length < 3)
                        ? 'Codes look like BRGY-AUD-001'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    initialValue: _categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Uncategorised'),
                      ),
                      ...inventory.categories.map(
                        (category) => DropdownMenuItem<String?>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'What is included, capacity, restrictions…',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _locationController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Storage location',
                      hintText: 'Barangay Store Room',
                    ),
                  ),
                  const SectionHeader(title: 'CONDITION & POLICY'),
                  Text(
                    'Status',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AssetStatus.values
                        .map(
                          (status) => ChoiceChip(
                            label: Text(status.label),
                            selected: _status == status,
                            onSelected: (_) => setState(() => _status = status),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Condition', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AssetCondition.values
                        .map(
                          (condition) => ChoiceChip(
                            label: Text(condition.label),
                            selected: _condition == condition,
                            onSelected: (_) =>
                                setState(() => _condition = condition),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _requiresApproval,
                    onChanged: (value) =>
                        setState(() => _requiresApproval = value),
                    title: const Text('Require approval'),
                    subtitle: const Text(
                      'Officials review each request before release',
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _depositController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Deposit or fee (₱)',
                      prefixText: '₱ ',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Internal notes (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isEditing ? 'Save changes' : 'Add asset'),
                ),
              ),
            ),
    );
  }
}