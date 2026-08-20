#!/usr/bin/env python3
"""Generate an RX 9070 XT-accelerated hover-preview video gallery."""

from __future__ import annotations

import argparse
import hashlib
import html
import http.server
import json
import math
import mimetypes
import os
import shutil
import subprocess
import tempfile
import time
import urllib.parse
import webbrowser
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import asdict, dataclass
from functools import partial
from pathlib import Path
from typing import Any


VIDEO_EXTENSIONS = {
    ".avi", ".flv", ".m4v", ".mkv", ".mov", ".mp4", ".mpeg", ".mpg",
    ".webm", ".wmv",
}
CACHE_VERSION = 3
ENCODE_PROFILE = "rx9070xt-av1-vaapi-v1"


@dataclass(frozen=True)
class PreviewConfig:
    width: int
    segments: int
    segment_length: float
    fps: int
    thumbnail_percent: int
    quality: int
    device: str
    repair_on_error: bool
    repair_quality: int


@dataclass(frozen=True)
class OrphanGroup:
    source: Path
    cache: Path
    artifacts: tuple[Path, ...]
    total_size: int


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed < 1:
        raise argparse.ArgumentTypeError("must be at least 1")
    return parsed


def positive_float(value: str) -> float:
    parsed = float(value)
    if not math.isfinite(parsed) or parsed <= 0:
        raise argparse.ArgumentTypeError("must be a positive finite number")
    return parsed


def percentage(value: str) -> int:
    parsed = int(value)
    if not 0 <= parsed <= 100:
        raise argparse.ArgumentTypeError("must be between 0 and 100")
    return parsed


def av1_quality(value: str) -> int:
    parsed = int(value)
    if not 1 <= parsed <= 63:
        raise argparse.ArgumentTypeError("must be between 1 and 63")
    return parsed


def even(value: int) -> int:
    return value if value % 2 == 0 else value + 1


def ffmpeg_environment() -> dict[str, str]:
    environment = os.environ.copy()
    # This host globally requests the NVIDIA VAAPI driver despite using amdgpu.
    # Keep the correction local to the FFmpeg children.
    environment["LIBVA_DRIVER_NAME"] = "radeonsi"
    return environment


def run_command(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
        env=ffmpeg_environment(),
    )


def video_duration(path: Path) -> float | None:
    try:
        result = run_command([
            "ffprobe", "-v", "error", "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1", str(path),
        ])
        duration = float(result.stdout.strip())
        return duration if math.isfinite(duration) and duration > 0 else None
    except (OSError, subprocess.CalledProcessError, ValueError):
        return None


def video_stream_metadata(path: Path, duration: float) -> dict[str, Any]:
    stat = path.stat()
    stream: dict[str, Any] = {}
    try:
        result = run_command([
            "ffprobe", "-v", "error", "-select_streams", "v:0",
            "-show_entries", "stream=codec_name,width,height",
            "-of", "json", str(path),
        ])
        payload = json.loads(result.stdout)
        streams = payload.get("streams", [])
        if streams and isinstance(streams[0], dict):
            stream = streams[0]
    except (AttributeError, OSError, subprocess.CalledProcessError, ValueError, json.JSONDecodeError):
        pass
    return {
        "size": stat.st_size,
        "mtime": stat.st_mtime,
        "mtime_ns": stat.st_mtime_ns,
        "duration": duration,
        "codec": str(stream.get("codec_name", "unknown")).lower(),
        "width": int(stream.get("width") or 0),
        "height": int(stream.get("height") or 0),
        "extension": path.suffix.lower().removeprefix("."),
    }


def valid_metadata(value: Any) -> bool:
    if not isinstance(value, dict):
        return False
    try:
        return (
            int(value.get("size", 0)) > 0
            and float(value.get("mtime", 0)) > 0
            and float(value.get("duration", 0)) > 0
            and int(value.get("width", 0)) > 0
            and int(value.get("height", 0)) > 0
            and str(value.get("codec", "unknown")).lower() != "unknown"
        )
    except (TypeError, ValueError):
        return False


def asset_id(path: Path) -> str:
    return hashlib.sha256(os.fsencode(path.resolve())).hexdigest()[:16]


def output_paths(video: Path, output_directory: Path) -> tuple[Path, Path, Path, Path, Path]:
    suffix = hashlib.sha256(os.fsencode(video.name)).hexdigest()[:10]
    basename = f"{video.stem}-{suffix}"
    return (
        output_directory / f"{basename}.jpg",
        output_directory / f"{basename}.av1.webm",
        output_directory / f"{basename}.cache.json",
        output_directory / f"{basename}.repaired.mkv",
        output_directory / f"{basename}.repair.log",
    )


def cache_payload(video: Path, config: PreviewConfig) -> dict[str, Any]:
    stat = video.stat()
    preview_config = asdict(config)
    preview_config.pop("repair_on_error")
    preview_config.pop("repair_quality")
    return {
        "version": CACHE_VERSION,
        "profile": ENCODE_PROFILE,
        "source": {
            "path": str(video.resolve()),
            "size": stat.st_size,
            "mtime_ns": stat.st_mtime_ns,
        },
        "config": preview_config,
    }


def read_current_cache(
    cache_path: Path,
    thumbnail_path: Path,
    preview_path: Path,
    repaired_path: Path,
    expected: dict[str, Any],
    config: PreviewConfig,
) -> dict[str, Any] | None:
    try:
        cached = json.loads(cache_path.read_text(encoding="utf-8"))
        if not isinstance(cached, dict):
            return None
        cached_key = cached.get("key")
        if not isinstance(cached_key, dict):
            return None
        normalized_key = dict(cached_key)
        cached_config = normalized_key.get("config")
        if not isinstance(cached_config, dict):
            return None
        cached_config = dict(cached_config)
        legacy_repair_quality = cached_config.pop("repair_quality", None)
        cached_config.pop("repair_on_error", None)
        normalized_key["config"] = cached_config
        used_repair = bool(cached.get("used_repair"))
        repaired_quality = cached.get("repair_quality", legacy_repair_quality)
        if (
            normalized_key != expected
            or thumbnail_path.stat().st_size == 0
            or preview_path.stat().st_size == 0
            or (used_repair and repaired_path.stat().st_size == 0)
            or (used_repair and not config.repair_on_error)
            or (used_repair and repaired_quality != config.repair_quality)
            or not math.isfinite(float(cached.get("duration", 0)))
            or float(cached.get("duration", 0)) <= 0
        ):
            return None
        return cached
    except (AttributeError, OSError, TypeError, ValueError, json.JSONDecodeError):
        return None


def atomic_write_text(path: Path, content: str) -> None:
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_path, path)
    finally:
        temporary_path.unlink(missing_ok=True)


