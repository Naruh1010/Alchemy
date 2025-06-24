// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:alchemy/ui/blind_test.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:alchemy/main.dart';
import 'package:alchemy/settings.dart';
import 'package:alchemy/utils/connectivity.dart';
import 'package:logging/logging.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../api/cache.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';
import '../service/audio_service.dart';
import '../translations.i18n.dart';
import '../ui/elements.dart';
import '../ui/error.dart';
import '../ui/search.dart';
import 'cached_image.dart';
import 'menu.dart';
import 'tiles.dart';

class AlbumDetails extends StatefulWidget {
  final Album album;
  const AlbumDetails(this.album, {super.key});

  @override
  _AlbumDetailsState createState() => _AlbumDetailsState();
}

class _AlbumDetailsState extends State<AlbumDetails> {
  Album album = Album();
  bool _isLoading = true;
  bool _error = false;
  final PageController _albumController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  Color _accentColor = Colors.transparent;

  Future _loadAlbum() async {
    if (mounted) setState(() => _isLoading = true);
    //Get album from API, if doesn't have tracks
    if ((album.tracks ?? []).isEmpty) {
      try {
        if (await isConnected()) {
          Album a = await deezerAPI.album(album.id ?? '');
          //Preserve library
          a.library = album.library;
          if (mounted && a.id != null) setState(() => album = a);
        } else {
          Album? a = await downloadManager.getOfflineAlbum(album.id ?? '');
          //Preserve library
          a?.library = album.library;
          if (mounted && a?.id != null) setState(() => album = a ?? Album());
        }
      } catch (e) {
        if (mounted) setState(() => _error = true);
      }
    }
    _setColor();
    if (mounted) setState(() => _isLoading = false);
  }

  //Get count of CDs in album
  int get cdCount {
    int c = 1;
    for (Track t in (album.tracks ?? [])) {
      if ((t.diskNumber ?? 1) > c) c = t.diskNumber ?? 0;
    }
    return c;
  }

  Future _isLibrary() async {
    if (album.isIn(await downloadManager.getOfflineAlbums())) {
      setState(() {
        album.library = true;
      });
    }
    if (album.isIn(await deezerAPI.getAlbums())) {
      setState(() {
        album.library = true;
      });
    }
  }

  void _setColor() async {
    ColorScheme palette = await ColorScheme.fromImageProvider(
      provider: CachedNetworkImageProvider(
          album.image?.fullUrl ?? album.image?.thumbUrl ?? ''),
    );

    if (mounted) {
      setState(() {
        _accentColor = palette.secondary;
      });
    }
  }

  @override
  void initState() {
    album = widget.album;
    _setColor();
    _loadAlbum();
    _isLibrary();

    super.initState();

    _albumController.addListener(() {
      setState(() {
        _currentPage = _albumController.page?.round() ?? 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: _error
            ? const ErrorScreen()
            : _isLoading
                ? SplashScreen()
                : OrientationBuilder(
                    builder: (context, orientation) {
                      //Responsive
                      ScreenUtil.init(context, minTextAdapt: true);
                      //Landscape
                      if (orientation == Orientation.landscape) {
                        return SafeArea(
                          left: false,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height,
                                width: MediaQuery.of(context).size.width * 0.4,
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 4.0),
                                        child: ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            visualDensity:
                                                VisualDensity.compact,
                                            horizontalTitleGap: 8.0,
                                            leading: IconButton(
                                                onPressed: () async {
                                                  await Navigator.of(context)
                                                      .maybePop();
                                                },
                                                icon: Icon(Icons.arrow_back)),
                                            title: Text(
                                              album.title ?? '',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18.0,
                                              ),
                                            ),
                                            subtitle: Text(
                                              album.artistString ?? '',
                                              style: TextStyle(
                                                  fontSize: 14.0,
                                                  color:
                                                      Settings.secondaryText),
                                            ),
                                            trailing: IconButton(
                                              icon:
                                                  Icon(AlchemyIcons.more_vert),
                                              onPressed: () {
                                                MenuSheet m = MenuSheet();
                                                m.defaultAlbumMenu(album,
                                                    context: context);
                                              },
                                            ))),
                                    SizedBox(
                                        width:
                                            MediaQuery.of(context).size.height *
                                                0.5,
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.5,
                                        child: Stack(
                                          children: [
                                            PageView(
                                              controller: _albumController,
                                              onPageChanged: (index) {
                                                setState(() {
                                                  _currentPage = index;
                                                });
                                              },
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  children: [
                                                    Stack(
                                                      children: [
                                                        CachedImage(
                                                          url: album.image
                                                                  ?.full ??
                                                              album.image
                                                                  ?.thumb ??
                                                              'assets/cover.jpg',
                                                          width: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .height *
                                                              0.5,
                                                          fullThumb: true,
                                                          rounded: true,
                                                        ),
                                                        Column(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .end,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Container(
                                                                decoration: BoxDecoration(
                                                                    gradient: LinearGradient(
                                                                        colors: [
                                                                          Theme.of(context)
                                                                              .scaffoldBackgroundColor
                                                                              .withAlpha(150),
                                                                          Colors
                                                                              .transparent
                                                                        ],
                                                                        begin: Alignment
                                                                            .bottomCenter,
                                                                        end: Alignment
                                                                            .topCenter,
                                                                        stops: [
                                                                          0.0,
                                                                          0.7
                                                                        ])),
                                                                child: SizedBox(
                                                                  width: MediaQuery.of(
                                                                              context)
                                                                          .size
                                                                          .height *
                                                                      0.5,
                                                                  height: MediaQuery.of(
                                                                              context)
                                                                          .size
                                                                          .height *
                                                                      0.1,
                                                                )),
                                                          ],
                                                        ),
                                                      ],
                                                    )
                                                  ],
                                                ),
                                                Container(
                                                    clipBehavior: Clip.hardEdge,
                                                    decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .scaffoldBackgroundColor,
                                                        border: Border.all(
                                                            color: Colors
                                                                .transparent),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(5)),
                                                    child: ListView(
                                                      children: [
                                                        ListTile(
                                                          dense: true,
                                                          visualDensity:
                                                              VisualDensity(
                                                                  horizontal:
                                                                      0.0,
                                                                  vertical: -4),
                                                          minVerticalPadding: 0,
                                                          title: Text(
                                                            'Tracks'.i18n,
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16),
                                                          ),
                                                          subtitle: Text(
                                                              (album.tracks
                                                                      ?.length)
                                                                  .toString(),
                                                              style: TextStyle(
                                                                  color: Settings
                                                                      .secondaryText,
                                                                  fontSize:
                                                                      12)),
                                                        ),
                                                        ListTile(
                                                          dense: true,
                                                          visualDensity:
                                                              VisualDensity(
                                                                  horizontal:
                                                                      0.0,
                                                                  vertical: -4),
                                                          minVerticalPadding: 0,
                                                          title: Text(
                                                            'Duration'.i18n,
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16),
                                                          ),
                                                          subtitle: Text(
                                                              album
                                                                  .durationString,
                                                              style: TextStyle(
                                                                  color: Settings
                                                                      .secondaryText,
                                                                  fontSize:
                                                                      12)),
                                                        ),
                                                        ListTile(
                                                          dense: true,
                                                          visualDensity:
                                                              VisualDensity(
                                                                  horizontal:
                                                                      0.0,
                                                                  vertical: -4),
                                                          minVerticalPadding: 0,
                                                          title: Text(
                                                            'Fans'.i18n,
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16),
                                                          ),
                                                          subtitle: Text(
                                                              (album.fans ?? 0)
                                                                  .toString(),
                                                              style: TextStyle(
                                                                  color: Settings
                                                                      .secondaryText,
                                                                  fontSize:
                                                                      12)),
                                                        ),
                                                        ListTile(
                                                          dense: true,
                                                          visualDensity:
                                                              VisualDensity(
                                                                  horizontal:
                                                                      0.0,
                                                                  vertical: -4),
                                                          minVerticalPadding: 0,
                                                          title: Text(
                                                            'Released'.i18n,
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16),
                                                          ),
                                                          subtitle: Text(
                                                              album.releaseDate ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Settings
                                                                      .secondaryText,
                                                                  fontSize:
                                                                      12)),
                                                        ),
                                                      ],
                                                    ))
                                              ],
                                            ),
                                            Column(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Padding(
                                                  padding:
                                                      EdgeInsets.only(top: 8.0),
                                                  child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: List.generate(
                                                          2,
                                                          (i) => Container(
                                                                margin: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            2.0,
                                                                        vertical:
                                                                            8.0),
                                                                width: 12.0,
                                                                height: 4.0,
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .white
                                                                      .withAlpha(_currentPage ==
                                                                              i
                                                                          ? 255
                                                                          : 150),
                                                                  border: Border.all(
                                                                      color: Colors
                                                                          .transparent),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              100),
                                                                ),
                                                              ))),
                                                ),
                                              ],
                                            ),
                                          ],
                                        )),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4.0, horizontal: 6.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        mainAxisSize: MainAxisSize.max,
                                        children: <Widget>[
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding:
                                                    EdgeInsets.only(right: 8.0),
                                                child: IconButton(
                                                  icon: (album.library ?? false)
                                                      ? Icon(
                                                          AlchemyIcons
                                                              .heart_fill,
                                                          size: 25,
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                          semanticLabel:
                                                              'Unlove'.i18n,
                                                        )
                                                      : Icon(
                                                          AlchemyIcons.heart,
                                                          size: 25,
                                                          semanticLabel:
                                                              'Love'.i18n,
                                                        ),
                                                  onPressed: () async {
                                                    //Add to library
                                                    if (!(album.library ??
                                                        false)) {
                                                      bool result =
                                                          await deezerAPI
                                                              .addFavoriteAlbum(
                                                                  album.id ??
                                                                      '');
                                                      if (result) {
                                                        Fluttertoast.showToast(
                                                            msg:
                                                                'Added to library'
                                                                    .i18n,
                                                            toastLength: Toast
                                                                .LENGTH_SHORT,
                                                            gravity:
                                                                ToastGravity
                                                                    .BOTTOM);
                                                        setState(() => album
                                                            .library = true);
                                                      } else {
                                                        Fluttertoast.showToast(
                                                            msg:
                                                                'Failed to add album to library'
                                                                    .i18n,
                                                            toastLength: Toast
                                                                .LENGTH_SHORT,
                                                            gravity:
                                                                ToastGravity
                                                                    .BOTTOM);
                                                      }
                                                      return;
                                                    }
                                                    //Remove
                                                    bool result =
                                                        await deezerAPI
                                                            .removeAlbum(
                                                                album.id ?? '');
                                                    if (result) {
                                                      Fluttertoast.showToast(
                                                          msg:
                                                              'Album removed from library!'
                                                                  .i18n,
                                                          toastLength: Toast
                                                              .LENGTH_SHORT,
                                                          gravity: ToastGravity
                                                              .BOTTOM);
                                                      setState(() => album
                                                          .library = false);
                                                    } else {
                                                      Fluttertoast.showToast(
                                                          msg:
                                                              'Failed to remove album from library'
                                                                  .i18n,
                                                          toastLength: Toast
                                                              .LENGTH_SHORT,
                                                          gravity: ToastGravity
                                                              .BOTTOM);
                                                    }
                                                  },
                                                ),
                                              ),
                                              IconButton(
                                                  onPressed: () => {
                                                        SharePlus.instance
                                                            .share(
                                                          ShareParams(
                                                            text:
                                                                'https://deezer.com/album/' +
                                                                    (album.id ??
                                                                        ''),
                                                          ),
                                                        )
                                                      },
                                                  icon: Icon(
                                                    AlchemyIcons.share_android,
                                                    size: 20.0,
                                                  )),
                                              Padding(
                                                padding:
                                                    EdgeInsets.only(left: 8.0),
                                                child: MakeAlbumOffline(
                                                    album: album),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Container(
                                                margin:
                                                    EdgeInsets.only(right: 6.0),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .primaryColor,
                                                  border: Border.all(
                                                      color: Theme.of(context)
                                                          .scaffoldBackgroundColor
                                                          .withAlpha(0)),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          100),
                                                ),
                                                child: IconButton(
                                                    onPressed: () async {
                                                      album.tracks?.shuffle();
                                                      GetIt.I<AudioPlayerHandler>()
                                                          .playFromTrackList(
                                                              album.tracks ??
                                                                  [],
                                                              album.tracks?[0]
                                                                      .id ??
                                                                  '',
                                                              QueueSource(
                                                                  id: album.id,
                                                                  source: album
                                                                      .title,
                                                                  text: album
                                                                          .title ??
                                                                      'Album' +
                                                                          ' shuffle'
                                                                              .i18n));
                                                    },
                                                    icon: Icon(
                                                      AlchemyIcons.shuffle,
                                                      size: 18,
                                                    )),
                                              )
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView(
                                  children: [
                                    ...List.generate(
                                        (album.tracks?.length ?? 0), (i) {
                                      Track t = (album.tracks ?? [])[i];
                                      return TrackTile(t, onTap: () {
                                        Playlist p = Playlist(
                                            title: album.title,
                                            id: album.id,
                                            tracks: album.tracks);
                                        GetIt.I<AudioPlayerHandler>()
                                            .playFromPlaylist(p, t.id ?? '');
                                      }, onHold: () {
                                        MenuSheet m = MenuSheet();
                                        m.defaultTrackMenu(t, context: context);
                                      });
                                    }),
                                    if (_isLoading)
                                      Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: <Widget>[
                                            CircularProgressIndicator(
                                              color: Theme.of(context)
                                                  .primaryColor,
                                            )
                                          ],
                                        ),
                                      ),
                                    if (_error && (album.tracks ?? []).isEmpty)
                                      const ErrorScreen(),
                                    ListenableBuilder(
                                        listenable: playerBarState,
                                        builder: (BuildContext context,
                                            Widget? child) {
                                          return AnimatedPadding(
                                            duration:
                                                Duration(milliseconds: 200),
                                            padding: EdgeInsets.only(
                                                bottom: playerBarState.state
                                                    ? 80
                                                    : 0),
                                          );
                                        }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      //Portrait
                      // ignore: prefer_const_constructors
                      return CustomScrollView(
                        controller: _scrollController,
                        slivers: <Widget>[
                          DetailedAppBar(
                            title: album.title ?? '',
                            subtitle: album.artists?[0].name,
                            moreFunction: () {
                              MenuSheet m = MenuSheet();
                              m.defaultAlbumMenu(album, context: context);
                            },
                            expandedHeight: MediaQuery.of(context).size.width,
                            backgroundColor: _accentColor,
                            screens: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Stack(
                                    children: [
                                      CachedImage(
                                        url: album.image?.fullUrl ??
                                            album.image?.thumbUrl ??
                                            'assets/cover.jpg',
                                        height:
                                            MediaQuery.of(context).size.width,
                                        width:
                                            MediaQuery.of(context).size.width,
                                        fullThumb: true,
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                    colors: [
                                                      Theme.of(context)
                                                          .scaffoldBackgroundColor
                                                          .withAlpha(150),
                                                      Theme.of(context)
                                                          .scaffoldBackgroundColor
                                                          .withAlpha(0)
                                                    ],
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    stops: [0.0, 0.7])),
                                            child: SizedBox(
                                              width: MediaQuery.of(context)
                                                  .size
                                                  .width,
                                              height: MediaQuery.of(context)
                                                      .size
                                                      .width /
                                                  6,
                                            ),
                                          ),
                                          Container(
                                              decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                      colors: [
                                                        Theme.of(context)
                                                            .scaffoldBackgroundColor
                                                            .withAlpha(150),
                                                        Colors.transparent
                                                      ],
                                                      begin: Alignment
                                                          .bottomCenter,
                                                      end: Alignment.topCenter,
                                                      stops: [0.0, 0.7])),
                                              child: SizedBox(
                                                width: MediaQuery.of(context)
                                                    .size
                                                    .width,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .width /
                                                    6,
                                              )),
                                        ],
                                      ),
                                    ],
                                  )
                                ],
                              ),
                              Container(
                                decoration: BoxDecoration(color: _accentColor),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      minVerticalPadding: 1,
                                      leading: Icon(
                                        AlchemyIcons.album,
                                        size: 25,
                                      ),
                                      title: Text(
                                        'Tracks'.i18n,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      subtitle: Text(
                                          (album.tracks?.length).toString(),
                                          style: TextStyle(
                                              color: Settings.secondaryText,
                                              fontSize: 12)),
                                    ),
                                    ListTile(
                                      minVerticalPadding: 1,
                                      leading: Icon(
                                        AlchemyIcons.clock,
                                        size: 25,
                                      ),
                                      title: Text(
                                        'Duration'.i18n,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      subtitle: Text(album.durationString,
                                          style: TextStyle(
                                              color: Settings.secondaryText,
                                              fontSize: 12)),
                                    ),
                                    ListTile(
                                      minVerticalPadding: 1,
                                      leading: Icon(
                                        AlchemyIcons.heart,
                                        size: 25,
                                      ),
                                      title: Text(
                                        'Fans'.i18n,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      subtitle: Text(
                                          (album.fans ?? 0).toString(),
                                          style: TextStyle(
                                              color: Settings.secondaryText,
                                              fontSize: 12)),
                                    ),
                                    ListTile(
                                      minVerticalPadding: 1,
                                      leading: Icon(
                                        AlchemyIcons.calendar,
                                        size: 25,
                                      ),
                                      title: Text(
                                        'Released'.i18n,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      subtitle: Text(album.releaseDate ?? '',
                                          style: TextStyle(
                                              color: Settings.secondaryText,
                                              fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            scrollController: _scrollController,
                          ),
                          SliverToBoxAdapter(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_accentColor, Colors.transparent],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: ListTile(
                                      title: Text(
                                        album.title ?? '',
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.start,
                                        maxLines: 1,
                                        style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 40.0,
                                            fontWeight: FontWeight.w900),
                                      ),
                                      subtitle: Text(
                                        album.artistString ?? '',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                            color: Settings.secondaryText,
                                            fontSize: 14.0),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0, horizontal: 6.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      mainAxisSize: MainAxisSize.max,
                                      children: <Widget>[
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(right: 8.0),
                                              child: IconButton(
                                                  icon: (album.library ?? false)
                                                      ? Icon(
                                                          AlchemyIcons
                                                              .heart_fill,
                                                          size: 25,
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                          semanticLabel:
                                                              'Unlove'.i18n,
                                                        )
                                                      : Icon(
                                                          AlchemyIcons.heart,
                                                          size: 25,
                                                          semanticLabel:
                                                              'Love'.i18n,
                                                        ),
                                                  onPressed: () async {
                                                    //Add to library
                                                    if (!(album.library ??
                                                        false)) {
                                                      bool result =
                                                          await deezerAPI
                                                              .addFavoriteAlbum(
                                                                  album.id ??
                                                                      '');
                                                      if (result) {
                                                        Fluttertoast.showToast(
                                                            msg:
                                                                'Added to library'
                                                                    .i18n,
                                                            toastLength: Toast
                                                                .LENGTH_SHORT,
                                                            gravity:
                                                                ToastGravity
                                                                    .BOTTOM);
                                                        setState(() => album
                                                            .library = true);
                                                      } else {
                                                        Fluttertoast.showToast(
                                                            msg:
                                                                'Failed to add album to library'
                                                                    .i18n,
                                                            toastLength: Toast
                                                                .LENGTH_SHORT,
                                                            gravity:
                                                                ToastGravity
                                                                    .BOTTOM);
                                                      }
                                                      return;
                                                    }
                                                    //Remove
                                                    bool result =
                                                        await deezerAPI
                                                            .removeAlbum(
                                                                album.id ?? '');
                                                    if (result) {
                                                      Fluttertoast.showToast(
                                                          msg:
                                                              'Album removed from library!'
                                                                  .i18n,
                                                          toastLength: Toast
                                                              .LENGTH_SHORT,
                                                          gravity: ToastGravity
                                                              .BOTTOM);
                                                      setState(() => album
                                                          .library = false);
                                                    } else {
                                                      Fluttertoast.showToast(
                                                          msg:
                                                              'Failed to remove album from library'
                                                                  .i18n,
                                                          toastLength: Toast
                                                              .LENGTH_SHORT,
                                                          gravity: ToastGravity
                                                              .BOTTOM);
                                                    }
                                                  }),
                                            ),
                                            IconButton(
                                                onPressed: () => {
                                                      SharePlus.instance.share(
                                                        ShareParams(
                                                          text:
                                                              'https://deezer.com/album/' +
                                                                  (album.id ??
                                                                      ''),
                                                        ),
                                                      )
                                                    },
                                                icon: Icon(
                                                  AlchemyIcons.share_android,
                                                  size: 20.0,
                                                )),
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(left: 8.0),
                                              child: MakeAlbumOffline(
                                                  album: album),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Container(
                                              margin:
                                                  EdgeInsets.only(right: 6.0),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                border: Border.all(
                                                    color: Theme.of(context)
                                                        .scaffoldBackgroundColor
                                                        .withAlpha(0)),
                                                borderRadius:
                                                    BorderRadius.circular(100),
                                              ),
                                              child: IconButton(
                                                  onPressed: () async {
                                                    album.tracks?.shuffle();
                                                    GetIt.I<AudioPlayerHandler>()
                                                        .playFromTrackList(
                                                            album.tracks ?? [],
                                                            album.tracks?[0]
                                                                    .id ??
                                                                '',
                                                            QueueSource(
                                                                id: album.id,
                                                                source:
                                                                    album.title,
                                                                text: album
                                                                        .title ??
                                                                    'Album' +
                                                                        ' shuffle'
                                                                            .i18n));
                                                  },
                                                  icon: Icon(
                                                    AlchemyIcons.shuffle,
                                                    size: 18,
                                                  )),
                                            )
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Container(
                              height: 4.0,
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (BuildContext context, int index) {
                                Track t = (album.tracks ?? [])[index];
                                return TrackTile(
                                  t,
                                  onTap: () {
                                    Playlist p = Playlist(
                                        title: album.title,
                                        id: album.id,
                                        tracks: album.tracks);
                                    GetIt.I<AudioPlayerHandler>()
                                        .playFromPlaylist(p, t.id ?? '');
                                  },
                                  onHold: () {
                                    MenuSheet m = MenuSheet();
                                    m.defaultTrackMenu(t, context: context);
                                  },
                                );
                              },
                              childCount: (album.tracks?.length ?? 0),
                            ),
                          ),
                          if (_isLoading)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    CircularProgressIndicator(
                                      color: Theme.of(context).primaryColor,
                                    )
                                  ],
                                ),
                              ),
                            ),
                          if (_error && (album.tracks ?? []).isEmpty)
                            const SliverToBoxAdapter(
                              child: ErrorScreen(),
                            ),
                          SliverToBoxAdapter(
                            child: ListenableBuilder(
                              listenable: playerBarState,
                              builder: (BuildContext context, Widget? child) {
                                return AnimatedPadding(
                                  duration: Duration(milliseconds: 200),
                                  padding: EdgeInsets.only(
                                      bottom: playerBarState.state ? 80 : 0),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ));
  }
}

