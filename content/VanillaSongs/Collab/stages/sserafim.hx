// ============================================================================
//  LE SSERAFIM - SPAGHETTI 舞台（FrozenEngine / HScript）
// ----------------------------------------------------------------------------
//  移植自 V-Slice 0.8.7：
//    D:/funkin.assets/preload/scripts/stages/sserafim.hxc
//    D:/funkin.assets/preload/scripts/stages/props/{PerspectiveSprite,
//        SserafimCutsceneSprite,SserafimGfSprite,SserafimBfSprite,
//        SserafimLipSyncSprite}.hxc
//  资源静态部分在 ../shared/stages/sserafim.json（bg / 桌椅 / 卡车 / 灯光 / 前凳 /
//  过场吧台 / 过场汉堡），本脚本只管"动"的部分。
//
//  Iris HScript：不能声明 class，所有东西都是顶层函数 + 顶层变量。
//
//  目录：
//    §0  调参表（改动基本都在这里）
//    §1  状态
//    §2  小工具
//    §3  shader（SserafimShader 运行时版）
//    §4  相机
//    §5  外观（resetLook / startClear）
//    §6  女团角色
//    §7  嘴型 lipsync  ← 每条嘴绑定的成员/偏移都在这张表里
//    §8  透视地板
//    §9  尘埃
//    §10 过场
//    §11 歌曲事件
//    §12 节拍 / 音符 / 调试
//    §13 结尾
//    §14 生命周期
// ============================================================================

import flixel.addons.display.FlxBackdrop;
import flixel.addons.effects.FlxSkewedSprite;
import sys.io.File;
import sys.FileSystem;
import Date;

// ============================================================================
//  §0  调参表
// ============================================================================

// ---- 舞台基准 zoom -----------------------------------------------------------
// 官方 stage json `cameraZoom: 0.5`，V-Slice 的 direct 模式缩放倍率是 FlxCamera.defaultZoom(=1.0)，
// 所以事件换算就是 `zoom * 1.0`。之前这里写成 0.45 / ×0.9，整个画面比原版宽 11%。
var STAGE_BASE_ZOOM = 0.5;
var CUTSCENE_ZOOM_IN = 0.7;      // 过场推近
var CUTSCENE_ZOOM_REST = 0.55;   // 撞车后回落的站立镜头

// ---- 嘴型全局微调 ------------------------------------------------------------
// 五个嘴如果整体偏同一个方向，只改这两个数；单个嘴歪了改 §7 表里的 calib。
var MOUTH_GLOBAL_X = 0.0;
var MOUTH_GLOBAL_Y = 0.0;

// 嘴型图集里嘴的"锚点"（导出 FLA 的画布坐标，见 §7 说明）。一般不用动。
var MOUTH_PIVOT_SHARED = [263.8, 195.85];      // sserafim-lipsync
var MOUTH_PIVOT_YUNJIN = [229.6, 204.45];      // sserafim-lipsync-yunjin

// F2 打开调试：在每个嘴的位置画一条带名字的标记，方便肉眼对位。
var MOUTH_DEBUG = false;

// ---- 其它开关 ---------------------------------------------------------------
// 官方 onSongLoaded 里 PlayState.remove(comboPopUps)：这舞台不要评级弹窗。
// FE 没有这个组（每次判定临时造精灵），所以改成每帧把活跃弹窗组隐藏。
var HIDE_RATING_POPUPS = true;

// ============================================================================
//  §1  状态
// ============================================================================

// ---- shader ----
var characterShader = null;
var stageShader = null;

// ---- 女团 ----
// 槽位顺序 = 官方事件数组顺序：0 yunjin / 1 kazuha(dad) / 2 chaewon / 3 eunchae / 4 sakura(bf)
var yunjin = null;
var chaewon = null;
var eunchae = null;

// 只给日志用。**不要**在读日志的地方直接访问 MOUTHS：
// Iris 里顶层 var 声明晚于函数定义时，函数体内解析不到那个名字
// （实测 goodNoteHit → girlSing 报 "Unknown variable: MOUTHS"）。
var GIRL_NAMES = ['yunjin', 'kazuha', 'chaewon', 'eunchae', 'sakura'];

var baseVisible = [true, false, false, false, false];
var girlsVisible = [true, false, false, false, false];
var girlsSinging = [false, false, false, false, false];
var girlHold = [0, 0, 0, 0, 0];
var singLogAt = -99999.0;
var gfBeautiful = false;
var gfDanceFlip = false;
var gfHold = 0;        // gf 唱姿保持的剩余拍数（0 = 可以回去跳舞）

// ---- 舞台物件 ----
var props = null;
var dust1 = null; var dust2 = null; var dust3 = null; var dust4 = null;
var solidCover = null;
var floorSpr = null;
var floorTopX = 790.0; var floorTopY = 625.0;
var floorBottomX = 760.0; var floorBottomY = 1375.0;

// ---- 过场 ----
var hasPlayedCutscene = false;
var cutsceneActive = false;
var cutsceneSkipped = true;
var canSkipCutscene = true;
var skipText = null;
var cutsceneSprite = null;
var sserafimGf = null;
var sserafimBf = null;
var SEEYOU1 = null;
var SEEYOU2 = null;
var cutsceneSound = null;
// gf/bf 起身图集按"帧标签区间"播，记下区间结束帧，播到就停格
var gfStopFrame = -1;
var bfStopFrame = -1;
var yunjinDance = false;
var doorFrameHooked = false;
var doorShownFinal = false;

// 过场定时器"代"号：finish / skip 之后 cutsceneGen + 1，之前排下的回调全部作废。
// 少了这层，跳过过场时 @563 crash / @650 getup 这些 timer 会在歌里继续跑 ——
// 表现就是"玩到一半突然播开局事件（白闪 / 重新摆人物 / 再倒计时一次）"。
//
// ⚠ 绝对不能写 `cutsceneGen++`：hscript-iris 的 `++` / `--` **对脚本级变量不写回**
//   （实测 `var G=0; function f(){G++;} f(); G` 还是 0，函数内局部 var 也一样）。
//   一旦用了 ++，代号永远不变 = 所有过场 timer 全部照旧触发。
var cutsceneGen = 0;

// 所有过场定时器的实体，跳过/结束时逐个 cancel（FlxTimer 是全局的，不等脚本销毁）
var cutTimers = [];
// 结尾演出的定时器（endStuff）
var endTimers = [];

// 开头 gf/bf 起身精灵的 y 微调（负数 = 往上）。用户实机校准。
// gf 基准 -104、bf 基准 531（官方坐标）。
var CUT_BFGF_Y_SHIFT = -80.0;

// 过场取景的目标屏幕中心（fitAnimateCenter 用）。
var CUT_FIT_X = 640.0;
var CUT_FIT_Y = 180.0;
var cutFitted = false;

// 酒吧交谈场景整体下移（实机校准旋钮，单位 = 屏幕像素，正 = 往下，负 = 往上）。
// gf/bf 画在过场图集里，图集是一整块精灵 —— gf/bf 不单独动，动就是三层同量一起动：
//   1) 过场图集：取景中心 = CUT_FIT_Y + SHIFT/0.7（fit 是"预缩放屏空间"，除以推近 zoom
//      后屏幕上正好下移 SHIFT 像素；图集里的吧台画 + gf/bf 整块一起走）；
//   2) 过场专用世界道具（拉长吧台/汉堡）：y += SHIFT/0.7；
//   3) 过场地板：updateFloorSkew 里对 floorTopY/floorBottomY 加同样的量，只在过场生效。
// 三层屏幕位移完全相等，相对对位不会脱开。微调只改这一个数。
// ⚠ 为什么不挪镜头：过场期间 PlayState 每帧把 camGame.followLerp 压成 0（inCutscene 分支），
//   flixel updateLerp 在 lerp==0 时直接跳过 scroll 更新 —— 镜头整个过场冻在初始 scroll，
//   camPosTo 的 camFollow tween 视觉上完全无效（实机日志 cam=1149,232 全程不变可证）。
var CUT_SCENE_SHIFT_Y = 200.0;
var cutFloorShift = 0.0;   // 过场地板当前生效的下移量（setCutsceneVisibility 里切换，切回 0）

// gf 戳自己 / 戳 bf 那一下：官方脚本只有 HapticUtil.vibrate(PC 上是空实现) + 一帧变暗，
// 所以这里补一个很轻的镜头顿挫（强度是屏幕比例，0.003 ≈ 4px）。
var POKE_SHAKE = true;
var POKE_SHAKE_POWER = 0.003;
var POKE_SHAKE_TIME = 0.12;

// ---- 性能 ----
var popupsOff = false;
var LOG_HOT = false;          // 逐音符 / 逐事件的日志（会开文件，默认关）
var shadersOff = false;       // F3 调试开关
var PERF_LOG = true;          // F4 开关；日志里 perf fps/worst 就是它写的
var perfAccum = 0.0;
var perfFrames = 0;
var perfWorst = 0.0;

// ---- 脉冲灯 ----
var lightsEnabled = false;
var lightsColors = [];
var lightsDurations = [];
var lightsIntensities = [];

// ---- 相机 ----
var stageBaseZoom = STAGE_BASE_ZOOM;
var camZoomTween = null;
var camPosTween = null;
// 正在跑的调色 / 变暗 tween（跳过过场时要掐掉，不然会在歌里继续改画面）
var adjustTween = null;
var darkTween = null;

// ---- 一次性标志 ----
var strumsHidden = false;
var popupTick = 0;

// ============================================================================
//  §2  小工具
// ============================================================================

function ps() return PlayState.instance;

function getProp(name) {
	if (props == null) return null;
	return props.get(name);
}

// 脚本自己的落盘日志。release 下 trace 不落盘、FlxG.log 也只进控制台，
// 排查"过场到底走到哪一步"只能自己写文件。
function slog(msg) {
	try {
		var f = File.append('crash/sserafim.log', false);
		f.writeString(Date.now().toString() + ' ' + msg + '\n');
		f.close();
	} catch (e:Dynamic) {
		try { trace('[sserafim] ' + msg); } catch (e2:Dynamic) {}
	}
}

// 精灵在屏幕上的落点体检（判断"看不见"是画面外还是没画）。
// 换算：screen = (world - cam.scroll * scrollFactor) * zoom + 屏幕中心 * (1 - zoom)
function probeSprite(tag, spr) {
	var p = ps();
	if (spr == null) { slog('probe ' + tag + ': null'); return; }
	var s = 'probe ' + tag;
	try { s += ' pos=' + Math.round(spr.x) + ',' + Math.round(spr.y); } catch (e:Dynamic) {}
	try { s += ' wh=' + Math.round(spr.width) + 'x' + Math.round(spr.height); } catch (e:Dynamic) {}
	try { s += ' rel=' + Math.round(spr.relativeX) + ',' + Math.round(spr.relativeY); } catch (e:Dynamic) {}
	try { s += ' sf=' + spr.scrollFactor.x + ',' + spr.scrollFactor.y; } catch (e:Dynamic) {}
	try { s += ' vis=' + spr.visible + ' alpha=' + spr.alpha; } catch (e:Dynamic) {}
	try { s += ' cf=' + spr.anim.curFrame + ' sym=' + spr.anim.curSymbol.name; } catch (e:Dynamic) {}
	if (p != null && p.camGame != null) {
		try {
			s += ' cam=' + Math.round(p.camGame.scroll.x) + ',' + Math.round(p.camGame.scroll.y) + ' z=' + p.camGame.zoom;
		} catch (e:Dynamic) {}
		// 真正画到屏幕上的矩形（用 flxanimate 回填的 rel/wh 换算，见 fitAnimateCenter）
		try {
			var z = p.camGame.zoom;
			var px = spr.x + spr.relativeX;
			var py = spr.y + spr.relativeY;
			var sx = px * z + 640 * (1 - z);
			var sy = py * z + 360 * (1 - z);
			s += ' screen=' + Math.round(sx) + ',' + Math.round(sy)
				+ ' to=' + Math.round((px + spr.width) * z + 640 * (1 - z))
				+ ',' + Math.round((py + spr.height) * z + 360 * (1 - z));
		} catch (e:Dynamic) {}
	}
	slog(s);
}

