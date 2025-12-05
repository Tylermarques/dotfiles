#!/usr/bin/env python3
"""
import_sd.py - Import files from an SD card, group them by trip based on
2-day gaps in capture times, rsync to a remote directory, then clean up and unmount.
"""

import os
import subprocess
import argparse
import platform
import re
import json
from datetime import datetime, timedelta
from pathlib import Path
from collections import Counter

# Supported media file extensions
MEDIA_EXTS = {
    # DJI Raw and info files
    ".DNG",
    ".LRF",
    ".SRT",
    ".jpg",
    ".jpeg",
    ".png",
    ".mp4",
    ".mov",
    ".avi",
    ".heic",
    ".cr2",
    ".nef",
    ".orf",
    ".rw2",
}


def detect_sd_cards():
    """Detect SD cards on Linux and Mac systems."""
    system = platform.system()
    candidates = []

    if system == "Linux":
        # Check for removable storage devices
        try:
            result = subprocess.run(
                ["lsblk", "-o", "NAME,SIZE,TYPE,MOUNTPOINT,REMOVABLE", "-J"],
                capture_output=True,
                text=True,
                check=True,
            )
            import json

            data = json.loads(result.stdout)

            for device in data.get("blockdevices", []):
                if device.get("removable") == "1" and device.get("type") == "disk":
                    for child in device.get("children", []):
                        if child.get("type") == "part":
                            name = child["name"]
                            size = child.get("size", "unknown")
                            mountpoint = child.get("mountpoint")
                            candidates.append(
                                {
                                    "device": f"/dev/{name}",
                                    "size": size,
                                    "mountpoint": mountpoint,
                                    "description": f"Removable device {name} ({size})",
                                }
                            )
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            # Fallback: check /sys/block for removable devices
            try:
                for block_device in Path("/sys/block").glob("*"):
                    removable_file = block_device / "removable"
                    if removable_file.exists():
                        with open(removable_file) as f:
                            if f.read().strip() == "1":
                                device_name = block_device.name
                                # Look for partitions
                                for partition in block_device.glob(f"{device_name}*"):
                                    if partition.name != device_name:
                                        candidates.append(
                                            {
                                                "device": f"/dev/{partition.name}",
                                                "size": "unknown",
                                                "mountpoint": None,
                                                "description": f"Removable device {partition.name}",
                                            }
                                        )
            except Exception:
                pass

    elif system == "Darwin":  # macOS
        try:
            # Get all disks
            result = subprocess.run(
                ["diskutil", "list", "-plist"],
                capture_output=True,
                text=True,
                check=True,
            )

            # Parse the plist output
            try:
                import plistlib

                data = plistlib.loads(result.stdout.encode())

                for disk_info in data.get("AllDisks", []):
                    # Get detailed info about each disk
                    info_result = subprocess.run(
                        ["diskutil", "info", "-plist", disk_info],
                        capture_output=True,
                        text=True,
                        check=True,
                    )
                    disk_data = plistlib.loads(info_result.stdout.encode())

                    # Look for removable media (SD cards, USB drives, etc.)
                    if (
                        disk_data.get("Removable")
                        or disk_data.get("External")
                        or "SD" in disk_data.get("MediaName", "").upper()
                    ):
                        device_id = disk_data.get("DeviceIdentifier", "")
                        size = disk_data.get("TotalSize", 0)
                        size_str = (
                            f"{size // (1024**3):.1f}GB" if size > 0 else "unknown"
                        )
                        media_name = disk_data.get("MediaName", "Unknown")
                        mount_point = disk_data.get("MountPoint")

                        candidates.append(
                            {
                                "device": f"/dev/{device_id}",
                                "size": size_str,
                                "mountpoint": mount_point,
                                "description": f"{media_name} ({size_str})",
                            }
                        )

            except Exception:
                # Fallback: use diskutil list with text parsing
                result = subprocess.run(
                    ["diskutil", "list"], capture_output=True, text=True, check=True
                )

                lines = result.stdout.split("\n")
                for line in lines:
                    if re.search(r"external|removable", line.lower()):
                        match = re.search(r"(/dev/disk\d+)", line)
                        if match:
                            device = match.group(1)
                            candidates.append(
                                {
                                    "device": device,
                                    "size": "unknown",
                                    "mountpoint": None,
                                    "description": f"External device {device}",
                                }
                            )

        except subprocess.CalledProcessError:
            pass

    return candidates


