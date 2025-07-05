import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemy/ui/blind_test.dart';
import 'package:alchemy/ui/elements.dart';
import 'package:alchemy/ui/router.dart';
import 'package:alchemy/ui/tiles.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttericon/octicons_icons.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:alchemy/settings.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../api/cache.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';
import '../utils/navigator_keys.dart';
import '../service/audio_service.dart';
import '../translations.i18n.dart';
import '../ui/cached_image.dart';
import '../ui/details_screens.dart';
import '../ui/error.dart';

class MenuSheet {
  Function navigateCallback;

  // Use no-op callback if not provided
  MenuSheet({Function? navigateCallback})
      : navigateCallback = navigateCallback ?? (() {});

  //===================
  // DEFAULT
  //===================

  void show(BuildContext context, List<Widget> options) {
    showModalBottomSheet(
        backgroundColor: Colors.transparent,
        useRootNavigator: true,
        isScrollControlled: true,
        context: context,
        builder: (BuildContext context) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  (MediaQuery.of(context).orientation == Orientation.landscape)
                      ? 220
                      : 350,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border.all(color: Colors.transparent),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18))),
              child: SingleChildScrollView(
                child: Material(
                  color: Colors.transparent,
                  child: Column(children: options),
                ),
              ),
            ),
          );
        });
  }

  //===================
  // TRACK
  //===================

  void showWithTrack(BuildContext context, Track track, List<Widget> options) {
    bool isOffline = false;
    downloadManager
        .checkOffline(track: track)
        .then((managerAnswer) => isOffline = managerAnswer);
    showModalBottomSheet(
        backgroundColor: Colors.transparent,
        useRootNavigator: true,
        isScrollControlled: true,
        context: context,
        builder: (BuildContext context) {
          return Container(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border.all(color: Colors.transparent),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      track.title ?? '',
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 20.0,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                if (isOffline)
                                  Icon(
                                    Octicons.primitive_dot,
                                    color: Colors.green,
                                    size: 12.0,
                                  ),
                              ],
                            ),
                            Padding(padding: EdgeInsets.only(top: 4.0)),
                            Text(
                              track.artistString ?? '',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                  fontSize: 14.0,
                                  color: Settings.secondaryText),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: 'Album art'.i18n,
                        image: true,
                        child: CachedImage(
                          url: track.image?.full ?? '',
                          height: 128,
                          width: 128,
                          circular: true,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              track.album?.title ?? '',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(' (' + (track.durationString ?? '') + ')')
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 16.0,
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (MediaQuery.of(context).orientation ==
                              Orientation.landscape)
                          ? 200
                          : 350,
                    ),
                    child: SingleChildScrollView(
                      child: Material(
                          color: Colors.transparent,
                          child: Column(children: options)),
                    ),
                  )
                ],
              ));
        });
  }

  //Default track options
  void defaultTrackMenu(Track track,
      {required BuildContext context,
      List<Widget> options = const [],
      Function? onRemove}) {
    Album elevatedAlbum = track.album ?? Album();

    if (elevatedAlbum.id != null) {
      deezerAPI.album(elevatedAlbum.id ?? '').then((Album a) {
        elevatedAlbum = a;
      });
    } else {
      Track elevatedTrack = track;
      deezerAPI.track(track.id ?? '').then((Track t) {
        elevatedTrack = t;
      });
      deezerAPI.album(elevatedTrack.album?.id ?? '').then((Album a) {
        elevatedAlbum = a;
      });
    }

    showWithTrack(context, track, [
      addToQueueNext(track, context),
      addToQueue(track, context),
      (cache.checkTrackFavorite(track))
          ? removeFavoriteTrack(track, context, onUpdate: onRemove)
          : addTrackFavorite(track, context),
      ...options,
      downloadTrack(track, context),
      addToPlaylist(track, context),
      showAlbum(elevatedAlbum, context),
      ...List.generate(track.artists?.length ?? 0,
          (i) => showArtist(track.artists?[i] ?? Artist(), context)),
      shareTile('track', track.id ?? ''),
      playMix(track, context),
    ]);
  }

  //===================
  // TRACK OPTIONS
  //===================

  Widget addToQueueNext(Track t, BuildContext context) => ListTile(
      title: Text('Play next'.i18n),
      leading: const Icon(Icons.playlist_play),
      onTap: () async {
        //-1 = next
        await GetIt.I<AudioPlayerHandler>()
            .insertQueueItem(-1, t.toMediaItem());
        if (context.mounted) _close(context);
      });

  Widget addToQueue(Track t, BuildContext context) => ListTile(
      title: Text('Add to queue'.i18n),
      leading: const Icon(Icons.playlist_add),
      onTap: () async {
        await GetIt.I<AudioPlayerHandler>().addQueueItem(t.toMediaItem());
        if (context.mounted) _close(context);
      });

  Widget addTrackFavorite(Track t, BuildContext context) => ListTile(
      title: Text('Add track to favorites'.i18n),
      leading: const Icon(AlchemyIcons.heart_fill),
      onTap: () async {
        await deezerAPI.addFavoriteTrack(t.id!);
        //Make track offline, if favorites are offline
        Playlist p = Playlist(id: cache.favoritesPlaylistId);
        if (await downloadManager.checkOffline(playlist: p)) {
          downloadManager.addOfflinePlaylist(p);
        }
        Fluttertoast.showToast(
            msg: 'Added to library'.i18n,
            gravity: ToastGravity.BOTTOM,
            toastLength: Toast.LENGTH_SHORT);
        //Add to cache
        cache.libraryTracks ??= [];
        cache.libraryTracks?.add(t.id!);

        if (context.mounted) _close(context);
      });

  Widget downloadTrack(Track t, BuildContext context) {
    bool isOffline = false;
    downloadManager
        .checkOffline(track: t)
        .then((managerAnswer) => isOffline = managerAnswer);

    return ListTile(
      title: Text((isOffline) ? 'Remove from storage' : 'Download'.i18n),
      leading: (isOffline)
          ? Icon(
              AlchemyIcons.download_fill,
              color: Theme.of(context).primaryColor,
            )
          : Icon(AlchemyIcons.download),
      onTap: () async {
        bool isDownloaded = await downloadManager.checkOffline(track: t);
        if (isDownloaded) {}
        downloadManager.addOfflineTrack(t, private: true, isSingleton: true);
        showDownloadStartedToast();
        if (context.mounted) _close(context);
      },
    );
  }

  Widget addToPlaylist(Track t, BuildContext context) => ListTile(
        title: Text('Add to playlist'.i18n),
        leading: const Icon(Icons.playlist_add),
        onTap: () async {
          //Show dialog to pick playlist
          await showDialog(
              context: context,
              builder: (context) {
                return SelectPlaylistDialog(
                    track: t,
                    callback: (Playlist p) async {
                      await deezerAPI.addToPlaylist(t.id!, p.id!);
                      //Update the playlist if offline
                      if (await downloadManager.checkOffline(playlist: p)) {
                        downloadManager.addOfflinePlaylist(p);
                      }
                      Fluttertoast.showToast(
                        msg: 'Track added to'.i18n + ' ${p.title}',
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                      );
                    });
              });
          if (context.mounted) _close(context);
        },
      );

  Widget removeFromPlaylist(
          Track t, Playlist p, BuildContext context, Function? onRemove) =>
      ListTile(
        title: Text('Remove from playlist'.i18n),
        leading: const Icon(AlchemyIcons.trash),
        onTap: () async {
          await deezerAPI.removeFromPlaylist(t.id!, p.id!);
          if (onRemove != null) onRemove();
          Fluttertoast.showToast(
            msg: 'Track removed from'.i18n + ' ${p.title}',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
          if (context.mounted) _close(context);
        },
      );

  Widget removeFavoriteTrack(Track t, BuildContext context, {onUpdate}) =>
      ListTile(
        title: Text('Remove favorite'.i18n),
        leading: Icon(
          AlchemyIcons.heart_fill,
          color: Theme.of(context).primaryColor,
        ),
        onTap: () async {
          await deezerAPI.removeFavorite(t.id!);
          //Check if favorites playlist is offline, update it
          Playlist p = Playlist(id: cache.favoritesPlaylistId);
          if (await downloadManager.checkOffline(playlist: p)) {
            await downloadManager.addOfflinePlaylist(p);
          }
          //Remove from cache
          cache.libraryTracks?.removeWhere((i) => i == t.id);
          Fluttertoast.showToast(
              msg: 'Track removed from library'.i18n,
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM);
          if (onUpdate != null) onUpdate();
          if (context.mounted) _close(context);
        },
      );

  //Redirect to artist page (ie from track)
  Widget showArtist(Artist a, BuildContext context) => ListTile(
        title: Text(
          'Go to'.i18n + ' ${a.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: const Icon(Icons.recent_actors),
        onTap: () {
          if (context.mounted) _close(context);
          customNavigatorKey.currentState
              ?.push(MaterialPageRoute(builder: (context) => ArtistDetails(a)));

          navigateCallback();
        },
      );

  Widget showAlbum(Album a, BuildContext context) => ListTile(
        title: Text(
          'Go to'.i18n + ' ${a.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: const Icon(Icons.album),
        onTap: () async {
          if (context.mounted) _close(context);
          customNavigatorKey.currentState
              ?.push(MaterialPageRoute(builder: (context) => AlbumDetails(a)));

          navigateCallback();
        },
      );

  Widget playMix(Track track, BuildContext context) => ListTile(
        title: Text('Play mix'.i18n),
        leading: const Icon(Icons.online_prediction),
        onTap: () async {
          GetIt.I<AudioPlayerHandler>().playMix(track.id!, track.title!);
          if (context.mounted) _close(context);
        },
      );

  //===================
  // ALBUM
  //===================

  //Default album options
  void defaultAlbumMenu(Album album,
      {required BuildContext context,
      List<Widget> options = const [],
      Function? onRemove}) {
    show(context, [
      (album.library != null && onRemove != null)
          ? removeAlbum(album, context, onRemove: onRemove)
          : libraryAlbum(album, context),
      downloadAlbum(album, context),
      offlineAlbum(album, context),
      shareTile('album', album.id!),
      ...List.generate(album.artists?.length ?? 0, (int index) {
        return showArtist(album.artists![index], context);
      }),
      ...options
    ]);
  }

  //===================
  // ALBUM OPTIONS
  //===================

  Widget downloadAlbum(Album a, BuildContext context) => ListTile(
      title: Text('Download'.i18n),
      leading: const Icon(AlchemyIcons.download),
      onTap: () async {
        if (context.mounted) _close(context);
        if (await downloadManager.addOfflineAlbum(a, private: false) != false) {
          showDownloadStartedToast();
        }
      });

  Widget offlineAlbum(Album a, BuildContext context) => ListTile(
        title: Text('Make offline'.i18n),
        leading: const Icon(Icons.offline_pin),
        onTap: () async {
          await deezerAPI.addFavoriteAlbum(a.id!);
          await downloadManager.addOfflineAlbum(a, private: false);
          if (context.mounted) _close(context);
          showDownloadStartedToast();
        },
      );

  Widget libraryAlbum(Album a, BuildContext context) => ListTile(
        title: Text('Add to library'.i18n),
        leading: const Icon(Icons.library_music),
        onTap: () async {
          await deezerAPI.addFavoriteAlbum(a.id!);
          Fluttertoast.showToast(
              msg: 'Added to library'.i18n, gravity: ToastGravity.BOTTOM);
          if (context.mounted) _close(context);
        },
      );

  //Remove album from favorites
  Widget removeAlbum(Album a, BuildContext context,
          {required Function onRemove}) =>
      ListTile(
        title: Text('Remove album'.i18n),
        leading: const Icon(AlchemyIcons.trash),
        onTap: () async {
          await deezerAPI.removeAlbum(a.id!);
          await downloadManager.removeOfflineAlbum(a.id!);
          Fluttertoast.showToast(
            msg: 'Album removed'.i18n,
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
          onRemove();
          if (context.mounted) _close(context);
        },
      );

  //===================
  // ARTIST
  //===================

  void defaultArtistMenu(Artist artist,
      {required BuildContext context,
      List<Widget> options = const [],
      Function? onRemove}) {
    show(context, [
      (artist.library != null)
          ? removeArtist(artist, context, onRemove: onRemove)
          : favoriteArtist(artist, context),
      shareTile('artist', artist.id!),
      ...options
    ]);
  }

  //===================
  // ARTIST OPTIONS
  //===================

  Widget removeArtist(Artist a, BuildContext context, {Function? onRemove}) =>
      ListTile(
        title: Text('Remove from favorites'.i18n),
        leading: const Icon(AlchemyIcons.trash),
        onTap: () async {
          await deezerAPI.removeArtist(a.id!);
          Fluttertoast.showToast(
              msg: 'Artist removed from library'.i18n,
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM);
          if (onRemove != null) onRemove();
          if (context.mounted) _close(context);
        },
      );

  Widget favoriteArtist(Artist a, BuildContext context) => ListTile(
        title: Text('Add to favorites'.i18n),
        leading: const Icon(AlchemyIcons.heart_fill),
        onTap: () async {
          await deezerAPI.addFavoriteArtist(a.id!);
          Fluttertoast.showToast(
              msg: 'Added to library'.i18n,
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM);
          if (context.mounted) _close(context);
        },
      );

  //===================
  // PLAYLIST
  //===================

  void defaultPlaylistMenu(Playlist playlist,
      {required BuildContext context,
      List<Widget> options = const [],
      Function? onRemove,
      Function? onUpdate}) {
    show(context, [
      playBlindTest(playlist, context),
      if (!(playlist.library ?? false)) addPlaylistOffline(playlist, context),
      shareTile('playlist', playlist.id!),
      if (playlist.user?.id == deezerAPI.userId)
        editPlaylist(playlist, context: context, onUpdate: onUpdate),
      (playlist.library == true)
          ? (playlist.user?.id?.trim() == deezerAPI.userId)
              ? deletePlaylist(playlist, context: context, onUpdate: onUpdate)
              : removePlaylistLibrary(playlist, context, onRemove: onRemove)
          : addPlaylistLibrary(playlist, context),
      ...options
    ]);
  }

  //===================
  // PLAYLIST OPTIONS
  //===================

  Widget playBlindTest(Playlist p, BuildContext context,
          {Function? onRemove}) =>
      ListTile(
        title: Text('Play blind test'.i18n),
        leading: const Icon(AlchemyIcons.question),
        onTap: () async {
          Navigator.of(context, rootNavigator: true)
              .push(SlideBottomRoute(widget: BlindTestChoiceScreen(p)));
        },
      );

  Widget removePlaylistLibrary(Playlist p, BuildContext context,
          {Function? onRemove}) =>
      ListTile(
        title: Text('Remove from library'.i18n),
        leading: const Icon(AlchemyIcons.trash),
        onTap: () async {
          if (p.user?.id?.trim() == deezerAPI.userId) {
            //Delete playlist if own
            await deezerAPI.deletePlaylist(p.id!);
          } else {
            //Just remove from library
            await deezerAPI.removePlaylist(p.id!);
          }
          downloadManager.removeOfflinePlaylist(p.id!);
          if (onRemove != null) onRemove();
          if (context.mounted) _close(context);
        },
      );

  Widget addPlaylistLibrary(Playlist p, BuildContext context) => ListTile(
        title: Text('Add playlist to library'.i18n),
        leading: const Icon(AlchemyIcons.heart_fill),
        onTap: () async {
          await deezerAPI.addPlaylist(p.id!);
          Fluttertoast.showToast(
              msg: 'Added playlist to library'.i18n,
              gravity: ToastGravity.BOTTOM);
          if (context.mounted) _close(context);
        },
      );

  Widget addPlaylistOffline(Playlist p, BuildContext context) => ListTile(
        title: Text('Download playlist'.i18n),
        leading: const Icon(Icons.offline_pin),
        onTap: () async {
          //Add to library
          await deezerAPI.addPlaylist(p.id!);
          downloadManager.addOfflinePlaylist(p, private: false);
          if (context.mounted) _close(context);
          showDownloadStartedToast();
        },
      );

  Widget editPlaylist(Playlist p,
          {required BuildContext context, Function? onUpdate}) =>
      ListTile(
        title: Text('Edit playlist'.i18n),
        leading: const Icon(AlchemyIcons.pen),
        onTap: () async {
          if (context.mounted) _close(context);
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CreatePlaylistScreen(playlist: p),
            ),
          );
          if (onUpdate != null) onUpdate();
        },
      );

  Widget deletePlaylist(Playlist p,
          {required BuildContext context, Function? onUpdate}) =>
      ListTile(
        title: Text('Remove playlist'.i18n),
        leading: const Icon(AlchemyIcons.trash),
        onTap: () async {
          await deezerAPI.deletePlaylist(p.id ?? '');
          if (context.mounted) _close(context);

          if (onUpdate != null) onUpdate();
        },
      );

  //===================
  // SHOW/EPISODE
  //===================

  dynamic defaultShowEpisodeMenu(Show s, ShowEpisode e,
      {required BuildContext context, List<Widget> options = const []}) {
    show(context, [
      shareTile('episode', e.id!),
      shareShow(s.id!),
      downloadExternalEpisode(e),
      ...options
    ]);
  }

  Widget shareShow(String id) => ListTile(
        title: Text('Share show'.i18n),
        leading: const Icon(AlchemyIcons.share_android),
        onTap: () async {
          SharePlus.instance.share(
            ShareParams(
              text: 'https://deezer.com/show/$id',
            ),
          );
        },
      );

  //Open direct download link in browser
  Widget downloadExternalEpisode(ShowEpisode e) => ListTile(
        title: Text('Download externally'.i18n),
        leading: const Icon(AlchemyIcons.download),
        onTap: () async {
          if (e.url != null) await launchUrlString(e.url!);
        },
      );

  //===================
  // OTHER
  //===================

  dynamic showDownloadStartedToast() {
    Fluttertoast.showToast(
        msg: 'Downloads added!'.i18n,
        gravity: ToastGravity.BOTTOM,
        toastLength: Toast.LENGTH_SHORT);
  }

  //Create playlist
  Future createPlaylist(BuildContext context, {List<Track>? tracks}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatePlaylistScreen(tracks: tracks),
      ),
    );
  }

  Widget shareTile(String type, String id) => ListTile(
        title: Text('Share'.i18n),
        leading: const Icon(Icons.share),
        onTap: () async {
          SharePlus.instance.share(
            ShareParams(
              text: 'https://deezer.com/$type/$id',
            ),
          );
        },
      );

  Widget sleepTimer(BuildContext context) => ListTile(
        title: Text('Sleep timer'.i18n),
        leading: const Icon(Icons.access_time),
        onTap: () async {
          showDialog(
              context: context,
              builder: (context) {
                return const SleepTimerDialog();
              });
        },
      );

  Widget wakelock(BuildContext context) => ListTile(
        title: Text(cache.wakelock
            ? 'Allow screen to turn off'.i18n
            : 'Keep the screen on'.i18n),
        leading: const Icon(Icons.screen_lock_portrait),
        onTap: () async {
          _close(context);
          //Enable
          if (!cache.wakelock) {
            WakelockPlus.enable();
            Fluttertoast.showToast(
                msg: 'Wakelock enabled!'.i18n, gravity: ToastGravity.BOTTOM);
            cache.wakelock = true;
            return;
          }
          //Disable
          WakelockPlus.disable();
          Fluttertoast.showToast(
              msg: 'Wakelock disabled!'.i18n, gravity: ToastGravity.BOTTOM);
          cache.wakelock = false;
        },
      );

  void _close(BuildContext context) => {
        if (Navigator.of(context, rootNavigator: true).canPop())
          {Navigator.of(context, rootNavigator: true).pop()}
      };
}

