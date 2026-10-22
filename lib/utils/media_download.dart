// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/utils/downloads_saver.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:vodozemac/vodozemac.dart' show CryptoUtils;

/// Downloads an attachment once and shares the progress between everything
/// showing it: the timeline bubble, the fullscreen viewer and "save file".
///
/// The SDK database already keeps attachments up to 10 MB. Bigger ones are
/// kept in the cache directory exactly as the server sent them, so files
/// from encrypted rooms stay encrypted on disk. Videos are decrypted into a
/// separate file only while they play. [cleanUp] and the size cap apply the
/// user's cache settings to the cached files.
class MediaDownload extends ChangeNotifier {
  static final Map<String, MediaDownload> _downloads = {};

  /// Entries beyond this are dropped when nothing listens to them, so
  /// scrolling through a long history doesn't keep every event in memory.
  static const int _maxEntries = 200;

  static const String _filePrefix = 'media_';
  static const String _playbackPrefix = 'playback_';
  static const String _exportPrefix = 'export_';

  /// Keep at most this many entries in [AppSettings.mediaExported].
  static const int _maxExportedEntries = 1000;

  static const int _maxParallelAutoDownloads = 2;
  static int _autoDownloadsRunning = 0;
  static final List<MediaDownload> _autoDownloadQueue = [];

  /// Exports run one after another, so they don't overwrite each other's
  /// entries in [AppSettings.mediaExported].
  static Future<void> _exports = Future.value();

  /// Keyed by event ID, not transaction ID: the local echo of a sent
  /// attachment and the event from the server must not share an entry, or
  /// the server event would keep using the local echo, which has no URL.
  /// [rememberSent] carries the file over instead.
  factory MediaDownload.of(Event event) {
    final existing = _downloads[event.eventId];
    if (existing != null) return existing;
    final download = _downloads[event.eventId] = MediaDownload._(event);
    if (_downloads.length > _maxEntries) _evict();
    return download;
  }

  MediaDownload._(this.event);

  static void _evict() {
    final unused = _downloads.entries
        .where((entry) => entry.value._isUnused)
        .take(_downloads.length - _maxEntries)
        .map((entry) => entry.key)
        .toList();
    unused.forEach(_downloads.remove);
  }

  final Event event;

  int _listenerCount = 0;

  @override
  void addListener(VoidCallback listener) {
    _listenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listenerCount--;
    super.removeListener(listener);
  }

  bool get _isUnused =>
      _listenerCount <= 0 &&
      _download == null &&
      _autoDownloadTurn == null &&
      _playbackFile == null;

  bool get _isVideo => event.messageType == MessageTypes.Video;

  /// On web there is no file system, and only videos are worth keeping in
  /// memory, so the player doesn't download them twice.
  bool get _keepsDownload => !kIsWeb || _isVideo;

  int? get fileSize => event.infoMap.tryGet<int>('size');

  int? downloadedBytes;

  /// The attachment as the server sent it, encrypted for encrypted rooms.
  File? _file;

  /// Decrypted video for the player, deleted by [releasePlayback].
  File? _playbackFile;

  MatrixFile? _webFile;

  /// The SDK database (or, while sending, its local echo cache) has a copy.
  bool _inDatabase = false;

  /// A finished download, handed to the [getFile] call that asked for it so
  /// it doesn't have to read the file back.
  MatrixFile? _fresh;

  Future<void>? _download;
  Future<void>? _localCheck;
  final Stopwatch _stopwatch = Stopwatch();

  bool get isDownloaded => _file != null || _webFile != null || _inDatabase;

  bool get isDownloading => _download != null && !isDownloaded;

  /// Null while unknown, or once all bytes arrived and the file is being
  /// written.
  double? get progress {
    final bytes = downloadedBytes;
    final fileSize = this.fileSize;
    if (bytes == null || fileSize == null || fileSize <= 0) return null;
    final progress = bytes / fileSize;
    return progress < 1 ? progress : null;
  }

  /// Extrapolated from the average speed so far. Waits a second so the first
  /// burst of bytes doesn't produce a wildly optimistic estimate.
  Duration? get timeLeft {
    final bytes = downloadedBytes;
    final fileSize = this.fileSize;
    final elapsed = _stopwatch.elapsedMilliseconds;
    if (bytes == null || fileSize == null || bytes <= 0 || bytes >= fileSize) {
      return null;
    }
    if (elapsed < 1000) return null;
    return Duration(
      milliseconds: ((fileSize - bytes) * elapsed / bytes).ceil(),
    );
  }

