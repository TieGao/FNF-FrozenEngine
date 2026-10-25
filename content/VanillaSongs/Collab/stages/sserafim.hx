// ============================================================================
//  LE SSERAFIM - SPAGHETTI 舞台（FrozenEngine / HScript）
// ----------------------------------------------------------------------------
//  移植自 V-Slice 0.8.7 的 sserafim.hxc / props/*.hxc。
//  静态道具在 ../shared/stages/sserafim.json，本脚本只管"动"的部分。
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
// 官方 stage json 的 cameraZoom
var STAGE_BASE_ZOOM = 0.5;
var CUTSCENE_ZOOM_IN = 0.7;      // 过场推近
var CUTSCENE_ZOOM_REST = 0.55;   // 撞车后回落的站立镜头

// ---- 嘴型全局微调 ------------------------------------------------------------
var MOUTH_GLOBAL_X = 0.0;
var MOUTH_GLOBAL_Y = 0.0;

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

var baseVisible = [true, false, false, false, false];
var girlsVisible = [true, false, false, false, false];
var girlsSinging = [false, false, false, false, false];
var girlHold = [0, 0, 0, 0, 0];
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

// 过场定时器代号：finish / skip 之后 +1，之前排下的回调全部作废（不能写 ++）
var cutsceneGen = 0;

var cutTimers = [];      // 过场定时器实体，跳过/结束时逐个 cancel
var endTimers = [];      // 结尾演出的定时器（endStuff）

// 开头 gf/bf 起身精灵的 y 微调（负数 = 往上，实机校准；gf 基准 -104、bf 基准 531）
var CUT_BFGF_Y_SHIFT = -80.0;

// 过场取景的目标屏幕中心（fitAnimateCenter 用）。
var CUT_FIT_X = 640.0;
var CUT_FIT_Y = 180.0;
var cutFitted = false;

// 酒吧交谈场景整体下移（实机校准，屏幕像素，正 = 往下；过场图集/过场道具/过场地板三层同量）
var CUT_SCENE_SHIFT_Y = 200.0;
var cutFloorShift = 0.0;   // 过场地板当前生效的下移量（setCutsceneVisibility 里切换，切回 0）

// gf 戳人时的镜头顿挫
var POKE_SHAKE = true;
var POKE_SHAKE_POWER = 0.003;
var POKE_SHAKE_TIME = 0.12;

// ---- 性能 ----
var popupsOff = false;

// ---- 脉冲灯 ----
var lightsEnabled = false;
var lightsColors = [];
var lightsDurations = [];
var lightsIntensities = [];

// ---- 相机 ----
var stageBaseZoom = STAGE_BASE_ZOOM;
var camZoomTween = null;
var camPosTween = null;
// 正在跑的调色 / 变暗 tween
var adjustTween = null;
var darkTween = null;

// ---- 一次性标志 ----
var strumsHidden = false;

// ============================================================================
//  §2  小工具
// ============================================================================

function ps() return PlayState.instance;

function getProp(name) {
	if (props == null) return null;
	return props.get(name);
}

// FlxAnimate 的取景校正：用 draw() 回填的 width/height/relativeX/Y 把图集矩形摆到屏幕目标中心
function fitAnimateCenter(spr, cx, cy) {
	if (spr == null) return false;
	if (spr.width <= 0 || spr.height <= 0) return false;
	spr.setPosition(cx - spr.relativeX - spr.width * 0.5,
					cy - spr.relativeY - spr.height * 0.5);
	return true;
}

// FlxAnimate 的符号名各图集不同 —— 失败就退回默认符号，别让过场崩掉
function tryAnim(spr, name) {
	if (spr == null || spr.anim == null) return;
	try { spr.anim.play(name, true); } catch (e:Dynamic) { try { spr.anim.play(); } catch (e2:Dynamic) {} }
}

// 图集帧标签定位（FlxAnim.play 认不出帧标签）
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

// 把 spr 插到 prop 之后（FE 的 stage json 没有 zIndex）
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
		// 内容包回退：直接读磁盘
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

// 剧情变暗（frag 的 darkAmt uniform）
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

// 戳人那一下的镜头顿挫
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

// 调色 tween
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