class SleepTimerDialog extends StatefulWidget {
  const SleepTimerDialog({super.key});

  @override
  _SleepTimerDialogState createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends State<SleepTimerDialog> {
  int hours = 0;
  int minutes = 30;

  String _endTime() {
    return '${cache.sleepTimerTime!.hour.toString().padLeft(2, '0')}:${cache.sleepTimerTime!.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sleep timer'.i18n),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Hours:'.i18n),
                  NumberPicker(
                      value: hours,
                      minValue: 0,
                      maxValue: 69,
                      onChanged: (v) => setState(() => hours = v)),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Minutes:'.i18n),
                  NumberPicker(
                      value: minutes,
                      minValue: 0,
                      maxValue: 60,
                      onChanged: (v) => setState(() => minutes = v)),
                ],
              ),
            ],
          ),
          Container(height: 4.0),
          if (cache.sleepTimerTime != null)
            Text(
              'Current timer ends at'.i18n + ': ' + _endTime(),
              textAlign: TextAlign.center,
            )
        ],
      ),
      actions: [
        TextButton(
          child: Text('Dismiss'.i18n),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        if (cache.sleepTimer != null)
          TextButton(
            child: Text('Cancel current timer'.i18n),
            onPressed: () {
              cache.sleepTimer!.cancel();
              cache.sleepTimer = null;
              cache.sleepTimerTime = null;
              Navigator.of(context).pop();
            },
          ),
        TextButton(
          child: Text('Save'.i18n),
          onPressed: () {
            Duration duration = Duration(hours: hours, minutes: minutes);
            cache.sleepTimer?.cancel();
            //Create timer
            cache.sleepTimer =
                Stream.fromFuture(Future.delayed(duration)).listen((_) {
              GetIt.I<AudioPlayerHandler>().pause();
              cache.sleepTimer?.cancel();
              cache.sleepTimerTime = null;
              cache.sleepTimer = null;
            });
            cache.sleepTimerTime = DateTime.now().add(duration);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class SelectPlaylistDialog extends StatefulWidget {
  final Track? track;
  final Function callback;
  const SelectPlaylistDialog({this.track, required this.callback, super.key});

  @override
  _SelectPlaylistDialogState createState() => _SelectPlaylistDialogState();
}

class _SelectPlaylistDialogState extends State<SelectPlaylistDialog> {
  bool createNew = false;

  @override
  Widget build(BuildContext context) {
    //Create new playlist
    if (createNew) {
      if (widget.track == null) {
        return CreatePlaylistScreen();
      }
      return CreatePlaylistScreen(tracks: [widget.track!]);
    }

    return AlertDialog(
      title: Text('Select playlist'.i18n),
      content: FutureBuilder(
        future: deezerAPI.getPlaylists(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            const SizedBox(
              height: 100,
              child: ErrorScreen(),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          List<Playlist> playlists = snapshot.data!;
          return SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ...List.generate(
                  playlists.length,
                  (i) => ListTile(
                        title: Text(playlists[i].title!),
                        leading: CachedImage(
                          url: playlists[i].image?.thumb ?? '',
                        ),
                        onTap: () {
                          widget.callback(playlists[i]);
                          Navigator.of(context).pop();
                        },
                      )),
              ListTile(
                title: Text('Create new playlist'.i18n),
                leading: const Icon(Icons.add),
                onTap: () async {
                  setState(() {
                    createNew = true;
                  });
                },
              )
            ]),
          );
        },
      ),
    );
  }
}

class CreatePlaylistScreen extends StatefulWidget {
  final List<Track>? tracks;
  final Playlist? playlist;
  const CreatePlaylistScreen({this.tracks, this.playlist, super.key});

  @override
  _CreatePlaylistScreenState createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends State<CreatePlaylistScreen> {
  bool _isPrivate = true;
  bool _isCollaborative = false;
  bool _emptyTitle = false;
  String _title = '';
  TextEditingController? _titleController;
  List<int>? _imageBytes;
  bool _isLoading = false;
  bool _titleHasFocus = false;
  List<Track> _tracks = [];
  Color? _placeholderColor;

  final FocusNode _keyboardListenerFocusNode = FocusNode();
  final FocusNode _textFieldFocusNode = FocusNode();

  //Create or edit mode
  bool get edit => widget.playlist != null;

  Future<Uint8List> _createImageFromColor(Color color,
      {int width = 500, int height = 500}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
        recorder, Rect.fromLTWH(0.0, 0.0, width.toDouble(), height.toDouble()));
    final paint = Paint()..color = color;
    canvas.drawRect(
        Rect.fromLTWH(0.0, 0.0, width.toDouble(), height.toDouble()), paint);
    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  void initState() {
    //Edit playlist mode
    if (edit) {
      _title = widget.playlist?.title ?? '';
      _tracks = widget.playlist?.tracks ?? [];
    } else {
      _tracks = widget.tracks ?? [];
    }

    if (widget.playlist?.image == null) {
      _placeholderColor =
          Color((Random().nextDouble() * 0xFFFFFF).toInt()).withAlpha(255);
    }

    _titleController = TextEditingController(text: _title);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar(
        edit ? 'Edit playlist'.i18n : 'Create playlist'.i18n,
        actions: [
          TextButton(
              onPressed: () async {
                if (_title == '') {
                  Fluttertoast.showToast(
                      msg: "The playlist's title can't be empty.".i18n);
                  if (mounted) {
                    setState(() {
                      _emptyTitle = true;
                    });
                  }
                  return;
                }
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                    _keyboardListenerFocusNode.unfocus();
                    _textFieldFocusNode.unfocus();
                  });
                }
                if (edit) {
                  List<int>? imageToUpload = _imageBytes;
                  if (imageToUpload == null &&
                      widget.playlist?.image == null &&
                      _placeholderColor != null) {
                    imageToUpload =
                        await _createImageFromColor(_placeholderColor!);
                  }
                  //Update
                  await deezerAPI.updatePlaylist(
                    title: _titleController!.value.text,
                    playlistId: widget.playlist!.id!,
                    isPrivate: _isPrivate,
                    isCollaborative: _isCollaborative,
                    pictureData: imageToUpload,
                  );
                  Fluttertoast.showToast(
                      msg: 'Playlist updated!'.i18n,
                      gravity: ToastGravity.BOTTOM);
                } else {
                  List<int>? imageToUpload = _imageBytes;
                  if (imageToUpload == null && _placeholderColor != null) {
                    imageToUpload =
                        await _createImageFromColor(_placeholderColor!);
                  }
                  List<String> tracks = [];
                  tracks = _tracks.map<String>((t) => t.id!).toList();
                  await deezerAPI.createPlaylist(
                      title: _title,
                      isPrivate: _isPrivate,
                      isCollaborative: _isCollaborative,
                      pictureData: imageToUpload,
                      trackIds: tracks);
                  Fluttertoast.showToast(
                      msg: 'Playlist created!'.i18n,
                      gravity: ToastGravity.BOTTOM);
                }
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ))
        ],
      ),
      body: Stack(
        children: [
          ListView(
            children: <Widget>[
              Padding(
                padding: EdgeInsetsGeometry.only(top: 30, bottom: 45),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: AlignmentDirectional.bottomEnd,
                      children: [
                        Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: ShapeDecoration(
                            shape: SmoothRectangleBorder(
                              borderRadius: SmoothBorderRadius(
                                cornerRadius: 30,
                                cornerSmoothing: 0.8,
                              ),
                            ),
                          ),
                          child: (_imageBytes?.isNotEmpty ?? false)
                              ? Image.memory(
                                  _imageBytes as Uint8List,
                                  height: 160,
                                  width: 160,
                                  fit: BoxFit.cover,
                                )
                              : widget.playlist?.image != null
                                  ? CachedImage(
                                      url: widget.playlist?.image?.full ?? '',
                                      width: 160,
                                      height: 160,
                                    )
                                  : Container(
                                      height: 160,
                                      width: 160,
                                      color: _placeholderColor),
                        ),
                        IconButton(
                            onPressed: () async {
                              ImagePicker picker = ImagePicker();
                              XFile? imageFile = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1000,
                                maxHeight: 1000,
                              );
                              if (imageFile == null) return;
                              List<int>? imageData =
                                  await imageFile.readAsBytes();
                              if (mounted) {
                                setState(() {
                                  _imageBytes = imageData;
                                });
                              }
                            },
                            icon: Icon(AlchemyIcons.pen))
                      ],
                    )
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Name'.i18n,
                  style: TextStyle(color: Settings.secondaryText),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(
                  16,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: KeyboardListener(
                        focusNode: _keyboardListenerFocusNode,
                        onKeyEvent: (event) {
                          // For Android TV: quit search textfield
                          if (event is KeyUpEvent) {
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowDown) {
                              _textFieldFocusNode.unfocus();
                            }
                          }
                        },
                        child: Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: ShapeDecoration(
                            shape: SmoothRectangleBorder(
                              borderRadius: SmoothBorderRadius(
                                cornerRadius: 10,
                                cornerSmoothing: 0.4,
                              ),
                              side: _emptyTitle
                                  ? BorderSide(
                                      color: Colors.redAccent,
                                      width: 1.5,
                                    )
                                  : _titleHasFocus
                                      ? BorderSide(
                                          color: settings.theme == Themes.Light
                                              ? Colors.black.withAlpha(100)
                                              : Colors.white.withAlpha(100),
                                          width: 1.5)
                                      : BorderSide.none,
                            ),
                          ),
                          child: Focus(
                            onFocusChange: (focused) {
                              setState(() {
                                _titleHasFocus = focused;
                              });
                            },
                            focusNode: _textFieldFocusNode,
                            child: TextField(
                              onChanged: (String s) {
                                if (mounted && s != '') {
                                  setState(() {
                                    _emptyTitle = false;
                                    _title = s;
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Playlist name',
                                hintStyle: TextStyle(
                                  color: settings.theme == Themes.Light
                                      ? Colors.black.withAlpha(100)
                                      : Colors.white.withAlpha(100),
                                ),

                                fillColor: settings.theme == Themes.Light
                                    ? Colors.black.withAlpha(30)
                                    : Colors.white.withAlpha(30),
                                filled: true,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 4.0,
                                    horizontal: 10.0), // Added contentPadding
                              ),
                              controller: _titleController,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (String s) {},
                              style: TextStyle(
                                  color: settings.theme == Themes.Light
                                      ? Colors.black
                                      : Colors.white),
                              cursorColor: settings.theme == Themes.Light
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Preferences'.i18n,
                  style: TextStyle(color: Settings.secondaryText),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(
                  16,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        clipBehavior: Clip.hardEdge,
                        decoration: ShapeDecoration(
                            shape: SmoothRectangleBorder(
                                borderRadius: SmoothBorderRadius(
                                  cornerRadius: 10,
                                  cornerSmoothing: 0.4,
                                ),
                                side: BorderSide(
                                    color: settings.theme == Themes.Light
                                        ? Colors.black.withAlpha(100)
                                        : Colors.white.withAlpha(100),
                                    width: 1.5)),
                            color: settings.theme == Themes.Light
                                ? Colors.black.withAlpha(30)
                                : Colors.white.withAlpha(30)),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                AlchemyIcons.humans,
                                size: 20,
                              ),
                              title: Text('Collaborative'),
                              trailing: Switch(
                                value: _isCollaborative,
                                onChanged: (bool v) {
                                  if (mounted && !_isPrivate) {
                                    setState(() => _isCollaborative = v);
                                  }
                                },
                              ),
                              enabled: !_isPrivate,
                            ),
                            FreezerDivider(),
                            ListTile(
                              leading: Icon(
                                AlchemyIcons.mask,
                                size: 20,
                              ),
                              title: Text('Private'),
                              trailing: Switch(
                                value: _isPrivate,
                                onChanged: (bool v) {
                                  if (mounted && !_isCollaborative) {
                                    setState(() => _isPrivate = v);
                                  }
                                },
                              ),
                              enabled: !_isCollaborative,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...List.generate(
                  _tracks.length,
                  (int i) => TrackTile(
                        _tracks[i],
                        trailing: IconButton(
                            onPressed: () {
                              deezerAPI.removeFromPlaylist(_tracks[i].id ?? '',
                                  widget.playlist?.id ?? '');
                              if (mounted) {
                                setState(() {
                                  _tracks.removeAt(i);
                                });
                              }
                            },
                            icon: Icon(
                              AlchemyIcons.trash,
                              color: Colors.redAccent,
                            )),
                      ))
            ],
          ),
          if (_isLoading)
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              alignment: Alignment.center,
              color: Colors.black.withAlpha(30),
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            )
        ],
      ),
    );
  }
}