  int _lastNotifiedPercent = -1;
  int _lastNotifiedAt = 0;

  /// Rebuilding the bubble for every network chunk would be thousands of
  /// rebuilds for a big video, so only notify when the percentage changes
  /// or once a second, which keeps the time left moving.
  void _onDownloadProgress(int bytes) {
    downloadedBytes = bytes;
    final fileSize = this.fileSize;
    final percent = fileSize == null || fileSize <= 0
        ? 0
        : bytes * 100 ~/ fileSize;
    final now = _stopwatch.elapsedMilliseconds;
    if (percent == _lastNotifiedPercent && now - _lastNotifiedAt < 1000) {
      return;
    }
    _lastNotifiedPercent = percent;
    _lastNotifiedAt = now;
    notifyListeners();
  }

  /// Looks for an earlier download without touching the network.
  Future<void> checkLocal() => _localCheck ??= _checkLocal();

  Future<void> _checkLocal() async {
    if (!_keepsDownload || isDownloaded) return;
    try {
      if (!kIsWeb) {
        final file = await _cacheFile();
        if (await file.exists()) {
          _file = file;
          notifyListeners();
          return;
        }
      }
      if (await _isInLocalStore()) {
        _inDatabase = true;
        notifyListeners();
      }
    } catch (e, s) {
      Logs().w('Unable to look for a local copy of an attachment', e, s);
    }
  }

  /// Whether the SDK has the attachment locally, without decrypting it.
  Future<bool> _isInLocalStore() async {
    if (!event.status.isSent) {
      // The local echo of a file being sent, from the SDK's sending cache.
      try {
        await event.downloadAndDecryptAttachment(fromLocalStoreOnly: true);
        return true;
      } catch (_) {
        return false;
      }
    }
    final mxcUrl = event.attachmentMxcUrl;
    final fileSize = this.fileSize;
    final database = event.room.client.database;
    // The SDK only stores attachments it knows to be small enough.
    if (mxcUrl == null || fileSize == null || fileSize > database.maxFileSize) {
      return false;
    }
    return await database.getFile(mxcUrl) != null;
  }

  /// [export] copies the download to the gallery or Downloads if the user
  /// wants that. Explicit "save" and "share" don't, they pick a place
  /// themselves.
  Future<void> download({bool export = true}) =>
      _download ??= _run(export: export, keepFresh: false);

  Future<void> _run({required bool export, required bool keepFresh}) async {
    try {
      await checkLocal();
      if (isDownloaded) return;
      _stopwatch
        ..reset()
        ..start();
      _lastNotifiedPercent = -1;
      Uint8List? raw;
      final matrixFile = await event.downloadAndDecryptAttachment(
        // Not called when the SDK found the file in its database, or when a
        // content scanner downloads encrypted files.
        downloadCallback: (uri) async => raw = await _downloadRaw(uri),
      );
      _stopwatch.stop();
      final rawBytes = raw;
      if (kIsWeb) {
        if (_keepsDownload) _webFile = matrixFile;
      } else if (await _isInLocalStore()) {
        _inDatabase = true;
      } else if (rawBytes != null) {
        await _writeRaw(rawBytes);
      } else if (!event.isAttachmentEncrypted) {
        await _writeRaw(matrixFile.bytes);
      }
      if (keepFresh) _fresh = matrixFile;
      if (!isDownloaded) {
        // Nowhere to keep it (web, or an encrypted file through a content
        // scanner), so it counts as not downloaded.
        _download = null;
      }
      notifyListeners();
      if (export) _queueExport(matrixFile);
    } catch (_) {
      _download = null;
      downloadedBytes = null;
      _stopwatch
        ..stop()
        ..reset();
      notifyListeners();
      rethrow;
    }
  }

  /// Like the SDK's own download, but keeps the bytes as they come from the
  /// server, so they can be cached without decrypting them.
  Future<Uint8List> _downloadRaw(Uri uri) async {
    final client = event.room.client;
    final request = http.Request('GET', uri);
    final scanner = client.contentScannerConfig;
    if (scanner == null || scanner.withAuthHeader) {
      request.headers['authorization'] = 'Bearer ${client.accessToken}';
    }
    final response = await client.httpClient.send(request);
    if (response.statusCode >= 400) {
      client.unexpectedResponse(response, await response.stream.toBytes());
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      builder.add(chunk);
      _onDownloadProgress(builder.length);
    }
    return builder.takeBytes();
  }