// 事件推的是基准，相机自己 lerp/bop 回基准 —— 别直接 tween camGame.zoom，会和 bop 打架
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

// 官方 startClear()：从"当前"调色缓到 0
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

// 全员站位整体微调（实机校准），只作用于演出里的女团五人（过场图集仍用官方坐标）
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

// gf 是数组第 6 位（官方 baseSinging / 我们的 sserafimSing 都是 6 位），
// 但她不在 girlList 里，引擎也永远不会让 gf 唱 → 必须由这里自己驱动
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
	if (!p.gf.hasAnimation(nm)) return;
	p.gf.playAnim(nm, true);
	gfHold = 2;
}

// skipBf = 这一拍已经播过 bf 专属姿势（joint / bf1 / bf2），别再播普通 singX
function girlSing(dirName, isPlayerSide, skipBf) {
	if (!isPlayerSide) return;
	var girls = girlList();
	for (i in 0...girls.length) {
		if (girls[i] == null) continue;
		if (!girlsSinging[i]) {
			// 不唱的成员按回 idle（bf 槽每颗音符都会被引擎播 singX）
			if (i == 4 && skipBf != true) {
				var cur4 = girls[4].getAnimationName();
				if (cur4 != null && cur4.indexOf('sing') == 0) {
					girls[4].playAnim('idle', true);
					girlHold[4] = 0;
				}
			}
			continue;
		}
		if (i == 4 && skipBf == true) continue;
		// i == 4（sakura = bf 槽）：她在唱时引擎自己就会播 singX，这里再播会从头重启
		if (i == 4) continue;
		if (girlHold[i] > 8) continue;
		girls[i].playAnim('sing' + dirName, true);
		girlHold[i] = 4;
	}
	if (gfSings()) gfSing(dirName);
}

//  §7  嘴型 lipsync
// ----------------------------------------------------------------------------
//  嘴 = 独立 FlxAnimate 叠加在角色上，锚点逐帧取自 sserafim/lipsync/anchors.json。
//  数据格式：{ 角色id: { 动画名: [[x, y, rot], ...] } }
//    x/y = "mouth xxx" 占位位图的 bbox 中心（姿势符号自身坐标，不含根时间轴摆放）
//    rot = 该帧头部倾斜角
// ----------------------------------------------------------------------------

// 嘴图集里嘴美术的 bbox 中心（画布坐标，兼作旋转中心与位置补偿）
var MOUTH_ART_CENTER_SHARED = [249.80, 208.29];   // sserafim-lipsync
var MOUTH_ART_CENTER_YUNJIN = [249.08, 208.02];   // sserafim-lipsync-yunjin

// 整体角度修正（正数=顺时针）
var MOUTH_ANGLE_FIX = 0.0;

// MOUTHS 表 —— 一条嘴对应一名成员
//   girl/charId/slot  成员名 / 角色图集目录（anchors.json 的键）/ 舞台槽位
//   atlas/artCenter   嘴图集 / 嘴美术 bbox 中心（旋转中心）
//   alpha/angle/flip  透明度 / 角度修正 / 是否镜像
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
	// 没有该动画的逐帧锚点就整张嘴隐藏
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
	// 负 scale = 绕 origin（嘴美术中心）镜像；flipX 会绕画布原点镜像，不能用
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
		// miss 时整张嘴隐藏
		if (a == null) { ls.visible = false; continue; }
		try { if (anim != null && anim.indexOf('miss') >= 0) { ls.visible = false; continue; } } catch (e:Dynamic) {}

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

		// 只有正在唱的成员嘴才动，其他人 fixed 在第 0 帧（闭口）
		var singing = (girlsSinging[i] == true);
		if (singing) {
			try { if (anim != null && anim.indexOf('miss') >= 0) singing = false; } catch (e:Dynamic) {}
		}
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
	}
}

// FlxTextBorderStyle 是真 enum，HScript 里写字符串会崩 —— 从 HUD 自带文本借一个构造好的值
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

// ============================================================================
//  §8  透视地板
// ============================================================================

