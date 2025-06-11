import 'dart:async';
import 'dart:math';

import 'package:alchemy/ui/catcher_screen.dart';
import 'package:alchemy/settings.dart';
import 'package:alchemy/ui/cached_image.dart';
import 'package:alchemy/ui/settings_screen.dart';
import 'package:alchemy/utils/connectivity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:alchemy/main.dart';
import 'package:figma_squircle/figma_squircle.dart';

import '../api/cache.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';
import '../service/audio_service.dart';
import '../translations.i18n.dart';
import '../ui/details_screens.dart';
import '../ui/elements.dart';
import '../ui/home_screen.dart';
import '../ui/menu.dart';
import './tiles.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String? _query;
  bool _online = true;
  //bool _loading = false;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _keyboardListenerFocusNode = FocusNode();
  final FocusNode _textFieldFocusNode = FocusNode();
  InstantSearchResults? _searchResults;
  bool _showCards = true;
  bool _hasFocus = false;
  Timer? _debounce;
  int _historyDisplayLength = 0;

  List<SearchHistoryItem> _recentlySearched = [];
  List<HomePageSection> _searchSections = [];

  void _loadUserRecentlySearched() async {
    if (mounted) {
      setState(() {
        _recentlySearched = cache.searchHistory ?? [];
      });
    }

    if (await isConnected()) {
      List<SearchHistoryItem> recentlySearched =
          await deezerAPI.getUserHistory();
      if (mounted) {
        setState(() {
          _recentlySearched = recentlySearched;
        });
      }

      cache.searchHistory = recentlySearched;
      cache.save();
    }

    if (mounted) {
      setState(() {
        _historyDisplayLength = min(5, _recentlySearched.length);
      });
    }
  }

  void _load() async {
    if (mounted) {
      setState(() {
        _searchSections = cache.searchSections;
      });
    }

    bool netStatus = await isConnected();

    if (mounted) {
      setState(() {
        _online = netStatus;
        //_loading = false;
      });
    }

    if (netStatus) {
      List<HomePageSection> searchSections =
          await deezerAPI.getUserSearchPage();

      if (mounted) {
        setState(() {
          _searchSections = searchSections;
        });
      }

      cache.searchSections = searchSections;
      cache.save();
    }
  }

  @override
  void initState() {
    _load();
    _loadUserRecentlySearched();

    super.initState();
  }

  @override
  void dispose() {
    _textFieldFocusNode.dispose();
    _keyboardListenerFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _search(String query) async {
    if (mounted) {
      setState(() {
        _query = query;
      });
    }
    if (!_online && mounted) {
      InstantSearchResults instantSearchResults =
          await downloadManager.search(query);
      setState(() {
        _searchResults = instantSearchResults;
      });
    } else if (mounted) {
      InstantSearchResults instantSearchResults = await deezerAPI.instantSearch(
        query,
        includeBestResult: true,
        includeTracks: true,
        includeAlbums: true,
        includeArtists: true,
        includePlaylists: true,
        includeUsers: true,
        includeFlowConfigs: true,
        includeLivestreams: true,
        includePodcasts: true,
        includePodcastEpisodes: true,
        includeChannels: true,
      );
      setState(() {
        _searchResults = instantSearchResults;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FocusScope(
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
                    'Discover',
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
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => SettingsScreen()));
                      },
                      icon: const Icon(AlchemyIcons.settings),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width * 0.05,
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
                                cornerRadius: 20,
                                cornerSmoothing: 0.4,
                              ),
                              side: _hasFocus
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
                                _hasFocus = focused;
                                if (!focused &&
                                    (_query == null || _query!.isEmpty)) {
                                  _showCards = true;
                                }
                                if (focused) {
                                  _showCards = false;
                                }
                              });
                            },
                            focusNode: _textFieldFocusNode,
                            child: TextField(
                              onChanged: (String s) {
                                if (_debounce?.isActive ?? false) {
                                  _debounce!.cancel();
                                }
                                _debounce = Timer(
                                    const Duration(milliseconds: 300), () {
                                  _search(s);
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search',
                                hintStyle: TextStyle(
                                    color: settings.theme == Themes.Light
                                        ? Colors.black.withAlpha(100)
                                        : Colors.white.withAlpha(100)),
                                prefixIcon: Icon(
                                  AlchemyIcons
                                      .search, // Replace with AlchemyIcons.search if available
                                  color: settings.theme == Themes.Light
                                      ? Colors.black.withAlpha(100)
                                      : Colors.white.withAlpha(100),
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  // Added suffixIcon
                                  icon: Icon(Icons.clear,
                                      color: _hasFocus
                                          ? settings.theme == Themes.Light
                                              ? Colors.black
                                              : Colors.white
                                          : settings.theme == Themes.Light
                                              ? Colors.black.withAlpha(100)
                                              : Colors.white.withAlpha(100),
                                      size: 16),
                                  splashRadius:
                                      20, // Adjust splash radius as needed
                                  onPressed: () {
                                    _controller.clear(); // Clear text field
                                    _textFieldFocusNode
                                        .unfocus(); // Release focus
                                    setState(() {
                                      _showCards = true;
                                      _hasFocus = false;
                                      _searchResults = null;
                                      _query = '';
                                    });
                                  },
                                ),
                                fillColor: settings.theme == Themes.Light
                                    ? Colors.black.withAlpha(30)
                                    : Colors.white.withAlpha(30),
                                filled: true,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 18.0,
                                    horizontal: 20.0), // Added contentPadding
                              ),
                              controller: _controller,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (String s) {
                                _search(s);
                                _textFieldFocusNode.unfocus();
                              },
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
              if (_showCards && (_searchResults?.empty ?? true))
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.05),
                  child: SizedBox(
                    height: 84,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                                builder: (context) => CatcherScreen()));
                      },
                      child: Container(
                        clipBehavior: Clip.hardEdge,
                        decoration: ShapeDecoration(
                            shape: SmoothRectangleBorder(
                              borderRadius: SmoothBorderRadius(
                                cornerRadius: 20,
                                cornerSmoothing: 0.4,
                              ),
                              side: BorderSide(
                                  color: settings.primaryColor, width: 1.5),
                            ),
                            color: settings.primaryColor.withAlpha(100)),
                        alignment: Alignment.centerLeft,
                        child: ListTile(
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12.0),
                          //visualDensity: VisualDensity.compact,
                          leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                AlchemyIcons.wave,
                                size: 32,
                              ),
                            ],
                          ),
                          title: Text(
                            'What is playing ?',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Identify the music playing around you.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_showCards && !_online && (_searchResults?.empty ?? true))
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          AlchemyIcons.offline,
                          size: 30,
                          color: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.color
                              ?.withAlpha(150),
                        ),
                        Text(
                          'Oops, we are offline'.i18n,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.color
                                  ?.withAlpha(150),
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_showCards && _online && (_searchResults?.empty ?? true))
                ...List.generate(
                  _searchSections.length,
                  (i) {
                    switch (_searchSections[i].layout) {
                      case HomePageSectionLayout.ROW:
                        return HomepageRowSection(_searchSections[i]);
                      case HomePageSectionLayout.GRID:
                        return HomePageGridSection(_searchSections[i]);
                      default:
                        return HomepageRowSection(_searchSections[i]);
                    }
                  },
                ),

              //History
              if (!_showCards &&
                  _recentlySearched.isNotEmpty &&
                  ((_query ?? '').length < 2 &&
                      ((_searchResults?.empty ?? true) || _query == ''))) ...[
                ListTile(
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.05),
                  title: Text(
                    'Recent searches'.i18n,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                    ),
                  ),
                  trailing: IconButton(
                    onPressed: () {
                      deezerAPI.callPipeApi(params: {
                        'operationName': 'ClearSearchSuccessResult',
                        'variables': {},
                        'query':
                            'mutation ClearSearchSuccessResult { clearSearchSuccessResult { __typename status } }'
                      });
                      cache.searchHistory = [];
                      cache.save();
                      setState(() {});
                    },
                    icon: Icon(
                      AlchemyIcons.trash,
                      size: 20,
                    ),
                  ),
                ),
                ...List.generate(
                  _historyDisplayLength,
                  (int i) {
                    dynamic data = _recentlySearched[i].data;
                    switch (_recentlySearched[i].type) {
                      case SearchHistoryItemType.TRACK:
                        return Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05),
                          child: TrackTile(
                            data,
                            padding: EdgeInsets.zero,
                            onTap: () {
                              List<Track> queue = _recentlySearched
                                  .where((h) =>
                                      h.type == SearchHistoryItemType.TRACK)
                                  .map<Track>((t) => t.data)
                                  .toList();
                              GetIt.I<AudioPlayerHandler>().playFromTrackList(
                                  queue,
                                  data.id,
                                  QueueSource(
                                      text: 'Search history'.i18n,
                                      source: 'searchhistory',
                                      id: 'searchhistory'));
                            },
                            onHold: () {
                              MenuSheet m = MenuSheet();
                              m.defaultTrackMenu(data, context: context);
                            },
                          ),
                        );
                      case SearchHistoryItemType.ALBUM:
                        return Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05),
                          child: AlbumTile(
                            data,
                            padding: EdgeInsets.zero,
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => AlbumDetails(data)));
                            },
                            onHold: () {
                              MenuSheet m = MenuSheet();
                              m.defaultAlbumMenu(data, context: context);
                            },
                          ),
                        );
                      case SearchHistoryItemType.ARTIST:
                        return Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05),
                          child: ArtistHorizontalTile(
                            data,
                            padding: EdgeInsets.zero,
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => ArtistDetails(data)));
                            },
                            onHold: () {
                              MenuSheet m = MenuSheet();
                              m.defaultArtistMenu(data, context: context);
                            },
                          ),
                        );
                      case SearchHistoryItemType.PLAYLIST:
                        return Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05),
                          child: PlaylistTile(
                            data,
                            padding: EdgeInsets.zero,
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => PlaylistDetails(data)));
                            },
                            onHold: () {
                              MenuSheet m = MenuSheet();
                              m.defaultPlaylistMenu(data, context: context);
                            },
                          ),
                        );
                      case SearchHistoryItemType.SHOW:
                        return Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05),
                          child: ShowTile(
                            data,
                            padding: EdgeInsets.zero,
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => ShowScreen(data)));
                            },
                            onHold: () {
                              MenuSheet m = MenuSheet();
                              m.defaultShowEpisodeMenu(data, data?.episodes?[0],
                                  context: context);
                            },
                          ),
                        );
                      case SearchHistoryItemType.EPISODE:
                        return Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05),
                          child: ShowEpisodeTile(
                            data,
                            padding: EdgeInsets.zero,
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => ShowScreen(data)));
                            },
                            onHold: () {
                              MenuSheet m = MenuSheet();
                              m.defaultShowEpisodeMenu(data, data?.episodes?[0],
                                  context: context);
                            },
                          ),
                        );
                    }
                  },
                ),
                if (_recentlySearched.isNotEmpty &&
                    _historyDisplayLength < _recentlySearched.length)
                  ViewAllButton(
                    onTap: () {
                      if (mounted) {
                        setState(() {
                          _historyDisplayLength = _recentlySearched.length;
                        });
                      }
                    },
                  )
              ],

              if ((_query != '') && !_showCards)
                Builder(
                  key: Key(_query ?? ''),
                  builder: (BuildContext context) {
                    if (_searchResults == null) {
                      return const SizedBox
                          .shrink(); // Or a loading indicator if you prefer
                    }

                    final results = _searchResults!;

                    if (results.empty && _query != '') {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                AlchemyIcons.warning,
                                size: 30,
                                color: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.color
                                    ?.withAlpha(150),
                              ),
                              Text(
                                'Empty results.'.i18n,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.color
                                        ?.withAlpha(150),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "Oops, looks like we couldn't find what you are looking for."
                                    .i18n,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.color
                                      ?.withAlpha(150),
                                  fontSize: 12,
                                ),
                              ),
                              if (_online)
                                Text(
                                  'This could be due to a technical error or poor internet connection. Check your connection and reload the page.'
                                      .i18n,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.color
                                        ?.withAlpha(150),
                                    fontSize: 12,
                                  ),
                                ),
                              if (!_online)
                                Text(
                                  'Offline searches are only performed against your downloaded content.'
                                      .i18n,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.color
                                        ?.withAlpha(150),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }

                    //Tracks
                    List<Widget> tracks = [];
                    if (results.tracks != null && results.tracks!.isNotEmpty) {
                      tracks = [
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05,
                              vertical: 20.0),
                          child: Text(
                            'Tracks'.i18n,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                                fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...List.generate(3, (i) {
                          if (results.tracks!.length <= i) {
                            return const SizedBox(
                              width: 0,
                              height: 0,
                            );
                          }
                          Track t = results.tracks![i];
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05,
                            ),
                            child: TrackTile(
                              t,
                              padding: EdgeInsets.zero,
                              onTap: () {
                                cache.addToSearchHistory(t);
                                GetIt.I<AudioPlayerHandler>().playFromTrackList(
                                    results.tracks!,
                                    t.id ?? '',
                                    QueueSource(
                                        text: 'Search'.i18n,
                                        id: _query,
                                        source: 'search'));
                              },
                              onHold: () {
                                MenuSheet m = MenuSheet();
                                m.defaultTrackMenu(t, context: context);
                              },
                            ),
                          );
                        }),
                        ViewAllButton(
                          onTap: () async {
                            InstantSearchResults trackResults =
                                await deezerAPI.instantSearch(_query ?? '',
                                    includeTracks: true, count: 25);
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => TrackListScreen(
                                    trackResults.tracks ?? [],
                                    QueueSource(
                                        id: _query,
                                        source: 'search',
                                        text: 'Search'.i18n),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ];
                    }

                    //Albums
                    List<Widget> albums = [];
                    if (results.albums != null && results.albums!.isNotEmpty) {
                      albums = [
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05,
                              vertical: 20),
                          child: Text(
                            'Albums'.i18n,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                                fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...List.generate(3, (i) {
                          if (results.albums!.length <= i) {
                            return const SizedBox(
                              height: 0,
                              width: 0,
                            );
                          }
                          Album a = results.albums![i];
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05,
                            ),
                            child: AlbumTile(
                              a,
                              padding: EdgeInsets.zero,
                              onHold: () {
                                MenuSheet m = MenuSheet();
                                m.defaultAlbumMenu(a, context: context);
                              },
                              onTap: () {
                                cache.addToSearchHistory(a);
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => AlbumDetails(a)));
                              },
                            ),
                          );
                        }),
                        ViewAllButton(
                          onTap: () async {
                            InstantSearchResults trackResults =
                                await deezerAPI.instantSearch(_query ?? '',
                                    includeAlbums: true, count: 25);
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => AlbumListScreen(
                                    trackResults.albums ?? [],
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ];
                    }

                    //Artists
                    List<Widget> artists = [];
                    if (results.artists != null &&
                        results.artists!.isNotEmpty) {
                      artists = [
                        Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05),
                          child: Text(
                            'Artists'.i18n,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                                fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(height: 4),
                        Padding(
                          padding: EdgeInsets.only(
                              left: MediaQuery.of(context).size.width * 0.05),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(
                                results.artists!.length,
                                (int i) {
                                  Artist a = results.artists![i];
                                  return ArtistTile(
                                    a,
                                    onTap: () {
                                      cache.addToSearchHistory(a);
                                      Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  ArtistDetails(a)));
                                    },
                                    onHold: () {
                                      MenuSheet m = MenuSheet();
                                      m.defaultArtistMenu(a, context: context);
                                    },
                                    size: MediaQuery.of(context).size.width / 4,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ];
                    }

                    //Playlists
                    List<Widget> playlists = [];
                    if (results.playlists != null &&
                        results.playlists!.isNotEmpty) {
                      playlists = [
                        Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05),
                          child: Text(
                            'Playlists'.i18n,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                                fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...List.generate(3, (i) {
                          if (results.playlists!.length <= i) {
                            return const SizedBox(
                              height: 0,
                              width: 0,
                            );
                          }
                          Playlist p = results.playlists![i];
                          return Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal:
                                    MediaQuery.of(context).size.width * 0.05),
                            child: PlaylistTile(
                              padding: EdgeInsets.zero,
                              p,
                              onTap: () {
                                cache.addToSearchHistory(p);
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => PlaylistDetails(p)));
                              },
                              onHold: () {
                                MenuSheet m = MenuSheet();
                                m.defaultPlaylistMenu(p, context: context);
                              },
                            ),
                          );
                        }),
                        ViewAllButton(
                          onTap: () async {
                            InstantSearchResults trackResults =
                                await deezerAPI.instantSearch(_query ?? '',
                                    includePlaylists: true, count: 25);
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => SearchResultPlaylists(
                                    trackResults.playlists ?? [],
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ];
                    }

                    //Shows
                    List<Widget> shows = [];
                    if (results.shows != null && results.shows!.isNotEmpty) {
                      shows = [
                        Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05),
                          child: Text(
                            'Shows'.i18n,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                                fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...List.generate(3, (i) {
                          if (results.shows!.length <= i) {
                            return const SizedBox(
                              height: 0,
                              width: 0,
                            );
                          }
                          Show s = results.shows![i];
                          return Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal:
                                    MediaQuery.of(context).size.width * 0.05),
                            child: ShowTile(
                              s,
                              padding: EdgeInsets.zero,
                              onTap: () async {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => ShowScreen(s)));
                              },
                            ),
                          );
                        }),
                        ViewAllButton(
                          onTap: () async {
                            InstantSearchResults trackResults =
                                await deezerAPI.instantSearch(_query ?? '',
                                    includePodcasts: true, count: 25);
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ShowListScreen(
                                    trackResults.shows ?? [],
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ];
                    }

                    //Episodes
                    List<Widget> episodes = [];
                    if (results.episodes != null &&
                        results.episodes!.isNotEmpty) {
                      episodes = [
                        Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.05),
                          child: Text(
                            'Episodes'.i18n,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                                fontSize: 20.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...List.generate(3, (i) {
                          if (results.episodes!.length <= i) {
                            return const SizedBox(
                              height: 0,
                              width: 0,
                            );
                          }
                          ShowEpisode e = results.episodes![i];
                          return Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal:
                                    MediaQuery.of(context).size.width * 0.05),
                            child: ShowEpisodeTile(
                              e,
                              padding: EdgeInsets.zero,
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.more_vert,
                                  semanticLabel: 'Options'.i18n,
                                ),
                                onPressed: () {
                                  MenuSheet m = MenuSheet();
                                  m.defaultShowEpisodeMenu(e.show!, e,
                                      context: context);
                                },
                              ),
                              onTap: () async {
                                //Load entire show, then play
                                Show show =
                                    await deezerAPI.show(e.show?.id ?? '');
                                await GetIt.I<AudioPlayerHandler>()
                                    .playShowEpisode(
                                  show,
                                  show.episodes ?? [],
                                  index: show.episodes?.indexWhere(
                                          (ShowEpisode ep) => e.id == ep.id) ??
                                      0,
                                );
                              },
                            ),
                          );
                        }),
                        ViewAllButton(
                          onTap: () async {
                            InstantSearchResults trackResults =
                                await deezerAPI.instantSearch(_query ?? '',
                                    includePodcastEpisodes: true, count: 25);
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => EpisodeListScreen(
                                    trackResults.episodes ?? [],
                                  ),
                                ),
                              );
                            }
                          },
                        )
                      ];
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          height: 8.0,
                        ),
                        if (results.bestResult != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: 16.0,
                                    horizontal:
                                        MediaQuery.of(context).size.width *
                                            0.05),
                                child: Text(
                                  'Top result',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20.0),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 16.0),
                                child: Container(
                                  clipBehavior: Clip.hardEdge,
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Theme.of(context)
                                              .scaffoldBackgroundColor
                                              .withAlpha(0)),
                                      borderRadius: BorderRadius.circular(10),
                                      color: Colors.white.withAlpha(30)),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    radius: 10.0,
                                    onTap: results.bestResult.runtimeType ==
                                            Track
                                        ? () {
                                            GetIt.I<AudioPlayerHandler>()
                                                .playMix(results.bestResult.id,
                                                    results.bestResult.title);
                                          }
                                        : results.bestResult.runtimeType ==
                                                Album
                                            ? () {
                                                Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            AlbumDetails(results
                                                                .bestResult)));
                                              }
                                            : results.bestResult.runtimeType ==
                                                    ShowEpisode
                                                ? () {
                                                    GetIt.I<AudioPlayerHandler>()
                                                        .playShowEpisode(
                                                            results.bestResult
                                                                ?.show,
                                                            [
                                                              results.bestResult
                                                            ],
                                                            index: 0);
                                                  }
                                                : results.bestResult
                                                            .runtimeType ==
                                                        Playlist
                                                    ? () {
                                                        Navigator.of(context).push(
                                                            MaterialPageRoute(
                                                                builder: (context) =>
                                                                    PlaylistDetails(
                                                                        results
                                                                            .bestResult)));
                                                      }
                                                    : results.bestResult
                                                                .runtimeType ==
                                                            Artist
                                                        ? () {
                                                            Navigator.of(
                                                                    context)
                                                                .push(MaterialPageRoute(
                                                                    builder: (context) =>
                                                                        ArtistDetails(
                                                                            results.bestResult)));
                                                          }
                                                        : results.bestResult
                                                                    .runtimeType ==
                                                                Show
                                                            ? () {
                                                                Navigator.of(
                                                                        context)
                                                                    .push(MaterialPageRoute(
                                                                        builder:
                                                                            (context) =>
                                                                                ShowScreen(results.bestResult)));
                                                              }
                                                            : () {},
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 6.0, horizontal: 8.0),
                                          child: CachedImage(
                                            url: results
                                                    .bestResult?.image?.full ??
                                                '',
                                            height: 60,
                                            width: 60,
                                            fullThumb: true,
                                            rounded: true,
                                          ),
                                        ),
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              results.bestResult.runtimeType ==
                                                          Track ||
                                                      results.bestResult
                                                              .runtimeType ==
                                                          Album ||
                                                      results.bestResult
                                                              .runtimeType ==
                                                          ShowEpisode ||
                                                      results.bestResult
                                                              .runtimeType ==
                                                          Playlist
                                                  ? results.bestResult.title
                                                  : results.bestResult
                                                                  .runtimeType ==
                                                              Artist ||
                                                          results.bestResult
                                                                  .runtimeType ==
                                                              Show
                                                      ? results.bestResult.name
                                                      : '',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                              style: TextStyle(fontSize: 16.0),
                                            ),
                                            Text(
                                                results.bestResult.runtimeType ==
                                                            Track ||
                                                        results.bestResult
                                                                .runtimeType ==
                                                            Album
                                                    ? (results.bestResult.artists as List<Artist?>?)
                                                                ?.isNotEmpty ??
                                                            false
                                                        ? 'Track • By ' +
                                                            results
                                                                .bestResult
                                                                .artists[0]
                                                                ?.name
                                                        : ''
                                                    : results.bestResult.runtimeType ==
                                                            Artist
                                                        ? 'Artist • ' +
                                                            results.bestResult.fans
                                                                .toString() +
                                                            ' fans'
                                                        : results.bestResult.runtimeType == Show ||
                                                                results.bestResult.runtimeType ==
                                                                    ShowEpisode
                                                            ? 'Podcast'
                                                            : results.bestResult.runtimeType ==
                                                                    Playlist
                                                                ? 'Playlist • By ' +
                                                                    results
                                                                        .bestResult
                                                                        .user
                                                                        .name
                                                                : '',
                                                style: TextStyle(
                                                    fontSize: 12.0,
                                                    color: Settings.secondaryText))
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ...tracks,
                        ...albums,
                        ...artists,
                        ...playlists,
                        ...shows,
                        ...episodes,
                      ],
                    );
                  },
                ),
              ListenableBuilder(
                  listenable: playerBarState,
                  builder: (BuildContext context, Widget? child) {
                    return AnimatedPadding(
                      duration: Duration(milliseconds: 200),
                      padding: EdgeInsets.only(
                          bottom: playerBarState.state ? 80 : 0),
                    );
                  }),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchBrowseCard extends StatelessWidget {
  final Color color;
  final Widget? icon;
  final VoidCallback onTap;
  final String text;
  const SearchBrowseCard(
      {super.key,
      required this.color,
      required this.onTap,
      required this.text,
      this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: MediaQuery.of(context).size.width / 2 - 32,
            height: 75,
            child: Center(
                child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) icon!,
                if (icon != null) Container(width: 8.0),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: (color.computeLuminance() > 0.5)
                          ? Colors.black
                          : Colors.white),
                ),
              ],
            )),
          ),
        ));
  }
}