  /// Starts the download in the background if the user's settings allow it
  /// for this attachment. [cancelAutoDownload] takes it out of the queue
  /// again.
  Future<void> autoDownload() async {
    if (kIsWeb || !_isAutoDownloadEnabled) return;
    await checkLocal();
    if (!_isAutoDownloadAllowed || _autoDownloadTurn != null) return;
    if (!await _waitForAutoDownloadSlot()) return;
    try {
      if (_isAutoDownloadAllowed && await _isOnAllowedConnection()) {
        await download();
      }
    } catch (e, s) {
      // Not worth an error dialog for a download nobody asked for. Opening
      // the attachment tries again and reports the error.
      Logs().w('Unable to download attachment automatically', e, s);
    } finally {
      _releaseAutoDownloadSlot();
    }
  }

  Completer<bool>? _autoDownloadTurn;

  /// Completes with false if cancelled while waiting.
  Future<bool> _waitForAutoDownloadSlot() {
    if (_autoDownloadsRunning < _maxParallelAutoDownloads) {
      _autoDownloadsRunning++;
      return Future.value(true);
    }
    final turn = _autoDownloadTurn = Completer<bool>();
    _autoDownloadQueue.add(this);
    return turn.future;
  }

  /// Hands the slot straight to the next download in the queue, so the
  /// limit holds even before the woken download runs.
  static void _releaseAutoDownloadSlot() {
    while (_autoDownloadQueue.isNotEmpty) {
      final next = _autoDownloadQueue.removeAt(0);
      final turn = next._autoDownloadTurn;
      next._autoDownloadTurn = null;
      if (turn != null) {
        turn.complete(true);
        return;
      }
    }
    _autoDownloadsRunning--;
  }

  /// Drops a queued automatic download, for when its bubble goes away.
  /// Downloads that already started keep going.
  void cancelAutoDownload() {
    final turn = _autoDownloadTurn;
    if (turn == null) return;
    _autoDownloadTurn = null;
    _autoDownloadQueue.remove(this);
    turn.complete(false);
  }

  bool get _isAutoDownloadAllowed =>
      !isDownloaded && _download == null && _isAutoDownloadEnabled;

  bool get _isAutoDownloadEnabled {
    final enabled = switch (event.messageType) {
      MessageTypes.Video => AppSettings.autoDownloadVideos.value,
      MessageTypes.Image => AppSettings.autoDownloadImages.value,
      MessageTypes.File => AppSettings.autoDownloadFiles.value,
      _ => false,
    };
    if (!enabled) return false;
    final maxSizeMb = AppSettings.autoDownloadMaxSizeMb.value;
    if (maxSizeMb <= 0) return true;
    final fileSize = this.fileSize;
    return fileSize != null && fileSize <= maxSizeMb * 1000 * 1000;
  }

  static Future<bool> _isOnAllowedConnection() async {
    if (!AppSettings.autoDownloadWifiOnly.value) return true;
    final connections = await Connectivity().checkConnectivity();
    return connections.contains(ConnectivityResult.wifi) ||
        connections.contains(ConnectivityResult.ethernet);
  }

  /// The decrypted attachment, from the cache, the database or the network.
  /// See [download] for [export].
  Future<MatrixFile> getFile({bool export = true}) async {
    if (!_keepsDownload) {
      return event.downloadAndDecryptAttachment(
        onDownloadProgress: _onDownloadProgress,
      );
    }
    if (_download == null && !isDownloaded) {
      _download = _run(export: export, keepFresh: true);
    }
    await _download;
    final fresh = _fresh;
    _fresh = null;
    if (fresh != null) return fresh;
    return _readLocal(() async {
      final webFile = _webFile;
      if (webFile != null) return webFile;
      final file = _file;
      if (file == null) {
        return event.downloadAndDecryptAttachment(fromLocalStoreOnly: true);
      }
      final raw = await file.readAsBytes();
      _touch(file);
      return MatrixFile(
        bytes: await _decrypt(raw),
        name: event.content.tryGet<String>('filename') ?? event.body,
        mimeType: event.attachmentMimetype,
      );
    });
  }

