#!/usr/bin/env python3
"""NMV 图集「逐动画包围盒」离线复刻（对位 NmvAtlasAnchor.getBounds）。

用途：不构建、不开游戏，直接算出某个符号/动画的包围盒（= 移植端折进
character.offset 的那个 anchor），用来核对运行日志里的
`nmv bounds <key> via=<anim> x= y= w= h=` / `nmv off ... anchor=`。

算法逐行对位 source/nmv/utils/NmvAtlasAnchor.hx：
  符号包围盒 = 并集{ 逐帧包围盒 }
  帧包围盒   = 并集{ 层包围盒 }（Clipper 层跳过；Clipped 层与遮罩层求交）
  层包围盒   = 并集{ 元素包围盒 }（keyframe = 第一个 I+DU > frame 的关键帧）
  元素包围盒 = 位图 → (offset.x, offset.y, w, h) 四角过矩阵
               符号 → 子符号在 (FF + rel, 按 LP 取模/截断/SingleFrame) 帧的包围盒，再过矩阵

用法：
  python anchor-probe.py <图集目录> --symbol up
  python anchor-probe.py <图集目录> --all
  python anchor-probe.py <图集目录> --symbol idle --json-offset 249,-190
      （给 --json-offset 时顺带打印 offset = json + anchor，等价 nmv off 的最后两列）
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from importlib.machinery import SourceFileLoader

_probe = SourceFileLoader('anim_render_probe', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'anim-render-probe.py')).load_module()
Atlas = _probe.Atlas
keyframe_at = _probe.keyframe_at

MAX_DEPTH = 32


def layer_type(layer):
    """flxanimate FlxLayer 的 type：'Clp' → Clipper，Clipped 由 Clpb 字段标出。"""
    lt = layer.get('LT')
    if lt == 'Clp':
        return 'Clipper'
    if layer.get('Clpb'):
        return 'Clipped'
    return 'Normal'


def find_layer(sym, name):
    for layer in sym.get('TL', {}).get('L', []):
        if layer.get('LN') == name:
            return layer
    return None


def mat_of(el):
    si = el.get('SI')
    asi = el.get('ASI')
    src = si if si is not None else asi
    mx = (src or {}).get('MX')
    if not mx:
        return (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
    return (float(mx[0]), float(mx[1]), float(mx[2]), float(mx[3]), float(mx[4]), float(mx[5]))


def transform_points(m, pts):
    a, b, c, d, tx, ty = m
    out = []
    for (x, y) in pts:
        out.append((a * x + c * y + tx, b * x + d * y + ty))
    return out


def bbox(pts):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return (min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys))


def union(a, b):
    if a is None:
        return b
    if b is None:
        return a
    x1 = min(a[0], b[0])
    y1 = min(a[1], b[1])
    x2 = max(a[0] + a[2], b[0] + b[2])
    y2 = max(a[1] + a[3], b[1] + b[3])
    return (x1, y1, x2 - x1, y2 - y1)


def intersect(a, b):
    if a is None or b is None:
        return None
    x1 = max(a[0], b[0])
    y1 = max(a[1], b[1])
    x2 = min(a[0] + a[2], b[0] + b[2])
    y2 = min(a[1] + a[3], b[1] + b[3])
    if x2 <= x1 or y2 <= y1:
        return None
    return (x1, y1, x2 - x1, y2 - y1)


def nested_frame(params, rel, nested_total):
    ff = params.get('FF') or 0
    lp = params.get('LP') or 'LP'
    if nested_total <= 0:
        return 0
    if lp == 'SF':
        return ff
    f = ff + rel
    if lp == 'PO':
        return max(0, min(f, nested_total - 1))
    return f % nested_total


class AnchorProbe:
    def __init__(self, folder, pin_mc=True):
        self.atlas = Atlas(folder)
        self.syms = self.atlas.syms
        self.pin_mc = pin_mc
        self.memo = {}

    def total(self, sn):
        return self.atlas.total_frames(sn)

    def sym_bounds(self, sn):
        sym = self.syms.get(sn)
        if sym is None:
            return None, 0
        total = self.total(sn)
        out = None
        for f in range(total):
            out = union(out, self.frame_bounds(sn, f))
        return out, total

    def frame_bounds(self, sn, frame, depth=0):
        if depth > MAX_DEPTH:
            return None
        sym = self.syms.get(sn)
        if sym is None:
            return None
        key = (sn, frame)
        if key in self.memo:
            return self.memo[key]
        self.memo[key] = None

        out = None
        for layer in sym.get('TL', {}).get('L', []):
            lt = layer_type(layer)
            if lt == 'Clipper':
                continue
            lr = self.layer_bounds(layer, frame, depth)
            if lr is None:
                continue
            if lt == 'Clipped':
                masker = find_layer(sym, layer.get('Clpb'))
                if masker is not None:
                    lr = intersect(lr, self.layer_bounds(masker, frame, depth))
                    if lr is None:
                        continue
            out = union(out, lr)
        self.memo[key] = out
        return out

    def layer_bounds(self, layer, frame, depth):
        kf = keyframe_at(layer, frame)
        if kf is None:
            return None
        rel = frame - kf['I']
        out = None
        for el in kf.get('E', []):
            out = union(out, self.element_bounds(el, rel, depth))
        return out

    def element_bounds(self, el, rel, depth):
        if el.get('visible') is False:
            return None
        m = mat_of(el)
        si = el.get('SI')
        if si is None:
            name = (el.get('ASI') or {}).get('N')
            fr = self.atlas._frames.get(name)
            if fr is None:
                return None
            x = float(fr.get('x', 0)) - float(fr.get('frameX', 0) or 0)
            # spritemap 里 w/h 是裁剪后尺寸；offset 语义 = -frameX（Aseprite/TexturePacker 约定）
            w = float(fr.get('w', 0))
            h = float(fr.get('h', 0))
            if w <= 0 or h <= 0:
                return None
            ox = -float(fr.get('frameX', 0) or 0)
            oy = -float(fr.get('frameY', 0) or 0)
            pts = [(ox, oy), (ox + w, oy), (ox, oy + h), (ox + w, oy + h)]
            return bbox(transform_points(m, pts))

        child = si.get('SN')
        nested = self.syms.get(child)
        if nested is None:
            return None
        total = self.total(child)
        st = si.get('ST') or 'G'
        if self.pin_mc and st in ('MC', 'movieclip', 'B', 'button'):
            cf = 0
        else:
            cf = nested_frame(si, rel, total)
        nb = self.frame_bounds(child, cf, depth + 1)
        if nb is None:
            return None
        x, y, w, h = nb
        pts = [(x, y), (x + w, y), (x, y + h), (x + w, y + h)]
        return bbox(transform_points(m, pts))


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    folder = argv[1]
    opts = {}
    i = 2
    while i < len(argv):
        k = argv[i]
        if k.startswith('--'):
            nxt = argv[i + 1] if i + 1 < len(argv) and not argv[i + 1].startswith('--') else True
            opts[k[2:]] = nxt
            i += 2 if nxt is not True else 1
        else:
            i += 1

    probe = AnchorProbe(folder, pin_mc=not opts.get('no-pin-mc'))
    names = []
    if opts.get('symbol'):
        names = [s.strip() for s in str(opts['symbol']).split(',') if s.strip()]
    elif opts.get('all'):
        # 主符号排最前：white 这类"动画都在主时间轴上用 label 定位"的角色，
        # 运行时 resolveSymbol 会拆包回主符号，anchor 用的就是它（不是 SD 里的子符号）
        root = probe.atlas.root.get('SN')
        names = ([root] if root else []) + [s['SN'] for s in probe.atlas.anim['SD']['S']]
    else:
        print(__doc__)
        return 1

    joff = None
    if opts.get('json-offset'):
        joff = [float(v) for v in str(opts['json-offset']).split(',')]

    for sn in names:
        b, total = probe.sym_bounds(sn)
        if b is None:
            print(f'{sn:28s} frames={total:3d}  <空>')
            continue
        line = f'{sn:28s} frames={total:3d} x={b[0]:8.1f} y={b[1]:8.1f} w={b[2]:7.1f} h={b[3]:7.1f}'
        if joff is not None:
            line += f'  -> off={joff[0] + b[0]:8.1f},{joff[1] + b[1]:8.1f}'
        print(line)
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
