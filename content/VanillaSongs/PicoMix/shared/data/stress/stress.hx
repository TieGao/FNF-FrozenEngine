// ============================================================================
//  stress-pico 演出脚本（官方 stress-pico.hxc 移植）
//  位于 content/VanillaSongs/PicoMix/shared/data/stress/（per-song 加载）
//  开场视频（全模式，官方语义）+ SetHealthIcon/EnableMask/保护窗 + 结尾过场 + 字幕
//  redhead 后 sing/idle 强制血皮：剥掉谱面残留的 -alt 后缀，tankman 换 -bloody（官方 isBloody 重映射）
// ============================================================================

import sys.FileSystem;
import Date;

// ---- 保护窗时长表（ms）：redheadsAnim/knifeToss/hehPrettyGood 实机校准后改这里 ----
function animDur(name:String) {
	switch (name) {
		case 'redheadsAnim': return 3200;
		case 'knifeToss': return 3500;
		case 'hehPrettyGood': return 2130;
		case 'hehPrettyGood-bloody': return 2130;
	}
	return null;
}

// ---- 结尾过场时序（官方 stress-pico.hxc，秒 = 帧/24） ----
var T_LAUGH = 176 / 24;
var T_PULLBACK = 270 / 24;
var T_FINISH = 320 / 24;

var endCutActive:Bool = false;
var hasPlayedEnd:Bool = false;
var endGen = 0;
var endTimers = [];
var animWindows = [];
var maskLoaded:Bool = false;
var maskFailed:Bool = false;
var isBloody:Bool = false;   // redhead 动画后换血皮（官方 tankman-bloody.hxc 的动画名重映射）

var cutElapsed:Float = 0;
var blackBg:FlxSprite = null;
var subText:FlxText = null;
var subCam:FlxCamera = null;
var dadFocus = [0.0, 0.0];

// 官方 end-cutscene-pico.srt（文本 + 起止秒）
var SUBS = [
	{t0: 0.56, t1: 2.76, text: 'Singing that was cool and all but...'},
	{t0: 3.44, t1: 5.36, text: 'I just wanna let you know that was...'},
	{t0: 5.56, t1: 6.90, text: 'Insanely painful.'},
	{t0: 10.44, t1: 11.58, text: 'Assholes.'}
];

var camPosTween = null;
var camZoomTween = null;

function ps() return PlayState.instance;

function onCreatePost(?e) {
	var p = ps();
	if (p == null) return;
	animWindows = [];
	endCutActive = false;
	isBloody = false;

	// 分尸图动画逐帧预热：FlxAnimate 每一帧都要现场构建符号实例树（FlxAnim.update 里
	// 无条件走 updateRender），不预热的话 redhead 换皮 / 结尾笑 正式播放时会逐帧掉帧。
	var dad = p.dad;
	if (dad != null) {
		sweepAnim(dad, 'redheadsAnim');
		sweepAnim(dad, 'idle-bloody');
		sweepAnim(dad, 'hehPrettyGood-bloody');
		if (dad.hasAnimation('idle')) dad.playAnim('idle', true);
	}
	sweepAnim(p.boyfriend, 'knifeToss');
}

function sweepAnim(ch, name) {
	if (ch == null || !ch.hasAnimation(name)) return;
	try {
		ch.playAnim(name, true);
		var atlas = ch.atlas;
		if (atlas == null || atlas.anim == null) return;
		var len:Int = atlas.anim.length;
		for (i in 0...len) {
			atlas.anim.curFrame = i;
			atlas.update(0);
		}
	} catch (e:Dynamic) {}
}

