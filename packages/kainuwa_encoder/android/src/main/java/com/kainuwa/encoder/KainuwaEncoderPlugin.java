package com.kainuwa.encoder;

import android.app.Activity;
import android.graphics.Bitmap;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;
import android.provider.OpenableColumns;

import androidx.annotation.NonNull;
import androidx.annotation.OptIn;
import androidx.media3.common.Effect;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.audio.AudioProcessor;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.effect.OverlayEffect;
import androidx.media3.effect.Presentation;
import androidx.media3.effect.TextureOverlay;
import androidx.media3.transformer.Composition;
import androidx.media3.transformer.EditedMediaItem;
import androidx.media3.transformer.EditedMediaItemSequence;
import androidx.media3.transformer.Effects;
import androidx.media3.transformer.ExportException;
import androidx.media3.transformer.ExportResult;
import androidx.media3.transformer.ProgressHolder;
import androidx.media3.transformer.Transformer;

import com.google.common.collect.ImmutableList;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * Local plugin for Kainuwa Studio: system file picker, image + audio to MP4 export
 * (Media3 Transformer), and saving finished videos into Movies.
 */
@OptIn(markerClass = UnstableApi.class)
public class KainuwaEncoderPlugin
        implements FlutterPlugin,
        MethodChannel.MethodCallHandler,
        ActivityAware,
        PluginRegistry.ActivityResultListener {

    private static final String CHANNEL_NAME = "kainuwa_encoder";
    private static final int REQUEST_PICK = 4101;
    private static final int REQUEST_SAVE = 4102;

    private MethodChannel channel;
    private Context appContext;
    private Activity activity;
    private ActivityPluginBinding activityBinding;

    private MethodChannel.Result pendingPick;
    private MethodChannel.Result pendingSave;
    private String pendingSavePath;

    private Transformer transformer;
    private MethodChannel.Result exportResult;
    private String exportOutput;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService worker = Executors.newSingleThreadExecutor();

    private final Runnable progressTicker = new Runnable() {
        @Override
        public void run() {
            Transformer t = transformer;
            if (t == null) {
                return;
            }
            ProgressHolder holder = new ProgressHolder();
            int state = t.getProgress(holder);
            if (state == Transformer.PROGRESS_STATE_AVAILABLE && channel != null) {
                channel.invokeMethod("progress", holder.progress);
            }
            mainHandler.postDelayed(this, 500);
        }
    };

    // ---- FlutterPlugin ----

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        appContext = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (transformer != null) {
            transformer.cancel();
        }
        transformer = null;
        exportResult = null;
        mainHandler.removeCallbacks(progressTicker);
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
    }

    // ---- ActivityAware ----

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        activityBinding = binding;
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        detachActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        detachActivity();
    }

    private void detachActivity() {
        if (activityBinding != null) {
            activityBinding.removeActivityResultListener(this);
        }
        activityBinding = null;
        activity = null;
    }

    // ---- Method calls ----

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "pick":
                pick((String) call.argument("mime"), result);
                break;
            case "exportScene":
                exportScene(call, result);
                break;
            case "cancel":
                cancel(result);
                break;
            case "saveToMovies":
                saveToMovies((String) call.argument("path"), (String) call.argument("name"), result);
                break;
            case "filesDir":
                result.success(appContext.getFilesDir().getAbsolutePath());
                break;
            default:
                result.notImplemented();
        }
    }

    // ---- File picker ----

    private void pick(String mime, MethodChannel.Result result) {
        if (activity == null) {
            result.error("no_activity", "The app screen is not ready yet.", null);
            return;
        }
        if (pendingPick != null) {
            result.error("busy", "A file picker is already open.", null);
            return;
        }
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType(mime == null ? "*/*" : mime);
        pendingPick = result;
        activity.startActivityForResult(intent, REQUEST_PICK);
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQUEST_SAVE) {
            handleSaveResult(resultCode, data);
            return true;
        }
        if (requestCode != REQUEST_PICK) {
            return false;
        }
        final MethodChannel.Result r = pendingPick;
        pendingPick = null;
        if (r == null) {
            return true;
        }
        if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
            r.success(null);
            return true;
        }
        final Uri uri = data.getData();
        worker.execute(() -> {
            try {
                final String path = copyToCache(uri);
                mainHandler.post(() -> r.success(path));
            } catch (Exception e) {
                final String message = String.valueOf(e.getMessage());
                mainHandler.post(() -> r.error("copy_failed", message, null));
            }
        });
        return true;
    }

    private String displayName(Uri uri) {
        String name = null;
        try (Cursor cursor = appContext.getContentResolver()
                .query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                name = cursor.getString(0);
            }
        } catch (Exception ignored) {
            // fall through to the default name
        }
        if (name == null || name.trim().isEmpty()) {
            name = "file";
        }
        return name.replaceAll("[^A-Za-z0-9._-]", "_");
    }

    private String copyToCache(Uri uri) throws IOException {
        File dir = new File(appContext.getFilesDir(), "media");
        if (!dir.exists() && !dir.mkdirs()) {
            throw new IOException("Could not create the import folder.");
        }
        File target = new File(dir, System.currentTimeMillis() + "_" + displayName(uri));
        try (InputStream in = appContext.getContentResolver().openInputStream(uri);
             OutputStream out = new FileOutputStream(target)) {
            if (in == null) {
                throw new IOException("Could not open the chosen file.");
            }
            copyStream(in, out);
        }
        return target.getAbsolutePath();
    }

    private static void copyStream(InputStream in, OutputStream out) throws IOException {
        byte[] buffer = new byte[64 * 1024];
        int read;
        while ((read = in.read(buffer)) != -1) {
            out.write(buffer, 0, read);
        }
    }

    // ---- Export ----

    private long readDurationMs(String path) {
        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        try {
            retriever.setDataSource(path);
            String value = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
            return value == null ? -1 : Long.parseLong(value);
        } catch (Exception e) {
            return -1;
        } finally {
            try {
                retriever.release();
            } catch (Exception ignored) {
                // nothing to do
            }
        }
    }

    private static double num(MethodCall call, String key, double fallback) {
        Object value = call.argument(key);
        return value instanceof Number ? ((Number) value).doubleValue() : fallback;
    }

    private static String str(MethodCall call, String key) {
        Object value = call.argument(key);
        if (value instanceof String) {
            String s = ((String) value).trim();
            return s.isEmpty() ? null : s;
        }
        return null;
    }

    private void exportScene(MethodCall call, MethodChannel.Result result) {
        if (transformer != null) {
            result.error("busy", "An export is already running.", null);
            return;
        }
        String imagePath = str(call, "image");
        String narrationPath = str(call, "narration");
        String musicPath = str(call, "music");
        String outputPath = str(call, "output");
        if (imagePath == null || narrationPath == null || outputPath == null) {
            result.error("bad_arguments", "Image, narration and output paths are required.", null);
            return;
        }
        int width = (int) num(call, "width", 1280);
        int height = (int) num(call, "height", 720);
        float narrationVolume = (float) num(call, "narrationVolume", 1.0);
        float musicVolume = (float) num(call, "musicVolume", 0.3);
        long musicFadeInMs = (long) num(call, "musicFadeInMs", 0);
        long musicFadeOutMs = (long) num(call, "musicFadeOutMs", 0);
        String overlayText = str(call, "overlayText");
        long overlayStartMs = (long) num(call, "overlayStartMs", 1000);
        long overlayDurationMs = (long) num(call, "overlayDurationMs", 800);
        String overlayAnimation = str(call, "overlayAnimation");

        long narrationMs = readDurationMs(narrationPath);
        if (narrationMs <= 0) {
            result.error("bad_audio", "Could not read the length of the narration file.", null);
            return;
        }

        File out = new File(outputPath);
        File parent = out.getParentFile();
        if (parent != null && !parent.exists()) {
            parent.mkdirs();
        }
        if (out.exists()) {
            out.delete();
        }

        // Picture: the image for the whole narration, plus an optional animated text label.
        MediaItem imageItem = new MediaItem.Builder()
                .setUri(Uri.fromFile(new File(imagePath)))
                .setImageDurationMs(narrationMs)
                .build();
        List<Effect> imageEffects = new ArrayList<>();
        imageEffects.add(Presentation.createForWidthAndHeight(
                width, height, Presentation.LAYOUT_SCALE_TO_FIT));
        if (overlayText != null) {
            Bitmap label = AnimatedTextOverlay.renderText(overlayText);
            imageEffects.add(new OverlayEffect(ImmutableList.<TextureOverlay>of(
                    new AnimatedTextOverlay(label, overlayStartMs * 1000L,
                            overlayDurationMs * 1000L, overlayAnimation))));
        }
        EditedMediaItem editedImage = new EditedMediaItem.Builder(imageItem)
                .setFrameRate(30)
                .setEffects(new Effects(new ArrayList<AudioProcessor>(), imageEffects))
                .build();

        // Narration: only the sound of the file, with its own volume.
        List<AudioProcessor> narrationProcessors = new ArrayList<>();
        if (Math.abs(narrationVolume - 1f) > 0.001f) {
            narrationProcessors.add(new GainAudioProcessor(
                    narrationVolume, 0L, 0L, narrationMs * 1000L));
        }
        EditedMediaItem editedNarration = new EditedMediaItem.Builder(
                MediaItem.fromUri(Uri.fromFile(new File(narrationPath))))
                .setRemoveVideo(true)
                .setEffects(new Effects(narrationProcessors, new ArrayList<Effect>()))
                .build();

        List<EditedMediaItemSequence> sequences = new ArrayList<>();
        sequences.add(new EditedMediaItemSequence(Collections.singletonList(editedImage)));
        sequences.add(new EditedMediaItemSequence(Collections.singletonList(editedNarration)));

        // Background music: cut to the narration length, with volume and fades.
        if (musicPath != null) {
            long musicMs = readDurationMs(musicPath);
            if (musicMs <= 0) {
                result.error("bad_audio", "Could not read the length of the music file.", null);
                return;
            }
            long usedMs = Math.min(musicMs, narrationMs);
            MediaItem.Builder musicBuilder = new MediaItem.Builder()
                    .setUri(Uri.fromFile(new File(musicPath)));
            if (musicMs > narrationMs) {
                musicBuilder.setClippingConfiguration(
                        new MediaItem.ClippingConfiguration.Builder()
                                .setEndPositionMs(narrationMs)
                                .build());
            }
            List<AudioProcessor> musicProcessors = new ArrayList<>();
            musicProcessors.add(new GainAudioProcessor(
                    musicVolume, musicFadeInMs * 1000L, musicFadeOutMs * 1000L, usedMs * 1000L));
            EditedMediaItem editedMusic = new EditedMediaItem.Builder(musicBuilder.build())
                    .setRemoveVideo(true)
                    .setEffects(new Effects(musicProcessors, new ArrayList<Effect>()))
                    .build();
            sequences.add(new EditedMediaItemSequence(Collections.singletonList(editedMusic)));
        }

        List<Effect> compositionVideoEffects = new ArrayList<>();
        compositionVideoEffects.add(Presentation.createForWidthAndHeight(
                width, height, Presentation.LAYOUT_SCALE_TO_FIT));
        Effects compositionEffects =
                new Effects(new ArrayList<AudioProcessor>(), compositionVideoEffects);

        Composition composition = new Composition.Builder(sequences)
                .setEffects(compositionEffects)
                .build();

        exportResult = result;
        exportOutput = outputPath;

        transformer = new Transformer.Builder(appContext)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(new Transformer.Listener() {
                    @Override
                    public void onCompleted(Composition composition, ExportResult exportResultInfo) {
                        MethodChannel.Result r = exportResult;
                        String path = exportOutput;
                        finishExport();
                        if (r != null) {
                            r.success(path);
                        }
                    }

                    @Override
                    public void onError(Composition composition, ExportResult exportResultInfo,
                                        ExportException exception) {
                        MethodChannel.Result r = exportResult;
                        finishExport();
                        if (r != null) {
                            r.error("export_failed",
                                    exception.getMessage() + " (code " + exception.errorCode + ")",
                                    null);
                        }
                    }
                })
                .build();

        mainHandler.removeCallbacks(progressTicker);
        mainHandler.postDelayed(progressTicker, 500);
        transformer.start(composition, outputPath);
    }

    private void finishExport() {
        transformer = null;
        exportResult = null;
        exportOutput = null;
        mainHandler.removeCallbacks(progressTicker);
    }

    private void cancel(MethodChannel.Result result) {
        Transformer t = transformer;
        MethodChannel.Result pending = exportResult;
        if (t != null) {
            t.cancel();
        }
        finishExport();
        if (pending != null) {
            pending.error("cancelled", "Export cancelled.", null);
        }
        result.success(null);
    }

    // ---- Save to Movies ----

    private void saveToMovies(String path, String name, MethodChannel.Result result) {
        if (path == null || name == null) {
            result.error("bad_arguments", "Path and name are required.", null);
            return;
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            saveWithPicker(path, name, result);
            return;
        }
        worker.execute(() -> {
            try {
                ContentResolver resolver = appContext.getContentResolver();
                ContentValues values = new ContentValues();
                values.put(MediaStore.Video.Media.DISPLAY_NAME, name);
                values.put(MediaStore.Video.Media.MIME_TYPE, "video/mp4");
                values.put(MediaStore.Video.Media.RELATIVE_PATH,
                        Environment.DIRECTORY_MOVIES + "/Kainuwa Studio");
                values.put(MediaStore.Video.Media.IS_PENDING, 1);
                Uri uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values);
                if (uri == null) {
                    throw new IOException("Could not create the file in Movies.");
                }
                try (InputStream in = new FileInputStream(path);
                     OutputStream out = resolver.openOutputStream(uri)) {
                    if (out == null) {
                        throw new IOException("Could not write to Movies.");
                    }
                    copyStream(in, out);
                }
                ContentValues done = new ContentValues();
                done.put(MediaStore.Video.Media.IS_PENDING, 0);
                resolver.update(uri, done, null, null);
                mainHandler.post(() -> result.success("Movies/Kainuwa Studio/" + name));
            } catch (Exception e) {
                final String message = String.valueOf(e.getMessage());
                mainHandler.post(() -> result.error("save_failed", message, null));
            }
        });
    }

    // Android 9 and older: let the user choose where to save (no storage permission needed).
    private void saveWithPicker(String path, String name, MethodChannel.Result result) {
        if (activity == null) {
            result.error("no_activity", "The app screen is not ready yet.", null);
            return;
        }
        if (pendingSave != null) {
            result.error("busy", "A save dialog is already open.", null);
            return;
        }
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("video/mp4");
        intent.putExtra(Intent.EXTRA_TITLE, name);
        pendingSave = result;
        pendingSavePath = path;
        activity.startActivityForResult(intent, REQUEST_SAVE);
    }

    private void handleSaveResult(int resultCode, Intent data) {
        final MethodChannel.Result r = pendingSave;
        final String path = pendingSavePath;
        pendingSave = null;
        pendingSavePath = null;
        if (r == null) {
            return;
        }
        if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null || path == null) {
            r.error("save_cancelled", "Saving was cancelled.", null);
            return;
        }
        final Uri uri = data.getData();
        worker.execute(() -> {
            try (InputStream in = new FileInputStream(path);
                 OutputStream out = appContext.getContentResolver().openOutputStream(uri)) {
                if (out == null) {
                    throw new IOException("Could not write to the chosen location.");
                }
                copyStream(in, out);
                mainHandler.post(() -> r.success("the location you chose"));
            } catch (Exception e) {
                final String message = String.valueOf(e.getMessage());
                mainHandler.post(() -> r.error("save_failed", message, null));
            }
        });
    }
}
