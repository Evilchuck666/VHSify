# VHSify technical guide

[Back to the project overview](README.md)

VHSify is two equivalent scripts, `vhsify.sh` (Bash 3.2+) and `vhsify.ps1`
(PowerShell 5.1+), that drive FFmpeg and SoX.

## Processing pipeline

### Step 0: **VHS FX (video)**
`ffmpeg -filter_complex` pipeline:
- Split into **Y/U/V** with `extractplanes`.
- Luma (Y) down/up: `scale=768:1080` → `scale=1920:1080`.
- Chroma (U/V) down/up: `scale=120:540` → `scale=960:540`.
- Recombine to **yuv420p** via `mergeplanes`.
- Tone & texture: `eq=saturation=0.75`, `noise=alls=5`, and a mild **horizontal jitter** in luma with `geq` + `random()`.

The output is always **1920×1080**, whatever the source resolution.

**Outputs:** `vhs.avi` (video only, **UTVideo**, tagged as `bt709`) and `audio.wav` (source audio as 48 kHz stereo PCM float).

### Step 1: **VHS FX (audio)**
Using **SoX**:
1. Synthesize **brown noise** for the full duration (queried via `ffprobe`). 48 kHz / 32‑bit float / stereo.
2. Mix original audio + noise with gains `inVol` and `outVol` (noise only if the video is silent).
3. Apply a **low‑pass** at **4 kHz**.

**Output:** `vhs.wav`.

### Step 2: **Final mux**
Combine `vhs.avi` (video) + `vhs.wav` (audio) without re‑encoding (`-c copy`) into `<name>_vhs.avi`.

### Step 3: **Cleanup**
Temporaries (`noise.wav`, `mix.wav`, `vhs.avi`, `vhs.wav`, `audio.wav`) are deleted, and the temp folder is removed even if something fails.

## Default constants

Defined at the top of both scripts (`UPPER_CASE` in `vhsify.sh`, `$global:camelCase` in `vhsify.ps1`).

| Variable          | Default     | Notes                                  |
|-------------------|-------------|----------------------------------------|
| `sampleRate`      | `48000`     | Audio sample rate (Hz)                 |
| `bitDepth`        | `32`        | Float processing depth                 |
| `channels`        | `2`         | Stereo                                 |
| `lowPassFreq`     | `4000`      | Low‑pass cutoff (Hz)                   |
| `inVol`           | `1.0`       | Gain for original track                |
| `outVol`          | `0.077`     | Gain for noise track                   |
| `db`              | `-22.75`    | For `dbVolume` computation             |
| `dbVolume`        | `10^(dB/20)`| Linear factor derived from `db`        |
| `vCodec`          | `utvideo`   | Lossless intermediate                  |
| `aCodec`          | `pcm_f32le` | Float PCM                              |
| `pixFmt`          | `yuv420p`   | Pixel format                           |
| `vidColorspace`   | `bt709`     | Colorimetry signaled on output         |

> Fine‑tune the look in `FFMPEG_FILTER` / `$global:ffmpegFilter` (saturation, noise amount, jitter magnitude, etc.).

## Post-processing

Lossless intermediates are **large** (easily several GB per minute of 1080p). Transcode after inspection:

**To H.264 (high quality):**
```sh
ffmpeg -i "clip_vhs.avi" -c:v libx264 -crf 16 -preset slow -c:a aac -b:a 192k "clip_vhs.mp4"
```
**To H.265/HEVC:**
```sh
ffmpeg -i "clip_vhs.avi" -c:v libx265 -crf 20 -preset slow -tag:v hvc1 -c:a aac -b:a 192k "clip_vhs_hevc.mp4"
```
**Remux to MKV (no re‑encode):**
```sh
ffmpeg -i "clip_vhs.avi" -c copy "clip_vhs.mkv"
```

> **macOS:** QuickTime can't play UTVideo AVI files. Use [IINA](https://iina.io) or [VLC](https://www.videolan.org), or transcode to H.264/HEVC as shown above.

## Troubleshooting

- **`ffprobe` returns `N/A`** → the source file or container is problematic. Try `ffmpeg -i input -c copy fixed.mkv`, then run the script again.
- **`ffmpeg`/`sox` not found** → install them (see [Requirements](README.md#-requirements)) and make sure they're in your `PATH`.
- **Paths with spaces** → always wrap them in quotes: `"My Videos/clip.mp4"`.
- **`Permission denied` on Linux/macOS** → `chmod +x vhsify.sh`, or run it as `bash vhsify.sh`.
- **"running scripts is disabled" on Windows** → `Unblock-File .\vhsify.ps1` or `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
- **Emoji/Unicode look broken on Windows** → use **PowerShell 7** in **Windows Terminal**.
- **`The "mapping" option is deprecated` warning** → harmless on recent FFmpeg; the old syntax is kept so the script also works with older FFmpeg versions.
- **Colorimetry looks off in some players** → remux to MKV: `ffmpeg -i clip_vhs.avi -c copy clip_vhs.mkv`.

## Releases

The [Test and release](.github/workflows/release.yaml) workflow runs both scripts on generated clips on **Ubuntu**, **macOS** (including the stock bash 3.2) and **Windows** (PowerShell 7 and 5.1) on every push and pull request.

To publish a release:
1. Bump `VERSION` in `vhsify.sh` and `$script:VhsifyVersion` in `vhsify.ps1`, then push to `main`.
2. Go to **Actions → Test and release → Run workflow** and enter the version (e.g. `1.0.1`, without the `v`).

The workflow tests everything, packages `VHSify-linux.tar.gz`, `VHSify-macos.tar.gz` and `VHSify-windows.zip`, generates `SHA256SUMS.txt`, and creates the `vX.Y.Z` tag and GitHub release with auto‑generated notes.
