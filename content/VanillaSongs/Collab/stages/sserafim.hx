// LE SSERAFIM collab stage for FrozenEngine.
// Port of VS preload/scripts/stages/sserafim.hxc (+ SserafimCutscene/Bf/Gf/LipSync props,
// PerspectiveSprite). Iris HScript: no class declarations, everything is plain functions.
//
// Static props come from shared/stages/sserafim.json (bg / tables / stools / truck / lights /
// frontStool) and are looked up through PlayState.variables. Everything dynamic lives here:
// SserafimShader tinting, dust, perspective floor, the 3 extra girls, cutscene, kick sequence,
// pulse lights and the SEEYOU ending.

import flixel.addons.display.FlxBackdrop;
import flixel.addons.effects.FlxSkewedSprite;
import flixel.util.FlxColor;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import Date;

// ---- shaders (runtime-loaded GLSL) ----
var characterShader = null;
var stageShader = null;

// ---- extra girls ----
var yunjin = null;
var chaewon = null;
var eunchae = null;

// ---- visibility / singing state (index order = VS event arrays) ----
// 0 yunjin / 1 kazuha(dad) / 2 chaewon / 3 eunchae / 4 sakura(bf) / 5 gf
var baseVisible = [true, false, false, false, false];
var girlsVisible = [true, false, false, false, false];
var girlsSinging = [false, false, false, false, false];
var girlHold = [0, 0, 0, 0, 0];
var gfBeautiful = false;
var gfDanceFlip = false;

// ---- stage bits ----
var dust1 = null; var dust2 = null; var dust3 = null; var dust4 = null;
var solidCover = null;
var floorSpr = null;
var floorBottomX = 760.0; var floorBottomY = 1375.0;
var floorTopX = 790.0; var floorTopY = 625.0;

// ---- cutscene ----
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
var yunjinDance = false;
var doorFrameHooked = false;

// ---- pulse lights ----
var lightsEnabled = false;
var lightsColors = [];
var lightsDurations = [];
var lightsIntensities = [];

// ---- lipsync（原版 SserafimLipSyncSprite + 角色脚本注入的近似移植）----
// VS 把嘴部精灵注入图集 "mouth default" 帧；FE 侧用独立 FlxAnimate 叠加。
// 嘴部图集与身体图集同一 FLA 坐标系导出 → 与角色同位置/同缩放摆放即可对齐（小偏差实机微调）。
// VS: shouldSing = characterType == BF（轮唱到谁谁张嘴）；不唱停在 frame 0（闭嘴）。
// 顺序同 girlsVisible：0 yunjin / 1 kazuha(dad) / 2 chaewon / 3 eunchae / 4 sakura(bf)。gf 原版没有嘴型。
var lipsyncs = [null, null, null, null, null];
var lipsyncAtlas = ['sserafim-lipsync-yunjin', 'sserafim-lipsync', 'sserafim-lipsync', 'sserafim-lipsync', 'sserafim-lipsync'];
var lipsyncFlip = [false, true, false, false, true];

function addLipsync(i, char) {
	var ls = new FlxAnimate(0, 0);
	Paths.loadAnimateAtlas(ls, lipsyncAtlas[i]);
	ls.scrollFactor.set(char.scrollFactor.x, char.scrollFactor.y);
	ls.flipX = lipsyncFlip[i];
	ls.shader = characterShader;
	ls.visible = char.visible;
	try { ls.anim.play(); } catch (e:Dynamic) {}
	var p = ps();
	p.insert(indexBehindFrontStool(), ls);
	return ls;
}

function updateLipsync() {
	var girls = [yunjin, ps().dad, chaewon, eunchae, ps().boyfriend];
	var frame = 0;
	if (Conductor != null && Conductor.songPosition > 0) frame = Math.floor((Conductor.songPosition / 1000) * 24);
	for (i in 0...5) {
		var ls = lipsyncs[i];
		var c = girls[i];
		if (ls == null) continue;
		if (c == null) { ls.visible = false; continue; }
		ls.visible = c.visible;
		ls.setPosition(c.x, c.y);
		ls.scale.set(c.scale.x, c.scale.y);
		ls.scrollFactor.set(c.scrollFactor.x, c.scrollFactor.y);
		// VS: 唱的时候帧号跟歌曲位置走（24fps），不唱回第 0 帧（闭嘴）
		var target = 0;
		if (girlsSinging[i] && frame > 0) {
			var len = 0;
			try { len = ls.anim.length; } catch (e:Dynamic) { len = 0; }
			if (len > 0) target = frame % len;
		}
		try { ls.anim.curFrame = target; } catch (e:Dynamic) {}
	}
}