// FlxAnimate 的取景校正 -------------------------------------------------------------------
// flxanimate 的 draw() 把图集画在"(世界坐标 - scroll*scrollFactor)"这个"预缩放屏空间"里，
// 然后把**实际画到的矩形**回填进 width/height，把 (矩形 - x/y) 回填进 relativeX/Y。
// ⇒ 想让这块美术在屏幕上居中，直接：
//      x = 屏幕中心X - relativeX - width/2     （y 同理）
// 两个理由让这一行就够：
//   1. relativeX = 图集内部偏移 - scroll*sf，公式里的 scroll 项正好抵消 → 与镜头无关；
//   2. relativeX 对 x 的平移是不变量（x 改了，回填的矩形跟着改），所以反复调用不会漂。
// 官方用 FunkinSprite 自己的 frame 原点处理这层偏移，我们是裸 FlxAnimate，必须自己补，
// 否则 cutsceneMain 会整块掉到画面下方约 1000px（只剩舞台道具的静态吧台，看不见 gf/bf）。
function fitAnimateCenter(spr, cx, cy) {
	if (spr == null) return false;
	if (spr.width <= 0 || spr.height <= 0) return false;
	spr.setPosition(cx - spr.relativeX - spr.width * 0.5,
					cy - spr.relativeY - spr.height * 0.5);
	return true;
}

// 图集精灵体检。FlxAnimate.draw() 会把 _flashRect（本帧真正画到的范围）写进 width/height，
// 所以 wh>0 = 真的画出了东西；wh=0 = 一帧都没画（图集/符号/元素某一环断了）。
// 过场"空场景"到底属于哪一种，靠这行日志区分。
function dumpAnimate(tag, spr) {
	if (spr == null) { slog(tag + ': null'); return; }
	var s = tag;
	try { s += ' wh=' + spr.width + 'x' + spr.height; } catch (e:Dynamic) {}
	try { s += ' f=' + spr.frameWidth + 'x' + spr.frameHeight; } catch (e:Dynamic) {}
	try { s += ' pos=' + spr.x + ',' + spr.y; } catch (e:Dynamic) {}
	try { s += ' rel=' + spr.relativeX + ',' + spr.relativeY; } catch (e:Dynamic) {}
	try { s += ' org=' + spr.origin.x + ',' + spr.origin.y; } catch (e:Dynamic) {}
	try { s += ' cf=' + spr.anim.curFrame + '/' + spr.anim.length; } catch (e:Dynamic) {}
	try { s += ' play=' + (spr.anim.isPlaying ? 1 : 0); } catch (e:Dynamic) {}
	try { s += ' sym=' + spr.anim.curSymbol.name; } catch (e:Dynamic) {}
	try { s += ' layers=' + spr.anim.curSymbol.timeline.getList().length; } catch (e:Dynamic) {}
	try { s += ' inst=' + spr.anim.curInstance.name + ',vis=' + spr.anim.curInstance.visible; } catch (e:Dynamic) {}
	try { s += ' frames=' + spr.frames.numFrames; } catch (e:Dynamic) {}
	slog(s);

	// 根时间轴每一层的名字 + 帧数。层数对但 wh=0 → 是元素/帧的问题；
	// 层数不对 → 是 TL 解析的问题（0 帧的"文件夹层"、重名层都在这看）。
	try {
		var ls = spr.anim.curSymbol.timeline.getList();
		var s2 = '';
		var n = ls.length;
		if (n > 32) n = 32;
		for (k in 0...n) s2 += ls[k].name + '(' + ls[k].length + ')';
		slog(tag + ' layers: ' + s2);
	} catch (e:Dynamic) { slog(tag + ' layers FAILED ' + e); }
}

// FlxAnimate 的符号名各图集不同 —— 失败就退回默认符号，别让过场崩掉
function tryAnim(spr, name) {
	if (spr == null || spr.anim == null) return;
	try { spr.anim.play(name, true); } catch (e:Dynamic) { try { spr.anim.play(); } catch (e2:Dynamic) {} }
}

// 图集里的"命名区间"（layer0 的 N/DU，如 gfGetUp 的 static / getup）**不是符号**。
// FlxAnim.play('名字') 只查 animsMap / metadata.name / symbolDictionary，认不出帧标签，
// 官方靠 FunkinAnimationController 兜了这一层，我们这边没有 —— 只能自己按标签定位。
function labelIndex(spr, name) {
	if (spr == null || spr.anim == null) return -1;
	var idx = -1;
	try {
		var kf = spr.anim.getFrameLabel(name);
		if (kf != null) idx = kf.index;
	} catch (e:Dynamic) {}
	return idx;
}

function labelDuration(spr, name) {
	if (spr == null || spr.anim == null) return 0;
	var d = 0;
	try {
		var kf = spr.anim.getFrameLabel(name);
		if (kf != null) d = kf.duration;
	} catch (e:Dynamic) {}
	return d;
}

// 定格在某个标签的首帧
function holdLabel(spr, name) {
	if (spr == null) return;
	tryAnim(spr, '');
	var idx = labelIndex(spr, name);
	try {
		spr.anim.curFrame = (idx >= 0) ? idx : 0;
		spr.anim.pause();
	} catch (e:Dynamic) {}
}

// 从标签首帧开始播，返回区间结束帧（-1 = 没找到这个标签）
function playLabel(spr, name) {
	if (spr == null) return -1;
	tryAnim(spr, '');
	var idx = labelIndex(spr, name);
	var dur = labelDuration(spr, name);
	if (idx < 0) {
		try { spr.anim.resume(); } catch (e:Dynamic) {}
		return -1;
	}
	try {
		spr.anim.curFrame = idx;
		spr.anim.resume();
	} catch (e:Dynamic) {}
	return (dur > 0) ? (idx + dur - 1) : -1;
}

// 角色当前播的动画名。Character.getAnimationName() 是 inline，反射拿不到，直接读私有字段。
function currentAnim(c) {
	if (c == null) return 'idle';
	var n = Reflect.field(c, '_lastPlayedAnimation');
	return (n == null || n == '') ? 'idle' : n;
}

// 把 spr 插到 prop 之后（图层顺序靠数组顺序，FE 的 stage json 没有 zIndex）
// 找不到目标就放最底层，别默认丢到最上面（那会盖住所有东西）
function insertAfterProp(spr, propName) {
	var p = ps();
	var target = getProp(propName);
	var idx = 0;
	if (target != null) {
		for (i in 0...p.members.length) {
			if (p.members[i] == target) { idx = i + 1; break; }
		}
	}
	p.insert(idx, spr);
	return idx;
}

function indexBehindFrontStool() {
	var p = ps();
	var front = getProp('frontStool');
	var idx = 0;
	if (front != null) {
		for (i in 0...p.members.length) {
			if (p.members[i] == front) { idx = i; break; }
		}
	}
	return idx;
}

// ============================================================================
//  §3  shader
// ============================================================================

function newShader(isChar) {
	var src = Paths.getTextFromFile('shaders/sserafim.frag');
	if (src == null || src.length < 1) {
		// 内容包回退未必命中 shaders/ —— 直接读磁盘
		try {
			var p = Paths.currentContentRoot + '/sserafim/shaders/sserafim.frag';
			if (FileSystem.exists(p)) src = File.getContent(p);
		} catch (e:Dynamic) { src = null; }
	}
	if (src == null || src.length < 1) return null;
	var sh = null;
	try {
		sh = new FlxRuntimeShader(src);
	} catch (e:Dynamic) { return null; }
	sh.setBool('isChar', isChar);
	sh.setFloat('darkAmt', 0);
	sh.setFloat('pulseStrength', 0);
	sh.setFloat('truckStrength', 0);
	sh.setFloatArray('lightColor', [1, 1, 1]);
	adjustColor(sh, 0, 0, 0, 0);
	return sh;
}

function adjustColor(sh, b, h, c, s) {
	if (sh == null) return;
	sh.setFloat('brightness', b);
	sh.setFloat('hue', h);
	sh.setFloat('contrast', c);
	sh.setFloat('saturation', s);
}

function getAdjust(sh) {
	if (sh == null) return [0, 0, 0, 0];
	var out = [0, 0, 0, 0];
	try {
		out = [sh.getFloat('brightness'), sh.getFloat('hue'), sh.getFloat('contrast'), sh.getFloat('saturation')];
	} catch (e:Dynamic) {}
	return out;
}

// 剧情变暗 = 官方 SserafimShader.darkenAmount（= frag 里的 darkAmt uniform）。
// 曾经改成"camHUD 上一块整屏黑幕"，结果 camHUD 那条路在 FE 里没画出来 → 歌里的
// sserafimDark 事件全部失效（场景压暗消失）。黑幕已删，回到官方这条路。
function setBothDark(v) {
	if (characterShader != null) characterShader.setFloat('darkAmt', v);
	if (stageShader != null) stageShader.setFloat('darkAmt', v);
}

function setBothAdjust(b, h, c, s) {
	adjustColor(characterShader, b, h, c, s);
	adjustColor(stageShader, b, h, c, s);
}

function setBothTruck(v) {
	if (characterShader != null) characterShader.setFloat('truckStrength', v);
	if (stageShader != null) stageShader.setFloat('truckStrength', v);
}

function setBothPulse(v) {
	if (characterShader != null) characterShader.setFloat('pulseStrength', v);
	if (stageShader != null) stageShader.setFloat('pulseStrength', v);
}

function setBothPulseColor(col) {
	var rgb = [((col >> 16) & 255) / 255, ((col >> 8) & 255) / 255, (col & 255) / 255];
	if (characterShader != null) characterShader.setFloatArray('lightColor', rgb);
	if (stageShader != null) stageShader.setFloatArray('lightColor', rgb);
}

function currentDark() {
	if (stageShader == null) return 0;
	var v = 0.0;
	try { v = stageShader.getFloat('darkAmt'); } catch (e:Dynamic) { v = 0; }
	return v;
}

// 戳人那一下的镜头顿挫。官方在这一帧只有 HapticUtil.vibrate（PC 空实现）+ 一帧变暗，
// 所以手感上是"没反应"；补一个极轻的 shake，视觉上就有"戳到了"的反馈。
function pokePunch() {
	if (!POKE_SHAKE) return;
	var p = ps();
	if (p == null || p.camGame == null) return;
	try { p.camGame.shake(POKE_SHAKE_POWER, POKE_SHAKE_TIME); } catch (e:Dynamic) {}
}

function darkenTween(amt, dur) {
	if (darkTween != null) { darkTween.cancel(); darkTween = null; }
	var proxy = { amt: currentDark() };
	darkTween = FlxTween.tween(proxy, { amt: amt }, dur, { ease: FlxEase.sineInOut,
		onUpdate: function(tw) { setBothDark(proxy.amt); } });
}

// 调色 tween：过场跳过时要能中途掐掉，否则它会在歌里继续改画面颜色
function tweenAdjust(b, h, c, s, dur, ?ease, ?fromB, ?fromH, ?fromC, ?fromS) {
	if (adjustTween != null) { adjustTween.cancel(); adjustTween = null; }
	var cur = getAdjust(stageShader);
	var proxy = {
		b: (fromB != null) ? fromB : cur[0],
		h: (fromH != null) ? fromH : cur[1],
		c: (fromC != null) ? fromC : cur[2],
		s: (fromS != null) ? fromS : cur[3]
	};
	adjustTween = FlxTween.tween(proxy, { b: b, h: h, c: c, s: s }, dur, {
		ease: (ease != null) ? ease : FlxEase.sineInOut,
		onUpdate: function(tw) { setBothAdjust(proxy.b, proxy.h, proxy.c, proxy.s); } });
}

function killLookTweens() {
	if (adjustTween != null) { try { adjustTween.cancel(); } catch (e:Dynamic) {} adjustTween = null; }
	if (darkTween != null) { try { darkTween.cancel(); } catch (e:Dynamic) {} darkTween = null; }
}

// ============================================================================
//  §4  相机
// ============================================================================

// FE 的 defaultCamZoom 就是 V-Slice 的 currentCameraZoom（bop 系统的基准）。
// 事件推的是基准，相机自己 lerp/bop 回基准 —— 别直接 tween camGame.zoom，会和 bop 打架。
function camZoomTo(target, dur, ?ease) {
	var p = ps();
	if (camZoomTween != null) camZoomTween.cancel();
	if (dur <= 0) {
		camZoomTween = null;
		p.defaultCamZoom = target;
		p.camGame.zoom = target;
		return;
	}
	camZoomTween = FlxTween.tween(p, { defaultCamZoom: target }, dur, {
		ease: ease == null ? FlxEase.linear : ease,
		onUpdate: function(tw) { p.camGame.zoom = p.defaultCamZoom; },
		onComplete: function(tw) { p.camGame.zoom = p.defaultCamZoom; }
	});
}

