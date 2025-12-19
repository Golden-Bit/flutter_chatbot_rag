import 'dart:async';
import 'dart:convert';

import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/utilities/localization.dart'; // ⬅️ IMPORT LOCALIZZAZIONI
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

// ====== Costanti UI ======
const _kMaxDialogWidth = 900.0;
const _kListPageSize   = 20;
const _kPhoneWidth     = 600.0;

// ====== Helpers ======
Color _statusColor(ActivityStatusDart s) {
  switch (s) {
    case ActivityStatusDart.pending:   return Colors.amber[700]!;
    case ActivityStatusDart.running:   return Colors.blue[700]!;
    case ActivityStatusDart.completed: return Colors.green[700]!;
    case ActivityStatusDart.error:     return Colors.red[700]!;
    default:                           return Colors.grey[600]!;
  }
}

String _statusLabel(ActivityStatusDart s, AppLocalizations loc) {
  switch (s) {
    case ActivityStatusDart.pending:
      return loc.usage_status_pending;
    case ActivityStatusDart.running:
      return loc.usage_status_running;
    case ActivityStatusDart.completed:
      return loc.usage_status_completed;
    case ActivityStatusDart.error:
      return loc.usage_status_error;
    default:
      return loc.usage_status_unknown;
  }
}

String _typeLabel(ActivityTypeDart t, AppLocalizations loc) {
  switch (t) {
    case ActivityTypeDart.uploadAsync:
      return loc.usage_type_upload;
    case ActivityTypeDart.streamEvents:
      return loc.usage_type_chat;
    default:
      return loc.usage_type_unknown;
  }
}

IconData _typeIcon(ActivityTypeDart t) {
  switch (t) {
    case ActivityTypeDart.uploadAsync:  return Icons.upload_file_rounded;
    case ActivityTypeDart.streamEvents: return Icons.message_rounded;
    default:                            return Icons.article_outlined;
  }
}

// Costo arrotondato all’intero, senza simbolo €, con separatori it_IT
String _niceMoney(double v) {
  final int rounded = v.round();
  return NumberFormat.decimalPattern('it_IT').format(rounded);
}

String _niceDateTime(DateTime? d) {
  if (d == null) return '—';
  return DateFormat('dd MMM y HH:mm', 'it_IT').format(d);
}

String _truncate(String? s, [int max = 140]) {
  if (s == null) return '';
  if (s.length <= max) return s;
  return s.substring(0, max - 1) + '…';
}

String _prettyJson(Map<String, dynamic>? m) {
  try {
    return const JsonEncoder.withIndent('  ').convert(m ?? const {});
  } catch (_) {
    return (m ?? const {}).toString();
  }
}

/// Dialog principale – legge i dati REALI via SDK
class UsageDialog extends StatefulWidget {
  const UsageDialog({
    super.key,
    required this.sdk,
    required this.username,
    required this.token,
  });

  final ContextApiSdk sdk;
  final String username;
  final String token;

  @override
  State<UsageDialog> createState() => _UsageDialogState();
}

class _UsageDialogState extends State<UsageDialog> {
  // Filtri
  DateTime? _startDate;
  DateTime? _endDate;
  String?   _statusFilter; // 'PENDING' | 'RUNNING' | 'COMPLETED' | 'ERROR' | null
  String?   _typeFilter;   // 'UPLOAD_ASYNC' | 'STREAM_EVENTS' | null
  final TextEditingController _searchCtrl = TextEditingController();

  // Lista + paginazione
  final ScrollController _scrollCtrl = ScrollController();
  final List<ActivityRecord> _items = <ActivityRecord>[];

  bool _loading = false;
  bool _initialLoad = true;
  bool _hasMore = true;
  int  _skip = 0;
  int  _limit = _kListPageSize;

  // Info aggregate
  double _totalCost = 0.0;
  int    _totalCount = 0;

  // Error banner
  String? _error;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('it_IT', null);
    // Default: ultimi 7 giorni (date-only)
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    _endDate   = DateTime(now.year, now.month, now.day);