def temporary_output(directory: Path, suffix: str) -> Path:
    descriptor, name = tempfile.mkstemp(prefix=".encoding-", suffix=suffix, dir=directory)
    os.close(descriptor)
    return Path(name)


def segment_ranges(duration: float, requested: int, length: float) -> list[tuple[float, float]]:
    clip_length = min(length, duration)
    count = min(requested, max(1, int(duration / clip_length)))
    spacing = duration / count
    ranges: list[tuple[float, float]] = []
    for index in range(count):
        start = max(0.0, (index + 0.5) * spacing - clip_length / 2)
        start = min(start, max(0.0, duration - clip_length))
        ranges.append((start, clip_length))
    return ranges


def vaapi_input_options(config: PreviewConfig) -> list[str]:
    return [
        "-init_hw_device", f"vaapi=thumbs:{config.device}",
        "-filter_hw_device", "thumbs",
        "-hwaccel", "vaapi",
        "-hwaccel_device", "thumbs",
        "-hwaccel_output_format", "vaapi",
    ]


def vaapi_scale(config: PreviewConfig) -> str:
    width = f"max(2,trunc(min({config.width},iw)/2)*2)"
    return f"scale_vaapi=w='{width}':h=-2:format=nv12:mode=fast"


def create_thumbnail(video: Path, destination: Path, duration: float, config: PreviewConfig) -> None:
    position = min(duration * config.thumbnail_percent / 100, max(0.0, duration - 0.001))
    scaled_width = f"max(2,trunc(min({config.width},iw)/2)*2)"
    hardware_command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-xerror"]
    hardware_command.extend(vaapi_input_options(config))
    hardware_command.extend([
        "-ss", f"{position:.6f}", "-i", str(video),
        "-frames:v", "1",
        "-vf", f"{vaapi_scale(config)},hwdownload,format=nv12",
        "-q:v", "3", "-update", "1", "-y", str(destination),
    ])
    try:
        run_command(hardware_command)
    except subprocess.CalledProcessError:
        run_command([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-xerror",
            "-ss", f"{position:.6f}", "-i", str(video),
            "-frames:v", "1",
            "-vf", f"scale=w='{scaled_width}':h=-2",
            "-q:v", "3", "-update", "1", "-y", str(destination),
        ])


def create_preview_segment(
    video: Path,
    destination: Path,
    start: float,
    length: float,
    config: PreviewConfig,
) -> None:
    scaled_width = f"max(2,trunc(min({config.width},iw)/2)*2)"
    frame_count = max(1, round(config.fps * length))
    hardware_command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-xerror"]
    hardware_command.extend(vaapi_input_options(config))
    hardware_command.extend([
        "-ss", f"{start:.6f}", "-i", str(video), "-an",
        "-vf", vaapi_scale(config),
        "-r", str(config.fps), "-fps_mode", "cfr", "-frames:v", str(frame_count),
        "-c:v", "av1_vaapi",
        "-profile:v", "main",
        "-rc_mode", "CQP",
        "-global_quality", str(config.quality),
        "-async_depth", "8",
        "-g", str(frame_count),
        "-y", str(destination),
    ])
    try:
        run_command(hardware_command)
    except subprocess.CalledProcessError:
        run_command([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-xerror",
            "-vaapi_device", config.device,
            "-ss", f"{start:.6f}", "-i", str(video), "-an",
            "-vf", f"scale=w='{scaled_width}':h=-2,format=nv12,hwupload",
            "-r", str(config.fps), "-fps_mode", "cfr", "-frames:v", str(frame_count),
            "-c:v", "av1_vaapi",
            "-profile:v", "main",
            "-rc_mode", "CQP",
            "-global_quality", str(config.quality),
            "-async_depth", "8",
            "-g", str(frame_count),
            "-y", str(destination),
        ])


def ffconcat_escape(path: Path) -> str:
    return str(path).replace("\\", "\\\\").replace("'", "'\\''")


def create_preview(video: Path, destination: Path, duration: float, config: PreviewConfig) -> None:
    ranges = segment_ranges(duration, config.segments, config.segment_length)
    segments: list[Path] = []
    concat_file = temporary_output(destination.parent, ".ffconcat")
    try:
        for start, length in ranges:
            segment = temporary_output(destination.parent, ".webm")
            segments.append(segment)
            create_preview_segment(video, segment, start, length, config)
        concat_file.write_text(
            "ffconcat version 1.0\n"
            + "".join(f"file '{ffconcat_escape(segment)}'\n" for segment in segments),
            encoding="utf-8",
        )
        run_command([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-xerror",
            "-f", "concat", "-safe", "0", "-i", str(concat_file),
            "-c", "copy", "-y", str(destination),
        ])
    finally:
        concat_file.unlink(missing_ok=True)
        for segment in segments:
            segment.unlink(missing_ok=True)


def repair_video(video: Path, destination: Path, config: PreviewConfig) -> str:
    """Decode past damaged packets and write a clean, high-quality AV1 copy."""
    result = run_command([
        "ffmpeg", "-hide_banner", "-loglevel", "warning",
        "-vaapi_device", config.device,
        "-fflags", "+discardcorrupt",
        "-err_detect", "ignore_err",
        "-i", str(video),
        "-map", "0:v:0",
        "-map", "0:a?",
        "-map", "0:s?",
        "-map_metadata", "0",
        "-map_chapters", "0",
        "-vf", "format=nv12,hwupload",
        "-c:v", "av1_vaapi",
        "-profile:v", "main",
        "-rc_mode", "CQP",
        "-global_quality", str(config.repair_quality),
        "-async_depth", "8",
        "-c:a", "copy",
        "-c:s", "copy",
        "-y", str(destination),
    ])
    if destination.stat().st_size == 0:
        raise RuntimeError("FFmpeg produced an empty repaired video")
    if video_duration(destination) is None:
        raise RuntimeError("FFprobe could not validate the repaired video")
    return result.stderr


def describe_ffmpeg_error(error: subprocess.CalledProcessError) -> str:
    lines = (error.stderr or "").strip().splitlines()
    return "\n".join(lines[-8:]) or str(error)


