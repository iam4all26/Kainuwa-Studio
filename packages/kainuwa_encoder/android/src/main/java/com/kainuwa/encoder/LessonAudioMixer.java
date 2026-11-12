package com.kainuwa.encoder;

import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.ShortBuffer;
import java.util.Arrays;
import java.util.List;

/**
 * Builds the whole narration track of a lesson as one mono 16-bit WAV file.
 * Every scene gets exactly its own length (cut or padded with silence), so the
 * sound can never drift away from the pictures. Voice cleaning and volume are
 * applied here.
 */
final class LessonAudioMixer {

    static final int RATE = 44100;

    interface Control {
        boolean cancelled();

        void progress(int percent);
    }

    static final class Spec {
        String path;       // null means silence
        long durationMs;
        float volume = 1f;
        boolean clean;
    }

    private LessonAudioMixer() {
    }

    static void mix(List<Spec> specs, File out, Control control) throws IOException {
        long totalMs = 0;
        for (Spec s : specs) {
            totalMs += s.durationMs;
        }
        long totalFrames = Math.round(totalMs * RATE / 1000.0);

        try (OutputStream os = new BufferedOutputStream(new FileOutputStream(out), 256 * 1024)) {
            writeHeader(os, totalFrames);
            long cumMs = 0;
            long written = 0;
            for (int i = 0; i < specs.size(); i++) {
                if (control.cancelled()) {
                    throw new IOException("Export cancelled.");
                }
                Spec spec = specs.get(i);
                cumMs += spec.durationMs;
                long endFrame = Math.round(cumMs * RATE / 1000.0);
                long sceneFrames = endFrame - written;

                short[] pcm = null;
                if (spec.path != null) {
                    try {
                        pcm = decode(spec.path, sceneFrames, control);
                    } catch (IOException e) {
                        throw e;
                    } catch (Exception e) {
                        throw new IOException("Could not read the narration of slide " + (i + 1)
                                + ": " + e.getMessage());
                    }
                    if (spec.clean) {
                        cleanVoice(pcm);
                    }
                    applyGain(pcm, spec.volume);
                }
                writeFrames(os, pcm, sceneFrames);
                written = endFrame;
                control.progress((int) ((i + 1) * 100L / specs.size()));
            }
        }
    }

    // ---- WAV output ----

