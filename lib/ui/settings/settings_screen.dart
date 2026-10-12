import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../data/backup_service.dart';
import '../../data/diary_repository.dart';
import '../../services/gemini_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onRestored;

  const SettingsScreen({super.key, this.onRestored});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _gemini = GeminiService();
  final _diaryRepo = DiaryRepository();
  final _backupService = BackupService();

  final _apiKeyCtrl = TextEditingController();
  final _calGoalCtrl = TextEditingController();
  final _proteinGoalCtrl = TextEditingController();

  bool _obscureKey = true;
  bool _busyBackup = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _calGoalCtrl.dispose();
    _proteinGoalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final key = await _gemini.getApiKey();
    final calGoal = await _diaryRepo.getDailyTarget('target_calories');
    final protGoal = await _diaryRepo.getDailyTarget('target_protein');
    if (mounted) {
      setState(() {
        _apiKeyCtrl.text = key ?? '';
        _calGoalCtrl.text = calGoal != null ? calGoal.round().toString() : '';
        _proteinGoalCtrl.text =
            protGoal != null ? protGoal.round().toString() : '';
      });
    }
  }

  Future<void> _saveSettings() async {
    await _gemini.saveApiKey(_apiKeyCtrl.text);
    final cal = double.tryParse(_calGoalCtrl.text.trim());
    final prot = double.tryParse(_proteinGoalCtrl.text.trim());
    await _diaryRepo.setDailyTarget('target_calories', cal);
    await _diaryRepo.setDailyTarget('target_protein', prot);

    widget.onRestored?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved!')),
      );
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _busyBackup = true);
    try {
      await _backupService.exportAndShareBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (files.isEmpty || files.single.path == null) return;

      setState(() => _busyBackup = true);
      final file = File(files.single.path!);
      await _backupService.restoreFromBackupZip(file);
      widget.onRestored?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Backup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Gemini AI Configuration (${GeminiService.modelName})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Used for 1-tap recipe nutrition estimation, quick-add diary macros, and AI cooking inspiration.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'Google AI Studio API Key',
              hintText: 'AIzaSy...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Daily Food Diary Goals (Optional)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _calGoalCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Daily Calories (kcal)',
                    hintText: 'e.g., 2200',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _proteinGoalCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Daily Protein (g)',
                    hintText: 'e.g., 140',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Settings'),
          ),
          const Divider(height: 36),
          Text(
            'Local Data Backup & Restore',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Export all your recipes, photos, comments, and food diary entries into a single .zip file to save to Google Drive or local storage.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busyBackup ? null : _exportBackup,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Export Backup (.zip)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busyBackup ? null : _restoreBackup,
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: const Text('Restore (.zip)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