//List all tracks
class TrackListScreen extends StatefulWidget {
  final QueueSource queueSource;
  final List<Track> tracks;
  final Future<List<Track>>? load;

  const TrackListScreen(this.tracks, this.queueSource, {this.load, super.key});

  @override
  _TrackListScreenState createState() => _TrackListScreenState();
}

class _TrackListScreenState extends State<TrackListScreen> {
  bool _isLoading = false;
  List<Track> _tracks = [];

  void _parentLoader() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    List<Track> fetchedTracks = await widget.load!;

    if (mounted) {
      setState(() {
        _tracks = fetchedTracks;
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    if (mounted && widget.load != null) {
      _parentLoader();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? SplashScreen()
        : Scaffold(
            appBar: FreezerAppBar('Tracks'.i18n),
            body: ListView.builder(
              itemCount: _tracks.length,
              itemBuilder: (BuildContext context, int i) {
                Track t = _tracks[i];
                return TrackTile(
                  t,
                  onTap: () {
                    GetIt.I<AudioPlayerHandler>().playFromTrackList(
                        _tracks, t.id ?? '', widget.queueSource);
                  },
                  onHold: () {
                    MenuSheet m = MenuSheet();
                    m.defaultTrackMenu(t, context: context);
                  },
                );
              },
            ),
          );
  }
}

//List all albums
class AlbumListScreen extends StatelessWidget {
  final List<Album> albums;
  const AlbumListScreen(this.albums, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Albums'.i18n),
      body: ListView.builder(
        itemCount: albums.length,
        itemBuilder: (context, i) {
          Album a = albums[i];
          return AlbumTile(
            a,
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => AlbumDetails(a)));
            },
            onHold: () {
              MenuSheet m = MenuSheet();
              m.defaultAlbumMenu(a, context: context);
            },
          );
        },
      ),
    );
  }
}

