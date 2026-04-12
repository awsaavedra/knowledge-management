#!/usr/bin/env python3
"""Convert PNG, JPG, JPEG, and static GIF images in the vault attachments/ to WebP.

Animated GIFs are skipped (WebP animation is often larger).
Originals are deleted after successful conversion.
Wikilinks (![[file.png]]) in vault notes are updated to the new .webp filename.
Already-converted files (where .webp exists) are skipped.

Usage:
    python3 scripts/compress-images.py              # convert all
    python3 scripts/compress-images.py --dry-run    # preview what would change
    python3 scripts/compress-images.py --keep       # convert but keep originals
"""

import argparse
import glob
import os
import re

from PIL import Image

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_PROJECT_DIR = os.path.dirname(_SCRIPT_DIR)
_DEFAULT_VAULT = os.path.join(os.path.dirname(_PROJECT_DIR), "knowledge-management-system")
VAULT_DIR = os.environ.get("OBSIDIAN_VAULT", _DEFAULT_VAULT)
ATTACHMENTS_DIR = os.path.join(VAULT_DIR, "attachments")
EXTENSIONS = ("*.png", "*.jpg", "*.jpeg", "*.gif")
QUALITY = 80
NOTE_DIRS = ("daily", "inbox")


def is_animated_gif(path):
    try:
        img = Image.open(path)
        return getattr(img, "n_frames", 1) > 1
    except Exception:
        return False


def update_wikilinks(old_name, new_name, dry_run=False):
    """Replace ![[old_name]] with ![[new_name]] across all vault notes."""
    count = 0
    for subdir in NOTE_DIRS:
        note_dir = os.path.join(VAULT_DIR, subdir)
        if not os.path.isdir(note_dir):
            continue
        for md_path in glob.glob(os.path.join(note_dir, "**", "*.md"), recursive=True):
            with open(md_path, "r") as f:
                content = f.read()
            # Match ![[old_name]] and [[old_name]] (with or without !)
            pattern = re.escape(old_name)
            if pattern not in content:
                continue
            updated = content.replace(old_name, new_name)
            if not dry_run:
                with open(md_path, "w") as f:
                    f.write(updated)
            count += 1
            rel = os.path.relpath(md_path, VAULT_DIR)
            action = "WOULD UPDATE" if dry_run else "UPDATED"
            print(f"    {action} link in {rel}")
    return count


def convert_image(path, dry_run=False, keep=False):
    name, ext = os.path.splitext(path)
    out = name + ".webp"
    old_basename = os.path.basename(path)
    new_basename = os.path.basename(out)

    if os.path.exists(out):
        return None  # already converted

    if path.lower().endswith(".gif") and is_animated_gif(path):
        return "skip-animated"

    if dry_run:
        update_wikilinks(old_basename, new_basename, dry_run=True)
        return "would-convert"

    img = Image.open(path)
    img.save(out, "webp", quality=QUALITY)

    old_size = os.path.getsize(path)
    new_size = os.path.getsize(out)

    update_wikilinks(old_basename, new_basename)

    if not keep:
        os.remove(path)

    return (old_size, new_size)


def main():
    parser = argparse.ArgumentParser(
        description="Convert images in vault attachments/ to WebP"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Preview without converting"
    )
    parser.add_argument(
        "--keep", action="store_true", help="Keep originals after conversion"
    )
    args = parser.parse_args()

    if not os.path.isdir(ATTACHMENTS_DIR):
        print(f"Attachments dir not found: {ATTACHMENTS_DIR}")
        return

    total_old = 0
    total_new = 0
    converted = 0
    skipped_animated = 0
    skipped_existing = 0

    for ext in EXTENSIONS:
        for path in sorted(
            glob.glob(os.path.join(ATTACHMENTS_DIR, "**", ext), recursive=True)
        ):
            result = convert_image(path, dry_run=args.dry_run, keep=args.keep)

            if result is None:
                skipped_existing += 1
            elif result == "skip-animated":
                print(
                    f"  SKIP (animated): {os.path.relpath(path, ATTACHMENTS_DIR)}"
                )
                skipped_animated += 1
            elif result == "would-convert":
                print(
                    f"  WOULD CONVERT:   {os.path.relpath(path, ATTACHMENTS_DIR)}"
                )
            else:
                old_size, new_size = result
                reduction = 100 * (1 - new_size / old_size) if old_size else 0
                print(
                    f"  {os.path.relpath(path, ATTACHMENTS_DIR)} -> .webp  "
                    f"({old_size:,} -> {new_size:,}, {reduction:.0f}% reduction)"
                )
                total_old += old_size
                total_new += new_size
                converted += 1

    print()
    if args.dry_run:
        print("Dry run complete. No files were modified.")
    elif converted:
        reduction = 100 * (1 - total_new / total_old) if total_old else 0
        print(
            f"Converted {converted} images: {total_old:,} -> {total_new:,} bytes "
            f"({reduction:.0f}% total reduction)"
        )
    else:
        print("No images to convert.")

    if skipped_animated:
        print(f"Skipped {skipped_animated} animated GIF(s).")
    if skipped_existing:
        print(f"Skipped {skipped_existing} already-converted file(s).")


if __name__ == "__main__":
    main()