def process_video(video: Path, config: PreviewConfig, output_name: str, force: bool) -> dict[str, Any]:
    output_directory = video.parent / output_name
    output_directory.mkdir(exist_ok=True)
    thumbnail, preview, cache, repaired, repair_log = output_paths(video, output_directory)
    expected_cache = cache_payload(video, config)
    cached = None if force else read_current_cache(
        cache, thumbnail, preview, repaired, expected_cache, config
    )

    if cached is not None:
        status = "cached"
        used_repair = bool(cached.get("used_repair"))
        duration = float(cached["duration"])
        metadata = cached.get("metadata")
        if not valid_metadata(metadata):
            metadata = video_stream_metadata(video, duration)
            cached["metadata"] = metadata
            atomic_write_text(cache, json.dumps(cached, indent=2) + "\n")
    else:
        temporary_thumbnail = temporary_output(output_directory, ".jpg")
        temporary_preview = temporary_output(output_directory, ".webm")
        temporary_repaired: Path | None = None
        repair_details = ""
        used_repair = False
        try:
            source = video
            duration = video_duration(source)
            if duration is None:
                if not config.repair_on_error:
                    raise RuntimeError("ffprobe could not read a positive duration")
                temporary_repaired = temporary_output(output_directory, ".mkv")
                repair_details = "Initial failure: ffprobe could not read a positive duration\n\n"
                repair_details += repair_video(video, temporary_repaired, config)
                source = temporary_repaired
                duration = video_duration(source)
                if duration is None:
                    raise RuntimeError("ffprobe could not read the repaired video duration")
                used_repair = True

            try:
                create_thumbnail(source, temporary_thumbnail, duration, config)
                create_preview(source, temporary_preview, duration, config)
            except subprocess.CalledProcessError as original_error:
                if not config.repair_on_error or used_repair:
                    raise
                temporary_repaired = temporary_output(output_directory, ".mkv")
                repair_details = (
                    "Initial preview failure:\n"
                    f"{describe_ffmpeg_error(original_error)}\n\n"
                    "Repair pass:\n"
                )
                repair_details += repair_video(video, temporary_repaired, config)
                source = temporary_repaired
                duration = video_duration(source)
                if duration is None:
                    raise RuntimeError("ffprobe could not read the repaired video duration")
                create_thumbnail(source, temporary_thumbnail, duration, config)
                create_preview(source, temporary_preview, duration, config)
                used_repair = True

            if temporary_thumbnail.stat().st_size == 0 or temporary_preview.stat().st_size == 0:
                raise RuntimeError("FFmpeg produced an empty output")
            if used_repair and temporary_repaired is not None:
                os.replace(temporary_repaired, repaired)
                atomic_write_text(
                    repair_log,
                    f"Source: {video.resolve()}\nOutput: {repaired.resolve()}\n\n"
                    f"{repair_details.rstrip()}\n",
                )
            os.replace(temporary_thumbnail, thumbnail)
            os.replace(temporary_preview, preview)
            metadata = video_stream_metadata(video, duration)
            cache_record = {
                "key": expected_cache,
                "used_repair": used_repair,
                "duration": duration,
                "repair_quality": config.repair_quality if used_repair else None,
                "metadata": metadata,
            }
            atomic_write_text(cache, json.dumps(cache_record, indent=2) + "\n")
        finally:
            temporary_thumbnail.unlink(missing_ok=True)
            temporary_preview.unlink(missing_ok=True)
            if temporary_repaired is not None:
                temporary_repaired.unlink(missing_ok=True)
        status = "repaired" if used_repair else "generated"

    playback_video = repaired if used_repair else video

    return {
        "id": asset_id(video),
        "name": video.name,
        "video": str(playback_video.resolve()),
        "original": str(video.resolve()),
        "thumbnail": str(thumbnail.resolve()),
        "preview": str(preview.resolve()),
        "duration": duration,
        "folder": str(video.parent.resolve()),
        "repaired": used_repair,
        "status": status,
        **metadata,
    }


def discover_videos(roots: list[Path], recursive: bool, output_name: str) -> list[Path]:
    videos: set[Path] = set()
    for root in roots:
        if recursive:
            for directory, directory_names, file_names in os.walk(root):
                directory_names[:] = [name for name in directory_names if name != output_name]
                folder = Path(directory)
                videos.update(
                    folder / name
                    for name in file_names
                    if Path(name).suffix.lower() in VIDEO_EXTENSIONS
                )
        else:
            videos.update(
                path for path in root.iterdir()
                if path.is_file() and path.suffix.lower() in VIDEO_EXTENSIONS
            )
    return sorted(videos)


def discover_output_directories(roots: list[Path], recursive: bool, output_name: str) -> list[Path]:
    directories: set[Path] = set()
    for root in roots:
        candidate = root / output_name
        if candidate.is_dir():
            directories.add(candidate)
        if not recursive:
            continue
        for directory, directory_names, _file_names in os.walk(root):
            if output_name in directory_names:
                directories.add(Path(directory) / output_name)
                directory_names.remove(output_name)
    return sorted(directories)


def orphan_groups(
    roots: list[Path],
    recursive: bool,
    output_name: str,
) -> tuple[list[OrphanGroup], list[tuple[Path, str]]]:
    groups: list[OrphanGroup] = []
    warnings: list[tuple[Path, str]] = []
    for output_directory in discover_output_directories(roots, recursive, output_name):
        for cache in sorted(output_directory.glob("*.cache.json")):
            try:
                payload = json.loads(cache.read_text(encoding="utf-8"))
                source_value = payload["key"]["source"]["path"]
                source = Path(str(source_value))
                if not source.is_absolute():
                    source = (cache.parent / source).resolve()
            except (KeyError, OSError, TypeError, json.JSONDecodeError) as error:
                warnings.append((cache, f"unreadable cache source: {error}"))
                continue
            if source.exists():
                continue

            basename = cache.name.removesuffix(".cache.json")
            expected_names = (
                f"{basename}.jpg",
                f"{basename}.av1.webm",
                f"{basename}.repaired.mkv",
                f"{basename}.repair.log",
                cache.name,
            )
            artifacts = tuple(
                path
                for name in expected_names
                if (path := output_directory / name).is_file() or path.is_symlink()
            )
            total_size = 0
            for artifact in artifacts:
                try:
                    total_size += artifact.lstat().st_size
                except OSError:
                    pass
            groups.append(OrphanGroup(source, cache, artifacts, total_size))
    return groups, warnings


def print_orphan_report(
    groups: list[OrphanGroup],
    warnings: list[tuple[Path, str]],
) -> None:
    artifact_count = sum(len(group.artifacts) for group in groups)
    total_size = sum(group.total_size for group in groups)
    if groups:
        print(
            f"Found {len(groups)} orphaned video cache group(s): "
            f"{artifact_count} artifact(s), {format_size(total_size)}"
        )
        for group in groups:
            print(f"  missing source: {group.source}")
            for artifact in group.artifacts:
                print(f"    {artifact}")
    else:
        print("No orphaned thumbnail artifacts found.")
    if warnings:
        print(f"Skipped {len(warnings)} cache file(s) that could not be verified:")
        for cache, detail in warnings:
            print(f"  {cache}: {detail}")


def trash_orphan_groups(groups: list[OrphanGroup]) -> tuple[int, list[tuple[Path, str]]]:
    trashed = 0
    failures: list[tuple[Path, str]] = []
    for group in groups:
        for artifact in group.artifacts:
            try:
                subprocess.run(
                    ["gio", "trash", str(artifact)],
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    check=True,
                )
                trashed += 1
            except (OSError, subprocess.CalledProcessError) as error:
                detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
                failures.append((artifact, detail or str(error)))
    return trashed, failures