    _scrollCtrl.addListener(_onScroll);
    unawaited(_fetch(reset: true));
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ========== DatePicker SAFE ==========
  // useRootNavigator: true per evitare l’overlay “grigio” bloccato
  Future<void> _pickDate({required bool isStart}) async {
    final loc = LocalizationProvider.of(context);
    try {
      final firstDate = DateTime(2023, 1, 1);
      final lastDate  = DateTime.now();

      DateTime initial = isStart ? (_startDate ?? DateTime.now())
                                 : (_endDate   ?? DateTime.now());

      if (initial.isBefore(firstDate)) initial = firstDate;
      if (initial.isAfter(lastDate))   initial = lastDate;

      final picked = await showDatePicker(
        context: context,
        useRootNavigator: true,
        initialDate: initial,
        firstDate: firstDate,
        lastDate: lastDate,
        locale: const Locale('it', 'IT'),
        builder: (ctx, child) {
          return Theme(
            data: Theme.of(ctx).copyWith(
              dialogBackgroundColor: Colors.white,
              colorScheme: Theme.of(ctx).colorScheme.copyWith(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                  ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      );

      if (!mounted || picked == null) return;

      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _endDate!.isBefore(_startDate!)) {
            _startDate = _endDate;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '${loc.usage_error_date_prefix} $e');
    }
  }

  // ========== Paginazione ==========
  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 240) {
      unawaited(_fetch());
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;

    final loc = LocalizationProvider.of(context);

    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _skip = 0;
        _hasMore = true;
        _initialLoad = _items.isEmpty;
      }
    });

    try {
      // endDate inclusiva (23:59:59.999)
      DateTime? endInclusive;
      if (_endDate != null) {
        endInclusive = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59, 999);
      }

      final resp = await widget.sdk.listActivities(
        username: widget.username,
        token: widget.token,
        startDate: _startDate?.toUtc(),
        endDate:   endInclusive?.toUtc(),
        type:   (_typeFilter?.isEmpty ?? true) ? null : _typeFilter,
        status: (_statusFilter?.isEmpty ?? true) ? null : _statusFilter,
        q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        skip: _skip,
        limit: _limit,
      );