// 官方 PerspectiveSprite 的双 scrollFactor 折成等价 skew 矩阵
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
		// 灰尘不挂 stageShader（官方就没有）
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
		// 过场期间保持隐藏（非过场照常恢复）
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
	// 过场下移：地板只在过场里挪，切回正常地板时归零
	cutFloorShift = inCutscene ? CUT_SCENE_SHIFT_Y / CUTSCENE_ZOOM_IN : 0.0;
	if (ps().gf != null) ps().gf.visible = false;
	if (cutsceneSprite != null) cutsceneSprite.visible = inCutscene;
}

// ---- 过场定时器：带"代"号 + 实体表，过场作废后自动失效 ----

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
	cutsceneGen = cutsceneGen + 1;
	var old = cutTimers;
	cutTimers = [];
	for (t in old) {
		if (t == null) continue;
		try { t.cancel(); } catch (e:Dynamic) {}
	}
}

// 结尾演出定时器（不吃过场代号，只认关卡归属）
function endTime(sec, fn) {
	var owner = ps();
	var tmr = new FlxTimer();
	endTimers.push(tmr);
	tmr.start(sec, function(t) {
		if (owner != ps()) return;
		fn(t);
	});
}

// 定格在"标签首帧 + offset"
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

	// 逐段兜错：一步炸掉不该把整段过场（和歌）一起带走
	try { setCutsceneVisibility(true); }
	catch (e:Dynamic) {}

	try { resetLook(); setBothAdjust(0, 0, 0, 0); }
	catch (e:Dynamic) {}

	// skip 提示文本（直接设属性，不走 setFormat）
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
	} catch (e:Dynamic) {
		skipText = null;
	}

	if (cutsceneSprite != null) {
		cutsceneSprite.visible = true;
		tryAnim(cutsceneSprite, '');
	}

	// 开场镜头：0.5 → 0.7
	try {
		camZoomTo(stageBaseZoom, 0);
		camPosTo(660, -200, 0);
		p.camGame.fade(0xFF000000, 3, true, null, true);
		camZoomTo(CUTSCENE_ZOOM_IN, 3, FlxEase.circOut);
		camPosTo(660, 300, 3, FlxEase.circOut);
	} catch (e:Dynamic) {}

	// 取景自校正：1.2s 首次，3.4s 镜头推完再校一次（第一次校时镜头还在动，落点会差几十像素）
	cutTime(1.2, function(tmr) {
		try {
			fitAnimateCenter(cutsceneSprite, CUT_FIT_X, CUT_FIT_Y + CUT_SCENE_SHIFT_Y / CUTSCENE_ZOOM_IN);
		} catch (e:Dynamic) {}
	});
	cutTime(3.4, function(tmr) {
		try {
			fitAnimateCenter(cutsceneSprite, CUT_FIT_X, CUT_FIT_Y + CUT_SCENE_SHIFT_Y / CUTSCENE_ZOOM_IN);
		} catch (e:Dynamic) {}
	});

	cutTime(20 / 24, function(tmr) {
		cutsceneSound = FlxG.sound.play(Paths.sound('cutscene/startCutscene'), 1.0);
	});

	// gf 戳自己
	cutTime(245 / 24, function(tmr) { darkenTween(0.2, 0.01); pokePunch(); });
	cutTime(251 / 24, function(tmr) { darkenTween(0, 0.8); });

	// gf 戳 bf
	cutTime(406 / 24, function(tmr) { darkenTween(0.2, 0.01); pokePunch(); });
	cutTime(411 / 24, function(tmr) { darkenTween(0, 0.8); });

	// 卡车开始逼近 —— 画面变冷变亮
	cutTime(499 / 24, function(tmr) {
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
		// 显式拉回灰尘（对齐官方撞车后满天灰）
		hideDust(true);
		if (solidCover != null) FlxTween.tween(solidCover, { alpha: 0 }, 3, { ease: FlxEase.sineOut });

		// getup 提前到 @650 起播（官方 @710 太晚），末帧由 onUpdate 定格（防时间轴循环回躺姿）
		if (sserafimGf != null) { sserafimGf.visible = true; gfStopFrame = playLabel(sserafimGf, 'getup'); }
		if (sserafimBf != null) { sserafimBf.visible = true; bfStopFrame = playLabel(sserafimBf, 'getup'); }
	});

	cutTime(730 / 24, function(tmr) {
		finishCutscene();
	});
}

