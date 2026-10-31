#!/usr/bin/env python3
"""NMV / flxanimate（Dot-Stuff）图集离线光栅化器。

用途：把 Animation.json + spritemap1.json + spritemap1.png 按**移植端的算法**
逐帧画成 PNG，用来肉眼核对"零件到底渲染成什么样"。不需要构建、不需要开游戏。

算法（与 Dot-Stuff flxanimate / NMV flixel-animate 两边一致的那套）：
  播放动画 = 选中某个符号 + 一串帧号
  每帧：根符号.timeline 按帧号取当前关键帧 → 关键帧内相对帧 rel = frame - kf.index
        每个元素：
          ASI(位图/limb) → 用元素矩阵画该 limb
          SI(符号实例)   → 子帧 = (rel + FF) % 子符号总帧数   [LP=Loop]
                          = clamp(rel + FF, 0, len-1)        [LP=PlayOnce]
                          = FF                                [LP=SingleFrame]
                          → 递归画子符号
  矩阵：final = elementMatrix × parentMatrix（openfl concat 语义，先元素后父级）

用法：
  python anim-render-probe.py <图集目录> --anim idle --frames 0-6 --out out/
  python anim-render-probe.py <图集目录> --symbol down --list-frames 0,2,4
  # 可选：--pin-bits  零件只显示 FF 帧（不随父时间线推进），用来 A/B 对比
  #      --scale 0.5   --char <角色json路径>（--anim 用角色 json 里的 name/indices）
"""
import json
import os
import struct
import sys
import zlib

# ---------- PNG ----------

def png_load(path):
    d = open(path, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n'
    i = 8
    w = h = None
    idat = b''
    while i < len(d):
        ln = struct.unpack('>I', d[i:i + 4])[0]
        typ = d[i + 4:i + 8]
        body = d[i + 8:i + 8 + ln]
        if typ == b'IHDR':
            w, h, bd, ct, comp, filt, il = struct.unpack('>IIBBBBB', body)
            assert bd == 8 and ct == 6 and il == 0, 'only RGBA8 non-interlaced'
        elif typ == b'IDAT':
            idat += body
        elif typ == b'IEND':
            break
        i += 12 + ln
    raw = zlib.decompress(idat)
    stride = w * 4
    out = bytearray(w * h * 4)
    prev = bytearray(stride)
    pos = 0
    for y in range(h):
        f = raw[pos]; pos += 1
        line = bytearray(raw[pos:pos + stride]); pos += stride
        if f == 1:
            for x in range(4, stride):
                line[x] = (line[x] + line[x - 4]) & 0xFF
        elif f == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 0xFF
        elif f == 3:
            for x in range(stride):
                a = line[x - 4] if x >= 4 else 0
                line[x] = (line[x] + ((a + prev[x]) >> 1)) & 0xFF
        elif f == 4:
            for x in range(stride):
                a = line[x - 4] if x >= 4 else 0
                b = prev[x]
                c = prev[x - 4] if x >= 4 else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 0xFF
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return w, h, out


def png_save(path, w, h, buf):
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)
        raw += buf[y * stride:(y + 1) * stride]
    comp = zlib.compress(bytes(raw), 6)

    def chunk(typ, body):
        return struct.pack('>I', len(body)) + typ + body + struct.pack('>I', zlib.crc32(typ + body) & 0xFFFFFFFF)

    out = b'\x89PNG\r\n\x1a\n'
    out += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    out += chunk(b'IDAT', comp)
    out += chunk(b'IEND', b'')
    open(path, 'wb').write(out)


# ---------- 图集 ----------

class Atlas:
    def __init__(self, folder):
        self.dir = folder
        self.anim = json.load(open(os.path.join(folder, 'Animation.json'), encoding='utf-8'))
        self.syms = {s['SN']: s for s in self.anim['SD']['S']}
        self.root = self.anim['AN']
        self.syms.setdefault(self.root['SN'], self.root)
        self._frames = {}
        self._load_spritemap()
        self._png = None

    def _load_spritemap(self):
        for name in ('spritemap1.json', 'spritemap.json', 'spritemap0.json'):
            p = os.path.join(self.dir, name)
            if os.path.exists(p):
                d = json.load(open(p, encoding='utf-8'))
                for s in d['ATLAS']['SPRITES']:
                    sp = s['SPRITE']
                    self._frames[sp['name']] = sp
                img = d.get('meta', {}).get('image')
                self._img = os.path.join(self.dir, img) if img else os.path.join(self.dir, name.replace('.json', '.png'))
                return
        raise SystemExit('no spritemap json in ' + self.dir)

    def png(self):
        if self._png is None:
            self._png = png_load(self._img)
        return self._png

    def total_frames(self, sn):
        s = self.syms.get(sn)
        if s is None:
            return 0
        n = 0
        for L in s['TL']['L']:
            for f in L['FR']:
                n = max(n, f['I'] + f.get('DU', 1))
        return n

    def labels(self):
        out = {}
        for L in self.root['TL']['L']:
            for f in L['FR']:
                if f.get('N'):
                    out[f['N']] = (f['I'], f.get('DU', 1))
        return out


