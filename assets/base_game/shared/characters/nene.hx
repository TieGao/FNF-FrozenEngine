// nene 的 ABot 音箱（位置 / 接线照 Funkin-Psych-Online：abot 挂在 gf 锚点 + (10, 340)）。
// 原版把它挂在 nene 角色脚本上（`nene.hxc` 的 `setupAbot()`）；引擎角色是数据驱动的，
// 所以在这里补挂。PhillyStreets / PhillyBlazin 两个舞台自己建了一个，跳过避免叠两个。

var abot:ABotSpeaker = null;

function onCreatePost()
{
	var ps = PlayState.instance;
	if (ps == null || ps.gf == null || ps.gfGroup == null) return;

	// 低血量抬刀状态机（5 个 nene 变体共用一份）
	ps.startHScriptsNamed('characters/nene-knife.hx');

	// PhillyStreets / PhillyBlazin 自己建了 ABot（PhillyStreetsErect 继承前者，也要算上）
	var stage:String = PlayState.curStage;
	if (StringTools.startsWith(stage, 'phillyStreets') || StringTools.startsWith(stage, 'phillyBlazin')) return;

	addHaxeLibrary('ABotSpeaker', 'states.stages.objects');
	abot = new ABotSpeaker(ps.gfGroup.x + 10, ps.gfGroup.y + 340);
	ps.insert(ps.members.indexOf(ps.gfGroup), abot);
	abot.updateABotEye(1, true);
}

function onSongStart()
{
	// 音浪频谱：接上正在播的音乐（引擎的 SpectralAnalyzer 需要 snd 才会动）
	if (abot != null) abot.snd = FlxG.sound.music;
}

function onStepHit()
{
	if (abot == null) return;
	var ps = PlayState.instance;
	var notes = PlayState.SONG.notes;
	if (notes == null || notes.length < 1) return;
	var sec = Std.int(Math.max(0, Math.min(ps.curSection, notes.length - 1)));
	// 原版行为：轮到玩家唱就看右边，否则看左边
	abot.updateABotEye(notes[sec].mustHitSection ? 1 : 0);
}
