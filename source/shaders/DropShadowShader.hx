package shaders;

import flixel.FlxG;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxAngle;
import openfl.display.BitmapData;

/**
 * 原版 `funkin.graphics.shaders.DropShadowShader` 的移植：边缘高光（rim light）+ Adjust Color 合一。
 *
 * 两者写在一个 shader 里是原版的设计 —— `FlxSprite.shader` 只有一个槽位，角色要同时吃调色和描边光。
 * 参数语义与原版一致，照着原版脚本（或 Erect Mode 的 `*Erect.lua`）抄数值即可。
 *
 * 与原版实现的三处差异，都是为了让它在 FE 的 flixel 6.2 / OpenFL 上稳：
 * - 去掉 `#ifdef HAS_DERIVATIVES` / `fwidth`：OpenFL 的 GLSL ES 1.0 要显式开扩展才能用导数，
 *   而 shader 编译失败只 Log.error、不抛异常，表现成角色静默消失。这里固定用 `1.0 / openfl_TextureSize`。
 * - `useMask` 用 float 而不是 bool（OpenFL 的 bool uniform 赋值路径不稳）。
 * - 采样统一走 `flixel_texture2D`：FE 的角色是 sparrow 图集、帧只是图集里的一块，
 *   必须让 flixel 的 uv 变换把帧内坐标映射到图集坐标。
 *
 * `uFrameBounds` 必须逐帧传 `frame.uv`（图集归一化坐标），与原版一致。
 * flixel 交给 shader 的 `openfl_TextureCoordv` 是**整张图集**的归一化坐标（顶点 uv 取自
 * `frame.frame / 图集尺寸`），不是帧内 0~1；`dist` 又是按图集像素算的偏移，所以写死
 * `(0,0,1,1)` 等于关掉"偏移点是否还在本帧内"这道判定：采样点会甩到图集里相邻的帧上，
 * `rim` 随换帧在 0/1 之间跳，表现就是边缘光一直闪（gfTankmen 图集帧间最小缝只有 4px，
 * 而 dist=15px，必跨）。原版 sparrow 角色也走这条路径，只有 animateatlas 才开 render texture。
 *
 * 逐帧信息由 `attach()` 注册进静态表，在 `FlxG.signals.preDraw` 里轮询换帧（原版挂的是
 * `animation.onFrameChange`，但 FE 的 flixel 6.2 正常播放时不派发，见 `refreshTracked`）。
 *
 * GLSL 里不写注释、只用 ASCII（见项目记忆）。
 */
