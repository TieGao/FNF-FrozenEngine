package nmv.objects;

/**
 * NMV PlayState.playHUD（BaseHUD/PsychHUD）的 FE 映射。
 *
 * FE 的 HUD 元素（iconP1/iconP2/healthBar/scoreTxt...）直接挂在 PlayState 上，
 * NMV 脚本走 playHUD.iconP2 这一层 —— 垫片用 getter 逐次取当前 PlayState 的
 * 同名字段（不能用构造期快照，脚本建卡时那些字段可能还没建）。
 * NMV BaseHUD 的专有面（updateHUD/重排等）未映射，语料只用到图标与血条。
 */
class PlayHUDShim
{
	public function new() {}

	public var iconP1(get, never):Dynamic;
	public var iconP2(get, never):Dynamic;
	public var healthBar(get, never):Dynamic;
	public var scoreTxt(get, never):Dynamic;

	function get_iconP1():Dynamic
	{
		return PlayState.instance == null ? null : PlayState.instance.iconP1;
	}

	function get_iconP2():Dynamic
	{
		return PlayState.instance == null ? null : PlayState.instance.iconP2;
	}

	function get_healthBar():Dynamic
	{
		return PlayState.instance == null ? null : PlayState.instance.healthBar;
	}

	function get_scoreTxt():Dynamic
	{
		return PlayState.instance == null ? null : PlayState.instance.scoreTxt;
	}
}