def select_sd_card(candidates):
    """Present SD card options to user and get selection."""
    if not candidates:
        print("No SD cards detected.")
        return None

    print("Detected SD cards:")
    for i, card in enumerate(candidates, 1):
        mount_info = (
            f" (mounted at {card['mountpoint']})"
            if card["mountpoint"]
            else " (not mounted)"
        )
        print(f"{i}. {card['description']}{mount_info}")

    while True:
        try:
            choice = input(
                f"\nSelect SD card (1-{len(candidates)}) or 'q' to quit: "
            ).strip()
            if choice.lower() == "q":
                return None

            idx = int(choice) - 1
            if 0 <= idx < len(candidates):
                selected = candidates[idx]
                confirm = (
                    input(f"Use {selected['description']}? (y/n): ").strip().lower()
                )
                if confirm in ["y", "yes"]:
                    return selected
                else:
                    continue
            else:
                print(f"Please enter a number between 1 and {len(candidates)}")
        except ValueError:
            print("Invalid input. Please enter a number or 'q' to quit.")
        except KeyboardInterrupt:
            print("\nOperation cancelled.")
            return None


def parse_args():
    parser = argparse.ArgumentParser(
        description="Import SD card, group media by trip, and rsync to remote."
    )
    parser.add_argument(
        "device",
        nargs="?",
        help="SD card device node (e.g., /dev/sdb1). If not specified, will auto-detect.",
    )
    parser.add_argument(
        "--mount-point", default="/mnt/sdcard", help="Local mount point for the SD card"
    )
    parser.add_argument(
        "--remote-user", default="tyler", help="SSH user for remote host"
    )
    parser.add_argument(
        "--remote-host", default="proxmox", help="Remote host to rsync to"
    )
    parser.add_argument(
        "--remote-dir",
        default="/main/plex/library/personal/imports/",
        help="Remote directory to import into",
    )
    parser.add_argument(
        "--threshold-days",
        type=int,
        default=2,
        help="Day gap threshold to start a new trip",
    )
    return parser.parse_args()


def mount_sd(device, mount_point):
    if not mount_point.exists():
        subprocess.run(["sudo", "mkdir", "-p", str(mount_point)], check=True)
    if not os.path.ismount(str(mount_point)):
        subprocess.run(["sudo", "mount", device, str(mount_point)], check=True)


def unmount_sd(mount_point):
    if os.path.ismount(str(mount_point)):
        subprocess.run(["sudo", "umount", str(mount_point)], check=True)


def get_timestamp(file_path):
    # Currently using filesystem modification time;
    # could be extended to use EXIF for images.
    return datetime.fromtimestamp(file_path.stat().st_mtime)


def extract_gps_from_exif(file_path):
    """Extract GPS coordinates from image EXIF data using exiftool."""
    try:
        result = subprocess.run(
            ["exiftool", "-ee", "-json", str(file_path)],
            capture_output=True,
            text=True,
            check=True,
        )

        data = json.loads(result.stdout)
        if not data:
            return None

        exif_data = data[0]

        # Check for GPS coordinates in DMS format
        lat_dms = exif_data.get("GPSLatitude")
        lon_dms = exif_data.get("GPSLongitude")

        if lat_dms and lon_dms:
            # Parse DMS format like "47 deg 9' 38.60\" N"
            lat_decimal = parse_dms_to_decimal(lat_dms)
            lon_decimal = parse_dms_to_decimal(lon_dms)

            if lat_decimal is not None and lon_decimal is not None:
                return {
                    "latitude": lat_decimal,
                    "longitude": lon_decimal,
                    "file": file_path,
                }

    except (subprocess.CalledProcessError, json.JSONDecodeError, KeyError):
        pass

    return None


