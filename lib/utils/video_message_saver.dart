import 'package:fluffychat/config/setting_keys.dart';
import 'package:gal/gal.dart';
import 'package:matrix/matrix.dart';

abstract class VideoMessageSaver {
  static const String album = 'd0b0 chat';

  /// Whether the client currently can't reach the homeserver.
  static bool isOffline(Client client) =>
      client.onSyncStatus.value?.status == SyncStatus.error;

  /// Whether a recorded video message should be saved to the gallery before
  /// sending, according to the user's settings and the connection state.
  static bool shouldSaveBeforeSend(Client client) =>
      AppSettings.videoMessageSaveToGallery.value ||
      (AppSettings.videoMessageSaveWhenOffline.value && isOffline(client));

  /// Saves the video at [path] to the "d0b0 chat" gallery album. Returns
  /// false if permission was denied or saving failed.
  static Future<bool> saveToGallery(String path) async {
    try {
      if (!await Gal.hasAccess(toAlbum: true) &&
          !await Gal.requestAccess(toAlbum: true)) {
        return false;
      }
      await Gal.putVideo(path, album: album);
      return true;
    } catch (e, s) {
      Logs().w('Unable to save video message to gallery', e, s);
      return false;
    }
  }
}