function finishCutscene() {
	var p = ps();
	// 作废还没到点的过场回调
	cutsceneKillTimers();
	cutsceneActive = false;
	cutsceneSkipped = true;
	if (cutsceneSprite != null) cutsceneSprite.visible = false;
	p.inCutscene = false;
	p.camHUD.visible = true;
	if (skipText != null) skipText.visible = false;
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

	// 跳过点可能落在白闪 / 黑幕中间，补回正常画面
	if (solidCover != null) {
		FlxTween.cancelTweensOf(solidCover);
		solidCover.alpha = 0;
	}
	p.camGame.fade(0xFF000000, 0.01, true, null, true);
	try { p.camGame.stopFlash(); } catch (e:Dynamic) {}

	camZoomTo(CUTSCENE_ZOOM_REST, 1, FlxEase.circOut);
	camPosTo(1070, 470, 1, FlxEase.circOut);

	// 官方直接定格在"站起来"（curFrame 23），不从躺倒重播
	if (sserafimGf != null) { sserafimGf.visible = true; holdLabelAt(sserafimGf, 'getup', 22); }
	if (sserafimBf != null) { sserafimBf.visible = true; holdLabelAt(sserafimBf, 'getup', 22); }
}

function skipCutscene() {
	var p = ps();
	cutsceneKillTimers();
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
		case 'sserafimSing':
			if (params != null && params.singing != null) {
				setGirlsSinging(params.singing);
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
					if (p.gf != null) p.gf.visible = true;
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
				// 玩家侧图标建立时已镜像一次，不再额外翻
				var wantFlip = (params.flipX == true);
				if (params.char == 0) wantFlip = false;
				icon.flipX = wantFlip;
				icon.visible = true;
			} catch (e:Dynamic) {}
		case 'ZoomCamera':
			if (params == null) return;
			var zoom = params.zoom;
			if (zoom == null) return;
			// stage 模式乘舞台基准，direct 模式乘 1.0
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

// kick2 第 23 帧起门不在图集里 → 换静态图；flxanimate 帧回调不触发，只能轮询
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
	}
}

// ============================================================================
//  §12  节拍 / 音符
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
	if (yunjin != null && yunjin.visible && yunjinDance && !girlsSinging[0] && girlHold[0] <= 0) {
		// kick1/kick2 没播完之前别按回 idle
		var kicking = false;
		try {
			var cur0 = yunjin.getAnimationName();
			kicking = (cur0 != null && cur0.indexOf('kick') == 0 && !yunjin.isAnimationFinished());
		} catch (e:Dynamic) {}
		if (!kicking) yunjin.playAnim('idle');
	}

	// gf：唱完要手动解除 sing 姿态，否则引擎不会让她回去跳舞
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
	// 官方 onNoteMiss：正在唱的成员播 miss 姿势（bf 槽=sakura 由引擎自己播）
	girlMiss(['LEFT', 'DOWN', 'UP', 'RIGHT'][Std.int(Math.abs(note.noteData)) % 4]);
}

// miss 分工：只有 girlsSinging 为真的成员播 singXmiss，没在唱的继续跳舞。
// gf 也在这里管（引擎永远不会让她唱/miss）。动画没有就静默跳过。
function girlMiss(dirName) {
	var girls = girlList();
	for (i in 0...girls.length) {
		if (i == 4) continue;
		var g = girls[i];
		if (g == null || !girlsSinging[i]) continue;
		var anim = 'sing' + dirName + 'miss';
		if (g.hasAnimation(anim)) {
			g.playAnim(anim, true);
			girlHold[i] = 4;
		}
	}
	var p = ps();
	if (gfSings() && p.gf != null && p.gf.visible) {
		var nm = 'sing' + dirName + 'miss' + (gfBeautiful ? '-beautiful' : '');
		if (!p.gf.hasAnimation(nm)) nm = 'sing' + dirName + 'miss';
		if (p.gf.hasAnimation(nm)) {
			p.gf.playAnim(nm, true);
			gfHold = 2;
		}
	}
}