// ---------------------------------------------------------------------------
// 开场视频：stress-pico 官方连 Freeplay 都播（stress-pico.hxc 不判 isStoryMode）
// ---------------------------------------------------------------------------
function onStartCountdown() {
	var p = ps();
	if (p == null || p.chartingMode) return;

	var lastAt = getVar('stressPicoCutscene_at');
	if (lastAt != null && (Date.now().getTime() - lastAt) < 120000) return;

	var file = Paths.video('stressPicoCutscene');
	if (!FileSystem.exists(file)) {
		debugPrint('week7p: video missing: ' + file);
		return;
	}

	setVar('stressPicoCutscene_at', Date.now().getTime());
	p.startVideo('stressPicoCutscene', false, true);
	return '##PSYCHLUA_FUNCTIONSTOP';
}

// ---------------------------------------------------------------------------
// 结尾过场（官方 onSongEnd：全模式播一次）
// ---------------------------------------------------------------------------
function onEndSong() {
	var p = ps();
	if (hasPlayedEnd) return;
	hasPlayedEnd = true;

	endCutActive = true;
	endGen = endGen + 1;
	cutElapsed = 0;

	p.inCutscene = true;
	p.canPause = false;
	p.camHUD.visible = false;
	p.camZooming = false;

	// tankman 相机焦点（PlayState.moveCamera(isDad=true) 同款公式）
	var mid = p.dad.getMidpoint();
	var fx = mid.x + 150 + p.dad.cameraPosition[0] + p.opponentCameraOffset[0];
	var fy = mid.y - 100 + p.dad.cameraPosition[1] + p.opponentCameraOffset[1];
	dadFocus = [fx, fy];

	camPosTo(fx + 320, fy - 70, 2.8, FlxEase.expoOut);
	camZoomTo(0.65, 2.0, FlxEase.expoOut);

	p.dad.playAnim('stressPicoEnding', true);   // 304 帧 ≈ 12.7s
	FlxG.sound.play(Paths.sound('erect/endCutscene'), 1.0);

	buildSubtitles();

	endTime(T_LAUGH, function(t) {
		if (p.boyfriend != null) p.boyfriend.playAnim('laughEnd', true);
	});
	endTime(T_PULLBACK, function(t) {
		camPosTo(dadFocus[0] + 320, dadFocus[1] - 370, 2, FlxEase.quadInOut);
		if (blackBg != null) FlxTween.tween(blackBg, {alpha: 1}, 2);
	});
	endTime(T_FINISH, function(t) {
		finishEndCutscene();
	});
	return '##PSYCHLUA_FUNCTIONSTOP';
}

function finishEndCutscene() {
	var p = ps();
	endCutActive = false;
	killEndTimers();
	destroySubtitles();
	if (blackBg != null) { p.remove(blackBg, true); blackBg = null; }
	if (camPosTween != null) { try { camPosTween.cancel(); } catch (e:Dynamic) {} camPosTween = null; }
	if (camZoomTween != null) { try { camZoomTween.cancel(); } catch (e:Dynamic) {} camZoomTween = null; }

	p.health = 2;
	p.inCutscene = false;
	p.canPause = true;
	p.camHUD.visible = true;
	p.endSong();
}

function onDestroy(?e) {
	endCutActive = false;
	killEndTimers();
	destroySubtitles();
	if (blackBg != null && ps() != null) { try { ps().remove(blackBg, true); } catch (e2:Dynamic) {} blackBg = null; }
}

// 过场期间禁暂停（sserafim 同款）
function onPause() {
	if (endCutActive) return '##PSYCHLUA_FUNCTIONSTOP';
}