class MakeAlbumOffline extends StatefulWidget {
  final Album? album;
  const MakeAlbumOffline({super.key, this.album});

  @override
  _MakeAlbumOfflineState createState() => _MakeAlbumOfflineState();
}

class _MakeAlbumOfflineState extends State<MakeAlbumOffline> {
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    downloadManager.checkOffline(album: widget.album).then((v) {
      setState(() {
        _offline = v;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
        icon: _offline
            ? Icon(
                AlchemyIcons.download_fill,
                size: 25,
                color: Theme.of(context).primaryColor,
              )
            : Icon(
                AlchemyIcons.download,
                size: 25,
              ),
        onPressed: () async {
          //Add to offline
          if (_offline) {
            downloadManager.removeOfflineAlbum(widget.album?.id ?? '');
            Fluttertoast.showToast(
                msg: 'Removed album from offline!'.i18n,
                gravity: ToastGravity.BOTTOM,
                toastLength: Toast.LENGTH_SHORT);
            setState(() {
              _offline = false;
            });
          } else {
            await deezerAPI.addFavoriteAlbum(widget.album?.id ?? '');
            await downloadManager.addOfflineAlbum(widget.album ?? Album(),
                private: true);
            MenuSheet().showDownloadStartedToast();
            setState(() {
              _offline = true;
            });
            return;
          }
        });
  }
}

class ArtistDetails extends StatefulWidget {
  final Artist artist;
  const ArtistDetails(this.artist, {super.key});

  @override
  _ArtistDetailsState createState() => _ArtistDetailsState();
}

class _ArtistDetailsState extends State<ArtistDetails> {
  Artist artist = Artist();
  bool _isLoading = true;
  bool _error = false;
  final ScrollController _scrollController = ScrollController();
  Color _accentColor = Colors.transparent;

  void _setColor() async {
    ColorScheme palette = await ColorScheme.fromImageProvider(
      provider: CachedNetworkImageProvider(
          artist.image?.fullUrl ?? artist.image?.thumbUrl ?? ''),
    );

    if (mounted) {
      setState(() {
        _accentColor = palette.secondary;
      });
    }
  }

  Future _loadArtist() async {
    //Load artist from api if no albums
    if (artist.albums.isEmpty) {
      try {
        Artist a = await deezerAPI.artist(artist.id ?? '');
        if (artist.isIn(await deezerAPI.getArtists())) {
          a.library = true;
        }
        setState(() => artist = a);
      } catch (e) {
        setState(() => _error = true);
      }
    }
    setState(() => _isLoading = false);

    //load complete artist
    try {
      Artist a = await deezerAPI.completeArtist(artist.id ?? '');
      a.library = artist.library;
      if (mounted) setState(() => artist = a);
    } catch (e) {
      Logger.root.info(
          'Something went wrong loading full details for artist ${artist.id}');
    }

    _setColor();
  }

  @override
  void initState() {
    artist = widget.artist;
    _setColor();
    _loadArtist();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: _error
          ? const ErrorScreen()
          : _isLoading
              ? SplashScreen()
              : OrientationBuilder(
                  builder: (context, orientation) {
                    //Responsive
                    ScreenUtil.init(context, minTextAdapt: true);
                    //Landscape
                    if (orientation == Orientation.landscape) {
                      // ignore: prefer_const_constructors
                      return SafeArea(
                        left: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height,
                              width: MediaQuery.of(context).size.width * 0.4,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 4.0),
                                      child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: IconButton(
                                              onPressed: () async {
                                                await Navigator.of(context)
                                                    .maybePop();
                                              },
                                              icon: Icon(Icons.arrow_back)),
                                          title: Text(
                                            artist.name ?? '',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18.0),
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(AlchemyIcons.more_vert),
                                            onPressed: () {
                                              MenuSheet m = MenuSheet();
                                              m.defaultArtistMenu(artist,
                                                  context: context);
                                            },
                                          ))),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.height *
                                        0.5,
                                    height: MediaQuery.of(context).size.height *
                                        0.5,
                                    child: CachedImage(
                                      url: artist.image?.full ?? '',
                                      width:
                                          MediaQuery.of(context).size.height *
                                              0.5,
                                      fullThumb: true,
                                      circular: true,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0, horizontal: 6.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      mainAxisSize: MainAxisSize.max,
                                      children: <Widget>[
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(right: 8.0),
                                              child: IconButton(
                                                icon: (artist.library ?? false)
                                                    ? Icon(
                                                        AlchemyIcons.heart_fill,
                                                        size: 25,
                                                        color: Theme.of(context)
                                                            .primaryColor,
                                                        semanticLabel:
                                                            'Unlove'.i18n,
                                                      )
                                                    : Icon(
                                                        AlchemyIcons.heart,
                                                        size: 25,
                                                        semanticLabel:
                                                            'Love'.i18n,
                                                      ),
                                                onPressed: () async {
                                                  //Add to library
                                                  if (!(artist.library ??
                                                      false)) {
                                                    bool result =
                                                        await deezerAPI
                                                            .addFavoriteArtist(
                                                                artist.id ??
                                                                    '');
                                                    if (result) {
                                                      Fluttertoast.showToast(
                                                          msg:
                                                              'Artist added to library'
                                                                  .i18n,
                                                          toastLength: Toast
                                                              .LENGTH_SHORT,
                                                          gravity: ToastGravity
                                                              .BOTTOM);
                                                      setState(() => artist
                                                          .library = true);
                                                      return;
                                                    } else {
                                                      Fluttertoast.showToast(
                                                          msg:
                                                              'Failed to add artist to library'
                                                                  .i18n,
                                                          toastLength: Toast
                                                              .LENGTH_SHORT,
                                                          gravity: ToastGravity
                                                              .BOTTOM);
                                                    }
                                                  }
                                                  //Remove
                                                  bool result = await deezerAPI
                                                      .removeArtist(
                                                          artist.id ?? '');
                                                  if (result) {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Artist removed from library!'
                                                                .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                    setState(() =>
                                                        artist.library = false);
                                                  } else {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Failed to remove artist from library'
                                                                .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                  }
                                                },
                                              ),
                                            ),
                                            IconButton(
                                                onPressed: () => {
                                                      SharePlus.instance.share(
                                                        ShareParams(
                                                          text:
                                                              'https://deezer.com/artist/' +
                                                                  (artist.id ??
                                                                      ''),
                                                        ),
                                                      )
                                                    },
                                                icon: Icon(
                                                  AlchemyIcons.share_android,
                                                  size: 20.0,
                                                )),
                                          ],
                                        ),
                                        if ((artist.radio ?? false))
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Container(
                                                margin:
                                                    EdgeInsets.only(right: 6.0),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .primaryColor,
                                                  border: Border.all(
                                                      color: Theme.of(context)
                                                          .scaffoldBackgroundColor
                                                          .withAlpha(0)),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          100),
                                                ),
                                                child: IconButton(
                                                    onPressed: () async {
                                                      List<Track> tracks =
                                                          await deezerAPI
                                                              .smartRadio(
                                                                  artist.id ??
                                                                      '');
                                                      if (tracks.isNotEmpty) {
                                                        GetIt.I<AudioPlayerHandler>()
                                                            .playFromTrackList(
                                                                tracks,
                                                                tracks[0].id!,
                                                                QueueSource(
                                                                    id:
                                                                        artist
                                                                            .id,
                                                                    text: 'Radio'
                                                                            .i18n +
                                                                        ' ${artist.name}',
                                                                    source:
                                                                        'smartradio'));
                                                      }
                                                    },
                                                    icon: Icon(
                                                      AlchemyIcons.shuffle,
                                                      size: 18,
                                                    )),
                                              )
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'Top Tracks'.i18n,
                                      textAlign: TextAlign.left,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20.0),
                                    ),
                                  ),
                                  ...List.generate(3, (i) {
                                    if (artist.topTracks.length <= i) {
                                      return const SizedBox(
                                        height: 0,
                                        width: 0,
                                      );
                                    }
                                    Track t = artist.topTracks[i];
                                    return TrackTile(
                                      t,
                                      onTap: () {
                                        GetIt.I<AudioPlayerHandler>()
                                            .playFromTopTracks(artist.topTracks,
                                                t.id!, artist);
                                      },
                                      onHold: () {
                                        MenuSheet mi = MenuSheet();
                                        mi.defaultTrackMenu(t,
                                            context: context);
                                      },
                                    );
                                  }),
                                  ViewAllButton(
                                    padding: EdgeInsets.only(top: 4),
                                    onTap: () async {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => TrackListScreen(
                                            artist.topTracks,
                                            queueSource: QueueSource(
                                                id: artist.id,
                                                text: 'Top'.i18n +
                                                    '${artist.name}',
                                                source: 'topTracks'),
                                            load: deezerAPI.artistTopTracks(
                                                artist.id ?? ''),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  //Highlight
                                  if (artist.highlight != null)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            artist.highlight?.title ?? '',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            textAlign: TextAlign.left,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20.0),
                                          ),
                                        ),
                                        if ((artist.highlight?.type ?? '') ==
                                            ArtistHighlightType.ALBUM)
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 16.0),
                                            child: Container(
                                              clipBehavior: Clip.hardEdge,
                                              decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: Theme.of(context)
                                                          .scaffoldBackgroundColor
                                                          .withAlpha(0)),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  color: Colors.white
                                                      .withAlpha(30)),
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                radius: 10.0,
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              AlbumDetails(
                                                                  artist
                                                                      .highlight
                                                                      ?.data)));
                                                },
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    CachedImage(
                                                      url: artist
                                                              .highlight
                                                              ?.data
                                                              ?.image
                                                              ?.full ??
                                                          '',
                                                      height: 150,
                                                      width: 150,
                                                      fullThumb: true,
                                                      rounded: true,
                                                    ),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.all(12.0),
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            artist.highlight
                                                                ?.data?.title,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            maxLines: 1,
                                                            style: TextStyle(
                                                                fontSize: 16.0),
                                                          ),
                                                          Padding(
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(
                                                                          4.0)),
                                                          Text(
                                                              'By ' +
                                                                  artist
                                                                      .highlight
                                                                      ?.data
                                                                      ?.artistString,
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      12.0,
                                                                  color: Settings
                                                                      .secondaryText)),
                                                          Padding(
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(
                                                                          4.0)),
                                                          Text(
                                                              'Released on ' +
                                                                  artist
                                                                      .highlight
                                                                      ?.data
                                                                      ?.releaseDate,
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      12.0,
                                                                  color: Settings
                                                                      .secondaryText))
                                                        ],
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  //Albums
                                  Container(
                                    height: 8,
                                  ),
                                  Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0, vertical: 4.0),
                                        child: InkWell(
                                            onTap: () {
                                              Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          DiscographyScreen(
                                                            artist: artist,
                                                          )));
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 12.0,
                                                      horizontal: 4.0),
                                                  child: Text(
                                                    'Discography'.i18n,
                                                    textAlign: TextAlign.left,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 20.0),
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.chevron_right,
                                                )
                                              ],
                                            )),
                                      ),
                                      Container(height: 4.0),
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                            12.0, 8.0, 1.0, 8.0),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          physics: ClampingScrollPhysics(),
                                          child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: List.generate(
                                                  artist.albums.length > 10
                                                      ? 10
                                                      : artist.albums.length,
                                                  (i) {
                                                //Top albums
                                                Album a = artist.albums[i];
                                                return LargeAlbumTile(a);
                                              })),
                                        ),
                                      ),
                                      // Biography
                                      if (artist.biography?.summary != null)
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Biography'.i18n,
                                                textAlign: TextAlign.left,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20.0),
                                              ),
                                              Container(height: 8.0),
                                              Text(
                                                artist.biography!.summary!,
                                                maxLines:
                                                    5, // Adjust as needed for landscape
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color:
                                                        Settings.secondaryText),
                                              ),
                                              ViewAllButton(
                                                padding:
                                                    EdgeInsets.only(top: 4),
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          BiographyScreen(
                                                        biography:
                                                            artist.biography!,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      // Similar Artists
                                      if (artist.relatedArtists?.isNotEmpty ??
                                          false)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child: Text(
                                                'Similar Artists'.i18n,
                                                textAlign: TextAlign.left,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20.0),
                                              ),
                                            ),
                                            Container(height: 4.0),
                                            Padding(
                                              padding: EdgeInsets.fromLTRB(
                                                  12.0,
                                                  0.0,
                                                  1.0,
                                                  8.0), // Reduced top padding
                                              child: SizedBox(
                                                height:
                                                    180, // Adjust height as needed
                                                child: ListView.builder(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  physics:
                                                      ClampingScrollPhysics(),
                                                  itemCount: (artist
                                                                  .relatedArtists
                                                                  ?.length ??
                                                              0) >
                                                          5
                                                      ? 5
                                                      : (artist.relatedArtists
                                                              ?.length ??
                                                          0), // Show fewer items or adjust based on screen width
                                                  itemBuilder: (context, i) {
                                                    Artist? a = artist
                                                        .relatedArtists?[i];
                                                    return Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 4.0),
                                                      child: ArtistTile(
                                                          a ?? Artist(),
                                                          size:
                                                              120), // Adjust size
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      // Playlists
                                      if (artist.playlists?.isNotEmpty ?? false)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child: Text(
                                                'Playlists'.i18n,
                                                textAlign: TextAlign.left,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20.0),
                                              ),
                                            ),
                                            Container(height: 4.0),
                                            Padding(
                                              padding: EdgeInsets.fromLTRB(
                                                  12.0, 0.0, 1.0, 8.0),
                                              child: SizedBox(
                                                height:
                                                    205, // Adjust height as needed
                                                child: ListView.builder(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  physics:
                                                      ClampingScrollPhysics(),
                                                  itemCount: (artist.playlists
                                                                  ?.length ??
                                                              0) >
                                                          5
                                                      ? 5
                                                      : (artist.playlists
                                                              ?.length ??
                                                          0),
                                                  itemBuilder: (context, i) {
                                                    Playlist? p =
                                                        artist.playlists?[i];
                                                    return Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 4.0),
                                                      child: LargePlaylistTile(
                                                          p ?? Playlist()),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      // Featured In
                                      if (artist.featuredIn?.isNotEmpty ??
                                          false)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child: Text(
                                                'Featured in'.i18n,
                                                textAlign: TextAlign.left,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20.0),
                                              ),
                                            ),
                                            Container(height: 4.0),
                                            Padding(
                                              padding: EdgeInsets.fromLTRB(
                                                  12.0, 0.0, 1.0, 8.0),
                                              child: SizedBox(
                                                height:
                                                    230, // Adjust height as needed
                                                child: ListView.builder(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  physics:
                                                      ClampingScrollPhysics(),
                                                  itemCount: (artist.featuredIn
                                                                  ?.length ??
                                                              0) >
                                                          5
                                                      ? 5
                                                      : (artist.featuredIn
                                                              ?.length ??
                                                          0),
                                                  itemBuilder: (context, i) {
                                                    Album? a =
                                                        artist.featuredIn?[i];
                                                    return Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 4.0),
                                                      child: LargeAlbumTile(
                                                          a ?? Album()),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ListenableBuilder(
                                          listenable: playerBarState,
                                          builder: (BuildContext context,
                                              Widget? child) {
                                            return AnimatedPadding(
                                              duration:
                                                  Duration(milliseconds: 200),
                                              padding: EdgeInsets.only(
                                                  bottom: playerBarState.state
                                                      ? 80
                                                      : 5),
                                            );
                                          }),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    }
                    //Portrait
                    // ignore: prefer_const_constructors
                    return CustomScrollView(
                      controller: _scrollController,
                      slivers: <Widget>[
                        DetailedAppBar(
                          title: artist.name ?? '',
                          moreFunction: () {
                            MenuSheet m = MenuSheet();
                            m.defaultArtistMenu(artist, context: context);
                          },
                          expandedHeight: MediaQuery.of(context).size.width,
                          backgroundColor: _accentColor,
                          screens: [
                            Stack(
                              children: [
                                CachedImage(
                                  url: artist.image?.full ?? '',
                                  height: MediaQuery.of(context).size.width,
                                  width: MediaQuery.of(context).size.width,
                                  fullThumb: true,
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                              colors: [
                                                Theme.of(context)
                                                    .scaffoldBackgroundColor
                                                    .withAlpha(150),
                                                Theme.of(context)
                                                    .scaffoldBackgroundColor
                                                    .withAlpha(0)
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              stops: [0.0, 0.7])),
                                      child: SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width,
                                        height:
                                            MediaQuery.of(context).size.width /
                                                5,
                                      ),
                                    ),
                                    Container(
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                                colors: [
                                                  Theme.of(context)
                                                      .scaffoldBackgroundColor
                                                      .withAlpha(150),
                                                  Theme.of(context)
                                                      .scaffoldBackgroundColor
                                                      .withAlpha(0)
                                                ],
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                stops: [0.0, 0.7])),
                                        child: SizedBox(
                                          width:
                                              MediaQuery.of(context).size.width,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .width /
                                              5,
                                        )),
                                  ],
                                ),
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: ListTile(
                                    title: Text(
                                      artist.name ?? '',
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 40.0,
                                          fontWeight: FontWeight.w900),
                                    ),
                                    subtitle: Text(artist.fansString + ' fans',
                                        textAlign: TextAlign.left,
                                        style: TextStyle(fontSize: 14.0)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          scrollController: _scrollController,
                        ),
                        SliverToBoxAdapter(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_accentColor, Colors.transparent],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 14.0,
                                      bottom: 4.0,
                                      right: 6.0,
                                      left: 6.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.max,
                                    children: <Widget>[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: <Widget>[
                                          Padding(
                                            padding:
                                                EdgeInsets.only(right: 8.0),
                                            child: IconButton(
                                              icon: (artist.library ?? false)
                                                  ? Icon(
                                                      AlchemyIcons.heart_fill,
                                                      size: 25,
                                                      color: Theme.of(context)
                                                          .primaryColor,
                                                      semanticLabel:
                                                          'Unlove'.i18n,
                                                    )
                                                  : Icon(
                                                      AlchemyIcons.heart,
                                                      size: 25,
                                                      semanticLabel:
                                                          'Love'.i18n,
                                                    ),
                                              onPressed: () async {
                                                //Add to library
                                                if (!(artist.library ??
                                                    false)) {
                                                  bool result = await deezerAPI
                                                      .addFavoriteArtist(
                                                          artist.id ?? '');
                                                  if (result) {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Artist added to library'
                                                                .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                    setState(() =>
                                                        artist.library = true);
                                                    return;
                                                  } else {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Failed to add artist to library'
                                                                .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                  }
                                                }
                                                //Remove
                                                bool result = await deezerAPI
                                                    .removeArtist(
                                                        artist.id ?? '');
                                                if (result) {
                                                  Fluttertoast.showToast(
                                                      msg:
                                                          'Artist removed from library!'
                                                              .i18n,
                                                      toastLength:
                                                          Toast.LENGTH_SHORT,
                                                      gravity:
                                                          ToastGravity.BOTTOM);
                                                  setState(() =>
                                                      artist.library = false);
                                                } else {
                                                  Fluttertoast.showToast(
                                                      msg:
                                                          'Failed to remove artist from library'
                                                              .i18n,
                                                      toastLength:
                                                          Toast.LENGTH_SHORT,
                                                      gravity:
                                                          ToastGravity.BOTTOM);
                                                }
                                              },
                                            ),
                                          ),
                                          IconButton(
                                              onPressed: () => {
                                                    SharePlus.instance.share(
                                                      ShareParams(
                                                        text:
                                                            'https://deezer.com/artist/' +
                                                                (artist.id ??
                                                                    ''),
                                                      ),
                                                    )
                                                  },
                                              icon: Icon(
                                                AlchemyIcons.share_android,
                                                size: 20.0,
                                              )),
                                        ],
                                      ),
                                      if ((artist.radio ?? false))
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Container(
                                              margin:
                                                  EdgeInsets.only(right: 6.0),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                border: Border.all(
                                                    color: Theme.of(context)
                                                        .scaffoldBackgroundColor
                                                        .withAlpha(0)),
                                                borderRadius:
                                                    BorderRadius.circular(100),
                                              ),
                                              child: IconButton(
                                                  onPressed: () async {
                                                    List<Track> tracks =
                                                        await deezerAPI
                                                            .smartRadio(
                                                                artist.id ??
                                                                    '');
                                                    if (tracks.isNotEmpty) {
                                                      GetIt.I<AudioPlayerHandler>()
                                                          .playFromTrackList(
                                                              tracks,
                                                              tracks[0].id!,
                                                              QueueSource(
                                                                  id: artist.id,
                                                                  text: 'Radio'
                                                                          .i18n +
                                                                      ' ${artist.name}',
                                                                  source:
                                                                      'smartradio'));
                                                    }
                                                  },
                                                  icon: Icon(
                                                    AlchemyIcons.shuffle,
                                                    size: 18,
                                                  )),
                                            )
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        //Top tracks
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Top Tracks'.i18n,
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 20.0),
                            ),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              Track t = artist.topTracks[index];
                              return TrackTile(
                                t,
                                onTap: () {
                                  GetIt.I<AudioPlayerHandler>()
                                      .playFromTopTracks(
                                          artist.topTracks, t.id!, artist);
                                },
                                onHold: () {
                                  MenuSheet mi = MenuSheet();
                                  mi.defaultTrackMenu(t, context: context);
                                },
                              );
                            },
                            childCount: artist.topTracks.length > 3
                                ? 3
                                : artist.topTracks.length,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: ViewAllButton(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            onTap: () async {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => TrackListScreen(
                                    artist.topTracks,
                                    queueSource: QueueSource(
                                        id: artist.id,
                                        text: 'Top'.i18n + '${artist.name}',
                                        source: 'topTracks'),
                                    load: deezerAPI
                                        .artistTopTracks(artist.id ?? ''),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        //Highlight
                        if (artist.highlight != null)
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    artist.highlight?.title ?? '',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20.0),
                                  ),
                                ),
                                if ((artist.highlight?.type ?? '') ==
                                    ArtistHighlightType.ALBUM)
                                  Container(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Container(
                                      clipBehavior: Clip.hardEdge,
                                      decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Theme.of(context)
                                                  .scaffoldBackgroundColor
                                                  .withAlpha(0)),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          color: Colors.white.withAlpha(30)),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        radius: 10.0,
                                        onTap: () {
                                          Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      AlbumDetails(artist
                                                          .highlight?.data)));
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CachedImage(
                                              url: artist.highlight?.data?.image
                                                      ?.full ??
                                                  '',
                                              height: 150,
                                              width: 150,
                                              fullThumb: true,
                                              rounded: true,
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: EdgeInsets.all(12.0),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      artist.highlight?.data
                                                          ?.title,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                      style: TextStyle(
                                                          fontSize: 16.0),
                                                    ),
                                                    Padding(
                                                        padding: EdgeInsets.all(
                                                            4.0)),
                                                    Text(
                                                        'By ' +
                                                            artist
                                                                .highlight
                                                                ?.data
                                                                ?.artistString,
                                                        style: TextStyle(
                                                            fontSize: 12.0,
                                                            color: Settings
                                                                .secondaryText)),
                                                    Padding(
                                                        padding: EdgeInsets.all(
                                                            4.0)),
                                                    Text(
                                                        'Released on ' +
                                                            artist
                                                                .highlight
                                                                ?.data
                                                                ?.releaseDate,
                                                        style: TextStyle(
                                                            fontSize: 12.0,
                                                            color: Settings
                                                                .secondaryText))
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                Container(
                                  height: 16,
                                )
                              ],
                            ),
                          ),
                        //Discography
                        if (artist.albums.isNotEmpty)
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 300,
                              child: Column(children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: 4.0),
                                  child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    DiscographyScreen(
                                                      artist: artist,
                                                    )));
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 12.0,
                                                horizontal: 4.0),
                                            child: Text(
                                              'Discography'.i18n,
                                              textAlign: TextAlign.left,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20.0),
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                          )
                                        ],
                                      )),
                                ),
                                Container(height: 4.0),
                                Padding(
                                    padding: EdgeInsets.fromLTRB(
                                        12.0, 8.0, 1.0, 8.0),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      physics: ClampingScrollPhysics(),
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: List.generate(
                                              artist.albums.length > 10
                                                  ? 10
                                                  : artist.albums.length, (i) {
                                            //Top albums
                                            Album a = artist.albums[i];
                                            return LargeAlbumTile(a);
                                          })),
                                    ))
                              ]),
                            ),
                          ),

                        if (artist.biography?.summary != null)
                          SliverToBoxAdapter(
                            child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 8.0,
                                    ),
                                    Text(
                                      'Biography',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      textAlign: TextAlign.left,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20.0),
                                    ),
                                    Container(
                                      height: 16,
                                    ),
                                    Text(
                                      artist.biography?.summary ?? '',
                                      maxLines: 10,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: Settings.secondaryText),
                                    ),
                                    ViewAllButton(
                                      padding: EdgeInsets.only(top: 4),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                BiographyScreen(
                                              biography: artist.biography!,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                )),
                          ),

                        //Similar artists
                        if (artist.relatedArtists?.isNotEmpty ?? false)
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 260,
                              child: Column(children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: 4.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 12.0, horizontal: 4.0),
                                        child: Text(
                                          'Similar Artists'.i18n,
                                          textAlign: TextAlign.left,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20.0),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                Container(height: 4.0),
                                Padding(
                                    padding: EdgeInsets.fromLTRB(
                                        12.0, 8.0, 1.0, 8.0),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      physics: ClampingScrollPhysics(),
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: List.generate(
                                              (artist.relatedArtists?.length ??
                                                          0) >
                                                      10
                                                  ? 10
                                                  : (artist.relatedArtists
                                                          ?.length ??
                                                      0), (i) {
                                            //Top albums
                                            Artist? a =
                                                artist.relatedArtists?[i];
                                            return ArtistTile(a ?? Artist());
                                          })),
                                    ))
                              ]),
                            ),
                          ),

                        //Playlists
                        if (artist.playlists?.isNotEmpty ?? false)
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 275,
                              child: Column(children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: 4.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 12.0, horizontal: 4.0),
                                        child: Text(
                                          'Playlists'.i18n,
                                          textAlign: TextAlign.left,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20.0),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                Container(height: 4.0),
                                Padding(
                                    padding: EdgeInsets.fromLTRB(
                                        12.0, 8.0, 1.0, 8.0),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      physics: ClampingScrollPhysics(),
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: List.generate(
                                              (artist.playlists?.length ?? 0) >
                                                      10
                                                  ? 10
                                                  : (artist.playlists?.length ??
                                                      0), (i) {
                                            //Top albums
                                            Playlist? a = artist.playlists?[i];
                                            return LargePlaylistTile(
                                                a ?? Playlist());
                                          })),
                                    ))
                              ]),
                            ),
                          ),

                        //Featured in
                        if (artist.featuredIn?.isNotEmpty ?? false)
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 320,
                              child: Column(children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: 4.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 12.0, horizontal: 4.0),
                                        child: Text(
                                          'Featured in'.i18n,
                                          textAlign: TextAlign.left,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20.0),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                Container(height: 4.0),
                                Padding(
                                    padding: EdgeInsets.fromLTRB(
                                        12.0, 8.0, 1.0, 8.0),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      physics: ClampingScrollPhysics(),
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: List.generate(
                                              (artist.featuredIn?.length ?? 0) >
                                                      10
                                                  ? 10
                                                  : (artist
                                                          .featuredIn?.length ??
                                                      0), (i) {
                                            //Top albums
                                            Album? a = artist.featuredIn?[i];
                                            return LargeAlbumTile(a ?? Album());
                                          })),
                                    ))
                              ]),
                            ),
                          ),

                        SliverToBoxAdapter(
                          child: ListenableBuilder(
                              listenable: playerBarState,
                              builder: (BuildContext context, Widget? child) {
                                return AnimatedPadding(
                                  duration: Duration(milliseconds: 200),
                                  padding: EdgeInsets.only(
                                      bottom: playerBarState.state ? 80 : 5),
                                );
                              }),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

class BiographyScreen extends StatelessWidget {
  final Bio biography;

  const BiographyScreen({required this.biography, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Biography'),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(biography.full ?? biography.summary ?? ''),
              Container(height: 16),
              if (biography.source != null)
                Text(
                  '© ' + (biography.source ?? ''),
                  style: TextStyle(color: Settings.secondaryText),
                )
            ],
          ),
        ),
      ),
    );
  }
}

