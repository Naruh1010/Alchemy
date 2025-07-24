import 'package:alchemy/api/cache.dart';
import 'package:alchemy/api/deezer.dart';
import 'package:alchemy/api/definitions.dart';
import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:alchemy/main.dart';
import 'package:alchemy/settings.dart';
import 'package:alchemy/translations.i18n.dart';
import 'package:alchemy/ui/cached_image.dart';
import 'package:alchemy/ui/downloads_screen.dart';
import 'package:alchemy/ui/elements.dart';
import 'package:alchemy/ui/library.dart';
import 'package:alchemy/ui/settings_screen.dart';
import 'package:alchemy/utils/connectivity.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  Color? gradientColor = cache.userColor != null
      ? Color(cache.userColor ?? 0)
      : null;
  String? userEmail = cache.userEmail;
  String? userName = cache.userName;
  ImageDetails? userPicture = ImageDetails.fromJson(cache.userPicture);

  Future<void> _load() async {
    if (await isConnected()) {
      User? u = await deezerAPI.getUser(deezerAPI.userId);
      if (mounted) {
        setState(() {
          //userEmail = u.email;
          userName = u?.name ?? userName;
          userPicture = u?.image ?? userPicture;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: RefreshIndicator(
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: MediaQuery.of(context).size.width,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top * 1.5,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gradientColor ?? Theme.of(context).scaffoldBackgroundColor,
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          color: Theme.of(context).scaffoldBackgroundColor,
                          spreadRadius: 5,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: MediaQuery.of(context).size.height / 8,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                gradientColor ?? Theme.of(context).primaryColor,
                            width: 3.0,
                          ),
                        ),
                        child: Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(shape: BoxShape.circle),
                          child: CachedImage(url: userPicture?.fullUrl ?? ''),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).size.height * 0.01,
                    ),
                    child: Text(
                      userName ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      userEmail ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w300,
                        color: Theme.of(context).secondaryHeaderColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.width * 0.05),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
              ),
              leading: Icon(AlchemyIcons.pen),
              title: Text('Edit profile'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => UpdateUserScreen()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
              ),
              leading: Icon(AlchemyIcons.settings),
              title: Text('Access settings'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              },
            ),
            FreezerDivider(),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
              ),
              leading: Icon(AlchemyIcons.double_note),
              title: Text('Your tracks'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => LibraryTracks()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
              ),
              leading: Icon(AlchemyIcons.podcast),
              title: Text('Your podcasts'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (context) => LibraryShows()));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
              ),
              leading: Icon(AlchemyIcons.arrow_time),
              title: Text('Your history'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => HistoryScreen()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
              ),
              leading: Icon(AlchemyIcons.download),
              title: Text('Your downloads'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => DownloadsScreen()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
              ),
              leading: Icon(AlchemyIcons.book),
              title: Text('Your playlists'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => LibraryPlaylists()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
              ),
              leading: Icon(AlchemyIcons.album),
              title: Text('Your albums'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => LibraryAlbums()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
              ),
              leading: Icon(AlchemyIcons.human_circle),
              title: Text('Your artists'),
              trailing: Icon(AlchemyIcons.chevron_end),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => LibraryArtists()),
                );
              },
            ),
            ListenableBuilder(
              listenable: playerBarState,
              builder: (BuildContext context, Widget? child) {
                return AnimatedPadding(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.only(
                    bottom: playerBarState.state ? 80 : 0,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class UpdateUserScreen extends StatefulWidget {
  const UpdateUserScreen({super.key});

  @override
  _UpdateUserScreenState createState() => _UpdateUserScreenState();
}

class _UpdateUserScreenState extends State<UpdateUserScreen> {
  String _name = '';
  String _email = '';
  String _sex = '';
  DateTime birthDay = DateTime.now();
  ImageDetails _picture = ImageDetails();
  TextEditingController? _nameController;
  TextEditingController? _emailController;
  List<int>? _imageBytes;
  bool _isLoading = false;
  bool _nameHasFocus = false;
  bool _emailHasFocus = false;
  bool _emptyName = false;
  bool _emptyEmail = false;

  final FocusNode _keyboardListenerFocusNode = FocusNode();
  final FocusNode _nameFieldFocusNode = FocusNode();
  final FocusNode _emailFieldFocusNode = FocusNode();

  Future<void> _load() async {
    Map<String, dynamic> data = await deezerAPI.callGwLightApi(
      'deezer.getUserData',
    );
    if (mounted) {
      setState(() {
        cache.userName = data['results']['USER']['BLOG_NAME'] ?? '';
        cache.userPicture = ImageDetails.fromPrivateString(
          data['results']['USER']['USER_PICTURE'],
          type: 'user',
        ).toJson();
        cache.userEmail = data['results']['USER']['EMAIL'];
        cache.userSex = data['results']['USER']['USER_GENDER'];
        _name = data['results']['USER']['BLOG_NAME'] ?? '';
        _picture = ImageDetails.fromPrivateString(
          data['results']['USER']['USER_PICTURE'],
          type: 'user',
        );
        _email = data['results']['USER']['EMAIL'];
        _sex = data['results']['USER']['USER_GENDER'];
        cache.save();
      });
    }
  }

  @override
  void initState() {
    if (mounted) {
      setState(() {
        _name = cache.userName;
        _email = cache.userEmail;
        _picture = ImageDetails.fromJson(cache.userPicture);
      });
    }
    _load();

    _nameController = TextEditingController(text: _name);
    _emailController = TextEditingController(text: _email);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar(
        'Edit your profile'.i18n,
        actions: [
          TextButton(
            onPressed: () async {
              if (_name == '') {
                Fluttertoast.showToast(
                  msg: "The username can't be empty.".i18n,
                );
                if (mounted) {
                  setState(() {
                    _emptyName = true;
                  });
                }
                return;
              }
              if (_email == '') {
                Fluttertoast.showToast(msg: "The email can't be empty.".i18n);
                if (mounted) {
                  setState(() {
                    _emptyEmail = true;
                  });
                }
                return;
              }
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _keyboardListenerFocusNode.unfocus();
                  _nameFieldFocusNode.unfocus();
                  _emailFieldFocusNode.unfocus();
                });
              }

              if (_imageBytes?.isNotEmpty ?? false) {
                String? s = await deezerAPI.profilePictureUpload(
                  imageData: _imageBytes!,
                );
                if (s != '' && mounted) {
                  setState(() {
                    _picture = ImageDetails.fromPrivateString(s, type: 'user');
                    cache.userPicture = _picture.toJson();
                    cache.save();
                  });
                }
              }

              if (_name != cache.userName) {
                await deezerAPI.updateUser(name: _name);
                _load();
              }
              if (_email != cache.userEmail) {}
              if (_sex != cache.userSex) {
                await deezerAPI.updateUser(sex: _sex);
                _load();
              }

              //Update

              Fluttertoast.showToast(
                msg: 'Profile updated!'.i18n,
                gravity: ToastGravity.BOTTOM,
              );

              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
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
                              : CachedImage(
                                  url: _picture.fullUrl ?? '',
                                  width: 160,
                                  height: 160,
                                ),
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
                            List<int>? imageData = await imageFile
                                .readAsBytes();
                            if (mounted) {
                              setState(() {
                                _imageBytes = imageData;
                              });
                            }
                          },
                          icon: Icon(AlchemyIcons.pen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Username'.i18n,
                  style: TextStyle(color: Settings.secondaryText),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
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
                              _nameFieldFocusNode.unfocus();
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
                              side: _emptyName
                                  ? BorderSide(
                                      color: Colors.redAccent,
                                      width: 1.5,
                                    )
                                  : _nameHasFocus
                                  ? BorderSide(
                                      color: settings.theme == Themes.Light
                                          ? Colors.black.withAlpha(100)
                                          : Colors.white.withAlpha(100),
                                      width: 1.5,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          child: Focus(
                            onFocusChange: (focused) {
                              setState(() {
                                _nameHasFocus = focused;
                              });
                            },
                            focusNode: _nameFieldFocusNode,
                            child: TextField(
                              onChanged: (String s) {
                                if (mounted && s != '') {
                                  setState(() {
                                    _emptyName = false;
                                    _name = s;
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Username',
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
                                  horizontal: 10.0,
                                ), // Added contentPadding
                              ),
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (String s) {},
                              style: TextStyle(
                                color: settings.theme == Themes.Light
                                    ? Colors.black
                                    : Colors.white,
                              ),
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
                  'Email'.i18n,
                  style: TextStyle(color: Settings.secondaryText),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
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
                              _emailFieldFocusNode.unfocus();
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
                              side: _emptyEmail
                                  ? BorderSide(
                                      color: Colors.redAccent,
                                      width: 1.5,
                                    )
                                  : _emailHasFocus
                                  ? BorderSide(
                                      color: settings.theme == Themes.Light
                                          ? Colors.black.withAlpha(100)
                                          : Colors.white.withAlpha(100),
                                      width: 1.5,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                          child: Focus(
                            onFocusChange: (focused) {
                              setState(() {
                                _emailHasFocus = focused;
                              });
                            },
                            focusNode: _emailFieldFocusNode,
                            child: TextField(
                              onChanged: (String s) {
                                if (mounted && s != '') {
                                  setState(() {
                                    _emptyEmail = false;
                                    _email = s;
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Email address',
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
                                  horizontal: 10.0,
                                ), // Added contentPadding
                              ),
                              controller: _emailController,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (String s) {},
                              style: TextStyle(
                                color: settings.theme == Themes.Light
                                    ? Colors.black
                                    : Colors.white,
                              ),
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
              ListTile(
                title: Text(
                  'Gender'.i18n,
                  style: TextStyle(color: Settings.secondaryText),
                ),
                subtitle: Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    _sex == 'M'
                        ? 'Male'
                        : _sex == 'F'
                        ? 'Female'
                        : '',
                    style: TextStyle(
                      color: settings.theme == Themes.Light
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      // Use a distinct context for the dialog
                      String? tempSex =
                          _sex; // Use a temporary variable for selection within the dialog

                      return AlertDialog(
                        title: const Text('Pick your gender'),
                        content: StatefulBuilder(
                          // Use StatefulBuilder to manage state within the dialog
                          builder: (BuildContext context, StateSetter setState) {
                            return Column(
                              mainAxisSize: MainAxisSize
                                  .min, // Essential to prevent column from taking full height
                              children: [
                                ListTile(
                                  title: const Text('Male'),
                                  leading: Radio<String>(
                                    groupValue: tempSex,
                                    value: 'M',
                                    onChanged: (String? value) {
                                      setState(() {
                                        tempSex = value;
                                      });
                                      // Update the main state and close the dialog
                                      if (mounted) {
                                        this.setState(() {
                                          // Calling setState on the main widget's state
                                          _sex = value!;
                                        });
                                      }
                                      Navigator.of(
                                        dialogContext,
                                      ).pop(); // Close the dialog
                                    },
                                  ),
                                ),
                                ListTile(
                                  title: const Text('Female'),
                                  leading: Radio<String>(
                                    groupValue: tempSex,
                                    value: 'F',
                                    onChanged: (String? value) {
                                      setState(() {
                                        tempSex = value;
                                      });
                                      // Update the main state and close the dialog
                                      if (mounted) {
                                        this.setState(() {
                                          // Calling setState on the main widget's state
                                          _sex = value!;
                                        });
                                      }
                                      Navigator.of(
                                        dialogContext,
                                      ).pop(); // Close the dialog
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  );
                },
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
                ),
            ],
          ),
        ],
      ),
    );
  }
}