def parse_dms_to_decimal(dms_string):
    """Convert DMS format like '47 deg 9' 38.60\" N' to decimal degrees."""
    try:
        # Remove quotes and split by spaces
        parts = dms_string.replace('"', '').replace("'", '').split()

        # Extract degrees, minutes, seconds, and direction
        degrees = float(parts[0])
        minutes = float(parts[2])
        seconds = float(parts[3])
        direction = parts[4] if len(parts) > 4 else parts[-1]

        # Convert to decimal
        decimal = degrees + minutes/60 + seconds/3600

        # Apply direction (negative for South/West)
        if direction in ['S', 'W']:
            decimal = -decimal

        return decimal

    except (ValueError, IndexError):
        return None


def reverse_geocode(latitude, longitude):
    """Convert GPS coordinates to location name using Nominatim API."""
    try:
        import urllib.request
        import urllib.parse

        # Use Nominatim (OpenStreetMap) API for reverse geocoding
        url = "https://nominatim.openstreetmap.org/reverse"
        params = {
            "format": "json",
            "lat": latitude,
            "lon": longitude,
            "addressdetails": 1,
            "accept-language": "en",
        }

        query_string = urllib.parse.urlencode(params)
        full_url = f"{url}?{query_string}"

        req = urllib.request.Request(full_url)
        req.add_header("User-Agent", "SD Card Import Script")

        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode())

            address = data.get("address", {})

            # Try to get a good location name in order of preference
            location_parts = []

            # City/town level
            city = (
                address.get("city")
                or address.get("town")
                or address.get("village")
                or address.get("municipality")
            )

            # State/region level
            state = (
                address.get("state") or address.get("province") or address.get("region")
            )

            # Country level
            country = address.get("country")

            # Build location name
            if city:
                location_parts.append(city)
            if state and state != city:
                location_parts.append(state)
            if country and len(location_parts) == 0:
                location_parts.append(country)

            if location_parts:
                return "_".join(location_parts).replace(" ", "_")

    except Exception:
        pass

    return None


def analyze_trip_locations(trip_files):
    """Analyze GPS data from trip files and suggest a location-based name."""
    locations = []

    # Extract GPS data from image and video files
    for file_path, _ in trip_files:
        if file_path.suffix.lower() in {
            ".jpg",
            ".jpeg",
            ".heic",
            ".cr2",
            ".nef",
            ".orf",
            ".rw2",
            ".mp4",
            ".mov",
            ".avi",
        }:
            gps_data = extract_gps_from_exif(file_path)
            if gps_data:
                location = reverse_geocode(gps_data["latitude"], gps_data["longitude"])
                if location:
                    locations.append(location)

    if not locations:
        return None

    # Find the most common location
    location_counts = Counter(locations)
    most_common_location = location_counts.most_common(1)[0][0]

    # If multiple locations, use the most common one
    if len(location_counts) > 1:
        return f"{most_common_location}_trip"
    else:
        return most_common_location


def group_media_files(mount_point, threshold_days):
    # Recursively gather media files
    files = [
        p
        for p in mount_point.rglob("*")
        if p.is_file() and p.suffix.lower() in MEDIA_EXTS
    ]
    if not files:
        return []
    # Pair with timestamps and sort
    files_ts = sorted([(get_timestamp(p), p) for p in files], key=lambda x: x[0])
    threshold = timedelta(days=threshold_days)
    trips = []
    current_trip = []
    last_ts = None
    for ts, fp in files_ts:
        if last_ts is None or (ts - last_ts) <= threshold:
            # If we're below threshold, add to current trip
            current_trip.append((fp, ts))
        else:
            # Above threshold, create new trip
            trips.append(current_trip)
            current_trip = [(fp, ts)]
        last_ts = ts
    if current_trip:
        trips.append(current_trip)
    return trips


