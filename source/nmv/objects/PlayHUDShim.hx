package nmv.objects;

import flixel.math.FlxMath;

/**
 * NMV PlayState.playHUD（BaseHUD/PsychHUD）的 FE 映射。
 *
 * FE 的 HUD 元素（iconP1/iconP2/healthBar/scoreTxt/timeBar/timeTxt...）直接挂在 PlayState 上，
 * NMV 脚本走 playHUD.<字段> 这一层 —— 垫片用 getter 逐次取当前 PlayState 的
 * 同名字段（不能用构造期快照，脚本建卡时那些字段可能还没建）。
 *
 * 语料实测用面（2026-10-30 全包扫描）：iconP1/iconP2/healthBar/scoreTxt/timeBar/timeTxt/
 * healthLerp/members/add/insert + PsychHUD 专有开关（updateIconPos 等，只写不读）。
 * finalem.hx onCreatePost 写 playHUD.timeBar.visible 时缺 timeBar 曾让 onCreatePost
 * 半途而废（finaleDarkFG 没建 → onSongStart 对 null tween alpha → VarTween 崩溃）。
 */
class PlayHUDShim
{
	/**
	 * 共享实例：preset 的全局 playHUD 与 InterpEx 的 game.playHUD 特判都返回它。
	 * 垫片本体无状态（全部 getter 逐次取 PlayState.instance），单例只让
	 * _healthLerp/_healthBarOverride 等会话内存不因脚本数分裂。
	 */
	public static var instance(default, null):PlayHUDShim = new PlayHUDShim();

	/** NMV PsychHUD 的静态排版工具（victory 舞台脚本用） */
	public static inline function formatScoreField(label:String, value:String):String
	{
		return nmv.data.Lang.hasSpecial('rightToLeft') ? '$value :$label' : '$label: $value';
	}

	public function new() {}

	// ---- NMV PsychHUD 的脚本可调面（legacy 包 utils.hx onCreatePost 会写这些）。
	// FE 无此 HUD 系统，给 NMV 同款默认值的会话内存版：ratingScale/combosScale
	// 参与 FE 侧无实际渲染语义，但缺了字段 hscript 会抛 Invalid field 并中断脚本函数。
	public var ratingPop:Float = (.785 / .7);
	public var combosPop:Float = (.6 / .5);
	public var ratingScale:Float = .7;
	public var combosScale:Float = .5;
	public var ratingSuffix:String = '';
	public var ratingPrefix:String = '';

	/** NMV PsychHUD 的图标更新开关：脚本置 false 关掉 NMV 侧图标跟随，FE 侧无对应行为，仅为可写字段。 */
	public var updateIconPos:Bool = true;
	public var updateIconScale:Bool = true;
	public var updateIconAnimation:Bool = true;

	/** NMV PsychHUD 每帧向 parent.health 收敛的血量显示值（0..2）。 */
	var _healthLerp:Float = 1;
	var _healthLerpTouched:Bool = false;

	public var healthLerp(get, set):Float;

	function get_healthLerp():Float
	{
		// 无 override 时向真实血量收敛（NMV PsychHUD.update 同参数 0.15）；
		// Bar 的取值回调每帧来读，等效于 NMV 的逐帧 lerp。
		if (!_healthLerpTouched && PlayState.instance != null)
			_healthLerp = FlxMath.lerp(_healthLerp, PlayState.instance.health, 0.15);
		return _healthLerp;
	}

	function set_healthLerp(v:Float):Float
	{
		_healthLerpTouched = true;
		return _healthLerp = v;
	}

	// ---- 图标/条/字：逐次取 PlayState 同名字段
	public var iconP1(get, never):Dynamic;
	public var iconP2(get, never):Dynamic;
	public var scoreTxt(get, never):Dynamic;
	public var timeBar(get, never):Dynamic;
	public var timeTxt(get, never):Dynamic;

	// healthBar 可写：finaleUI.hx:72 `playHUD.healthBar = newBar`（kill 旧条换终局条），
	// getter 优先返回脚本设置的替换值，读不到再取 PlayState 的
	var _healthBarOverride:Dynamic = null;

	public var healthBar(get, set):Dynamic;

	function get_healthBar():Dynamic
	{
		if (_healthBarOverride != null) return _healthBarOverride;
		return PlayState.instance == null ? null : PlayState.instance.healthBar;
	}

	function set_healthBar(v:Dynamic):Dynamic
	{
		return _healthBarOverride = v;
	}

	function get_iconP1():Dynamic
	{
		return PlayState.instance == null ? null : PlayState.instance.iconP1;
	}

	function get_iconP2():Dynamic
	{
		return PlayState.instance == null ? null : PlayState.instance.iconP2;
	}

	function get_scoreTxt():Dynamic
	{
		return PlayState.instance == null ? null : PlayState.instance.scoreTxt;
	}

	function get_timeBar():Dynamic
	{
		return PlayState.instance == null ? null : PlayState.instance.timeBar;
	}

	function get_timeTxt():Dynamic
	{
		// PlayState.timeTxt 是私有字段，走 Reflect 绕过访问控制
		return PlayState.instance == null ? null : Reflect.getProperty(PlayState.instance, 'timeTxt');
	}

	// ---- 组容器面：PsychHUD 是 FlxSpriteGroup，脚本往 HUD 层 add/insert。
	// FE 的 HUD 元素全在 uiGroup，直接转发。
	public var members(get, never):Array<Dynamic>;

	function get_members():Array<Dynamic>
	{
		return PlayState.instance == null ? [] : cast PlayState.instance.uiGroup.members;
	}

	public function add(obj:Dynamic):Dynamic
	{
		if (PlayState.instance != null && obj != null)
			PlayState.instance.uiGroup.add(obj);
		return obj;
	}

	public function insert(index:Int, obj:Dynamic):Dynamic
	{
		if (PlayState.instance != null && obj != null)
			PlayState.instance.uiGroup.insert(index, obj);
		return obj;
	}

	/** defeat/script.hx 调用；NMV 里重排图标位置，FE 侧无对应行为，空实现保链路不断。 */
	public function updateIconsPosition():Void {}

	/** 换歌时清会话内存（单例被 NMVSciptHolder.destroy 调）。 */
	public function resetSession():Void
	{
		_healthBarOverride = null;
		_healthLerp = 1;
		_healthLerpTouched = false;
	}
}