function camPosTo(x, y, dur, ?ease) {
	var p = ps();
	if (camPosTween != null) camPosTween.cancel();
	Reflect.setProperty(p, 'isCameraOnForcedPos', true);
	if (dur <= 0) {
		camPosTween = null;
		p.camFollow.setPosition(x, y);
		return;
	}
	camPosTween = FlxTween.tween(p.camFollow, { x: x, y: y }, dur, { ease: ease == null ? FlxEase.linear : ease });
}

// ============================================================================
//  §5  外观（夜间调色 / 踢门后转晴）
// ============================================================================

// 官方 resetClear()
function resetLook() {
	killLookTweens();
	if (stageShader != null) FlxTween.cancelTweensOf(stageShader);
	if (characterShader != null) FlxTween.cancelTweensOf(characterShader);
	if (floorSpr != null) FlxTween.cancelTweensOf(floorSpr);

	setBothAdjust(-24, 6, -26, -74);
	setBothDark(0);
	setBothTruck(0);
	setBothPulse(0);

	resetDust();

	if (yunjin != null) {
		yunjin.playAnim('doorclosed', true);
		yunjinDance = false;           // 官方 danceEvery = 0
	}
	if (getProp('truckDoor') != null) getProp('truckDoor').visible = false;
	lightsEnabled = false;
}

// 官方 startClear()：从"当前"调色缓到 0。
// 旧版把起点写死成 55（那是过场里卡车逼近时的亮度），踢门瞬间会闪白。
function startClear() {
	var cur = getAdjust(stageShader);
	var proxy = { b: cur[0], h: cur[1], c: cur[2], s: cur[3] };
	FlxTween.tween(proxy, { b: 0, h: 0, c: 0, s: 0 }, 24, { ease: FlxEase.sineOut,
		onUpdate: function(tw) { setBothAdjust(proxy.b, proxy.h, proxy.c, proxy.s); } });

	if (dust1 == null) return;
	var ds = [dust1, dust2, dust3, dust4];
	var dys = [100, 200, 150, 100];
	var durs = [20, 16, 24, 16];
	for (i in 0...ds.length) {
		var d = ds[i];
		FlxTween.tween(d, { alpha: 0, y: d.y + dys[i] }, durs[i], { ease: FlxEase.sineOut });
		FlxTween.tween(d.velocity, { x: 0 }, durs[i], { ease: FlxEase.sineOut });
	}
}

// ============================================================================
//  §6  女团角色
// ============================================================================

// 全员站位整体微调（用户实机校准）：整个角色组相对背景偏右下，统一往左上挪。
// 200 = 第一轮校准，再 +30 = 第二轮微调（合计 -230）。
// 只作用于"演出里的角色"（女团五人：yunjin / kazuha=dad / chaewon / eunchae / sakura=bf）；
// 过场图集与起身精灵仍用官方坐标（y 单独由 CUT_BFGF_Y_SHIFT 调）。
var CHAR_SHIFT_X = -230.0;
var CHAR_SHIFT_Y = -230.0;

function addGirl(id, x, y, scrollF) {
	var c = new Character(0, 0, id, false);
	c.setPosition(x + CHAR_SHIFT_X, y + CHAR_SHIFT_Y);
	c.scrollFactor.set(scrollF, scrollF);
	c.shader = characterShader;
	return c;
}

// 槽位 → 角色对象。0 yunjin / 1 kazuha(dad) / 2 chaewon / 3 eunchae / 4 sakura(bf)
var girlsCache = null;

function girlList() {
	var p = ps();
	if (girlsCache == null) {
		girlsCache = [yunjin, p.dad, chaewon, eunchae, p.boyfriend];
	} else {
		// 缓存建早了的话补上引擎侧角色（dad/bf 是 PlayState 建的，可能晚一拍）
		if (girlsCache[1] == null && p.dad != null) girlsCache[1] = p.dad;
		if (girlsCache[4] == null && p.boyfriend != null) girlsCache[4] = p.boyfriend;
	}
	return girlsCache;
}

function setGirlsVisible(arr) {
	if (arr == null || arr.length < 5) return;
	if (yunjin != null) yunjin.visible = arr[0];
	if (ps().dad != null) ps().dad.visible = arr[1];
	if (chaewon != null) chaewon.visible = arr[2];
	if (eunchae != null) eunchae.visible = arr[3];
	if (ps().boyfriend != null) ps().boyfriend.visible = arr[4];
	girlsVisible = arr;
}

function setGirlsSinging(arr) {
	if (arr == null || arr.length < 5) return;
	girlsSinging = arr;
}

// VS 语义：只有 singing 标志为真的成员会在**玩家侧**音符上唱；对手侧一律 idle
// 把 true/false 数组压成 "10000"，日志里一眼能看出谁在唱
function flags(a) {
	if (a == null) return 'null';
	var s = '';
	for (i in 0...a.length) s += (a[i] == true) ? '1' : '0';
	return s;
}

// gf 是数组第 6 位（官方 baseSinging / 我们的 sserafimSing 都是 6 位），
// 但她不在 girlList 里（引擎的 gf 不是"女团成员"），引擎也永远不会让 gf 唱 →
// 必须由这里自己驱动，否则 singing[5] 永远是白给的。
function gfSings() {
	if (girlsSinging == null || girlsSinging.length < 6) return false;
	return girlsSinging[5] == true;
}

function gfSing(dirName) {
	var p = ps();
	if (p == null || p.gf == null || !p.gf.visible) return;
	// 官方 SserafimGfSprite.playAnimation 在 isBeautiful 时会自动加 -beautiful 后缀
	var nm = 'sing' + dirName + (gfBeautiful ? '-beautiful' : '');
	if (!p.gf.hasAnimation(nm)) nm = 'sing' + dirName;
	if (!p.gf.hasAnimation(nm)) {
		slog('gf: NO anim ' + nm);
		return;
	}
	p.gf.playAnim(nm, true);
	gfHold = 2;
}

// skipBf = 这一拍已经播过 sakura 专属 kind（joint / bf1 / bf2）。
// 那种情况下绝不能再播普通 singX —— 会把刚播的专属姿势顶掉，
// 表现就是"bf 的那几套动作根本没出现"。
function girlSing(dirName, isPlayerSide, skipBf) {
	if (!isPlayerSide) return;
	var girls = girlList();
	var sang = '';
	for (i in 0...girls.length) {
		if (girls[i] == null) continue;
		if (!girlsSinging[i]) {
			// 不唱的成员：bf 槽每按一个音符，引擎都会自动给她播 singX，
			// 这里按回 idle（否则不唱歌的人也在做唱歌动作）
			if (i == 4 && skipBf != true) {
				// 只在"已经是唱姿"时才按回 idle —— 每颗音符都强播 idle 会抖
				var cur4 = girls[4].getAnimationName();
				// ⚠ 不能用 startsWith：hscript-iris 里 String 的 startsWith/endsWith 解析不到
				// （报 "tried to call null function startsWith"）。用 indexOf == 0。
				if (cur4 != null && cur4.indexOf('sing') == 0) {
					girls[4].playAnim('idle', true);
					girlHold[4] = 0;
				}
			}
			continue;
		}
		if (i == 4 && skipBf == true) {
			sang += GIRL_NAMES[i] + '(kind) ';
			continue;
		}
		if (girlHold[i] > 8) continue;
		girls[i].playAnim('sing' + dirName, true);
		girlHold[i] = 4;
		sang += GIRL_NAMES[i] + ' ';
	}
	if (gfSings()) { gfSing(dirName); sang += 'gf '; }
	// 每秒最多落一行，用来确认"谁在唱"
	var now = Conductor.songPosition;
	if (now - singLogAt > 1000) {
		singLogAt = now;
		if (LOG_HOT) slog('hit ' + dirName + ' flags=' + flags(girlsSinging) + ' sang=[' + sang + ']');
	}
}

//  §7  嘴型 lipsync
// ----------------------------------------------------------------------------
//  官方做法：SserafimLipSyncSprite 作为 element 塞进角色图集的 "mouth xxx" 帧，
//  嘴因此天然跟着头部逐帧走，每个动画再用 LIP_SYNC_OFFSETS 微调几像素。
//  FE 的 flxanimate 不能在运行时往符号帧里塞精灵 → 独立 FlxAnimate 叠加，
//  锚点从图集矩阵**逐帧**算出来（.workbuddy-ai/tools/sserafim_fix_anims.py →
//  sserafim/lipsync/anchors.json），所以 idle 的呼吸位移、唱姿的偏头都跟得上。
//
//  数据格式：{ 角色id: { 动画名: [[x, y, rot], ...] } }
//    x/y = "mouth xxx" 占位位图的 bbox 中心（姿势符号自身坐标，不含根时间轴摆放）
//    rot = 该帧头部倾斜角
//  位置：嘴中心 = 角色画布上的 (x, y) → 屏幕 = char.x - char.offset.x + x
//        （角色 offset 已经补上了"姿势符号在根时间轴上的摆放"，见角色 json 的 offsets）
//  旋转：必须绕嘴图集自己的美术中心转（MOUTH_ART_CENTER），否则会甩出 200px+
// ----------------------------------------------------------------------------

// 嘴图集里"嘴美术"的 bbox 中心（画布坐标）—— 同时用作旋转中心和位置补偿
var MOUTH_ART_CENTER_SHARED = [249.80, 208.29];   // sserafim-lipsync
var MOUTH_ART_CENTER_YUNJIN = [249.08, 208.02];   // sserafim-lipsync-yunjin

// 整体角度修正：嘴看起来整体歪了才动它（正数=顺时针）
var MOUTH_ANGLE_FIX = 0.0;

// MOUTHS 表 —— 一条嘴对应一名成员
//   girl/charId  成员名 / 角色图集目录（也是 anchors.json 的键）
//   slot         舞台槽位，纯注释用
//   atlas        嘴图集
//   artCenter    该图集里嘴美术的 bbox 中心（旋转中心）
//   alpha        官方 chaewon 的嘴是半透明
//   flip         官方 kazuha / sakura 给嘴单独设了 flipX。**这里默认关**：
//                flxanimate 的 flipX 是绕画布原点镜像（不是绕美术中心），
//                开了会把嘴整体甩到左边一个画布宽度。真要镜像得另想办法。
var MOUTHS = [
	{
		girl: 'yunjin',
		charId: 'sserafim-yunjin',
		slot: '额外角色（舞台最左）',
		atlas: 'sserafim-lipsync-yunjin',
		artCenter: MOUTH_ART_CENTER_YUNJIN,
		alpha: 1.0,
		angle: 0.0,
		flip: false
	},
	{
		girl: 'kazuha',
		charId: 'sserafim-kazuha',
		slot: 'dad 槽（舞台中央偏右）',
		atlas: 'sserafim-lipsync',
		artCenter: MOUTH_ART_CENTER_SHARED,
		alpha: 1.0,
		angle: 0.0,
		flip: true          // 官方 kazuha 的嘴就是镜像的
	},
	{
		girl: 'chaewon',
		charId: 'sserafim-chaewon',
		slot: '额外角色（背对镜头 → 嘴半透明）',
		atlas: 'sserafim-lipsync',
		artCenter: MOUTH_ART_CENTER_SHARED,
		alpha: 0.5,
		angle: 180.0,       // 锚点 rot ≈ +175（上下颠倒）→ 补 180
		flip: false
	},
	{
		girl: 'eunchae',
		charId: 'sserafim-eunchae',
		slot: '额外角色（舞台最右）',
		atlas: 'sserafim-lipsync',
		artCenter: MOUTH_ART_CENTER_SHARED,
		alpha: 1.0,
		angle: 180.0,       // 锚点 rot ≈ ±175（上下颠倒）→ 补 180
		flip: false
	},
	{
		girl: 'sakura',
		charId: 'sserafim-sakura',
		slot: 'bf 槽（玩家，舞台右侧）',
		atlas: 'sserafim-lipsync',
		artCenter: MOUTH_ART_CENTER_SHARED,
		alpha: 1.0,
		angle: 0.0,
		flip: true          // 官方 sakura 的嘴也是镜像的
	}
];

