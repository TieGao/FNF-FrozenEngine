#!/usr/bin/env python3
"""NMV Animate 图集帧推演（离线、不启动游戏）。

用途：在改「零件帧语义」这类底层逻辑之前，先用真实 Animation.json 算出
"每个时间轴帧上，每个叶子零件最终显示第几帧"，把行为钉死再动代码。

背景（2026-10-31 夜事故）：移植端曾把嵌套符号（零件）的帧钉回 firstFrame，
理由是"参考引擎 LF 缺省 → lastFrame=0 → 区间塌成一帧"。这个前提是错的：
    NMV FlxAnimateJson.hx  get_LF() => this.LF ?? this.lastFrame ?? -1   （缺省 -1）
    NMV SymbolInstance.hx  hasLastFrame = (lastFrame > -1)              （缺省 false）
所以参考引擎走的是 wrap(firstFrame + 相对帧, 0, 符号总帧-1)，
和 Dot-Stuff 的 (相对帧 + firstFrame) % symbol.length 完全等价。

本脚本实现的就是这两边一致的算法：
    关键帧 rel   = 帧 - 关键帧起点
    零件 curFF   = LP=PO ? clamp(rel+FF, 0, len-1)
                 : LP=SF ? FF
                 : (rel + FF) % len
    （len = 该符号时间轴总帧数 = FlxSymbol.length = Timeline.totalFrames）

用法：
    python anim-frame-probe.py <图集目录> <根符号名> <起始帧> <结束帧> [零件名...]

    # whitedk 的 idle 段（根符号 '!!!!'，标签 idle_w 覆盖 0..13）
    python anim-frame-probe.py ".../images/characters/story/white/whitedk" '!!!!' 0 13 'knife'

    # 加 --freeze 复现事故版本（所有零件钉 firstFrame）
"""
import json
import os
import sys


def load(atlas_dir):
    with open(os.path.join(atlas_dir, 'Animation.json'), encoding='utf-8') as f:
        return json.load(f)


def index_symbols(data):
    syms = {}
    for s in data['SD']['S']:
        syms[s['SN']] = s
    # 根符号也进字典（NMV 与移植端都把它当作可播放符号）
    syms.setdefault(data['AN']['SN'], data['AN'])
    return syms


def total_frames(sym):
    n = 0
    for layer in sym['TL']['L']:
        for kf in layer['FR']:
            n = max(n, kf['I'] + kf.get('DU', 1))
    return n


def keyframe_at(layer, frame):
    """FlxLayer._get / NMV Layer.getFrameAtIndex 同义：第一个 index+duration > frame 的关键帧。"""
    for kf in layer['FR']:
        if kf['I'] + kf.get('DU', 1) > frame:
            return kf
    return None


def part_frame(rel, ff, lp, length):
    if lp == 'PO':
        return max(0, min(rel + ff, length - 1))
    if lp == 'SF':
        return ff
    return (rel + ff) % length if length > 0 else 0


def render(syms, sym_name, frame, depth, out, freeze, max_depth=16):
    if depth > max_depth:
        return
    sym = syms.get(sym_name)
    if sym is None:
        return
    for layer in sym['TL']['L']:
        kf = keyframe_at(layer, frame)
        if kf is None:
            continue
        rel = frame - kf['I']
        for el in kf.get('E', []):
            si = el.get('SI')
            if si is None:
                out.append((depth, 'limb', el.get('ASI', {}).get('N'), rel))
                continue
            child = si.get('SN')
            ff = si.get('FF') or 0
            lp = si.get('LP') or 'LP'
            cflen = total_frames(syms[child]) if child in syms else 0
            # NMV MovieClipInstance.getFrameIndex(): swfMode ? 推进 : 0
            # 语料里 MC 元件的 FF/LP 恒为空 —— 作者在 Animate 里看到的就是静止的第 0 帧
            if (si.get('ST') or 'G') in ('MC', 'movieclip', 'B', 'button'):
                cf = 0
            elif freeze:
                cf = ff
            else:
                cf = part_frame(rel, ff, lp, cflen)
            out.append((depth, child, None, cf))
            render(syms, child, cf, depth + 1, out, freeze, max_depth)


def main(argv):
    if len(argv) < 5:
        print(__doc__)
        return 1
    atlas_dir, root, start, end = argv[1], argv[2], int(argv[3]), int(argv[4])
    wanted = argv[5:]
    freeze = '--freeze' in wanted
    wanted = [w for w in wanted if w != '--freeze']

    data = load(atlas_dir)
    syms = index_symbols(data)
    print(f'atlas={os.path.basename(atlas_dir)}  root={root}  frames={start}..{end}  freeze={freeze}')

    for f in range(start, end + 1):
        out = []
        render(syms, root, f, 0, out, freeze)
        parts = []
        for depth, name, limb, cf in out:
            label = name if name else limb
            if wanted and not any(w in str(label) for w in wanted):
                continue
            parts.append(f'{label}@{cf}')
        print(f'  frame {f:3d}: ' + '  '.join(parts))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
