// stress-pico 的 Otis 演出（官方 otis-speaker.hxc 移植）
// 数据源：content/VanillaSongs/PicoMix/shared/data/stress/picospeaker.json
//         （官方 picospeaker 难度，584 条，音符 [时间, 方向] 决定何时朝哪边开枪）
// 三件事：按谱面播 shoot1-4、在枪口位置放闪光、把 ABot 音箱挂到 gf 旁边。
//
// gf 每拍都会 dance() 回 idle，会把 shoot 动画掐断 —— 开枪后用 skipDance 开一个
// 时间窗挡住，窗口过了再放开（用时间窗而不是等动画结束，重进/暂停也不会卡死）。

// ---- 可调项（坐标都是相对 gf 锚点的像素） ----
// 枪口闪光位置，下标 = 谱面方向 0..3。用 otis 各开枪帧的最外沿（枪口）与闪光帧的
// 内容中心离线对齐出来的（otis 的 anim offsets 全为 0，所以直接叠在 gf 锚点上）。
// 实机发现偏，就调这张表。
var MUZZLE_OFFSETS = [[333, -365], [395, -439], [-835, -408], [-906, -472]];
var ENABLE_MUZZLE = true;
// ABot 音箱位置（官方 otis-speaker.hxc: gf + (170, 455)；nene 的标定值是 (10, 340)）
var ABOT_OFFSET = [170, 455];
var ENABLE_ABOT = true;
// 开枪后禁舞时长（ms）：shoot 动画 12 帧 @24fps ≈ 500ms
var SHOOT_HOLD = 520;

var shootTimes:Array<Float> = [];
var shootDirs:Array<Int> = [];
var nextShot:Int = 0;
var armed:Bool = false;
var shootUntil:Float = 0;

var muzzle:FlxSprite = null;
var abot:ABotSpeaker = null;

function onCreatePost(?e)
{
	var p = PlayState.instance;
	if (p == null || p.chartingMode) return;

	var gf = p.gf;
	if (gf == null || gf.curCharacter != 'otis-speaker') return;

	armed = true;
	loadChart();
	buildMuzzle(p);
	buildAbot(p);
}

// ---------------------------------------------------------------------------
// picospeaker 谱面：每首只有一份（不带难度/变体后缀），直接读文件
// ---------------------------------------------------------------------------
function loadChart()
{
	shootTimes = [];
	shootDirs = [];
	nextShot = 0;

	var path = Paths.json('stress/picospeaker');
	if (path == null || !FileSystem.exists(path))
	{
		debugPrint('otis: picospeaker chart not found');
		return;
	}

	try
	{
		var data = parseJson(File.getContent(path));
		if (data == null) return;
		// 兼容扁平与 {"song": {...}} 两种写法（本包是扁平）
		var songData = data;
		if (songData.notes == null && data.song != null) songData = data.song;
		if (songData.notes == null) return;

		for (sec in songData.notes)
		{
			var notes = sec.sectionNotes;
			if (notes == null) continue;
			for (n in notes)
			{
				shootTimes.push(n[0]);
				shootDirs.push(Std.int(n[1]) % 4);
			}
		}
		debugPrint('otis: loaded ' + shootTimes.length + ' shots');
	}
	catch (e:Dynamic)
	{
		debugPrint('otis: picospeaker parse failed: ' + e);
	}
}

// ---------------------------------------------------------------------------
// 枪口闪光：官方 characters/otis/muzzle-flashes/otis_flashes，四组帧按方向各播一组
// ---------------------------------------------------------------------------
function buildMuzzle(p)
{
	if (!ENABLE_MUZZLE) return;
	try
	{
		muzzle = new FlxSprite(0, 0);
		muzzle.frames = Paths.getSparrowAtlas('characters/otis-speaker/muzzle-flashes/otis_flashes');
		muzzle.animation.addByPrefix('shoot1', 'shoot back0', 24, false);
		muzzle.animation.addByPrefix('shoot2', 'shoot back low0', 24, false);
		muzzle.animation.addByPrefix('shoot3', 'shoot forward0', 24, false);
		muzzle.animation.addByPrefix('shoot4', 'shoot forward low0', 24, false);
		muzzle.antialiasing = ClientPrefs.data.antialiasing;
		muzzle.visible = false;
		// 层级压在 gf 之上（gfGroup 的下一层）
		var idx = p.members.indexOf(p.gfGroup);
		if (idx >= 0) p.insert(idx + 1, muzzle) else p.add(muzzle);
	}
	catch (e:Dynamic)
	{
		debugPrint('otis: muzzle build failed: ' + e);
		muzzle = null;
	}
}

// ---------------------------------------------------------------------------
// ABot 音箱（官方挂在 otis-speaker 角色脚本上；引擎角色是数据驱动的，这里补挂）
// ---------------------------------------------------------------------------
function buildAbot(p)
{
	if (!ENABLE_ABOT) return;
	try
	{
		addHaxeLibrary('ABotSpeaker', 'states.stages.objects');
		var gf = p.gf;
		abot = new ABotSpeaker(gf.x + ABOT_OFFSET[0], gf.y + ABOT_OFFSET[1]);
		var idx = p.members.indexOf(p.gfGroup);
		if (idx >= 0) p.insert(idx, abot) else p.add(abot);
		abot.updateABotEye(1, true);
	}
	catch (e:Dynamic)
	{
		debugPrint('otis: abot build failed: ' + e);
		abot = null;
	}
}

function onSongStart()
{
	if (abot != null) abot.snd = FlxG.sound.music;
}

// ---------------------------------------------------------------------------
// 逐帧：按时间点触发开枪
// ---------------------------------------------------------------------------
function onUpdate(elapsed)
{
	if (!armed) return;
	var p = PlayState.instance;
	if (p == null) return;

	if (shootUntil > 0 && Conductor.songPosition > shootUntil)
	{
		shootUntil = 0;
		if (p.gf != null) p.gf.skipDance = false;
	}

	if (muzzle != null && muzzle.visible && muzzle.animation.curAnim != null && muzzle.animation.finished)
		muzzle.visible = false;

	while (nextShot < shootTimes.length && shootTimes[nextShot] <= Conductor.songPosition)
	{
		fire(shootDirs[nextShot]);
		nextShot++;
	}
}

function fire(dir:Int)
{
	var p = PlayState.instance;
	var gf = p.gf;
	if (gf == null) return;

	var anim = 'shoot' + (dir + 1);
	if (gf.hasAnimation(anim))
	{
		gf.playAnim(anim, true);
		gf.skipDance = true;
		shootUntil = Conductor.songPosition + SHOOT_HOLD;
	}

	if (muzzle != null)
	{
		var off = MUZZLE_OFFSETS[dir];
		muzzle.setPosition(gf.x + off[0], gf.y + off[1]);
		muzzle.visible = true;
		muzzle.animation.play(anim, true);
	}
}

// 官方 otis-speaker.hxc 按 FocusCamera 的 char 挪瞳孔；FE 的 ABotSpeaker 用眼动近似
function onEvent(name, value1, value2, strumTime)
{
	if (name != 'Set Camera Target' || abot == null) return;

	var v = (value1 == null) ? '' : value1.toLowerCase();
	if (v.indexOf('bf') == 0 || v == 'boyfriend') abot.updateABotEye(1);
	else if (v.indexOf('dad') == 0) abot.updateABotEye(0);
}

function onDestroy(?e)
{
	armed = false;
	shootTimes = [];
	shootDirs = [];
}
