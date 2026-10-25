package states.stages;

#if BASE_GAME_ERECT
import states.stages.objects.*;
import shaders.DropShadowShader;
import substates.GameOverSubstate;

/**
 * Week 6（school）的 erect 变体舞台，道具 / 坐标照原版 `schoolErect` 舞台。
 * 引擎侧的 erect 图片与原版逐字节相同，所以原版坐标能直接用。
 *
 * 像素舞台：道具按 `PlayState.daPixelZoom` 放大、关抗锯齿。
 * 原版 erect 里背景女生（`weeb/bgFreaks`）的 alpha 是 0，Erect Mode 干脆没建这个精灵，
 * 所以本舞台也不建 —— `BG Freaks Expression` 事件在这里无事可做。
 */
class SchoolErect extends BaseStage
{
	override function create()
	{
		var _song = PlayState.SONG;
		if(_song.gameOverSound == null || _song.gameOverSound.trim().length < 1) GameOverSubstate.deathSoundName = 'fnf_loss_sfx-pixel';
		if(_song.gameOverLoop == null || _song.gameOverLoop.trim().length < 1) GameOverSubstate.loopSoundName = 'gameOver-pixel';
		if(_song.gameOverEnd == null || _song.gameOverEnd.trim().length < 1) GameOverSubstate.endSoundName = 'gameOverEnd-pixel';
		if(_song.gameOverChar == null || _song.gameOverChar.trim().length < 1) GameOverSubstate.characterName = 'bf-pixel-dead';

		var props:Array<FlxSprite> = [];

		var sky:BGSprite = new BGSprite('weeb/erect/weebSky', -626, -78, 0.2, 0.2);
		add(sky);
		props.push(sky);

		var backTrees:BGSprite = new BGSprite('weeb/erect/weebBackTrees', -842, -80, 0.5, 0.5);
		add(backTrees);
		props.push(backTrees);

		var school:BGSprite = new BGSprite('weeb/erect/weebSchool', -816, -38, 0.75, 0.75);
		add(school);
		props.push(school);

		var street:BGSprite = new BGSprite('weeb/erect/weebStreet', -662, 6, 1, 1);
		add(street);
		props.push(street);

		var treesBG:FlxSprite = new FlxSprite(-806, -1050);
		treesBG.frames = Paths.getPackerAtlas('weeb/erect/weebTrees');
		treesBG.animation.add('treeLoop', [for (i in 0...19) i], 12);
		treesBG.animation.play('treeLoop');
		treesBG.scrollFactor.set(1, 1);
		add(treesBG);
		props.push(treesBG);

		if (!ClientPrefs.data.lowQuality)
		{
			var treesFG:BGSprite = new BGSprite('weeb/erect/weebTreesBack', -500, 6, 1, 1);
			add(treesFG);
			props.push(treesFG);

			var petals:BGSprite = new BGSprite('weeb/erect/petals', -20, -40, 0.85, 0.85, ['PETALS ALL'], true);
			add(petals);
			props.push(petals);
		}

		// 像素道具统一放大：先 setGraphicSize 再 updateHitbox（两者配套用才不会把 offset 弄歪）
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
		if (!ClientPrefs.data.shaders) return;

		// 原版 schoolErect.hxc：按角色挂 rim-light 蒙版
		// BF：pico-pixel 用 picoPixel_mask，其余 bfPixel_mask（threshold 1）
		attachShadow(boyfriend, -10, -23, -66, 24, 90, 5, 0.1,
			1, (boyfriend != null && boyfriend.curCharacter == 'pico-pixel')
				? 'weeb/erect/masks/picoPixel_mask' : 'weeb/erect/masks/bfPixel_mask');
		// DAD：senpai_mask（threshold 1）
		attachShadow(dad, -10, -23, -66, 24, 90, 5, 0.1, 1, 'weeb/erect/masks/senpai_mask');

		// gf：nene-pixel 用 nenePixel_mask（官方弱参数组 + 蒙版）；gf-pixel 弱参数 + gfPixel_mask
		if (gf != null && gf.curCharacter == 'nene-pixel')
			attachShadow(gf, -10, -25, -42, 5, 90, 3, 0.3, 1, 'weeb/erect/masks/nenePixel_mask');
		else if (gf != null && gf.curCharacter == 'gf-pixel')
			attachShadow(gf, -10, -25, -42, 5, 90, 3, 0.3, 1, 'weeb/erect/masks/gfPixel_mask');
		else if (gf != null)
			attachShadow(gf, -10, -23, -66, 24, 90, 5, 0.1, 1, 'weeb/erect/masks/gfPixel_mask');
	}

	static inline var RIM_COLOR:Int = 0xFF52351D;

	/** 原版 `dropShadow` 的边缘高光 + Adjust Color 合一，颜色固定为本舞台的 RIM_COLOR；maskKey 非空时挂 rim 蒙版。 */
	function attachShadow(char:FlxSprite, hue:Float, saturation:Float, brightness:Float, contrast:Float,
		angle:Float, distance:Float, threshold:Float, strength:Float = 1, ?maskKey:String, maskThreshold:Float = 1):DropShadowShader
	{
		if (char == null) return null;
		var maskBmp = null;
		if (maskKey != null)
		{
			var maskImg = Paths.image(maskKey);
			maskBmp = (maskImg != null) ? maskImg.bitmap : null;
		}
		return DropShadowShader.attach(char, {
			hue: hue,
			saturation: saturation,
			brightness: brightness,
			contrast: contrast,
			color: RIM_COLOR,
			angle: angle,
			strength: strength,
			distance: distance,
			threshold: threshold,
			mask: maskBmp,
			maskThreshold: maskThreshold
		});
	}
}
#end
