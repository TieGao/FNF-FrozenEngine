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
		// NmvSprite：补 NMV flixel fork 的 zIndex/skew 字段（API 兼容，无渲染语义）
		script.set("FlxSprite", nmv.objects.NmvSprite);
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
		script.set("FlxParticle", flixel.effects.particles.FlxParticle);
		// FlxAxes 是 enum abstract(Int) 旗标，注册名字→值映射
		script.set("FlxAxes", {
			XY: flixel.util.FlxAxes.XY,
			X: flixel.util.FlxAxes.X,
			Y: flixel.util.FlxAxes.Y,
			NONE: flixel.util.FlxAxes.NONE
		});

		script.set('FlxCameraFollowStyle', flixel.FlxCamera.FlxCameraFollowStyle);
		script.set("FlxTextBorderStyle", flixel.text.FlxText.FlxTextBorderStyle);
		script.set("FlxBarFillDirection", flixel.ui.FlxBar.FlxBarFillDirection);

		// FE 的 animate 一族是 flxanimate.PsychFlxAnimate（import.hx 里别名为 FlxAnimate）
		script.set("FlxAnimate", flxanimate.PsychFlxAnimate);
		script.set("FlxAnimateFrames", flxanimate.frames.FlxAnimateFrames);

		// NMV 用 Int 封装的 ScriptedFlxColor，FE 同思路
		script.set('FlxColor', ScriptFlxColor);

		// ---- shader 族（语料 29 个文件依赖，Phase 5 专项）----
		// BlendMode 是 Int 型 enum abstract，不能注册类型本身；注册名字→值映射对象，
		// 脚本的 `sprite.blend = BlendMode.ADD` 走字段访问拿 Int，Reflect 赋值兼容
		script.set("BlendMode", {
			ADD: openfl.display.BlendMode.ADD,
			ALPHA: openfl.display.BlendMode.ALPHA,
			DARKEN: openfl.display.BlendMode.DARKEN,
			DIFFERENCE: openfl.display.BlendMode.DIFFERENCE,
			ERASE: openfl.display.BlendMode.ERASE,
			HARDLIGHT: openfl.display.BlendMode.HARDLIGHT,
			INVERT: openfl.display.BlendMode.INVERT,
			LAYER: openfl.display.BlendMode.LAYER,
			LIGHTEN: openfl.display.BlendMode.LIGHTEN,
			MULTIPLY: openfl.display.BlendMode.MULTIPLY,
			NORMAL: openfl.display.BlendMode.NORMAL,
			OVERLAY: openfl.display.BlendMode.OVERLAY,
			SCREEN: openfl.display.BlendMode.SCREEN,
			SHADER: openfl.display.BlendMode.SHADER,
			SUBTRACT: openfl.display.BlendMode.SUBTRACT
		});
		// openfl 通用件
		script.set("ShaderFilter", openfl.filters.ShaderFilter);
		script.set("FlxShader", flixel.system.FlxAssets.FlxShader);
		// NMV 引擎自带类，按原样移植进 nmv/shaders（属性式 API 与 FE 同名类不同形，
		// 不能复用 FE 版：DropShadowShader 缺 color/angle/distance/... 属性，
		// ColorSwap 缺 flash/daAlpha，RGBPalette 缺 setColors）
		script.set("DropShadowShader", nmv.shaders.DropShadowShader);
		script.set("ColorMatrixShader", nmv.shaders.ColorMatrixShader);
		script.set("HeatwaveShader", nmv.shaders.HeatwaveShader);
		script.set("ChromaticAbberation", nmv.shaders.ChromaticAbberation);
		script.set("OverlayShader", nmv.shaders.OverlayShader);
		script.set("ColorSwap", nmv.shaders.ColorSwap);
		script.set("RGBPalette", nmv.shaders.RGBPalette);
		// RGBShaderReference 在 NMV 引擎里就不存在（finaleUI.hx 在 NMV 本体也解析不到），
		// 接 FE 的同名类，构造签名 (sprite, palette) 与语料用法一致
		script.set("RGBShaderReference", shaders.RGBPalette.RGBShaderReference);
	}
}