class DiscographyScreen extends StatefulWidget {
  final Artist artist;
  const DiscographyScreen({required this.artist, super.key});

  @override
  _DiscographyScreenState createState() => _DiscographyScreenState();
}

class _DiscographyScreenState extends State<DiscographyScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _keyboardListenerFocusNode = FocusNode();
  final FocusNode _textFieldFocusNode = FocusNode();
  bool _hasFocus = false;
  late Artist artist;
  bool _isLoading = false;
  bool _error = false;
  final ScrollController _scrollController = ScrollController();
  String _filter = '';
  bool _albums = false;
  bool _eps = false;
  bool _singles = false;

  Future _load() async {
    setState(() => _isLoading = true);

    //Fetch data
    List<Album> data;
    try {
      data = await deezerAPI.discographyPage(artist.id ?? '',
          start: artist.albums.length, nb: 100);
    } catch (e) {
      setState(() {
        _error = true;
        _isLoading = false;
      });
      return;
    }

    //Save
    if (mounted) {
      setState(() {
        artist.albums.addAll(data);
        _isLoading = false;
      });
    }
  }

  Widget get _isLoadingWidget {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [CircularProgressIndicator()],
        ),
      );
    }
    //Error
    if (_error) return const ErrorScreen();
    //Success
    return const SizedBox(
      width: 0,
      height: 0,
    );
  }

  @override
  void initState() {
    artist = widget.artist;
    artist.albums = [];

    _load();

    //Lazy loading scroll
    _scrollController.addListener(() {
      double off = _scrollController.position.maxScrollExtent * 0.90;
      if (_scrollController.position.pixels > off) {
        _load();
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (BuildContext context) {
      List<Album> albums = artist.albums
          .where((a) => a.type == AlbumType.ALBUM)
          .where((a) =>
              a.title?.toLowerCase().contains(_filter.toLowerCase()) ?? false)
          .toList();
      List<Widget> albumsSection = [];
      if (albums.isNotEmpty) {
        albumsSection = [
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
                vertical: 20.0),
            child: Text(
              'Albums'.i18n,
              textAlign: TextAlign.left,
              style:
                  const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
            ),
          ),
          ...List.generate(albums.length, (i) {
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
              ),
              child: AlbumTile(
                albums[i],
                padding: EdgeInsets.zero,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => AlbumDetails(albums[i]))),
                onHold: () {
                  MenuSheet m = MenuSheet();
                  m.defaultAlbumMenu(albums[i], context: context);
                },
              ),
            );
          }),
        ];
      }

      List<Album> singles = artist.albums
          .where((a) => a.type == AlbumType.SINGLE)
          .where((a) =>
              a.title?.toLowerCase().contains(_filter.toLowerCase()) ?? false)
          .toList();
      List<Widget> singlesSection = [];
      if (singles.isNotEmpty) {
        singlesSection = [
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
                vertical: 20.0),
            child: Text(
              'Singles'.i18n,
              textAlign: TextAlign.left,
              style:
                  const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
            ),
          ),
          ...List.generate(singles.length, (i) {
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
              ),
              child: AlbumTile(
                singles[i],
                padding: EdgeInsets.zero,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => AlbumDetails(singles[i]))),
                onHold: () {
                  MenuSheet m = MenuSheet();
                  m.defaultAlbumMenu(singles[i], context: context);
                },
              ),
            );
          }),
        ];
      }

      List<Album> eps = artist.albums
          .where((a) => a.type == AlbumType.EP)
          .where((a) =>
              a.title?.toLowerCase().contains(_filter.toLowerCase()) ?? false)
          .toList();
      List<Widget> epsSection = [];
      if (eps.isNotEmpty) {
        epsSection = [
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
                vertical: 20.0),
            child: Text(
              'EPs'.i18n,
              textAlign: TextAlign.left,
              style:
                  const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
            ),
          ),
          ...List.generate(eps.length, (i) {
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
              ),
              child: AlbumTile(
                eps[i],
                padding: EdgeInsets.zero,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => AlbumDetails(eps[i]))),
                onHold: () {
                  MenuSheet m = MenuSheet();
                  m.defaultAlbumMenu(eps[i], context: context);
                },
              ),
            );
          }),
        ];
      }

      return Scaffold(
        appBar: FreezerAppBar(
          'Discography'.i18n,
        ),
        body: ListView(
          controller: _scrollController,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
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
                            });
                          },
                          focusNode: _textFieldFocusNode,
                          child: TextField(
                            onChanged: (String s) {
                              if (mounted) {
                                setState(
                                  () {
                                    _filter = s;
                                  },
                                );
                              }
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
                                size: 16,
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
                                    size: 12),
                                splashRadius:
                                    16, // Adjust splash radius as needed
                                onPressed: () {
                                  _controller.clear(); // Clear text field
                                  _textFieldFocusNode
                                      .unfocus(); // Release focus
                                  setState(() {
                                    _hasFocus = false;
                                    _filter = '';
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
                                  vertical: 14.0,
                                  horizontal: 16.0), // Added contentPadding
                            ),
                            controller: _controller,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (String s) {
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
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05,
                  vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  if (albumsSection.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _albums
                                ? Theme.of(context).primaryColor
                                : settings.theme == Themes.Light
                                    ? Colors.black.withAlpha(100)
                                    : Colors.white.withAlpha(100),
                            width: 1.5),
                        borderRadius: BorderRadius.circular(20),
                        color: settings.theme == Themes.Light
                            ? Colors.black.withAlpha(30)
                            : Colors.white.withAlpha(30),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: InkWell(
                        onTap: () {
                          if (mounted) {
                            setState(() {
                              _albums = !_albums;
                            });
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 4,
                          children: [
                            if (_albums)
                              Icon(
                                AlchemyIcons.cross,
                                size: 10,
                              ),
                            Text(
                              'Albums',
                              style: TextStyle(fontSize: 12),
                            )
                          ],
                        ),
                      ),
                    ),
                  if (singlesSection.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _singles
                                ? Theme.of(context).primaryColor
                                : settings.theme == Themes.Light
                                    ? Colors.black.withAlpha(100)
                                    : Colors.white.withAlpha(100),
                            width: 1.5),
                        borderRadius: BorderRadius.circular(20),
                        color: settings.theme == Themes.Light
                            ? Colors.black.withAlpha(30)
                            : Colors.white.withAlpha(30),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: InkWell(
                        onTap: () {
                          if (mounted) {
                            setState(() {
                              _singles = !_singles;
                            });
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 4,
                          children: [
                            if (_singles)
                              Icon(
                                AlchemyIcons.cross,
                                size: 10,
                              ),
                            Text(
                              'Singles',
                              style: TextStyle(fontSize: 12),
                            )
                          ],
                        ),
                      ),
                    ),
                  if (epsSection.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _eps
                                ? Theme.of(context).primaryColor
                                : settings.theme == Themes.Light
                                    ? Colors.black.withAlpha(100)
                                    : Colors.white.withAlpha(100),
                            width: 1.5),
                        borderRadius: BorderRadius.circular(20),
                        color: settings.theme == Themes.Light
                            ? Colors.black.withAlpha(30)
                            : Colors.white.withAlpha(30),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: InkWell(
                        onTap: () {
                          if (mounted) {
                            setState(() {
                              _eps = !_eps;
                            });
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 4,
                          children: [
                            if (_eps)
                              Icon(
                                AlchemyIcons.cross,
                                size: 10,
                              ),
                            Text(
                              'EPs',
                              style: TextStyle(fontSize: 12),
                            )
                          ],
                        ),
                      ),
                    )
                ],
              ),
            ),
            //Albums
            if (!_albums && !_eps && !_singles) ...[
              ...albumsSection,
              ...singlesSection,
              ...epsSection,
            ],
            if (_albums) ...albumsSection,
            if (_singles) ...singlesSection,
            if (_eps) ...epsSection,
            _isLoadingWidget,
          ],
        ),
      );
    });
  }
}

