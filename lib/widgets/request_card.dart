import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../data/models/borrow_request.dart';
import 'status_chip.dart';

class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    this.onTap,
    this.showRequester = false,
    this.trailingAction,
  });

  final BorrowRequest request;
  final VoidCallback? onTap;
  final bool showRequester;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetName = request.asset?.name ?? 'Barangay asset';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.referenceNo,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  StatusChip.request(
                    context,
                    request.status.value,
                    request.status.label,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                assetName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showRequester && request.requester != null) ...[
                const SizedBox(height: 3),
                Text(
                  'Requested by ${request.requester!.fullName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${Fmt.shortDate(request.borrowDate)}  →  ${Fmt.shortDate(request.returnDate)}'
                      '  (${request.totalDays}d)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (request.isLate) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 15,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          Fmt.countdown(request.returnDate),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (trailingAction != null) ...[
                const SizedBox(height: 10),
                trailingAction!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical progress tracker: submitted → approved → released → returned.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({
    super.key,
    required this.request,
  });

  final BorrowRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final declined = request.status == RequestStatus.declined ||
        request.status == RequestStatus.cancelled;

    final steps = <_Step>[
      _Step(
        'Request submitted',
        request.createdAt,
        Icons.send_rounded,
        done: true,
      ),
      _Step(
        declined ? 'Declined' : 'Approved',
        request.reviewedAt,
        declined ? Icons.cancel_rounded : Icons.verified_rounded,
        done: request.reviewedAt != null,
        active: !declined && request.status == RequestStatus.approved,
      ),
      _Step(
        'Released',
        request.releasedAt,
        Icons.outbound_rounded,
        done: request.releasedAt != null,
        active: request.status == RequestStatus.released,
      ),
      _Step(
        'Returned',
        request.returnedAt,
        Icons.assignment_turned_in_rounded,
        done: request.returnedAt != null,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineTile(
            step: steps[i],
            isLast: i == steps.length - 1,
            theme: theme,
          ),
      ],
    );
  }
}

class _Step {
  const _Step(
    this.label,
    this.at,
    this.icon, {
    this.done = false,
    this.active = false,
  });

  final String label;
  final DateTime? at;
  final IconData icon;
  final bool done;
  final bool active;
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.step,
    required this.isLast,
    required this.theme,
  });

  final _Step step;
  final bool isLast;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final color = step.done
        ? scheme.primary
        : step.active
            ? const Color(0xFFF9A825)
            : scheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.4),
                ),
                child: Icon(step.icon, size: 15, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: step.done ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          step.done || step.active ? FontWeight.w700 : null,
                      color: step.done ? null : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (step.at != null)
                    Text(
                      Fmt.dateTime(step.at),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}