var lipsyncs = [null, null, null, null, null];
var mouthLabels = null;      // MOUTH_DEBUG 用
var mouthAnchors = null;     // anchors.json 解析结果

// 读逐帧锚点表（只读一次）
function loadMouthAnchors() {
	if (mouthAnchors != null) return mouthAnchors;
	mouthAnchors = {};
	try {
		var path = Paths.currentContentRoot + '/sserafim/lipsync/anchors.json';
		if (FileSystem.exists(path)) mouthAnchors = parseJson(File.getContent(path));
	} catch (e:Dynamic) { mouthAnchors = {}; }
	return mouthAnchors;
}

// (成员序号, 动画名, 帧号) → [x, y, rot]；没有就回落 idle
var mouthTabs = null;

function mouthTab(i) {
	if (mouthTabs == null) {
		mouthTabs = [];
		var all = loadMouthAnchors();
		for (k in 0...5) {
			var t = null;
			try { t = Reflect.field(all, MOUTHS[k].charId); } catch (e:Dynamic) { t = null; }
			mouthTabs.push(t);
		}
	}
	return mouthTabs[i];
}

function mouthAnchor(i, animName, frame) {
	var tab = mouthTab(i);
	if (tab == null) return null;
	var frames = null;
	try { frames = Reflect.field(tab, animName); } catch (e:Dynamic) { frames = null; }
	if (frames == null) { try { frames = Reflect.field(tab, 'idle'); } catch (e:Dynamic) { frames = null; } }
	if (frames == null || frames.length < 1) return null;
	var idx = frame;
	if (idx < 0) idx = 0;
	if (idx > frames.length - 1) idx = frames.length - 1;
	return frames[idx];
}

function addMouth(i, char) {
	var m = MOUTHS[i];
	var ls = new FlxAnimate(0, 0);
	try {
		Paths.loadAnimateAtlas(ls, m.atlas);
	} catch (e:Dynamic) { return null; }
	ls.scrollFactor.set(char.scrollFactor.x, char.scrollFactor.y);
	ls.alpha = m.alpha;
	ls.shader = characterShader;
	ls.visible = char.visible;
	ls.origin.set(m.artCenter[0], m.artCenter[1]);
	// flipX 在 flxanimate 里是绕画布原点镜像（会把嘴整体甩出去一个画布宽），
	// 用负 scale 才是绕 origin（= 嘴的美术中心）镜像，位置不动。
	if (m.flip == true) ls.scale.x = -1;
	try { ls.anim.play(); } catch (e:Dynamic) {}
	return ls;
}

// 每帧把嘴摆到角色当前"嘴锚点"上（锚点逐帧查表 → 呼吸/偏头都跟着）
function updateLipsync() {
	var girls = girlList();

	// 口型帧号：官方 = floor(songPosition/1000*24) - 1
	var mouthFrame = 0;
	try {
		mouthFrame = Std.int(Math.floor((Conductor.songPosition / 1000) * 24) - 1);
	} catch (e:Dynamic) { mouthFrame = 0; }
	if (mouthFrame < 0) mouthFrame = 0;

	for (i in 0...5) {
		var c = girls[i];
		var ls = lipsyncs[i];
		if (c == null || ls == null) continue;
		var m = MOUTHS[i];

		var anim = 'idle';
		try { anim = c.getAnimationName(); } catch (e:Dynamic) { anim = 'idle'; }
		if (anim == null) anim = 'idle';

		var cf = 0;
		try { cf = Std.int(c.atlas.anim.curFrame); } catch (e:Dynamic) { cf = 0; }

		var a = mouthAnchor(i, anim, cf);
		if (a == null) { ls.visible = false; continue; }

		var sx = c.scale.x;
		var sy = c.scale.y;

		// 嘴中心落到角色画布的锚点上（减掉嘴图集自己的美术中心）
		ls.x = c.x - c.offset.x + a[0] * sx - m.artCenter[0];
		ls.y = c.y - c.offset.y + a[1] * sy - m.artCenter[1];
		var extraAngle = 0.0;
		try { if (m.angle != null) extraAngle = m.angle; } catch (e:Dynamic) {}
		ls.angle = a[2] + MOUTH_ANGLE_FIX + extraAngle;
		ls.alpha = m.alpha * c.alpha;
		ls.visible = c.visible;
		ls.scrollFactor.set(c.scrollFactor.x, c.scrollFactor.y);

		// 官方 SserafimLipSyncSprite.shouldSing：**只有正在唱的成员嘴才动**，
		// 其他人 fixed 在第 0 帧（闭口）。以前这里无条件按 songPosition 推进帧，
		// 结果五张嘴连同 gf 一起动 —— 就是"按下就一起唱"的观感来源（事件其实是对的）。
		var singing = (girlsSinging[i] == true);
		if (!singing) {
			try {
				if (ls.anim.isPlaying) ls.anim.pause();
				// 只在真的不同的时候写，避免每帧无谓地碰 flxanimate 的帧游标
				if (ls.anim.curFrame != 0) ls.anim.curFrame = 0;
			} catch (e:Dynamic) {}
		} else {
			try { if (!ls.anim.isPlaying) ls.anim.resume(); } catch (e:Dynamic) {}
			var f = mouthFrame;
			try {
				var len = ls.anim.length;
				if (len > 0) {
					if (f > len - 1) f = len - 1;
					if (ls.anim.curFrame != f) ls.anim.curFrame = f;
				}
			} catch (e:Dynamic) {}
		}

		if (MOUTH_DEBUG && mouthLabels != null) {
			var lb = mouthLabels[i];
			if (lb != null) {
				lb.visible = ls.visible;
				lb.setPosition(ls.x - 100, ls.y - 46);
			}
		}
	}
}

// FlxTextBorderStyle 是真 enum（不是 enum abstract），HScript 里写字符串会崩：
// 字符串被塞进 borderStyle 字段，FlxText.regenGraphic 的 switch(borderStyle) 读不到
// __Index → 空引用（就是 FlxText.hx:917 那个崩溃点）。所以这里从 PlayState 自带的 HUD
// 文本借一个已经构造好的 OUTLINE 枚举值；借不到就退化成无描边，绝不写字符串。
var outlineStyle = null;
var outlineStyleTried = false;

function getOutlineStyle() {
	if (outlineStyleTried) return outlineStyle;
	outlineStyleTried = true;
	var names = ['timeTxt', 'scoreTxt', 'botplayTxt', 'frameReplayTxt'];
	for (n in names) {
		if (outlineStyle == null) {
			try {
				var hud = Reflect.field(ps(), n);
				if (hud != null) {
					var st = hud.borderStyle;
					if (st != null) outlineStyle = st;
				}
			} catch (e:Dynamic) {}
		}
	}
	return outlineStyle;
}

// 给文本加描边（安全版）
function applyOutline(t, size, col) {
	try { t.color = col; } catch (e:Dynamic) {}
	try {
		var st = getOutlineStyle();
		if (st != null) {
			t.borderStyle = st;
			t.borderSize = size;
			t.borderColor = 0xFF000000;
		}
	} catch (e:Dynamic) {}
}

// F2 调试标注：写着成员名的标签，直接告诉你哪张嘴是谁的
function buildMouthLabels() {
	var p = ps();
	mouthLabels = [];
	for (i in 0...5) {
		var m = MOUTHS[i];
		var t = new FlxText(0, 0, 200, '#' + i + ' ' + m.girl, 16);
		applyOutline(t, 2, 0xFF00FF00);
		t.scrollFactor.set(1, 1);
		t.cameras = [p.camGame];
		t.visible = false;
		p.add(t);
		mouthLabels.push(t);
	}
}

function setMouthDebug(on) {
	MOUTH_DEBUG = on;
	if (on && mouthLabels == null) buildMouthLabels();
	if (mouthLabels != null) for (l in mouthLabels) l.visible = on;
}

// ============================================================================
//  §8  透视地板
// ============================================================================

// 官方 PerspectiveSprite：bottom scroll 1.05 / top scroll 0.93，精灵本身 scrollFactor 0.93。
// 这里把两条公式（corrected = obj + cam.scroll*(spriteSF - objSF)）折成等价的 skew 矩阵。
// 数学上与官方一致，位置不能乱改。
function updateFloorSkew(cam) {
	if (floorSpr == null || floorSpr.graphic == null) return;
	var botX = floorBottomX - cam.scroll.x * 0.12;
	var botY = floorBottomY - cam.scroll.y * 0.12 + cutFloorShift;
	var topX = floorTopX;
	var topY = floorTopY + cutFloorShift;
	var h = floorSpr.frameHeight > 0 ? floorSpr.frameHeight : floorSpr.height;
	if (h <= 0) return;
	var distX = topX - botX;
	var distY = topY - (botY - h);
	var m = floorSpr.transformMatrix;
	m.a = 1; m.b = 0;
	m.c = -(distX / h);
	m.d = 1 - (distY / h);
	m.tx = distX / 2;
	m.ty = distY / 2;
	floorSpr.matrixExposed = true;
	floorSpr.x = botX - floorSpr.width / 2;
	floorSpr.y = botY - h;
}

// ============================================================================
//  §9  尘埃
// ============================================================================

// 官方 buildStage 里的初始摆位（撞车后 resetDust 会再往下一段）
function makeDust() {
	var p = ps();
	dust1 = new FlxBackdrop(Paths.image('dust/dustMid'), 0x01);
	dust2 = new FlxBackdrop(Paths.image('dust/dustBack'), 0x01);
	dust3 = new FlxBackdrop(Paths.image('dust/dustMid'), 0x01);
	dust4 = new FlxBackdrop(Paths.image('dust/dustBack'), 0x01);
	var ds = [dust1, dust2, dust3, dust4];
	var pos = [[-650, -200], [-650, -250], [-650, -400], [-650, -1300]];
	var scrolls = [1.1, 1.15, 1.2, 1.25];
	var scales = [1.5, 1.5, 2.0, 3.5];
	var vels = [350, -300, -200, -150];
	var alphas = [0.8, 0.9, 0.8, 0.9];
	var cols = [0xff98847d, 0xff8b6c63, 0xff6e645c, 0xff886a60];
	for (i in 0...ds.length) {
		var d = ds[i];
		d.setPosition(pos[i][0], pos[i][1]);
		d.scrollFactor.set(scrolls[i], scrolls[i]);
		d.scale.set(scales[i], scales[i]);
		d.velocity.x = vels[i];
		d.alpha = alphas[i];
		d.color = cols[i];
		// ⚠ 官方灰尘**没有**挂 shader（addProp 那套只管 stage 道具，dust 是直接 add 的）。
		// 这里一旦挂上 stageShader，夜间调色（-24/6/-26/-74）会把 4 层满屏灰尘一起去色压暗，
		// 观感就是"灰尘变成一层灰褐色脏罩子"，而且相当于每帧多跑 4 次全屏片元。
		p.add(d);
	}
}

function resetDust() {
	if (dust1 == null) return;
	var ds = [dust1, dust2, dust3, dust4];
	var pos = [[-650, -400], [-650, -450], [-650, -600], [-650, -1500]];
	var vels = [350, -300, -200, -150];
	for (i in 0...ds.length) {
		var d = ds[i];
		FlxTween.cancelTweensOf(d);
		FlxTween.cancelTweensOf(d.velocity);
		d.setPosition(pos[i][0], pos[i][1]);
		d.velocity.x = vels[i];
		d.alpha = 1;
		// 过场期间别恢复可见：introCutscene 的顺序是 setCutsceneVisibility(true)
		// （hideDust(false) 藏掉）→ resetLook()（走到这里），无条件 true 会把
		// 刚藏好的灰尘整个拉回来，开场就变成满天灰。非过场（歌里/重试）照常恢复。
		d.visible = !cutsceneActive;
	}
}

function hideDust(visible) {
	if (dust1 == null) return;
	dust1.visible = visible;
	dust2.visible = visible;
	dust3.visible = visible;
	dust4.visible = visible;
}

// ============================================================================
//  §10  过场
// ============================================================================

