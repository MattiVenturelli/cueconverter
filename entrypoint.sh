#!/bin/bash
set -euo pipefail

POLL_INTERVAL="${POLL_INTERVAL:-30}"
MARKER="${MARKER:-.complete}"
PROCESSED_LIST="/tmp/processed_cues"
FAILED_LIST="/tmp/failed_cues"
touch "$PROCESSED_LIST" "$FAILED_LIST"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

process_cue() {
    local cue_file="$1"
    local dir
    dir="$(dirname "$cue_file")"

    # Skip cue files that don't reference a .flac source
    if ! grep -q '^FILE.*\.flac' "$cue_file"; then
        log "Skipping $cue_file (does not reference a .flac file)"
        echo "$cue_file" >> "$PROCESSED_LIST"
        return 0
    fi

    # Skip if download is not complete (no marker file)
    if [ ! -f "$dir/$MARKER" ]; then
        return 0
    fi

    # Lock per directory to prevent concurrent splits on the same .flac
    local lockfile="$dir/.cueconverter.lock"
    if [ -f "$lockfile" ]; then
        log "Skipping $cue_file (another conversion is in progress in this directory)"
        return 0
    fi
    touch "$lockfile"
    trap "rm -f '$lockfile'" RETURN

    # Find the associated .flac file
    # Strategy: 1) parse FILE directive from cue sheet, 2) same basename, 3) single .flac in dir
    local flac_file=""

    # 1) Extract filename from FILE directive in cue sheet
    local cue_ref
    cue_ref=$(grep -m1 '^FILE ' "$cue_file" | sed 's/^FILE "\(.*\)".*/\1/')
    if [[ -n "$cue_ref" && -f "$dir/$cue_ref" ]]; then
        flac_file="$dir/$cue_ref"
    fi

    # 2) Try same basename as cue file
    if [[ -z "$flac_file" ]]; then
        local base
        base="$(basename "$cue_file" .cue)"
        if [[ -f "$dir/$base.flac" ]]; then
            flac_file="$dir/$base.flac"
        fi
    fi

    # 3) Fallback: single .flac in directory
    if [[ -z "$flac_file" ]]; then
        local flac_count
        flac_count=$(find "$dir" -maxdepth 1 -name '*.flac' -type f | wc -l)
        if [[ "$flac_count" -eq 1 ]]; then
            flac_file=$(find "$dir" -maxdepth 1 -name '*.flac' -type f)
        fi
    fi

    if [[ -z "$flac_file" || ! -f "$flac_file" ]]; then
        log "ERROR: No matching .flac file found for $cue_file"
        return 1
    fi

    # Verify FLAC integrity before splitting
    log "Verifying: $flac_file"
    if ! flac --test --silent "$flac_file" 2>/dev/null; then
        log "ERROR: FLAC integrity check failed for $flac_file (corrupt or incomplete)"
        echo "$cue_file" >> "$FAILED_LIST"
        return 1
    fi

    log "Splitting: $flac_file using $cue_file"

    # Split the flac file into individual tracks
    if ! shnsplit -f "$cue_file" -t "%n - %t" -o flac -d "$dir" "$flac_file"; then
        log "ERROR: shnsplit failed for $cue_file"
        return 1
    fi

    # Apply metadata from cue sheet to split tracks
    local split_tracks
    split_tracks=$(find "$dir" -maxdepth 1 -name '[0-9][0-9] - *.flac' -type f | sort)

    if [[ -z "$split_tracks" ]]; then
        log "ERROR: No split tracks found after shnsplit"
        return 1
    fi

    if ! cuetag.sh "$cue_file" $split_tracks; then
        log "WARNING: cuetag failed, tracks were split but may lack metadata"
    fi

    # Mark as processed before deleting
    echo "$cue_file" >> "$PROCESSED_LIST"

    # Remove original files and other cue/log files
    log "Removing original files"
    rm -f "$flac_file" "$dir/$MARKER"
    find "$dir" -maxdepth 1 -name '*.cue' -type f -exec sh -c 'echo "$1" >> "'"$PROCESSED_LIST"'"' _ {} \; -delete
    # Remove pregap track if present
    rm -f "$dir/00 - pregap.flac"

    log "Done processing: $cue_file"
}

log "Starting cueconverter - polling /watch every ${POLL_INTERVAL}s (marker: $MARKER)"

while true; do
    find /watch -name '*.cue' -type f | while read -r cue_file; do
        # Skip already processed files
        if grep -qFx "$cue_file" "$PROCESSED_LIST" "$FAILED_LIST" 2>/dev/null; then
            continue
        fi
        process_cue "$cue_file" || true
    done
    sleep "$POLL_INTERVAL"
done