  /// Decrypts cached bytes without the SDK, which may ask the server about
  /// media support first and would fail offline.
  Future<Uint8List> _decrypt(Uint8List raw) async {
    if (!event.isAttachmentEncrypted) return raw;
    final fileMap = event.content.tryGetMap<String, Object?>('file');
    final key = fileMap?.tryGetMap<String, Object?>('key')?.tryGet<String>('k');
    final iv = fileMap?.tryGet<String>('iv');
    final sha256 = fileMap
        ?.tryGetMap<String, Object?>('hashes')
        ?.tryGet<String>('sha256');
    if (key == null || iv == null || sha256 == null) {
      throw 'No encrypted file info found';
    }
    final decrypted = await event.room.client.nativeImplementations.decryptFile(
      EncryptedFile(data: raw, k: key, iv: iv, sha256: sha256),
    );
    if (decrypted == null) throw 'Unable to decrypt file';
    return decrypted;
  }

  /// Unencrypted videos play straight from the cache. Encrypted ones are
  /// decrypted into a file that [releasePlayback] deletes again.
  Future<VideoPlayerController> createController() async {
    await download();
    final webFile = _webFile;
    if (webFile != null) {
      return VideoPlayerController.networkUrl(
        Uri.dataFromBytes(webFile.bytes, mimeType: webFile.mimeType),
      );
    }
    final file = _file;
    if (!event.isAttachmentEncrypted && file != null && await file.exists()) {
      _touch(file);
      return VideoPlayerController.file(file);
    }
    final matrixFile = await getFile();
    final playbackFile = _playbackFile ??= File(
      '${(await getTemporaryDirectory()).path}/$_playbackPrefix'
      '${(await _cacheFile()).uri.pathSegments.last}',
    );
    if (!await playbackFile.exists()) {
      await playbackFile.writeAsBytes(matrixFile.bytes);
    }
    return VideoPlayerController.file(playbackFile);
  }

  /// Deletes the decrypted file [createController] wrote for the player.
  Future<void> releasePlayback() async {
    final playbackFile = _playbackFile;
    _playbackFile = null;
    await playbackFile?.delete().catchError((_) => playbackFile);
  }

  /// Runs [read] on the local copy, downloading the attachment again if the
  /// copy disappeared in the meantime (cache cleared, database entry
  /// expired).
  Future<T> _readLocal<T>(Future<T> Function() read) async {
    for (var attempt = 0; ; attempt++) {
      await download();
      try {
        return await read();
      } catch (_) {
        if (attempt > 0) rethrow;
        _forget();
      }
    }
  }

  void _forget() {
    _file = null;
    _webFile = null;
    _inDatabase = false;
    _download = null;
    _localCheck = null;
    downloadedBytes = null;
    notifyListeners();
  }

  /// Counts as a use, so the cleanup keeps what is still opened.
  static void _touch(File file) =>
      file.setLastModified(DateTime.now()).catchError((_) {});

  Future<void> _writeRaw(Uint8List raw) async {
    final file = await _cacheFile();
    // Write under another name first, so an interrupted write is never
    // mistaken for a finished download.
    final partFile = File('${file.path}.part');
    await partFile.writeAsBytes(raw);
    await partFile.rename(file.path);
    _file = file;
    notifyListeners();
    unawaited(_enforceSizeCap(keep: file));
  }

  /// Puts an attachment the user just sent into the local store, so it
  /// doesn't need to be downloaded again: the event from the server has a
  /// new event ID and starts without the local echo's copy. For encrypted
  /// rooms the uploaded bytes are rebuilt with the event's key, which AES-CTR
  /// makes identical to what was uploaded.
  static Future<void> rememberSent(
    Room room,
    MatrixFile file,
    String? eventId,
  ) async {
    if (kIsWeb || eventId == null) return;
    try {
      final event = await room.getEventById(eventId);
      final mxcUrl = event?.attachmentMxcUrl;
      if (event == null || mxcUrl == null) return;
      final raw = _uploadedBytes(event, file.bytes);
      if (raw == null) return;
      final database = room.client.database;
      if (raw.lengthInBytes < database.maxFileSize) {
        await database.storeFile(
          mxcUrl,
          raw,
          DateTime.now().millisecondsSinceEpoch,
        );
      } else {
        await MediaDownload.of(event)._writeRaw(raw);
      }
    } catch (e, s) {
      Logs().w('Unable to keep a copy of a sent attachment', e, s);
    }
  }