class DropShadowShader extends ErrorHandledShader
{
	@:glFragmentSource('
		#pragma header

		uniform vec4 uFrameBounds;

		uniform float dist;
		uniform float str;
		uniform float thr;

		uniform float angCos;
		uniform float angSin;

		uniform sampler2D altMask;
		uniform float useMask;
		uniform float thr2;
		uniform vec2 uMaskScale;

		uniform vec3 dropColor;

		uniform float hue;
		uniform float saturation;
		uniform float brightness;
		uniform float contrast;

		const vec3 grayscaleValues = vec3(0.3098039215686275, 0.607843137254902, 0.0823529411764706);
		const float e = 2.718281828459045;
		const vec3 lumaValue = vec3(0.2126, 0.7152, 0.0722);

		vec3 applyHueRotate(vec3 aColor, float aHue)
		{
			float angle = radians(aHue);

			mat3 m1 = mat3(0.213, 0.213, 0.213, 0.715, 0.715, 0.715, 0.072, 0.072, 0.072);
			mat3 m2 = mat3(0.787, -0.213, -0.213, -0.715, 0.285, -0.715, -0.072, -0.072, 0.928);
			mat3 m3 = mat3(-0.213, 0.143, -0.787, -0.715, 0.140, 0.715, 0.928, -0.283, 0.072);
			mat3 m = m1 + cos(angle) * m2 + sin(angle) * m3;

			return m * aColor;
		}

		vec3 applySaturation(vec3 aColor, float value)
		{
			if (value > 0.0) value = value * 3.0;
			value = (1.0 + (value / 100.0));
			vec3 grayscale = vec3(dot(aColor, grayscaleValues));
			return clamp(mix(grayscale, aColor, value), 0.0, 1.0);
		}

		vec3 applyContrast(vec3 aColor, float value)
		{
			value = (1.0 + (value / 100.0));
			if (value > 1.0)
			{
				value = (((0.00852259 * pow(e, 4.76454 * (value - 1.0))) * 1.01) - 0.0086078159) * 10.0;
				value += 1.0;
			}
			return clamp((aColor - 0.25) * value + 0.25, 0.0, 1.0);
		}

		vec3 applyHSBCEffect(vec3 color)
		{
			color = color + ((brightness) / 255.0);
			color = applyHueRotate(color, hue);
			color = applyContrast(color, contrast);
			color = applySaturation(color, saturation);
			return color;
		}

		float getLumaRGB(vec3 color)
		{
			return dot(color.rgb, lumaValue);
		}

		vec4 getTexRGBA(vec2 uv)
		{
			return flixel_texture2D(bitmap, uv);
		}

		float lwidth_manual(float center, vec2 uv, vec2 px)
		{
			vec3 p2x1 = getTexRGBA(uv + vec2( 1.0,  0.0) * px).rgb;
			vec3 p1x2 = getTexRGBA(uv + vec2( 0.0,  1.0) * px).rgb;
			vec3 p2x2 = getTexRGBA(uv + vec2( 1.0,  1.0) * px).rgb;

			float right = getLumaRGB(p2x1);
			float down = getLumaRGB(p1x2);
			float diagonal = getLumaRGB(p2x2);

			float dx = abs(right - center);
			float dy = abs(down - center);
			float dd = abs(diagonal - center);

			return ((dx + dy + dd * 0.7) / (1.0 + 1.0 + 0.7)) * 2.0;
		}

		float getThreshold(vec2 uv)
		{
			float threshold = thr;

			if (useMask > 0.5)
			{
				float maskIntensity = texture2D(altMask, uv * uMaskScale).b;
				if (maskIntensity > 0.0)
					threshold = thr2;
			}

			return threshold;
		}

		void main()
		{
			vec2 uv = openfl_TextureCoordv;
			vec4 color4 = flixel_texture2D(bitmap, uv);
			vec2 ratio = 1.0 / openfl_TextureSize.xy;
			vec2 px = ratio;

			float color3_light = getLumaRGB(color4.rgb);
			float delta = lwidth_manual(color3_light, uv, px);

			float threshold = getThreshold(uv);
			float intensity = smoothstep(threshold - delta, threshold + delta, color3_light);

			float shadowAlpha = 0.0;

			vec3 color3_no_effect = color4.a > 0.0 ? color4.rgb / color4.a : color4.rgb;
			vec3 color3 = applyHSBCEffect(color3_no_effect);

			vec2 checked = vec2(
				uv.x + (dist * angCos * ratio.x),
				uv.y - (dist * angSin * ratio.y)
			);

			if (checked.x > uFrameBounds.x &&
				checked.y > uFrameBounds.y &&
				checked.x < uFrameBounds.z &&
				checked.y < uFrameBounds.w)
			{
				shadowAlpha = flixel_texture2D(bitmap, checked).a;
			}

			float rim = (1.0 - (shadowAlpha * str)) * intensity;

			color3 += dropColor * rim;

			gl_FragColor = vec4(color3 * color4.a, color4.a);
		}
	')
	/** 原版脚本里 `ang` 传的角度（度），换帧时要加上帧自身的旋转。 */
	var baseAngle:Float = 0;

	/** altMask 的像素尺寸，用于把图集 uv 换算回 mask 的 uv（两者画布尺寸通常不同）。 */
	var maskWidth:Int = 0;
	var maskHeight:Int = 0;
	var maskScaleDirty:Bool = false;
	var lastMaskGfxW:Int = -1;
	var lastMaskGfxH:Int = -1;

	public function new()
	{
		super('DropShadow');

		// altMask 在没调 setAltMask 时也必须绑一个纹理：它被动态分支引用，驱动不会优化掉，留空会让 sampler 悬空。
		// 1x1 白色够用 —— useMask 默认 0，根本采样不到它。
		data.altMask.input = new BitmapData(1, 1, true, 0xFFFFFFFF);
		data.uFrameBounds.value = [0.0, 0.0, 1.0, 1.0];
		data.dist.value = [15.0];
		data.str.value = [1.0];
		data.thr.value = [0.1];
		data.angCos.value = [1.0];
		data.angSin.value = [0.0];
		data.useMask.value = [0.0];
		data.thr2.value = [1.0];
		data.uMaskScale.value = [1.0, 1.0];
		data.dropColor.value = [1.0, 1.0, 1.0];
		data.hue.value = [0.0];
		data.saturation.value = [0.0];
		data.brightness.value = [0.0];
		data.contrast.value = [0.0];
	}

	/** 原版 `setAdjustColor` 的四个参数：hue 是角度，brightness 是 0~255 偏移，saturation / contrast 是百分比。 */
	public function applyAdjustColor(hue:Float, saturation:Float, brightness:Float, contrast:Float):Void
	{
		data.hue.value = [hue];
		data.saturation.value = [saturation];
		data.brightness.value = [brightness];
		data.contrast.value = [contrast];
	}

	/** 边缘光：颜色、角度（度）、强度、像素距离、亮度阈值。 */
	public function setRim(color:Int, angle:Float, strength:Float, distance:Float, threshold:Float):Void
	{
		baseAngle = angle;
		data.dropColor.value = [((color >> 16) & 0xFF) / 255, ((color >> 8) & 0xFF) / 255, (color & 0xFF) / 255];
		data.str.value = [strength];
		data.dist.value = [distance];
		data.thr.value = [threshold];
		updateAngle(0);
	}

	/**
	 * 二级掩码：掩码里蓝色通道非零的像素改用 `maskThreshold`（原版的 `altMask` / `useMask` / `thr2`）。
	 *
	 * `mask` 必须是**与角色图集同一像素坐标**的画布（原版 animateatlas 的舞台截图就是这样）。
	 * 它跟图集常常不同尺寸（`gfTankmen_mask` 8192×4096 vs 图集 7500×2580，多出来的部分全是空），
	 * 所以采样要乘 `图集尺寸 / mask 尺寸` 把同一像素对回去 —— 直接拿 uv 采会整块错位，
	 * 换帧时命中/不命中随机切换，rim 强度就会逐帧跳。
	 */
	public function setAltMask(mask:BitmapData, maskThreshold:Float = 1.0):Void
	{
		data.altMask.input = mask;
		data.thr2.value = [maskThreshold];
		data.useMask.value = [1.0];
		maskWidth = mask.width;
		maskHeight = mask.height;
		maskScaleDirty = true;
	}

	/** 换帧时同步帧边界、mask 换算比例与角度偏移（由 preDraw 轮询调用，见 `attach`）。 */
	public function updateFrameInfo(frame:FlxFrame):Void
	{
		if (frame == null || frame.uv == null) return;
		// uv 是图集归一化坐标；写死 (0,0,1,1) 等于关掉"偏移采样还在本帧内"的判定，
		// dist 会把采样点甩到图集里相邻的帧上，rim 随换帧忽有忽无。
		data.uFrameBounds.value = [frame.uv.left, frame.uv.top, frame.uv.right, frame.uv.bottom];
		updateMaskScale(frame);
		updateAngle(frame.angle * FlxAngle.TO_RAD);
	}

	function updateMaskScale(frame:FlxFrame):Void
	{
		if (maskWidth <= 0 || maskHeight <= 0) return;
		var gfx = frame.parent;
		if (gfx == null) return;
		if (!maskScaleDirty && gfx.width == lastMaskGfxW && gfx.height == lastMaskGfxH) return;

		lastMaskGfxW = gfx.width;
		lastMaskGfxH = gfx.height;
		maskScaleDirty = false;
		data.uMaskScale.value = [gfx.width / maskWidth, gfx.height / maskHeight];
	}

	function updateAngle(frameAngleRad:Float):Void
	{
		var rad:Float = baseAngle * FlxAngle.TO_RAD + frameAngleRad;
		data.angCos.value = [Math.cos(rad)];
		data.angSin.value = [Math.sin(rad)];
	}

	/**
	 * 待同步的实例表。**不能挂 `animation.callback`**：flixel 6.2 里它只在手动赋
	 * `frameIndex` 时触发，正常播放（`FlxAnimation.update` 只自增 `curFrame`）完全不回调，
	 * 挂了也只在开局跑一次 —— 帧边界永远停在第一帧，后续帧的 dist 采样点落在邻帧/帧外，
	 * 表现就是角色每次换帧都有随机一块边缘光丢失（ugh erect 的 gf 就是这么闪的）。
	 *
	 * 改成 preDraw 轮询：此时本帧 update 已跑完、绘制还没开始，读到的必定是当前帧；
	 * 再用 lastFrame 挡掉没换帧的场合，开销只剩一次引用比较。
	 */
	static var tracked:Array<DropShadowShader> = [];
	static var hooked:Bool = false;

	var target:FlxSprite;
	var lastFrame:FlxFrame;

	static function refreshTracked():Void
	{
		var i:Int = tracked.length;
		while (i-- > 0)
		{
			var sh:DropShadowShader = tracked[i];
			var spr:FlxSprite = sh.target;
			// 角色已销毁（frames 被置空）或 shader 被换掉 → 退出追踪
			if (spr == null || spr.frames == null || spr.shader != sh)
			{
				sh.target = null;
				sh.lastFrame = null;
				tracked.splice(i, 1);
				continue;
			}

			var frame:FlxFrame = spr.frame;
			if (frame == sh.lastFrame) continue;
			sh.lastFrame = frame;
			sh.updateFrameInfo(frame);
		}
	}

	/** 给一个精灵挂上这套光影，并在 preDraw 阶段逐帧同步帧边界与角度。 */
	public static function attach(target:FlxSprite, cfg:DropShadowConfig):DropShadowShader
	{
		var sh:DropShadowShader = new DropShadowShader();
		sh.applyAdjustColor(cfg.hue, cfg.saturation, cfg.brightness, cfg.contrast);
		sh.setRim(cfg.color, cfg.angle, cfg.strength, cfg.distance, cfg.threshold);
		if (cfg.mask != null) sh.setAltMask(cfg.mask, cfg.maskThreshold);

		target.shader = sh;
		sh.target = target;
		sh.updateFrameInfo(target.frame);

		if (!hooked)
		{
			hooked = true;
			FlxG.signals.preDraw.add(refreshTracked);
		}
		if (tracked.indexOf(sh) == -1) tracked.push(sh);

		return sh;
	}
}

/** `DropShadowShader.attach` 的参数。语义同原版脚本里那几个 `setShaderFloat`。 */
typedef DropShadowConfig =
{
	var hue:Float;
	var saturation:Float;
	var brightness:Float;
	var contrast:Float;
	var color:Int;
	/** 角度，单位是度（原版脚本传的是 `math.rad(x)`，这里换算过）。 */
	var angle:Float;
	var strength:Float;
	var distance:Float;
	var threshold:Float;
	@:optional var mask:BitmapData;
	@:optional var maskThreshold:Float;
}
