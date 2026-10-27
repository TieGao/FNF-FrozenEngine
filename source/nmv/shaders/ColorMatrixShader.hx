package nmv.shaders;

/**
 * NMV funkin.game.shaders.ColorMatrixShader 原样移植。
 */
class ColorMatrixShader extends flixel.system.FlxAssets.FlxShader
{
	@:glFragmentSource('
		#pragma header

		uniform mat4 uMultipliers;
		uniform vec4 uOffsets;

		void main() {
			vec4 color = flixel_texture2D(bitmap, openfl_TextureCoordv);

			if (color.a == 0.0) {
				gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
			} else {
				color = vec4(color.rgb / color.a, color.a);
				color = uOffsets + color * uMultipliers;

				gl_FragColor = vec4(color.rgb * color.a, color.a);
			}
		}
	')

	public function new()
	{
		super();

		uMultipliers.value = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
		uOffsets.value = [0, 0, 0, 0];
	}

	public function setMatrix(matrix:Array<Float>):Void
	{
		var multipliers = uMultipliers.value;
		var offsets = uOffsets.value;

		multipliers[0] = matrix[0];
		multipliers[1] = matrix[1];
		multipliers[2] = matrix[2];
		multipliers[3] = matrix[3];
		multipliers[4] = matrix[5];
		multipliers[5] = matrix[6];
		multipliers[6] = matrix[7];
		multipliers[7] = matrix[8];
		multipliers[8] = matrix[10];
		multipliers[9] = matrix[11];
		multipliers[10] = matrix[12];
		multipliers[11] = matrix[13];
		multipliers[12] = matrix[15];
		multipliers[13] = matrix[16];
		multipliers[14] = matrix[17];
		multipliers[15] = matrix[18];

		offsets[0] = (matrix[4] / 255);
		offsets[1] = (matrix[9] / 255);
		offsets[2] = (matrix[14] / 255);
		offsets[3] = (matrix[19] / 255);

		uMultipliers.value = multipliers;
		uOffsets.value = offsets;
	}
}
