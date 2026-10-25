// ============================================================================
//  Sserafim 舞台调试工具（从 content/VanillaSongs/Collab/stages/sserafim.hx 抽出）
// ----------------------------------------------------------------------------
//  这是一份参考实现，平时不参与运行。需要排查问题时，把需要的函数整段
//  并回目标脚本（sserafim.hx）即可 —— 里面的 girlList / MOUTHS / lipsyncs /
//  characterShader / stageShader / getProp / floorSpr 都引用主脚本的顶层变量。
//
//  提供：
//    slog(msg)              落盘日志（crash/sserafim.log，release 下 trace 不落盘）
//    probeSprite(tag, spr)  精灵屏幕落点体检（画面外 or 没画）
//    dumpAnimate(tag, spr)  FlxAnimate 图集体检（wh=0 = 一帧都没画出来）
//    checkDebugKeys()       F2 嘴型标注 / F3 摘 shader / F4 性能日志
//    setShadersEnabled(on)  F3 的实体：批量挂/摘 character/stage shader
//    perf 探针              每 10s 记一次 fps + 最差单帧（onUpdate 里调用）
//
//  用法（并回主脚本后）：
//    onUpdate 开头加 checkDebugKeys() 和 perf 探针块；
//    在想体检的位置加 probeSprite / dumpAnimate 调用。
// ============================================================================

import sys.io.File;
import Date;

// ---- 开关 ----
var LOG_HOT = false;     // 逐音符 / 逐事件的日志（会开文件，默认关）
var shadersOff = false;  // F3 状态
var PERF_LOG = true;     // F4 开关
var perfAccum = 0.0;
var perfFrames = 0;
var perfWorst = 0.0;

// F2 嘴型标注状态
var MOUTH_DEBUG = false;
var mouthLabels = null;

// ----------------------------------------------------------------------------
//  落盘日志
// ----------------------------------------------------------------------------
function slog(msg) {
	try {
		var f = File.append('crash/sserafim.log', false);
		f.writeString(Date.now().toString() + ' ' + msg + '\n');
		f.close();
	} catch (e:Dynamic) {
		try { trace('[sserafim] ' + msg); } catch (e2:Dynamic) {}
	}
}

// ----------------------------------------------------------------------------
//  精灵屏幕落点体检（判断"看不见"是画面外还是没画）。
//  换算：screen = (world - cam.scroll * scrollFactor) * zoom + 屏幕中心 * (1 - zoom)
// ----------------------------------------------------------------------------
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
		// 真正画到屏幕上的矩形（用 flxanimate 回填的 rel/wh 换算，见主脚本 fitAnimateCenter）
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

// ----------------------------------------------------------------------------
//  FlxAnimate 图集体检。FlxAnimate.draw() 会把 _flashRect（本帧真正画到的范围）
//  写进 width/height，所以 wh>0 = 真的画出了东西；wh=0 = 一帧都没画
//  （图集/符号/元素某一环断了）。
// ----------------------------------------------------------------------------
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

// ----------------------------------------------------------------------------
//  调试按键（onUpdate 里调用 checkDebugKeys()）
//    F2 嘴型标注开关；F3 摘/挂 shader；F4 性能日志开关
// ----------------------------------------------------------------------------
function checkDebugKeys() {
	var k = FlxG.keys;
	if (k == null) return;
	if (k.justPressed.F2) setMouthDebug(!MOUTH_DEBUG);
	// F3 用来分辨"卡在 GPU shader"还是"卡在别处"：
	// 摘掉后帧率明显回升 = 瓶颈是逐精灵的 FlxRuntimeShader（片元对每像素都很贵）。
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

// ----------------------------------------------------------------------------
//  F2 嘴型标注：在每个嘴的位置画一条带名字的标签，方便肉眼对位
// ----------------------------------------------------------------------------
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

// 嘴型标注的每帧跟随（onUpdate 里、updateLipsync 之后调用）
function updateMouthDebug() {
	if (!MOUTH_DEBUG || mouthLabels == null) return;
	for (i in 0...5) {
		var ls = lipsyncs[i];
		var lb = mouthLabels[i];
		if (ls == null || lb == null) continue;
		lb.visible = ls.visible;
		lb.setPosition(ls.x - 100, ls.y - 46);
	}
}

// ----------------------------------------------------------------------------
//  性能探针（onUpdate 里调用）：每 10 秒记一次 fps + 最差单帧。
//  worst 才是"卡顿"，平均值看不出来。别调成 1-2 秒：slog 要开文件，
//  写得越勤越容易自己制造掉帧。
// ----------------------------------------------------------------------------
function perfTick(elapsed) {
	if (!PERF_LOG) return;
	perfAccum = perfAccum + elapsed;
	perfFrames = perfFrames + 1;
	if (elapsed > perfWorst) perfWorst = elapsed;
	if (perfAccum >= 10.0) {
		var p = ps();
		slog('perf fps=' + (Math.round(perfFrames / perfAccum * 10) / 10)
			+ ' worst=' + (Math.round(perfWorst * 1000) / 10) + 'ms'
			+ (shadersOff ? ' (no shader)' : '')
			+ (p != null && p.camGame != null ? ' zoom=' + Math.round(p.camGame.zoom * 100) / 100 : ''));
		perfAccum = 0;
		perfFrames = 0;
		perfWorst = 0;
	}
}