    private static void writeHeader(OutputStream os, long frames) throws IOException {
        long dataBytes = frames * 2;
        ByteBuffer b = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN);
        b.put(new byte[]{'R', 'I', 'F', 'F'});
        b.putInt((int) (36 + dataBytes));
        b.put(new byte[]{'W', 'A', 'V', 'E'});
        b.put(new byte[]{'f', 'm', 't', ' '});
        b.putInt(16);
        b.putShort((short) 1);
        b.putShort((short) 1);
        b.putInt(RATE);
        b.putInt(RATE * 2);
        b.putShort((short) 2);
        b.putShort((short) 16);
        b.put(new byte[]{'d', 'a', 't', 'a'});
        b.putInt((int) dataBytes);
        os.write(b.array());
    }

    private static void writeFrames(OutputStream os, short[] pcm, long frames) throws IOException {
        final int chunk = 32768;
        byte[] bytes = new byte[chunk * 2];
        long done = 0;
        while (done < frames) {
            int n = (int) Math.min(chunk, frames - done);
            for (int i = 0; i < n; i++) {
                long idx = done + i;
                int v = (pcm != null && idx < pcm.length) ? pcm[(int) idx] : 0;
                bytes[i * 2] = (byte) (v & 0xFF);
                bytes[i * 2 + 1] = (byte) ((v >> 8) & 0xFF);
            }
            os.write(bytes, 0, n * 2);
            done += n;
        }
    }

    // ---- Decoding ----

    private static final class ShortList {
        short[] data = new short[1 << 16];
        int size;

        void add(short v) {
            if (size == data.length) {
                data = Arrays.copyOf(data, data.length * 2);
            }
            data[size++] = v;
        }
    }

    /** Decodes any audio file to mono 16-bit PCM at RATE, at most maxOutFrames long. */
    private static short[] decode(String path, long maxOutFrames, Control control)
            throws IOException {
        MediaExtractor extractor = new MediaExtractor();
        MediaCodec codec = null;
        try {
            extractor.setDataSource(path);
            int track = -1;
            MediaFormat format = null;
            for (int i = 0; i < extractor.getTrackCount(); i++) {
                MediaFormat f = extractor.getTrackFormat(i);
                String mime = f.getString(MediaFormat.KEY_MIME);
                if (mime != null && mime.startsWith("audio/")) {
                    track = i;
                    format = f;
                    break;
                }
            }
            if (track < 0 || format == null) {
                throw new IOException("The file has no sound.");
            }
            extractor.selectTrack(track);
            codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME));
            codec.configure(format, null, null, 0);
            codec.start();

            int srcRate = format.containsKey(MediaFormat.KEY_SAMPLE_RATE)
                    ? format.getInteger(MediaFormat.KEY_SAMPLE_RATE) : RATE;
            int channels = format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)
                    ? format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) : 1;

            ShortList mono = new ShortList();
            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
            boolean inDone = false;
            boolean outDone = false;
            while (!outDone) {
                if (control.cancelled()) {
                    throw new IOException("Export cancelled.");
                }
                if (!inDone) {
                    int ii = codec.dequeueInputBuffer(10000);
                    if (ii >= 0) {
                        ByteBuffer ib = codec.getInputBuffer(ii);
                        int size = ib == null ? -1 : extractor.readSampleData(ib, 0);
                        if (size < 0) {
                            codec.queueInputBuffer(ii, 0, 0, 0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                            inDone = true;
                        } else {
                            codec.queueInputBuffer(ii, 0, size, extractor.getSampleTime(), 0);
                            extractor.advance();
                        }
                    }
                }
                int oi = codec.dequeueOutputBuffer(info, 10000);
                if (oi >= 0) {
                    ByteBuffer ob = codec.getOutputBuffer(oi);
                    if (info.size > 0 && ob != null) {
                        ob.position(info.offset);
                        ob.limit(info.offset + info.size);
                        ShortBuffer sb = ob.order(ByteOrder.nativeOrder()).asShortBuffer();
                        int ch = Math.max(1, channels);
                        int frames = sb.remaining() / ch;
                        for (int f = 0; f < frames; f++) {
                            int sum = 0;
                            for (int c = 0; c < ch; c++) {
                                sum += sb.get();
                            }
                            mono.add((short) (sum / ch));
                        }
                    }
                    codec.releaseOutputBuffer(oi, false);
                    if ((info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        outDone = true;
                    }
                    long limit = (long) ((maxOutFrames + 2000) * (double) srcRate / RATE) + 1;
                    if (mono.size >= limit) {
                        outDone = true;
                    }
                } else if (oi == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    MediaFormat f = codec.getOutputFormat();
                    if (f.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        srcRate = f.getInteger(MediaFormat.KEY_SAMPLE_RATE);
                    }
                    if (f.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        channels = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT);
                    }
                }
            }
            return resample(mono.data, mono.size, srcRate, maxOutFrames);
        } finally {
            if (codec != null) {
                try {
                    codec.stop();
                } catch (Exception ignored) {
                    // nothing to do
                }
                try {
                    codec.release();
                } catch (Exception ignored) {
                    // nothing to do
                }
            }
            extractor.release();
        }
    }

    private static short[] resample(short[] src, int len, int srcRate, long maxOut) {
        if (srcRate <= 0) {
            srcRate = RATE;
        }
        if (srcRate == RATE) {
            return Arrays.copyOf(src, (int) Math.min(len, maxOut));
        }
        long outLen = Math.min((long) len * RATE / srcRate, maxOut);
        short[] out = new short[(int) outLen];
        double step = (double) srcRate / RATE;
        for (int j = 0; j < out.length; j++) {
            double pos = j * step;
            int i0 = (int) pos;
            double frac = pos - i0;
            int s0 = src[i0];
            int s1 = i0 + 1 < len ? src[i0 + 1] : s0;
            out[j] = (short) Math.round(s0 + (s1 - s0) * frac);
        }
        return out;
    }

    private static void applyGain(short[] pcm, float gain) {
        if (Math.abs(gain - 1f) < 0.001f) {
            return;
        }
        for (int i = 0; i < pcm.length; i++) {
            int v = Math.round(pcm[i] * gain);
            pcm[i] = (short) Math.max(Short.MIN_VALUE, Math.min(Short.MAX_VALUE, v));
        }
    }

    // ---- Voice cleaning: high-pass about 90 Hz, then a gentle noise gate ----

    private static void cleanVoice(short[] pcm) {
        if (pcm.length < RATE / 5) {
            return;
        }
        highPass(pcm, 90.0);
        gate(pcm);
    }

    private static void highPass(short[] pcm, double fc) {
        double w0 = 2.0 * Math.PI * fc / RATE;
        double cosw = Math.cos(w0);
        double alpha = Math.sin(w0) / (2.0 * 0.7071);
        double a0 = 1.0 + alpha;
        double b0 = ((1.0 + cosw) / 2.0) / a0;
        double b1 = (-(1.0 + cosw)) / a0;
        double b2 = b0;
        double a1 = (-2.0 * cosw) / a0;
        double a2 = (1.0 - alpha) / a0;
        double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
        for (int i = 0; i < pcm.length; i++) {
            double x0 = pcm[i];
            double y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
            x2 = x1;
            x1 = x0;
            y2 = y1;
            y1 = y0;
            long r = Math.round(y0);
            pcm[i] = (short) Math.max(Short.MIN_VALUE, Math.min(Short.MAX_VALUE, r));
        }
    }

    private static void gate(short[] pcm) {
        final int win = RATE / 50; // 20 ms
        int count = pcm.length / win;
        if (count < 10) {
            return;
        }
        float[] level = new float[count];
        for (int w = 0; w < count; w++) {
            double sum = 0;
            int base = w * win;
            for (int i = 0; i < win; i++) {
                double v = pcm[base + i];
                sum += v * v;
            }
            level[w] = (float) Math.sqrt(sum / win);
        }
        float[] sorted = level.clone();
        Arrays.sort(sorted);
        float floor = sorted[(int) (count * 0.10f)];
        float loud = sorted[(int) (count * 0.90f)];
        // Not enough difference between quiet and loud parts: leave the voice alone.
        if (loud < floor * 4f || loud < 400f) {
            return;
        }
        float openThr = Math.max(floor * 2.5f, 150f);
        openThr = Math.min(openThr, loud * 0.25f);
        float closeThr = openThr * 0.7f;

        boolean[] open = new boolean[count];
        boolean state = false;
        int hold = 0;
        final int holdWindows = 8; // 160 ms
        for (int w = 0; w < count; w++) {
            if (level[w] >= (state ? closeThr : openThr)) {
                state = true;
                hold = holdWindows;
            } else if (hold > 0) {
                hold--;
            } else {
                state = false;
            }
            open[w] = state;
        }
        // Open one window early so the start of a word is not cut.
        boolean[] target = new boolean[count];
        for (int w = 0; w < count; w++) {
            target[w] = open[w] || (w + 1 < count && open[w + 1]);
        }

        final float closedGain = 0.2f;
        double atk = 1.0 - Math.exp(-1.0 / (0.008 * RATE));
        double rel = 1.0 - Math.exp(-1.0 / (0.15 * RATE));
        double g = 1.0;
        for (int i = 0; i < pcm.length; i++) {
            int w = Math.min(count - 1, i / win);
            double t = target[w] ? 1.0 : closedGain;
            g += (t - g) * (t > g ? atk : rel);
            pcm[i] = (short) Math.round(pcm[i] * g);
        }
    }
}
