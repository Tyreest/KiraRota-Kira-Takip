import 'dart:convert';
import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants.dart';
import '../domain/models/rental.dart';

/// Yedek kaydetme sonucu (SAF).
enum BackupSaveOutcome { saved, cancelled, failed }

class BackupSaveResult {
  const BackupSaveResult(this.outcome, {this.path, this.error});

  final BackupSaveOutcome outcome;
  final String? path;
  final Object? error;

  bool get isSuccess => outcome == BackupSaveOutcome.saved;
}

/// Dosya seçimi sonucu — iptal = null.
class BackupPickResult {
  const BackupPickResult({this.bytes, this.fileName});

  final Uint8List? bytes;
  final String? fileName;
}

/// Parse / doğrulama sonucu.
class BackupDecodeResult {
  const BackupDecodeResult._({this.rentals, this.errorMessage});

  const BackupDecodeResult.ok(List<Rental> rentals)
    : this._(rentals: rentals, errorMessage: null);

  const BackupDecodeResult.invalid([
    this.errorMessage = 'Bu dosya geçerli bir KiraRota yedeği değil.',
  ]) : rentals = null;

  final List<Rental>? rentals;
  final String? errorMessage;

  bool get isValid => rentals != null;
}

/// Hazırlanmış yedek dosyası (geçici dosya + baytlar).
class PreparedRentalBackup {
  PreparedRentalBackup({
    required this.fileName,
    required this.bytes,
    required this.tempFile,
    required this.payload,
  });

  final String fileName;
  final Uint8List bytes;
  final File tempFile;
  final Map<String, dynamic> payload;

  Future<void> dispose() async {
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {}
  }
}

typedef BackupShareFn = Future<ShareResult> Function(ShareParams params);
typedef TempDirectoryFn = Future<Directory> Function();
typedef BackupPickFn = Future<BackupPickResult?> Function();

/// Kira kayıtları yedekleme / geri yükleme (mevcut JSON şeması).
///
/// Payload: `{ app, exportedAt, rentals }` — UI’da ham içerik gösterilmez.
class RentalBackupService {
  RentalBackupService({
    FileSaver? fileSaver,
    BackupShareFn? share,
    TempDirectoryFn? temporaryDirectory,
    BackupPickFn? pickBackupFile,
  }) : _fileSaver = fileSaver ?? FileSaver.instance,
       _share = share ?? SharePlus.instance.share,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _pickBackupFile = pickBackupFile ?? _defaultPick;

  final FileSaver _fileSaver;
  final BackupShareFn _share;
  final TempDirectoryFn _temporaryDirectory;
  final BackupPickFn _pickBackupFile;

  static const invalidBackupMessage =
      'Bu dosya geçerli bir KiraRota yedeği değil.';

  /// `KiraRota-Yedek-YYYY-MM-DD.json`
  static String backupFileName({DateTime? now}) {
    final d = now ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'KiraRota-Yedek-$y-$m-$day.json';
  }

  /// Uzantısız ad (FileSaver `name` + `fileExtension`).
  static String backupBaseFileName({DateTime? now}) {
    final full = backupFileName(now: now);
    return full.substring(0, full.length - '.json'.length);
  }

  /// Mevcut export şeması — yeni alan uydurma.
  Map<String, dynamic> buildPayload(
    List<Rental> rentals, {
    DateTime? exportedAt,
  }) {
    return {
      'app': AppConstants.appName,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'rentals': rentals.map((e) => e.toJson()).toList(),
    };
  }

  Uint8List encodePayload(Map<String, dynamic> payload) {
    final text = const JsonEncoder.withIndent('  ').convert(payload);
    return Uint8List.fromList(utf8.encode(text));
  }

  BackupDecodeResult decodeBackup(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const BackupDecodeResult.invalid();
      }
      final map = Map<String, dynamic>.from(decoded);
      final rentalsRaw = map['rentals'];
      if (rentalsRaw is! List) {
        return const BackupDecodeResult.invalid();
      }
      final rentals = <Rental>[];
      for (final item in rentalsRaw) {
        if (item is! Map) {
          return const BackupDecodeResult.invalid();
        }
        rentals.add(Rental.fromJson(Map<String, dynamic>.from(item)));
      }
      return BackupDecodeResult.ok(rentals);
    } catch (_) {
      return const BackupDecodeResult.invalid();
    }
  }

  BackupDecodeResult decodeBackupBytes(Uint8List bytes) {
    try {
      return decodeBackup(utf8.decode(bytes));
    } catch (_) {
      return const BackupDecodeResult.invalid();
    }
  }

  Future<PreparedRentalBackup> prepareBackup(
    List<Rental> rentals, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final fileName = backupFileName(now: at);
    final payload = buildPayload(rentals, exportedAt: at);
    final bytes = encodePayload(payload);
    final dir = await _temporaryDirectory();
    await _cleanupStaleTempBackups(dir);
    final temp = File('${dir.path}${Platform.pathSeparator}$fileName');
    await temp.writeAsBytes(bytes, flush: true);
    return PreparedRentalBackup(
      fileName: fileName,
      bytes: bytes,
      tempFile: temp,
      payload: payload,
    );
  }

  Future<BackupSaveResult> savePreparedToDevice(
    PreparedRentalBackup prepared,
  ) async {
    try {
      final baseName = prepared.fileName.endsWith('.json')
          ? prepared.fileName.substring(0, prepared.fileName.length - 5)
          : prepared.fileName;
      final path = await _fileSaver.saveAs(
        name: baseName,
        bytes: prepared.bytes,
        fileExtension: 'json',
        mimeType: MimeType.json,
      );
      if (path == null || path.trim().isEmpty) {
        return const BackupSaveResult(BackupSaveOutcome.cancelled);
      }
      return BackupSaveResult(BackupSaveOutcome.saved, path: path);
    } on MissingPluginException catch (e) {
      return BackupSaveResult(BackupSaveOutcome.failed, error: e);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('iptal')) {
        return const BackupSaveResult(BackupSaveOutcome.cancelled);
      }
      return BackupSaveResult(BackupSaveOutcome.failed, error: e);
    }
  }

  /// Dosya eki olarak paylaşır — ham JSON text body göndermez.
  Future<ShareResult> sharePrepared(PreparedRentalBackup prepared) {
    return _share(
      ShareParams(
        files: [
          XFile(
            prepared.tempFile.path,
            mimeType: 'application/json',
            name: prepared.fileName,
          ),
        ],
        text: 'KiraRota yedeği',
        subject: 'KiraRota yedeği',
      ),
    );
  }

  Future<BackupPickResult?> pickBackupFile() => _pickBackupFile();

  static const _pickChannel = MethodChannel(
    'com.tyreest.kiraartisi/backup_files',
  );

  static Future<BackupPickResult?> _defaultPick() async {
    try {
      final raw = await _pickChannel.invokeMethod<dynamic>('pickBackupJson');
      if (raw == null) return null;
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      final bytesRaw = map['bytes'];
      final Uint8List bytes;
      if (bytesRaw is Uint8List) {
        bytes = bytesRaw;
      } else if (bytesRaw is List) {
        bytes = Uint8List.fromList(bytesRaw.cast<int>());
      } else {
        return null;
      }
      final name = map['name'] as String?;
      return BackupPickResult(bytes: bytes, fileName: name);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _cleanupStaleTempBackups(Directory dir) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isEmpty
            ? entity.path
            : entity.uri.pathSegments.last;
        if (!name.startsWith('KiraRota-Yedek-') || !name.endsWith('.json')) {
          continue;
        }
        try {
          await entity.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }
}