class PlaylistDetails extends StatefulWidget {
  final Playlist playlist;
  const PlaylistDetails(this.playlist, {super.key});

  @override
  _PlaylistDetailsState createState() => _PlaylistDetailsState();
}

class _PlaylistDetailsState extends State<PlaylistDetails> {
  late Playlist playlist;
  bool _isLoading = false;
  bool _isLoadingTracks = false;
  bool _error = false;
  final ScrollController _scrollController = ScrollController();
  final PageController _playlistController = PageController();
  int _currentPage = 0;
  Color _accentColor = Colors.transparent;

  //Load cached playlist sorting
  void _restoreSort() async {
    //Find index
    int? index = Sorting.index(SortSourceTypes.PLAYLIST, id: playlist.id);
    if (index == null) return;

    //Preload tracks
    if ((playlist.tracks?.length ?? 0) < (playlist.trackCount ?? 0)) {
      playlist = await deezerAPI.fullPlaylist(playlist.id ?? '');
    }
  }

  Future _isLibrary() async {
    if (playlist.isIn(await downloadManager.getOfflinePlaylists())) {
      setState(() {
        playlist.library = true;
      });
      return;
    }
    if (playlist.isIn(await deezerAPI.getPlaylists())) {
      setState(() {
        playlist.library = true;
      });
      return;
    }
  }