function setCutsceneVisibility(inCutscene) {
	setGirlsVisible(inCutscene ? [false, false, false, false, false] : baseVisible);
	if (getProp('truck') != null) getProp('truck').visible = !inCutscene;
	if (getProp('truckDoor') != null) getProp('truckDoor').visible = false;
	if (getProp('backTables') != null) getProp('backTables').visible = !inCutscene;
	if (getProp('backStools') != null) getProp('backStools').visible = !inCutscene;
	if (getProp('frontStool') != null) getProp('frontStool').visible = !inCutscene;
	hideDust(!inCutscene);
	// 过场专用的拉长吧台 + 汉堡（官方 zIndex 12/13）
	if (getProp('backTablesCutscene') != null) getProp('backTablesCutscene').visible = inCutscene;
	if (getProp('burgerCutscene') != null) getProp('burgerCutscene').visible = inCutscene;

	if (floorSpr != null) {
		var img = Paths.image(inCutscene ? 'cutscene/floor-cutscene' : 'floor');
		if (img != null) floorSpr.loadGraphic(img);
	}
	// 过场整体下移（CUT_SCENE_SHIFT_Y）：地板只在过场里挪，切回正常地板时归零
	cutFloorShift = inCutscene ? CUT_SCENE_SHIFT_Y / CUTSCENE_ZOOM_IN : 0.0;
	if (ps().gf != null) ps().gf.visible = false;
	if (cutsceneSprite != null) cutsceneSprite.visible = inCutscene;
}

// ---- 过场定时器：带"代"号 + 实体表，过场作废后自动失效 ----

// 三重保险：
//   owner != ps()       → 已经换关卡（死亡重试 / 换歌），旧回调一律不执行
//   g != cutsceneGen    → 过场被跳过 / 正常结束
//   !cutsceneActive     → 双保险
// 只要其中一条成立就直接 return，绝不会在歌里突然播开局事件。
function cutTime(sec, fn) {
	var owner = ps();
	var g = cutsceneGen;
	var tmr = new FlxTimer();
	cutTimers.push(tmr);
	tmr.start(sec, function(t) {
		if (owner != ps()) return;
		if (g != cutsceneGen) return;
		if (!cutsceneActive) return;
		fn(t);
	});
}

function cutsceneKillTimers() {
	cutsceneGen = cutsceneGen + 1;   // 别写 ++（见 §1 说明）
	var old = cutTimers;
	cutTimers = [];
	for (t in old) {
		if (t == null) continue;
		try { t.cancel(); } catch (e:Dynamic) {}
	}
}

// 结尾演出用的定时器（不吃过场代号，只认关卡归属）
function endTime(sec, fn) {
	var owner = ps();
	var tmr = new FlxTimer();
	endTimers.push(tmr);
	tmr.start(sec, function(t) {
		if (owner != ps()) return;
		fn(t);
	});
}

// 把某个帧标签区间定格在"区间首帧 + offset"（官方 restart 时 curFrame = 23 的等价物）
function holdLabelAt(spr, name, offset) {
	if (spr == null) return;
	tryAnim(spr, '');
	var idx = labelIndex(spr, name);
	try {
		spr.anim.curFrame = (idx >= 0) ? idx + offset : 0;
		spr.anim.pause();
	} catch (e:Dynamic) {}
}

function introCutscene() {
	var p = ps();
	p.inCutscene = true;
	p.camHUD.visible = false;
	slog('intro: enter');

	// 逐段兜错：一步炸掉不该把整段过场（和歌）一起带走
	try { setCutsceneVisibility(true); slog('intro: visibility ok'); }
	catch (e:Dynamic) { slog('intro: visibility FAILED ' + e); }

	try { resetLook(); setBothAdjust(0, 0, 0, 0); slog('intro: look ok'); }
	catch (e:Dynamic) { slog('intro: look FAILED ' + e); }

	// skip 提示。不用 setFormat：HScript 动态调用时缺省的 EmbeddedFont 参数会变成 false，
	// 字体会走 systemFont 分支。直接设 font / size / alignment 属性更稳。
	try {
		skipText = new FlxText(936, 618, 0, 'Skip [ ENTER ]', 20);
		skipText.font = Paths.font('vcr.ttf');
		skipText.size = 40;
		skipText.alignment = 'right';
		applyOutline(skipText, 2, 0xFFFFFFFF);
		skipText.scrollFactor.set(0, 0);
		skipText.alpha = 0;
		skipText.cameras = [p.camOther];
		p.add(skipText);
		FlxTween.tween(skipText, { alpha: 1 }, 0.5, { ease: FlxEase.quadOut });
		slog('intro: skipText ok');
	} catch (e:Dynamic) {
		slog('intro: skipText FAILED ' + e);
		skipText = null;
	}

	if (cutsceneSprite != null) {
		cutsceneSprite.visible = true;
		tryAnim(cutsceneSprite, '');
		var alen = -1;
		var acur = -1;
		try { alen = cutsceneSprite.anim.length; } catch (e:Dynamic) {}
		try { acur = cutsceneSprite.anim.isPlaying ? 1 : 0; } catch (e:Dynamic) {}
		slog('intro: main play len=' + alen + ' playing=' + acur
			+ ' vis=' + cutsceneSprite.visible + ' alpha=' + cutsceneSprite.alpha
			+ ' x=' + cutsceneSprite.x + ' y=' + cutsceneSprite.y);
	} else {
		slog('intro: NO cutsceneSprite!');
	}

	// 开场镜头：0.5 → 0.7
	try {
		camZoomTo(stageBaseZoom, 0);
		camPosTo(660, -200, 0);
		p.camGame.fade(0xFF000000, 3, true, null, true);
		camZoomTo(CUTSCENE_ZOOM_IN, 3, FlxEase.circOut);
		camPosTo(660, 300, 3, FlxEase.circOut);
		slog('intro: camera ok zoom=' + p.camGame.zoom);
	} catch (e:Dynamic) { slog('intro: camera FAILED ' + e); }

	// 1 秒后回访：curFrame 一直不动 = 时间轴根本没在走（不是"看不见"，是"没播"）
	cutTime(1.0, function(tmr) {
		var cf = -1;
		var ip = 0;
		if (cutsceneSprite != null) {
			try { cf = cutsceneSprite.anim.curFrame; } catch (e:Dynamic) {}
			try { ip = cutsceneSprite.anim.isPlaying ? 1 : 0; } catch (e:Dynamic) {}
		}
		slog('intro +1s curFrame=' + cf + ' playing=' + ip);
	});

	// 画了没有？（wh=0 就是"图集在走但一个像素都没画出来"）
	cutTime(1.2, function(tmr) { 
		try { dumpAnimate('probe cutscene', cutsceneSprite); } catch (e:Dynamic) { slog('probe cutscene FAILED ' + e); }
		// 取景自校正：把整块过场美术摆到屏幕中央（镜头 1 秒后还在往后推，3.4s 再校一次）
		try {
			if (fitAnimateCenter(cutsceneSprite, CUT_FIT_X, CUT_FIT_Y + CUT_SCENE_SHIFT_Y / CUTSCENE_ZOOM_IN)) {
				slog('fit cutscene @1.2 pos=' + Math.round(cutsceneSprite.x) + ',' + Math.round(cutsceneSprite.y));
			} else {
				slog('fit cutscene @1.2 SKIPED (wh=' + cutsceneSprite.width + 'x' + cutsceneSprite.height + ')');
			}
		} catch (e:Dynamic) { slog('fit cutscene FAILED ' + e); }
		try { probeSprite('cutscene', cutsceneSprite); } catch (e:Dynamic) {}
		try {
			var idx = -1;
			for (i in 0...ps().members.length) if (ps().members[i] == cutsceneSprite) idx = i;
			slog('probe cutscene members[' + idx + '/' + ps().members.length + '] exists=' + cutsceneSprite.exists);
		} catch (e:Dynamic) {}
	});

	// 镜头推完（3s）再校一次：第一次校正时镜头还在动，落点会差几十像素
	cutTime(3.4, function(tmr) {
		try {
			if (fitAnimateCenter(cutsceneSprite, CUT_FIT_X, CUT_FIT_Y + CUT_SCENE_SHIFT_Y / CUTSCENE_ZOOM_IN)) {
				slog('fit cutscene @3.4 pos=' + Math.round(cutsceneSprite.x) + ',' + Math.round(cutsceneSprite.y)
					+ ' wh=' + Math.round(cutsceneSprite.width) + 'x' + Math.round(cutsceneSprite.height));
			}
			probeSprite('cutscene @3.4', cutsceneSprite);
		} catch (e:Dynamic) { slog('fit cutscene @3.4 FAILED ' + e); }
	});

	cutTime(20 / 24, function(tmr) {
		cutsceneSound = FlxG.sound.play(Paths.sound('cutscene/startCutscene'), 1.0);
		slog('intro @20 sound=' + (cutsceneSound != null));
	});

	// gf 戳自己
	cutTime(245 / 24, function(tmr) { if (LOG_HOT) slog('intro @245'); darkenTween(0.2, 0.01); pokePunch(); });
	cutTime(251 / 24, function(tmr) { darkenTween(0, 0.8); });

	// gf 戳 bf
	cutTime(406 / 24, function(tmr) { darkenTween(0.2, 0.01); pokePunch(); });
	cutTime(411 / 24, function(tmr) { darkenTween(0, 0.8); });

	// 卡车开始逼近 —— 画面变冷变亮
	cutTime(499 / 24, function(tmr) {
		slog('intro @499');
		endSkip();
		tweenAdjust(55, 0, -30, 0, 49 / 24, FlxEase.sineOut);
	});

	// 卡车贴脸
	cutTime(548 / 24, function(tmr) {
		FlxTween.cancelTweensOf(stageShader);
		FlxTween.cancelTweensOf(characterShader);
		// 从上一段的目标值接着推，别从"当前值"读（会抖）
		tweenAdjust(66, 10, -17, 0, 15 / 24, FlxEase.expoIn, 55, 0, -30, 0);
	});

	// 撞车 + 闪白
	cutTime(563 / 24, function(tmr) {
		slog('intro @563 crash');
		FlxTween.cancelTweensOf(stageShader);
		FlxTween.cancelTweensOf(characterShader);
		setBothAdjust(0, 0, 0, 0);
		p.camGame.fade(0xFFFFFFFF, 30 / 24, true, null, true);
		if (solidCover != null) solidCover.alpha = 1;
		setCutsceneVisibility(false);
	});

	// 从黑里淡出，bf/gf 趴在地上
	cutTime(650 / 24, function(tmr) {
		camZoomTo(CUTSCENE_ZOOM_IN, 0);
		camZoomTo(CUTSCENE_ZOOM_REST, 3, FlxEase.circOut);
		camPosTo(1070, 470, 0);

		resetLook();
		if (solidCover != null) FlxTween.tween(solidCover, { alpha: 0 }, 3, { ease: FlxEase.sineOut });

		if (sserafimGf != null) { sserafimGf.visible = true; holdLabel(sserafimGf, 'static'); }
		if (sserafimBf != null) { sserafimBf.visible = true; holdLabel(sserafimBf, 'static'); }
		slog('intro @650 gf/bf static');

		// 对照组：起身精灵是能画出来的，把它和过场的体检数据放一起看就能定位是谁的问题
		cutTime(0.8, function(t2) {
			try { dumpAnimate('probe gfGetUp', sserafimGf); } catch (e:Dynamic) {}
			try { dumpAnimate('probe bfGetUp', sserafimBf); } catch (e:Dynamic) {}
			try { probeSprite('gfGetUp', sserafimGf); } catch (e:Dynamic) {}
			try { probeSprite('bfGetUp', sserafimBf); } catch (e:Dynamic) {}
		});
	});

	cutTime(710 / 24, function(tmr) {
		if (sserafimGf != null) gfStopFrame = playLabel(sserafimGf, 'getup');
		if (sserafimBf != null) bfStopFrame = playLabel(sserafimBf, 'getup');
		slog('intro @710 getup gfStop=' + gfStopFrame + ' bfStop=' + bfStopFrame);
	});

	cutTime(730 / 24, function(tmr) {
		slog('intro @730 finish');
		finishCutscene();
	});
}

function finishCutscene() {
	var p = ps();
	// 过场结束（正常播完 / 被跳过都走这里）：先把还没到点的过场回调全部作废，
	// 否则 @563 crash 这类 timer 会在歌里触发，把角色/黑幕重新摆一遍。
	cutsceneKillTimers();
	cutsceneActive = false;
	cutsceneSkipped = true;
	if (cutsceneSprite != null) cutsceneSprite.visible = false;
	p.inCutscene = false;
	p.camHUD.visible = true;
	if (skipText != null) skipText.visible = false;
	slog('finish: charting=' + p.chartingMode + ' startedCountdown=' + p.startedCountdown);
	if (!p.chartingMode) p.startCountdown();
}

