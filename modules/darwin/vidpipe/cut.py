#!/usr/bin/env python3
"""Turn ffmpeg silencedetect output into a select/aselect expression that keeps the speech.

Usage: cut.py SILENCE_LOG --duration SECONDS --pad SECONDS --out EXPR_FILE
"""
import argparse
import re
import sys


def parse_silences(text, duration):
    """Return [(start, end)] pairs from silencedetect's log lines."""
    silences, current = [], None
    for line in text.splitlines():
        m = re.search(r"silence_start: (-?\d+(?:\.\d+)?)", line)
        if m:
            current = max(0.0, float(m.group(1)))
            continue
        m = re.search(r"silence_end: (-?\d+(?:\.\d+)?)", line)
        if m and current is not None:
            silences.append((current, min(float(m.group(1)), duration)))
            current = None
    if current is not None:  # silence runs to the end of the file
        silences.append((current, duration))
    return silences


def cut_regions(silences, duration, pad):
    """Shrink each silence by `pad` on both sides so a little natural air stays."""
    regions = []
    for start, end in silences:
        a = 0.0 if start <= 0.01 else start + pad
        b = duration if end >= duration - 0.01 else end - pad
        if b - a > 0.05:
            regions.append((a, b))
    return regions


def keep_segments(regions, duration):
    """Everything that is not a cut region."""
    keep, cursor = [], 0.0
    for a, b in regions:
        if a - cursor > 0.05:
            keep.append((cursor, a))
        cursor = b
    if duration - cursor > 0.05:
        keep.append((cursor, duration))
    return keep


def fmt(t):
    minutes, seconds = divmod(int(round(t)), 60)
    return f"{minutes}:{seconds:02d}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--duration", type=float, required=True)
    ap.add_argument("--pad", type=float, default=0.25)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    with open(args.log, errors="replace") as fh:
        text = fh.read()

    silences = parse_silences(text, args.duration)
    regions = cut_regions(silences, args.duration, args.pad)
    keep = keep_segments(regions, args.duration)

    if not keep:
        print("    everything looked like silence; keeping the whole video "
              "(try a lower --threshold, e.g. -45)", file=sys.stderr)
        keep, regions = [(0.0, args.duration)], []

    expr = "+".join(f"between(t,{a:.3f},{b:.3f})" for a, b in keep)
    with open(args.out, "w") as fh:
        fh.write(expr)

    kept = sum(b - a for a, b in keep)
    print(f"    kept {fmt(kept)} of {fmt(args.duration)}: "
          f"removed {fmt(args.duration - kept)} across {len(regions)} pauses")


if __name__ == "__main__":
    main()