      setState(() {
        if (reset) _items.clear();
        _items.addAll(resp.items);
        _skip += resp.items.length;

        _totalCost  = resp.totalCostUsd;
        _totalCount = resp.total;
        _hasMore    = _items.length < resp.total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '${loc.usage_error_load_prefix} $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _initialLoad = false;
      });
    }
  }

  void _resetFilters() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      _endDate   = DateTime(now.year, now.month, now.day);
      _statusFilter = null;
      _typeFilter   = null;
      _searchCtrl.clear();
    });
    unawaited(_fetch(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocalizationProvider.of(context);

    // Limitiamo SEMPRE l’altezza massima del dialog al 90% dello schermo:
    final media = MediaQuery.of(context);
    final maxDialogHeight = media.size.height * 0.9;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // evita bleed fuori dal raggio
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _kMaxDialogWidth,
          maxHeight: maxDialogHeight,
        ),
        child: LayoutBuilder(
          builder: (ctx, cons) {
            final bool isPhone = cons.maxWidth < _kPhoneWidth;

            // Corpo scrollabile internamente grazie a Column + Expanded sulla lista
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.max, // occupa tutta l’altezza disponibile
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitle(context, loc),
                  const SizedBox(height: 16),
                  _buildFilters(context, isPhone: isPhone, loc: loc),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(text: _error!),
                  ],
                  const SizedBox(height: 12),

                  // ⬇️ La LISTA ora usa Expanded: prende tutto lo spazio residuo e scorre
                  Expanded(
                    child: _buildListArea(context, isPhone: isPhone, loc: loc),
                  ),

                  const SizedBox(height: 8),
                  // SafeArea bottom per non tagliare su device con gesture-bar
                  SafeArea(
                    top: false,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${loc.usage_period_total_prefix} ${_niceMoney(_totalCost)} · $_totalCount ${loc.usage_period_total_suffix_activities}',
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, AppLocalizations loc) {
    return Row(
      children: [
        const Icon(Icons.bar_chart_rounded, size: 24, color: Colors.black87),
        const SizedBox(width: 8),
        Text(
          loc.usage_analysis_title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        IconButton(
          tooltip: loc.usage_refresh,
          icon: const Icon(Icons.refresh_rounded, size: 20),
          onPressed: () => _fetch(reset: true),
        ),
        IconButton(
          tooltip: loc.close,
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
        ),
      ],
    );
  }

  // ====== Filtri con layout reattivo ======
  Widget _buildFilters(
    BuildContext context, {
    required bool isPhone,
    required AppLocalizations loc,
  }) {
    String fmt(DateTime? d) =>
        d == null ? loc.usage_filter_select_placeholder
                  : DateFormat('dd MMM y', 'it_IT').format(d);

    final fields = <Widget>[
      _DateField(
        label: loc.usage_filter_from,
        text: fmt(_startDate),
        onTap: () => _pickDate(isStart: true),
      ),
      _DateField(
        label: loc.usage_filter_to,
        text: fmt(_endDate),
        onTap: () => _pickDate(isStart: false),
      ),

      // ▼▼▼  MENU COERENTI CON POPUP DELL’APP (showMenu + PopupMenuItem) ▼▼▼
      _MenuField<String>(
        label: loc.usage_filter_type,
        value: _typeFilter,
        hint: loc.usage_filter_any,
        anyLabel: loc.usage_filter_any,
        items: [
          _MenuChoice('UPLOAD_ASYNC',  loc.usage_type_upload),
          _MenuChoice('STREAM_EVENTS', loc.usage_type_chat),
        ],
        onSelected: (v) => setState(() => _typeFilter = v),
      ),
      _MenuField<String>(
        label: loc.usage_filter_status,
        value: _statusFilter,
        hint: loc.usage_filter_any,
        anyLabel: loc.usage_filter_any,
        items: [
          _MenuChoice('PENDING',   loc.usage_status_pending),
          _MenuChoice('RUNNING',   loc.usage_status_running),
          _MenuChoice('COMPLETED', loc.usage_status_completed),
          _MenuChoice('ERROR',     loc.usage_status_error),
        ],
        onSelected: (v) => setState(() => _statusFilter = v),
      ),

      _SearchField(
        controller: _searchCtrl,
        onSubmitted: (_) => _fetch(reset: true),
        loc: loc,
      ),
    ];

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: () => _fetch(reset: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(loc.usage_button_apply),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _resetFilters,
          child: Text(loc.usage_button_reset),
        ),
      ],
    );

    if (!isPhone) {
      // Desktop/tablet: 2 righe ordinate
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: fields[0]),
            const SizedBox(width: 12),
            Expanded(child: fields[1]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: fields[2]),
            const SizedBox(width: 12),
            Expanded(child: fields[3]),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: fields[4]),
            const SizedBox(width: 12),
            actions,
          ]),
        ],
      );
    }

    // Telefono: 1 colonna (campi larghi e leggibili)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(width: double.infinity, child: fields[0]),
            SizedBox(width: double.infinity, child: fields[1]),
            SizedBox(width: double.infinity, child: fields[2]),
            SizedBox(width: double.infinity, child: fields[3]),
            SizedBox(width: double.infinity, child: fields[4]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _fetch(reset: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text(loc.usage_button_apply),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _resetFilters,
              child: Text(loc.usage_button_reset),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildListArea(
    BuildContext context, {
    required bool isPhone,
    required AppLocalizations loc,
  }) {
    // NIENTE altezza fissa qui: il parent fornisce lo spazio via Expanded.
    if (_initialLoad && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(child: Text(loc.usage_no_activities));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Scrollbar(
        controller: _scrollCtrl,
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(12),
          itemCount: _items.length + 1, // +1 per loader finale
          itemBuilder: (ctx, idx) {
            if (idx == _items.length) {
              if (_loading) {
                return const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!_hasMore) return const SizedBox.shrink();
              return const SizedBox(height: 48);
            }

            final it = _items[idx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _ActivityCard(
                record: it,
                onTap: () => _openDetail(it),
                loc: loc,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openDetail(ActivityRecord base) async {
    ActivityRecord? detail;
    Object? err;

    try {
      detail = await widget.sdk.getActivityDetail(
        activityId: base.activityId,
        username: widget.username,
        token: widget.token,
      );
    } catch (e) {
      err = e;
    }

    if (!mounted) return;

    final loc = LocalizationProvider.of(context);

    await showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => _ActivityDetailDialog(
        record: detail ?? base,
        errorText: err?.toString(),
        loc: loc,
      ),
    );
  }
}

//=============================================================================
//  WIDGETS UI (cards, fields, dialog dettaglio)
//=============================================================================
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.record,
    required this.onTap,
    required this.loc,
  });

  final ActivityRecord record;
  final VoidCallback onTap;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final title = record.metadata?['filename'] as String?
        ?? record.metadata?['context'] as String?
        ?? record.metadata?['chain_id'] as String?
        ?? record.activityId;

    final subtitle = [
      _typeLabel(record.type, loc),
      if (record.startTime != null) _niceDateTime(record.startTime),
    ].join(' · ');

    final trailingText = record.costUsd != null ? _niceMoney(record.costUsd!) : '';

    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_typeIcon(record.type), size: 22, color: Colors.black87),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    if ((record.responsePreview ?? '').isNotEmpty)
                      Text(
                        _truncate(record.responsePreview, 180),
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusChip(status: record.status, loc: loc),
                  const SizedBox(height: 8),
                  if (trailingText.isNotEmpty)
                    Text(trailingText, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.loc});
  final ActivityStatusDart status;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        border: Border.all(color: c.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status, loc),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmitted,
    required this.loc,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: loc.usage_search_label,
        hintText: loc.usage_search_hint,
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: (controller.text.isEmpty)
            ? null
            : IconButton(
                tooltip: loc.usage_search_clear,
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  onSubmitted('');
                },
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// =====  Campo menù coerente con PopupMenu dell’app  =====
class _MenuChoice<T> {
  final T value;
  final String label;
  const _MenuChoice(this.value, this.label);
}

class _MenuField<T> extends StatelessWidget {
  const _MenuField({
    required this.label,
    required this.value,
    required this.items,
    required this.onSelected,
    required this.hint,
    this.includeAny = true,
    this.anyLabel = 'Qualsiasi',
  });

  final String label;
  final T? value;
  final List<_MenuChoice<T>> items;
  final ValueChanged<T?> onSelected;
  final String hint;

  final bool includeAny;
  final String anyLabel;

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (innerCtx) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final RenderBox box = innerCtx.findRenderObject() as RenderBox;
          final RenderBox overlay = Overlay.of(innerCtx).context.findRenderObject() as RenderBox;
          final Rect fieldRect = Rect.fromPoints(
            box.localToGlobal(Offset.zero, ancestor: overlay),
            box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
          );

          final List<PopupMenuEntry<T?>> entries = <PopupMenuEntry<T?>>[
            if (includeAny)
              PopupMenuItem<T?>(
                value: null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        anyLabel,
                        style: TextStyle(
                          fontWeight: (value == null) ? FontWeight.bold : FontWeight.normal,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    if (value == null) const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
            ...items.map((i) {
              final bool isSelected = value == i.value;
              return PopupMenuItem<T?>(
                value: i.value,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        i.label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    if (isSelected) const Icon(Icons.check, size: 18),
                  ],
                ),
              );
            }),
          ];

          final selected = await showMenu<T?>(
            context: innerCtx,
            position: RelativeRect.fromRect(fieldRect, Offset.zero & overlay.size),
            color: Theme.of(context).popupMenuTheme.color ?? Colors.white,
            shape: Theme.of(context).popupMenuTheme.shape ??
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            constraints: BoxConstraints(minWidth: box.size.width),
            items: entries,
          );

          if (selected != null || includeAny) {
            onSelected(selected);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
          ),
          child: Text(
            (value == null)
                ? hint
                : (items.firstWhere((e) => e.value == value).label),
            style: TextStyle(
              fontSize: 13,
              color: (value == null) ? Colors.black54 : Colors.black87,
            ),
          ),
        ),
      );
    });
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.text,
    required this.onTap,
  });

  final String label;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