// ---------------------------------------------------------------------------
// 事件
// ---------------------------------------------------------------------------
function onEvent(name, value1, value2, strumTime) {
	var p = ps();
	if (p == null) return;

	switch (name) {
		case 'SetHealthIcon':
			var params = null;
			try { params = parseJson(value1); } catch (e:Dynamic) {}
			if (params == null || params.id == null) return;
			var icon = (params.char == 0) ? p.iconP1 : p.iconP2;
			if (icon == null) return;
			try {
				icon.changeIcon(params.id);
				icon.visible = true;
			} catch (e:Dynamic) {}

		case 'EnableMask':
			enableMask();

		case 'Play Animation':
			var dur = animDur(value1);
			if (dur == null) return;
			var side = 'dad';
			var v2 = (value2 == null) ? '' : value2.toLowerCase();
			if (v2 == 'bf' || v2 == 'boyfriend') side = 'bf';
			else if (v2 == 'gf' || v2 == 'girlfriend') side = 'gf';
			animWindows.push({side: side, t0: strumTime - 20, t1: strumTime + dur});
			if (value1 == 'redheadsAnim' && side == 'dad') isBloody = true;
	}
}

// EnableMask：官方 tankmanBattlefieldErect.hxc 的 bloody 蒙版（Erect 包 week7/images/erect/masks/）
function enableMask() {
	if (maskLoaded) { setMaskOn(); return; }
	if (maskFailed) return;
	var p = ps();
	if (p.dad == null || p.dad.shader == null) { maskFailed = true; return; }
	try {
		var sh = p.dad.shader;
		var g = Paths.image('erect/masks/tankmanCaptainBloody_mask');
		if (g == null || g.bitmap == null) { maskFailed = true; return; }
		sh.data.altMask.input = g.bitmap;
		sh.data.thr2.value = [1.0];
		maskLoaded = true;
		setMaskOn();
	} catch (e:Dynamic) {
		maskFailed = true;   // 最坏情况蒙版无效，不影响通关
	}
}

function setMaskOn() {
	try { ps().dad.shader.data.useMask.value = [1.0]; } catch (e:Dynamic) {}
}

// 防 sing 打断（sserafim Pre 钩子先例）+ noteType 后缀改写
function goodNoteHitPre(note) {
	guardNote(note, 'bf');
	rewriteSingSuffix(note, singTargetIsDad(note, true));
}

function opponentNoteHitPre(note) {
	guardNote(note, 'dad');
	rewriteSingSuffix(note, singTargetIsDad(note, false));
}

// 谱面残留的 Alt Animation note 没有对应 -alt 动画（官方谱面 kind 为空，转换器产物）：
// 目标是 tankman 且已过 redhead → 改写 -bloody；否则剥掉后缀回普通 sing（pico/gf 同样无 -alt）
function singTargetIsDad(note, fromGoodHit) {
	var p = ps();
	if (p == null) return false;
	if (fromGoodHit) return !note.gfNote && !note.mustPress;
	return p.opponentMode != 'opponent' && !note.gfNote;
}

function rewriteSingSuffix(note, isDadSide) {
	if (note == null || note.animSuffix != '-alt') return;
	if (isDadSide && isBloody) note.animSuffix = '-bloody';
	else note.animSuffix = '';
}

function guardNote(note, side) {
	if (note == null || animWindows.length == 0) return;
	var now = Conductor.songPosition;
	for (w in animWindows) {
		if (w.side == side && now >= w.t0 && now <= w.t1) {
			note.noAnimation = true;
			return;
		}
	}
}

// ---------------------------------------------------------------------------
// 逐帧
// ---------------------------------------------------------------------------
function onUpdate(elapsed) {
	var p = ps();
	if (p == null) return;

	// redhead 后血皮 idle（dance() 只会播干净 idle，逐帧兜底重映射；改写后动画名带 -bloody 不会重入）
	if (isBloody && !endCutActive && p.dad != null && p.dad.getAnimationName() == 'idle')
		p.dad.playAnim('idle-bloody', true);

	if (endCutActive) {
		cutElapsed = cutElapsed + elapsed;
		updateSubtitles();
		// pico 笑完接循环（laughEnd 有 -loop 后缀动画）
		var bf = p.boyfriend;
		if (bf != null && bf.animation != null && bf.animation.curAnim != null
			&& bf.animation.curAnim.name == 'laughEnd' && bf.animation.curAnim.finished) {
			bf.playAnim('laughEnd-loop', true);
		}
	}
}