  void _loadTracks() async {
    // Got all tracks, return
    if (_isLoadingTracks ||
        (playlist.tracks?.length ?? 0) >=
            (playlist.trackCount ?? playlist.tracks?.length ?? 0)) {
      return;
    }

    if (mounted) setState(() => _isLoadingTracks = true);
    int pos = playlist.tracks?.length ?? 0;
    //Get another page of tracks
    List<Track> tracks;
    try {
      tracks =
          await deezerAPI.playlistTracksPage(playlist.id ?? '', pos, nb: 25);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _isLoadingTracks = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        playlist.tracks?.addAll(tracks);
        _isLoadingTracks = false;
      });
    }
  }

  Future _load() async {
    if (mounted) setState(() => _isLoading = true);

    // Initial load if no tracks
    if (playlist.tracks?.isEmpty ?? true) {
      //If playlist is offline
      Playlist? offlinePlaylist = await downloadManager
          .getOfflinePlaylist(playlist.id ?? '')
          .catchError((e) {
        if (mounted) {
          setState(() {
            _error = true;
          });
        }
        return null;
      });
      if ((offlinePlaylist?.tracks?.isNotEmpty ?? false) && mounted) {
        setState(() {
          playlist = offlinePlaylist ?? Playlist();
          _isLoading = false;
        });

        //Try to update offline playlist
        Playlist? fullPlaylist =
            await deezerAPI.fullPlaylist(playlist.id ?? '');
        if (fullPlaylist.tracks != offlinePlaylist?.tracks &&
            (fullPlaylist.tracks?.isNotEmpty ?? false)) {
          setState(() {
            playlist = fullPlaylist;
          });
          await downloadManager.updateOfflinePlaylist(playlist);
        }
      } else {
        //If playlist is not offline
        Playlist? onlinePlaylist =
            await deezerAPI.playlist(playlist.id ?? '', nb: 25).catchError((e) {
          if (mounted) {
            setState(
              () {
                _error = true;
              },
            );
          }

          return Playlist();
        });
        if (mounted) {
          setState(() {
            playlist = onlinePlaylist;
            _isLoading = false;
          });
        }
      }
    }

    _setColor();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setColor() async {
    ColorScheme palette = await ColorScheme.fromImageProvider(
      provider: CachedNetworkImageProvider(
          playlist.image?.fullUrl ?? playlist.image?.thumbUrl ?? ''),
    );

    if (mounted) {
      setState(() {
        _accentColor = palette.secondary;
      });
    }
  }

  @override
  void initState() {
    playlist = widget.playlist;
    _setColor();
    _load();
    _isLibrary();
    _restoreSort();
    super.initState();

    _scrollController.addListener(() {
      double off = _scrollController.position.maxScrollExtent * 0.90;
      if (_scrollController.position.pixels > off &&
          widget.playlist.tracks?.length != widget.playlist.trackCount) {
        _loadTracks();
      }
    });

    _playlistController.addListener(() {
      setState(() {
        _currentPage = _playlistController.page?.round() ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _playlistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _error
          ? const ErrorScreen()
          : _isLoading
              ? SplashScreen()
              : OrientationBuilder(builder: (context, orientation) {
                  //Responsive
                  ScreenUtil.init(context, minTextAdapt: true);
                  //Landscape
                  if (orientation == Orientation.landscape) {
                    // ignore: prefer_const_constructors
                    return SafeArea(
                      left: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height,
                            width: MediaQuery.of(context).size.width * 0.4,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 4.0),
                                    child: ListTile(
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        horizontalTitleGap: 8.0,
                                        leading: IconButton(
                                            onPressed: () async {
                                              await Navigator.of(context)
                                                  .maybePop();
                                            },
                                            icon: Icon(Icons.arrow_back)),
                                        title: Text(
                                          playlist.title ?? '',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18.0),
                                        ),
                                        subtitle: Text(
                                          playlist.user?.name ?? '',
                                          style: TextStyle(
                                              fontSize: 14.0,
                                              color: Settings.secondaryText),
                                        ),
                                        trailing: IconButton(
                                          icon: Icon(AlchemyIcons.more_vert),
                                          onPressed: () {
                                            MenuSheet m = MenuSheet();
                                            m.defaultPlaylistMenu(playlist,
                                                context: context, onUpdate: () {
                                              if (mounted) {
                                                setState(() {
                                                  playlist.tracks = [];
                                                });
                                                _load();
                                              }
                                            });
                                          },
                                        ))),
                                SizedBox(
                                    width: MediaQuery.of(context).size.height *
                                        0.5,
                                    height: MediaQuery.of(context).size.height *
                                        0.5,
                                    child: Stack(
                                      children: [
                                        PageView(
                                          controller: _playlistController,
                                          onPageChanged: (index) {
                                            setState(() {
                                              _currentPage = index;
                                            });
                                          },
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Stack(
                                                  children: [
                                                    CachedImage(
                                                      url: playlist
                                                              .image?.full ??
                                                          '',
                                                      width:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .height *
                                                              0.5,
                                                      fullThumb: true,
                                                      rounded: true,
                                                    ),
                                                    Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Container(
                                                            decoration: BoxDecoration(
                                                                gradient: LinearGradient(
                                                                    colors: [
                                                                      Theme.of(
                                                                              context)
                                                                          .scaffoldBackgroundColor
                                                                          .withAlpha(
                                                                              150),
                                                                      Colors
                                                                          .transparent
                                                                    ],
                                                                    begin: Alignment
                                                                        .bottomCenter,
                                                                    end: Alignment
                                                                        .topCenter,
                                                                    stops: [
                                                                      0.0,
                                                                      0.7
                                                                    ])),
                                                            child: SizedBox(
                                                              width: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .height *
                                                                  0.5,
                                                              height: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .height *
                                                                  0.1,
                                                            )),
                                                      ],
                                                    ),
                                                  ],
                                                )
                                              ],
                                            ),
                                            Container(
                                                clipBehavior: Clip.hardEdge,
                                                decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .scaffoldBackgroundColor,
                                                    border: Border.all(
                                                        color: Theme.of(context)
                                                            .scaffoldBackgroundColor
                                                            .withAlpha(0)),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5)),
                                                child: ListView(
                                                  children: [
                                                    ListTile(
                                                      dense: true,
                                                      visualDensity:
                                                          VisualDensity(
                                                              horizontal: 0.0,
                                                              vertical: -4),
                                                      minVerticalPadding: 0,
                                                      title: Text(
                                                        'Tracks'.i18n,
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16),
                                                      ),
                                                      subtitle: Text(
                                                          (playlist.tracks
                                                                  ?.length)
                                                              .toString(),
                                                          style: TextStyle(
                                                              color: Settings
                                                                  .secondaryText,
                                                              fontSize: 12)),
                                                    ),
                                                    ListTile(
                                                      dense: true,
                                                      visualDensity:
                                                          VisualDensity(
                                                              horizontal: 0.0,
                                                              vertical: -4),
                                                      minVerticalPadding: 0,
                                                      title: Text(
                                                        'Duration'.i18n,
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16),
                                                      ),
                                                      subtitle: Text(
                                                          playlist
                                                              .durationString,
                                                          style: TextStyle(
                                                              color: Settings
                                                                  .secondaryText,
                                                              fontSize: 12)),
                                                    ),
                                                    ListTile(
                                                      dense: true,
                                                      visualDensity:
                                                          VisualDensity(
                                                              horizontal: 0.0,
                                                              vertical: -4),
                                                      minVerticalPadding: 0,
                                                      title: Text(
                                                        'Fans'.i18n,
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16),
                                                      ),
                                                      subtitle: Text(
                                                          (playlist.fans ?? 0)
                                                              .toString(),
                                                          style: TextStyle(
                                                              color: Settings
                                                                  .secondaryText,
                                                              fontSize: 12)),
                                                    ),
                                                  ],
                                                ))
                                          ],
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(top: 8.0),
                                              child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: List.generate(
                                                      2,
                                                      (i) => Container(
                                                            margin: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        2.0,
                                                                    vertical:
                                                                        8.0),
                                                            width: 12.0,
                                                            height: 4.0,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors
                                                                  .white
                                                                  .withAlpha(
                                                                      _currentPage ==
                                                                              i
                                                                          ? 255
                                                                          : 150),
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .transparent),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          100),
                                                            ),
                                                          ))),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4.0, horizontal: 6.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.max,
                                    children: <Widget>[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          if (playlist.user?.id !=
                                              deezerAPI.userId)
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(right: 8.0),
                                              child: IconButton(
                                                icon: (playlist.library ??
                                                        false)
                                                    ? Icon(
                                                        AlchemyIcons.heart_fill,
                                                        size: 25,
                                                        color: Theme.of(context)
                                                            .primaryColor,
                                                        semanticLabel:
                                                            'Unlove'.i18n,
                                                      )
                                                    : Icon(
                                                        AlchemyIcons.heart,
                                                        size: 25,
                                                        semanticLabel:
                                                            'Love'.i18n,
                                                      ),
                                                onPressed: () async {
                                                  //Add to library
                                                  if (!(playlist.library ??
                                                      false)) {
                                                    bool result =
                                                        await deezerAPI
                                                            .addPlaylist(
                                                                playlist.id ??
                                                                    '');
                                                    if (result) {
                                                      Fluttertoast.showToast(
                                                          msg:
                                                              'Added to library'
                                                                  .i18n,
                                                          toastLength: Toast
                                                              .LENGTH_SHORT,
                                                          gravity: ToastGravity
                                                              .BOTTOM);
                                                      setState(() => playlist
                                                          .library = true);
                                                      return;
                                                    } else {
                                                      Fluttertoast.showToast(
                                                          msg:
                                                              'Failed to add playlist to library'
                                                                  .i18n,
                                                          toastLength: Toast
                                                              .LENGTH_SHORT,
                                                          gravity: ToastGravity
                                                              .BOTTOM);
                                                    }
                                                  }
                                                  //Remove
                                                  bool result = await deezerAPI
                                                      .removePlaylist(
                                                          playlist.id ?? '');
                                                  if (result) {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Playlist removed from library!'
                                                                .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                    setState(() => playlist
                                                        .library = false);
                                                  } else {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Failed to remove playlist from library!'
                                                                .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                  }
                                                },
                                              ),
                                            ),
                                          IconButton(
                                              onPressed: () => {
                                                    SharePlus.instance.share(
                                                      ShareParams(
                                                        text:
                                                            'https://deezer.com/playlist/' +
                                                                (playlist.id ??
                                                                    ''),
                                                      ),
                                                    )
                                                  },
                                              icon: Icon(
                                                AlchemyIcons.share_android,
                                                size: 20.0,
                                              )),
                                          Padding(
                                            padding: EdgeInsets.only(left: 8.0),
                                            child:
                                                MakePlaylistOffline(playlist),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Container(
                                            margin: EdgeInsets.only(right: 6.0),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              border: Border.all(
                                                  color: Theme.of(context)
                                                      .scaffoldBackgroundColor
                                                      .withAlpha(0)),
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                            ),
                                            child: IconButton(
                                                onPressed: () async {
                                                  Navigator.of(context,
                                                          rootNavigator: true)
                                                      .push(MaterialPageRoute(
                                                          builder: (context) =>
                                                              BlindTestChoiceScreen(
                                                                  playlist)));
                                                },
                                                icon: Icon(
                                                  AlchemyIcons.music_quiz,
                                                  size: 20,
                                                )),
                                          ),
                                          Container(
                                            margin: EdgeInsets.only(right: 6.0),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              border: Border.all(
                                                  color: Theme.of(context)
                                                      .scaffoldBackgroundColor
                                                      .withAlpha(0)),
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                            ),
                                            child: IconButton(
                                                onPressed: () async {
                                                  List<Track> tracklist =
                                                      List.from(
                                                          playlist.tracks ??
                                                              []);
                                                  if (playlist.trackCount !=
                                                      tracklist.length) {
                                                    playlist = await deezerAPI
                                                        .fullPlaylist(
                                                            playlist.id ?? '');
                                                    tracklist = List.from(
                                                        playlist.tracks ?? []);
                                                  }
                                                  tracklist.shuffle();
                                                  GetIt.I<AudioPlayerHandler>()
                                                      .playFromTrackList(
                                                          tracklist,
                                                          tracklist[0].id ?? '',
                                                          QueueSource(
                                                              id: playlist.id,
                                                              source: playlist
                                                                  .title,
                                                              text: playlist
                                                                      .title ??
                                                                  'Playlist' +
                                                                      ' shuffle'
                                                                          .i18n));
                                                  tracklist.shuffle();
                                                  GetIt.I<AudioPlayerHandler>()
                                                      .playFromTrackList(
                                                          tracklist,
                                                          tracklist[0].id ?? '',
                                                          QueueSource(
                                                              id: playlist.id,
                                                              source: playlist
                                                                  .title,
                                                              text: playlist
                                                                      .title ??
                                                                  'Playlist' +
                                                                      ' shuffle'
                                                                          .i18n));
                                                },
                                                icon: Icon(
                                                  AlchemyIcons.shuffle,
                                                  size: 18,
                                                )),
                                          )
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              controller: _scrollController,
                              children: [
                                ...List.generate((playlist.tracks?.length ?? 0),
                                    (i) {
                                  Track t = (playlist.tracks ?? [])[i];
                                  return TrackTile(t, onTap: () async {
                                    (playlist.trackCount !=
                                                playlist.tracks?.length &&
                                            await isConnected())
                                        ? deezerAPI
                                            .fullPlaylist(playlist.id ?? '')
                                            .then((Playlist p) => {
                                                  GetIt.I<AudioPlayerHandler>()
                                                      .playFromPlaylist(
                                                          Playlist(
                                                              title: p.title,
                                                              id: p.id,
                                                              tracks: p.tracks),
                                                          t.id ?? '')
                                                })
                                        : GetIt.I<AudioPlayerHandler>()
                                            .playFromPlaylist(
                                                Playlist(
                                                    title: playlist.title,
                                                    id: playlist.id,
                                                    tracks: playlist.tracks),
                                                t.id ?? '');
                                  }, onHold: () async {
                                    MenuSheet m = MenuSheet();
                                    m.defaultTrackMenu(t,
                                        context: context,
                                        options: [
                                          (playlist.user?.id ==
                                                      deezerAPI.userId &&
                                                  playlist.id !=
                                                      cache.favoritesPlaylistId)
                                              ? m.removeFromPlaylist(
                                                  t, playlist, context, () {
                                                  setState(() {
                                                    playlist.tracks = playlist
                                                        .tracks
                                                        ?.where((track) =>
                                                            track.id != t.id)
                                                        .toList();
                                                  });
                                                })
                                              : const SizedBox(
                                                  width: 0,
                                                  height: 0,
                                                )
                                        ],
                                        onRemove: playlist.id ==
                                                cache.favoritesPlaylistId
                                            ? () {
                                                setState(() {
                                                  playlist.tracks = playlist
                                                      .tracks
                                                      ?.where((track) =>
                                                          track.id != t.id)
                                                      .toList();
                                                });
                                              }
                                            : null);
                                  });
                                }),
                                if (_isLoadingTracks)
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        CircularProgressIndicator(
                                          color: Theme.of(context).primaryColor,
                                        )
                                      ],
                                    ),
                                  ),
                                if (_error &&
                                    playlist.tracks?.length !=
                                        playlist.trackCount)
                                  const ErrorScreen(),
                                ListenableBuilder(
                                    listenable: playerBarState,
                                    builder:
                                        (BuildContext context, Widget? child) {
                                      return AnimatedPadding(
                                        duration: Duration(milliseconds: 200),
                                        padding: EdgeInsets.only(
                                            bottom:
                                                playerBarState.state ? 80 : 0),
                                      );
                                    }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  //Portrait
                  // ignore: prefer_const_constructors
                  return CustomScrollView(
                    controller: _scrollController,
                    slivers: <Widget>[
                      DetailedAppBar(
                        title: playlist.title ?? '',
                        subtitle: playlist.user?.name ?? '',
                        moreFunction: () {
                          MenuSheet m = MenuSheet();
                          m.defaultPlaylistMenu(playlist, context: context,
                              onUpdate: () {
                            if (mounted) {
                              setState(() {
                                playlist.tracks = [];
                              });
                              _load();
                            }
                          });
                        },
                        expandedHeight: MediaQuery.of(context).size.width,
                        backgroundColor: _accentColor,
                        screens: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Stack(
                                children: [
                                  CachedImage(
                                    url: playlist.image?.full ?? '',
                                    height: MediaQuery.of(context).size.width,
                                    width: MediaQuery.of(context).size.width,
                                    fullThumb: true,
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                                colors: [
                                                  Theme.of(context)
                                                      .scaffoldBackgroundColor
                                                      .withAlpha(150),
                                                  Theme.of(context)
                                                      .scaffoldBackgroundColor
                                                      .withAlpha(0)
                                                ],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                stops: [0.0, 0.7])),
                                        child: SizedBox(
                                          width:
                                              MediaQuery.of(context).size.width,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .width /
                                              5,
                                        ),
                                      ),
                                      Container(
                                          decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                  colors: [
                                                    Theme.of(context)
                                                        .scaffoldBackgroundColor
                                                        .withAlpha(150),
                                                    Theme.of(context)
                                                        .scaffoldBackgroundColor
                                                        .withAlpha(0)
                                                  ],
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  stops: [0.0, 0.7])),
                                          child: SizedBox(
                                            width: MediaQuery.of(context)
                                                .size
                                                .width,
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .width /
                                                5,
                                          )),
                                    ],
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                                colors: [
                                                  Theme.of(context)
                                                      .scaffoldBackgroundColor
                                                      .withAlpha(150),
                                                  Theme.of(context)
                                                      .scaffoldBackgroundColor
                                                      .withAlpha(0)
                                                ],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                stops: [0.0, 0.7])),
                                        child: SizedBox(
                                          width:
                                              MediaQuery.of(context).size.width,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .width /
                                              6,
                                        ),
                                      ),
                                      Container(
                                          decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                  colors: [
                                                    Theme.of(context)
                                                        .scaffoldBackgroundColor
                                                        .withAlpha(150),
                                                    Theme.of(context)
                                                        .scaffoldBackgroundColor
                                                        .withAlpha(0)
                                                  ],
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  stops: [0.0, 0.7])),
                                          child: SizedBox(
                                            width: MediaQuery.of(context)
                                                .size
                                                .width,
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .width /
                                                6,
                                          )),
                                    ],
                                  ),
                                ],
                              )
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(color: _accentColor),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  minVerticalPadding: 1,
                                  leading: Icon(
                                    AlchemyIcons.album,
                                    size: 25,
                                  ),
                                  title: Text(
                                    'Tracks'.i18n,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  subtitle: Text(
                                      (playlist.trackCount ??
                                              playlist.tracks?.length ??
                                              0)
                                          .toString(),
                                      style: TextStyle(
                                          color: Settings.secondaryText,
                                          fontSize: 12)),
                                ),
                                if (playlist.duration != Duration.zero)
                                  ListTile(
                                    minVerticalPadding: 1,
                                    leading: Icon(
                                      AlchemyIcons.clock,
                                      size: 25,
                                    ),
                                    title: Text(
                                      'Duration'.i18n,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    subtitle: Text(playlist.durationString,
                                        style: TextStyle(
                                            color: Settings.secondaryText,
                                            fontSize: 12)),
                                  ),
                                ListTile(
                                  minVerticalPadding: 1,
                                  leading: Icon(
                                    AlchemyIcons.heart,
                                    size: 25,
                                  ),
                                  title: Text(
                                    'Fans'.i18n,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  subtitle: Text(
                                      (NumberFormat.decimalPattern()
                                              .format(playlist.fans ?? 0))
                                          .toString(),
                                      style: TextStyle(
                                          color: Settings.secondaryText,
                                          fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          if ((playlist.description?.length ?? 0) > 0)
                            Container(
                                decoration: BoxDecoration(color: _accentColor),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [Text(playlist.description ?? '')],
                                ))
                        ],
                        scrollController: _scrollController,
                      ),
                      SliverToBoxAdapter(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_accentColor, Colors.transparent],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.all(4.0),
                                child: ListTile(
                                  title: Text(
                                    playlist.title ?? '',
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.start,
                                    maxLines: 1,
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 40.0,
                                        fontWeight: FontWeight.w900),
                                  ),
                                  subtitle: Text(
                                    playlist.user?.name ?? '',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                        color: Settings.secondaryText,
                                        fontSize: 14.0),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12.0, horizontal: 6.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  mainAxisSize: MainAxisSize.max,
                                  children: <Widget>[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        if (playlist.user?.id !=
                                            deezerAPI.userId)
                                          Padding(
                                            padding:
                                                EdgeInsets.only(right: 8.0),
                                            child: IconButton(
                                              icon: (playlist.library ?? false)
                                                  ? Icon(
                                                      AlchemyIcons.heart_fill,
                                                      size: 25,
                                                      color: Theme.of(context)
                                                          .primaryColor,
                                                      semanticLabel:
                                                          'Unlove'.i18n,
                                                    )
                                                  : Icon(
                                                      AlchemyIcons.heart,
                                                      size: 25,
                                                      semanticLabel:
                                                          'Love'.i18n,
                                                    ),
                                              onPressed: () async {
                                                //Add to library
                                                if (!(playlist.library ??
                                                    false)) {
                                                  bool result = await deezerAPI
                                                      .addPlaylist(
                                                          playlist.id ?? '');
                                                  if (result) {
                                                    Fluttertoast.showToast(
                                                        msg: 'Added to library'
                                                            .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                    setState(() => playlist
                                                        .library = true);
                                                    return;
                                                  } else {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Failed to add playlist to library'
                                                                .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                  }
                                                }
                                                //Remove
                                                bool result = await deezerAPI
                                                    .removePlaylist(
                                                        playlist.id ?? '');
                                                if (result) {
                                                  Fluttertoast.showToast(
                                                      msg:
                                                          'Playlist removed from library!'
                                                              .i18n,
                                                      toastLength:
                                                          Toast.LENGTH_SHORT,
                                                      gravity:
                                                          ToastGravity.BOTTOM);
                                                  setState(() =>
                                                      playlist.library = false);
                                                } else {
                                                  Fluttertoast.showToast(
                                                      msg:
                                                          'Failed to remove playlist from library!'
                                                              .i18n,
                                                      toastLength:
                                                          Toast.LENGTH_SHORT,
                                                      gravity:
                                                          ToastGravity.BOTTOM);
                                                }
                                              },
                                            ),
                                          ),
                                        IconButton(
                                            onPressed: () => {
                                                  SharePlus.instance.share(
                                                    ShareParams(
                                                      text:
                                                          'https://deezer.com/playlist/' +
                                                              (playlist.id ??
                                                                  ''),
                                                    ),
                                                  )
                                                },
                                            icon: Icon(
                                              AlchemyIcons.share_android,
                                              size: 20.0,
                                            )),
                                        Padding(
                                          padding: EdgeInsets.only(left: 8.0),
                                          child: MakePlaylistOffline(playlist),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          margin: EdgeInsets.only(right: 6.0),
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context).primaryColor,
                                            border: Border.all(
                                                color: Theme.of(context)
                                                    .scaffoldBackgroundColor
                                                    .withAlpha(0)),
                                            borderRadius:
                                                BorderRadius.circular(100),
                                          ),
                                          child: IconButton(
                                              onPressed: () async {
                                                Navigator.of(context,
                                                        rootNavigator: true)
                                                    .push(MaterialPageRoute(
                                                        builder: (context) =>
                                                            BlindTestChoiceScreen(
                                                                playlist)));
                                              },
                                              icon: Icon(
                                                AlchemyIcons.music_quiz,
                                                size: 20,
                                              )),
                                        ),
                                        Container(
                                          margin: EdgeInsets.only(right: 6.0),
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context).primaryColor,
                                            border: Border.all(
                                                color: Theme.of(context)
                                                    .scaffoldBackgroundColor
                                                    .withAlpha(0)),
                                            borderRadius:
                                                BorderRadius.circular(100),
                                          ),
                                          child: IconButton(
                                              onPressed: () async {
                                                List<Track> tracklist =
                                                    List.from(
                                                        playlist.tracks ?? []);
                                                if (playlist.trackCount !=
                                                        tracklist.length &&
                                                    await isConnected()) {
                                                  playlist = await deezerAPI
                                                      .fullPlaylist(
                                                          playlist.id ?? '');
                                                  tracklist = List.from(
                                                      playlist.tracks ?? []);
                                                }
                                                tracklist.shuffle();
                                                GetIt.I<AudioPlayerHandler>()
                                                    .playFromTrackList(
                                                        tracklist,
                                                        tracklist[0].id ?? '',
                                                        QueueSource(
                                                            id: playlist.id,
                                                            source:
                                                                playlist.title,
                                                            text: playlist
                                                                    .title ??
                                                                'Playlist' +
                                                                    ' shuffle'
                                                                        .i18n));
                                                tracklist.shuffle();
                                                GetIt.I<AudioPlayerHandler>()
                                                    .playFromTrackList(
                                                        tracklist,
                                                        tracklist[0].id ?? '',
                                                        QueueSource(
                                                            id: playlist.id,
                                                            source:
                                                                playlist.title,
                                                            text: playlist
                                                                    .title ??
                                                                'Playlist' +
                                                                    ' shuffle'
                                                                        .i18n));
                                              },
                                              icon: Icon(
                                                AlchemyIcons.shuffle,
                                                size: 18,
                                              )),
                                        )
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Container(
                          height: 4.0,
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                          Track t = playlist.tracks?[index] ?? Track();
                          return TrackTile(
                            t,
                            onTap: () async {
                              (playlist.trackCount != playlist.tracks?.length &&
                                      await isConnected())
                                  ? deezerAPI
                                      .fullPlaylist(playlist.id ?? '')
                                      .then((Playlist p) => {
                                            GetIt.I<AudioPlayerHandler>()
                                                .playFromPlaylist(
                                                    Playlist(
                                                        title: p.title,
                                                        id: p.id,
                                                        tracks: p.tracks),
                                                    t.id ?? '')
                                          })
                                  : GetIt.I<AudioPlayerHandler>()
                                      .playFromPlaylist(
                                          Playlist(
                                              title: playlist.title,
                                              id: playlist.id,
                                              tracks: playlist.tracks),
                                          t.id ?? '');
                            },
                            onHold: () {
                              MenuSheet m = MenuSheet();
                              m.defaultTrackMenu(t,
                                  context: context,
                                  options: [
                                    (playlist.user?.id == deezerAPI.userId &&
                                            playlist.id !=
                                                cache.favoritesPlaylistId)
                                        ? m.removeFromPlaylist(
                                            t, playlist, context, () {
                                            setState(() {
                                              playlist.tracks = playlist.tracks
                                                  ?.where((track) =>
                                                      track.id != t.id)
                                                  .toList();
                                            });
                                          })
                                        : const SizedBox(
                                            width: 0,
                                            height: 0,
                                          )
                                  ],
                                  onRemove: playlist.id ==
                                          cache.favoritesPlaylistId
                                      ? () {
                                          setState(() {
                                            playlist.tracks = playlist.tracks
                                                ?.where(
                                                    (track) => track.id != t.id)
                                                .toList();
                                          });
                                        }
                                      : null);
                            },
                          );
                        }, childCount: playlist.tracks?.length ?? 0),
                      ),
                      if (_isLoadingTracks)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor,
                                )
                              ],
                            ),
                          ),
                        ),
                      if (_error &&
                          playlist.tracks?.length != playlist.trackCount)
                        const ErrorScreen(),
                      SliverToBoxAdapter(
                        child: ListenableBuilder(
                            listenable: playerBarState,
                            builder: (BuildContext context, Widget? child) {
                              return AnimatedPadding(
                                duration: Duration(milliseconds: 200),
                                padding: EdgeInsets.only(
                                    bottom: playerBarState.state ? 80 : 0),
                              );
                            }),
                      ),
                    ],
                  );
                }),
    );
  }
}

