package states.stages;

#if BASE_GAME_ERECT
import flixel.addons.effects.FlxTrail;
import states.stages.objects.*;
import shaders.DropShadowShader;
import substates.GameOverSubstate;

/**
 * Week 6（schoolEvil）的 erect 变体舞台，道具 / 坐标照原版 `schoolEvilErect` 舞台。
 * 引擎侧的 erect 图片与原版逐字节相同，所以原版坐标能直接用。
 *
 * dad 后面挂一条 `FlxTrail`（原版脚本里也是挂在 dad 身后）。
 * `Trigger BG Ghouls` 事件唤起 `weeb/bgGhouls` 的故障动画，播完自己隐藏。
 */
class SchoolEvilErect extends BaseStage
{
	var bgGhouls:BGSprite;

	override function create()
	{
		var _song = PlayState.SONG;
		if(_song.gameOverSound == null || _song.gameOverSound.trim().length < 1) GameOverSubstate.deathSoundName = 'fnf_loss_sfx-pixel';
		if(_song.gameOverLoop == null || _song.gameOverLoop.trim().length < 1) GameOverSubstate.loopSoundName = 'gameOver-pixel';
		if(_song.gameOverEnd == null || _song.gameOverEnd.trim().length < 1) GameOverSubstate.endSoundName = 'gameOverEnd-pixel';
		if(_song.gameOverChar == null || _song.gameOverChar.trim().length < 1) GameOverSubstate.characterName = 'bf-pixel-dead';

		// 原版的 solid 道具：1x1 纯色靠 scale 铺开。不能调 updateHitbox()，否则 offset/origin 会把整块推飞
		var solid:FlxSprite = new FlxSprite(-500, -1000);
		solid.makeGraphic(1, 1, FlxColor.BLACK);
		solid.scrollFactor.set(0, 0);
		solid.scale.set(2400, 2000);
		solid.antialiasing = false;
		add(solid);

		var props:Array<FlxSprite> = [];

		// 绘制顺序照原版 zIndex：backspikes(15) < school(20) < backspike(25) < evilstreet(30)
		var backspikes:BGSprite = new BGSprite('weeb/erect/evil/weebBackSpikes', -842, -180, 0.5, 0.5);
		add(backspikes);
		props.push(backspikes);

		var school:BGSprite = new BGSprite('weeb/erect/evil/weebSchool', -816, -38, 0.75, 0.75);
		add(school);
		props.push(school);

		var backspike:BGSprite = new BGSprite('weeb/erect/evil/backSpike', 1416, 464, 0.85, 0.85);
		add(backspike);
		props.push(backspike);

		var evilstreet:BGSprite = new BGSprite('weeb/erect/evil/weebStreet', -662, 6, 1, 1);
		add(evilstreet);
		props.push(evilstreet);

		for (spr in props)
		{
			spr.antialiasing = false;
			spr.setGraphicSize(Std.int(spr.width * PlayState.daPixelZoom));
			spr.updateHitbox();
		}

		setDefaultGF('gf-pixel');
	}

	override function createPost()
	{
		if (dad != null)
		{
			var trail:FlxTrail = new FlxTrail(dad, null, 4, 24, 0.3, 0.069);
			addBehindDad(trail);
		}

		if (!ClientPrefs.data.shaders) return;

		// 原版 schoolEvilErect.lua：hue -28 / sat -20 / contrast 31 / brightness -66，
		// 边缘光 120 度、强度 1、距离 4、阈值 0.1；dad 另改 105 度 / 强度 0.34 / 距离 3，gf 改成 90 度
		attachShadow(boyfriend, -28, -20, -66, 31, 120, 4, 0.1);
		attachShadow(dad, -28, -20, -66, 31, 105, 3, 0.1, 0.34);

		// gf-pixel 在原版脚本里另有一组更弱的值
		if (gf != null && gf.curCharacter == 'gf-pixel')
			attachShadow(gf, -28, -20, -42, 11, 90, 3, 0.3);
		else
			attachShadow(gf, -28, -20, -66, 31, 90, 4, 0.1);
	}

	static inline var RIM_COLOR:Int = 0xFF521D4B;

	/** 原版 `dropShadow` 的边缘高光 + Adjust Color 合一，颜色固定为本舞台的 RIM_COLOR。 */
	function attachShadow(char:FlxSprite, hue:Float, saturation:Float, brightness:Float, contrast:Float,
		angle:Float, distance:Float, threshold:Float, strength:Float = 1):Void
	{
		if (char == null) return;
		DropShadowShader.attach(char, {
			hue: hue,
			saturation: saturation,
			brightness: brightness,
			contrast: contrast,
			color: RIM_COLOR,
			angle: angle,
			strength: strength,
			distance: distance,
			threshold: threshold
		});
	}

	// 谱面里有该事件才建精灵（PlayState 按事件名去重，这里只会跑一次）
	override function eventPushed(event:objects.Note.EventNote)
	{
		switch (event.event)
		{
			case "Trigger BG Ghouls":
				if (ClientPrefs.data.lowQuality) return;

				bgGhouls = new BGSprite('weeb/bgGhouls', -100, 190, 0.9, 0.9, ['BG freaks glitch instance'], false);
				bgGhouls.setGraphicSize(Std.int(bgGhouls.width * PlayState.daPixelZoom));
				bgGhouls.updateHitbox();
				bgGhouls.visible = false;
				bgGhouls.antialiasing = false;
				bgGhouls.animation.finishCallback = function(name:String)
				{
					if (name == 'BG freaks glitch instance') bgGhouls.visible = false;
				}
				addBehindGF(bgGhouls);
		}
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch (eventName)
		{
			case "Trigger BG Ghouls":
				if (ClientPrefs.data.lowQuality || bgGhouls == null) return;
				bgGhouls.dance(true);
				bgGhouls.visible = true;
		}
	}
}
#end
