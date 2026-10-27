import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/device_preferences.dart';
import '../state/authentication_providers.dart';
import '../../groups/validation/group_validators.dart';
import '../../expenses/data/expense_draft_store.dart';
import '../../../core/operations/export_sharing.dart';

class DeviceSettingsSection extends ConsumerStatefulWidget {
  const DeviceSettingsSection({super.key});
  @override
  ConsumerState<DeviceSettingsSection> createState() =>
      _DeviceSettingsSectionState();
}

class _DeviceSettingsSectionState extends ConsumerState<DeviceSettingsSection> {
  String? _account, _currency, _message;
  bool _busy = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      authenticationControllerProvider.select(
        (controller) => controller.state.user?.id,
      ),
      (_, id) => _load(id),
      fireImmediately: true,
    );
  }

  Future<void> _load(String? id) async {
    final generation = ++_generation;
    _account = id;
    _busy = false;
    _currency = null;
    _message = null;
    if (id == null) return;
    try {
      final currency = await ref
          .read(devicePreferencesProvider)
          .defaultCurrency(id);
      if (mounted && generation == _generation) {
        setState(() => _currency = currency);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _message =
              'Device preferences could not load. Choose a currency manually when creating a group.',
        );
      }
    }
  }

  Future<void> _currencyChanged(String? value) async {
    final account = _account;
    if (account == null || _busy) return;
    final generation = _generation;
    setState(() => _busy = true);
    try {
      await ref
          .read(devicePreferencesProvider)
          .setDefaultCurrency(account, value);
      if (mounted && generation == _generation) {
        setState(() {
          _currency = value;
          _message = 'Default currency saved on this device.';
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _message = 'The preference could not be saved. Please retry.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _clear({required bool drafts}) async {
    final account = _account;
    if (account == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          drafts ? 'Clear unsent drafts?' : 'Clear temporary exports?',
        ),
        content: Text(
          drafts
              ? 'Only unsent expense drafts for this account are removed. Pending financial submissions are preserved.'
              : 'Only private temporary export files for this account are removed. Pending submissions and shared ledgers are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _account != account) return;
    final generation = _generation;
    setState(() => _busy = true);
    try {
      if (drafts) {
        await ref.read(expenseDraftStoreProvider).deleteAccount(account);
      } else {
        await ref.read(exportSharingProvider).clearAccount(account);
      }
      if (mounted && generation == _generation) {
        setState(
          () => _message = drafts
              ? 'Unsent drafts cleared. Pending submissions remain saved.'
              : 'Temporary export files cleared.',
        );
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _message = 'Local cleanup could not complete. Please retry.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Device settings'),
      const Text(
        'These preferences apply to this account on this device and are not synchronized.',
      ),
      DropdownButtonFormField<String>(
        key: ValueKey('$_account:$_currency'),
        initialValue: _currency,
        decoration: const InputDecoration(
          labelText: 'Default currency for new groups',
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('Choose each time')),
          for (final code in GroupValidators.supportedCurrencies)
            DropdownMenuItem(value: code, child: Text(code)),
        ],
        onChanged: _busy ? null : _currencyChanged,
      ),
      Wrap(
        children: [
          TextButton(
            onPressed: _busy ? null : () => _clear(drafts: true),
            child: const Text('Clear unsent drafts'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _clear(drafts: false),
            child: const Text('Clear temporary exports'),
          ),
        ],
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_message != null) Semantics(liveRegion: true, child: Text(_message!)),
    ],
  );
}
