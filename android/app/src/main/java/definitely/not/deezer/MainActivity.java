package definitely.not.deezer;

import android.content.ComponentName;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Message;
import android.os.Messenger;
import android.os.Parcelable;
import android.os.RemoteException;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.ryanheise.audioservice.AudioServiceActivity;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends AudioServiceActivity {
    private static final String NATIVE_CHANNEL = "definitely.not.deezer/native";
    private static final String EVENT_CHANNEL = "definitely.not.deezer/events";
    private static final String TAG = "MainActivity";
    EventChannel.EventSink eventSink;

    // --- Download Service ---
    boolean downloadServiceBound = false;
    Messenger downloadServiceMessenger;
    Messenger activityMessengerForDownload;

    // --- ACRCloud Service ---
    boolean acrServiceBound = false;
    Messenger acrServiceMessenger;
    Messenger activityMessengerForAcr;

    SQLiteDatabase db;
    StreamServer streamServer;

    String intentPreload;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        Log.d(TAG, "onCreate");
        Intent intent = getIntent();
        intentPreload = intent.getStringExtra("preload");
        super.onCreate(savedInstanceState);
        activityMessengerForAcr = new Messenger(new IncomingHandler(this));
        activityMessengerForDownload = new Messenger(new IncomingHandler(this));
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        Log.d(TAG, "configureFlutterEngine");
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), NATIVE_CHANNEL).setMethodCallHandler((call, result) -> {
            Log.d(TAG, "MethodChannel received: " + call.method);
            try {
                switch (call.method) {
                    case "addDownloads":
                        addDownloads(call.arguments(), result);
                        break;
                    case "getDownloads":
                        getDownloads(result);
                        break;
                    case "updateSettings":
                        updateSettings(call.argument("json").toString(), result);
                        break;
                    case "loadDownloads":
                        loadDownloads(result);
                        break;
                    case "start":
                        startDownloads(result);
                        break;
                    case "stop":
                        stopDownloads(result);
                        break;
                    case "removeDownload":
                        removeDownload((int) call.argument("id"), result);
                        break;
                    case "retryDownloads":
                        retryDownloads(result);
                        break;
                    case "removeDownloads":
                        removeDownloads((int) call.argument("state"), result);
                        break;
                    case "getPreloadInfo":
                        getPreloadInfo(result);
                        break;
                    case "arch":
                        getArch(result);
                        break;
                    case "startServer":
                        startServer(call.argument("arl"), result);
                        break;
                    case "getStreamInfo":
                        getStreamInfo(call.argument("id").toString(), result);
                        break;
                    case "kill":
                        killServices(result);
                        break;
                    case "acrConfigure":
                        acrConfigure(call.argument("host"), call.argument("accessKey"), call.argument("accessSecret"), result);
                        break;
                    case "acrStart":
                        acrStart(result);
                        break;
                    case "acrCancel":
                        acrCancel(result);
                        break;
                    case "acrRelease":
                        acrRelease(result);
                        break;
                    default:
                        Log.w(TAG, "Unknown method called: " + call.method);
                        result.notImplemented();
                }
            } catch (Exception e) {
                Log.e(TAG, "Error handling method call: " + call.method, e);
                result.error("NATIVE_ERROR", "Error handling method call: " + call.method, e.getMessage());
            }
        });

        EventChannel eventChannel = new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), EVENT_CHANNEL);
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                Log.i(TAG, "Event Sink Listening");
                eventSink = events;
                sendMessageToDownloadService(DownloadService.SERVICE_REGISTER_CLIENT, null);
                sendMessageToAcrService(AcrCloudHandler.MSG_ACR_STATE, null);
            }

            @Override
            public void onCancel(Object arguments) {
                Log.i(TAG, "Event Sink Cancelled");
                sendMessageToDownloadService(DownloadService.SERVICE_UNREGISTER_CLIENT, null);
                eventSink = null;
            }
        });
    }

    // --- Download Service Methods ---

    private void addDownloads(Object arguments, MethodChannel.Result result) {
        if (!(arguments instanceof ArrayList)) {
            result.error("INVALID_ARGS", "Downloads list is not an ArrayList", null);
            return;
        }
        ArrayList<HashMap<String, Object>> downloads = (ArrayList<HashMap<String, Object>>) arguments;
        if (downloads.isEmpty()) {
            result.success(null);
            return;
        }
        db.beginTransaction();
        try {
            for (HashMap<String, Object> download : downloads) {
                String trackId = (String) download.get("trackId");
                String path = (String) download.get("path");
                if (trackId == null || path == null) {
                    Log.e(TAG, "Invalid download data: trackId or path is null");
                    continue;
                }
                try (Cursor cursor = db.rawQuery("SELECT id, state, quality FROM Downloads WHERE trackId == ? AND path == ?", new String[]{trackId, path})) {
                    if (cursor.moveToFirst()) {
                        int state = cursor.getInt(1);
                        if (state >= 3) {
                            ContentValues values = new ContentValues();
                            values.put("state", 0);
                            values.put("quality", cursor.getInt(2));
                            db.update("Downloads", values, "id == ?", new String[]{Integer.toString(cursor.getInt(0))});
                            Log.d(TAG, "Download exists, resetting state to NONE: " + trackId);
                        } else {
                            Log.d(TAG, "Download already in progress or queued: " + trackId);
                        }
                        continue;
                    }
                }
                ContentValues row = Download.flutterToSQL(download);
                db.insert("Downloads", null, row);
                Log.d(TAG, "Inserting new download: " + trackId);
            }
            db.setTransactionSuccessful();
        } catch (Exception e) {
            Log.e(TAG, "Error adding downloads", e);
            result.error("DB_ERROR", "Error adding downloads", e.getMessage());
        } finally {
            db.endTransaction();
        }
        sendMessageToDownloadService(DownloadService.SERVICE_LOAD_DOWNLOADS, null);
        result.success(null);
    }

    private void getDownloads(MethodChannel.Result result) {
        List<HashMap<?, ?>> downloadsList = new ArrayList<>();
        db.beginTransaction();
        try (Cursor cursor = db.query("Downloads", null, null, null, null, null, null)) {
            while (cursor.moveToNext()) {
                Download download = Download.fromSQL(cursor);
                downloadsList.add(download.toHashMap());
            }
            db.setTransactionSuccessful();
        } catch (Exception e) {
            Log.e(TAG, "Error getting downloads", e);
            result.error("DB_ERROR", "Error getting downloads", e.getMessage());
        } finally {
            db.endTransaction();
        }
        result.success(downloadsList);
    }

    private void updateSettings(String json, MethodChannel.Result result) {
        Bundle bundle = new Bundle();
        bundle.putString("json", json);
        sendMessageToDownloadService(DownloadService.SERVICE_SETTINGS_UPDATE, bundle);
        result.success(null);
    }

    private void loadDownloads(MethodChannel.Result result) {
        sendMessageToDownloadService(DownloadService.SERVICE_LOAD_DOWNLOADS, null);
        result.success(null);
    }

    private void startDownloads(MethodChannel.Result result) {
        sendMessageToDownloadService(DownloadService.SERVICE_START_DOWNLOAD, null);
        result.success(downloadServiceBound);
    }

    private void stopDownloads(MethodChannel.Result result) {
        sendMessageToDownloadService(DownloadService.SERVICE_STOP_DOWNLOADS, null);
        result.success(null);
    }

    private void removeDownload(int id, MethodChannel.Result result) {
        Bundle bundle = new Bundle();
        bundle.putInt("id", id);
        sendMessageToDownloadService(DownloadService.SERVICE_REMOVE_DOWNLOAD, bundle);
        result.success(null);
    }

    private void retryDownloads(MethodChannel.Result result) {
        sendMessageToDownloadService(DownloadService.SERVICE_RETRY_DOWNLOADS, null);
        result.success(null);
    }

    private void removeDownloads(int state, MethodChannel.Result result) {
        Bundle bundle = new Bundle();
        bundle.putInt("state", state);
        sendMessageToDownloadService(DownloadService.SERVICE_REMOVE_DOWNLOADS, bundle);
        result.success(null);
    }

    // --- Common/Other Methods ---

    private void getPreloadInfo(MethodChannel.Result result) {
        result.success(intentPreload);
        intentPreload = null;
    }

    private void getArch(MethodChannel.Result result) {
        result.success(System.getProperty("os.arch"));
    }

    // --- Stream Server Methods ---

    private void startServer(String arl, MethodChannel.Result result) {
        if (streamServer == null) {
            String offlinePath = getExternalFilesDir("offline").getAbsolutePath();
            streamServer = new StreamServer(arl, offlinePath);
            streamServer.start();
        }
        result.success(null);
    }

    private void getStreamInfo(String id, MethodChannel.Result result) {
        if (streamServer == null) {
            result.success(null);
            return;
        }
        StreamServer.StreamInfo info = streamServer.streams.get(id);
        result.success(info != null ? info.toJSON() : null);
    }

    private void killServices(MethodChannel.Result result) {
        Log.d(TAG, "Kill command received");
        stopDownloadService();
        stopAcrService();
        stopStreamServer();
        result.success(null);
    }

    private void stopDownloadService() {
        Intent dlIntent = new Intent(this, DownloadService.class);
        stopService(dlIntent);
    }

    private void stopAcrService() {
        Intent acrIntent = new Intent(this, AcrCloudHandler.class);
        stopService(acrIntent);
    }

    private void stopStreamServer() {
        if (streamServer != null) {
            streamServer.stop();
            streamServer = null;
        }
    }

    // --- ACRCloud Service Methods ---

    private void acrConfigure(String host, String key, String secret, MethodChannel.Result result) {
        if (host == null || key == null || secret == null) {
            result.error("INVALID_ARGS", "Missing ACR configuration arguments", null);
            return;
        }
        Bundle bundle = new Bundle();
        bundle.putString(AcrCloudHandler.KEY_ACR_HOST, host);
        bundle.putString(AcrCloudHandler.KEY_ACR_ACCESS_KEY, key);
        bundle.putString(AcrCloudHandler.KEY_ACR_ACCESS_SECRET, secret);
        sendMessageToAcrService(AcrCloudHandler.MSG_ACR_CONFIGURE, bundle);
        result.success(true);
    }

    private void acrStart(MethodChannel.Result result) {
        sendMessageToAcrService(AcrCloudHandler.MSG_ACR_START, null);
        result.success(acrServiceBound);
    }

    private void acrCancel(MethodChannel.Result result) {
        sendMessageToAcrService(AcrCloudHandler.MSG_ACR_CANCEL, null);
        result.success(null);
    }

    private void acrRelease(MethodChannel.Result result) {
        sendMessageToAcrService(AcrCloudHandler.MSG_ACR_RELEASE, null);
        result.success(null);
    }

    // --- Service Connections ---

    private void connectDownloadService() {
        if (downloadServiceBound) {
            Log.d(TAG, "Already bound to DownloadService.");
            return;
        }
        Intent intent = new Intent(this, DownloadService.class);
        intent.putExtra("activityMessenger", activityMessengerForDownload);
        startService(intent);
        bindService(intent, downloadConnection, Context.BIND_AUTO_CREATE);
        Log.i(TAG, "Attempting to bind DownloadService...");
    }

    private void connectAcrService() {
        if (acrServiceBound) {
            Log.d(TAG, "Already bound to AcrCloudHandler.");
            return;
        }
        Intent intent = new Intent(this, AcrCloudHandler.class);
        bindService(intent, acrConnection, Context.BIND_AUTO_CREATE);
        Log.i(TAG, "Attempting to bind AcrCloudHandler...");
    }

    private final ServiceConnection downloadConnection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
            Log.i(TAG, "DownloadService Bound!");
            downloadServiceMessenger = new Messenger(iBinder);
            downloadServiceBound = true;
        }

        @Override
        public void onServiceDisconnected(ComponentName componentName) {
            Log.w(TAG, "DownloadService Disconnected unexpectedly!");
            downloadServiceMessenger = null;
            downloadServiceBound = false;
        }
    };

    private final ServiceConnection acrConnection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
            Log.i(TAG, "AcrCloudHandler Bound!");
            acrServiceMessenger = new Messenger(iBinder);
            acrServiceBound = true;
            Message msg = Message.obtain(null, AcrCloudHandler.MSG_ACR_REGISTER_CLIENT);
            msg.replyTo = activityMessengerForAcr;
            sendMessageToAcrService(msg);
        }

        @Override
        public void onServiceDisconnected(ComponentName componentName) {
            Log.w(TAG, "AcrCloudHandler Disconnected unexpectedly!");
            acrServiceMessenger = null;
            acrServiceBound = false;
        }
    };

    // --- Incoming Message Handler (from Services) ---

    private static class IncomingHandler extends Handler {
        private final WeakReference<MainActivity> weakReference;

        IncomingHandler(MainActivity activity) {
            super(Looper.getMainLooper());
            this.weakReference = new WeakReference<>(activity);
        }

        @Override
        public void handleMessage(@NonNull Message msg) {
            MainActivity activity = weakReference.get();
            if (activity == null) {
                Log.w(TAG, "IncomingHandler: Activity is null, ignoring message: " + msg.what);
                return;
            }
            if (activity.eventSink == null) {
                Log.w(TAG, "IncomingHandler: EventSink is null, cannot forward message: " + msg.what);
                return;
            }

            EventChannel.EventSink eventSink = activity.eventSink;
            Bundle data = msg.getData();
            HashMap<String, Object> eventData = new HashMap<>();

            Log.d(TAG, "IncomingHandler received message: " + msg.what);

            try {
                switch (msg.what) {
                    case DownloadService.SERVICE_ON_PROGRESS:
                        eventData.put("eventType", "downloadProgress");
                        ArrayList<Bundle> downloads = getParcelableArrayList(data, "downloads", Bundle.class);
                        if (downloads != null && !downloads.isEmpty()) {
                            ArrayList<HashMap<String, Object>> progressData = new ArrayList<>();
                            for (Bundle bundle : downloads) {
                                HashMap<String, Object> item = new HashMap<>();
                                item.put("id", bundle.getInt("id"));
                                item.put("state", bundle.getInt("state"));
                                item.put("received", bundle.getLong("received"));
                                item.put("filesize", bundle.getLong("filesize"));
                                item.put("quality", bundle.getInt("quality"));
                                item.put("trackId", bundle.getString("trackId"));
                                progressData.add(item);
                            }
                            eventData.put("data", progressData);
                            eventSink.success(eventData);
                        } else {
                            Log.w(TAG, "Received download progress but no data bundles found.");
                        }
                        break;
                    case DownloadService.SERVICE_ON_STATE_CHANGE:
                        eventData.put("eventType", "downloadState");
                        HashMap<String, Object> stateData = new HashMap<>();
                        stateData.put("running", data.getBoolean("running"));
                        stateData.put("queueSize", data.getInt("queueSize"));
                        eventData.put("data", stateData);
                        eventSink.success(eventData);
                        break;
                    case AcrCloudHandler.MSG_ACR_RESULT:
                        eventData.put("eventType", "acrResult");
                        eventData.put("resultJson", data.getString(AcrCloudHandler.KEY_ACR_RESULT_JSON));
                        eventSink.success(eventData);
                        break;
                    case AcrCloudHandler.MSG_ACR_VOLUME:
                        eventData.put("eventType", "acrVolume");
                        eventData.put("volume", data.getDouble(AcrCloudHandler.KEY_ACR_VOLUME));
                        eventSink.success(eventData);
                        break;
                    case AcrCloudHandler.MSG_ACR_ERROR:
                        eventData.put("eventType", "acrError");
                        eventData.put("error", data.getString(AcrCloudHandler.KEY_ACR_ERROR));
                        eventSink.success(eventData);
                        break;
                    case AcrCloudHandler.MSG_ACR_STATE:
                        eventData.put("eventType", "acrState");
                        HashMap<String, Object> acrStateData = new HashMap<>();
                        acrStateData.put("initialized", data.getBoolean(AcrCloudHandler.KEY_ACR_STATE_INITIALIZED));
                        acrStateData.put("processing", data.getBoolean(AcrCloudHandler.KEY_ACR_STATE_PROCESSING));
                        eventData.put("data", acrStateData);
                        eventSink.success(eventData);
                        break;
                    default:
                        Log.w(TAG, "IncomingHandler: Unhandled message type: " + msg.what);
                        super.handleMessage(msg);
                }
            } catch (Exception e) {
                Log.e(TAG, "Error handling message or sending to EventSink: " + msg.what, e);
            }
        }
    }

    // --- Send Message Helper Methods ---

    void sendMessageToDownloadService(int type, Bundle data) {
        if (!downloadServiceBound) {
            Log.w(TAG, "Cannot send message to DownloadService - not bound.");
            return;
        }
        if (downloadServiceMessenger == null) {
            Log.e(TAG, "Cannot send message to DownloadService - messenger is null despite being bound!");
            return;
        }

        Message msg = Message.obtain(null, type);
        if (data != null) {
            msg.setData(data);
        }
        try {
            Log.d(TAG, "Sending message to DownloadService: " + type);
            downloadServiceMessenger.send(msg);
        } catch (RemoteException e) {
            Log.e(TAG, "Failed to send message to DownloadService", e);
            downloadServiceBound = false;
            downloadServiceMessenger = null;
        }
    }

    void sendMessageToAcrService(int type, Bundle data) {
        if (!acrServiceBound) {
            Log.w(TAG, "Cannot send message to AcrCloudHandler - not bound.");
            return;
        }
        if (acrServiceMessenger == null) {
            Log.e(TAG, "Cannot send message to AcrCloudHandler - messenger is null despite being bound!");
            return;
        }

        Message msg = Message.obtain(null, type);
        if (data != null) {
            msg.setData(data);
        }
        msg.replyTo = activityMessengerForAcr;
        sendMessageToAcrService(msg);
    }

    void sendMessageToAcrService(Message msg) {
        if (!acrServiceBound) {
            Log.w(TAG, "Cannot send message object to AcrCloudHandler - not bound.");
            return;
        }
        if (acrServiceMessenger == null) {
            Log.e(TAG, "Cannot send message object to AcrCloudHandler - messenger is null despite being bound!");
            return;
        }
        try {
            Log.d(TAG, "Sending message object to AcrCloudHandler: " + msg.what);
            acrServiceMessenger.send(msg);
        } catch (RemoteException e) {
            Log.e(TAG, "Failed to send message object to AcrCloudHandler", e);
            acrServiceBound = false;
            acrServiceMessenger = null;
        }
    }

    // --- Lifecycle Methods ---

    @Override
    protected void onStart() {
        Log.d(TAG, "onStart");
        super.onStart();
        try {
            DownloadsDatabase dbHelper = new DownloadsDatabase(getApplicationContext());
            if (db == null || !db.isOpen()) {
                db = dbHelper.getWritableDatabase();
                Log.i(TAG, "Database opened.");
            } else {
                Log.w(TAG, "Database already open.");
            }
        } catch (Exception e) {
            Log.e(TAG, "Error opening database", e);
            return;
        }
        connectDownloadService();
        connectAcrService();
    }

    @Override
    protected void onResume() {
        Log.d(TAG, "onResume");
        super.onResume();
    }

    @Override
    protected void onPause() {
        Log.d(TAG, "onPause");
        super.onPause();
    }

    @Override
    protected void onStop() {
        Log.d(TAG, "onStop");
        super.onStop();
    }

    @Override
    protected void onDestroy() {
        Log.i(TAG, "onDestroy");
        super.onDestroy();
        stopStreamServer();
        unbindDownloadService();
        unbindAcrService();
        closeDatabase();
    }

    private void unbindDownloadService() {
        if (downloadServiceBound) {
            Log.i(TAG, "Unbinding DownloadService");
            try {
                unbindService(downloadConnection);
            } catch (IllegalArgumentException e) {
                Log.w(TAG, "Error unbinding DownloadService (already unbound?): " + e.getMessage());
            }
            downloadServiceBound = false;
            downloadServiceMessenger = null;
        }
    }

    private void unbindAcrService() {
        if (acrServiceBound) {
            Log.i(TAG, "Unbinding AcrCloudHandler");
            try {
                sendMessageToAcrService(AcrCloudHandler.MSG_ACR_UNREGISTER_CLIENT, null);
                unbindService(acrConnection);
            } catch (IllegalArgumentException e) {
                Log.w(TAG, "Error unbinding AcrCloudHandler (already unbound?): " + e.getMessage());
            }
            acrServiceBound = false;
            acrServiceMessenger = null;
        }
    }

    private void closeDatabase() {
        if (db != null && db.isOpen()) {
            Log.i(TAG, "Closing Database");
            db.close();
            db = null;
        }
    }

    // --- Utility Methods ---

    @Nullable
    public static <T extends Parcelable> ArrayList<T> getParcelableArrayList(@Nullable Bundle bundle, @Nullable String key, @NonNull Class<T> clazz) {
        if (bundle == null || key == null) return null;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return bundle.getParcelableArrayList(key, clazz);
        } else {
            @SuppressWarnings("deprecation")
            ArrayList<T> list = bundle.getParcelableArrayList(key);
            if (list != null && !list.isEmpty()) {
                if (!clazz.isInstance(list.get(0))) {
                    Log.e(TAG, "getParcelableArrayList: Type mismatch for key '" + key + "'. Expected " + clazz.getName() + " but got " + list.get(0).getClass().getName());
                    return new ArrayList<>();
                }
            }
            return list;
        }
    }
}