def manifest_path(value: Any, base: Path) -> Path:
    path = Path(str(value))
    return path if path.is_absolute() else (base / path).resolve()


def normalize_manifest_item(raw: Any, base: Path) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise ValueError("manifest item is not an object")
    video_value = raw.get("video")
    thumbnail_value = raw.get("thumbnail", raw.get("thumb"))
    preview_value = raw.get("preview")
    if not video_value or not thumbnail_value or not preview_value:
        raise ValueError("manifest item is missing video, thumbnail, or preview")

    video = manifest_path(video_value, base)
    original = manifest_path(raw.get("original", video_value), base)
    thumbnail = manifest_path(thumbnail_value, base)
    preview = manifest_path(preview_value, base)
    nested_metadata = raw.get("metadata") if isinstance(raw.get("metadata"), dict) else {}

    def metadata_value(key: str, default: Any) -> Any:
        return raw.get(key, nested_metadata.get(key, default))

    try:
        duration = float(metadata_value("duration", 0) or 0)
        size = int(metadata_value("size", 0) or 0)
        mtime = float(metadata_value("mtime", 0) or 0)
        width = int(metadata_value("width", 0) or 0)
        height = int(metadata_value("height", 0) or 0)
    except (TypeError, ValueError) as error:
        raise ValueError(f"manifest item has invalid numeric metadata: {error}") from error

    return {
        "id": str(raw.get("id") or asset_id(original)),
        "name": str(raw.get("name") or original.name),
        "video": str(video),
        "original": str(original),
        "thumbnail": str(thumbnail),
        "preview": str(preview),
        "duration": duration,
        "folder": str(manifest_path(raw.get("folder", original.parent), base)),
        "repaired": bool(raw.get("repaired", False)),
        "status": str(raw.get("status", "existing")),
        "size": size,
        "mtime": mtime,
        "mtime_ns": int(metadata_value("mtime_ns", 0) or 0),
        "codec": str(metadata_value("codec", "unknown") or "unknown").lower(),
        "width": width,
        "height": height,
        "extension": str(metadata_value("extension", original.suffix.removeprefix("."))).lower(),
    }


def item_cache_path(item: dict[str, Any]) -> Path | None:
    thumbnail = Path(item["thumbnail"])
    if thumbnail.name.endswith(".jpg"):
        candidate = thumbnail.with_name(thumbnail.name.removesuffix(".jpg") + ".cache.json")
        if candidate.is_file():
            return candidate
    preview = Path(item["preview"])
    if preview.name.endswith(".av1.webm"):
        candidate = preview.with_name(preview.name.removesuffix(".av1.webm") + ".cache.json")
        if candidate.is_file():
            return candidate
    return None


def hydrate_item_metadata(item: dict[str, Any]) -> tuple[dict[str, Any], bool]:
    if valid_metadata(item):
        return item, False

    cache_path = item_cache_path(item)
    cached: dict[str, Any] | None = None
    if cache_path is not None:
        try:
            value = json.loads(cache_path.read_text(encoding="utf-8"))
            if isinstance(value, dict):
                cached = value
                metadata = value.get("metadata")
                if valid_metadata(metadata):
                    enriched = dict(item)
                    enriched.update(metadata)
                    return enriched, True
        except (OSError, json.JSONDecodeError):
            pass

    original = Path(item["original"])
    if not original.is_file():
        return item, False
    duration = float(item.get("duration", 0) or 0)
    if duration <= 0:
        probed_duration = video_duration(original)
        if probed_duration is None:
            return item, False
        duration = probed_duration
    try:
        metadata = video_stream_metadata(original, duration)
    except OSError:
        return item, False
    if not valid_metadata(metadata):
        return item, False

    enriched = dict(item)
    enriched.update(metadata)
    if cache_path is not None and cached is not None:
        cached["metadata"] = metadata
        atomic_write_text(cache_path, json.dumps(cached, indent=2) + "\n")
    return enriched, True