// ----------------------------------------------------------------------------
//  官方 sserafim-sakura.hxc 的自定义 note kind，FE 引擎不认识，由这里接管：
//  -joint 两人合唱 / -bf1 只有 bf 唱 / -bf2 bf 另一套姿势；miss 时 bf1 用 bf2
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
	// 对手侧不唱，只在还停在唱姿时按回 idle
	if (ps().dad != null && !girlsSinging[1]) {
		var cur1 = null;
		try { cur1 = ps().dad.getAnimationName(); } catch (e:Dynamic) {}
		if (cur1 != null && cur1.indexOf('sing') == 0) ps().dad.playAnim('idle', true);
	}
}

// ----------------------------------------------------------------------------
//  引擎 Pre 钩子：不该引擎播的 note 动画直接 noAnimation，分工归脚本管
//  （没在唱的 sakura / bf 专属 kind / 对手侧全部）。
// ----------------------------------------------------------------------------
function goodNoteHitPre(note) {
	if (note == null || note.gfNote) return;
	if (girlsSinging == null || !girlsSinging[4] || sakuraSuffix(note.noteType) != null) {
		note.noAnimation = true;
	}
}

function opponentNoteHitPre(note) {
	if (note == null) return;
	note.noAnimation = true;
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

// FE 的 startCountdown 先于 onCreatePost，post 构建体抽成幂等的 buildPost()，
// 在 onStartCountdown 里先补建一次
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

	characterShader = newShader(true);
	stageShader = newShader(false);

	// --- 透视地板：官方 zIndex 11（bg 之后、backTables 之前）---
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

	// --- 额外三名成员 ---
	if (yunjin == null) {
		yunjin = addGirl('sserafim-yunjin', -796, -113, 0.95);
		chaewon = addGirl('sserafim-chaewon', 537, -202, 0.95);
		eunchae = addGirl('sserafim-eunchae', 620, 375, 0.97);
		// 官方 zIndex 1000：在 dad/bf 之上、frontStool(1500) 之下
		var idx = indexBehindFrontStool();
		p.insert(idx, yunjin);
		p.insert(idx + 1, chaewon);
		p.insert(idx + 2, eunchae);
	}

	if (p.gf != null) { p.gf.x -= 1400; p.gf.y -= 1050; }
	if (p.dad != null) { p.dad.x += CHAR_SHIFT_X; p.dad.y += CHAR_SHIFT_Y; }
	if (p.boyfriend != null) { p.boyfriend.x += CHAR_SHIFT_X -175; p.boyfriend.y += CHAR_SHIFT_Y -150; }
	if (p.dad != null) p.dad.shader = characterShader;
	if (p.boyfriend != null) p.boyfriend.shader = characterShader;
	if (p.gf != null) p.gf.shader = characterShader;

	// --- 背景道具：只给"该吃调色"的物件挂 stageShader（灯光不挂，blend 改 SCREEN/ADD）---
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

	// StageData 会把 scale≠1 道具的 offset/origin 挪到中心，与官方"以左上角为基准"不一致，还原
	for (key in ['backTablesCutscene', 'burgerCutscene']) {
		var sp = getProp(key);
		if (sp != null) { sp.offset.set(0, 0); sp.origin.set(0, 0); }
	}

	// 过场下移：吧台/汉堡跟图集、地板三层同量一起动
	for (key in ['backTablesCutscene', 'burgerCutscene']) {
		var sp = getProp(key);
		if (sp != null) sp.y += CUT_SCENE_SHIFT_Y / CUTSCENE_ZOOM_IN;
		if (sp != null) sp.x += 1100;
	}

	// --- 嘴型（一条嘴一个成员，见 §7 表）---
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
	} catch (e:Dynamic) {}

	// --- 尘埃 ---
	try {
		if (dust1 == null) makeDust();
	} catch (e:Dynamic) {}

	if (solidCover == null) {
		solidCover = new FlxSprite(-5000, -3000).makeGraphic(10000, 10000, 0xFF000000);
		solidCover.scrollFactor.set(0, 0);
		solidCover.alpha = 0;
		p.add(solidCover);
	}

	// --- 过场精灵：三个逐个建、逐个兜错 ---
	if (cutsceneSprite == null) {
		try {
			cutsceneSprite = new FlxAnimate(0, 0);
			Paths.loadAnimateAtlas(cutsceneSprite, 'cutscene/cutsceneMain');
			cutsceneSprite.setPosition(-395, 10);
			cutsceneSprite.scrollFactor.set(0.94, 0.94);
			cutsceneSprite.shader = characterShader;
			cutsceneSprite.visible = false;
		} catch (e:Dynamic) {
			cutsceneSprite = null;
		}

		try {
			sserafimGf = new FlxAnimate(0, 0);
			Paths.loadAnimateAtlas(sserafimGf, 'cutscene/gfGetUp');
			sserafimGf.setPosition(655, -104 + CUT_BFGF_Y_SHIFT);
			sserafimGf.scrollFactor.set(0.95, 0.95);
			sserafimGf.shader = characterShader;
			sserafimGf.alpha = 0.5;
			sserafimGf.visible = false;
		} catch (e:Dynamic) {
			sserafimGf = null;
		}

		try {
			sserafimBf = new FlxAnimate(0, 0);
			Paths.loadAnimateAtlas(sserafimBf, 'cutscene/bfGetUp');
			sserafimBf.setPosition(1220, 531 + CUT_BFGF_Y_SHIFT);
			sserafimBf.scrollFactor.set(0.99, 0.99);
			sserafimBf.shader = characterShader;
			sserafimBf.visible = false;
		} catch (e:Dynamic) {
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
		} catch (e:Dynamic) {}
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
		hasPlayedCutscene = true;
		return;
	}

	// 用开场过场顶掉倒计时
	hasPlayedCutscene = true;
	cutsceneActive = true;
	cutsceneSkipped = false;
	canSkipCutscene = false;
	setVar('sserafim_cutscene_at', Date.now().getTime());
	// 过场任何一环抛错都不能把歌卡死
	try {
		introCutscene();
	} catch (e:Dynamic) {
		finishCutscene();
	}
	return '##PSYCHLUA_FUNCTIONSTOP';
}

