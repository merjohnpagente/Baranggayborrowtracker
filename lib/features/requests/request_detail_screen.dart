import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/qr_payload.dart';
import '../../data/models/asset.dart';
import '../../data/models/borrow_request.dart';
import '../../state/auth_provider.dart';
import '../../state/requests_provider.dart';
import '../../core/widgets/asset_card.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/request_card.dart';
import '../../core/widgets/status_chip.dart';
import '../qr/qr_display_screen.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({
    super.key,
    required this.requestId,
    this.showRequester = false,
  });

  final String requestId;

  /// Officials see who asked for the item; residents do not need the block.
  final bool showRequester;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  BorrowRequest? _request;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request =
        await context.read<RequestsProvider>().fetchById(widget.requestId);
    if (!mounted) return;
    setState(() {
      _request = request;
      _loading = false;
    });
  }

  Future<void> _cancel() async {
    final confirmed = await _confirm(
      title: 'Cancel request?',
      message: 'This cannot be undone. You can submit a new request later.',
      actionLabel: 'Cancel request',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      final updated = await context.read<RequestsProvider>().cancel(widget.requestId);
      if (!mounted) return;
      setState(() {
        _request = updated;
        _working = false;
      });
      AppToast.success(context, 'Request cancelled.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      AppToast.error(context, _message(error));
    }
  }

  Future<void> _review(bool approve) async {
    final remarks = await _askRemarks(
      title: approve ? 'Approve request' : 'Decline request',
      label: approve ? 'Note for the resident (optional)' : 'Reason (required)',
      hint: approve
          ? 'Released at the barangay hall on the scheduled date.'
          : 'Court is reserved by the basketball league that day.',
      required: !approve,
    );
    if (remarks == null || !mounted) return;

    setState(() => _working = true);
    try {
      final updated = await context.read<RequestsProvider>().review(
            id: widget.requestId,
            approve: approve,
            remarks: remarks.isEmpty ? null : remarks,
          );
      if (!mounted) return;
      setState(() {
        _request = updated;
        _working = false;
      });
      AppToast.success(context, approve ? 'Request approved.' : 'Request declined.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      AppToast.error(context, _message(error));
    }
  }

  Future<void> _release() async {
    final confirmed = await _confirm(
      title: 'Release item?',
      message:
          'Confirm that ${_request?.asset?.name ?? 'the item'} was handed over to '
          '${_request?.requester?.fullName ?? 'the resident'}.',
      actionLabel: 'Release now',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      final updated = await context.read<RequestsProvider>().release(
            id: widget.requestId,
          );
      if (!mounted) return;
      setState(() {
        _request = updated;
        _working = false;
      });
      AppToast.success(context, 'Item released. The QR code is now active.');
      if (mounted) _showQr(updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      AppToast.error(context, _message(error));
    }
  }

  Future<void> _markReturned() async {
    var condition = AssetCondition.good;
    final remarksController = TextEditingController();
    final remarks = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Receive returned item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Condition of the item as received:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AssetCondition.values
                    .map(
                      (value) => ChoiceChip(
                        label: Text(value.label),
                        selected: condition == value,
                        onSelected: (_) =>
                            setDialogState(() => condition = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: remarksController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Remarks (optional)',
                  hintText: 'Complete, with minor scratches…',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(remarksController.text),
              child: const Text('Confirm return'),
            ),
          ],
        ),
      ),
    );
    remarksController.dispose();
    if (remarks == null || !mounted) return;

    setState(() => _working = true);
    try {
      final updated = await context.read<RequestsProvider>().markReturned(
            id: widget.requestId,
            condition: condition,
            remarks: remarks.isEmpty ? null : remarks,
          );
      if (!mounted) return;
      setState(() {
        _request = updated;
        _working = false;
      });
      AppToast.success(context, 'Return recorded. Thank you!');
    } catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      AppToast.error(context, _message(error));
    }
  }

  void _showQr(BorrowRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QrDisplayScreen(
          title: 'Release pass',
          payload: QrPayload.forRequest(request.id),
          subtitle:
              'Show this to the releasing officer. It links back to request '
              '${request.referenceNo}.',
          footer: 'Valid for ${Fmt.date(request.borrowDate)} – '
              '${Fmt.date(request.returnDate)}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final request = _request;

    if (_loading) {
      return const Scaffold(body: LoadingView());
    }
    if (request == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Request not found',
          message: 'It may have been removed from the records.',
        ),
      );
    }

    final isOwner = auth.profile?.id == request.userId;
    final actions = <Widget>[];

    if (isOwner && request.status.isCancellableByOwner) {
      actions.add(
        OutlinedButton.icon(
          onPressed: _working ? null : _cancel,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Cancel request'),
        ),
      );
    }
    // Approving is admin/approver work; releasing and receiving are
    // admin/staff work. The database enforces exactly that split, so the
    // buttons follow the same two flags instead of "is an official".
    if (auth.role.canApprove && request.status == RequestStatus.pending) {
      actions.add(
        OutlinedButton.icon(
          onPressed: _working ? null : () => _review(false),
          icon: const Icon(Icons.block_rounded),
          label: const Text('Decline'),
        ),
      );
      actions.add(
        FilledButton.icon(
          onPressed: _working ? null : () => _review(true),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Approve'),
        ),
      );
    }
    if (auth.role.canHandleAssets && request.status == RequestStatus.approved) {
      actions.add(
        FilledButton.icon(
          onPressed: _working ? null : _release,
          icon: const Icon(Icons.outbound_rounded),
          label: const Text('Release to resident'),
        ),
      );
    }
    if (auth.role.canHandleAssets && request.status.isReturnable) {
      actions.add(
        FilledButton.icon(
          onPressed: _working ? null : _markReturned,
          icon: const Icon(Icons.assignment_turned_in_rounded),
          label: const Text('Mark as returned'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(request.referenceNo),
        actions: [
          if (request.status.isReturnable)
            IconButton(
              tooltip: 'Show QR pass',
              onPressed: () => _showQr(request),
              icon: const Icon(Icons.qr_code_2_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            children: [
              StatusChip.request(
                context,
                request.status.value,
                request.status.label,
              ),
              const SizedBox(width: 8),
              if (request.isLate)
                const StatusChip(
                  label: 'Overdue',
                  color: Color(0xFFC62828),
                  icon: Icons.warning_amber_rounded,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            request.asset?.name ?? 'Barangay asset',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (widget.showRequester && request.requester != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                UserAvatar(profile: request.requester!, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.requester!.fullName,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        request.requester!.role.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  InfoRow(
                    icon: Icons.flag_outlined,
                    label: 'Purpose',
                    value: request.purpose,
                  ),
                  InfoRow(
                    icon: Icons.event_available_rounded,
                    label: 'Borrow period',
                    value: '${Fmt.date(request.borrowDate)}  →  '
                        '${Fmt.date(request.returnDate)}',
                  ),
                  InfoRow(
                    icon: Icons.timelapse_rounded,
                    label: 'Duration',
                    value: '${request.totalDays} day(s)',
                  ),
                  if (request.status.isActive)
                    InfoRow(
                      icon: Icons.notifications_active_outlined,
                      label: 'Return reminder',
                      value: Fmt.countdown(request.returnDate),
                      valueColor: request.isLate
                          ? theme.colorScheme.error
                          : null,
                    ),
                  InfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Submitted',
                    value: Fmt.dateTime(request.createdAt),
                  ),
                ],
              ),
            ),
          ),
          if (request.reviewRemarks != null &&
              request.reviewRemarks!.isNotEmpty) ...[
            const SectionHeader(title: 'OFFICIAL NOTE'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(request.reviewRemarks!,
                    style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
          if (request.returnCondition != null ||
              (request.returnRemarks != null &&
                  request.returnRemarks!.isNotEmpty)) ...[
            const SectionHeader(title: 'RETURN NOTE'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (request.returnRemarks != null &&
                        request.returnRemarks!.isNotEmpty)
                      Text(request.returnRemarks!,
                          style: theme.textTheme.bodyMedium),
                    if (request.returnCondition != null) ...[
                      if (request.returnRemarks != null &&
                          request.returnRemarks!.isNotEmpty)
                        const SizedBox(height: 8),
                      StatusChip(
                        label: 'Condition: ${request.returnCondition!.label}',
                        color: theme.colorScheme.outline,
                        icon: Icons.build_outlined,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SectionHeader(title: 'PROGRESS'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: StatusTimeline(request: request),
            ),
          ),
          if (request.asset != null) ...[
            const SectionHeader(title: 'ITEM'),
            AssetCard(
              asset: request.asset!,
              onTap: () => context.push('/assets/${request.asset!.id}'),
            ),
          ],
        ],
      ),
      bottomNavigationBar: actions.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String actionLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<String?> _askRemarks({
    required String title,
    required String label,
    required String hint,
    bool required = false,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (required && value.isEmpty) return;
              Navigator.of(context).pop(value);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}