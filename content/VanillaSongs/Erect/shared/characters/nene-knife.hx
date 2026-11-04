// Nene 的低血量抬刀状态机（照原版 `nene.hxc` / `nene-pixel.hxc`）。
// 血量 <= 25%（满血 2 → 0.5）时：当前 danceLeft/danceRight 播完 → raiseKnife →
// idleKnife 待机（每 3~7 拍眨一次眼）→ 血量回升后 lowerKnife 收刀。
// 5 个 nene 变体共用这一份，各自的角色脚本在 onCreatePost 里启动。
// PhillyStreets / PhillyBlazin 舞台自带同一套（作用于 gf），这里跳过避免双重驱动。

var nene:Dynamic = null;
var skipped:Bool = false;

/** 0 默认 / 1 准备抬刀 / 2 抬刀中 / 3 持刀待机 / 4 收刀中 */
var knifeState:Int = 0;
var animFinished:Bool = false;
var blinkCountdown:Int = 3;
var blinkAnim:String = 'idleKnife';

var MIN_BLINK_DELAY:Int = 3;
var MAX_BLINK_DELAY:Int = 7;
var VULTURE_THRESHOLD:Float = 0.5;

function ensureNene():Bool
{
	if (nene != null) return true;
	if (skipped) return false;

	var ps = PlayState.instance;
	if (ps == null) return false;

	var stage:String = PlayState.curStage;
	if (stage != null && (StringTools.startsWith(stage, 'phillyStreets') || StringTools.startsWith(stage, 'phillyBlazin')))
	{
		skipped = true;
		return false;
	}

	// PicoMix 里 nene 固定是 gf；dad 兜底给把 nene 放对手位的场合
	if (ps.gf != null && ps.gf.hasAnimation('raiseKnife')) nene = ps.gf;
	else if (ps.dad != null && ps.dad.hasAnimation('raiseKnife')) nene = ps.dad;

	if (nene != null && nene.hasAnimation('idleKnifeBlink')) blinkAnim = 'idleKnifeBlink';
	return nene != null;
}

function onUpdate(elapsed:Float)
{
	if (!ensureNene()) return;

	animFinished = nene.isAnimationFinished();
	transitionState();
}

function onBeatHit()
{
	if (!ensureNene()) return;
	if (knifeState != 3) return;

	if (blinkCountdown <= 0)
	{
		nene.playAnim(blinkAnim, false);
		blinkCountdown = FlxG.random.int(MIN_BLINK_DELAY, MAX_BLINK_DELAY);
	}
	else blinkCountdown--;
}

function transitionState()
{
	var ps = PlayState.instance;
	if (ps == null) return;

	if (knifeState == 0)
	{
		if (ps.health <= VULTURE_THRESHOLD)
		{
			knifeState = 1;
			// 让当前 danceLeft/danceRight 播完，别被下一拍打断
			nene.skipDance = true;
		}
	}
	else if (knifeState == 1)
	{
		if (ps.health > VULTURE_THRESHOLD)
		{
			knifeState = 0;
			nene.skipDance = false;
		}
		else if (animFinished)
		{
			knifeState = 2;
			nene.playAnim('raiseKnife');
			nene.danced = true;
			animFinished = false;
		}
	}
	else if (knifeState == 2)
	{
		if (animFinished)
		{
			knifeState = 3;
			// 进待机先眨一次，把 raiseKnife 的末帧换成 idleKnife
			blinkCountdown = 0;
			animFinished = false;
		}
	}
	else if (knifeState == 3)
	{
		if (ps.health > VULTURE_THRESHOLD)
		{
			knifeState = 4;
			nene.playAnim('lowerKnife');
		}
	}
	else if (knifeState == 4)
	{
		if (animFinished)
		{
			knifeState = 0;
			animFinished = false;
			nene.skipDance = false;
		}
	}
}