def load_existing_gallery(
    root: Path,
    gallery_name: str,
    default_width: int,
    metadata_jobs: int = 2,
) -> tuple[list[dict[str, Any]], int, Path]:
    manifest = root / f"{gallery_name}.json"
    try:
        payload = json.loads(manifest.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise SystemExit(f"Existing manifest not found: {manifest}") from error
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Could not read existing manifest {manifest}: {error}") from error

    if isinstance(payload, list):
        raw_items = payload
        width = default_width
    elif isinstance(payload, dict) and isinstance(payload.get("items"), list):
        raw_items = payload["items"]
        try:
            width = even(int(payload.get("config", {}).get("width", default_width)))
        except (AttributeError, TypeError, ValueError):
            width = default_width
    else:
        raise SystemExit(f"Existing manifest has an unsupported structure: {manifest}")

    try:
        items = [normalize_manifest_item(item, root) for item in raw_items]
    except ValueError as error:
        raise SystemExit(f"Invalid existing manifest {manifest}: {error}") from error
    if not items:
        raise SystemExit(f"Existing manifest contains no videos: {manifest}")

    missing_metadata = [index for index, item in enumerate(items) if not valid_metadata(item)]
    if missing_metadata:
        print(f"Hydrating metadata for {len(missing_metadata)} video(s) from caches or source files…")
        completed = 0
        enriched_count = 0
        with ThreadPoolExecutor(max_workers=min(metadata_jobs, len(missing_metadata))) as executor:
            futures = {
                executor.submit(hydrate_item_metadata, items[index]): index
                for index in missing_metadata
            }
            for future in as_completed(futures):
                index = futures[future]
                try:
                    items[index], changed = future.result()
                except (OSError, RuntimeError, ValueError):
                    changed = False
                completed += 1
                enriched_count += int(changed)
                if completed == len(missing_metadata) or completed % 10 == 0:
                    print(f"  metadata {completed}/{len(missing_metadata)}")
        unresolved = len(missing_metadata) - enriched_count
        print(f"Metadata: {enriched_count} enriched, {unresolved} unresolved")
        if enriched_count:
            if isinstance(payload, dict):
                persisted_payload = dict(payload)
                persisted_payload["items"] = items
            else:
                persisted_payload = {
                    "profile": ENCODE_PROFILE,
                    "config": {"width": width},
                    "items": items,
                }
            atomic_write_text(manifest, json.dumps(persisted_payload, indent=2) + "\n")
    return items, width, root / f"{gallery_name}.html"


def prune_manifest_entries(root: Path, gallery_name: str) -> int:
    manifest = root / f"{gallery_name}.json"
    if not manifest.is_file():
        return 0
    try:
        payload = json.loads(manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return 0
    if isinstance(payload, list):
        raw_items = payload
    elif isinstance(payload, dict) and isinstance(payload.get("items"), list):
        raw_items = payload["items"]
    else:
        return 0

    kept: list[Any] = []
    removed = 0
    for raw in raw_items:
        if not isinstance(raw, dict) or not raw.get("video"):
            kept.append(raw)
            continue
        source_value = raw.get("original", raw["video"])
        if manifest_path(source_value, root).exists():
            kept.append(raw)
        else:
            removed += 1
    if not removed:
        return 0
    if isinstance(payload, list):
        updated_payload: Any = kept
    else:
        updated_payload = dict(payload)
        updated_payload["items"] = kept
    atomic_write_text(manifest, json.dumps(updated_payload, indent=2) + "\n")
    return removed


HTML_HEAD = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Hover-preview gallery</title>
<style>
:root { color-scheme: dark; --card-width: WIDTHpx; }
* { box-sizing: border-box; }
body { margin: 0; padding: 0 24px 28px; background: #111; color: #eee;
       font-family: system-ui, sans-serif; }
header { position: sticky; z-index: 2; top: 0; margin: 0 -24px; padding: 13px 24px;
         background: #111e; border-bottom: 1px solid #333; backdrop-filter: blur(10px); }
.title-row { display: flex; align-items: baseline; gap: 12px; margin-bottom: 10px; }
h1 { margin: 0; font-size: 1.35rem; }
#stats, .folder-count { color: #aaa; font-size: .86rem; font-weight: 400; }
.controls { display: flex; flex-wrap: wrap; gap: 8px; }
input, select, button { border: 1px solid #555; border-radius: 7px; background: #222;
                        color: inherit; padding: 8px 10px; font: inherit; }
#filter { flex: 1 1 260px; min-width: 180px; }
select { max-width: 180px; }
button { cursor: pointer; }
button:hover { background: #303030; }
h2 { display: flex; align-items: center; gap: 9px; margin: 30px 0 14px;
     border-bottom: 1px solid #444; padding-bottom: 7px; font-size: 1.05rem; }
.folder-toggle { min-width: 0; overflow: hidden; padding: 0; border: 0; background: none;
                 text-align: left; text-overflow: ellipsis; white-space: nowrap; font-weight: 650; }
.folder-toggle:hover { background: none; color: #8fd392; }
section.collapsed .grid { display: none; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, var(--card-width)), 1fr));
        gap: 20px; }
figure { min-width: 0; margin: 0; }
.preview { position: relative; overflow: hidden; border-radius: 9px; background: #222;
           box-shadow: 0 3px 12px #0008; }
video { display: block; width: 100%; aspect-ratio: 16 / 9; object-fit: contain; cursor: pointer; }
.progress { position: absolute; right: 0; bottom: 0; left: 0; height: 4px; pointer-events: none; }
.progress > span { display: block; width: 0; height: 100%; background: #65c466; }
figcaption { overflow-wrap: anywhere; padding-top: 7px; text-align: center; }
.video-name { font-size: .9rem; }
.video-meta { margin-top: 3px; color: #aaa; font-size: .76rem; }
.repair-badge { color: #f4bf75; }
[hidden] { display: none !important; }
@media (max-width: 700px) {
  body { padding-right: 12px; padding-left: 12px; }
  header { margin-right: -12px; margin-left: -12px; padding-right: 12px; padding-left: 12px; }
  select { flex: 1 1 145px; max-width: none; }
}
</style>
<script>
document.addEventListener('DOMContentLoaded', () => {
  const fileMode = location.protocol === 'file:';
  const figures = [...document.querySelectorAll('figure')];
  const sections = [...document.querySelectorAll('section')];
  const controls = {
    filter: document.querySelector('#filter'),
    sort: document.querySelector('#sort'),
    codec: document.querySelector('#codec'),
    resolution: document.querySelector('#resolution'),
    repair: document.querySelector('#repair')
  };
  const stats = document.querySelector('#stats');

  const codecs = [...new Set(figures.map(figure => figure.dataset.codec))].sort();
  for (const codec of codecs) {
    if (!codec || codec === 'unknown') continue;
    const option = document.createElement('option');
    option.value = codec;
    option.textContent = codec.toUpperCase();
    controls.codec.append(option);
  }

  try {
    const saved = JSON.parse(localStorage.getItem('thumbnail-gallery-controls') || '{}');
    for (const [name, value] of Object.entries(saved)) {
      if (controls[name] && [...controls[name].options || []].some(option => option.value === value)) {
        controls[name].value = value;
      }
    }
  } catch (_) {}

  const resolutionMatches = (height, selected) => {
    if (selected === 'all') return true;
    if (selected === '2160') return height >= 2160;
    if (selected === '1440') return height >= 1440 && height < 2160;
    if (selected === '1080') return height >= 1080 && height < 1440;
    if (selected === '720') return height >= 720 && height < 1080;
    if (selected === 'sd') return height > 0 && height < 720;
    return height === 0;
  };

  const comparators = {
    'name-asc': (a, b) => a.dataset.name.localeCompare(b.dataset.name),
    'name-desc': (a, b) => b.dataset.name.localeCompare(a.dataset.name),
    'date-desc': (a, b) => Number(b.dataset.mtime) - Number(a.dataset.mtime),
    'date-asc': (a, b) => Number(a.dataset.mtime) - Number(b.dataset.mtime),
    'size-desc': (a, b) => Number(b.dataset.size) - Number(a.dataset.size),
    'size-asc': (a, b) => Number(a.dataset.size) - Number(b.dataset.size),
    'duration-desc': (a, b) => Number(b.dataset.duration) - Number(a.dataset.duration),
    'duration-asc': (a, b) => Number(a.dataset.duration) - Number(b.dataset.duration),
    'resolution-desc': (a, b) => Number(b.dataset.pixels) - Number(a.dataset.pixels),
    'resolution-asc': (a, b) => Number(a.dataset.pixels) - Number(b.dataset.pixels)
  };

  const applyView = () => {
    const query = controls.filter.value.toLocaleLowerCase().trim();
    const codec = controls.codec.value;
    const resolution = controls.resolution.value;
    const repair = controls.repair.value;
    let visibleTotal = 0;

    for (const figure of figures) {
      const matches = (!query || figure.dataset.search.includes(query))
        && (codec === 'all' || figure.dataset.codec === codec)
        && resolutionMatches(Number(figure.dataset.height), resolution)
        && (repair === 'all' || figure.dataset.repaired === repair);
      figure.hidden = !matches;
      if (!matches) {
        const video = figure.querySelector('video');
        video.pause();
        video.currentTime = 0;
      } else visibleTotal++;
    }

    const compare = comparators[controls.sort.value] || comparators['name-asc'];
    for (const section of sections) {
      const grid = section.querySelector('.grid');
      const cards = [...grid.querySelectorAll('figure')].sort(compare);
      for (const card of cards) grid.append(card);
      const visible = cards.filter(card => !card.hidden).length;
      section.hidden = visible === 0;
      section.querySelector('.folder-count').textContent = `${visible} / ${cards.length}`;
    }
    stats.textContent = `${visibleTotal} / ${figures.length} videos`;
    try {
      localStorage.setItem('thumbnail-gallery-controls', JSON.stringify({
        sort: controls.sort.value,
        codec: controls.codec.value,
        resolution: controls.resolution.value,
        repair: controls.repair.value
      }));
    } catch (_) {}
  };

  controls.filter.addEventListener('input', applyView);
  for (const control of [controls.sort, controls.codec, controls.resolution, controls.repair]) {
    control.addEventListener('change', applyView);
  }
  document.querySelector('#reset').addEventListener('click', () => {
    controls.filter.value = '';
    controls.sort.value = 'name-asc';
    controls.codec.value = 'all';
    controls.resolution.value = 'all';
    controls.repair.value = 'all';
    applyView();
  });
  document.querySelectorAll('.folder-toggle').forEach(button => {
    button.addEventListener('click', () => {
      const section = button.closest('section');
      section.classList.toggle('collapsed');
      button.setAttribute('aria-expanded', String(!section.classList.contains('collapsed')));
    });
  });

  const posterObserver = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      const video = entry.target;
      video.poster = fileMode ? video.dataset.posterFile : video.dataset.posterHttp;
      posterObserver.unobserve(video);
    }
  }, { rootMargin: '240px' });

  let activeVideo = null;
  const loadPreview = video => {
    if (video.dataset.previewLoaded === 'true') return;
    const source = video.querySelector('source');
    source.src = fileMode ? source.dataset.srcFile : source.dataset.srcHttp;
    video.dataset.previewLoaded = 'true';
    video.preload = 'auto';
    video.load();
  };

  document.querySelectorAll('video').forEach(video => {
    const progress = video.parentElement.querySelector('.progress > span');
    const launch = () => {
      if (fileMode) window.open(video.dataset.videoUri);
      else fetch('/launch/' + encodeURIComponent(video.dataset.assetId), { method: 'POST' });
    };
    const startPreview = () => {
      if (activeVideo && activeVideo !== video) {
        activeVideo.pause();
        activeVideo.currentTime = 0;
      }
      activeVideo = video;
      loadPreview(video);
      video.play().catch(() => {});
    };
    video.addEventListener('mouseenter', startPreview);
    video.addEventListener('focus', () => loadPreview(video));
    video.addEventListener('mouseleave', () => {
      video.pause();
      video.currentTime = 0;
      if (activeVideo === video) activeVideo = null;
    });
    video.addEventListener('click', launch);
    video.addEventListener('keydown', event => {
      if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); launch(); }
    });
    video.addEventListener('timeupdate', () => {
      progress.style.width = video.duration ? `${100 * video.currentTime / video.duration}%` : '0';
    });
    posterObserver.observe(video);
  });
  applyView();
});
</script>
</head>
<body>
<header>
  <div class="title-row"><h1>Hover-preview gallery</h1><span id="stats"></span></div>
  <div class="controls">
    <input id="filter" type="search" placeholder="Search names, folders, codecs…">
    <select id="sort" aria-label="Sort videos">
      <option value="name-asc">Name A–Z</option><option value="name-desc">Name Z–A</option>
      <option value="date-desc">Newest first</option><option value="date-asc">Oldest first</option>
      <option value="size-desc">Largest first</option><option value="size-asc">Smallest first</option>
      <option value="duration-desc">Longest first</option><option value="duration-asc">Shortest first</option>
      <option value="resolution-desc">Highest resolution</option><option value="resolution-asc">Lowest resolution</option>
    </select>
    <select id="codec" aria-label="Filter by codec"><option value="all">All codecs</option></select>
    <select id="resolution" aria-label="Filter by resolution">
      <option value="all">All resolutions</option><option value="2160">2160p+</option>
      <option value="1440">1440p</option><option value="1080">1080p</option>
      <option value="720">720p</option><option value="sd">Below 720p</option>
      <option value="unknown">Unknown resolution</option>
    </select>
    <select id="repair" aria-label="Filter by repair status">
      <option value="all">All files</option><option value="true">Repaired only</option>
      <option value="false">Original only</option>
    </select>
    <button id="reset" type="button">Reset</button>
  </div>
</header>
"""


def attribute(value: str) -> str:
    return html.escape(value, quote=True)


def format_duration(seconds: float) -> str:
    if 0 < seconds < 1:
        return f"{seconds:.1f}s"
    total = max(0, round(seconds))
    hours, remainder = divmod(total, 3600)
    minutes, seconds = divmod(remainder, 60)
    return f"{hours}:{minutes:02d}:{seconds:02d}" if hours else f"{minutes}:{seconds:02d}"


def format_size(size: int) -> str:
    value = float(max(0, size))
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if value < 1024 or unit == "TiB":
            return f"{value:.0f} {unit}" if unit == "B" else f"{value:.1f} {unit}"
        value /= 1024
    return f"{size} B"


def format_date(timestamp: float) -> str:
    return time.strftime("%Y-%m-%d", time.localtime(timestamp)) if timestamp > 0 else "unknown date"


def build_html(items: list[dict[str, Any]], width: int, page: Path) -> None:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for item in items:
        grouped.setdefault(item["folder"], []).append(item)

    parts = [HTML_HEAD.replace("WIDTH", str(width))]
    for folder in sorted(grouped):
        try:
            title = str(Path(folder).relative_to(page.parent)) or "."
        except ValueError:
            title = folder
        folder_items = grouped[folder]
        parts.append(
            f'<section data-folder="{attribute(folder.lower())}"><h2>'
            f'<button class="folder-toggle" type="button" aria-expanded="true">'
            f'▾ {html.escape(title)}</button><span class="folder-count">'
            f'{len(folder_items)} / {len(folder_items)}</span></h2><div class="grid">'
        )
        for item in sorted(folder_items, key=lambda entry: entry.get("name", entry["video"]).lower()):
            video = Path(item["video"])
            thumbnail = Path(item["thumbnail"])
            preview = Path(item["preview"])
            identifier = attribute(item["id"])
            name = item.get("name", video.name)
            duration = float(item.get("duration", 0) or 0)
            size = int(item.get("size", 0) or 0)
            mtime = float(item.get("mtime", 0) or 0)
            codec = str(item.get("codec", "unknown") or "unknown").lower()
            source_width = int(item.get("width", 0) or 0)
            source_height = int(item.get("height", 0) or 0)
            repaired = bool(item.get("repaired", False))
            resolution = f"{source_width}×{source_height}" if source_width and source_height else "unknown res"
            metadata = (
                f"{format_duration(duration)} · {resolution} · {codec.upper()} · "
                f"{format_size(size)} · {format_date(mtime)}"
            )
            search = f"{name} {folder} {codec} {resolution}".lower()
            parts.append(
                f'<figure data-name="{attribute(name.lower())}" data-search="{attribute(search)}" '
                f'data-codec="{attribute(codec)}" data-width="{source_width}" data-height="{source_height}" '
                f'data-pixels="{source_width * source_height}" data-size="{size}" data-mtime="{mtime}" '
                f'data-duration="{duration}" data-repaired="{str(repaired).lower()}">'
                '<div class="preview">'
                f'<video muted loop playsinline preload="none" tabindex="0" role="button" '
                f'aria-label="Open {attribute(name)}" data-asset-id="{identifier}" '
                f'data-video-uri="{attribute(video.as_uri())}" '
                f'data-poster-file="{attribute(thumbnail.as_uri())}" '
                f'data-poster-http="/media/{identifier}/thumbnail">'
                f'<source data-src-file="{attribute(preview.as_uri())}" '
                f'data-src-http="/media/{identifier}/preview" type="video/webm">'
                '</video><div class="progress"><span></span></div></div>'
                f'<figcaption><div class="video-name">{html.escape(name)}</div>'
                f'<div class="video-meta">{html.escape(metadata)}'
                f'{" · <span class=\"repair-badge\">repaired</span>" if repaired else ""}'
                '</div></figcaption></figure>'
            )
        parts.append("</div></section>")
    parts.append("</body></html>\n")
    atomic_write_text(page, "".join(parts))


def serve(page: Path, items: list[dict[str, Any]]) -> None:
    assets = {item["id"]: item for item in items}

    class GalleryHandler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, _format: str, *args: object) -> None:
            pass

        def do_GET(self) -> None:
            parsed = urllib.parse.urlparse(self.path)
            parts = parsed.path.strip("/").split("/")
            if len(parts) == 3 and parts[0] == "media":
                item = assets.get(parts[1])
                key = {"thumbnail": "thumbnail", "preview": "preview"}.get(parts[2])
                if item is not None and key is not None:
                    self.send_asset(Path(item[key]))
                    return
                self.send_error(404)
                return
            if parsed.path == "/":
                self.send_response(302)
                self.send_header("Location", "/" + urllib.parse.quote(page.name))
                self.end_headers()
                return
            super().do_GET()

        def do_POST(self) -> None:
            parts = urllib.parse.urlparse(self.path).path.strip("/").split("/")
            if len(parts) == 2 and parts[0] == "launch":
                item = assets.get(parts[1])
                if item is not None and Path(item["video"]).is_file():
                    subprocess.Popen(
                        ["xdg-open", item["video"]],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        start_new_session=True,
                    )
                    self.send_response(204)
                    self.end_headers()
                    return
            self.send_error(404)

        def send_asset(self, path: Path) -> None:
            try:
                size = path.stat().st_size
                content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
                start, end = self.requested_range(size)
                partial_response = start != 0 or end != size - 1
                self.send_response(206 if partial_response else 200)
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Length", str(end - start + 1))
                self.send_header("Accept-Ranges", "bytes")
                if partial_response:
                    self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
                self.send_header("Cache-Control", "no-cache")
                self.end_headers()
                with path.open("rb") as handle:
                    handle.seek(start)
                    remaining = end - start + 1
                    while remaining:
                        chunk = handle.read(min(256 * 1024, remaining))
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                        remaining -= len(chunk)
            except (BrokenPipeError, ConnectionResetError):
                pass
            except (OSError, ValueError):
                self.send_error(404)

        def requested_range(self, size: int) -> tuple[int, int]:
            value = self.headers.get("Range")
            if not value:
                return 0, size - 1
            unit, separator, ranges = value.partition("=")
            if unit != "bytes" or not separator or "," in ranges:
                raise ValueError("unsupported byte range")
            first, separator, last = ranges.partition("-")
            if not separator:
                raise ValueError("invalid byte range")
            if first:
                start = int(first)
                end = int(last) if last else size - 1
            else:
                suffix_length = int(last)
                start = max(0, size - suffix_length)
                end = size - 1
            end = min(end, size - 1)
            if start < 0 or start >= size or end < start:
                raise ValueError("byte range outside asset")
            return start, end

    handler = partial(GalleryHandler, directory=str(page.parent))
    with http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
        port = server.server_address[1]
        url = f"http://127.0.0.1:{port}/{urllib.parse.quote(page.name)}"
        webbrowser.open(url)
        print(f"Serving at {url}  (Ctrl-C to quit)")
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build an AV1 hover-preview gallery using this machine's RX 9070 XT."
    )
    parser.add_argument("dirs", nargs="*", help="Folders to scan (default: .)")
    parser.add_argument("--recursive", action="store_true", help="Include subdirectories")
    parser.add_argument("--width", type=positive_int, default=800, help="Maximum preview width (default: 800)")
    parser.add_argument("--segments", type=positive_int, default=12, help="Requested clips per preview (default: 12)")
    parser.add_argument("--seg-len", type=positive_float, default=1.0, help="Seconds per clip (default: 1.0)")
    parser.add_argument("--fps", type=positive_int, default=20, help="Preview frame rate (default: 20)")
    parser.add_argument("--thumb-pct", type=percentage, default=10, help="Thumbnail position percentage (default: 10)")
    parser.add_argument("--quality", type=av1_quality, default=32, help="AV1 quantizer; lower is better (default: 32)")
    parser.add_argument("--jobs", type=positive_int, default=2, help="Concurrent GPU encodes (default: 2)")
    parser.add_argument("--device", default="/dev/dri/renderD128", help="VAAPI render node")
    parser.add_argument(
        "--repair-on-error",
        action="store_true",
        help="Salvage a failed video into a separate repaired AV1 copy, then retry",
    )
    parser.add_argument(
        "--repair-quality",
        type=av1_quality,
        default=18,
        help="Repaired-copy AV1 quantizer; lower is better (default: 18)",
    )
    parser.add_argument("--force", action="store_true", help="Regenerate all assets")
    parser.add_argument("--out-dir", default="thumbnails_output", help="Per-folder output directory name")
    parser.add_argument("--gallery-name", default="master_gallery", help="Gallery HTML/JSON basename")
    parser.add_argument(
        "--serve-existing",
        action="store_true",
        help="Serve an existing manifest immediately without scanning or initializing VAAPI",
    )
    orphan_actions = parser.add_mutually_exclusive_group()
    orphan_actions.add_argument(
        "--list-orphans",
        action="store_true",
        help="Report generated artifacts whose recorded source video no longer exists",
    )
    orphan_actions.add_argument(
        "--prune-orphans",
        action="store_true",
        help="Move orphaned generated artifacts to desktop trash and update the manifest",
    )
    parser.add_argument("--no-serve", action="store_true", help="Generate files without starting the server")
    return parser.parse_args()


def validate_basename(parser_value: str, option: str) -> None:
    if not parser_value or Path(parser_value).name != parser_value or parser_value in {".", ".."}:
        raise SystemExit(f"{option} must be a single non-empty filename component")


def progress_time(seconds: float) -> str:
    total = max(0, round(seconds))
    hours, remainder = divmod(total, 3600)
    minutes, seconds = divmod(remainder, 60)
    if hours:
        return f"{hours}h {minutes:02d}m {seconds:02d}s"
    if minutes:
        return f"{minutes}m {seconds:02d}s"
    return f"{seconds}s"


def main() -> None:
    args = parse_arguments()
    validate_basename(args.out_dir, "--out-dir")
    validate_basename(args.gallery_name, "--gallery-name")

    if args.serve_existing:
        if args.list_orphans or args.prune_orphans:
            raise SystemExit("--serve-existing cannot be combined with orphan cleanup actions")
        if args.no_serve:
            raise SystemExit("--serve-existing cannot be combined with --no-serve")
        if len(args.dirs) > 1:
            raise SystemExit("--serve-existing accepts at most one gallery directory")
        root = Path(args.dirs[0] if args.dirs else ".").resolve()
        if not root.is_dir():
            raise SystemExit(f"Gallery directory does not exist: {root}")
        items, width, page = load_existing_gallery(
            root, args.gallery_name, even(args.width), args.jobs
        )
        build_html(items, width, page)
        print(f"Loaded {len(items)} video(s) from {root / f'{args.gallery_name}.json'}")
        serve(page, items)
        return

    roots: list[Path] = []
    for raw_root in args.dirs or ["."]:
        root = Path(raw_root).resolve()
        if not root.is_dir():
            print(f"Skipping non-directory: {root}")
        elif root not in roots:
            roots.append(root)
    if not roots:
        raise SystemExit("No readable input directories")

    if args.list_orphans or args.prune_orphans:
        if args.prune_orphans and shutil.which("gio") is None:
            raise SystemExit("Missing required command: gio")
        groups, warnings = orphan_groups(roots, args.recursive, args.out_dir)
        print_orphan_report(groups, warnings)
        if args.list_orphans:
            return
        trashed, trash_failures = trash_orphan_groups(groups)
        print(f"Moved {trashed} orphaned artifact(s) to desktop trash.")
        removed_entries = 0
        for root in roots:
            removed = prune_manifest_entries(root, args.gallery_name)
            removed_entries += removed
            if not removed:
                continue
            try:
                items, width, page = load_existing_gallery(
                    root, args.gallery_name, even(args.width), args.jobs
                )
            except SystemExit:
                build_html([], even(args.width), root / f"{args.gallery_name}.html")
            else:
                build_html(items, width, page)
        if removed_entries:
            print(f"Removed {removed_entries} orphaned item(s) from manifest files.")
        if trash_failures:
            print("Trash failures:")
            for artifact, detail in trash_failures:
                print(f"  {artifact}: {detail}")
            raise SystemExit(1)
        return

    missing_tools = [tool for tool in ("ffmpeg", "ffprobe") if shutil.which(tool) is None]
    if missing_tools:
        raise SystemExit("Missing required command(s): " + ", ".join(missing_tools))
    if not Path(args.device).exists():
        raise SystemExit(f"VAAPI render node does not exist: {args.device}")

    config = PreviewConfig(
        width=even(args.width),
        segments=args.segments,
        segment_length=args.seg_len,
        fps=args.fps,
        thumbnail_percent=args.thumb_pct,
        quality=args.quality,
        device=args.device,
        repair_on_error=args.repair_on_error,
        repair_quality=args.repair_quality,
    )
    videos = discover_videos(roots, args.recursive, args.out_dir)
    if not videos:
        print("Finished: no videos found.")
        return

    print(
        f"Processing {len(videos)} video(s) with AV1 VAAPI on {config.device} "
        f"({min(args.jobs, len(videos))} concurrent)"
    )
    items: list[dict[str, Any]] = []
    failures: list[tuple[Path, str]] = []
    counts = {"cached": 0, "generated": 0, "repaired": 0, "failed": 0}
    completed = 0
    started = time.monotonic()
    total = len(videos)
    with ThreadPoolExecutor(max_workers=min(args.jobs, len(videos))) as executor:
        futures = {
            executor.submit(process_video, video, config, args.out_dir, args.force): video
            for video in videos
        }
        for future in as_completed(futures):
            video = futures[future]
            try:
                item = future.result()
                items.append(item)
                status = str(item["status"])
                counts[status] = counts.get(status, 0) + 1
            except subprocess.CalledProcessError as error:
                status = "failed"
                failures.append((video, describe_ffmpeg_error(error)))
                counts[status] += 1
            except (OSError, RuntimeError) as error:
                status = "failed"
                failures.append((video, str(error)))
                counts[status] += 1
            except Exception as error:
                status = "failed"
                failures.append((video, f"{type(error).__name__}: {error}"))
                counts[status] += 1

            completed += 1
            elapsed = time.monotonic() - started
            eta = elapsed / completed * (total - completed) if completed else 0
            percent = completed / total * 100
            print(
                f"[{completed:>{len(str(total))}}/{total} {percent:5.1f}%] "
                f"{status:<9} {video} | elapsed {progress_time(elapsed)} "
                f"ETA {progress_time(eta)}"
            )

    elapsed = time.monotonic() - started
    print(
        "Summary: "
        + ", ".join(f"{counts[name]} {name}" for name in ("cached", "generated", "repaired", "failed"))
        + f" in {progress_time(elapsed)}"
    )
    if failures:
        print("Failure summary:")
        for video, detail in failures:
            indented = "\n".join(f"      {line}" for line in detail.splitlines())
            print(f"  - {video}\n{indented}")

    if not items:
        raise SystemExit("No previews were successfully generated")

    items.sort(key=lambda item: item["video"].lower())
    output_base = roots[0]
    manifest = output_base / f"{args.gallery_name}.json"
    page = output_base / f"{args.gallery_name}.html"
    manifest_payload = {
        "profile": ENCODE_PROFILE,
        "config": asdict(config),
        "items": items,
    }
    atomic_write_text(manifest, json.dumps(manifest_payload, indent=2) + "\n")
    build_html(items, config.width, page)
    print(f"Gallery:  {page}\nManifest: {manifest}")
    if not args.no_serve:
        serve(page, items)


if __name__ == "__main__":
    main()
