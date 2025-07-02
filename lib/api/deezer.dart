import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:alchemy/ui/details_screens.dart';
import 'package:alchemy/ui/menu.dart';
import 'package:alchemy/utils/navigator_keys.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:alchemy/utils/env.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:alchemy/api/cache.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:alchemy/api/download.dart';

import '../api/definitions.dart';
import '../api/spotify.dart';
import '../settings.dart';

DeezerAPI deezerAPI = DeezerAPI();

class KeyBag {
  String? token;
  String? tokenKey;
  String? userKey;
  String? sid;
  String? arl;

  KeyBag({
    this.token,
    this.tokenKey,
    this.userKey,
    this.sid,
    this.arl,
  });

  Map<String, String?> toJson() {
    return {
      'token': token,
      'tokenKey': tokenKey,
      'userKey': userKey,
      'sid': sid,
      'arl': arl,
    };
  }
}

class DeezerAPI {
  DeezerAPI({KeyBag? keyBag});

  static const String userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36';

  String? token;
  String? licenseToken;
  String? userId;
  String? favoritesPlaylistId;
  String? sid;
  KeyBag keyBag = KeyBag();
  final String deezerGatewayAPI = Env.deezerGatewayAPI;
  final String deezerMobileKey = Env.deezerMobileKey;

  Future? _authorizing;

  Future testFunction(BuildContext context) async {
    for (Track t in await downloadManager.allOfflineTracks()) {
      Logger.root.info(t.lyrics?.toJson());
    }
/*    ImagePicker picker = ImagePicker();
    XFile? imageFile = await picker.pickImage(source: ImageSource.gallery);
    if (imageFile == null) return;
    List<int>? imageData = await imageFile.readAsBytes();
    Logger.root.info(await imageUpload(imageData: imageData));*/
  }

  //Get headers
  Map<String, String> get headers => {
        'User-Agent': DeezerAPI.userAgent,
        'Content-Language':
            '${settings.deezerLanguage}-${settings.deezerCountry}',
        'Content-Type': 'text/plain;charset=UTF-8',
        //'origin': 'https://www.deezer.com',
        //'Cache-Control': 'max-age=0',
        'Accept': '*/*',
        'Accept-Charset': 'utf-8,ISO-8859-1;q=0.7,*;q=0.3',
        'Accept-Language':
            '${settings.deezerLanguage}-${settings.deezerCountry},${settings.deezerLanguage};q=0.9,en-US;q=0.8,en;q=0.7',
        'Connection': 'keep-alive',
        //'sec-fetch-site': 'same-origin',
        //'sec-fetch-mode': 'same-origin',
        //'sec-fetch-dest': 'empty',
        //'referer': 'https://www.deezer.com/',
        'Cookie': 'arl=${keyBag.arl}' + ((sid == null) ? '' : '; sid=$sid')
      };

  Future<String> getMediaPreview(String trackToken) async {
    //Generate URL
    Uri uri = Uri.https('media.deezer.com', 'v1/get_url');
    //Post
    http.Response res = await http
        .post(uri,
            headers: headers,
            body: jsonEncode({
              'license_token': licenseToken,
              'media': [
                {
                  'formats': [
                    {'cipher': 'NONE', 'format': 'MP3_128'}
                  ],
                  'type': 'PREVIEW',
                }
              ],
              'track_tokens': [trackToken]
            }))
        .catchError((e) {
      return http.Response('', 200);
    });
    if (res.body == '') return '';
    try {
      return jsonDecode(res.body)['data'][0]['media'][0]['sources'][0]['url'];
    } catch (e) {
      Logger.root.info('API preview fetch failed : $e');
      return '';
    }
  }

  Future<String> getTrackIsrc(String trackId) async {
    try {
      //Generate URL
      Map<dynamic, dynamic> track = await callPublicApi('track/$trackId');

      if (track['isrc'] != '') {
        return track['isrc'];
      } else {
        return '';
      }
    } catch (e) {
      return '';
    }
  }

  Future<String> getTrackPreview(String trackId) async {
    try {
      String isrc = await getTrackIsrc(trackId);
      dynamic data = await callPublicApi('track/isrc:$isrc');
      return data['preview'];
    } catch (e) {
      Logger.root.info('API preview fetch failed : $e');
      return '';
    }
  }

  //Call private GW-light API
  Future<Map<String, dynamic>> callGwLightApi(String method,
      {Map<String, dynamic>? params, String? gatewayInput}) async {
    //Generate URL
    Uri uri = Uri.https('www.deezer.com', '/ajax/gw-light.php', {
      'api_version': '1.0',
      'api_token': token,
      'input': '3',
      'method': method,
      'cid': Random().nextInt(1000000000).toString(),
      //Used for homepage
      if (gatewayInput != null) 'gateway_input': gatewayInput
    });
    //Post
    try {
      http.Response res = await http
          .post(uri, headers: headers, body: jsonEncode(params))
          .catchError((e) {
        return http.Response('', 200);
      });
      if (res.body == '') return {};
      dynamic body = jsonDecode(res.body);
      //Grab SID
      if (method == 'deezer.getUserData' && res.headers['set-cookie'] != null) {
        for (String cookieHeader in res.headers['set-cookie']!.split(';')) {
          if (cookieHeader.startsWith('sid=')) {
            sid = cookieHeader.split('=')[1];
          }
        }
      }
      // In case of error "Invalid CSRF token" retrieve new one and retry the same call
      // Except for "deezer.getUserData" method, which would cause infinite loop
      if (body['error'].isNotEmpty &&
          body['error'].containsKey('VALID_TOKEN_REQUIRED') &&
          (method != 'deezer.getUserData' && await rawAuthorize())) {
        return callGwLightApi(method,
            params: params, gatewayInput: gatewayInput);
      }
      return body;
    } catch (e) {
      Logger.root.info('Failed to call GW-light API.');
      return {};
    }
  }

