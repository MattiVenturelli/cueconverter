# cueconverter

Docker container that monitors a folder and automatically splits `.cue` + `.flac` albums into individual tagged FLAC tracks.

## How it works

1. Polls the watched folder every 30 seconds for `.cue` files
2. Waits until both `.cue` and `.flac` haven't been modified for 60 seconds (to avoid processing incomplete downloads)
3. Splits the single `.flac` into individual tracks using `shnsplit`
4. Applies metadata (artist, title, track number) from the cue sheet using `cuetag`
5. Removes the original `.cue` and single `.flac`, keeping only the split tracks

## Usage

```bash
docker compose up -d
```

Edit `docker-compose.yml` to point the volume to your downloads folder:

```yaml
volumes:
  - /path/to/your/downloads:/watch
```

## Configuration

Environment variables:

| Variable | Default | Description |
|---|---|---|
| `POLL_INTERVAL` | `30` | Seconds between each scan |
| `STABLE_SECS` | `60` | Seconds a file must be unmodified before processing |

Example with custom values:

```yaml
environment:
  - POLL_INTERVAL=15
  - STABLE_SECS=120
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
