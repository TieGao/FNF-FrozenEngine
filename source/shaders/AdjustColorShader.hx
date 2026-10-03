package shaders;

/**
 * Animate / Flash 的「调整颜色」滤镜：色相 / 饱和度 / 亮度 / 对比度。
 *
 * 类名与四个 uniform 同原版 `funkin.graphics.shaders.AdjustColorShader`，方便对着原版脚本核参数。
 * 挂法见 `states.stages.StageErect`。
 *
 * 基类用 `ErrorHandledShader`：shader 编译失败时不再静默消失，而是写 `crash/shader_AdjustColor_*.txt` 并弹窗。
 * GLSL 里**不要写注释、只用 ASCII**（见项目记忆）—— 非 ASCII 字节会让驱动编译失败、表现成物体静默消失。
 */
class AdjustColorShader extends ErrorHandledShader
{
	@:glFragmentSource('
		#pragma header

		uniform float hue;
		uniform float saturation;
		uniform float brightness;
		uniform float contrast;

		const vec3 grayscaleValues = vec3(0.3098039215686275, 0.607843137254902, 0.0823529411764706);
		const float e = 2.718281828459045;

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

		void main()
		{
			vec4 textureColor = flixel_texture2D(bitmap, openfl_TextureCoordv);

			vec3 unpremultipliedColor = textureColor.a > 0.0 ? textureColor.rgb / textureColor.a : textureColor.rgb;

			vec3 outColor = applyHSBCEffect(unpremultipliedColor);

			gl_FragColor = vec4(outColor * textureColor.a, textureColor.a);
		}')
	public function new()
	{
		super('AdjustColor');
	}

	/**
	 * 一次性写入四个 uniform。
	 * 取值语义同原版：hue 是角度（度）、brightness 是 0~255 的偏移量、saturation / contrast 是百分比。
	 */
	public function apply(hue:Float, saturation:Float, brightness:Float, contrast:Float):Void
	{
		data.hue.value = [hue];
		data.saturation.value = [saturation];
		data.brightness.value = [brightness];
		data.contrast.value = [contrast];
	}
}
