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
    List<String?> notificationId = List.generate(
            widget.notifications.length,
            (int i) => (widget.notifications[i].read ?? true)
                ? null
                : widget.notifications[i].id)
        .where((String? s) => s != null)
        .toList();

    if (notificationId.isNotEmpty) {
      await deezerAPI.callGwLightApi('notification.markAsRead',
          params: {'notif_ids': notificationId});
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