// ---------------------------------------------------------------------------
// 相机 helper（sserafim 同款：tween 基准，避免和 bop 打架）
// ---------------------------------------------------------------------------
function camZoomTo(target, dur, ?ease) {
	var p = ps();
	if (camZoomTween != null) camZoomTween.cancel();
	if (dur <= 0) {
		camZoomTween = null;
		p.defaultCamZoom = target;
		p.camGame.zoom = target;
		return;
	}
	camZoomTween = FlxTween.tween(p, {defaultCamZoom: target}, dur, {
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
	camPosTween = FlxTween.tween(p.camFollow, {x: x, y: y}, dur, {ease: ease == null ? FlxEase.linear : ease});
}

// ---------------------------------------------------------------------------
// 结尾过场：定时器 / 黑幕 / 字幕
// ---------------------------------------------------------------------------
function endTime(sec, fn) {
	var owner = ps();
	var g = endGen;
	var tmr = new FlxTimer();
	endTimers.push(tmr);
	tmr.start(sec, function(t) {
		if (owner != ps()) return;
		if (g != endGen) return;
		if (!endCutActive) return;
		fn(t);
	});
}

function killEndTimers() {
	endGen = endGen + 1;
	var old = endTimers;
	endTimers = [];
	for (t in old) {
		if (t == null) continue;
		try { t.cancel(); } catch (e:Dynamic) {}
	}
}

function buildSubtitles() {
	var p = ps();
	// 黑幕：1x1 + setGraphicSize（绝不 makeGraphic 大尺寸）
	blackBg = new FlxSprite();
	blackBg.makeGraphic(1, 1, 0xFF000000);
	blackBg.setGraphicSize(4000, 4000);
	blackBg.updateHitbox();
	blackBg.scrollFactor.set(0, 0);
	blackBg.alpha = 0;
	p.add(blackBg);

	// 字幕独立相机（盖在黑幕/一切之上）
	subCam = new FlxCamera(0, 0, FlxG.width, FlxG.height);
	subCam.bgColor = 0;
	FlxG.cameras.add(subCam, false);

	subText = new FlxText(0, FlxG.height - 90, FlxG.width, '', 28);
	subText.alignment = 'center';
	subText.color = 0xFFFFFFFF;
	applyOutline(subText, 2);
	subText.scrollFactor.set(0, 0);
	subText.cameras = [subCam];
	subText.visible = false;
	p.add(subText);
}

function updateSubtitles() {
	if (subText == null) return;
	var show = null;
	for (s in SUBS) {
		if (cutElapsed >= s.t0 && cutElapsed <= s.t1) { show = s; break; }
	}
	if (show == null) { subText.visible = false; return; }
	if (subText.text != show.text) subText.text = show.text;
	subText.visible = true;
}

function destroySubtitles() {
	if (subText != null) {
		try { if (ps() != null) ps().remove(subText, true); } catch (e:Dynamic) {}
		try { subText.destroy(); } catch (e:Dynamic) {}
		subText = null;
	}
	if (subCam != null) {
		try { FlxG.cameras.remove(subCam); } catch (e:Dynamic) {}
		try { subCam.destroy(); } catch (e:Dynamic) {}
		subCam = null;
	}
}

// 文本描边（sserafim 同款：FlxTextBorderStyle 是真 enum，从 HUD 借构造好的值）
var outlineStyle = null;
var outlineStyleTried = false;

function getOutlineStyle() {
	if (outlineStyleTried) return outlineStyle;
	outlineStyleTried = true;
	var names = ['timeTxt', 'scoreTxt', 'botplayTxt'];
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

function applyOutline(t, size) {
	try {
		var st = getOutlineStyle();
		if (st != null) {
			t.borderStyle = st;
			t.borderSize = size;
			t.borderColor = 0xFF000000;
		}
	} catch (e:Dynamic) {}
}
