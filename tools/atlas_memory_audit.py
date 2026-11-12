#!/usr/bin/env python3
"""
贴图解码内存静态审计（不依赖 PIL，直接读 PNG IHDR）。

用途：Psych/FE 的贴图在 CPU 侧常驻的是「解码后的 RGBA 缓冲」，
     与磁盘上的 PNG 体积无关（一张 4096x4096 的 1MB PNG 解码后是 64MB）。
     本脚本按目录汇总「解码后字节数」，用来定位内存大头。

用法：
    python tools/atlas_memory_audit.py                # 扫 assets/ 与 content/
    python tools/atlas_memory_audit.py --root . --top 40
    python tools/atlas_memory_audit.py --root export/release/windows/bin/content
"""

from __future__ import annotations

import argparse
import os
import struct
import sys
from collections import defaultdict
from dataclasses import dataclass


@dataclass
class PngInfo:
    path: str
    width: int
    height: int
    file_size: int

    @property
    def decoded(self) -> int:
        # openfl 统一转 BGRA32（4 字节/像素），不考虑 mipmap
        return self.width * self.height * 4


def read_png_info(path: str) -> PngInfo | None:
    try:
        with open(path, "rb") as f:
            head = f.read(33)
        if len(head) < 33 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
            return None
        width, height = struct.unpack(">II", head[16:24])
        return PngInfo(path, width, height, os.path.getsize(path))
    except OSError:
        return None


def walk_png(root: str):
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in filenames:
            if name.lower().endswith(".png"):
                full = os.path.join(dirpath, name)
                info = read_png_info(full)
                if info is not None:
                    yield info


def group_key(root: str, path: str) -> str:
    rel = os.path.relpath(path, root)
    parts = rel.replace("\\", "/").split("/")
    if len(parts) >= 3:
        return "/".join(parts[:2])
    if len(parts) >= 2:
        return parts[0]
    return "."


def human(n: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if abs(n) < 1024.0 or unit == "GB":
            return f"{n:,.1f}{unit}" if unit != "B" else f"{int(n)}B"
        n /= 1024.0
    return f"{n:,.1f}GB"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", action="append", default=None,
                    help="要扫描的根目录，可重复；默认 assets 与 content")
    ap.add_argument("--top", type=int, default=25)
    ap.add_argument("--min-bytes", type=int, default=0,
                    help="只统计解码后不小于该值的图（默认全部）")
    args = ap.parse_args()

    roots = args.root or ["assets", "content"]
    roots = [r for r in roots if os.path.isdir(r)]
    if not roots:
        print("没有找到可扫描的目录（请在工程根目录运行）", file=sys.stderr)
        return 1

    all_imgs: list[PngInfo] = []
    per_group: dict[str, list[PngInfo]] = defaultdict(list)

    for root in roots:
        for info in walk_png(root):
            if info.decoded < args.min_bytes:
                continue
            info.path = os.path.relpath(info.path, ".")
            all_imgs.append(info)
            per_group[group_key(root, info.path)].append(info)

    if not all_imgs:
        print("没有找到 PNG", file=sys.stderr)
        return 1

    total_decoded = sum(i.decoded for i in all_imgs)
    total_disk = sum(i.file_size for i in all_imgs)
    big = [i for i in all_imgs if i.width * i.height >= 2048 * 2048]

    print("=" * 78)
    print(f"PNG 数量: {len(all_imgs)}")
    print(f"磁盘体积: {human(total_disk)}")
    print(f"解码后  : {human(total_decoded)}  (BGRA32, {total_decoded / max(total_disk, 1):.1f}x 膨胀)")
    print(f">=2048x2048 的图: {len(big)} 张，解码共 {human(sum(i.decoded for i in big))}")
    print("=" * 78)

    print("\n按目录（解码后从大到小）:")
    print(f"{'group':<44}{'count':>7}{'decoded':>12}{'disk':>12}")
    for group, items in sorted(per_group.items(), key=lambda kv: -sum(i.decoded for i in kv[1])):
        d = sum(i.decoded for i in items)
        s = sum(i.file_size for i in items)
        print(f"{group[:43]:<44}{len(items):>7}{human(d):>12}{human(s):>12}")

    print(f"\nTop {args.top} 单图（解码后）:")
    print(f"{'decoded':>10}  {'size':>11}  {'disk':>9}  path")
    for info in sorted(all_imgs, key=lambda i: -i.decoded)[: args.top]:
        print(f"{human(info.decoded):>10}  {info.width:>5}x{info.height:<5}  {human(info.file_size):>9}  {info.path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
