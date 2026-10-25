package nmv.scripts.preset;

import crowplexus.iris.Iris;

/**
 * NMV preset 的 flixel 段。
 *
 * 与 NMV 的差异只有两处：FlxCamera/FunkinCamera 换成 FE 的 PsychCamera、
 * FlxAnimate* 换成 flxanimate.PsychFlxAnimate 一族，其余同名同源直接注册。
 */
class PresetFlixel
{
	public static function register(script:FunkinScript):Void
	{
		script.set("FlxG", flixel.FlxG);
		script.set("FlxSprite", flixel.FlxSprite);
		script.set("FlxCamera", flixel.FlxCamera);
		script.set("PsychCamera", backend.PsychCamera);
		script.set("FlxMath", flixel.math.FlxMath);
		script.set("FlxTimer", flixel.util.FlxTimer);
		script.set("FlxTween", flixel.tweens.FlxTween);
		script.set("FlxEase", flixel.tweens.FlxEase);
		script.set("FlxSound", flixel.sound.FlxSound);
		script.set('FlxText', flixel.text.FlxText);
		script.set("FlxRuntimeShader", flixel.addons.display.FlxRuntimeShader);
		script.set("FlxFlicker", flixel.effects.FlxFlicker);
		script.set('FlxSpriteUtil', flixel.util.FlxSpriteUtil);
		script.set("FlxBackdrop", flixel.addons.display.FlxBackdrop);
		// flixel 6 的 FlxPoint 是 abstract，不能直接注册；注册其实现类，
		// 脚本需要工厂时用 FlxBasePoint 构造（FlxPoint.get 的抽象语法不可用）
		script.set('FlxPoint', flixel.math.FlxBasePoint);

		script.set("FlxTypedGroup", flixel.group.FlxGroup);
		script.set("FlxSpriteGroup", flixel.group.FlxSpriteGroup);
		script.set("FlxEmitter", flixel.effects.particles.FlxEmitter);

		script.set('FlxCameraFollowStyle', flixel.FlxCamera.FlxCameraFollowStyle);
		script.set("FlxTextBorderStyle", flixel.text.FlxText.FlxTextBorderStyle);
		script.set("FlxBarFillDirection", flixel.ui.FlxBar.FlxBarFillDirection);

		// FE 的 animate 一族是 flxanimate.PsychFlxAnimate（import.hx 里别名为 FlxAnimate）
		script.set("FlxAnimate", flxanimate.PsychFlxAnimate);
		script.set("FlxAnimateFrames", flxanimate.frames.FlxAnimateFrames);

		// NMV 用 Int 封装的 ScriptedFlxColor，FE 同思路
		script.set('FlxColor', ScriptFlxColor);
	}
}
