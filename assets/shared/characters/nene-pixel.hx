// nene-pixel 的像素 ABot 音箱。
// 引擎 ABotSpeaker 已支持 isPixel 形态（abotPixel 精灵 + aBotVizPixel 频谱条，照 PSO 实现），
// 位置照 PSO 的 abot-pixel.json：gf 锚点 + (-90, 290)。

var abot:ABotSpeaker = null;

function onCreatePost()
{
	var ps = PlayState.instance;
	if (ps == null || ps.gf == null || ps.gfGroup == null) return;

	addHaxeLibrary('ABotSpeaker', 'states.stages.objects');
	abot = new ABotSpeaker(ps.gfGroup.x - 90, ps.gfGroup.y + 290, false, true);
	ps.insert(ps.members.indexOf(ps.gfGroup), abot);
	abot.updateABotEye(1, true);
}

function onSongStart()
{
	// 像素频谱条同样要接 snd 才会动
	if (abot != null) abot.snd = FlxG.sound.music;
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