def organize_trips(trips, mount_point):
    trip_dirs = []
    for idx, trip in enumerate(trips, start=1):
        start_ts = trip[0][1]
        end_ts = trip[-1][1]

        # Try to get location-based name
        print(f"Analyzing location data for trip {idx}...")
        location_name = analyze_trip_locations(trip)

        if location_name:
            # Use location-based name with date range
            dir_name = f"{location_name}_{start_ts.strftime('%Y%m%d')}_{end_ts.strftime('%Y%m%d')}"
            print(f"Trip {idx} location detected: {location_name}")
        else:
            # Fall back to date-based naming
            dir_name = (
                f"trip_{idx}_{start_ts.strftime('%Y%m%d')}_{end_ts.strftime('%Y%m%d')}"
            )
            print(f"Trip {idx} location detection failed, using date-based name")

        dest = mount_point / dir_name
        dest.mkdir(exist_ok=True)
        for fp, ts in trip:
            target = dest / fp.name
            if target.exists():
                target = dest / f"{ts.strftime('%Y%m%d_%H%M%S')}_{fp.name}"
            fp.rename(target)
        trip_dirs.append(dir_name)
    return trip_dirs


def rsync_and_cleanup(mount_point, remote_user, remote_host, remote_dir):
    src = str(mount_point) + "/"
    dest = f"{remote_user}@{remote_host}:{remote_dir}"
    cmd = [
        "rsync",
        "-avh",
        "--progress",
        "--prune-empty-dirs",
        src,
        dest,
    ]
    subprocess.run(cmd, check=True)
    # Remove any leftover empty directories
    for dirpath, dirs, files in os.walk(str(mount_point), topdown=False):
        if not dirs and not files:
            pass  # os.rmdir(dirpath)


def main():
    args = parse_args()
    mount_point = Path(args.mount_point)

    # Determine the device to use
    if args.device:
        device = args.device
        selected_card = None
        print(f"Using specified device: {device}")
    else:
        print("Auto-detecting SD cards...")
        candidates = detect_sd_cards()
        selected_card = select_sd_card(candidates)
        if not selected_card:
            print("No SD card selected. Exiting.")
            return
        device = selected_card["device"]
        print(f"Selected device: {device}")

    # Check if device is already mounted and use existing mount point
    already_mounted = False
    if selected_card and selected_card["mountpoint"]:
        mount_point = Path(selected_card["mountpoint"])
        already_mounted = True
        print(f"Device already mounted at: {mount_point}")
    else:
        # Check if manually specified device is already mounted
        try:
            result = subprocess.run(
                ["mount"], capture_output=True, text=True, check=True
            )
            for line in result.stdout.split("\n"):
                if device in line:
                    # Extract mount point from mount output
                    parts = line.split()
                    if len(parts) >= 3 and parts[0] == device:
                        existing_mount = parts[2]
                        mount_point = Path(existing_mount)
                        already_mounted = True
                        print(f"Device already mounted at: {mount_point}")
                        break
        except subprocess.CalledProcessError:
            pass

    try:
        if not already_mounted:
            print(f"Mounting {device} on {mount_point}…")
            mount_sd(device, mount_point)
        else:
            print(f"Using existing mount point: {mount_point}")

        print("Grouping media files into trips…")
        trips = group_media_files(mount_point, args.threshold_days)
        if not trips:
            print("No media files found. Exiting.")
            return

        trip_dirs = organize_trips(trips, mount_point)
        print(f"Organized into {len(trip_dirs)} trip(s): {trip_dirs}")

        print(f"Starting rsync to {args.remote_host}…")
        rsync_and_cleanup(
            mount_point, args.remote_user, args.remote_host, args.remote_dir
        )
        print("Rsync and cleanup complete.")
    finally:
        if not already_mounted:
            print(f"Unmounting {mount_point}…")
            unmount_sd(mount_point)
        else:
            print(f"Leaving {mount_point} mounted (was already mounted)")


if __name__ == "__main__":
    main()