function endSkip() {
	if (skipText != null) FlxTween.tween(skipText, { alpha: 0 }, 0.5, { ease: FlxEase.quadIn });
	cutsceneSkipped = true;
}

// 重开（死亡重试 / 编辑器）：直接摆出"事后"状态
function playCutsceneFromRestart() {
	var p = ps();
	cutsceneActive = false;
	cutsceneSkipped = true;
	hasPlayedCutscene = true;
	p.inCutscene = false;

	setCutsceneVisibility(false);
	resetLook();

	// 跳过点可能落在白闪 / 黑幕中间：把黑幕和镜头补回正常，否则会顶着一块黑屏唱歌
	if (solidCover != null) {
		FlxTween.cancelTweensOf(solidCover);
		solidCover.alpha = 0;
	}
	p.camGame.fade(0xFF000000, 0.01, true, null, true);
	try { p.camGame.stopFlash(); } catch (e:Dynamic) {}

	camZoomTo(CUTSCENE_ZOOM_REST, 1, FlxEase.circOut);
	camPosTo(1070, 470, 1, FlxEase.circOut);

	// 官方 playCutsceneFromRestart 是把 curFrame 直接设成 23（= 已经站起来了），
	// 不是从躺倒重播一遍 —— 否则跳过过场后会在歌里看到他们慢慢爬起来。
	if (sserafimGf != null) { sserafimGf.visible = true; holdLabelAt(sserafimGf, 'getup', 22); }
	if (sserafimBf != null) { sserafimBf.visible = true; holdLabelAt(sserafimBf, 'getup', 22); }

	// 跳过路径也要留一份落点数据（多半是在这里看不到 gf/bf）
	endTime(0.4, function(t) {
		try { probeSprite('skip gfGetUp', sserafimGf); } catch (e:Dynamic) {}
		try { probeSprite('skip bfGetUp', sserafimBf); } catch (e:Dynamic) {}
		try {
			if (p.gf != null) slog('skip real gf pos=' + Math.round(p.gf.x) + ',' + Math.round(p.gf.y)
				+ ' gfGroup=' + (p.gfGroup != null ? Math.round(p.gfGroup.x) + ',' + Math.round(p.gfGroup.y) : 'null'));
		} catch (e:Dynamic) {}
	});
}

function skipCutscene() {
	var p = ps();
	slog('skip: ENTER pressed at ' + Math.round(Conductor.songPosition));
	cutsceneKillTimers();   // 跳过 = 立刻作废后续过场回调（并把定时器实体 cancel 掉）
	cutsceneActive = false;
	cutsceneSkipped = true;
	if (cutsceneSound != null) cutsceneSound.stop();
	p.camGame.fade(0xFF000000, 0.25, false, null, true);
	endTime(0.3, function(tmr) {
		p.camGame.fade(0xFF000000, 0.4, true, null, true);
		playCutsceneFromRestart();
		endTime(0.5, function(tmr2) { finishCutscene(); });
	});
}

// ============================================================================
//  §11  歌曲事件
// ============================================================================

function onEvent(name, v1, v2, strumTime) {
	var p = ps();
	if (p == null) return;
	var params = null;
	// parseJson = hscript 预置的 haxe.Json.parse 闭包
	try { params = parseJson(v1); } catch (e:Dynamic) { params = null; }

	switch (name) {
		case 'sserafimShow':
			setGirlsVisible(params != null ? params.visible : null);
			if (LOG_HOT) slog('event: show -> ' + flags(girlsVisible));
		case 'sserafimSing':
			if (params == null || params.singing == null) {
				slog('event: sing -> PARSE FAILED, raw=' + v1);
			} else {
				setGirlsSinging(params.singing);
				if (LOG_HOT) slog('event: sing -> ' + flags(girlsSinging));
			}
		case 'sserafimDark':
			if (params != null) darkenTween(params.amount, params.duration);
		case 'sserafimLights':
			if (params != null) flashTruckLights(params.amount, params.duration);
		case 'sserafimCover':
			if (solidCover != null && params != null) solidCover.alpha = params.visible ? 1 : 0;
		case 'sserafimFlash':
			if (params != null) p.camGame.flash(0xFFFFFFFF, params.duration);
		case 'sserafimPulseLights':
			if (params == null) return;
			lightsEnabled = params.enabled == true;
			if (lightsEnabled && params.colors != null) {
				lightsColors = params.colors;
				lightsDurations = params.durations;
				lightsIntensities = params.intensities;
			}
		case 'sserafimKick':
			if (params == null) return;
			if (params.final == true) {
				if (yunjin != null) { yunjin.playAnim('kick2', true); yunjinDance = true; }
				FlxG.sound.play(Paths.sound('doorKick2'), 1.0);
				if (p.iconP2 != null) p.iconP2.visible = true;
				if (sserafimGf != null) {
					sserafimGf.visible = false;
					sserafimBf.visible = false;
					// 官方在这里把"过场里趴地上的 gf"换成真正的 gf 角色（会动、会跟着跳）
					if (p.gf != null) {
						p.gf.visible = true;
						slog('kick: real gf shown at ' + Math.round(p.gf.x) + ',' + Math.round(p.gf.y)
							+ ' anim=' + p.gf.getAnimationName()
							+ ' singAnim=' + p.gf.hasAnimation('singLEFT')
							+ ' danceAnim=' + p.gf.hasAnimation('danceLeft'));
					} else {
						slog('kick: p.gf == null! 真 gf 角色不存在（stage json hide_girlfriend?）');
					}
				}
				hookDoorFrame();
				startClear();
			} else {
				if (yunjin != null) yunjin.playAnim('kick1', true);
				FlxG.sound.play(Paths.sound('doorKick1'), 1.0);
			}
		case 'sserafimBeautiful':
			gfBeautiful = params != null && params.beautiful == true;
		case 'sserafimEnd':
			endStuff();
		case 'sserafimGuitarVibration':
			// 触感反馈，桌面端无操作
		case 'SetHealthIcon':
			// 官方 SetHealthIconSongEvent：char 0 = 玩家血条(iconP1)，1 = 对手(iconP2)
			if (params == null || params.id == null) return;
			var icon = null;
			if (params.char == 0) icon = p.iconP1; else icon = p.iconP2;
			if (icon == null) return;
			try {
				icon.changeIcon(params.id);
				// FE 的 HealthIcon 建 iconP1 时就用 animation.add(..., isPlayer) 把动画设成 FlipX 了
				// （玩家侧图标天生镜像一次）。V-Slice 那边的 flipX 语义跟这里叠起来正好反相，
				// 所以玩家侧一律不额外翻 —— gf / bf 图标"反了"就是这么来的。
				var wantFlip = (params.flipX == true);
				if (params.char == 0) wantFlip = false;
				icon.flipX = wantFlip;
				icon.visible = true;
				if (LOG_HOT) slog('event: icon char=' + params.char + ' -> ' + params.id + ' flip=' + wantFlip);
			} catch (e:Dynamic) { slog('event: icon ' + params.id + ' FAILED ' + e); }
		case 'ZoomCamera':
			if (params == null) return;
			var zoom = params.zoom;
			if (zoom == null) return;
			// stage 模式乘舞台基准；direct 模式乘 FlxCamera.defaultZoom（= 1.0，不是 0.9）
			var target = (params.mode == 'stage') ? zoom * stageBaseZoom : zoom;
			camZoomTo(target, vsDuration(params.duration), vsEase(params.ease, params.easeDir));
		case 'FocusCamera':
			if (params == null) return;
			var ch = params.char;
			if (ch == -1 || ch == null) {
				camPosTo(params.x, params.y, vsDuration(params.duration), vsEase(params.ease, params.easeDir));
			} else {
				var tx = 0.0; var ty = 0.0;
				if (ch == 0 && p.boyfriend != null) {
					tx = p.boyfriend.getMidpoint().x + p.boyfriendCameraOffset[0] - 100;
					ty = p.boyfriend.getMidpoint().y + p.boyfriendCameraOffset[1] - 100;
				} else if (ch == 1 && p.dad != null) {
					tx = p.dad.getMidpoint().x + p.opponentCameraOffset[0] + 150;
					ty = p.dad.getMidpoint().y + p.opponentCameraOffset[1] - 100;
				} else if (ch == 2 && p.gf != null) {
					tx = p.gf.getMidpoint().x + p.girlfriendCameraOffset[0];
					ty = p.gf.getMidpoint().y + p.girlfriendCameraOffset[1];
				}
				camPosTo(tx, ty, vsDuration(params.duration), vsEase(params.ease, params.easeDir));
			}
		case 'SetCameraBop':
			if (params == null) return;
			var rate = params.rate == null ? 4 : params.rate;
			var intensity = params.intensity == null ? 1 : params.intensity;
			Reflect.setProperty(p, 'erectCameraBopRate', Std.int(rate));
			Reflect.setProperty(p, 'erectCameraBopIntensity', intensity);
			Reflect.setProperty(p, 'erectCameraBopEnabled', true);
			Reflect.setProperty(p, 'camZooming', intensity > 0);
	}
}

// V-Slice 的 duration 单位是"步"，PE 这边要秒
function vsDuration(steps) {
	if (steps == null || steps <= 0) return 0;
	return Conductor.stepCrochet * steps / 1000 / Math.max(0.001, ps().playbackRate);
}

function vsEase(name, dir) {
	if (name == null || name == 'INSTANT') return FlxEase.linear;
	var n = name;
	if (n == 'CLASSIC') n = 'cube';
	var fn = n + (dir == null ? '' : dir);
	var f = Reflect.field(FlxEase, fn);
	return f == null ? FlxEase.linear : f;
}

function flashTruckLights(amount, duration) {
	var l1 = getProp('truckLight1'); var l2 = getProp('truckLight2');
	if (l1 == null) return;
	FlxTween.cancelTweensOf(l1);
	FlxTween.cancelTweensOf(l2);
	l1.alpha = amount;
	l2.alpha = amount;
	setBothTruck(amount);
	FlxTween.tween(l1, { alpha: 0 }, duration, {
		ease: FlxEase.cubeInOut,
		onUpdate: function(tw) { setBothTruck(l1.alpha); },
		onComplete: function(tw) { setBothTruck(0); }
	});
	FlxTween.tween(l2, { alpha: 0 }, duration, { ease: FlxEase.cubeInOut });
}

function flashBackLight(amount, duration, col) {
	var lc = getProp('backLightColor'); var lw = getProp('backLightWhite');
	if (lc == null) return;
	FlxTween.cancelTweensOf(lc);
	FlxTween.cancelTweensOf(lw);
	lc.color = col;
	lc.alpha = amount * 0.8;
	lw.alpha = amount * 0.7;
	setBothPulseColor(col);
	setBothPulse(lc.alpha);
	FlxTween.tween(lc, { alpha: 0 }, duration, {
		ease: FlxEase.cubeInOut,
		onUpdate: function(tw) { setBothPulse(lc.alpha); },
		onComplete: function(tw) { setBothPulse(0); }
	});
	FlxTween.tween(lw, { alpha: 0 }, duration, { ease: FlxEase.cubeInOut });
}

function hookDoorFrame() {
	if (doorFrameHooked || yunjin == null) return;
	doorFrameHooked = true;
	doorShownFinal = false;
}

// kick2 第 23 帧起门已经不在她的图集里了 → 换成静态那张。
// 注意：yunjin 是 flxanimate 角色，帧由 atlas.anim 驱动，
// `animation.onFrameChange` 根本不会触发（原来挂在那儿等于没挂），只能在 onUpdate 里轮询。
function updateDoorFrame() {
	if (!doorFrameHooked || doorShownFinal) return;
	if (yunjin == null) return;
	if (yunjin.getAnimationName() != 'kick2') return;
	var cf = 0;
	try { cf = Std.int(yunjin.atlas.anim.curFrame); } catch (e:Dynamic) { return; }
	if (cf >= 23) {
		doorShownFinal = true;
		var d = getProp('truckDoor');
		if (d != null) d.visible = true;
		slog('kick: static truckDoor shown at frame ' + cf);
	}
}

// ============================================================================
//  §12  节拍 / 音符 / 调试
// ============================================================================