def keyframe_at(layer, frame):
    for kf in layer['FR']:
        if kf['I'] + kf.get('DU', 1) > frame:
            return kf
    return None


def part_frame(rel, ff, lp, length):
    if lp == 'PO':
        return max(0, min(rel + ff, length - 1)) if length else 0
    if lp == 'SF':
        return ff
    return (rel + ff) % length if length else 0


# ---------- 光栅化 ----------

def mat_mul(m, p):
    """final = m × p （先 m 后 p），FlxMatrix(a,b,c,d,tx,ty)。"""
    a1, b1, c1, d1, tx1, ty1 = m
    a2, b2, c2, d2, tx2, ty2 = p
    return (
        a1 * a2 + b1 * c2,
        a1 * b2 + b1 * d2,
        c1 * a2 + d1 * c2,
        c1 * b2 + d1 * d2,
        tx1 * a2 + ty1 * c2 + tx2,
        tx1 * b2 + ty1 * d2 + ty2,
    )


def collect(atlas, sn, frame, parent, draws, pin_bits, depth=0, max_depth=24, nmv_mc=True):
    if depth > max_depth:
        return
    sym = atlas.syms.get(sn)
    if sym is None:
        return
    for layer in sym['TL']['L']:
        kf = keyframe_at(layer, frame)
        if kf is None:
            continue
        rel = frame - kf['I']
        for el in kf.get('E', []):
            mx = el.get('ASI', {}).get('MX') if 'ASI' in el else el.get('SI', {}).get('MX')
            m = (mx[0], mx[1], mx[2], mx[3], mx[4], mx[5]) if mx else (1, 0, 0, 1, 0, 0)
            final = mat_mul(m, parent)
            si = el.get('SI')
            if si is None:
                limb = el.get('ASI', {}).get('N')
                if limb in atlas._frames:
                    draws.append((atlas._frames[limb], final))
                continue
            child = si.get('SN')
            ff = si.get('FF') or 0
            lp = si.get('LP') or 'LP'
            clen = atlas.total_frames(child)
            st = si.get('ST') or 'G'
            if nmv_mc and st in ('MC', 'movieclip', 'B', 'button'):
                # NMV MovieClipInstance.getFrameIndex() -> swfMode ? super : 0
                cf = 0
            elif pin_bits:
                cf = ff
            else:
                cf = part_frame(rel, ff, lp, clen)
            collect(atlas, child, cf, final, draws, pin_bits, depth + 1, max_depth, nmv_mc)