  /// The bytes the server has for [plaintext], or null if they can't be
  /// reproduced, for example because the SDK shrank the image before
  /// uploading it.
  static Uint8List? _uploadedBytes(Event event, Uint8List plaintext) {
    final fileMap = event.content.tryGetMap<String, Object?>('file');
    if (fileMap == null) {
      return event.infoMap.tryGet<int>('size') == plaintext.length
          ? plaintext
          : null;
    }
    final key = fileMap.tryGetMap<String, Object?>('key')?.tryGet<String>('k');
    final iv = fileMap.tryGet<String>('iv');
    final sha256 = fileMap
        .tryGetMap<String, Object?>('hashes')
        ?.tryGet<String>('sha256');
    if (key == null || iv == null || sha256 == null) return null;
    final raw = CryptoUtils.aesCtr(
      input: plaintext,
      key: base64.decode(base64.normalize(key)),
      iv: base64.decode(base64.normalize(iv)),
    );
    final hash = base64.encode(CryptoUtils.sha256(input: raw));
    return base64.normalize(hash) == base64.normalize(sha256) ? raw : null;
  }

  /// The gallery album for photos or videos. Android keeps them in
  /// separate folders inside one; Apple Photos and Windows can't nest
  /// albums.
  static String galleryAlbum({required bool video}) {
    final type = video ? 'Videos' : 'Images';
    return PlatformInfos.isAndroid
        ? '${DownloadsSaver.folder}/$type'
        : '${DownloadsSaver.folder} $type';
  }

  /// Where the user wants a copy of this attachment, besides the cache.
  String get _destination => switch (event.messageType) {
    MessageTypes.Image => AppSettings.imageDownloadLocation.value,
    MessageTypes.Video => AppSettings.videoDownloadLocation.value,
    MessageTypes.File => AppSettings.fileDownloadLocation.value,
    _ => 'cache',
  };

  void _queueExport(MatrixFile matrixFile) {
    if (kIsWeb || _destination == 'cache') return;
    _exports = _exports.then((_) => _export(matrixFile));
  }

  /// Copies a fresh download to the gallery or Downloads, as configured.
  Future<void> _export(MatrixFile matrixFile) async {
    final destination = _destination;
    if (destination == 'cache') return;
    final id = event.attachmentMxcUrl?.toString() ?? event.eventId;
    final name = event.content.tryGet<String>('filename') ?? event.body;
    File? tempFile;
    try {
      final exported = AppSettings.mediaExported.value;
      if (exported.contains(id)) return;
      // Gal and the Downloads saver need a decrypted file. The cache holds
      // encrypted bytes for encrypted rooms, and small attachments only live
      // in the database, so write a temporary one for those.
      var file = event.isAttachmentEncrypted ? null : _file;
      if (file == null && (destination == 'downloads' || _isVideo)) {
        file = tempFile = File(
          '${(await getTemporaryDirectory()).path}/$_exportPrefix'
          '${(await _cacheFile()).uri.pathSegments.last}',
        );
        await file.writeAsBytes(matrixFile.bytes);
      }
      if (destination == 'downloads') {
        if (!await DownloadsSaver.save(file!, name, event.attachmentMimetype)) {
          return;
        }
      } else {
        if (!await Gal.hasAccess(toAlbum: true) &&
            !await Gal.requestAccess(toAlbum: true)) {
          return;
        }
        final album = galleryAlbum(video: _isVideo);
        if (_isVideo) {
          await Gal.putVideo(file!.path, album: album);
        } else {
          await Gal.putImageBytes(matrixFile.bytes, album: album, name: name);
        }
      }
      final updated = [...exported, id];
      await AppSettings.mediaExported.setItem(
        updated.length > _maxExportedEntries
            ? updated.sublist(updated.length - _maxExportedEntries)
            : updated,
      );
    } catch (e, s) {
      Logs().w('Unable to copy attachment to $destination', e, s);
    } finally {
      await tempFile?.delete().catchError((_) => tempFile!);
    }
  }

  Future<File> _cacheFile() async {
    final tempDir = await getTemporaryDirectory();
    final id =
        event.attachmentMxcUrl?.pathSegments.last ??
        event.transactionId ??
        event.eventId;
    final extension = extensionFromMime(event.attachmentMimetype);
    return File(
      '${tempDir.path}/$_filePrefix${Uri.encodeComponent(id)}'
      '${extension == null ? '' : '.$extension'}',
    );
  }

