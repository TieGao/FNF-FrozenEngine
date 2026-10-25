// pico-playable 的 censor 动画触发：谱面里 note kind = 'censor'（[UH-OH!] Censor Bar）的音符
// 打中时播 sing<方向>-censor（照官方 pico-playable.hxc 的 onNoteHit 分支）。
// 动画在角色 json 里（额外 sparrow 图集 characters/Pico_Censored，走 addExtraAtlas 的 sparrow 分支）。

function goodNoteHit(note)
{
	if (note == null || note.noteType != 'censor') return;

	var bf = game.boyfriend;
	if (bf == null || bf.curCharacter != 'pico-playable') return;

	// 玩家侧列号 0-3 = 左/下/上/右
	var dirs:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
	var anim:String = 'sing' + dirs[Std.int(Math.abs(note.noteData) % 4)] + '-censor';
	if (bf.hasAnimation(anim))
	{
		bf.holdTimer = 0;
		bf.playAnim(anim, true);
	}
}
