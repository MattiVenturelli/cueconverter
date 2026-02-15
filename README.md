# cueconverter

Docker container that monitors a folder and automatically splits `.cue` + `.flac` albums into individual tagged FLAC tracks.

## How it works

1. Polls the watched folder every 30 seconds for `.cue` files
2. Only processes directories containing a `.complete` marker file (created by your torrent client when the download finishes)
3. Verifies FLAC integrity before splitting
4. Splits the single `.flac` into individual tracks using `shnsplit`
5. Applies metadata (artist, title, track number) from the cue sheet using `cuetag`
6. Removes the original `.cue`, single `.flac`, and `.complete` marker

## Usage

```bash
docker compose up -d
```

Edit `docker-compose.yml` to point the volume to your downloads folder:

```yaml
volumes:
  - /path/to/your/downloads:/watch
```

### qBittorrent setup

In **Settings → Downloads → Run external program → Run on torrent finished**:

```
touch "%F/.complete"
```

This creates a `.complete` marker file when a torrent finishes downloading. The container will only process directories that contain this marker.

## Configuration

Environment variables:

| Variable | Default | Description |
|---|---|---|
| `POLL_INTERVAL` | `30` | Seconds between each scan |
| `MARKER` | `.complete` | Marker filename to look for |

Example with custom values:

```yaml
environment:
  - POLL_INTERVAL=15
  - MARKER=.done
```

## FLAC matching

The container finds the associated `.flac` file in this order:

1. `FILE` directive inside the `.cue` sheet
2. Same filename as the `.cue` (e.g. `album.cue` → `album.flac`)
3. Only `.flac` file in the directory

Cue sheets that don't reference a `.flac` source (e.g. `.wav` cue sheets) are skipped automatically.

## Build

```bash
docker build -t cueconverter .
```
