import 'package:alchemy/api/deezer.dart';
import 'package:alchemy/api/definitions.dart';
import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:alchemy/main.dart';
import 'package:alchemy/translations.i18n.dart';
import 'package:alchemy/ui/elements.dart';
import 'package:alchemy/ui/tiles.dart';
import 'package:alchemy/utils/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationScreen extends StatefulWidget {
  final List<DeezerNotification> notifications;
  const NotificationScreen(this.notifications, {super.key});

  @override
  _NotificationScreen createState() => _NotificationScreen();
}

class _NotificationScreen extends State<NotificationScreen> {
  List<DeezerNotification> notifications = [];
  bool _isLoading = false;
  bool _online = true;
  ScrollController _scrollController = ScrollController();

  void _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    bool online = await isConnected();

    if (mounted) {
      setState(() {
        _online = online;
      });
    }

    List<DeezerNotification> noti = await deezerAPI.getNotifications();

    if (mounted) {
      setState(() {
        notifications = noti;
        _isLoading = false;
      });
    }

    _readAll();
  }

  void _readAll() async {
    await deezerAPI.callGwApi(
      'appnotif_markAllAsRead',
    );
  }

  void _loadMore() async {
    List<DeezerNotification> nextNotifications =
        await deezerAPI.getNotifications(lastId: notifications.last.id);
    if (mounted) {
      setState(() {
        notifications.addAll(nextNotifications);
      });
    }
  }

  @override
  void initState() {
    if (widget.notifications.isNotEmpty && mounted) {
      setState(() {
        notifications = widget.notifications;
      });
      _readAll();
    } else {
      _load();
    }

    _scrollController.addListener(() {
      double off = _scrollController.position.maxScrollExtent * 0.90;
      if (_scrollController.position.pixels > off) {
        _loadMore();
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
    return Scaffold(
      appBar: FreezerAppBar('Notifications'),
      body: _online
          ? _isLoading
              ? SplashScreen()
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: notifications.length,
                  itemBuilder: (context, int i) => NotificationTile(
                        notifications[i],
                        onTap: () {
                          openScreenByURL(notifications[i].url ?? '');
                        },
                      ))
          : Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
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
                    Text(
                      'Notifications are only available if you are connected to the internet.'
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
            ),
    );
  }
}
