// bf-christmas 的 censor 动画触发：官方 erect cocoa 谱面里 note kind = 'censor' 的音符
// 打中时播 sing<方向>-censor（照官方 bf-christmas.hxc 的 onNoteHit 分支）。
// 动画在 Erect 包覆盖的 bf-christmas.json 里（image 追加 bfChristmas_Censored sparrow 图）。
// base 谱面没有 censor kind 音符，本脚本挂上无副作用。

function goodNoteHit(note)
{
	if (note == null || note.noteType != 'censor') return;

	var bf = game.boyfriend;
	if (bf == null || bf.curCharacter != 'bf-christmas') return;

	var dirs:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
	var anim:String = 'sing' + dirs[Std.int(Math.abs(note.noteData) % 4)] + '-censor';
	if (bf.hasAnimation(anim))
	{
		bf.holdTimer = 0;
		bf.playAnim(anim, true);
	}
}
