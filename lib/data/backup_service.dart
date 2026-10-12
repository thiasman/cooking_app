import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';

class BackupService {
  final DatabaseHelper _dbHelper;

  BackupService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Creates a ZIP file containing `cooking_app.db` and `photos/*` and returns its path.
  Future<File> createBackupZip({String? outputDirPath}) async {
    // Ensure database is initialized before backing up
    await _dbHelper.database;
    final dbPath = await _dbHelper.getDatabaseFilePath();
    final photosDir = await _dbHelper.getPhotosDirectory();

    final archive = Archive();

    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(
        ArchiveFile(DatabaseHelper.dbFileName, dbBytes.length, dbBytes),
      );
    }

    if (await photosDir.exists()) {
      await for (final entity in photosDir.list()) {
        if (entity is File) {
          final bytes = await entity.readAsBytes();
          final relName = p.join('photos', p.basename(entity.path));
          archive.addFile(ArchiveFile(relName, bytes.length, bytes));
        }
      }
    }

    final zipData = ZipEncoder().encode(archive);
    final dirPath = outputDirPath ?? (await getTemporaryDirectory()).path;
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final zipFile = File(p.join(dirPath, 'cookbook_backup_$dateStr.zip'));
    await zipFile.writeAsBytes(zipData, flush: true);
    return zipFile;
  }

  /// Creates a backup ZIP and opens the Android system share sheet (e.g. Save to Drive).
  Future<void> exportAndShareBackup() async {
    final zipFile = await createBackupZip();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(zipFile.path)],
        subject: 'My Cookbook Backup',
      ),
    );
  }

  /// Restores `cooking_app.db` and `photos/*` from a backup ZIP file.
  Future<void> restoreFromBackupZip(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final hasDb = archive.files.any((f) => f.name == DatabaseHelper.dbFileName);
    if (!hasDb) {
      throw FormatException(
        'Invalid backup file: ${DatabaseHelper.dbFileName} not found inside archive.',
      );
    }

    await _dbHelper.closeDatabase();
    final dbPath = await _dbHelper.getDatabaseFilePath();
    final photosDir = await _dbHelper.getPhotosDirectory();

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final content = file.content as List<int>;

      if (file.name == DatabaseHelper.dbFileName) {
        final outDb = File(dbPath);
        await outDb.parent.create(recursive: true);
        await outDb.writeAsBytes(content, flush: true);
      } else if (file.name.startsWith('photos/')) {
        final photoName = p.basename(file.name);
        if (photoName.isNotEmpty) {
          final outPhoto = File(p.join(photosDir.path, photoName));
          await outPhoto.writeAsBytes(content, flush: true);
        }
      }
    }

    // Re-open database
    await _dbHelper.database;
  }
}