class MakePlaylistOffline extends StatefulWidget {
  final Playlist playlist;
  const MakePlaylistOffline(this.playlist, {super.key});

  @override
  _MakePlaylistOfflineState createState() => _MakePlaylistOfflineState();
}

class _MakePlaylistOfflineState extends State<MakePlaylistOffline> {
  late Playlist playlist;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    downloadManager.checkOffline(playlist: widget.playlist).then((v) {
      setState(() {
        _offline = v;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: () async {
          if (!_offline) {
            //Add to offline
            if (widget.playlist.user?.id != deezerAPI.userId) {
              await deezerAPI.addPlaylist(widget.playlist.id!);
            }
            downloadManager.addOfflinePlaylist(widget.playlist, private: true);
            MenuSheet().showDownloadStartedToast();
            setState(() {
              _offline = true;
            });
            return;
          }
          downloadManager.removeOfflinePlaylist(widget.playlist.id!);
          Fluttertoast.showToast(
              msg: 'Playlist removed from offline!'.i18n,
              gravity: ToastGravity.BOTTOM,
              toastLength: Toast.LENGTH_SHORT);
          setState(() {
            _offline = false;
          });
        },
        icon: _offline
            ? Icon(
                AlchemyIcons.download_fill,
                size: 25,
                color: Theme.of(context).primaryColor,
              )
            : Icon(
                AlchemyIcons.download,
                size: 25,
              ));
  }
}

class ShowScreen extends StatefulWidget {
  final Show show;
  const ShowScreen(this.show, {super.key});

  @override
  _ShowScreenState createState() => _ShowScreenState();
}

class _ShowScreenState extends State<ShowScreen> {
  Show show = Show();
  bool _isLoading = true;
  bool _error = false;
  List<ShowEpisode> _episodes = [];
  bool _isLoadingTracks = false;
  final ScrollController _scrollController = ScrollController();
  Color _accentColor = Colors.transparent;

  void _setColor() async {
    ColorScheme palette = await ColorScheme.fromImageProvider(
      provider: CachedNetworkImageProvider(
          show.image?.fullUrl ?? show.image?.thumbUrl ?? ''),
    );

    if (mounted) {
      setState(() {
        _accentColor = palette.secondary;
      });
    }
  }

  Future _load() async {
    setState(() => _isLoading = true);

    // Initial load if no tracks
    if (_episodes.isEmpty) {
      Show? s;
      if (await isConnected()) {
        try {
          s = await deezerAPI.show(show.id!);
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _error = true;
              Logger.root.info('err: $e');
            });
          }
          return;
        }
      } else {
        try {
          s = await downloadManager.getOfflineShow(show.id!);
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _error = true;
              Logger.root.info('err: $e');
            });
          }
          return;
        }
      }
      setState(() {
        _episodes = s?.episodes ?? [];
        _isLoading = false;
      });
    }

    setState(() {
      _isLoading = false;
    });

    _setColor();
  }

  @override
  void initState() {
    show = widget.show;
    _setColor();
    _load();
    _isLibrary();
    _isSubscribed();
    super.initState();

    _scrollController.addListener(() {
      double off = _scrollController.position.maxScrollExtent * 0.90;
      if (_scrollController.position.pixels > off) {
        _loadTracks();
      }
    });
  }

  Future _isSubscribed() async {
    if ((await deezerAPI.getShowNotificationIds()).contains(show.id) &&
        mounted) {
      setState(() {
        show.isSubscribed = true;
      });
    } else {
      if (mounted) {
        setState(() {
          show.isSubscribed = false;
        });
      }
    }
  }

  Future _isLibrary() async {
    if (show.isIn(await downloadManager.getOfflineShows())) {
      setState(() {
        show.isLibrary = true;
      });
      return;
    }
    if (show.isIn(await deezerAPI.getUserShows())) {
      setState(() {
        show.isLibrary = true;
      });
      return;
    }
  }

  void _loadTracks() async {
    // Got all tracks, return
    if (_isLoadingTracks || _episodes.isEmpty || !(await isConnected())) {
      return;
    }

    setState(() => _isLoadingTracks = true);
    int pos = _episodes.length;
    //Get another page of tracks
    Show tmpShow;
    try {
      tmpShow = await deezerAPI.show(show.id ?? '', page: (pos / 1000).round());
    } catch (e) {
      if (mounted) {
        setState(() {
          Logger.root.info(e);
          _error = true;
          _isLoadingTracks = false;
        });
      }
      return;
    }

    setState(() {
      _episodes.addAll(tmpShow.episodes ?? []);
      _isLoadingTracks = false;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: _error
            ? const ErrorScreen()
            : _isLoading
                ? SplashScreen()
                : OrientationBuilder(builder: (context, orientation) {
                    //Responsive
                    ScreenUtil.init(context, minTextAdapt: true);
                    //Landscape
                    if (orientation == Orientation.landscape) {
                      // ignore: prefer_const_constructors
                      return SafeArea(
                        left: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height,
                              width: MediaQuery.of(context).size.width * 0.4,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 4.0),
                                      child: ListTile(
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          horizontalTitleGap: 8.0,
                                          leading: IconButton(
                                              onPressed: () async {
                                                await Navigator.of(context)
                                                    .maybePop();
                                              },
                                              icon: Icon(Icons.arrow_back)),
                                          title: Text(
                                            show.name ?? '',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18.0),
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(AlchemyIcons.more_vert),
                                            onPressed: () {
                                              MenuSheet m = MenuSheet();
                                              m.defaultShowEpisodeMenu(
                                                  show, _episodes[0],
                                                  context: context);
                                            },
                                          ))),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.height *
                                        0.5,
                                    height: MediaQuery.of(context).size.height *
                                        0.5,
                                    child: CachedImage(
                                      url: show.image?.full ?? '',
                                      width:
                                          MediaQuery.of(context).size.height *
                                              0.5,
                                      fullThumb: true,
                                      rounded: true,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0, horizontal: 6.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      mainAxisSize: MainAxisSize.max,
                                      children: <Widget>[
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(right: 8.0),
                                              child: IconButton(
                                                icon: (show.isLibrary ?? false)
                                                    ? Icon(
                                                        AlchemyIcons.heart_fill,
                                                        size: 25,
                                                        color: Theme.of(context)
                                                            .primaryColor,
                                                        semanticLabel:
                                                            'Unlove'.i18n,
                                                      )
                                                    : Icon(
                                                        AlchemyIcons.heart,
                                                        size: 25,
                                                        semanticLabel:
                                                            'Love'.i18n,
                                                      ),
                                                onPressed: () async {
                                                  //Add to library
                                                  if (!(show.isLibrary ??
                                                      false)) {
                                                    bool result =
                                                        await deezerAPI.addShow(
                                                            show.id ?? '');

                                                    if (result) {
                                                      Fluttertoast.showToast(
                                                          msg:
                                                              'Added to library'
                                                                  .i18n,
                                                          toastLength: Toast
                                                              .LENGTH_SHORT,
                                                          gravity: ToastGravity
                                                              .BOTTOM);
                                                      setState(() => show
                                                          .isLibrary = true);
                                                    } else {
                                                      Fluttertoast.showToast(
                                                          msg:
                                                              'Failed to add show to library'
                                                                  .i18n,
                                                          toastLength: Toast
                                                              .LENGTH_SHORT,
                                                          gravity: ToastGravity
                                                              .BOTTOM);
                                                    }
                                                    return;
                                                  }
                                                  //Remove
                                                  bool result = await deezerAPI
                                                      .removeShow(
                                                          show.id ?? '');
                                                  if (result) {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Show removed from library!'
                                                                .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                    setState(() =>
                                                        show.isLibrary = false);
                                                  } else {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Failed to remove show from library'
                                                                .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                  }
                                                },
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () async {
                                                if (show.isSubscribed ??
                                                    false) {
                                                  bool result = await deezerAPI
                                                      .unSubscribeShow(
                                                          show.id ?? '');
                                                  if (result) {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Unsubscribed from show!'
                                                                .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                    setState(() => show
                                                        .isSubscribed = false);
                                                  } else {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Failed to unsubscribe from show!'
                                                                .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                  }
                                                } else {
                                                  bool result = await deezerAPI
                                                      .subscribeShow(
                                                          show.id ?? '');
                                                  if (result) {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Subscribed to show!'
                                                                .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                    setState(() => show
                                                        .isSubscribed = true);
                                                  } else {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Failed to subscribe to show!'
                                                                .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                  }
                                                }
                                              },
                                              icon: Icon(
                                                (show.isSubscribed ?? false)
                                                    ? AlchemyIcons.bell_fill
                                                    : AlchemyIcons.bell,
                                                size: 20.0,
                                                color:
                                                    (show.isSubscribed ?? false)
                                                        ? Colors.green
                                                        : null,
                                              ),
                                            ),
                                            IconButton(
                                                onPressed: () => {
                                                      SharePlus.instance.share(
                                                        ShareParams(
                                                          text:
                                                              'https://deezer.com/show/' +
                                                                  (show.id ??
                                                                      ''),
                                                        ),
                                                      )
                                                    },
                                                icon: Icon(
                                                  AlchemyIcons.share_android,
                                                  size: 20.0,
                                                )),
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(left: 8.0),
                                              child: Container(),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Container(
                                              margin:
                                                  EdgeInsets.only(right: 6.0),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                border: Border.all(
                                                    color: Theme.of(context)
                                                        .scaffoldBackgroundColor
                                                        .withAlpha(0)),
                                                borderRadius:
                                                    BorderRadius.circular(100),
                                              ),
                                              child: IconButton(
                                                  onPressed: () async {
                                                    List<Track> tracklist =
                                                        List.from(_episodes);

                                                    tracklist.shuffle();
                                                    GetIt.I<AudioPlayerHandler>()
                                                        .playFromTrackList(
                                                            tracklist,
                                                            tracklist[0].id ??
                                                                '',
                                                            QueueSource(
                                                                id: show.id,
                                                                source:
                                                                    show.name,
                                                                text: show
                                                                        .name ??
                                                                    'Show' +
                                                                        ' shuffle'
                                                                            .i18n));
                                                    tracklist.shuffle();
                                                    GetIt.I<AudioPlayerHandler>()
                                                        .playFromTrackList(
                                                            tracklist,
                                                            tracklist[0].id ??
                                                                '',
                                                            QueueSource(
                                                                id: show.id,
                                                                source:
                                                                    show.name,
                                                                text: show
                                                                        .name ??
                                                                    'Show' +
                                                                        ' shuffle'
                                                                            .i18n));
                                                  },
                                                  icon: Icon(
                                                    AlchemyIcons.shuffle,
                                                    size: 18,
                                                  )),
                                            )
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                controller: _scrollController,
                                children: [
                                  ...List.generate(_episodes.length, (i) {
                                    ShowEpisode e = _episodes[i];
                                    return ShowEpisodeTile(e,
                                        onTap: () async {}, onHold: () async {
                                      MenuSheet m = MenuSheet();
                                      m.defaultShowEpisodeMenu(
                                        show, e,
                                        context: context,
                                        options: [
                                          //remove
                                        ],
                                        //onRemove: show.id ==
                                      );
                                    });
                                  }),
                                  if (_isLoadingTracks)
                                    Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          CircularProgressIndicator(
                                            color:
                                                Theme.of(context).primaryColor,
                                          )
                                        ],
                                      ),
                                    ),
                                  ListenableBuilder(
                                    listenable: playerBarState,
                                    builder:
                                        (BuildContext context, Widget? child) {
                                      return AnimatedPadding(
                                        duration: Duration(milliseconds: 200),
                                        padding: EdgeInsets.only(
                                            bottom:
                                                playerBarState.state ? 80 : 0),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    //Portrait
                    // ignore: prefer_const_constructors

                    return CustomScrollView(
                      controller: _scrollController,
                      slivers: <Widget>[
                        DetailedAppBar(
                          title: show.name ?? '',
                          subtitle: show.description ?? '',
                          backgroundColor: _accentColor,
                          moreFunction: () => showModalBottomSheet(
                            backgroundColor: Colors.transparent,
                            useRootNavigator: true,
                            isScrollControlled: true,
                            context: context,
                            builder: (BuildContext context) {
                              return DraggableScrollableSheet(
                                initialChildSize: 0.3,
                                minChildSize: 0.3,
                                maxChildSize: 0.9,
                                expand: false,
                                builder: (context,
                                    ScrollController scrollController) {
                                  return Container(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 12.0),
                                    clipBehavior: Clip.hardEdge,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .scaffoldBackgroundColor,
                                      border:
                                          Border.all(color: Colors.transparent),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(18),
                                        topRight: Radius.circular(18),
                                      ),
                                    ),
                                    // Use ListView instead of SingleChildScrollView for scrollable content
                                    child: ListView(
                                      controller:
                                          scrollController, // Important: Connect ScrollController
                                      children: [
                                        ListTile(
                                          leading: Container(
                                            clipBehavior: Clip.hardEdge,
                                            decoration: ShapeDecoration(
                                              shape: SmoothRectangleBorder(
                                                borderRadius:
                                                    SmoothBorderRadius(
                                                  cornerRadius: 10,
                                                  cornerSmoothing: 0.6,
                                                ),
                                              ),
                                            ),
                                            child: CachedImage(
                                              url: show.image?.full ?? '',
                                            ),
                                          ),
                                          title: Text(show.name ?? ''),
                                          subtitle: Text(show.authors ?? ''),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: Text(show.description ?? ''),
                                        ),
                                        ListTile(
                                          title: Text('Share'.i18n),
                                          leading: const Icon(Icons.share),
                                          onTap: () async {
                                            SharePlus.instance.share(
                                              ShareParams(
                                                text:
                                                    'https://deezer.com/show/' +
                                                        (show.id ?? ''),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          screens: [
                            Stack(
                              children: [
                                CachedImage(
                                  url: show.image?.full ?? '',
                                  height: MediaQuery.of(context).size.width,
                                  width: MediaQuery.of(context).size.width,
                                  fullThumb: true,
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                              colors: [
                                                Theme.of(context)
                                                    .scaffoldBackgroundColor
                                                    .withAlpha(150),
                                                Theme.of(context)
                                                    .scaffoldBackgroundColor
                                                    .withAlpha(0)
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              stops: [0.0, 0.7])),
                                      child: SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width,
                                        height:
                                            MediaQuery.of(context).size.width /
                                                5,
                                      ),
                                    ),
                                    Container(
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                                colors: [
                                                  Theme.of(context)
                                                      .scaffoldBackgroundColor
                                                      .withAlpha(150),
                                                  Theme.of(context)
                                                      .scaffoldBackgroundColor
                                                      .withAlpha(0)
                                                ],
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                stops: [0.0, 0.7])),
                                        child: SizedBox(
                                          width:
                                              MediaQuery.of(context).size.width,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .width /
                                              5,
                                        )),
                                  ],
                                ),
                              ],
                            ),
                          ],
                          expandedHeight: MediaQuery.of(context).size.width,
                          scrollController: _scrollController,
                        ),
                        SliverToBoxAdapter(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_accentColor, Colors.transparent],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: ListTile(
                                    title: Text(
                                      show.name ?? '',
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.start,
                                      maxLines: 1,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 40.0,
                                          fontWeight: FontWeight.w900),
                                    ),
                                    subtitle: InkWell(
                                      onTap: () => showModalBottomSheet(
                                        backgroundColor: Colors.transparent,
                                        useRootNavigator: true,
                                        isScrollControlled: true,
                                        context: context,
                                        builder: (BuildContext context) {
                                          return DraggableScrollableSheet(
                                            initialChildSize: 0.3,
                                            minChildSize: 0.3,
                                            maxChildSize: 0.9,
                                            expand: false,
                                            builder: (context,
                                                ScrollController
                                                    scrollController) {
                                              return Container(
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 12.0),
                                                clipBehavior: Clip.hardEdge,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .scaffoldBackgroundColor,
                                                  border: Border.all(
                                                      color:
                                                          Colors.transparent),
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(18),
                                                    topRight:
                                                        Radius.circular(18),
                                                  ),
                                                ),
                                                // Use ListView instead of SingleChildScrollView for scrollable content
                                                child: ListView(
                                                  controller:
                                                      scrollController, // Important: Connect ScrollController
                                                  children: [
                                                    ListTile(
                                                      leading: Container(
                                                        clipBehavior:
                                                            Clip.hardEdge,
                                                        decoration:
                                                            ShapeDecoration(
                                                          shape:
                                                              SmoothRectangleBorder(
                                                            borderRadius:
                                                                SmoothBorderRadius(
                                                              cornerRadius: 10,
                                                              cornerSmoothing:
                                                                  0.6,
                                                            ),
                                                          ),
                                                        ),
                                                        child: CachedImage(
                                                          url: show.image
                                                                  ?.full ??
                                                              '',
                                                        ),
                                                      ),
                                                      title:
                                                          Text(show.name ?? ''),
                                                      subtitle: Text(
                                                          show.authors ?? ''),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.all(16.0),
                                                      child: Text(
                                                          show.description ??
                                                              ''),
                                                    ),
                                                    ListTile(
                                                      title: Text('Share'.i18n),
                                                      leading: const Icon(
                                                          Icons.share),
                                                      onTap: () async {
                                                        SharePlus.instance
                                                            .share(
                                                          ShareParams(
                                                            text:
                                                                'https://deezer.com/show/' +
                                                                    (show.id ??
                                                                        ''),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                      child: CustomOverflowText(
                                        text: show.description ?? '',
                                        maxLines: 2,
                                        style: TextStyle(
                                            fontSize: 14.0,
                                            color: Colors.grey[700]),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12.0, horizontal: 6.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.max,
                                    children: <Widget>[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding:
                                                EdgeInsets.only(right: 8.0),
                                            child: IconButton(
                                              icon: (show.isLibrary ?? false)
                                                  ? Icon(
                                                      AlchemyIcons.heart_fill,
                                                      size: 25,
                                                      color: Theme.of(context)
                                                          .primaryColor,
                                                      semanticLabel:
                                                          'Unlove'.i18n,
                                                    )
                                                  : Icon(
                                                      AlchemyIcons.heart,
                                                      size: 25,
                                                      semanticLabel:
                                                          'Love'.i18n,
                                                    ),
                                              onPressed: () async {
                                                //Add to library
                                                if (!(show.isLibrary ??
                                                    false)) {
                                                  bool result = await deezerAPI
                                                      .addShow(show.id ?? '');

                                                  if (result) {
                                                    Fluttertoast.showToast(
                                                        msg: 'Added to library'
                                                            .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                    setState(() =>
                                                        show.isLibrary = true);
                                                  } else {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Failed to add show to library'
                                                                .i18n,
                                                        toastLength:
                                                            Toast.LENGTH_SHORT,
                                                        gravity: ToastGravity
                                                            .BOTTOM);
                                                  }
                                                  return;
                                                }
                                                //Remove
                                                bool result = await deezerAPI
                                                    .removeShow(show.id ?? '');
                                                if (result) {
                                                  Fluttertoast.showToast(
                                                      msg:
                                                          'Show removed from library!'
                                                              .i18n,
                                                      toastLength:
                                                          Toast.LENGTH_SHORT,
                                                      gravity:
                                                          ToastGravity.BOTTOM);
                                                  setState(() =>
                                                      show.isLibrary = false);
                                                } else {
                                                  Fluttertoast.showToast(
                                                      msg:
                                                          'Failed to remove show from library'
                                                              .i18n,
                                                      toastLength:
                                                          Toast.LENGTH_SHORT,
                                                      gravity:
                                                          ToastGravity.BOTTOM);
                                                }
                                              },
                                            ),
                                          ),
                                          IconButton(
                                              onPressed: () => {
                                                    SharePlus.instance.share(
                                                      ShareParams(
                                                        text:
                                                            'https://deezer.com/show/' +
                                                                (show.id ?? ''),
                                                      ),
                                                    )
                                                  },
                                              icon: Icon(
                                                AlchemyIcons.share_android,
                                                size: 20.0,
                                              )),
                                          Padding(
                                            padding: EdgeInsets.only(left: 8.0),
                                            //child: MakePlaylistOffline(playlist),
                                          ),
                                          IconButton(
                                            onPressed: () async {
                                              if (show.isSubscribed ?? false) {
                                                bool result = await deezerAPI
                                                    .unSubscribeShow(
                                                        show.id ?? '');
                                                if (result) {
                                                  Fluttertoast.showToast(
                                                      msg:
                                                          'Unsubscribed from show!'
                                                              .i18n,
                                                      toastLength:
                                                          Toast.LENGTH_SHORT,
                                                      gravity:
                                                          ToastGravity.BOTTOM);
                                                  setState(() => show
                                                      .isSubscribed = false);
                                                } else {
                                                  Fluttertoast.showToast(
                                                      msg:
                                                          'Failed to unsubscribe from show!'
                                                              .i18n,
                                                      toastLength:
                                                          Toast.LENGTH_SHORT,
                                                      gravity:
                                                          ToastGravity.BOTTOM);
                                                }
                                              } else {
                                                bool result = await deezerAPI
                                                    .subscribeShow(
                                                        show.id ?? '');
                                                if (result) {
                                                  Fluttertoast.showToast(
                                                      msg: 'Subscribed to show!'
                                                          .i18n,
                                                      toastLength:
                                                          Toast.LENGTH_SHORT,
                                                      gravity:
                                                          ToastGravity.BOTTOM);
                                                  setState(() =>
                                                      show.isSubscribed = true);
                                                } else {
                                                  Fluttertoast.showToast(
                                                      msg:
                                                          'Failed to subscribe to show!'
                                                              .i18n,
                                                      toastLength:
                                                          Toast.LENGTH_SHORT,
                                                      gravity:
                                                          ToastGravity.BOTTOM);
                                                }
                                              }
                                            },
                                            icon: Icon(
                                              (show.isSubscribed ?? false)
                                                  ? AlchemyIcons.bell_fill
                                                  : AlchemyIcons.bell,
                                              size: 20.0,
                                              color:
                                                  (show.isSubscribed ?? false)
                                                      ? Colors.green
                                                      : null,
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.only(left: 8.0),
                                            //child: MakePlaylistOffline(playlist),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Container(
                                            margin: EdgeInsets.only(right: 6.0),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              border: Border.all(
                                                  color: Theme.of(context)
                                                      .scaffoldBackgroundColor
                                                      .withAlpha(0)),
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                            ),
                                            child: IconButton(
                                                onPressed: () async {
                                                  await GetIt.I<
                                                          AudioPlayerHandler>()
                                                      .playShowEpisode(
                                                          show, _episodes,
                                                          index: 0);
                                                },
                                                icon: Icon(
                                                  AlchemyIcons.play,
                                                  size: 18,
                                                )),
                                          )
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Container(
                            height: 4.0,
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                              (BuildContext context, int index) {
                            ShowEpisode e = _episodes[index];
                            return ShowEpisodeTile(
                              e,
                              onTap: () async {
                                await GetIt.I<AudioPlayerHandler>()
                                    .playShowEpisode(show, _episodes,
                                        index: index);
                              },
                            );
                          }, childCount: _episodes.length),
                        ),
                        if (_isLoadingTracks)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  CircularProgressIndicator(
                                    color: Theme.of(context).primaryColor,
                                  )
                                ],
                              ),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: ListenableBuilder(
                              listenable: playerBarState,
                              builder: (BuildContext context, Widget? child) {
                                return AnimatedPadding(
                                  duration: Duration(milliseconds: 200),
                                  padding: EdgeInsets.only(
                                      bottom: playerBarState.state ? 80 : 0),
                                );
                              }),
                        ),
                      ],
                    );
                  }));
  }
}