// ---- props from stage json ----
var props = null;

// 对手侧 strumline 只隐藏一次（Iris：函数里引用不到定义在函数之后的顶层变量，必须放前面）
var strumsHidden = false;

function ps() return PlayState.instance;

// FlxAnimate symbol playback; symbol names differ per atlas, so fail soft
function tryAnim(spr, name) {
	if (spr == null || spr.anim == null) return;
	try { spr.anim.play(name, true); } catch (e:Dynamic) { try { spr.anim.play(); } catch (e2:Dynamic) {} }
}

function getProp(name) {
	if (props == null) return null;
	return props.get(name);
}

// ============================ shader helpers ============================

function newShader(isChar) {
	var src = Paths.getTextFromFile('shaders/sserafim.frag');
	if (src == null || src.length < 1) {
		// getTextFromFile 的内容包回退未必命中 shaders/ —— 直接读内容包磁盘
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

function darkenTween(amt, dur) {
	var proxy = { amt: currentDark() };
	FlxTween.tween(proxy, { amt: amt }, dur, { ease: FlxEase.sineInOut, onUpdate: function(tw) { setBothDark(proxy.amt); } });
}

function currentDark() {
	if (stageShader == null) return 0;
	return stageShader.getFloat('darkAmt');
}

// ============================ camera helpers ============================

var camZoomTween = null;
var camPosTween = null;
var forcedCamera = false;

function camZoomTo(target, dur, ?ease) {
	var p = ps();
	if (camZoomTween != null) camZoomTween.cancel();
	if (dur <= 0) {
		camZoomTween = null;
		p.defaultCamZoom = target;
		p.camGame.zoom = target;
		return;
	}
	camZoomTween = FlxTween.tween(p, { defaultCamZoom: target }, dur, { ease: ease == null ? FlxEase.linear : ease,
		onUpdate: function(tw) { if (ps() != null && !ps().camZooming) ps().camGame.zoom = ps().defaultCamZoom; } });
}

// VS world coords -> FE camera target (camFollow is followed instantly, followLerp = 0)
function camPosTo(x, y, dur, ?ease) {
	var p = ps();
	if (camPosTween != null) camPosTween.cancel();
	forcedCamera = true;
	Reflect.setProperty(p, 'isCameraOnForcedPos', true);
	if (dur <= 0) {
		camPosTween = null;
		p.camFollow.setPosition(x, y);
		return;
	}
	camPosTween = FlxTween.tween(p.camFollow, { x: x, y: y }, dur, { ease: ease == null ? FlxEase.linear : ease });
}

// ============================ look helpers ============================

// VS resetClear() - the "night after the crash" gameplay look
function resetLook() {
	// shader 可能加载失败（frag 路径/运行时问题）为 null —— FlxTween.cancelTweensOf(null) 会抛错
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
		yunjinDance = false;
	}
	if (getProp('truckDoor') != null) getProp('truckDoor').visible = false;
	lightsEnabled = false;
}

function resetDust() {
	if (dust1 == null) return;
	var ds = [dust1, dust2, dust3, dust4];
	var pos = [[-650, -400], [-650, -450], [-650, -600], [-650, -1500]];
	var vel = [350, -300, -200, -150];
	for (i in 0...ds.length) {
		var d = ds[i];
		FlxTween.cancelTweensOf(d);
		FlxTween.cancelTweensOf(d.velocity);
		d.setPosition(pos[i][0], pos[i][1]);
		d.velocity.x = vel[i];
		d.alpha = 1;
	}
}

function startClear() {
	var proxy = { b: 55, h: 6, c: -26, s: -74 };
	FlxTween.tween(proxy, { b: 0, h: 0, c: 0, s: 0 }, 24, { ease: FlxEase.sineOut,
		onUpdate: function(tw) { setBothAdjust(proxy.b, proxy.h, proxy.c, proxy.s); } });

	if (dust1 != null) {
		var alphas = [dust1.alpha, dust2.alpha, dust3.alpha, dust4.alpha];
		var ys = [dust1.y + 100, dust2.y + 200, dust3.y + 150, dust4.y + 100];
		var ds = [dust1, dust2, dust3, dust4];
		var durs = [20, 16, 24, 16];
		for (i in 0...ds.length) {
			FlxTween.tween(ds[i], { alpha: 0, y: ys[i] }, durs[i], { ease: FlxEase.sineOut });
			FlxTween.tween(ds[i].velocity, { x: 0 }, durs[i], { ease: FlxEase.sineOut });
		}
	}
}

// ============================ girls ============================

function addGirl(id, x, y, scrollF) {
	var c = new Character(0, 0, id, false);
	c.setPosition(x, y);
	c.scrollFactor.set(scrollF, scrollF);
	c.shader = characterShader;
	return c;
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

function girlSing(dirName, isPlayerSide) {
	// VS: only "singing" girls react, and only to the player's notes.
	if (!isPlayerSide) return;
	var girls = [yunjin, ps().dad, chaewon, eunchae, ps().boyfriend];
	for (i in 0...girls.length) {
		if (girls[i] == null || !girlsSinging[i]) continue;
		if (girlHold[i] > 8) continue;
		girls[i].playAnim('sing' + dirName, true);
		girlHold[i] = 4;
	}
}

// ============================ lifecycle ============================

function onCreatePost() {
	var p = ps();
	if (p == null) return;

	props = p.variables;

	characterShader = newShader(true);
	stageShader = newShader(false);

	// --- perspective floor (port of PerspectiveSprite) ---
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
	if (floorSpr != null) insertBehindCharacters(floorSpr);

	// --- extra girls ---
	if (yunjin == null) {
		yunjin = addGirl('sserafim-yunjin', -621, 154, 0.95);
		chaewon = addGirl('sserafim-chaewon', 687, 98, 0.95);
		eunchae = addGirl('sserafim-eunchae', 770, 675, 0.97);
		// VS keeps the girls above dad/bf (zIndex 1000) but below frontStool (1500)
		var idx = indexBehindFrontStool();
		p.insert(idx, yunjin);
		p.insert(idx + 1, chaewon);
		p.insert(idx + 2, eunchae);
	}
	if (p.dad != null) p.dad.shader = characterShader;
	if (p.boyfriend != null) p.boyfriend.shader = characterShader;
	if (p.gf != null) p.gf.shader = characterShader;

	// --- lipsync mouths（dad 槽 = kazuha、bf 槽 = sakura、外加三名背景女孩；gf 原版没有嘴型）---
	if (lipsyncs[0] == null) {
		var girlsArr = [yunjin, p.dad, chaewon, eunchae, p.boyfriend];
		for (i in 0...5) {
			if (girlsArr[i] != null) lipsyncs[i] = addLipsync(i, girlsArr[i]);
		}
	}
	for (key in ['bg', 'backTables', 'backStools', 'truck', 'truckDoor', 'truckLight1', 'truckLight2', 'backLightColor', 'backLightWhite', 'frontStool']) {
		var spr = getProp(key);
		if (spr != null) spr.shader = stageShader;
	}

	// --- dust backdrops (zIndex 2000: above everything except cover) ---
	if (dust1 == null) {
		dust1 = new FlxBackdrop(Paths.image('dust/dustMid'), 0x01);
		dust2 = new FlxBackdrop(Paths.image('dust/dustBack'), 0x01);
		dust3 = new FlxBackdrop(Paths.image('dust/dustMid'), 0x01);
		dust4 = new FlxBackdrop(Paths.image('dust/dustBack'), 0x01);
		var ds = [dust1, dust2, dust3, dust4];
		var pos = [[-650, -400], [-650, -450], [-650, -600], [-650, -1500]];
		var scrolls = [1.1, 1.15, 1.2, 1.25];
		var scales = [1.5, 1.5, 2, 3.5];
		var vels = [350, -300, -200, -150];
		var cols = [0xff98847d, 0xff8b6c63, 0xff6e645c, 0xff886a60];
		for (i in 0...ds.length) {
			var d = ds[i];
			d.setPosition(pos[i][0], pos[i][1]);
			d.scrollFactor.set(scrolls[i], scrolls[i]);
			d.scale.set(scales[i], scales[i]);
			d.velocity.x = vels[i];
			d.alpha = 0.85;
			d.color = cols[i];
			d.shader = stageShader;
			p.add(d);
		}
	}

	// --- solid black cover (zIndex 9999: topmost on camGame) ---
	if (solidCover == null) {
		solidCover = new FlxSprite(-5000, -3000).makeGraphic(10000, 10000, 0xFF000000);
		solidCover.scrollFactor.set(0, 0);
		solidCover.alpha = 0;
		p.add(solidCover);
	}

	// --- cutscene sprites ---
	if (cutsceneSprite == null) {
		cutsceneSprite = new FlxAnimate(0, 0);
		Paths.loadAnimateAtlas(cutsceneSprite, 'cutscene/cutsceneMain');
		cutsceneSprite.setPosition(-395, 10);
		cutsceneSprite.scrollFactor.set(0.94, 0.94);
		cutsceneSprite.shader = characterShader;
		cutsceneSprite.visible = false;

		sserafimGf = new FlxAnimate(0, 0);
		Paths.loadAnimateAtlas(sserafimGf, 'cutscene/gfGetUp');
		sserafimGf.setPosition(655, -104);
		sserafimGf.scrollFactor.set(0.95, 0.95);
		sserafimGf.shader = characterShader;
		sserafimGf.alpha = 0.5;
		sserafimGf.visible = false;

		sserafimBf = new FlxAnimate(0, 0);
		Paths.loadAnimateAtlas(sserafimBf, 'cutscene/bfGetUp');
		sserafimBf.setPosition(1220, 531);
		sserafimBf.scrollFactor.set(0.99, 0.99);
		sserafimBf.shader = characterShader;
		sserafimBf.visible = false;

		// cutscene props sit below frontStool (VS zIndex 25)
		var idx2 = indexBehindFrontStool();
		p.insert(idx2, sserafimGf);
		p.insert(idx2 + 1, sserafimBf);
		p.insert(idx2 + 2, cutsceneSprite);

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
	}

	// --- initial state ---
	setGirlsVisible(baseVisible);
	setGirlsSinging(girlsSinging);
	if (p.iconP2 != null) p.iconP2.visible = false;
	lightsEnabled = false;

	// retry within 2 minutes of a previous attempt skips the full cutscene
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

function insertBehindCharacters(spr) {
	var p = ps();
	var gfGroup = p.gfGroup;
	var idx = 0;
	if (gfGroup != null) {
		for (i in 0...p.members.length) {
			if (p.members[i] == gfGroup) { idx = i; break; }
		}
	}
	p.insert(idx, spr);
}

// ============================ countdown / cutscene ============================

function onStartCountdown() {
	var p = ps();
	if (hasPlayedCutscene) return;

	// play the intro cutscene instead of the countdown
	hasPlayedCutscene = true;
	cutsceneActive = true;
	cutsceneSkipped = false;
	canSkipCutscene = false;
	setVar('sserafim_cutscene_at', Date.now().getTime());
	// 过场任何一环抛错都不能把歌卡死 —— 兜底直接开唱
	try { introCutscene(); } catch (e:Dynamic) { finishCutscene(); }
	return '##PSYCHLUA_FUNCTIONSTOP';
}

function introCutscene() {
	var p = ps();
	p.inCutscene = true;
	p.camHUD.visible = false;

	setCutsceneVisibility(true);
	resetLook();
	setBothAdjust(0, 0, 0, 0);

	// skip hint（不用 FlxTextAlign/FlxTextBorderStyle 名字 —— enum 解析不进 hscript 作用域，用字符串属性）
	skipText = new FlxText(936, 618, 0, 'Skip [ ENTER ]', 20);
	skipText.setFormat(Paths.font('vcr.ttf'), 40, 0xFFFFFFFF);
	skipText.alignment = 'right';
	skipText.borderStyle = 'outline';
	skipText.borderSize = 2;
	skipText.borderColor = 0xFF000000;
	skipText.scrollFactor.set(0, 0);
	skipText.borderSize = 2;
	skipText.alpha = 0;
	skipText.cameras = [p.camOther];
	p.add(skipText);
	FlxTween.tween(skipText, { alpha: 1 }, 0.5, { ease: FlxEase.quadOut });

	// camera intro (VS zooms 0.5 -> 0.7; FE ratio 0.9)
	camZoomTo(0.45, 0);
	camPosTo(660, -200, 0);
	p.camGame.fade(0xFF000000, 3, true, null, true);
	camZoomTo(0.63, 3, FlxEase.circOut);
	camPosTo(660, 300, 3, FlxEase.circOut);

	cutsceneSprite.visible = true;
	tryAnim(cutsceneSprite, '');

	new FlxTimer().start(20 / 24, function(tmr) {
		cutsceneSound = FlxG.sound.play(Paths.sound('cutscene/startCutscene'), 1.0);
	});

	// gf taps herself
	new FlxTimer().start(245 / 24, function(tmr) { darkenTween(0.2, 0.01); });
	new FlxTimer().start(251 / 24, function(tmr) { darkenTween(0, 0.8); });

	// gf taps bf
	new FlxTimer().start(406 / 24, function(tmr) { darkenTween(0.2, 0.01); });
	new FlxTimer().start(411 / 24, function(tmr) { darkenTween(0, 0.8); });

	// truck gets closer - cool the colors down
	new FlxTimer().start(499 / 24, function(tmr) {
		endSkip();
		var proxy = { b: 0, h: 0, c: 0, s: 0 };
		FlxTween.tween(proxy, { b: 55, h: 0, c: -30, s: 0 }, 49 / 24, { ease: FlxEase.sineOut,
			onUpdate: function(tw) { setBothAdjust(proxy.b, proxy.h, proxy.c, proxy.s); } });
	});

	// truck really close
	new FlxTimer().start(548 / 24, function(tmr) {
		FlxTween.cancelTweensOf(stageShader);
		FlxTween.cancelTweensOf(characterShader);
		var proxy = { b: 55, h: 0, c: -30, s: 0 };
		FlxTween.tween(proxy, { b: 66, h: 10, c: -17, s: 0 }, 15 / 24, { ease: FlxEase.expoIn,
			onUpdate: function(tw) { setBothAdjust(proxy.b, proxy.h, proxy.c, proxy.s); } });
	});

	// crash + flash
	new FlxTimer().start(563 / 24, function(tmr) {
		FlxTween.cancelTweensOf(stageShader);
		FlxTween.cancelTweensOf(characterShader);
		setBothAdjust(0, 0, 0, 0);
		p.camGame.fade(0xFFFFFFFF, 30 / 24, true, null, true);
		if (solidCover != null) solidCover.alpha = 1;
		setCutsceneVisibility(false);
	});

	// fade out from black, show bf/gf on the ground
	new FlxTimer().start(650 / 24, function(tmr) {
		camZoomTo(0.63, 0);
		camZoomTo(0.495, 3, FlxEase.circOut);
		camPosTo(1070, 470, 0);

		resetLook();
		FlxTween.tween(solidCover, { alpha: 0 }, 3, { ease: FlxEase.sineOut });

		sserafimGf.visible = true;
		sserafimBf.visible = true;
		tryAnim(sserafimGf, 'static');
		tryAnim(sserafimBf, 'static');
	});

	new FlxTimer().start(710 / 24, function(tmr) {
		tryAnim(sserafimGf, 'getup');
		tryAnim(sserafimBf, 'getup');
	});

	// actually start the song
	new FlxTimer().start(730 / 24, function(tmr) { finishCutscene(); });
}

function finishCutscene() {
	var p = ps();
	cutsceneActive = false;
	cutsceneSkipped = true;
	p.inCutscene = false;
	p.camHUD.visible = true;
	if (skipText != null) { skipText.visible = false; }
	if (!p.chartingMode) p.startCountdown();
}

function endSkip() {
	if (skipText != null) {
		FlxTween.tween(skipText, { alpha: 0 }, 0.5, { ease: FlxEase.quadIn });
	}
	cutsceneSkipped = true;
}

function setCutsceneVisibility(inCutscene) {
	setGirlsVisible(inCutscene ? [false, false, false, false, false] : baseVisible);
	if (getProp('truck') != null) getProp('truck').visible = !inCutscene;
	if (getProp('truckDoor') != null) getProp('truckDoor').visible = false;
	if (getProp('backTables') != null) getProp('backTables').visible = !inCutscene;
	if (getProp('backStools') != null) getProp('backStools').visible = !inCutscene;
	if (getProp('frontStool') != null) getProp('frontStool').visible = !inCutscene;
	if (dust1 != null) {
		dust1.visible = !inCutscene; dust2.visible = !inCutscene;
		dust3.visible = !inCutscene; dust4.visible = !inCutscene;
	}
	if (floorSpr != null) {
		var img = Paths.image(inCutscene ? 'cutscene/floor-cutscene' : 'floor');
		if (img != null) floorSpr.loadGraphic(img);
	}
	if (ps().gf != null) ps().gf.visible = false;
	if (cutsceneSprite != null) cutsceneSprite.visible = inCutscene;
}

// restart path (death retry / charting): show the aftermath directly
function playCutsceneFromRestart() {
	var p = ps();
	cutsceneActive = false;
	cutsceneSkipped = true;
	hasPlayedCutscene = true;
	p.inCutscene = false;

	resetLook();

	camZoomTo(0.495, 1, FlxEase.circOut);
	camPosTo(1070, 470, 1, FlxEase.circOut);

	if (sserafimGf != null) { sserafimGf.visible = true; tryAnim(sserafimGf, 'getup'); }
	if (sserafimBf != null) { sserafimBf.visible = true; tryAnim(sserafimBf, 'getup'); }
}

function onUpdate(elapsed) {
	var p = ps();
	if (p == null) return;

	// hide opponent strumline once (VS aesthetic for this song)
	if (!strumsHidden && p.opponentStrums != null) {
		strumsHidden = true;
		for (a in p.opponentStrums.members) a.visible = false;
	}

	if (floorSpr != null) updateFloorSkew(p.camGame);

	updateLipsync();

	if (cutsceneActive && !cutsceneSkipped && p.controls != null && p.controls.ACCEPT) {
		if (canSkipCutscene) skipCutscene();
		else canSkipCutscene = true;
	}
}

function skipCutscene() {
	var p = ps();
	cutsceneActive = false;
	cutsceneSkipped = true;
	if (cutsceneSound != null) cutsceneSound.stop();
	p.camGame.fade(0xFF000000, 0.25, false, null, true);
	new FlxTimer().start(0.3, function(tmr) {
		p.camGame.fade(0xFF000000, 0.4, true, null, true);
		playCutsceneFromRestart();
		// show the aftermath state briefly then start the song
		new FlxTimer().start(0.5, function(tmr2) { finishCutscene(); });
	});
}

// ============================ perspective floor ============================

function updateFloorSkew(cam) {
	if (floorSpr == null || floorSpr.graphic == null) return;
	// VS: bottom scroll 1.05, top scroll 0.93; sprite scrollFactor 0.93
	var botX = floorBottomX - cam.scroll.x * 0.12;
	var botY = floorBottomY - cam.scroll.y * 0.12;
	var topX = floorTopX;
	var topY = floorTopY;
	var h = floorSpr.frameHeight > 0 ? floorSpr.frameHeight : floorSpr.height;
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

// ============================ events ============================

function onEvent(name, v1, v2, strumTime) {
	var p = ps();
	if (p == null) return;
	var params = null;
	try { params = Json.parse(v1); } catch (e:Dynamic) { params = null; }

	switch (name) {
		case 'sserafimShow':
			setGirlsVisible(params != null ? params.visible : null);
		case 'sserafimSing':
			setGirlsSinging(params != null ? params.singing : null);
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
			// haptics only
		case 'SetHealthIcon':
			if (params != null && p.iconP2 != null) {
				p.iconP2.changeIcon(params.id);
				p.iconP2.visible = true;
			}
		case 'ZoomCamera':
			if (params == null) return;
			var zoom = params.zoom;
			if (zoom == null) return;
			var target = (params.mode == 'stage') ? zoom * p.defaultCamZoom : zoom * 0.9;
			var ease = vsEase(params.ease, params.easeDir);
			camZoomTo(target, vsDuration(params.duration), ease);
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
	// at frame 23 of kick2 the door is gone from her atlas - show the static one
	yunjin.animation.onFrameChange.add(function(animName, frameNumber, index) {
		if (frameNumber == 23 && getProp('truckDoor') != null) getProp('truckDoor').visible = true;
	});
}

// ============================ beats / notes ============================

function onBeatHit() {
	var p = ps();
	if (p == null) return;
	var beat = p.curBeat;

	// pulse lights behind the truck
	if (lightsEnabled && lightsIntensities.length > 0) {
		var i = beat % lightsIntensities.length;
		var col = FlxColor.fromString(lightsColors[i % lightsColors.length]);
		flashBackLight(lightsIntensities[i], lightsDurations[i % lightsDurations.length], col);
	}

	// extra girls idle dance every 2 beats (VS danceEvery = 2)
	if (beat % 2 == 0) {
		for (i in 0...5) girlHold[i] = girlHold[i] - 1;
		if (chaewon != null && chaewon.visible && !girlsSinging[2] && girlHold[2] <= 0) chaewon.playAnim('idle');
		if (eunchae != null && eunchae.visible && !girlsSinging[3] && girlHold[3] <= 0) eunchae.playAnim('idle');
		if (yunjin != null && yunjin.visible && yunjinDance && !girlsSinging[0] && girlHold[0] <= 0) yunjin.playAnim('idle');
	}

	// beautiful gf dance override
	if (gfBeautiful && p.gf != null) {
		gfDanceFlip = !gfDanceFlip;
		p.gf.playAnim(gfDanceFlip ? 'danceLeft-beautiful' : 'danceRight-beautiful', true);
	}
}

function goodNoteHit(note) {
	if (note == null || note.isSustainNote) return;
	var dir = ['LEFT', 'DOWN', 'UP', 'RIGHT'][note.noteData % 4];
	girlSing(dir, true);
	if (!girlsSinging[4] && ps().boyfriend != null) ps().boyfriend.playAnim('idle', true);
}

function opponentNoteHit(note) {
	if (note == null || note.isSustainNote) return;
	// nobody sings on the opponent side in this arrangement (VS characterType logic)
	if (ps().dad != null && !girlsSinging[1]) ps().dad.playAnim('idle', true);
}

// ============================ ending ============================

function endStuff() {
	var p = ps();
	FlxG.sound.play(Paths.sound('cutscene/end1'), 1.0);

	new FlxTimer().start(0.05, function(tmr) {
		if (SEEYOU1 != null) SEEYOU1.visible = true;
		if (solidCover != null) solidCover.alpha = 1;
		p.camHUD.visible = false;
		p.inCutscene = true;
	});

	new FlxTimer().start(4, function(tmr) {
		if (SEEYOU1 != null) SEEYOU1.visible = false;
		if (SEEYOU2 != null) SEEYOU2.visible = true;
		FlxG.sound.play(Paths.sound('cutscene/end2'), 1.0);
	});

	new FlxTimer().start(8, function(tmr) {
		if (SEEYOU1 != null) SEEYOU1.visible = false;
		if (SEEYOU2 != null) SEEYOU2.visible = false;
	});

	new FlxTimer().start(9, function(tmr) {
		p.inCutscene = false;
		removeVar('sserafim_cutscene_at');
		p.endSong();
	});
}

// keep pause blocked while a scripted sequence is running
function onPause() {
	if (cutsceneActive || (ps() != null && ps().inCutscene)) return '##PSYCHLUA_FUNCTIONSTOP';
}