class SearchResultPlaylists extends StatelessWidget {
  final List<Playlist> playlists;
  const SearchResultPlaylists(this.playlists, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Playlists'.i18n),
      body: ListView.builder(
        itemCount: playlists.length,
        itemBuilder: (context, i) {
          Playlist p = playlists[i];
          return PlaylistTile(
            p,
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => PlaylistDetails(p)));
            },
            onHold: () {
              MenuSheet m = MenuSheet();
              m.defaultPlaylistMenu(p, context: context);
            },
          );
        },
      ),
    );
  }
}

class ShowListScreen extends StatelessWidget {
  final List<Show> shows;
  const ShowListScreen(this.shows, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Shows'.i18n),
      body: ListView.builder(
        itemCount: shows.length,
        itemBuilder: (context, i) {
          Show s = shows[i];
          return ShowTile(
            s,
            onTap: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (context) => ShowScreen(s)));
            },
          );
        },
      ),
    );
  }
}

class EpisodeListScreen extends StatelessWidget {
  final List<ShowEpisode> episodes;
  const EpisodeListScreen(this.episodes, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: FreezerAppBar('Episodes'.i18n),
        body: ListView.builder(
          itemCount: episodes.length,
          itemBuilder: (context, i) {
            ShowEpisode e = episodes[i];
            return ShowEpisodeTile(
              e,
              trailing: IconButton(
                icon: Icon(
                  Icons.more_vert,
                  semanticLabel: 'Options'.i18n,
                ),
                onPressed: () {
                  MenuSheet m = MenuSheet();
                  m.defaultShowEpisodeMenu(e.show!, e, context: context);
                },
              ),
              onTap: () async {
                //Load entire show, then play
                Show show = await deezerAPI.show(e.show?.id ?? '');
                await GetIt.I<AudioPlayerHandler>().playShowEpisode(
                  show,
                  show.episodes ?? [],
                  index: show.episodes
                          ?.indexWhere((ShowEpisode ep) => e.id == ep.id) ??
                      0,
                );
              },
            );
          },
        ));
  }
}