  Future<bool> getGatewayKeybag() async {
    final initKeyBytes = utf8.encode(deezerMobileKey);
    final encrypt.Key initKey = encrypt.Key(initKeyBytes);
    final initEncrypter = encrypt.Encrypter(
        encrypt.AES(initKey, mode: encrypt.AESMode.ecb, padding: null));

    Uri tokenUri = Uri.https('api.deezer.com', '/1.0/gateway.php',
        {'api_key': deezerGatewayAPI, 'output': '3', 'method': 'mobile_auth'});
    http.Response tokenReq =
        await http.get(tokenUri, headers: headers).catchError((e) {
      return http.Response('', 200);
    });

    dynamic tokenRes = jsonDecode(tokenReq.body);

    String token = tokenRes['results']['TOKEN'];

    String decrypted =
        initEncrypter.decrypt(encrypt.Encrypted.fromBase16(token));

    keyBag.token = decrypted.substring(0, 64);
    keyBag.tokenKey = decrypted.substring(64, 80);
    keyBag.userKey = decrypted.substring(80, 96);

    if (keyBag.token != null &&
        keyBag.tokenKey != null &&
        keyBag.userKey != null) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> getGatewayAuth() async {
    if ((keyBag.token == null ||
            keyBag.tokenKey == null ||
            keyBag.userKey == null) &&
        !(await getGatewayKeybag())) {
      return false;
    }

    final encrypter = encrypt.Encrypter(encrypt.AES(
        encrypt.Key(utf8.encode(keyBag.tokenKey!)),
        mode: encrypt.AESMode.ecb,
        padding: null));

    String authToken = encrypter.encrypt(keyBag.token!).base16.toString();

    Uri sidUri = Uri.https('api.deezer.com', '/1.0/gateway.php', {
      'api_key': deezerGatewayAPI,
      'output': '3',
      'method': 'api_checkToken',
      'auth_token': authToken
    });
    http.Response sidReq =
        await http.get(sidUri, headers: headers).catchError((e) {
      return http.Response('', 200);
    });

    dynamic sidRes = jsonDecode(sidReq.body);

    keyBag.sid = sidRes['results'];

    Uri arlUri = Uri.https('api.deezer.com', '/1.0/gateway.php', {
      'api_key': deezerGatewayAPI,
      'sid': keyBag.sid,
      'output': '3',
      'method': 'mobile_userAutolog',
    });
    http.Response arlReq =
        await http.get(arlUri, headers: headers).catchError((e) {
      return http.Response('', 200);
    });

    dynamic arlRes = jsonDecode(arlReq.body);

    keyBag.arl = arlRes['results']['ARL'];

    if (keyBag.sid != null && keyBag.arl != null) {
      return true;
    } else {
      return false;
    }
  }

  //Call private gateway API
  Future<Map<String, dynamic>> callGwApi(String method,
      {Map<String, dynamic>? params, String? gatewayInput}) async {
    //Generate URL
    Uri uri = Uri.https('api.deezer.com', '/1.0/gateway.php', {
      'api_key': deezerGatewayAPI,
      'sid': keyBag.sid,
      'method': method,
      'output': '3',
      'input': '3',
      'arl': keyBag.arl,
    });

    Map<String, String> gwHeaders = {
      'User-Agent': '',
      'Content-Type': 'text/plain;charset=UTF-8',
      'origin': 'https://www.deezer.com',
      'Cache-Control': 'max-age=0',
      'Accept': '*/*',
      'Accept-Charset': 'utf-8,ISO-8859-1;q=0.7,*;q=0.3',
      'Connection': 'keep-alive',
      'sec-fetch-site': 'same-origin',
      'sec-fetch-mode': 'same-origin',
      'sec-fetch-dest': 'empty',
      'referer': 'https://www.deezer.com/',
    };

    //Post
    http.Response res = await http
        .post(uri, headers: gwHeaders, body: jsonEncode(params))
        .catchError((e) {
      return http.Response('', 200);
    });

    dynamic body = jsonDecode(res.body);

    //Grab SID
    if (method == 'deezer.getUserData' && res.headers['set-cookie'] != null) {
      for (String cookieHeader in res.headers['set-cookie']!.split(';')) {
        if (cookieHeader.startsWith('sid=')) {
          sid = cookieHeader.split('=')[1];
        }
      }
    }
    // In case of error "Invalid CSRF token" retrieve new one and retry the same call
    // Except for "deezer.getUserData" method, which would cause infinite loop
    if (body['error'].isNotEmpty &&
        body['error'].containsKey('NEED_API_AUTH_REQUIRED') &&
        (method != 'deezer.getUserData' && await getGatewayAuth())) {
      return callGwApi(method, params: params, gatewayInput: gatewayInput);
    }
    return body;
  }

  Future<Map<dynamic, dynamic>> callPublicApi(String path) async {
    http.Response res =
        await http.get(Uri.parse('https://api.deezer.com/' + path));
    return jsonDecode(res.body);
  }

  Future<String> getJsonWebToken() async {
    //Generate URL
    //Uri uri = Uri.parse('https://auth.deezer.com/login/arl?jo=p&rto=c&i=c');
    try {
      Uri uri = Uri.https(
          'auth.deezer.com', '/login/arl', {'jo': 'p', 'rto': 'c', 'i': 'c'});
      //Post
      http.Response res = await http.post(uri, headers: headers);
      dynamic body = jsonDecode(res.body);
      //Grab jwt token
      if (body['jwt']?.isNotEmpty) {
        return body['jwt'];
      }
    } catch (e) {
      return '';
    }
    return '';
  }

  //Call private pipe API
  Future<Map<String, dynamic>> callPipeApi(
      {Map<String, dynamic>? params}) async {
    //Get jwt auth token
    String jwtToken = await getJsonWebToken();
    Map<String, String> pipeApiHeaders = headers;
    // Add jwt token to headers
    pipeApiHeaders['Authorization'] = 'Bearer $jwtToken';
    // Change Content-Type to application/json
    pipeApiHeaders['Content-Type'] = 'application/json';
    //Generate URL
    //Uri uri = Uri.parse('https://pipe.deezer.com/api');
    Uri uri = Uri.https('pipe.deezer.com', '/api/');
    //Post
    http.Response res =
        await http.post(uri, headers: pipeApiHeaders, body: jsonEncode(params));
    dynamic body = jsonDecode(res.body);

    return body;
  }

  Future<List<DeezerNotification>> getNotifications({
    int nb = 20,
    String? lastId,
  }) async {
    Map<dynamic, dynamic> data =
        await callGwApi('appnotif_getUserNotifications', params: {
      'NB': nb,
      'LAST_NOTIFICATION_ID': lastId,
    });
    if (data['results']?['data'] == null) {
      return [];
    } else {
      List<DeezerNotification> notifications = [];
      for (int i = 0; i < data['results']['data'].length; i++) {
        notifications.add(
            DeezerNotification.fromPrivateJson(data['results']['data'][i]));
      }
      return notifications;
    }
  }

  //Wrapper so it can be globally awaited
  Future<bool> authorize() async {
    return await (_authorizing ??= rawAuthorize().then((success) {
      _authorizing = null;
      return success;
    }));
  }

  //Authorize, bool = success
  Future<bool> rawAuthorize({Function? onError}) async {
    try {
      Map<dynamic, dynamic> data = await callGwLightApi('deezer.getUserData');
      if ((data['results']?['USER']?['USER_ID'] ?? 0) == 0) {
        return false;
      } else {
        token = data['results']['checkForm'];
        userId = data['results']['USER']['USER_ID']?.toString() ?? '';
        favoritesPlaylistId = data['results']['USER']['LOVEDTRACKS_ID'];
        licenseToken = data['results']['USER']['OPTIONS']['license_token'];

        //Store favoritesPlaylistId
        cache.favoritesPlaylistId =
            favoritesPlaylistId ?? cache.favoritesPlaylistId;
        cache.userName = data['results']['USER']['BLOG_NAME'] ?? '';
        cache.userPicture = ImageDetails.fromPrivateString(
                data['results']['USER']['USER_PICTURE'],
                type: 'user')
            .toJson();
        cache.userEmail = data['results']['USER']['EMAIL'];
        cache.userColor = (await ColorScheme.fromImageProvider(
                provider: CachedNetworkImageProvider(
                    ImageDetails.fromJson(cache.userPicture).fullUrl ?? '')))
            .primary
            .toARGB32();
        cache.save();

        return true;
      }
    } catch (e) {
      if (onError != null) {
        onError(e);
      }
      Logger.root.severe('Login Error (D): ' + e.toString());
      return false;
    }
  }

  //URL/Link parser
  Future<DeezerLinkResponse?> parseLink(String url) async {
    Uri uri = Uri.parse(url);
    //https://www.deezer.com/NOTHING_OR_COUNTRY/TYPE/ID
    if (uri.host == 'www.deezer.com' || uri.host == 'deezer.com') {
      if (uri.pathSegments.length < 2) return null;
      DeezerLinkType? type = DeezerLinkResponse.typeFromString(
          uri.pathSegments[uri.pathSegments.length - 2]);
      return DeezerLinkResponse(
          type: type, id: uri.pathSegments[uri.pathSegments.length - 1]);
    }
    //Share URL
    if (uri.host == 'dzr.page.link' || uri.host == 'www.dzr.page.link') {
      http.BaseRequest request = http.Request('HEAD', Uri.parse(url));
      request.followRedirects = false;
      http.StreamedResponse response = await request.send();
      String newUrl = response.headers['location'] ?? '';
      return parseLink(newUrl);
    }
    //Spotify
    if (uri.host == 'open.spotify.com') {
      if (uri.pathSegments.length < 2) return null;
      String spotifyUri = 'spotify:' + uri.pathSegments.sublist(0, 2).join(':');
      try {
        //Tracks
        if (uri.pathSegments[0] == 'track') {
          String id = await SpotifyScrapper.convertTrack(spotifyUri);
          return DeezerLinkResponse(type: DeezerLinkType.TRACK, id: id);
        }
        //Albums
        if (uri.pathSegments[0] == 'album') {
          String id = await SpotifyScrapper.convertAlbum(spotifyUri);
          return DeezerLinkResponse(type: DeezerLinkType.ALBUM, id: id);
        }
      } catch (e) {
        Logger.root.severe('Error converting Spotify results: ' + e.toString());
      }
    }
    return null;
  }

  //Check if Deezer available in country
  static Future<bool?> checkAvailability() async {
    try {
      http.Response res =
          await http.get(Uri.parse('https://api.deezer.com/infos'));
      return jsonDecode(res.body)['open'];
    } catch (e) {
      return null;
    }
  }

  //Search
  List<SearchHistoryItem> parseRawHistory(List<dynamic> json) {
    if (json.isEmpty) return [];

    List<SearchHistoryItem> searchHistory = [];

    for (dynamic rawItem in json) {
      String? rawType = rawItem['node']['__typename'];
      dynamic item;
      switch (rawType) {
        case 'Track':
          item = SearchHistoryItem(
              Track.fromPipeJson(rawItem['node']), SearchHistoryItemType.TRACK);
          break;
        case 'Album':
          item = SearchHistoryItem(
              Album.fromPipeJson(rawItem['node']), SearchHistoryItemType.ALBUM);
          break;
        case 'Artist':
          item = SearchHistoryItem(Artist.fromPipeJson(rawItem['node']),
              SearchHistoryItemType.ARTIST);
          break;
        case 'Playlist':
          item = SearchHistoryItem(Playlist.fromPipeJson(rawItem['node']),
              SearchHistoryItemType.PLAYLIST);
          break;
        case 'Podcast':
          item = SearchHistoryItem(
              Show.fromPipeJson(rawItem['node']), SearchHistoryItemType.SHOW);
          break;
      }
      if (item != null) searchHistory.add(item);
    }

    return searchHistory;
  }

  Future<List<SearchHistoryItem>> recentlySearched(
      {int start = 0, int limit = 5}) async {
    Map<dynamic, dynamic> data =
        await callGwApi('user_getRecentlySearched', params: {
      'START': limit,
      'LIMIT': start,
    });

    if (data['results']['data'] == null) return [];

    return parseRawHistory(data['results']['data']);
  }

  Future<List<SearchHistoryItem>> getUserHistory() async {
    Map<String, dynamic> apiParams = {
      'operationName': 'GetMySearchHistory',
      'variables': {'first': 20},
      'query':
          'query GetMySearchHistory(\$first: Int, \$after: String) { me { __typename searchHistory { __typename successResults(first: \$first, after: \$after) { __typename pageInfo { __typename ...PageInfoFragment } edges { __typename node { __typename ... on Album { ...AlbumCollectionFragment cover { __typename ...PictureMD5Fragment } albumContributors: contributors(first: 1) { __typename edges { __typename roles node { __typename ... on Artist { ...ArtistMinimalFragment } } } } } ... on Artist { ...ArtistDetailFragment picture { __typename ...PictureMD5Fragment } } ... on Playlist { ...PlaylistCollectionFragment picture { __typename ...PictureFragment } owner { __typename ...UserMinimalFragment } linkedArtist { __typename ...ArtistMinimalFragment } } ... on Track { ...TrackWithoutMediaCollectionFragment album { __typename ...AlbumMinimalFragment cover { __typename ...PictureMD5Fragment } } trackContributors: contributors(first: 1) { __typename edges { __typename roles node { __typename ... on Artist { ...ArtistMinimalFragment } } } } } ... on Podcast { ...PodcastCollectionFragment cover { __typename ...PictureMD5Fragment } } ... on PodcastEpisode { ...PodcastEpisodeCollectionFragment cover { __typename ...PictureMD5Fragment } } ... on Livestream { ...LivestreamCollectionFragment cover { __typename ...PictureMD5Fragment } } } } } } } }  fragment PageInfoFragment on PageInfo { __typename hasNextPage hasPreviousPage startCursor endCursor }  fragment AlbumCollectionFragment on Album { __typename id displayTitle type albumReleaseDate: releaseDate albumIsExplicit: isExplicit albumIsFavorite: isFavorite tracksCount rank }  fragment PictureMD5Fragment on Picture { __typename id md5 explicitStatus }  fragment ArtistMinimalFragment on Artist { __typename id name }  fragment ArtistDetailFragment on Artist { __typename id name fansCount onTour status hasPartialDiscography hasSmartRadio hasTopTracks isDummyArtist isPictureFromReliableSource artistIsFavorite: isFavorite isBannedFromRecommendation isSubscriptionEnabled }  fragment PlaylistCollectionFragment on Playlist { __typename id title playlistIsFavorite: isFavorite isFromFavoriteTracks creationDate lastModificationDate estimatedTracksCount isCharts isPrivate }  fragment PictureFragment on Picture { __typename id small: urls(pictureRequest: { height: 256 width: 256 } ) medium: urls(pictureRequest: { height: 750 width: 750 } ) large: urls(pictureRequest: { height: 1200 width: 1200 } ) copyright explicitStatus }  fragment UserMinimalFragment on User { __typename id name }  fragment TrackWithoutMediaCollectionFragment on Track { __typename id title duration gain bpm popularity trackReleaseDate: releaseDate trackIsExplicit: isExplicit trackIsFavorite: isFavorite isBannedFromRecommendation }  fragment AlbumMinimalFragment on Album { __typename id displayTitle }  fragment PodcastCollectionFragment on Podcast { __typename id displayTitle description podcastIsFavorite: isFavorite podcastIsExplicit: isExplicit }  fragment PodcastEpisodeCollectionFragment on PodcastEpisode { __typename id title duration releaseDate }  fragment LivestreamCollectionFragment on Livestream { __typename id name isOnStream }'
    };

    Map<dynamic, dynamic> rawHistory = await callPipeApi(params: apiParams);

    return parseRawHistory(
        rawHistory['data']['me']['searchHistory']['successResults']['edges']);
  }

  Future<InstantSearchResults> instantSearch(String query,
      {bool includeBestResult = false,
      bool includeTracks = false,
      bool includeAlbums = false,
      bool includeArtists = false,
      bool includePlaylists = false,
      bool includeUsers = false,
      bool includeFlowConfigs = false,
      bool includeLivestreams = false,
      bool includePodcasts = false,
      bool includePodcastEpisodes = false,
      bool includeChannels = false,
      int count = 2}) async {
    if (query == '') return InstantSearchResults();

    Map<String, dynamic> searchParams = {
      'operationName': 'InstantSearchQuery',
      'variables': {
        'querySearched': query,
        'first': count,
        'includeBestResult': includeBestResult,
        'includeTracks': includeTracks,
        'includeAlbums': includeAlbums,
        'includeArtists': includeArtists,
        'includePlaylists': includePlaylists,
        'includeUsers': includeUsers,
        'includeFlowConfigs': includeFlowConfigs,
        'includeLivestreams': includeLivestreams,
        'includePodcasts': includePodcasts,
        'includePodcastEpisodes': includePodcastEpisodes,
        'includeChannels': includeChannels
      },
      'query':
          'query InstantSearchQuery(\$querySearched: String!, \$first: Int, \$after: String, \$includeBestResult: Boolean!, \$includeTracks: Boolean!, \$includeAlbums: Boolean!, \$includeArtists: Boolean!, \$includePlaylists: Boolean!, \$includeUsers: Boolean!, \$includeFlowConfigs: Boolean!, \$includeLivestreams: Boolean!, \$includePodcasts: Boolean!, \$includePodcastEpisodes: Boolean!, \$includeChannels: Boolean!) { instantSearch(query: \$querySearched) { __typename bestResult @include(if: \$includeBestResult) { __typename ... on InstantSearchArtistBestResult { artist { __typename ...ArtistDetailFragment picture { __typename ...PictureMD5Fragment } } relatedContent { __typename ... on InstantSearchArtistBestResultRelatedContentTopTracks { tracks(limit: 3) { __typename id } } ... on InstantSearchArtistBestResultRelatedContentNewRelease { album { __typename ...AlbumDetailFragment cover { __typename ...PictureMD5Fragment } albumContributors: contributors(first: 1) { __typename edges { __typename roles node { __typename ... on Artist { ...ArtistMinimalFragment } } } } } } } } ... on InstantSearchAlbumBestResult { album { __typename ...AlbumCollectionFragment cover { __typename ...PictureMD5Fragment } albumContributors: contributors(first: 1) { __typename edges { __typename roles node { __typename ... on Artist { ...ArtistMinimalFragment } } } } } } ... on InstantSearchPlaylistBestResult { playlist { __typename ...PlaylistCollectionFragment picture { __typename ...PictureFragment } owner { __typename ...UserMinimalFragment } linkedArtist { __typename ...ArtistMinimalFragment } } } ... on InstantSearchTrackBestResult { track { __typename ...TrackWithoutMediaCollectionFragment album { __typename ...AlbumMinimalFragment cover { __typename ...PictureMD5Fragment } } trackContributors: contributors(first: 1) { __typename edges { __typename roles node { __typename ... on Artist { ...ArtistMinimalFragment } } } } } } ... on InstantSearchPodcastBestResult { podcast { __typename ...PodcastCollectionFragment cover { __typename ...PictureMD5Fragment } } } ... on InstantSearchPodcastEpisodeBestResult { podcastEpisode { __typename ...PodcastEpisodeCollectionFragment cover { __typename ...PictureMD5Fragment } podcast { __typename displayTitle } } } ... on InstantSearchLivestreamBestResult { livestream { __typename ...LivestreamCollectionFragment cover { __typename ...PictureMD5Fragment } } } } results { __typename tracks(first: \$first, after: \$after) @include(if: \$includeTracks) { __typename priority pageInfo { __typename ...PageInfoFragment } edges { __typename node { __typename ...TrackWithoutMediaCollectionFragment album { __typename ...AlbumMinimalFragment cover { __typename ...PictureMD5Fragment } } contributors(first: 1) { __typename edges { __typename roles node { __typename ...ArtistMinimalFragment } } } } } } albums(first: \$first, after: \$after) @include(if: \$includeAlbums) { __typename priority pageInfo { __typename ...PageInfoFragment } edges { __typename node { __typename ...AlbumCollectionFragment cover { __typename ...PictureMD5Fragment } contributors(first: 1) { __typename edges { __typename roles node { __typename ...ArtistMinimalFragment } } } } } } artists(first: \$first, after: \$after) @include(if: \$includeArtists) { __typename priority pageInfo { __typename ...PageInfoFragment } edges { __typename node { __typename ...ArtistDetailFragment picture { __typename ...PictureMD5Fragment } } } } playlists(first: \$first, after: \$after) @include(if: \$includePlaylists) { __typename pageInfo { __typename ...PageInfoFragment } priority edges { __typename node { __typename ...PlaylistCollectionFragment picture { __typename ...PictureFragment } owner { __typename ...UserMinimalFragment } linkedArtist { __typename ...ArtistMinimalFragment } } } } users(first: \$first, after: \$after) @include(if: \$includeUsers) { __typename priority pageInfo { __typename ...PageInfoFragment } edges { __typename node { __typename ...UserMinimalFragment picture { __typename ...PictureMD5Fragment } } } } flowConfigs(first: \$first, after: \$after) @include(if: \$includeFlowConfigs) { __typename priority pageInfo { __typename ...PageInfoFragment } edges { __typename node { __typename ...FlowConfigMinimalFragment visuals { __typename dynamicPageIcon { __typename ...UIAssetFragment } } } } } livestreams(first: \$first, after: \$after) @include(if: \$includeLivestreams) { __typename priority pageInfo { __typename ...PageInfoFragment } edges { __typename node { __typename ...LivestreamCollectionFragment cover { __typename ...PictureMD5Fragment } } } } podcasts(first: \$first, after: \$after) @include(if: \$includePodcasts) { __typename priority pageInfo { __typename ...PageInfoFragment } edges { __typename node { __typename ...PodcastCollectionFragment cover { __typename ...PictureMD5Fragment } } } } podcastEpisodes(first: \$first, after: \$after) @include(if: \$includePodcastEpisodes) { __typename priority pageInfo { __typename ...PageInfoFragment } edges { __typename node { __typename ...PodcastEpisodeCollectionFragment cover { __typename ...PictureMD5Fragment } } } } channels(first: \$first, after: \$after) @include(if: \$includeChannels) { __typename priority pageInfo { __typename ...PageInfoFragment } edges { __typename node { __typename ...ChannelCollectionFragment logo { __typename ...PictureMD5Fragment } picture { __typename ...PictureFragment } } } } } } }  fragment ArtistDetailFragment on Artist { __typename id name fansCount onTour status hasPartialDiscography hasSmartRadio hasTopTracks isDummyArtist isPictureFromReliableSource artistIsFavorite: isFavorite isBannedFromRecommendation isSubscriptionEnabled }  fragment PictureMD5Fragment on Picture { __typename id md5 explicitStatus }  fragment AlbumDetailFragment on Album { __typename id displayTitle type label producerLine duration releaseDate fansCount isExplicit isTakenDown isFavorite discsCount tracksCount }  fragment ArtistMinimalFragment on Artist { __typename id name }  fragment AlbumCollectionFragment on Album { __typename id displayTitle type albumReleaseDate: releaseDate albumIsExplicit: isExplicit albumIsFavorite: isFavorite tracksCount rank }  fragment PlaylistCollectionFragment on Playlist { __typename id title playlistIsFavorite: isFavorite isFromFavoriteTracks creationDate lastModificationDate estimatedTracksCount isCharts isPrivate }  fragment PictureFragment on Picture { __typename id small: urls(pictureRequest: { height: 256 width: 256 } ) medium: urls(pictureRequest: { height: 750 width: 750 } ) large: urls(pictureRequest: { height: 1200 width: 1200 } ) copyright explicitStatus }  fragment UserMinimalFragment on User { __typename id name }  fragment TrackWithoutMediaCollectionFragment on Track { __typename id title duration gain bpm popularity trackReleaseDate: releaseDate trackIsExplicit: isExplicit trackIsFavorite: isFavorite isBannedFromRecommendation }  fragment AlbumMinimalFragment on Album { __typename id displayTitle }  fragment PodcastCollectionFragment on Podcast { __typename id displayTitle description podcastIsFavorite: isFavorite podcastIsExplicit: isExplicit }  fragment PodcastEpisodeCollectionFragment on PodcastEpisode { __typename id title duration releaseDate }  fragment LivestreamCollectionFragment on Livestream { __typename id name isOnStream }  fragment PageInfoFragment on PageInfo { __typename hasNextPage hasPreviousPage startCursor endCursor }  fragment FlowConfigMinimalFragment on FlowConfig { __typename id title }  fragment UIAssetFragment on UIAsset { __typename id small: urls(uiAssetRequest: { height: 256 width: 256 } ) medium: urls(uiAssetRequest: { height: 750 width: 750 } ) large: urls(uiAssetRequest: { height: 1200 width: 1200 } ) }  fragment ChannelCollectionFragment on Channel { __typename id name backgroundColor slug }'
    };
    Map<dynamic, dynamic> data = await callPipeApi(params: searchParams);
    return InstantSearchResults.fromPipeJson(data['data']['instantSearch']);
  }

  Future logSuccessfullSearchResult(dynamic searchResult) async {
    switch (searchResult.runtimeType) {
      case Track:
        await callPipeApi(params: {
          'operationName': 'AddTrackInSearchSuccessResult',
          'variables': {'trackId': (searchResult as Track).id},
          'query':
              'mutation AddTrackInSearchSuccessResult(\$trackId: String!) { addTrackInSearchSuccessResult(trackId: \$trackId) { __typename status } }'
        });
      case Artist:
        await callPipeApi(params: {
          'operationName': 'AddArtistInSearchSuccessResult',
          'variables': {'artistId': (searchResult as Artist).id},
          'query':
              'mutation AddArtistInSearchSuccessResult(\$artistId: String!) { addArtistInSearchSuccessResult(artistId: \$artistId) { __typename status } }'
        });
      case Album:
        await callPipeApi(params: {
          'operationName': 'AddAlbumInSearchSuccessResult',
          'variables': {'albumId': (searchResult as Album).id},
          'query':
              'mutation AddAlbumInSearchSuccessResult(\$albumId: String!) { addAlbumInSearchSuccessResult(albumId: \$albumId) { __typename status } }'
        });
      case Playlist:
        await callPipeApi(params: {
          'operationName': 'AddPlaylistInSearchSuccessResult',
          'variables': {'playlistId': (searchResult as Playlist).id},
          'query':
              'mutation AddPlaylistInSearchSuccessResult(\$playlistId: String!) { addPlaylistInSearchSuccessResult(playlistId: \$playlistId) { __typename status } }'
        });
      case Show:
        await callPipeApi(params: {
          'operationName': 'AddPodcastInSearchSuccessResult',
          'variables': {'podcastId': (searchResult as Show).id},
          'query':
              'mutation AddPodcastInSearchSuccessResult(\$podcastId: String!) { addPodcastInSearchSuccessResult(podcastId: \$podcastId) { __typename status } }'
        });
      case ShowEpisode:
        await callPipeApi(params: {
          'operationName': 'AddPodcastEpisodeInSearchSuccessResult',
          'variables': {'podcastEpisodeId': (searchResult as ShowEpisode).id},
          'query':
              'mutation AddPodcastEpisodeInSearchSuccessResult(\$podcastEpisodeId: String!) { addPodcastEpisodeInSearchSuccessResult(episodeId: \$podcastEpisodeId) { __typename status } }'
        });
      default:
        Logger.root.info(
            'Unsupported search result type : ${searchResult.runtimeType}');
        return;
    }
  }

  Future<Track> track(String id) async {
    Map<dynamic, dynamic> data = await callGwApi('song.getListData', params: {
      'sng_ids': [id]
    });
    return Track.fromPrivateJson(data['results']?['data']?[0] ?? {});
  }

  //Get album details, tracks
  Future<Album> album(String id) async {
    Map<dynamic, dynamic> data = await callGwApi('mobile.pageAlbum', params: {
      'ALB_ID': id,
      'USER_ID': userId,
      'LANG': settings.deezerLanguage
    });
    while (data['results']?['DATA'] == null &&
        data['payload']?['FALLBACK']?['ALB_ID'] != null) {
      data = await callGwApi('mobile.pageAlbum', params: {
        'ALB_ID': id,
        'USER_ID': userId,
        'LANG': settings.deezerLanguage
      });
    }
    if (data['results']?['DATA'] == null) return Album();
    return Album.fromPrivateJson(data['results']['DATA'],
        songsJson: data['results']['SONGS'],
        library: data['results']['FAVORITE_STATUS']);
  }

  Future<Artist> artist(String id) async {
    Map<dynamic, dynamic> data =
        await callGwApi('mobile.pageArtistSections', params: {
      'USER_ID': userId,
      'ART_ID': id,
      'SECTIONS': [
        {
          'TOP_TRACKS': {'count': 4, 'start': 0},
          'HIGHLIGHT': {},
          'MASTHEAD': {'smartradio': true, 'bio_url': true},
        }
      ],
      'LANG': settings.deezerLanguage,
    });

    if (data['results'] == null) return Artist();

    Artist a = Artist.fromGwJson(
      data['results'].first,
    );

    return a;
  }

  //Get artist details
  Future<Artist> completeArtist(String id) async {
    Map<dynamic, dynamic> data =
        await callGwApi('mobile.pageArtistSections', params: {
      'USER_ID': userId,
      'ART_ID': id,
      'SECTIONS': [
        {
          'TOP_TRACKS': {'count': 4, 'start': 0},
          'HIGHLIGHT': {},
          'MASTHEAD': {'smartradio': true, 'bio_url': true},
          'ESSENTIALS': {'count': 6, 'start': 0},
          'FEATURED_IN': {'count': 13, 'start': 0},
          'PLAYLISTS': {'count': 13, 'start': 0}
        }
      ],
      'LANG': settings.deezerLanguage,
    });

    Map<dynamic, dynamic> complementaryData = await callPipeApi(params: {
      'query':
          'query artistPage {\n  artist(artistId: \"$id\") {\n    id\n    name\n    isDummyArtist\n    hasSmartRadio\n    fansCount\n    picture {\n      md5\n      explicitStatus\n    }\n    isPictureFromReliableSource\n    status\n    isSubscriptionEnabled\n    bio {\n      summary\n      full\n      source\n    }\n  }\n  ALBUM:artist(artistId: "$id") {\n    albums(types: [ALBUM], order: RELEASE_DATE, mode: OFFICIAL, roles: [MAIN], first: 13) {\n      pageInfo {\n        hasNextPage\n      }\n      edges {\n        node {\n          id\n          isFavorite\n          label\n          type\n          displayTitle\n          cover {\n            md5\n            explicitStatus\n          }\n          releaseDate\n          windowing {\n            releaseDateFree\n            releaseDateSub\n          }\n          contributors(first: 10) {\n            edges {\n              node {\n                ... on Artist {\n                  __typename\n                  id\n                  name\n                  isDummyArtist\n                  picture {\n                    md5\n                    explicitStatus\n                  }\n                }\n              }\n              roles\n            }\n          }\n        }\n      }\n    }\n  }\n  EP:artist(artistId: "$id") {\n    albums(types: [EP], order: RELEASE_DATE, mode: OFFICIAL, roles: [MAIN], first: 13) {\n      pageInfo {\n        hasNextPage\n      }\n      edges {\n        node {\n          id\n          isFavorite\n          label\n          type\n          displayTitle\n          cover {\n            md5\n            explicitStatus\n          }\n          releaseDate\n          windowing {\n            releaseDateFree\n            releaseDateSub\n          }\n          contributors(first: 10) {\n            edges {\n              node {\n                ... on Artist {\n                  __typename\n                  id\n                  name\n                  isDummyArtist\n                  picture {\n                    md5\n                    explicitStatus\n                  }\n                }\n              }\n              roles\n            }\n          }\n        }\n      }\n    }\n  }\n  SINGLES:artist(artistId: "$id") {\n    albums(types: [SINGLES], order: RELEASE_DATE, mode: OFFICIAL, roles: [MAIN], first: 13) {\n      pageInfo {\n        hasNextPage\n      }\n      edges {\n        node {\n          id\n          isFavorite\n          label\n          type\n          displayTitle\n          cover {\n            md5\n            explicitStatus\n          }\n          releaseDate\n          windowing {\n            releaseDateFree\n            releaseDateSub\n          }\n          contributors(first: 10) {\n            edges {\n              node {\n                ... on Artist {\n                  __typename\n                  id\n                  name\n                  isDummyArtist\n                  picture {\n                    md5\n                    explicitStatus\n                  }\n                }\n              }\n              roles\n            }\n          }\n        }\n      }\n    }\n  }\n  relatedArtists:artist(artistId: "$id") {\n    relatedArtist(first: 13) {\n      pageInfo {\n        hasNextPage\n        endCursor\n      }\n      edges {\n        cursor\n        node {\n          id\n          hasSmartRadio\n          isDummyArtist\n          fansCount\n          name\n          picture {\n            md5\n            explicitStatus\n          }\n        }\n      }\n    }\n  }\n  liveEventsByProximity:artist(artistId: "$id") {\n    liveEventsByProximity(first: 1) {\n      edges {\n        node {\n          id\n          name\n          description\n          startDate\n          status\n          venue\n          cityName\n          duration\n          hasSubscribedToNotification\n          countryCode\n          sources {\n            defaultUrl\n          }\n          types {\n            isConcert\n            isFestival\n            isLivestreamConcert\n            isLivestreamFestival\n          }\n          assets {\n            eventCardImageMobile {\n              md5\n              urls(pictureRequest: {height: 256, width: 256})\n            }\n          }\n          contributors {\n            pageInfo {\n              hasNextPage\n              endCursor\n            }\n            edges {\n              cursor\n              concertContributorMetadata {\n                roles {\n                  isMain\n                  isSupport\n                }\n                performanceOrder\n              }\n              node {\n                ... on Artist {\n                  __typename\n                  id\n                  name\n                  picture {\n                    urls(pictureRequest: {height: 750, width: 750})\n                  }\n                  fansCount\n                  isFavorite\n                }\n              }\n            }\n          }\n          live {\n            id\n            externalUrl {\n              url\n            }\n          }\n        }\n      }\n    }\n  }\n}'
    });
    if (data['results'] == null) return Artist();

    Artist a = Artist.fromGwJson(data['results'].first,
        pipeJson: complementaryData['data']);

    return a;
  }

  Future<List<Track>> artistTopTracks(
    String id, {
    int count = 100,
    int start = 0,
  }) async {
    Map<dynamic, dynamic> data =
        await callGwApi('mobile.pageArtistSections', params: {
      'USER_ID': userId,
      'ART_ID': id,
      'SECTIONS': [
        {
          'TOP_TRACKS': {'count': count, 'start': start}
        }
      ],
      'LANG': settings.deezerLanguage,
    });

    if (data['results']?[0]?['TOP_TRACKS']?['data'] == null) return [];

    return data['results']?[0]?['TOP_TRACKS']?['data']
        .map<Track>((dynamic t) => Track.fromPrivateJson(t))
        .toList();
  }

  //Get playlist tracks at offset
  Future<List<Track>> playlistTracksPage(String id, int start,
      {int nb = 50}) async {
    Map data = await callGwApi('playlist_getSongs', params: {
      'PLAYLIST_ID': id,
      'START': start.toString(),
      'NB': nb.toString(),
    });
    if (data['results'] == null) return [];
    return data['results']['data']
        ?.map<Track>((json) => Track.fromPrivateJson(json))
        .toList();
  }

  //Get playlist details
  Future<Playlist> playlist(String id, {int nb = 100}) async {
    Map<dynamic, dynamic> data = await callGwApi('playlist_getData', params: {
      'PLAYLIST_ID': id,
    });

    Map<dynamic, dynamic> songsData =
        await callGwApi('playlist_getSongs', params: {
      'PLAYLIST_ID': id,
      'START': '0',
      'NB': nb.toString(),
    });

    if (data['results'] == null) return Playlist();
    return Playlist.fromPrivateJson(data['results'],
        songsJson: songsData['results']);
  }

  //Get playlist with all tracks
  Future<Playlist> fullPlaylist(String id) async {
    return await playlist(id, nb: 100000);
  }

  //Add track to favorites
  Future<bool> addFavoriteTrack(String id) async {
    return addToPlaylist(id, cache.favoritesPlaylistId);
  }

  //Add album to favorites/library
  Future<bool> addFavoriteAlbum(String id) async {
    Map data = await callPipeApi(params: {
      'operationName': 'AddAlbumToFavorite',
      'variables': {'albumId': id},
      'query':
          'mutation AddAlbumToFavorite(\$albumId: String!) { addAlbumToFavorite(albumId: \$albumId) { __typename favoritedAt album { __typename id isFavorite } } }'
    });

    if (data['data']?['addAlbumToFavorite']?['album']?['isFavorite'] == true) {
      return true;
    }

    return false;
  }

  //Add artist to favorites/library
  Future<bool> addFavoriteArtist(String id) async {
    Map data = await callPipeApi(params: {
      'operationName': 'AddArtistToFavorite',
      'variables': {'artistId': id},
      'query':
          'mutation AddArtistToFavorite(\$artistId: String!) { addArtistToFavorite(artistId: \$artistId) { __typename favoritedAt artist { __typename id isFavorite isBannedFromRecommendation } } }'
    });

    if (data['data']?['addArtistToFavorite']?['artist']?['isFavorite'] ==
        true) {
      return true;
    }

    return false;
  }

  //Remove artist from favorites/library
  Future<bool> removeArtist(String id) async {
    Map data = await callPipeApi(params: {
      'operationName': 'RemoveArtistFromFavorite',
      'variables': {'artistId': id},
      'query':
          'mutation RemoveArtistFromFavorite(\$artistId: String!) { removeArtistFromFavorite(artistId: \$artistId) { __typename artist { __typename id isFavorite } } }'
    });

    if (data['data']?['removeArtistFromFavorite']?['artist']?['isFavorite'] ==
        false) {
      return true;
    }

    return false;
  }

  //Add tracks to playlist
  Future<bool> addToPlaylist(
    String trackId,
    String playlistId,
  ) async {
    Map data = await callPipeApi(params: {
      'operationName': 'AddTracksToPlaylist',
      'variables': {
        'input': {
          'playlistId': playlistId,
          'trackIds': [trackId]
        }
      },
      'query':
          'mutation AddTracksToPlaylist(\$input: PlaylistAddTracksMutationInput!) { addTracksToPlaylist(input: \$input) { __typename ... on PlaylistAddTracksOutput { addedTrackIds duplicatedTrackIds beyondLimitTrackIds playlist { __typename ...PlaylistOnTrackMutationFragment picture { __typename ...PictureFragment ...PictureMD5Fragment } } } ... on PlaylistAddTracksError { isNotAllowed } } }  fragment PlaylistOnTrackMutationFragment on Playlist { __typename id title estimatedDuration estimatedTracksCount lastModificationDate }  fragment PictureFragment on Picture { __typename id small: urls(pictureRequest: { height: 256 width: 256 } ) medium: urls(pictureRequest: { height: 750 width: 750 } ) large: urls(pictureRequest: { height: 1200 width: 1200 } ) copyright explicitStatus }  fragment PictureMD5Fragment on Picture { __typename id md5 explicitStatus }'
    });
    if (await downloadManager.checkOffline(
        playlist: Playlist(id: favoritesPlaylistId))) {
      downloadManager.updateOfflinePlaylist(Playlist(id: favoritesPlaylistId));
    }

    if (data['data']?['addTracksToPlaylist']?['addedTrackIds']?.isNotEmpty ==
        true) {
      return true;
    }

    return false;
  }

  //Remove track from playlist
  Future<bool> removeFromPlaylist(String trackId, String playlistId) async {
    Map data = await callPipeApi(
      params: {
        'operationName': 'RemoveTracksFromPlaylist',
        'variables': {
          'input': {
            'playlistId': playlistId,
            'trackIds': [trackId]
          }
        },
        'query':
            'mutation RemoveTracksFromPlaylist(\$input: PlaylistRemoveTracksMutationInput!) { removeTracksFromPlaylist(input: \$input) { __typename removedTrackIds playlist { __typename ...PlaylistOnTrackMutationFragment picture { __typename ...PictureFragment ...PictureMD5Fragment } } } }  fragment PlaylistOnTrackMutationFragment on Playlist { __typename id title estimatedDuration estimatedTracksCount lastModificationDate }  fragment PictureFragment on Picture { __typename id small: urls(pictureRequest: { height: 256 width: 256 } ) medium: urls(pictureRequest: { height: 750 width: 750 } ) large: urls(pictureRequest: { height: 1200 width: 1200 } ) copyright explicitStatus }  fragment PictureMD5Fragment on Picture { __typename id md5 explicitStatus }'
      },
    );

    if (data['data']?['removeTracksFromPlaylist']?['removedTrackIds']
        ?.isNotEmpty) {
      return true;
    }

    return false;
  }

  //Get homepage/music library from deezer
  Future<List<Playlist>> getUserGames() async {
    List grid = [
      'album',
      'artist',
      'channel',
      'flow',
      'playlist',
      'radio',
      'show',
      'smarttracklist',
      'track',
      'user'
    ];

    Uri uri = Uri.https('api.deezer.com', '/1.0/gateway.php', {
      'api_key': deezerGatewayAPI,
      'method': 'app_page_get',
      'gateway_input': jsonEncode(
        {
          'VERSION': '2.5',
          'LANG': settings.deezerLanguage,
          'SUPPORT': {
            'grid': grid,
            'horizontal-grid': grid,
            'filterable-grid': ['flow'],
            'item-highlight': ['radio'],
            'large-card': [
              'playlist',
              'video-link',
              'app',
              'album',
              'show',
              'artist'
            ],
            'highlight': [
              'generic',
              'playlist',
              'radio',
              'livestream',
              'album',
              'artist'
            ],
          },
          'page': 'channels/games',
        },
      ),
      'sid': keyBag.sid,
      'output': '3',
      'input': '3',
      'arl': keyBag.arl,
    });

    Map<String, String> gwHeaders = {
      'User-Agent': '',
      'Content-Type': 'text/plain;charset=UTF-8',
      'origin': 'https://www.deezer.com',
      'Cache-Control': 'max-age=0',
      'Accept': '*/*',
      'Accept-Charset': 'utf-8,ISO-8859-1;q=0.7,*;q=0.3',
      'Connection': 'keep-alive',
      'sec-fetch-site': 'same-origin',
      'sec-fetch-mode': 'same-origin',
      'sec-fetch-dest': 'empty',
      'referer': 'https://www.deezer.com/',
    };

    //Post
    http.Response res = await http.get(uri, headers: gwHeaders).catchError((e) {
      return http.Response('', 200);
    });

    dynamic body = jsonDecode(res.body);

    if (body['results'] == null) return [];

    List<dynamic>? sections = body['results']['sections'];
    List<Playlist> userQuizzes = [];

    for (int i = 0; i < (sections?.length ?? 0); i++) {
      List<dynamic> items = sections?[i]['items'];

      for (int j = 0; j < items.length; j++) {
        final regex = RegExp(r'^/game/blindtest/playlist/(\d+)');
        final match = regex.firstMatch(items[j]['target']);

        if (match != null) {
          Playlist target = await playlist(match.group(1) ?? '', nb: 0);
          userQuizzes.add(target);
        }
      }
    }
    return userQuizzes;
  }

  Future<List<Playlist>> getMusicQuizzes() async {
    List<Playlist> playlists = await getUserPlaylists(uId: '5207298602');
    return playlists;
  }

  //Get users playlists
  Future<List<Playlist>> getUserPlaylists({String? uId}) async {
    Map data = await callGwApi('playlist.getList',
        params: {'nb': '1000', 'start': '0', 'user_id': uId ?? userId});
    return (data['results']?['data'] ?? [])
        .map<Playlist>((json) => Playlist.fromPrivateJson(json, library: true))
        .toList();
  }

  //Get favorite playlists
  Future<List<Playlist>> getFavoritePlaylists() async {
    Map data = await callGwApi('playlist.getFavorites',
        params: {'nb': '1000', 'start': '0', 'user_id': userId});
    return (data['results']?['data'] ?? [])
        .map<Playlist>((json) => Playlist.fromPrivateJson(json, library: true))
        .toList();
  }

  //Get all playlists
  Future<List<Playlist>> getPlaylists() async {
    List<List<Playlist>> playlists =
        await Future.wait([getUserPlaylists(), getFavoritePlaylists()]);
    if (playlists.isEmpty) return [];
    if (playlists.length == 1) return playlists[0];

    return List.from(playlists[0])
      ..addAll(playlists[1])
      ..removeWhere((Playlist p) => p.id == cache.favoritesPlaylistId)
      ..sort((Playlist a, Playlist b) =>
          DateTime.parse(b.addedDate).compareTo(DateTime.parse(a.addedDate)));
  }

  //Get favorite trackIds
  Future<List<String>?> getFavoriteTrackIds() async {
    Map data =
        await callGwApi('user.getAllFeedbacks', params: {'checksums': null});
    final songsData = data['results']?['FAVORITES']?['SONGS']?['data'];

    if (songsData is List) {
      return songsData.map<String>((song) => song['SNG_ID'] as String).toList();
    }
    return null;
  }

  //Get favorite albums
  Future<List<Album>> getAlbums() async {
    Map data = await callGwApi('album.getFavorites',
        params: {'user_id': userId, 'start': 0, 'nb': 50});
    List albumList = data['results']?['data'] ?? [];
    List<Album> albums = albumList
        .map<Album>((json) => Album.fromPrivateJson(json, library: true))
        .toList();
    return albums;
  }

  //Remove album from library
  Future<bool> removeAlbum(String id) async {
    Map data = await callPipeApi(params: {
      'operationName': 'RemoveAlbumFromFavorite',
      'variables': {'albumId': id},
      'query':
          'mutation RemoveAlbumFromFavorite(\$albumId: String!) { removeAlbumFromFavorite(albumId: \$albumId) { __typename album { __typename id isFavorite } } }'
    });

    if (data['data']?['removeAlbumFromFavorite']?['album']?['isFavorite'] ==
        false) {
      return true;
    }

    return false;
  }

  //Remove track from favorites
  Future<bool> removeFavorite(String id) async {
    return removeFromPlaylist(id, cache.favoritesPlaylistId);
  }

  //Get favorite artists
  Future<List<Artist>> getArtists() async {
    Map data = await callGwApi('artist.getFavorites',
        params: {'user_id': userId, 'start': 0, 'nb': 40});
    return (data['results']?['data'] ?? [])
        .map<Artist>((json) => Artist.fromPrivateJson(json, library: true))
        .toList();
  }

  //Get lyrics by track id
  Future<LyricsFull> lyrics(Track track) async {
    for (String provider in settings.lyricsProviders) {
      if (provider == 'DEEZER') {
        // First try to get lyrics from pipe API
        Lyrics lyricsFromPipeApi = await lyricsFull(track.id ?? '');

        if (lyricsFromPipeApi.errorMessage == null &&
            lyricsFromPipeApi.isLoaded()) {
          lyricsFromPipeApi.provider = LyricsProvider.DEEZER;
          return lyricsFromPipeApi as LyricsFull;
        }

        // Fallback to get lyrics from legacy GW api
        Lyrics lyricsFromLegacy = await lyricsLegacy(track.id ?? '');

        if (lyricsFromLegacy.errorMessage == null &&
            lyricsFromLegacy.isLoaded()) {
          lyricsFromLegacy.provider = LyricsProvider.DEEZER;
          return lyricsFromLegacy as LyricsFull;
        }
      } else if (provider == 'LRCLIB') {
        http.Response res = http.Response('', 404);

        if (settings.advancedLRCLib) {
          res = await http.get(Uri.parse(
              'https://lrclib.net/api/get?artist_name=${(track.artists?[0].name ?? '')}&track_name=${(track.title ?? '')}&duration=${track.duration.inSeconds.toString()}'));
          if (res.statusCode == 404) {
            String isrc = await getTrackIsrc(track.id ?? '');
            Map<String, dynamic> trackData = await deezerAPI
                .callPublicApi('track/isrc:$isrc') as Map<String, dynamic>;
            if (trackData == {}) {
              Logger.root.info(
                  'ISRC fetch failed for track ${track.id}. Reverting to simple LRCLib fetch.');
              res = await http.get(Uri.parse(
                  'https://lrclib.net/api/get?artist_name=' +
                      (track.artists?[0].name ?? '') +
                      '&track_name=' +
                      (track.title ?? '')));
            } else {
              res = await http.get(Uri.parse(
                  'https://lrclib.net/api/get?artist_name=${(trackData['artist']?['name'] ?? '')}&track_name=${(trackData['title_short'] ?? trackData['title'] ?? '')}&album_name=${(trackData['album']?['title'] ?? '')}&duration=${(trackData['duration'].toString())}'));
              if (res.statusCode == 404) {
                res = await http.get(Uri.parse(
                    'https://lrclib.net/api/get?artist_name=${(trackData['artist']?['name'] ?? '')}&track_name=${(trackData['title_short'] ?? trackData['title'] ?? '')}&duration=${(trackData['duration'].toString())}'));
                if (res.statusCode == 404) {
                  res = await http.get(Uri.parse(
                      'https://lrclib.net/api/get?artist_name=${(trackData['artist']?['name'] ?? '')}&track_name=${(trackData['title_short'] ?? trackData['title'] ?? '')}'));
                  if (res.statusCode == 404) {
                    Logger.root.info(
                        'Advanced LRCLib api fetch failed for ${track.id}.');
                  }
                } else {
                  Logger.root.info(
                      'Got results for ${track.id} wit title, artist and duration.');
                }
              } else {
                Logger.root.info(
                    'Got results for ${track.id} wit title, artist, album and duration.');
              }
            }
          } else {
            Logger.root.info('Got immediate results for track ${track.id}.');
          }
        } else {
          res = await http.get(Uri.parse(
              'https://lrclib.net/api/get?artist_name=' +
                  (track.artists?[0].name ?? '') +
                  '&track_name=' +
                  (track.title ?? '')));
        }

        if (res.statusCode != 404) {
          Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
          List<SynchronizedLyric> synchronizedLyrics = [];

          if (data['syncedLyrics'] != null) {
            List<String> synchronizedLines = (data['syncedLyrics']).split('\n');
            for (int i = 0; i < synchronizedLines.length; i++) {
              List<String> line = synchronizedLines[i].split(' ');
              List<String> offset = line
                  .removeAt(0)
                  .replaceAll('[', '')
                  .replaceAll(']', '')
                  .split(':');
              String lyric = line.join(' ');
              synchronizedLyrics.add(
                SynchronizedLyric(
                    offset: Duration(
                        minutes: int.parse(offset.first),
                        milliseconds:
                            (double.parse(offset.last) * 1000).round()),
                    text: lyric),
              );
            }
          }

          LyricsFull lrclyrics = LyricsFull(
            id: data['id'].toString(),
            syncedLyrics:
                synchronizedLyrics.isNotEmpty ? synchronizedLyrics : null,
            unsyncedLyrics: data['plainLyrics'],
            provider: LyricsProvider.LRCLIB,
            isExplicit: track.explicit,
          );

          return lrclyrics;
        }
      } else if (provider == 'LYRICFIND') {
/*
        if (settings.lyricfindKey != null) {
          http.Response res = await http.get(Uri.parse(
              'https://api.lyricfind.com/lyric.do?apikey=${settings.lyricfindKey}&territory=${settings.deezerCountry}&lrckey=&reqtype=default&trackid=isrc:&format=lrconly,clean&output=json' +
                  (track.artists?[0].name ?? '') +
                  '&track_name=' +
                  (track.title ?? '')));
          Map<String, dynamic> data = jsonDecode(res.body);

          return LyricsFull(
            id: data['id'],
            syncedLyrics: data['syncedLyrics'],
            unsyncedLyrics: data['plainLyrics'],
            provider: LyricsProvider.LYRICFIND,
          );
        }
*/
      }
    }

    // No lyrics found, prefer to use pipe api error message
    //return lyricsFromPipeApi;
    return LyricsFull();
  }

  //Get lyrics by track id from legacy GW api
  Future<Lyrics> lyricsLegacy(String trackId) async {
    Map data = await callGwApi('song.getLyrics', params: {'sng_id': trackId});
    if (data['error'] != null && data['error'].length > 0) {
      return Lyrics.error(data['error']['DATA_ERROR']);
    }
    return LyricsClassic.fromPrivateJson(data['results']);
  }

  //Get lyrics by track id from pipe API
  Future<Lyrics> lyricsFull(String trackId) async {
    // Create lyrics request body with GraphQL query
    String queryStringGraphQL = '''
      query SynchronizedTrackLyrics(\$trackId: String!) {
        track(trackId: \$trackId) {
          id
          isExplicit
          lyrics {
            id
            copyright
            text
            writers
            synchronizedLines {
              lrcTimestamp
              line
              milliseconds
              duration
            }
          }
        }
      }''';

    /* Alternative query using fragments, used by Deezer web app
    String queryStringGraphQL = '''
      query SynchronizedTrackLyrics(\$trackId: String!) {
        track(trackId: \$trackId) {
          ...SynchronizedTrackLyrics
        }
      }
      fragment SynchronizedTrackLyrics on Track {
        id
        isExplicit
        lyrics {
          ...Lyrics
        }
      }
      fragment Lyrics on Lyrics {
        id
        copyright
        text
        writers
        synchronizedLines {
          ...LyricsSynchronizedLines
        }
      }
      fragment LyricsSynchronizedLines on LyricsSynchronizedLine {
        lrcTimestamp
        line
        milliseconds
        duration
      }
      ''';
    */

    Map<String, dynamic> requestParams = {
      'operationName': 'SynchronizedTrackLyrics',
      'variables': {'trackId': trackId},
      'query': queryStringGraphQL
    };
    Map data = await callPipeApi(params: requestParams);

    if (data['errors'] != null && data['errors'].length > 0) {
      return Lyrics.error('err');
    }
    return LyricsFull.fromPrivateJson(data['data']);
  }

  Future<List<Track>?> userTracks({int? limit}) async {
    Map data = await callGwApi('charts.getUserSongs', params: {
      'USER_ID': userId,
      'START': '0',
      'NB': (limit ?? 100).toString()
    });
    if (data['results']['data'] == null) return [];

    return data['results']['data']
        .map<Track>((json) => Track.fromPrivateJson(json))
        .toList();
  }

  Future<SmartTrackList?> smartTrackList(String id) async {
    Map data = await callGwApi('mobile.pageSmartTracklist',
        params: {'SMARTTRACKLIST_ID': id});
    if (data['results']['DATA'] == null) {
      return null;
    }
    return SmartTrackList.fromPrivateJson(data['results']['DATA'],
        songsJson: data['results']['SONGS']);
  }

  Future<List<Track>> flow({String? type}) async {
    Map data = await callGwApi('radio.getUserRadio',
        params: {'user_id': userId, 'config_id': type});
    return data['results']['data']
        .map<Track>((json) => Track.fromPrivateJson(json))
        .toList();
  }

  //Get homepage/music library from deezer
  Future<HomePage> homePage() async {
    List grid = [
      'album',
      'artist',
      'channel',
      'flow',
      'playlist',
      'radio',
      'show',
      'smarttracklist',
      'track',
      'user'
    ];

    Uri uri = Uri.https('api.deezer.com', '/1.0/gateway.php', {
      'api_key': deezerGatewayAPI,
      'method': 'app_page_get',
      'gateway_input': jsonEncode(
        {
          'VERSION': '2.5',
          'LANG': settings.deezerLanguage,
          'SUPPORT': {
            'grid': grid,
            'horizontal-grid': grid,
            'filterable-grid': ['flow'],
            'item-highlight': ['radio'],
            'large-card': [
              'playlist',
              'video-link',
              'app',
              'album',
              'show',
              'artist'
            ],
            'highlight': [
              'generic',
              'playlist',
              'radio',
              'livestream',
              'album',
              'artist'
            ],
          },
          'page': 'home',
        },
      ),
      'sid': keyBag.sid,
      'output': '3',
      'input': '3',
      'arl': keyBag.arl,
    });

    Map<String, String> gwHeaders = {
      'User-Agent': '',
      'Content-Type': 'text/plain;charset=UTF-8',
      'origin': 'https://www.deezer.com',
      'Cache-Control': 'max-age=0',
      'Accept': '*/*',
      'Accept-Charset': 'utf-8,ISO-8859-1;q=0.7,*;q=0.3',
      'Connection': 'keep-alive',
      'sec-fetch-site': 'same-origin',
      'sec-fetch-mode': 'same-origin',
      'sec-fetch-dest': 'empty',
      'referer': 'https://www.deezer.com/',
    };

    //Post
    http.Response res = await http.get(uri, headers: gwHeaders).catchError((e) {
      return http.Response('', 200);
    });

    dynamic body = jsonDecode(res.body);

    return HomePage.fromPrivateJson(body['results']);
  }

  //Log song listen to deezer
  Future logListen(String trackId) async {
    await callGwApi('log.listen', params: {
      'params': {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ts_listen': DateTime.now().millisecondsSinceEpoch,
        'type': 1,
        'stat': {'seek': 0, 'pause': 0, 'sync': 1},
        'media': {'id': trackId, 'type': 'song', 'format': 'MP3_128'}
      }
    });
  }

  Future<HomePage> getChannel(String target) async {
    List grid = [
      'album',
      'artist',
      'channel',
      'flow',
      'playlist',
      'radio',
      'show',
      'smarttracklist',
      'track',
      'user'
    ];

    Uri uri = Uri.https('api.deezer.com', '/1.0/gateway.php', {
      'api_key': deezerGatewayAPI,
      'method': 'app_page_get',
      'gateway_input': jsonEncode(
        {
          'VERSION': '2.5',
          'LANG': settings.deezerLanguage,
          'SUPPORT': {
            'filterable-grid': ['flow'],
            'grid': grid,
            'horizontal-grid': grid,
            'item-highlight': ['radio'],
            'large-card': ['album', 'playlist', 'show', 'video-link'],
            'ads': []
          },
          'page': target,
        },
      ),
      'sid': keyBag.sid,
      'output': '3',
      'input': '3',
      'arl': keyBag.arl,
    });

    Map<String, String> gwHeaders = {
      'User-Agent': '',
      'Content-Type': 'text/plain;charset=UTF-8',
      'origin': 'https://www.deezer.com',
      'Cache-Control': 'max-age=0',
      'Accept': '*/*',
      'Accept-Charset': 'utf-8,ISO-8859-1;q=0.7,*;q=0.3',
      'Connection': 'keep-alive',
      'sec-fetch-site': 'same-origin',
      'sec-fetch-mode': 'same-origin',
      'sec-fetch-dest': 'empty',
      'referer': 'https://www.deezer.com/',
    };

    //Post
    http.Response res = await http.get(uri, headers: gwHeaders).catchError((e) {
      return http.Response('', 200);
    });

    dynamic body = jsonDecode(res.body);

    return HomePage.fromPrivateJson(body['results']);
  }

  //Add playlist to library
  Future<bool> addPlaylist(String id) async {
    Map data = await callPipeApi(params: {
      'operationName': 'AddPlaylistToFavorite',
      'variables': {'playlistId': id},
      'query':
          'mutation AddPlaylistToFavorite(\$playlistId: String!) { addPlaylistToFavorite(playlistId: \$playlistId) { __typename favoritedAt playlist { __typename id isFavorite } } }'
    });

    if (data['data']?['addPlaylistToFavorite']?['playlist']?['isFavorite'] ==
        true) {
      return true;
    }

    return false;
  }

  //Remove playlist from library
  Future<bool> removePlaylist(String id) async {
    Map data = await callPipeApi(params: {
      'operationName': 'RemovePlaylistFromFavorite',
      'variables': {'playlistId': id},
      'query':
          'mutation RemovePlaylistFromFavorite(\$playlistId: String!) { removePlaylistFromFavorite(playlistId: \$playlistId) { __typename playlist { __typename id isFavorite } } }'
    });

    if (data['data']?['removePlaylistFromFavorite']?['playlist']
            ?['isFavorite'] ==
        false) {
      return true;
    }

    return false;
  }

  //Delete playlist
  Future deletePlaylist(String id) async {
    await callPipeApi(params: {
      'operationName': 'DeletePlaylist',
      'variables': {
        'input': {'playlistId': id}
      },
      'query':
          'mutation DeletePlaylist(\$input: PlaylistDeleteMutationInput!) { deletePlaylist(input: \$input) { __typename deleteStatus } }'
    });
  }

  Future<String> imageUpload({
    required List<int> imageData,
    String uploadPath = '/v2/playlist/picture',
  }) async {
    String jwtToken = await getJsonWebToken();
    Map<String, String> uploadApiHeaders = headers;
    // Add jwt token to headers
    uploadApiHeaders['Authorization'] = 'Bearer $jwtToken';

    Uri uri = Uri.https('upload.deezer.com', uploadPath);
    //Post

    http.MultipartFile imageFile = http.MultipartFile.fromBytes(
      'file',
      imageData,
      filename: 'playlist_cover.png',
    );

    http.MultipartRequest request = http.MultipartRequest('POST', uri)
      ..files.add(imageFile)
      ..headers.addAll(uploadApiHeaders);
    http.StreamedResponse streamedRes = await request.send();
    http.Response res = await http.Response.fromStream(streamedRes);

    dynamic body = jsonDecode(res.body);

    return body['results']?.toString() ?? '';
  }

  //Create playlist
  //Status 1 - private, 2 - collaborative
  Future<String> createPlaylist(
      {required String title,
      bool isPrivate = true,
      bool isCollaborative = false,
      List<int>? pictureData,
      List<String> trackIds = const []}) async {
    String? imageRef;

    if (pictureData?.isNotEmpty ?? false) {
      imageRef = await imageUpload(
          imageData: pictureData!, uploadPath: '/v2/playlist/picture');
    }

    Logger.root.info(imageRef);

    Map data = await callPipeApi(
      params: {
        'operationName': 'CreatePlaylist',
        'variables': {
          'input': {
            'title': title,
            'isPrivate': isPrivate,
            'isCollaborative': isCollaborative,
            'picture': imageRef,
          }
        },
        'query':
            'mutation CreatePlaylist(\$input: PlaylistCreateMutationInput!) { createPlaylist(input: \$input) { __typename playlist { __typename ...PlaylistDetailFragment mostPopularTrack { __typename ...TrackMinimalFragment } owner { __typename ...UserMinimalFragment picture { __typename ...PictureMD5Fragment } } linkedArtist { __typename ...ArtistMinimalFragment picture { __typename ...PictureMD5Fragment } } picture { __typename ...PictureFragment ...PictureMD5Fragment } } } }  fragment PlaylistDetailFragment on Playlist { __typename id title description estimatedDuration estimatedTracksCount lastModificationDate playlistIsFavorite: isFavorite isFromFavoriteTracks isBlindTestable isCharts isCollaborative isEditorialized isPrivate fansCount }  fragment TrackMinimalFragment on Track { __typename id title }  fragment UserMinimalFragment on User { __typename id name }  fragment PictureMD5Fragment on Picture { __typename id md5 explicitStatus }  fragment ArtistMinimalFragment on Artist { __typename id name }  fragment PictureFragment on Picture { __typename id small: urls(pictureRequest: { height: 256 width: 256 } ) medium: urls(pictureRequest: { height: 750 width: 750 } ) large: urls(pictureRequest: { height: 1200 width: 1200 } ) copyright explicitStatus }'
      },
    );

    if (trackIds.isNotEmpty &&
        data['data']?['createPlaylist']?['playlist']?['id'] != null) {
      Map addTracksData = await callPipeApi(params: {
        'operationName': 'AddTracksToPlaylist',
        'variables': {
          'input': {
            'playlistId': data['data']['createPlaylist']['playlist']['id'],
            'trackIds': trackIds
          }
        },
        'query':
            'mutation AddTracksToPlaylist(\$input: PlaylistAddTracksMutationInput!) { addTracksToPlaylist(input: \$input) { __typename ... on PlaylistAddTracksOutput { addedTrackIds duplicatedTrackIds beyondLimitTrackIds playlist { __typename ...PlaylistOnTrackMutationFragment picture { __typename ...PictureFragment ...PictureMD5Fragment } } } ... on PlaylistAddTracksError { isNotAllowed } } }  fragment PlaylistOnTrackMutationFragment on Playlist { __typename id title estimatedDuration estimatedTracksCount lastModificationDate }  fragment PictureFragment on Picture { __typename id small: urls(pictureRequest: { height: 256 width: 256 } ) medium: urls(pictureRequest: { height: 750 width: 750 } ) large: urls(pictureRequest: { height: 1200 width: 1200 } ) copyright explicitStatus }  fragment PictureMD5Fragment on Picture { __typename id md5 explicitStatus }'
      });
      return addTracksData['data']?['addTracksToPlaylist']?['playlist']?['id']
              ?.toString() ??
          '';
    }
    //Return playlistId
    return data['data']?['createPlaylist']?['playlist']?['id']?.toString() ??
        '';
  }

  Future<String> updatePlaylist({
    required String playlistId,
    String? title,
    bool isPrivate = true,
    bool isCollaborative = false,
    List<int>? pictureData,
  }) async {
    String? imageRef;

    if (pictureData?.isNotEmpty ?? false) {
      imageRef = await imageUpload(
          imageData: pictureData!, uploadPath: '/v2/playlist/picture');
    }

    Map data = await callPipeApi(
      params: {
        'operationName': 'UpdatePlaylist',
        'variables': {
          'input': {
            'playlistId': playlistId,
            'title': title,
            'isCollaborative': isCollaborative,
            'isPrivate': isPrivate,
            'picture': imageRef,
          }
        },
        'query':
            'mutation UpdatePlaylist(\$input: PlaylistUpdateMutationInput!) { updatePlaylist(input: \$input) { __typename playlist { __typename ...PlaylistDetailFragment mostPopularTrack { __typename ...TrackMinimalFragment } owner { __typename ...UserMinimalFragment picture { __typename ...PictureMD5Fragment } } linkedArtist { __typename ...ArtistMinimalFragment picture { __typename ...PictureMD5Fragment } } picture { __typename ...PictureFragment ...PictureMD5Fragment } } } }  fragment PlaylistDetailFragment on Playlist { __typename id title description estimatedDuration estimatedTracksCount lastModificationDate playlistIsFavorite: isFavorite isFromFavoriteTracks isBlindTestable isCharts isCollaborative isEditorialized isPrivate fansCount }  fragment TrackMinimalFragment on Track { __typename id title }  fragment UserMinimalFragment on User { __typename id name }  fragment PictureMD5Fragment on Picture { __typename id md5 explicitStatus }  fragment ArtistMinimalFragment on Artist { __typename id name }  fragment PictureFragment on Picture { __typename id small: urls(pictureRequest: { height: 256 width: 256 } ) medium: urls(pictureRequest: { height: 750 width: 750 } ) large: urls(pictureRequest: { height: 1200 width: 1200 } ) copyright explicitStatus }'
      },
    );

    //Return playlistId
    return data['data']?['updatePlaylist']?['playlist']?['id']?.toString() ??
        '';
  }

  //Get part of discography
  Future<List<Album>> discographyPage(String artistId,
      {int start = 0, int nb = 50}) async {
    Map albumRawIds = await callPipeApi(params: {
      'operationName': 'GetArtistRawDiscography',
      'variables': {
        'artistId': artistId,
        'albumTypes': ['ALBUM', 'EP', 'SINGLES'],
        'mode': 'OFFICIAL',
        'roles': ['MAIN'],
        'order': 'NONE',
        'onlyCanonical': true
      },
      'query':
          'query GetArtistRawDiscography(\$artistId: String!, \$albumTypes: [AlbumTypeInput!]!, \$mode: DiscographyMode!, \$roles: [ContributorRoles!]!, \$order: AlbumOrder!, \$onlyCanonical: Boolean!) { artist(artistId: \$artistId) { __typename id rawAlbums(types: \$albumTypes, mode: \$mode, order: \$order, roles: \$roles, onlyCanonical: \$onlyCanonical) { __typename albumId } } }'
    });

    List<String> albumIds = List.generate(
        albumRawIds['data']?['artist']?['rawAlbums'].length ?? 0,
        (int i) =>
            albumRawIds['data']?['artist']?['rawAlbums']?[i]?['albumId']);

    if (start >= albumIds.length) {
      albumIds = [];
    } else if (nb + start > albumIds.length) {
      albumIds = albumIds.skip(start).take(albumIds.length - start).toList();
    } else {
      albumIds = albumIds.skip(start).take(nb).toList();
    }

    if (albumIds.isEmpty) {
      return [];
    }

    Map rawAlbums = await callPipeApi(params: {
      'operationName': 'GetAlbumsCollectionByIdsWithSubtypes',
      'variables': {
        'ids': albumIds,
      },
      'query':
          'query GetAlbumsCollectionByIdsWithSubtypes(\$ids: [String!]!) { albumsByIds(ids: \$ids) { __typename ...AlbumCollectionFragment subtypes { __typename ...AlbumSubtypeFragment } cover { __typename ...PictureMD5Fragment } contributors(first: 1) { __typename edges { __typename roles node { __typename ...ArtistMinimalFragment } } } } }  fragment AlbumCollectionFragment on Album { __typename id displayTitle type albumReleaseDate: releaseDate albumIsExplicit: isExplicit albumIsFavorite: isFavorite tracksCount rank }  fragment AlbumSubtypeFragment on AlbumSubtype { __typename isStudio isLive isCompilation isKaraoke }  fragment PictureMD5Fragment on Picture { __typename id md5 explicitStatus }  fragment ArtistMinimalFragment on Artist { __typename id name }'
    });

    return rawAlbums['data']['albumsByIds']
        .map<Album>((a) => Album.fromPipeJson(a))
        .toList();
  }

  //Get smart radio for artist id
  Future<List<Track>> smartRadio(String artistId) async {
    Map data = await callGwApi('radio_getChannel', params: {
      'context': 'artist_smartradio',
      'context_id': artistId,
      'sng_id': '',
      'NB': '6'
    });

    if (data['results']?['data'] == null) return [];

    return data['results']?['data']
        .map<Track>((t) => Track.fromPrivateJson(t))
        .toList();
  }

  //Get shuffled library
  Future<List<Track>> libraryShuffle({int start = 0}) async {
    Map data = await callGwApi('tracklist.getShuffledCollection',
        params: {'nb': 50, 'start': start});
    return data['results']['data']
        .map<Track>((t) => Track.fromPrivateJson(t))
        .toList();
  }

  //Get similar tracks for track with id [trackId]
  Future<List<Track>> playMix(String trackId) async {
    Map data = await callGwApi('song.getSearchTrackMix',
        params: {'sng_id': trackId, 'start_with_input_track': 'true'});
    return data['results']['data']
        .map<Track>((t) => Track.fromPrivateJson(t))
        .toList();
  }

  Future<Show> show(String showId, {int page = 0, int nb = 1000}) async {
    Map<String, dynamic> data = await callGwApi('mobile.pageShow', params: {
      'SHOW_ID': showId,
      'START': page * nb,
      'NB': nb,
      'LANG': settings.deezerLanguage
    });
    if (data['results']?['DATA'] == null) return Show();
    Show show = Show.fromPrivateJson(
      data['results']['DATA'],
      epsJson: data['results']['EPISODES'],
      isFavorite: data['results']['FAVORITE_STATUS'],
    );
    return show;
  }

  //Add show to library
  Future<bool> addShow(String id) async {
    Map data = await callPipeApi(params: {
      'operationName': 'AddPodcastToFavorite',
      'variables': {'podcastId': id},
      'query':
          'mutation AddPodcastToFavorite(\$podcastId: String!) { addPodcastToFavorite(podcastId: \$podcastId) { __typename favoritedAt podcast { __typename id isFavorite } } }'
    });

    if (data['data']?['addPodcastToFavorite']?['podcast']?['isFavorite'] ==
        true) {
      return true;
    }

    return false;
  }

  //Add show to library
  Future<bool> removeShow(String id) async {
    Map data = await callPipeApi(params: {
      'operationName': 'RemovePodcastFromFavorite',
      'variables': {'podcastId': id},
      'query':
          'mutation RemovePodcastFromFavorite(\$podcastId: String!) { removePodcastFromFavorite(podcastId: \$podcastId) { __typename podcast { __typename id isFavorite } } }'
    });

    if (data['data']?['removePodcastFromFavorite']?['podcast']?['isFavorite'] ==
        false) {
      return true;
    }

    return false;
  }

  Future<List<HomePageSection>> getUserSearchPage() async {
    Map<String, dynamic> data = await callGwApi('search_getSearchHomeChannels');
    if (data['results'] == null ||
        data['results']['data'] == null ||
        data['results']['data'] is! List) {
      return [];
    }

    List<dynamic> rawSections = (data['results']['data'] as List<dynamic>)
        .where((dynamic candidate) => candidate['data']?.isNotEmpty)
        .toList();

    List<HomePageSection> sections = List.generate(
        rawSections.length,
        (int index) => HomePageSection(
            title: rawSections[index]?['title'],
            type: HomePageSectionType.OTHER,
            items: List.generate(
                rawSections[index]['data'].length,
                (int jndex) => HomePageItem.fromPrivateJson(
                    rawSections[index]['data'][jndex]))));

    return sections;
  }

  Future<List<String>> getShowNotificationIds() async {
    Map<String, dynamic> data = await callGwApi('shownotification_getIds');
    if (data['results'] == null ||
        data['results']['data'] == null ||
        data['results']['data'] is! List) {
      return [];
    }

    List<dynamic> dataList = data['results']['data'];

    return dataList
        .map<String>((item) {
          if (item != null && item['SHOW_ID'] != null) {
            return item['SHOW_ID'].toString();
          } else {
            return '';
          }
        })
        .where((id) => id != '')
        .toList();
  }

  Future<bool> subscribeShow(String id) async {
    Map data =
        await callGwApi('shownotification_subscribe', params: {'SHOW_ID': id});

    if (data['results'] == true) {
      return true;
    }

    return false;
  }

  Future<bool> unSubscribeShow(String id) async {
    Map data = await callGwApi('shownotification_unsubscribe',
        params: {'SHOW_ID': id});

    if (data['results'] == true) {
      return true;
    }

    return false;
  }

  Future<ShowEpisode> showEpisode(String episodeId) async {
    Map<String, dynamic> data =
        await callGwApi('episode.getData', params: {'episode_id': episodeId});
    if (data['results'] == null) {
      return ShowEpisode();
    }
    return ShowEpisode.fromPrivateJson(data['results']);
  }

  Future<List<Show>> getUserShows() async {
    Map<String, dynamic> data = await callGwApi('show.getFavorites', params: {
      'USER_ID': userId,
      'START': 0,
      'NB': 10000,
    });

    if (data['results']?['data'] == null) return [];

    return data['results']?['data']
        .map<Show>((e) => Show.fromPrivateJson(e))
        .toList();
  }
}

void openScreenByURL(String url) async {
  DeezerLinkResponse? res = await deezerAPI.parseLink(url);

  if (res == null || res.type == null) return;

  switch (res.type!) {
    case DeezerLinkType.TRACK:
      Track t = await deezerAPI.track(res.id!);
      MenuSheet()
          .defaultTrackMenu(t, context: mainNavigatorKey.currentContext!);
      break;
    case DeezerLinkType.ALBUM:
      Album a = await deezerAPI.album(res.id!);
      mainNavigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (context) => AlbumDetails(a)));
      break;
    case DeezerLinkType.ARTIST:
      Artist a = await deezerAPI.artist(res.id!);
      mainNavigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (context) => ArtistDetails(a)));
      break;
    case DeezerLinkType.PLAYLIST:
      Playlist p = await deezerAPI.playlist(res.id!);
      mainNavigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (context) => PlaylistDetails(p)));
      break;
    case DeezerLinkType.GAME:
      return;
  }
}
