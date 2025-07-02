import 'dart:math';

import 'package:alchemy/service/audio_service.dart';
import 'package:alchemy/ui/cached_image.dart';
import 'package:flutter/material.dart';
import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:alchemy/main.dart';
import 'package:alchemy/ui/details_screens.dart';
import 'package:alchemy/ui/library.dart';
import 'package:alchemy/ui/menu.dart';
import 'package:alchemy/ui/tiles.dart';
import 'package:alchemy/utils/connectivity.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:get_it/get_it.dart';

import '../api/cache.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';
import '../settings.dart';
import '../translations.i18n.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String? favoriteShows = '0';
  String? favoriteArtists = '0';
  String? favoriteAlbums = '0';
  Playlist? topPlaylist;

  List<Playlist>? _playlists;

  Playlist? favoritesPlaylist;
  bool _loading = false;

  List<Track> tracks = [];
  List<Track> randomTracks = [];
  int? trackCount;

  void _makeFavorite() {
    for (final track in tracks) {
      track.favorite = true;
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    // --- Initial fast load from cache ---
    if (cache.favoritePlaylists.isNotEmpty &&
        cache.favoritePlaylists[0].id != null) {
      _playlists = cache.favoritePlaylists;
    }
    if (cache.favoriteTracks.isNotEmpty) {
      tracks = cache.favoriteTracks;
      trackCount = tracks.length;
    }
    // Immediate UI update with cached data
    if (mounted) setState(() {});

    // --- Fetch data from sources ---
    final isOnline = await isConnected();
    List<Future> futures = [];

    if (!isOnline) {
      futures.add(downloadManager
          .getOfflinePlaylist(cache.favoritesPlaylistId)
          .then((favPlaylist) {
        if (mounted && favPlaylist != null) {
          setState(() {
            tracks = favPlaylist.tracks ?? [];
            favoritesPlaylist = favPlaylist;
            trackCount = favPlaylist.tracks?.length;
            _makeFavorite();
          });
        } else if (mounted) {
          // Fallback to all offline tracks if favorites playlist is not downloaded
          futures.add(downloadManager.allOfflineTracks().then((offlineTracks) {
            if (mounted) {
              setState(() {
                tracks = offlineTracks;
                trackCount = offlineTracks.length;
                favoritesPlaylist = Playlist(
                    id: '0',
                    title: 'Offline tracks'.i18n,
                    duration: Duration.zero,
                    tracks: offlineTracks);
              });
            }
          }));
        }
      }));
      futures.add(downloadManager.getOfflinePlaylists().then((playlists) {
        if (mounted) setState(() => _playlists = playlists);
      }));
      futures.add(downloadManager.getOfflineAlbums().then((albums) {
        if (mounted) setState(() => favoriteAlbums = albums.length.toString());
      }));
      futures.add(downloadManager.getOfflineShows().then((shows) {
        if (mounted) setState(() => favoriteShows = shows.length.toString());
      }));
    } else {
      // isOnline
      futures.add(deezerAPI.getPlaylists().then((onlinePlaylists) {
        if (mounted && onlinePlaylists.isNotEmpty) {
          setState(() {
            _playlists = onlinePlaylists;
            cache.favoritePlaylists = onlinePlaylists;
          });
        }
      }));

      futures.add(deezerAPI.getArtists().then((userArtists) {
        if (mounted) {
          setState(() => favoriteArtists = userArtists.length.toString());
        }
      }));

      futures.add(deezerAPI.getAlbums().then((userAlbums) {
        if (mounted) {
          setState(() => favoriteAlbums = userAlbums.length.toString());
        }
      }));

      futures.add(deezerAPI.getUserShows().then((userShows) {
        if (mounted) {
          setState(() => favoriteShows = userShows.length.toString());
        }
      }));

      // Top tracks and favorites are fetched together to decide which one to display
      final trackFutures = Future.wait([
        deezerAPI.userTracks(),
        deezerAPI.fullPlaylist(cache.favoritesPlaylistId),
      ]);
      futures.add(trackFutures);

      trackFutures.then((results) {
        if (!mounted) return;
        final topTracks = results[0] as List<Track>?;
        final onlineFavPlaylist = results[1] as Playlist?;

        setState(() {
          // Always update favorites playlist for its own tile
          if (onlineFavPlaylist != null) {
            favoritesPlaylist = onlineFavPlaylist;
          }

          if (topTracks != null && topTracks.isNotEmpty) {
            tracks = topTracks;
            topPlaylist = Playlist(
              id: '1',
              title: 'Your top tracks'.i18n,
              image: ImageDetails.fromJson(cache.userPicture),
              tracks: topTracks,
            );
          } else if (onlineFavPlaylist != null) {
            tracks = onlineFavPlaylist.tracks ?? [];
            topPlaylist = onlineFavPlaylist;
          }
          trackCount = tracks.length;
          cache.favoriteTracks = tracks;
        });
      });
    }

    // When all futures are complete, stop loading indicator and save cache
    Future.wait(futures).whenComplete(() {
      if (mounted) {
        setState(() => _loading = false);
        if (isOnline) {
          cache.save();
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
            padding: const EdgeInsets.only(top: 12.0),
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.05),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CachedImage(
                        url: ImageDetails.fromJson(cache.userPicture).fullUrl ??
                            '',
                        circular: true,
                      ),
                    ),
                  ),
                ),
                title: const Center(
                  child: Text(
                    'Library',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                trailing: SizedBox(
                  height: 60,
                  width: 60,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      splashRadius: 20,
                      alignment: Alignment.center,
                      onPressed: () {
                        List<Track> trackList = List.from(tracks);
                        trackList.shuffle();
                        GetIt.I<AudioPlayerHandler>().playFromTrackList(
                            trackList,
                            trackList[0].id ?? '',
                            QueueSource(
                                id: '',
                                source: 'Library',
                                text: 'Library shuffle'.i18n));
                      },
                      icon: const Icon(AlchemyIcons.shuffle),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Padding(
                  padding:
                      EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: LibraryGridItem(
                              title: 'Favorites'.i18n,
                              subtitle: '${(trackCount ?? 0)} ' + 'Songs'.i18n,
                              icon: AlchemyIcons.heart,
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => PlaylistDetails(
                                        favoritesPlaylist ??
                                            Playlist(
                                                id: cache
                                                    .favoritesPlaylistId))));
                              },
                            ),
                          ),

                          SizedBox(
                              width: MediaQuery.of(context).size.width *
                                  0.05), // Spacing between items
                          Expanded(
                            child: LibraryGridItem(
                              title: 'Artists'.i18n,
                              subtitle: favoriteArtists != null
                                  ? '$favoriteArtists ' + 'Artists'.i18n
                                  : 'You are offline',
                              icon: AlchemyIcons.human_circle,
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => LibraryArtists()));
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).size.width *
                              0.05), // Spacing between rows
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: LibraryGridItem(
                              title: 'Podcasts'.i18n,
                              subtitle: '$favoriteShows ' + 'Shows'.i18n,
                              icon: AlchemyIcons.podcast,
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) =>
                                        const LibraryShows()));
                              },
                            ),
                          ),
                          SizedBox(
                              width: MediaQuery.of(context).size.width *
                                  0.05), // Spacing between items
                          Expanded(
                            child: LibraryGridItem(
                              title: 'Albums'.i18n,
                              subtitle: favoriteAlbums != null
                                  ? '$favoriteAlbums ' + 'Albums'.i18n
                                  : 'You are offline',
                              icon: AlchemyIcons.album,
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => LibraryAlbums()));
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if ((_playlists?.isEmpty ?? true) && _loading)
                SizedBox(
                  height: 260,
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.05),
                    title: Text(
                      'Your Playlists'.i18n,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    trailing: Transform.scale(
                        scale: 0.5,
                        child: CircularProgressIndicator(
                            color: Theme.of(context).primaryColor)),
                    onTap: () => {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const LibraryPlaylists()))
                    },
                  ),
                ),
              if (_playlists?.isNotEmpty ?? false)
                SizedBox(
                  height: 260,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal:
                                MediaQuery.of(context).size.width * 0.05),
                        title: Text(
                          'Your Playlists'.i18n,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        trailing: _loading
                            ? Transform.scale(
                                scale: 0.5,
                                child: CircularProgressIndicator(
                                    color: Theme.of(context).primaryColor))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text((_playlists!.length).toString(),
                                      style: TextStyle(
                                          color: Settings.secondaryText)),
                                  const Icon(
                                    Icons.chevron_right,
                                  )
                                ],
                              ),
                        onTap: () => {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => const LibraryPlaylists()))
                        },
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.only(
                            left: MediaQuery.of(context).size.width * 0.03),
                        child: Row(children: [
                          if (_playlists != null)
                            ...List.generate(_playlists!.length,
                                (int i) => LargePlaylistTile(_playlists![i]))
                        ]),
                      ),
                    ],
                  ),
                ),
              if (tracks.isEmpty && _loading)
                Column(children: [
                  SizedBox(
                    height: 224,
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.05),
                      title: Text(
                        'Your Top Tracks'.i18n,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      trailing: Transform.scale(
                          scale: 0.5,
                          child: CircularProgressIndicator(
                              color: Theme.of(context).primaryColor)),
                      onTap: () => (favoritesPlaylist != null)
                          ? Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => PlaylistDetails(
                                  favoritesPlaylist ?? Playlist())))
                          : null,
                    ),
                  ),
                ]),
              if (tracks.isNotEmpty)
                SizedBox(
                  child: Column(children: [
                    ListTile(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.05),
                      title: Text(
                        'Your Top Tracks'.i18n,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      trailing: _loading
                          ? Transform.scale(
                              scale: 0.5,
                              child: CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text((tracks.length).toString(),
                                    style: TextStyle(
                                        color: Settings.secondaryText)),
                                const Icon(
                                  Icons.chevron_right,
                                )
                              ],
                            ),
                      onTap: () =>
                          (topPlaylist != null || favoritesPlaylist != null)
                              ? Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => PlaylistDetails(
                                      topPlaylist ??
                                          favoritesPlaylist ??
                                          Playlist())))
                              : null,
                    ),
                    ...List.generate(
                      min(5, tracks.length),
                      (int index) => Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05),
                          child: SimpleTrackTile(tracks[index], topPlaylist)),
                    ),
                  ]),
                ),
              ListenableBuilder(
                  listenable: playerBarState,
                  builder: (BuildContext context, Widget? child) {
                    return AnimatedPadding(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.only(
                          bottom: playerBarState.state ? 80 : 0),
                    );
                  }),
            ]),
      ),
    );
  }
}

class PlayerMenuButton extends StatelessWidget {
  final Track track;
  const PlayerMenuButton(this.track, {super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(
        AlchemyIcons.more_vert,
        semanticLabel: 'Options',
      ),
      onPressed: () {
        MenuSheet m = MenuSheet();
        m.defaultTrackMenu(track, context: context);
      },
    );
  }
}

class LibraryGridItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const LibraryGridItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(25),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
        decoration: ShapeDecoration(
          color: settings.theme == Themes.Light
              ? Colors.black.withAlpha(30)
              : Colors.white.withAlpha(30),
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
              cornerRadius: 25,
              cornerSmoothing: 0.6,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0, top: 4.0),
              child: Icon(icon, size: 20),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