function onBeatHit() {
	var p = ps();
	if (p == null) return;
	var beat = p.curBeat;

	// 卡车后方的脉冲灯
	if (lightsEnabled && lightsIntensities.length > 0) {
		var i = beat % lightsIntensities.length;
		var col = FlxColor.fromString(lightsColors[i % lightsColors.length]);
		flashBackLight(lightsIntensities[i], lightsDurations[i % lightsDurations.length], col);
	}

	// 女团 idle：官方 danceEvery = 1.0（每拍），不是每 2 拍
	for (i in 0...5) if (girlHold[i] > 0) girlHold[i] = girlHold[i] - 1;
	if (chaewon != null && chaewon.visible && !girlsSinging[2] && girlHold[2] <= 0) chaewon.playAnim('idle');
	if (eunchae != null && eunchae.visible && !girlsSinging[3] && girlHold[3] <= 0) eunchae.playAnim('idle');
	if (yunjin != null && yunjin.visible && yunjinDance && !girlsSinging[0] && girlHold[0] <= 0) yunjin.playAnim('idle');

	// gf：唱的时候保持 sing 姿势，不唱了才回去跳舞。
	// 引擎 characterBopper 只在"当前动画名不以 sing 开头"时才会让她跳，
	// 所以唱完必须由我们把 sing 姿态解除，否则她会一直定在唱歌姿势。
	// 唱姿保持的剩余拍数。别写 gfHold--（见 §1 关于 ++/-- 的说明）
	if (gfHold > 0) gfHold = gfHold - 1;
	if (p.gf != null) {
		var gsing = gfSings();
		if (!gsing && gfHold <= 0) {
			var cur = p.gf.getAnimationName();
			if (gfBeautiful) {
				gfDanceFlip = !gfDanceFlip;
				p.gf.playAnim(gfDanceFlip ? 'danceRight-beautiful' : 'danceLeft-beautiful', true);
			} else if (cur != null && cur.indexOf('sing') == 0) {
				p.gf.playAnim('danceLeft', true);
			}
		}
	}
}

function goodNoteHit(note) {
	if (note == null || note.isSustainNote) return;
	var kind = playSakuraKind(note, false);   // 先播 bf 专属姿势，并且不让下面覆盖它
	var dir = ['LEFT', 'DOWN', 'UP', 'RIGHT'][note.noteData % 4];
	girlSing(dir, true, kind);
}

function noteMiss(note) {
	if (note == null || note.isSustainNote) return;
	playSakuraKind(note, true);
}

// ----------------------------------------------------------------------------
//  官方 sserafim-sakura.hxc 的自定义 note kind：sakura-joint / sakura-bf1 / sakura-bf2
//  FE 的 Note 只认 Hurt Note / Alt Animation / No Animation / Censor，
//  这几个 kind 会被默默丢掉 → 角色永远只播普通 singX，
//  于是 sakura 的 joint / bf1 / bf2 三套（24 条动画）全部触发不了。
//  这里按官方 onNoteHit / onNoteMiss 的规则接管：
//    -joint  两人一起唱 → 'singX-joint'
//    -bf1    只有 bf 唱   → 'singX-bf1'
//    -bf2    bf 另一套姿势 → 'singX-bf2'
//    miss 时 bf1 统一用 bf2（官方就是这么写的，bf1 没有 miss 套）
// ----------------------------------------------------------------------------
function sakuraSuffix(kind) {
	if (kind == 'sakura-joint') return 'joint';
	if (kind == 'sakura-bf1') return 'bf1';
	if (kind == 'sakura-bf2') return 'bf2';
	return null;
}

function playSakuraKind(note, isMiss) {
	var suf = sakuraSuffix(note.noteType);
	if (suf == null) return false;
	var ch = ps().boyfriend;
	if (ch == null) return false;
	if (isMiss && suf == 'bf1') suf = 'bf2';
	var dir = ['LEFT', 'DOWN', 'UP', 'RIGHT'][Std.int(Math.abs(note.noteData)) % 4];
	var anim = 'sing' + dir + (isMiss ? 'miss' : '') + '-' + suf;
	if (!ch.hasAnimation(anim)) return false;
	ch.playAnim(anim, true);
	ch.holdTimer = 0;
	return true;
}

function opponentNoteHit(note) {
	if (note == null || note.isSustainNote) return;
	// 这套编曲里对手侧没人唱
	if (ps().dad != null && !girlsSinging[1]) ps().dad.playAnim('idle', true);
}

// F2：嘴型调试标注开关
function checkDebugKeys() {
	var k = FlxG.keys;
	if (k == null) return;
	if (k.justPressed.F2) setMouthDebug(!MOUTH_DEBUG);
	// F3：把舞台/角色的运行时 shader 全摘掉。用来分辨"卡在 GPU shader"还是"卡在别处"——
	// 摘掉后帧率明显回升 = 瓶颈是逐精灵的 FlxRuntimeShader（那个片元对每像素都很贵）。
	if (k.justPressed.F3) {
		shadersOff = !shadersOff;
		setShadersEnabled(!shadersOff);
		slog('perf: shaders ' + (shadersOff ? 'OFF' : 'ON'));
	}
	if (k.justPressed.F4) {
		PERF_LOG = !PERF_LOG;
		perfAccum = 0;
		perfFrames = 0;
		perfWorst = 0;
		slog('perf: log ' + (PERF_LOG ? 'ON' : 'OFF'));
	}
}

// 把所有挂过 shader 的精灵收集起来（角色侧用 characterShader，舞台侧用 stageShader）
function eachShaderSprite(fn) {
	var p = ps();
	var i = 0;
	for (c in girlList()) { if (c != null) fn(c, true); }
	if (p.gf != null) fn(p.gf, true);
	if (cutsceneSprite != null) fn(cutsceneSprite, true);
	if (sserafimGf != null) fn(sserafimGf, true);
	if (sserafimBf != null) fn(sserafimBf, true);
	for (i in 0...5) if (lipsyncs[i] != null) fn(lipsyncs[i], true);
	for (key in ['bg', 'backTables', 'backTablesCutscene', 'burgerCutscene', 'backStools',
				 'truck', 'truckDoor', 'frontStool']) {
		var spr = getProp(key);
		if (spr != null) fn(spr, false);
	}
	if (floorSpr != null) fn(floorSpr, false);
}

function setShadersEnabled(on) {
	eachShaderSprite(function(spr, isChar) {
		try { spr.shader = on ? (isChar ? characterShader : stageShader) : null; } catch (e:Dynamic) {}
	});
}

// ============================================================================
//  §13  结尾
// ============================================================================

function endStuff() {
	var p = ps();
	FlxG.sound.play(Paths.sound('cutscene/end1'), 1.0);

	endTime(0.05, function(tmr) {
		if (SEEYOU1 != null) SEEYOU1.visible = true;
		if (solidCover != null) solidCover.alpha = 1;
		p.camHUD.visible = false;
		p.inCutscene = true;
	});

	endTime(4, function(tmr) {
		if (SEEYOU1 != null) SEEYOU1.visible = false;
		if (SEEYOU2 != null) SEEYOU2.visible = true;
		FlxG.sound.play(Paths.sound('cutscene/end2'), 1.0);
	});

	endTime(8, function(tmr) {
		if (SEEYOU1 != null) SEEYOU1.visible = false;
		if (SEEYOU2 != null) SEEYOU2.visible = false;
	});

	endTime(9, function(tmr) {
		p.inCutscene = false;
		removeVar('sserafim_cutscene_at');
		p.endSong();
	});
}

// 脚本演出期间别让玩家暂停
function onPause() {
	if (cutsceneActive || (ps() != null && ps().inCutscene)) return '##PSYCHLUA_FUNCTIONSTOP';
}

// ============================================================================
//  §14  生命周期
// ============================================================================

// FE 的实际调用顺序是 startCountdown()（→ onStartCountdown）**先于** onCreatePost，
// 而过场精灵是在 post 阶段建的 —— 于是 onStartCountdown 永远看到 cutsceneSprite == null，
// 判定"图集没加载"就直接放行倒计时 = 开场根本不播（日志里 countdown: SKIP intro, len=-1）。
// 所以把 post 的构建体抽成幂等的 buildPost()，onStartCountdown 里先补建一次。
var postBuilt = false;

function onCreatePost() {
	buildPost();
}