def render(atlas, draws, scale=1.0, pad=8):
    tw, th, tex = atlas.png()
    # 先算包围盒
    minx = miny = 1e18
    maxx = maxy = -1e18
    for fr, m in draws:
        for (x, y) in ((0, 0), (fr['w'], 0), (0, fr['h']), (fr['w'], fr['h'])):
            px = m[0] * x + m[2] * y + m[4]
            py = m[1] * x + m[3] * y + m[5]
            minx = min(minx, px); maxx = max(maxx, px)
            miny = min(miny, py); maxy = max(maxy, py)
    if minx > maxx:
        return None
    w = int((maxx - minx) * scale) + pad * 2
    h = int((maxy - miny) * scale) + pad * 2
    canvas = bytearray(w * h * 4)

    for fr, m in draws:
        # 目标像素 → 源像素（逆变换），最近邻
        a, b, c, d, tx, ty = m
        det = a * d - b * c
        if abs(det) < 1e-9:
            continue
        ia, ib, ic, id_ = d / det, -b / det, -c / det, a / det
        fx, fy = fr['x'], fr['y']
        fw, fh = fr['w'], fr['h']
        # 元素局部坐标范围 → 目标范围
        pts = [(0, 0), (fw, 0), (0, fh), (fw, fh)]
        tpts = [(m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5]) for x, y in pts]
        x0 = int((min(p[0] for p in tpts) - minx) * scale) + pad
        x1 = int((max(p[0] for p in tpts) - minx) * scale) + pad + 1
        y0 = int((min(p[1] for p in tpts) - miny) * scale) + pad
        y1 = int((max(p[1] for p in tpts) - miny) * scale) + pad + 1
        x0 = max(0, x0); y0 = max(0, y0); x1 = min(w, x1); y1 = min(h, y1)
        for dy in range(y0, y1):
            wy = (dy - pad) / scale + miny
            for dx in range(x0, x1):
                wx = (dx - pad) / scale + minx
                lx = wx * ia + wy * ic + (-minx * 0 - 0)  # 占位，下面重算
                # 逆变换：局部 = m^-1 * (世界)
                ox = wx - tx
                oy = wy - ty
                lx = ox * ia + oy * ic
                ly = ox * ib + oy * id_
                if lx < 0 or ly < 0 or lx >= fw or ly >= fh:
                    continue
                sx = fx + int(lx)
                sy = fy + int(ly)
                if fr.get('rotated'):
                    sx, sy = fx + int(ly), fy + int(fw - 1 - lx)
                if sx < 0 or sy < 0 or sx >= tw or sy >= th:
                    continue
                si = (sy * tw + sx) * 4
                sa = tex[si + 3]
                if sa == 0:
                    continue
                sr, sg, sb = tex[si], tex[si + 1], tex[si + 2]
                di = (dy * w + dx) * 4
                da = canvas[di + 3]
                if da == 0:
                    canvas[di] = sr; canvas[di + 1] = sg; canvas[di + 2] = sb; canvas[di + 3] = sa
                else:
                    af = sa / 255.0
                    iaf = 1.0 - af
                    na = sa + da * iaf
                    canvas[di] = int((sr * sa + canvas[di] * da * iaf) / na)
                    canvas[di + 1] = int((sg * sa + canvas[di + 1] * da * iaf) / na)
                    canvas[di + 2] = int((sb * sa + canvas[di + 2] * da * iaf) / na)
                    canvas[di + 3] = int(na)
    return w, h, canvas


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
            opts[k[2:]] = argv[i + 1] if i + 1 < len(argv) and not argv[i + 1].startswith('--') else True
            i += 2 if not isinstance(opts[k[2:]], bool) else 1
        else:
            i += 1
    atlas = Atlas(folder)
    out_dir = opts.get('out', 'out')
    os.makedirs(out_dir, exist_ok=True)
    scale = float(opts.get('scale', 0.5))
    pin = bool(opts.get('pin-bits'))

    sym = opts.get('symbol')
    frames = None
    if opts.get('anim'):
        anim_name = opts['anim']
        cj = opts.get('char')
        if cj:
            ch = json.load(open(cj, encoding='utf-8'))
            ent = [a for a in ch['animations'] if a.get('anim') == anim_name]
            if not ent:
                print('no anim', anim_name)
                return 1
            ent = ent[0]
            nm = ent.get('name')
            idx = ent.get('indices') or []
            labs = atlas.labels()
            if nm in labs:
                base = labs[nm][0]
                frames = [base + k for k in idx] if idx else list(range(base, base + labs[nm][1]))
                sym = atlas.root['SN']
            else:
                sym = nm
                frames = idx if idx else list(range(atlas.total_frames(nm)))
        else:
            sym = anim_name
            frames = None
    if opts.get('list-frames'):
        frames = [int(x) for x in str(opts['list-frames']).split(',')]
    if frames is None:
        frames = list(range(atlas.total_frames(sym)))
    if opts.get('frames') and not opts.get('list-frames'):
        a, _, b = str(opts['frames']).partition('-')
        frames = [f for f in frames if int(a) <= f <= int(b or a)]

    print(f'atlas={os.path.basename(folder)} symbol={sym} frames={frames} pin={pin} scale={scale}')
    for f in frames:
        draws = []
        collect(atlas, sym, f, (1, 0, 0, 1, 0, 0), draws, pin)
        r = render(atlas, draws, scale)
        if r is None:
            print('  frame', f, 'empty')
            continue
        w, h, buf = r
        p = os.path.join(out_dir, f'f{f:03d}.png')
        png_save(p, w, h, buf)
        print(f'  frame {f} -> {p} ({w}x{h}, {len(draws)} draws)')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
