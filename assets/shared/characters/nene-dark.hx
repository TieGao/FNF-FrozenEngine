// nene-dark 的 ABot 音箱。接线同 nene.hx（PSO 标定：gf 锚点 + (10, 340)）。
// 暗色形态（原版 nene-dark.hxc）：
//   - 音箱本体用 `abot/dark/abotSystem` 暗色图集（addDarkSprite 参数），
//     平时显示暗色版；闪电把 nene 压暗时切回普通亮色版（原版是 TextureSwap 随 alpha 过渡，
//     这里用硬切近似）。
//   - stereoBG 常染 0xFF616785，眼白随 alpha 在 0xFF6F96CE 与白色间插值，
//   - 频谱条挂 AdjustColor(-26, -45, -12, 0) 压暗。

var abot:ABotSpeaker = null;

function onCreatePost()
{
	var ps = PlayState.instance;
	if (ps == null || ps.gf == null || ps.gfGroup == null) return;

	// 低血量抬刀状态机（5 个 nene 变体共用一份）
	ps.startHScriptsNamed('characters/nene-knife.hx');

	var stage:String = PlayState.curStage;
	if (StringTools.startsWith(stage, 'phillyStreets') || StringTools.startsWith(stage, 'phillyBlazin')) return;

	addHaxeLibrary('ABotSpeaker', 'states.stages.objects');
	addHaxeLibrary('AdjustColorShader', 'shaders');
	addHaxeLibrary('FlxColor');

	abot = new ABotSpeaker(ps.gfGroup.x + 10, ps.gfGroup.y + 340, true);
	ps.insert(ps.members.indexOf(ps.gfGroup), abot);
	abot.updateABotEye(1, true);

	// 暗色染色
	if (abot.bg != null) abot.bg.color = 0xFF616785;
	if (abot.eyeBg != null) abot.eyeBg.color = 0xFF6F96CE;
	var vizShader:AdjustColorShader = new AdjustColorShader();
	vizShader.apply(-26, -45, -12, 0);
	for (spr in abot.vizSprites) spr.shader = vizShader;

	// 默认显示暗色本体
	abot.darkSpeaker.visible = true;
	abot.speaker.visible = false;
}

function onSongStart()
{
	if (abot != null) abot.snd = FlxG.sound.music;
}

function onUpdate(elapsed:Float)
{
	if (abot == null) return;
	var ps = PlayState.instance;
	if (ps == null || ps.gf == null) return;

	// 闪电时舞台会把暗色角色 alpha 压到 0 —— 此时亮出普通色音箱，眼白回白
	// （hscript 调不了 FlxColor.interpolate 这类 abstract 静态方法，按状态硬切）
	var darkAmount:Float = ps.gf.alpha;
	if (abot.darkSpeaker != null) abot.darkSpeaker.visible = darkAmount >= 1;
	if (abot.speaker != null) abot.speaker.visible = darkAmount < 1;
	if (abot.eyeBg != null) abot.eyeBg.color = (darkAmount < 1) ? 0xFFFFFFFF : 0xFF6F96CE;
}

function onStepHit()
{
	if (abot == null) return;
	var ps = PlayState.instance;
	var notes = PlayState.SONG.notes;
	if (notes == null || notes.length < 1) return;
	var sec = Std.int(Math.max(0, Math.min(ps.curSection, notes.length - 1)));
	abot.updateABotEye(notes[sec].mustHitSection ? 1 : 0);
}
