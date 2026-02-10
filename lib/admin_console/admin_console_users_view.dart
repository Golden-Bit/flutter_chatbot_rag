import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:boxed_ai/user_manager/auth_sdk/models/admin_user_record.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/admin_user_search_request.dart';

import 'admin_console_controller.dart';
import 'admin_console_widgets.dart';

class AdminConsoleUsersView extends StatefulWidget {
  final AdminConsoleController controller;

  const AdminConsoleUsersView({
    super.key,
    required this.controller,
  });

  @override
  State<AdminConsoleUsersView> createState() => _AdminConsoleUsersViewState();
}

class _AdminConsoleUsersViewState extends State<AdminConsoleUsersView> {
  final _formKey = GlobalKey<FormState>();

  final _emailC = TextEditingController();
  final _subC = TextEditingController();
  final _phoneC = TextEditingController();
  final _rawFilterC = TextEditingController();
  final _limitC = TextEditingController(text: '20');
  final _pageTokenC = TextEditingController();

  bool _advanced = false;

  @override
  void initState() {
    super.initState();

    // Carica whitelist appena entri in Users (una volta).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await widget.controller.refreshWhitelist();
      } catch (_) {
        // best-effort
      }
    });
  }

  @override
  void dispose() {
    _emailC.dispose();
    _subC.dispose();
    _phoneC.dispose();
    _rawFilterC.dispose();
    _limitC.dispose();
    _pageTokenC.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  AdminUserSearchRequest _buildRequest({String? paginationTokenOverride}) {
    final limit = int.tryParse(_limitC.text.trim()) ?? 20;

    return AdminUserSearchRequest(
      email: _emailC.text.trim().isEmpty ? null : _emailC.text.trim(),
      sub: _subC.text.trim().isEmpty ? null : _subC.text.trim(),
      phoneNumber: _phoneC.text.trim().isEmpty ? null : _phoneC.text.trim(),
      rawFilter: _rawFilterC.text.trim().isEmpty ? null : _rawFilterC.text.trim(),
      limit: limit,
      paginationToken: (paginationTokenOverride ?? _pageTokenC.text).trim().isEmpty
          ? null
          : (paginationTokenOverride ?? _pageTokenC.text).trim(),
    );
  }

  Future<void> _search({String? paginationTokenOverride}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      await widget.controller.searchUsers(
        _buildRequest(paginationTokenOverride: paginationTokenOverride),
      );
      _snack('Ricerca completata: ${widget.controller.users.length} risultati.');
    } catch (e) {
      _snack('Errore ricerca: $e', error: true);
    }
  }

  Future<void> _toggleWhitelist(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return;

    final already = widget.controller.isWhitelisted(id);

    try {
      await widget.controller.setWhitelisted(id, !already);
      _snack(!already ? 'Aggiunto in whitelist.' : 'Rimosso dalla whitelist.');
    } catch (e) {
      _snack('Errore whitelist: $e', error: true);
    }
  }

  void _clearFilters() {
    _emailC.clear();
    _subC.clear();
    _phoneC.clear();
    _rawFilterC.clear();
    _pageTokenC.clear();
    _limitC.text = '20';
    setState(() => _advanced = false);
  }

  void _showWhitelistDialog() {
    final list = widget.controller.whitelist.toList()..sort();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Whitelist (${list.length})'),
          content: SizedBox(
            width: 600,
            child: list.isEmpty
                ? const Text('Whitelist vuota.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final id = list[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          id,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        trailing: IconButton(
                          tooltip: 'Copia ID',
                          icon: const Icon(Icons.copy_outlined),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: id));
                            if (mounted) Navigator.of(context).pop();
                            _snack('ID copiato negli appunti.');
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Chiudi'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final theme = Theme.of(context);

        final loadingLine = c.usersLoading || c.whitelistLoading || c.whitelistUpdating;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionHeader(
              title: 'Users',
              subtitle: 'Ricerca utenti Cognito e gestione whitelist (Payments).',
              icon: Icons.people_alt_outlined,
              trailing: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (c.whitelistLoading)
                    Chip(
                      label: const Text('Whitelist: loading...'),
                      avatar: const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    ActionChip(
                      label: Text('Whitelist: ${c.whitelist.length}'),
                      avatar: const Icon(Icons.verified_outlined, size: 18),
                      onPressed: _showWhitelistDialog,
                    ),
                  OutlinedButton.icon(
                    onPressed: c.whitelistLoading
                        ? null
                        : () async {
                            try {
                              await c.refreshWhitelist();
                              _snack('Whitelist aggiornata.');
                            } catch (e) {
                              _snack('Errore whitelist: $e', error: true);
                            }
                          },
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Aggiorna'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (loadingLine) const LinearProgressIndicator(minHeight: 2),
            if (loadingLine) const SizedBox(height: 12),

            // ─────────────────────────────────────────────────────────────
            // Search panel
            // ─────────────────────────────────────────────────────────────
            AdminCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ricerca utenti',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 320,
                          child: TextFormField(
                            controller: _emailC,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.alternate_email_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 320,
                          child: TextFormField(
                            controller: _subC,
                            decoration: const InputDecoration(
                              labelText: 'User ID (sub)',
                              prefixIcon: Icon(Icons.fingerprint_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: TextFormField(
                            controller: _phoneC,
                            decoration: const InputDecoration(
                              labelText: 'Telefono (E.164)',
                              prefixIcon: Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    InkWell(
                      onTap: () => setState(() => _advanced = !_advanced),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_advanced ? Icons.expand_less : Icons.expand_more),
                            const SizedBox(width: 6),
                            Text(
                              _advanced ? 'Nascondi filtri avanzati' : 'Mostra filtri avanzati',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_advanced) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _rawFilterC,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Raw filter (Cognito)',
                          hintText: 'es: email = "user@example.com"  OR  sub = "uuid"',
                          prefixIcon: Icon(Icons.filter_alt_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 180,
                            child: TextFormField(
                              controller: _limitC,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Limit',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final n = int.tryParse((v ?? '').trim());
                                if (n == null || n <= 0) return 'Valore non valido';
                                return null;
                              },
                            ),
                          ),
                          SizedBox(
                            width: 420,
                            child: TextFormField(
                              controller: _pageTokenC,
                              decoration: const InputDecoration(
                                labelText: 'Pagination token (opzionale)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: c.usersLoading ? null : () => _search(),
                          icon: const Icon(Icons.search_outlined),
                          label: const Text('Cerca'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: c.usersLoading ? null : _clearFilters,
                          icon: const Icon(Icons.clear_all_outlined),
                          label: const Text('Pulisci filtri'),
                        ),
                        const Spacer(),
                        if ((c.paginationToken ?? '').isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: c.usersLoading
                                ? null
                                : () => _search(paginationTokenOverride: c.paginationToken),
                            icon: const Icon(Icons.navigate_next_outlined),
                            label: const Text('Pagina successiva'),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    if ((c.appliedFilter ?? '').isNotEmpty)
                      Text(
                        'Filtro applicato: ${c.appliedFilter}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.75),
                        ),
                      ),
                    if ((c.paginationToken ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pagination token: ${c.paginationToken}',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.75),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copia token',
                            icon: const Icon(Icons.copy_outlined),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: c.paginationToken!));
                              _snack('Pagination token copiato.');
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─────────────────────────────────────────────────────────────
            // Results table
            // ─────────────────────────────────────────────────────────────
            AdminCard(
              padding: const EdgeInsets.all(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          'Risultati (${c.users.length})',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 8),
                        if (c.usersCount != 0) Chip(label: Text('count: ${c.usersCount}')),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (c.users.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        c.usersLoading
                            ? 'Caricamento...'
                            : 'Nessun risultato. Imposta i filtri e premi Cerca.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Username')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('User ID (sub)')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Enabled')),
                          DataColumn(label: Text('Creato')),
                          DataColumn(label: Text('Ultima mod.')),
                          DataColumn(label: Text('Azioni')),
                        ],
                        rows: c.users.map((u) => _rowForUser(u, c)).toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  DataRow _rowForUser(AdminUserRecord u, AdminConsoleController c) {
    final theme = Theme.of(context);

    final id = (u.sub ?? '').trim().isNotEmpty ? u.sub!.trim() : u.username;
    final email = (u.email ?? '').trim();

    final whitelisted = c.isWhitelisted(id);
    final busy = c.whitelistUpdating;

    return DataRow(
      cells: [
        DataCell(Text(u.username)),
        DataCell(Text(email.isEmpty ? '—' : email)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  id,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              IconButton(
                tooltip: 'Copia ID',
                icon: const Icon(Icons.copy_outlined, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: id));
                  _snack('ID copiato.');
                },
              ),
            ],
          ),
        ),
        DataCell(Text(u.userStatus ?? '—')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                (u.enabled ?? false)
                    ? Icons.check_circle_outline
                    : Icons.block_outlined,
                size: 18,
                color: (u.enabled ?? false)
                    ? theme.colorScheme.primary
                    : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text((u.enabled ?? false) ? 'true' : 'false'),
            ],
          ),
        ),
        DataCell(Text(_fmtDate(u.created))),
        DataCell(Text(_fmtDate(u.lastModified))),
        DataCell(
          OutlinedButton.icon(
            onPressed: busy ? null : () => _toggleWhitelist(id),
            icon: Icon(
              whitelisted
                  ? Icons.remove_circle_outline
                  : Icons.add_circle_outline,
            ),
            label: Text(
              whitelisted ? 'Rimuovi whitelist' : 'Aggiungi whitelist',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: whitelisted ? theme.colorScheme.error : null,
            ),
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hh:$mm';
  }
}