  static Future<List<File>> _filesWithPrefix(String prefix) async {
    final tempDir = await getTemporaryDirectory();
    return [
      await for (final entity in tempDir.list())
        if (entity is File && entity.uri.pathSegments.last.startsWith(prefix))
          entity,
    ];
  }

  static Future<List<File>> _cachedFiles({bool includePartial = false}) async =>
      [
        for (final file in await _filesWithPrefix(_filePrefix))
          if (includePartial || !file.path.endsWith('.part')) file,
      ];

  /// Resets downloads whose file was deleted, so their bubbles show them as
  /// not downloaded. They may still be in the SDK database, so look again.
  static void _forgetFiles(Set<String> paths) {
    if (paths.isEmpty) return;
    for (final download in _downloads.values) {
      if (paths.contains(download._file?.path)) {
        download._forget();
        download.checkLocal();
      }
    }
  }

  /// Deletes [files], remembering which ones are gone even if one fails.
  static Future<Set<String>> _deleteFiles(Iterable<File> files) async {
    final deleted = <String>{};
    for (final file in files) {
      try {
        await file.delete();
        deleted.add(file.path);
      } on FileSystemException catch (e) {
        if (!await file.exists()) {
          deleted.add(file.path);
        } else {
          Logs().w('Unable to delete cached file ${file.path}', e);
        }
      }
    }
    return deleted;
  }

  /// Total size of the cached files in bytes.
  static Future<int> cacheSize() async {
    if (kIsWeb) return 0;
    var size = 0;
    for (final file in await _cachedFiles(includePartial: true)) {
      size += await file.length();
    }
    return size;
  }

  static Future<void> clearCache() async {
    if (kIsWeb) return;
    _forgetFiles(await _deleteFiles(await _cachedFiles()));
  }

  /// Applies the cache settings: removes files that weren't opened for
  /// [AppSettings.mediaCacheMaxAgeDays] and keeps the cache under
  /// [AppSettings.mediaCacheMaxSizeMb]. Partial files left behind by
  /// interrupted writes are removed after a day.
  static Future<void> cleanUp() async {
    if (kIsWeb) return;
    try {
      final now = DateTime.now();
      final maxAge = Duration(days: AppSettings.mediaCacheMaxAgeDays.value);
      final expired = <File>[];
      for (final file in await _cachedFiles(includePartial: true)) {
        final isPartial = file.path.endsWith('.part');
        if (!isPartial && !AppSettings.mediaCacheAutoDelete.value) continue;
        final age = now.difference(await file.lastModified());
        if (age > (isPartial ? const Duration(days: 1) : maxAge)) {
          expired.add(file);
        }
      }
      _forgetFiles(await _deleteFiles(expired));
      await _enforceSizeCap();
    } catch (e, s) {
      Logs().w('Unable to clean up the media cache', e, s);
    }
  }

  /// Removes decrypted files a player or export left behind, for example
  /// when the app was killed. Only safe before anything plays, at startup.
  static Future<void> deleteLeftoverDecryptedFiles() async {
    if (kIsWeb) return;
    try {
      await _deleteFiles([
        ...await _filesWithPrefix(_playbackPrefix),
        ...await _filesWithPrefix(_exportPrefix),
      ]);
    } catch (e, s) {
      Logs().w('Unable to delete leftover decrypted files', e, s);
    }
  }

  /// Deletes the least recently opened files until the cache fits under
  /// [AppSettings.mediaCacheMaxSizeMb].
  static Future<void> _enforceSizeCap({File? keep}) async {
    final maxSizeMb = AppSettings.mediaCacheMaxSizeMb.value;
    if (!AppSettings.mediaCacheAutoDelete.value || maxSizeMb <= 0) return;
    try {
      final files = [
        for (final file in await _cachedFiles())
          (file: file, stat: await file.stat()),
      ]..sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
      var size = files.fold<int>(0, (size, f) => size + f.stat.size);
      final toDelete = <File>[];
      for (final (:file, :stat) in files) {
        if (size <= maxSizeMb * 1000 * 1000) break;
        if (file.path == keep?.path) continue;
        toDelete.add(file);
        size -= stat.size;
      }
      _forgetFiles(await _deleteFiles(toDelete));
    } catch (e, s) {
      Logs().w('Unable to enforce the media cache size', e, s);
    }
  }
}