// ===== Dettaglio attività =====
class _ActivityDetailDialog extends StatelessWidget {
  const _ActivityDetailDialog({
    required this.record,
    this.errorText,
    required this.loc,
  });

  final ActivityRecord record;
  final String? errorText;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxDialogHeight = media.size.height * 0.9;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760, maxHeight: maxDialogHeight),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView( // scroll se contenuto lungo
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_typeIcon(record.type), color: Colors.black87),
                    const SizedBox(width: 8),
                    Text(
                      loc.usage_detail_title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: loc.close,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _StatusChip(status: record.status, loc: loc),
                const SizedBox(height: 12),

                if (errorText != null) _ErrorBanner(text: errorText!),

                _kv(loc.usage_detail_activity_id, record.activityId),
                _kv(loc.usage_detail_user,       record.userId),
                _kv(loc.usage_detail_type,       _typeLabel(record.type, loc)),
                _kv(loc.usage_detail_status,     _statusLabel(record.status, loc)),
                _kv(
                  loc.usage_detail_cost,
                  record.costUsd != null ? _niceMoney(record.costUsd!) : '—',
                ),
                _kv(loc.usage_detail_start, _niceDateTime(record.startTime)),
                _kv(loc.usage_detail_end,   _niceDateTime(record.endTime)),
                const SizedBox(height: 8),

                _sectionTitle(loc.usage_detail_metadata),
                _monospaceBox(_prettyJson(record.metadata)),
                const SizedBox(height: 12),

                _sectionTitle(loc.usage_detail_payload),
                _monospaceBox(_prettyJson(record.payload)),
                const SizedBox(height: 12),

                _sectionTitle(loc.usage_detail_response_preview),
                _monospaceBox(
                  (record.responsePreview ?? '').isEmpty
                      ? '—'
                      : record.responsePreview!,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(fontSize: 13, color: Colors.black54))),
        Text(v, style: const TextStyle(fontSize: 13, color: Colors.black87)),
      ],
    ),
  );

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
  );

  Widget _monospaceBox(String text) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 260),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: Colors.black87),
        ),
      ),
    );
  }
}
