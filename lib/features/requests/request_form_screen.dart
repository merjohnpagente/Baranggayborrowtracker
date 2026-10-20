import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/asset.dart';
import '../../data/repositories/asset_repository.dart';
import '../../state/requests_provider.dart';
import '../../core/widgets/asset_card.dart';
import '../../core/widgets/common.dart';

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key, this.assetId});

  final String? assetId;

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();

  Asset? _asset;
  DateTime _borrowDate = DateTime.now();
  DateTime _returnDate =
      DateTime.now().add(const Duration(days: 1));
  bool _submitting = false;
  bool _checkingAvailability = false;

  /// `true` free, `false` taken, `null` not known yet / could not check.
  bool? _available;

  @override
  void initState() {
    super.initState();
    _borrowDate = _dateOnly(DateTime.now());
    _returnDate = _dateOnly(DateTime.now().add(const Duration(days: 1)));
    _load();
  }

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.assetId;
    if (id == null) return;
    final asset = await context.read<AssetRepository>().fetchAsset(id);
    if (!mounted) return;
    setState(() => _asset = asset);
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    setState(() => _checkingAvailability = true);
    final available = await context.read<RequestsProvider>().isAssetAvailable(
          assetId: widget.assetId!,
          // The reservation is the whole of the first day through the whole of
          // the last day, matching what `createRequest` stores. Checking a
          // narrower window here would say "free" for a slot that approval
          // later rejects.
          from: _dateOnly(_borrowDate),
          to: _endOfDay(_returnDate),
        );
    if (!mounted) return;
    setState(() {
      _available = available;
      _checkingAvailability = false;
    });
  }

  Future<void> _pickDate(bool isBorrow) async {
    final initial = isBorrow ? _borrowDate : _returnDate;
    final firstDate = isBorrow
        ? DateTime.now().subtract(const Duration(days: 1))
        : _borrowDate;
    final lastDate = isBorrow
        ? DateTime.now().add(const Duration(days: AppConfig.maxAdvanceDays))
        : _borrowDate.add(const Duration(days: AppConfig.maxBorrowDays));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: _dateOnly(firstDate),
      lastDate: _dateOnly(lastDate),
      helpText: isBorrow ? 'Pick-up date' : 'Return date',
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isBorrow) {
        _borrowDate = _dateOnly(picked);
        if (!_returnDate.isAfter(_borrowDate)) {
          _returnDate = _borrowDate.add(const Duration(days: 1));
        }
      } else {
        _returnDate = _dateOnly(picked);
      }
    });
    if (widget.assetId != null) _checkAvailability();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final requests = context.read<RequestsProvider>();
    final id = widget.assetId;
    if (id == null) {
      setState(() => _submitting = false);
      AppToast.error(context, 'Choose an item from the catalogue first.');
      return;
    }
    if (_available == false) {
      setState(() => _submitting = false);
      AppToast.error(
        context,
        'Those dates are already taken. Pick another day or another item.',
      );
      return;
    }

    try {
      final request = await requests.createRequest(
        assetId: id,
        purpose: _purposeController.text,
        borrowDate: _dateOnly(_borrowDate),
        returnDate: _endOfDay(_returnDate),
      );
      if (!mounted) return;
      AppToast.success(context, 'Request ${request.referenceNo} submitted.');
      context.pushReplacement('/requests/${request.id}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.error(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Request an item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            if (_asset != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_rounded,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _asset!.name,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              _asset!.code,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/assets/${_asset!.id}'),
                        child: const Text('View'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.search_rounded),
                  title: const Text('Choose an item'),
                  subtitle: const Text(
                    'Pick from the catalogue so we know what you need',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go('/assets'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SectionHeader(title: 'WHEN DO YOU NEED IT?'),
            Row(
              children: [
                Expanded(
                  child: DateField(
                    label: 'Borrow from',
                    value: _borrowDate,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DateField(
                    label: 'Return by',
                    value: _returnDate,
                    icon: Icons.event_busy_rounded,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 15, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  '${Fmt.inclusiveDays(_borrowDate, _returnDate)} day(s) · '
                  'up to ${AppConfig.maxBorrowDays} days per request',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (widget.assetId != null) ...[
              const SizedBox(height: 10),
              _availabilityNotice(theme),
            ],
            const SectionHeader(title: 'PURPOSE'),
            TextFormField(
              controller: _purposeController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Barangay basketball league finals on Saturday morning',
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  Validators.minimumLength(value, 10, 'Purpose'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Submitting sends this to the barangay office for '
                      'approval. You will see the status here once an official '
                      'reviews it.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _submitting || (_asset == null) ? null : _submit,
            icon: _submitting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              _submitting
                  ? 'Submitting…'
                  : _asset == null
                      ? 'Choose an item first'
                      : 'Submit request',
            ),
          ),
        ),
      ),
    );
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Three states, not two: checking, known (free / taken), and unknown.
  ///
  /// "Unknown" happens when the availability call fails — a dropped signal
  /// must not be shown as "taken" and must not block the request either.
  Widget _availabilityNotice(ThemeData theme) {
    if (_checkingAvailability) {
      return const Row(
        children: [
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Checking schedule…'),
        ],
      );
    }

    if (_available == null) {
      return Row(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Could not check the schedule right now. You may still submit — '
              'the office re-checks before approving.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    final free = _available!;
    final color =
        free ? const Color(0xFF169B62) : theme.colorScheme.error;
    return Row(
      children: [
        Icon(
          free ? Icons.check_circle_rounded : Icons.event_busy_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            free
                ? 'This item is free for your dates'
                : 'A confirmed booking covers these dates — pick other days.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// End of the chosen return day.
  ///
  /// A booking is stored as [start_time, end_time), so a return "on the 21st"
  /// has to end at 23:59:59 on the 21st. Storing midnight at the *start* of
  /// the 21st would make the item due a day early and let another request
  /// overlap the evening the borrower still has it.
  DateTime _endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59);
}