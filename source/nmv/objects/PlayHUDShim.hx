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

	// NMV PsychHUD 的脚本可调面（legacy 包 utils.hx onCreatePost 会写这些）。
	// FE 无此 HUD 系统，给 NMV 同款默认值的会话内存版：ratingScale/combosScale
	// 参与 FE 侧无实际渲染语义，但缺了字段 hscript 会抛 Invalid field 并中断脚本函数。
	public var ratingPop:Float = (.785 / .7);
	public var combosPop:Float = (.6 / .5);
	public var ratingScale:Float = .7;
	public var combosScale:Float = .5;
	public var ratingSuffix:String = '';

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