function onUpdate(elapsed) {
	var p = ps();
	if (p == null) return;

	// 对手侧 strumline 只隐藏一次
	if (!strumsHidden && p.opponentStrums != null) {
		strumsHidden = true;
		for (a in p.opponentStrums.members) a.visible = false;
	}

	// 这舞台不要评级弹窗：整组隐藏即可
	if (!popupsOff) {
		popupsOff = true;
		try {
			if (p.comboGroup != null) p.comboGroup.visible = false;
		} catch (e:Dynamic) {}
	}

	// 过场开场：第一帧画出来就立刻取景
	if (!cutFitted && cutsceneSprite != null && cutsceneSprite.visible && cutsceneSprite.width > 0) {
		cutFitted = true;
		try {
			fitAnimateCenter(cutsceneSprite, CUT_FIT_X, CUT_FIT_Y + CUT_SCENE_SHIFT_Y / CUTSCENE_ZOOM_IN);
		} catch (e:Dynamic) {}
	}

	if (floorSpr != null) updateFloorSkew(p.camGame);
	updateDoorFrame();
	updateLipsync();

	// 过场跳过
	if (cutsceneActive && !cutsceneSkipped && p.controls != null && p.controls.ACCEPT) {
		if (canSkipCutscene) skipCutscene();
		else canSkipCutscene = true;
	}

	// 根时间轴播完会循环回躺姿，播到 getup 末帧就定格（@650 记下的 gfStopFrame/bfStopFrame）
	if (sserafimGf != null && gfStopFrame >= 0) {
		try {
			if (sserafimGf.anim.isPlaying && sserafimGf.anim.curFrame >= gfStopFrame) {
				sserafimGf.anim.curFrame = gfStopFrame;
				sserafimGf.anim.pause();
				gfStopFrame = -1;
			}
		} catch (e:Dynamic) {}
	}
	if (sserafimBf != null && bfStopFrame >= 0) {
		try {
			if (sserafimBf.anim.isPlaying && sserafimBf.anim.curFrame >= bfStopFrame) {
				sserafimBf.anim.curFrame = bfStopFrame;
				sserafimBf.anim.pause();
				bfStopFrame = -1;
			}
		} catch (e:Dynamic) {}
	}
}
