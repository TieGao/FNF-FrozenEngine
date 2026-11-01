# 67 · 带单引号的歌名不加载（`d'low` / `don't-lied`）— 2026-11-01 上午

## 1. 现象与日志铁证

Freeplay 里点 `D'low` 反复弹回，`crash/latest.log`：

```
[09:05:43] FreeplayState.hx:2618: ERROR! [lime.utils.Assets] ERROR:
  There is no TEXT asset with an ID of "assets/shared/data/dlow/dlow-hard.json"
```

`d'low` 变成了 `dlow`。

## 2. 根因

`Paths.formatToSongPath` 的 `hideChars` 正则是 `~/[.,'"%?!]/g` —— **包含单引号**：

```haxe
final hideChars = ~/[.,'"%?!]/g;
return hideChars.replace(invalidChars.replace(path, '-'), '').trim().toLowerCase();
```

而 NMV 内容包的歌曲目录是**裸目录名**，单引号原样保留：

| 歌 | 实际目录 | 脚本 |
|---|---|---|
| D'low | `legacy/songs/d'low/` | `d'low.hx` |
| Don't Lied | `securitydlc/songs/don't-lied/` | `don't-lied.hx` |

`d'low` → `dlow` → `Song.getChart` 里
`Paths.json('dlow/dlow-hard')` 不存在 → `findNmvChart('dlow', 'dlow-hard')` 拼
`$root/songs/dlow/data/normal.json` 也不存在 → 抛异常 → Freeplay 弹回。

（`Inst.ogg` / `Voices.ogg` / 脚本同理：`Paths.inst/voices` 也都走 `formatToSongPath`。）

## 3. 改动

### 3.1 `source/backend/Paths.hx` · `formatToSongPath`

把 `'` 从 `hideChars` 里去掉：

```haxe
final hideChars = ~/[.,"%?!]/g;   // 单引号是合法文件名字符，不删
```

**为什么安全**：`'` 在 NTFS / EXT4 上都是合法字符；标准 FE 谱面与资源目录名从不含它，
所以对既有加载路径没有影响（原来把 `'` 删掉反而让所有带引号的目录永远找不到）。

### 3.2 `source/backend/Song.hx` · `findNmvChart` 兜底

万一某个内容包当初是按"去引号目录"（`songs/dlow/`）建的，改完后会反而找不到。
所以在候选全 miss 后补一次去引号探测：

```haxe
if (folder.indexOf("'") >= 0) {
    final stripped = folder.split("'").join('');
    for (candidate in candidates) {
        final alt = candidate.split('/$folder/').join('/$stripped/');
        if (alt != candidate && FileSystem.exists(alt)) return alt;
    }
}
```

## 4. 影响面盘点

| 调用点 | 之前 | 现在 |
|---|---|---|
| 谱面 `Song.getChart` | `dlow/dlow-hard` ✗ | `d'low/d'low-hard` → miss → `findNmvChart('d'low', …)` ✓ |
| 音轨 `Paths.inst/voices` | `songs/dlow/Inst.ogg` ✗ | `songs/d'low/Inst.ogg` ✓ |
| 歌曲脚本 `songs/<folder>/<folder>.hx` | `songs/dlow/dlow.hx` ✗ | `songs/d'low/d'low.hx` ✓ |
| 标准 FE 歌（目录无引号） | 不变 | 不变 |
| 难度回退 | `hard` → miss → `normal.json` | 同（`d'low-hard` 的 `lastIndexOf('-')` 仍能正确切成 `hard`） |

`don't-lied` 名字里自带连字符，`findNmvChart` 用 `lastIndexOf('-')` 取难度，
仍然落在最后一个 `-`（`don't-lied-normal` → `normal`）✓

## 5. 验证

```bash
haxe _nmvcheck.hxml > /tmp/log 2>&1; echo $?   # 0，零输出
```

## 6. 待实测

1. Freeplay 点 `D'low` 能进游戏（`latest.log` 不再出现 `assets/shared/data/dlow/...`）。
2. `Don't Lied` 同样。
3. 其他不带引号的歌回归一次（`formatToSongPath` 是全局函数，虽然理论上无影响）。
