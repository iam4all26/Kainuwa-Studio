package com.kainuwa.encoder;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

import androidx.annotation.OptIn;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.effect.BitmapOverlay;
import androidx.media3.effect.OverlaySettings;
import androidx.media3.effect.TextureOverlay;

import com.google.common.collect.ImmutableList;

import java.util.ArrayList;
import java.util.List;

/**
 * Animated items of a whole lesson. One set of "slots" is shared by all scenes:
 * at any moment slot k shows the k-th animated item of the scene that is playing.
 * Times are on the composition (whole lesson) timeline.
 */
@OptIn(markerClass = UnstableApi.class)
final class LessonOverlays {

    static final class Item {
        String path;
        float cx;
        float cy;
        String kind;
        long startMs;
        long durMs;
    }

    private final List<Long> sceneStartUs = new ArrayList<>();
    private final List<List<Item>> perScene = new ArrayList<>();
    private long cursorMs = 0;
    private int slots = 0;

    void addScene(long durationMs, List<Item> items) {
        sceneStartUs.add(cursorMs * 1000L);
        perScene.add(items);
        cursorMs += durationMs;
        slots = Math.max(slots, items.size());
    }

    int slotCount() {
        return slots;
    }

    private int sceneAt(long timeUs) {
        int idx = 0;
        for (int i = 0; i < sceneStartUs.size(); i++) {
            if (timeUs >= sceneStartUs.get(i)) {
                idx = i;
            } else {
                break;
            }
        }
        return idx;
    }

    ImmutableList<TextureOverlay> build() {
        ImmutableList.Builder<TextureOverlay> list = ImmutableList.builder();
        for (int k = 0; k < slots; k++) {
            list.add(new Slot(k));
        }
        return list.build();
    }

    private static final Bitmap BLANK = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888);
    private static final OverlaySettings HIDDEN =
            new OverlaySettings.Builder().setAlphaScale(0f).build();

    private final class Slot extends BitmapOverlay {
        private final int slot;
        private int cachedScene = -1;
        private Bitmap cachedBitmap = BLANK;

        Slot(int slot) {
            this.slot = slot;
        }

        private Item itemAt(int scene) {
            List<Item> items = perScene.get(scene);
            return slot < items.size() ? items.get(slot) : null;
        }

        @Override
        public Bitmap getBitmap(long presentationTimeUs) {
            int scene = sceneAt(presentationTimeUs);
            Item item = itemAt(scene);
            if (item == null) {
                return BLANK;
            }
            if (scene != cachedScene) {
                Bitmap decoded = BitmapFactory.decodeFile(item.path);
                cachedBitmap = decoded == null ? BLANK : decoded;
                cachedScene = scene;
            }
            return cachedBitmap;
        }

        @Override
        public OverlaySettings getOverlaySettings(long presentationTimeUs) {
            int scene = sceneAt(presentationTimeUs);
            Item item = itemAt(scene);
            if (item == null) {
                return HIDDEN;
            }
            double localMs = (presentationTimeUs - sceneStartUs.get(scene)) / 1000.0;
            double[] f = frame(item.kind, localMs, item.startMs, item.durMs);
            float x = (float) (item.cx * 2f - 1f + f[1] * 2.0);
            float y = (float) (1f - item.cy * 2f);
            return new OverlaySettings.Builder()
                    .setBackgroundFrameAnchor(x, y)
                    .setScale((float) f[2], (float) f[2])
                    .setAlphaScale((float) Math.max(0.0, Math.min(1.0, f[0])))
                    .build();
        }
    }

    /** Same formulas as lib/animation_math.dart. Returns alpha, dx (slide width fraction), scale. */
    static double[] frame(String kind, double timeMs, long startMs, long durMs) {
        if (kind == null || kind.equals("none")) {
            return new double[]{1, 0, 1};
        }
        double duration = Math.max(1, durMs);
        double progress = timeMs <= startMs ? 0.0 : Math.min(1.0, (timeMs - startMs) / duration);
        if (kind.equals("appear")) {
            return new double[]{progress > 0 ? 1 : 0, 0, 1};
        }
        double eased = 1 - Math.pow(1 - progress, 3);
        double alpha = eased;
        double dx = 0;
        double scale = 1;
        switch (kind) {
            case "slide":
                dx = -0.175 * (1 - eased);
                break;
            case "pop": {
                double q = progress - 1;
                scale = 1 + 2.70158 * q * q * q + 1.70158 * q * q;
                alpha = Math.min(1.0, progress * 4);
                break;
            }
            case "zoom":
                scale = 1.6 - 0.6 * eased;
                break;
            default:
                break;
        }
        if (progress <= 0) {
            alpha = 0;
        }
        return new double[]{alpha, dx, Math.max(0.01, scale)};
    }
}