function buildPost() {
	if (postBuilt) return;
	postBuilt = true;

	var p = ps();
	if (p == null) return;

	props = p.variables;
	stageBaseZoom = p.defaultCamZoom;   // stage json 的基准 zoom（事件乘数要用固定值）
	slog('post: begin zoom=' + stageBaseZoom);

	characterShader = newShader(true);
	stageShader = newShader(false);
	// 编译失败 / 文件读不到时这里会是 null —— 挂不上 shader 只会"没有调色"，
	// 而 shader 本身编不过时精灵会被画成黑块（整屏全黑，按 F3 摘掉 shader 才恢复）。
	slog('post: shaders char=' + (characterShader != null) + ' stage=' + (stageShader != null));

	// --- 透视地板：官方 zIndex 11（bg 之后、backTables 之前）---
	// 之前插在角色组之前 = 盖在所有静态道具上面，卡车下半截/桌椅腿全被吃掉。
	if (floorSpr == null) {
		try {
			floorSpr = new FlxSkewedSprite();
			floorSpr.matrixExposed = true;
			floorSpr.antialiasing = true;
			var img = Paths.image('floor');
			if (img != null) floorSpr.loadGraphic(img);
			floorSpr.scrollFactor.set(0.93, 0.93);
			floorSpr.shader = stageShader;
		} catch (e:Dynamic) { floorSpr = null; }
	}
	if (floorSpr != null) insertAfterProp(floorSpr, 'bg');
	slog('post: floor ok=' + (floorSpr != null));

	// --- 额外三名成员 ---
	if (yunjin == null) {
		yunjin = addGirl('sserafim-yunjin', -801, -140, 0.95);
		chaewon = addGirl('sserafim-chaewon', 537, -202, 0.95);
		eunchae = addGirl('sserafim-eunchae', 620, 375, 0.97);
		// 官方 zIndex 1000：在 dad/bf 之上、frontStool(1500) 之下
		var idx = indexBehindFrontStool();
		p.insert(idx, yunjin);
		p.insert(idx + 1, chaewon);
		p.insert(idx + 2, eunchae);
	}
	slog('post: extra girls ok');

	// dad(kazuha) / bf(sakura) 是引擎自己建的角色，addGirl 管不到 —— 同样的偏移量补一遍。
	// ⚠ gf 不要补：她的落点由 shared/characters/sserafim-gf.json 的 position 单独调
	//   （[-1100,-1000] = 站到卡车上，用户实机校准过，别当残留删掉）。
	if (p.gf != null) { p.gf.x -= 1300; p.gf.y -= 1200; }
	if (p.dad != null) { p.dad.x += CHAR_SHIFT_X; p.dad.y += CHAR_SHIFT_Y; }
	if (p.boyfriend != null) { p.boyfriend.x += CHAR_SHIFT_X; p.boyfriend.y += CHAR_SHIFT_Y; }
	slog('post: char shift ' + CHAR_SHIFT_X + ',' + CHAR_SHIFT_Y);
	try {
		if (p.gf != null) slog('post: gf pos=' + Math.round(p.gf.x) + ',' + Math.round(p.gf.y)
			+ ' group=' + (p.gfGroup != null ? Math.round(p.gfGroup.x) + ',' + Math.round(p.gfGroup.y) : 'null'));
		if (p.boyfriend != null) slog('post: bf pos=' + Math.round(p.boyfriend.x) + ',' + Math.round(p.boyfriend.y));
		if (p.dad != null) slog('post: dad pos=' + Math.round(p.dad.x) + ',' + Math.round(p.dad.y));
	} catch (e:Dynamic) {}
	if (p.dad != null) p.dad.shader = characterShader;
	if (p.boyfriend != null) p.boyfriend.shader = characterShader;
	if (p.gf != null) p.gf.shader = characterShader;

	// --- 背景道具：只给"该吃调色"的物件挂 stageShader ---
	// 官方 addProp：默认全挂，但把 4 个灯光和 solidCover 置空并改 blend。
	// 灯光挂上 shader 会被夜间调色压暗，而且 blend 从 SCREEN/ADD 退化成了普通覆盖。
	for (key in ['bg', 'backTables', 'backTablesCutscene', 'burgerCutscene', 'backStools',
				 'truck', 'truckDoor', 'frontStool']) {
		var spr = getProp(key);
		if (spr != null) spr.shader = stageShader;
	}
	var l1 = getProp('truckLight1');
	if (l1 != null) { l1.shader = null; l1.blend = 12; }        // SCREEN
	var l2 = getProp('truckLight2');
	if (l2 != null) { l2.shader = null; }                        // NORMAL
	var lc = getProp('backLightColor');
	if (lc != null) { lc.shader = null; lc.blend = 12; lc.color = 0xFFCC3300; }  // SCREEN
	var lw = getProp('backLightWhite');
	if (lw != null) { lw.shader = null; lw.blend = 0; }          // ADD

	// 过场专用道具平时不可见
	if (getProp('backTablesCutscene') != null) getProp('backTablesCutscene').visible = false;
	if (getProp('burgerCutscene') != null) getProp('burgerCutscene').visible = false;

	// FE 的 StageData 对 scale≠1 的道具会顺手 updateHitbox()，把 offset/origin 挪到中心，
	// 跟官方"以左上角为基准缩放"不一致 —— 吧台是 400 倍横向拉伸，会整块跑飞。这里还原。
	for (key in ['backTablesCutscene', 'burgerCutscene']) {
		var sp = getProp(key);
		if (sp != null) { sp.offset.set(0, 0); sp.origin.set(0, 0); }
	}

	// 过场整体下移（CUT_SCENE_SHIFT_Y）：拉长吧台/汉堡跟图集、地板三层同量一起动。
	// 这两个道具只在过场可见，永久平移不影响正式演出画面。
	for (key in ['backTablesCutscene', 'burgerCutscene']) {
		var sp = getProp(key);
		if (sp != null) sp.y += CUT_SCENE_SHIFT_Y / CUTSCENE_ZOOM_IN;
	}

	// --- 嘴型（一条嘴一个成员，见 §7 表）---
	// 逐块 try：任何一块炸掉都不能把后面（尤其是过场精灵）一起带走
	try {
		if (lipsyncs[0] == null) {
			var girlsArr = girlList();
			var insertAt = indexBehindFrontStool();
			for (i in 0...5) {
				if (girlsArr[i] == null) continue;
				lipsyncs[i] = addMouth(i, girlsArr[i]);
				if (lipsyncs[i] != null) p.insert(insertAt + i, lipsyncs[i]);
			}
		}
		slog('post: lipsync ok');
	} catch (e:Dynamic) { slog('post: lipsync FAILED ' + e); }

	// --- 尘埃 ---
	try {
		if (dust1 == null) makeDust();
		slog('post: dust ok');
	} catch (e:Dynamic) { slog('post: dust FAILED ' + e); }

	if (solidCover == null) {
		solidCover = new FlxSprite(-5000, -3000).makeGraphic(10000, 10000, 0xFF000000);
		solidCover.scrollFactor.set(0, 0);
		solidCover.alpha = 0;
		p.add(solidCover);
	}

	// --- 过场精灵 ---
	// 官方 FunkinSprite 是"图集 + 动画控制器"二合一，FE 里只有裸 FlxAnimate，
	// 所以三个精灵逐个建、逐个兜错 —— 一个图集坏了不能连累另外两个。
	if (cutsceneSprite == null) {
		try {
			cutsceneSprite = new FlxAnimate(0, 0);
			Paths.loadAnimateAtlas(cutsceneSprite, 'cutscene/cutsceneMain');
			cutsceneSprite.setPosition(-395, 10);
			cutsceneSprite.scrollFactor.set(0.94, 0.94);
			cutsceneSprite.shader = characterShader;
			cutsceneSprite.visible = false;
			slog('post: cutsceneMain ok len=' + cutsceneSprite.anim.length
				+ ' fw=' + cutsceneSprite.frameWidth + ' fh=' + cutsceneSprite.frameHeight
				+ ' frames=' + cutsceneSprite.frames.numFrames);
		} catch (e:Dynamic) {
			slog('post: cutsceneMain FAILED ' + e);
		}

		try {
			sserafimGf = new FlxAnimate(0, 0);
			Paths.loadAnimateAtlas(sserafimGf, 'cutscene/gfGetUp');
			sserafimGf.setPosition(655, -104 + CUT_BFGF_Y_SHIFT);
			sserafimGf.scrollFactor.set(0.95, 0.95);
			sserafimGf.shader = characterShader;
			sserafimGf.alpha = 0.5;
			sserafimGf.visible = false;
			slog('post: gfGetUp ok len=' + sserafimGf.anim.length + ' fw=' + sserafimGf.frameWidth + ' fh=' + sserafimGf.frameHeight + ' frames=' + sserafimGf.frames.numFrames);
		} catch (e:Dynamic) {
			slog('post: gfGetUp FAILED ' + e);
			sserafimGf = null;
		}

		try {
			sserafimBf = new FlxAnimate(0, 0);
			Paths.loadAnimateAtlas(sserafimBf, 'cutscene/bfGetUp');
			sserafimBf.setPosition(1220, 531 + CUT_BFGF_Y_SHIFT);
			sserafimBf.scrollFactor.set(0.99, 0.99);
			sserafimBf.shader = characterShader;
			sserafimBf.visible = false;
			slog('post: bfGetUp ok len=' + sserafimBf.anim.length + ' fw=' + sserafimBf.frameWidth + ' fh=' + sserafimBf.frameHeight + ' frames=' + sserafimBf.frames.numFrames);
		} catch (e:Dynamic) {
			slog('post: bfGetUp FAILED ' + e);
			sserafimBf = null;
		}

		// 官方 zIndex：gf/过场 25（角色之下）、bf 305（真 bf 的 300 之上）
		var idx2 = indexBehindFrontStool();
		if (sserafimGf != null) { p.insert(idx2, sserafimGf); idx2 = idx2 + 1; }
		if (cutsceneSprite != null) { p.insert(idx2, cutsceneSprite); idx2 = idx2 + 1; }

		if (sserafimBf != null) {
			var bfIdx = p.members.length;
			if (p.boyfriendGroup != null) {
				for (i in 0...p.members.length) if (p.members[i] == p.boyfriendGroup) { bfIdx = i + 1; break; }
			}
			p.insert(bfIdx, sserafimBf);
		}
		slog('post: cutscene sprites inserted at ' + idx2);

		try {
			SEEYOU1 = new FlxSprite().loadGraphic(Paths.image('end/end1'));
			SEEYOU1.scale.set(0.67, 0.67);
			SEEYOU1.updateHitbox();
			SEEYOU1.screenCenter();
			SEEYOU1.cameras = [p.camOther];
			SEEYOU1.visible = false;

			SEEYOU2 = new FlxSprite().loadGraphic(Paths.image('end/end2'));
			SEEYOU2.scale.set(0.67, 0.67);
			SEEYOU2.updateHitbox();
			SEEYOU2.setPosition(FlxG.width - 40 - SEEYOU2.width, FlxG.height - 40 - SEEYOU2.height);
			SEEYOU2.cameras = [p.camOther];
			SEEYOU2.visible = false;

			p.add(SEEYOU1);
			p.add(SEEYOU2);
		} catch (e:Dynamic) { slog('post: SEEYOU FAILED ' + e); }
	}

	// --- 初始状态 ---
	setGirlsVisible(baseVisible);
	setGirlsSinging(girlsSinging);
	if (p.iconP2 != null) p.iconP2.visible = false;
	lightsEnabled = false;

	// 两分钟内重试 = 跳过完整过场，直接"事后"
	var lastCut = getVar('sserafim_cutscene_at');
	var now = Date.now().getTime();
	if (lastCut != null && (now - lastCut) < 120000) {
		hasPlayedCutscene = true;
		playCutsceneFromRestart();
	}

	if (p.chartingMode) {
		hasPlayedCutscene = true;
		resetLook();
	}

	setVar('sserafim_stage_ready', true);
}

function onStartCountdown() {
	var p = ps();
	if (hasPlayedCutscene) return;

	// onStartCountdown 早于 onCreatePost —— 先把舞台/过场精灵补建出来
	buildPost();

	// 图集没加载成功就别硬播 30 秒空气：直接放行倒计时
	var mlen = -1;
	if (cutsceneSprite != null) {
		try { mlen = cutsceneSprite.anim.length; } catch (e:Dynamic) {}
	}
	if (mlen <= 0) {
		slog('countdown: SKIP intro, cutsceneMain len=' + mlen);
		hasPlayedCutscene = true;
		return;
	}

	// 用开场过场顶掉倒计时
	hasPlayedCutscene = true;
	cutsceneActive = true;
	cutsceneSkipped = false;
	canSkipCutscene = false;
	setVar('sserafim_cutscene_at', Date.now().getTime());
	slog('countdown: cutscene start, sprite=' + (cutsceneSprite != null) + ' gf=' + (sserafimGf != null) + ' bf=' + (sserafimBf != null));
	// 过场任何一环抛错都不能把歌卡死 —— 但也不能静默吞掉（那样看起来就是"过场没播"）
	try {
		introCutscene();
		slog('countdown: introCutscene returned');
	} catch (e:Dynamic) {
		slog('countdown: introCutscene FAILED ' + e);
		finishCutscene();
	}
	return '##PSYCHLUA_FUNCTIONSTOP';
}

function onUpdate(elapsed) {
	var p = ps();
	if (p == null) return;

	checkDebugKeys();

	// 性能探针：每 10 秒记一次 fps + 最差单帧（worst 才是"卡顿"，平均值看不出来）。
	// 别调成 1-2 秒：slog 要开文件，写得越勤越容易自己制造掉帧。F4 可以整个关掉。
	if (PERF_LOG) {
		perfAccum = perfAccum + elapsed;
		perfFrames = perfFrames + 1;
		if (elapsed > perfWorst) perfWorst = elapsed;
		if (perfAccum >= 10.0) {
			slog('perf fps=' + (Math.round(perfFrames / perfAccum * 10) / 10)
				+ ' worst=' + (Math.round(perfWorst * 1000) / 10) + 'ms'
				+ (shadersOff ? ' (no shader)' : '')
				+ ' zoom=' + Math.round(p.camGame.zoom * 100) / 100);
			perfAccum = 0;
			perfFrames = 0;
			perfWorst = 0;
		}
	}

	// 对手侧 strumline 只隐藏一次
	if (!strumsHidden && p.opponentStrums != null) {
		strumsHidden = true;
		for (a in p.opponentStrums.members) a.visible = false;
	}

	// 这舞台不要评级弹窗。判定弹窗（评级/early-late/combo/数字/ms）全都挂在 PlayState.comboGroup 里，
	// 整组 visible=false 就够了：FlxState.draw 看到组不可见就不会进 FlxGroup.draw，
	// 新建的和从对象池复用的精灵一律不会被画 —— 所以不会再有"先画出来一两帧再关掉"的跳动，
	// 也不用每帧轮询 activePopupGroups（原来那套既闪又遍历一个只增不减的数组）。
	if (!popupsOff) {
		popupsOff = true;
		try {
			if (p.comboGroup != null) p.comboGroup.visible = false;
		} catch (e:Dynamic) {}
	}

	// 过场开场：第一帧画出来就立刻取景（以前等 1.2s 才 fit，人物会"晚一会儿才出现"）
	if (!cutFitted && cutsceneSprite != null && cutsceneSprite.visible && cutsceneSprite.width > 0) {
		cutFitted = true;
		try {
			fitAnimateCenter(cutsceneSprite, CUT_FIT_X, CUT_FIT_Y + CUT_SCENE_SHIFT_Y / CUTSCENE_ZOOM_IN);
			probeSprite('cutscene first', cutsceneSprite);
		} catch (e:Dynamic) {}
	}

	if (floorSpr != null) updateFloorSkew(p.camGame);
	updateDoorFrame();
	updateLipsync();

	// getup 不再手动停格：官方就是让根时间轴一直播（踢门事件 2.5s 后就把两个起身精灵藏掉，
	// 时间轴根本播不完），以前硬停在末帧 = "起来后定在原地"。

	// 过场跳过
	if (cutsceneActive && !cutsceneSkipped && p.controls != null && p.controls.ACCEPT) {
		if (canSkipCutscene) skipCutscene();
		else canSkipCutscene = true;
	}
}
