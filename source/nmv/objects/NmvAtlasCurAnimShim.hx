package nmv.objects;

/**
 * NMV 脚本面的 atlas 角色 `animation.curAnim` 薄适配。
 *
 * 背景：FE 对 atlas 角色 `animation.curAnim` 恒 null（动画全走 atlas.anim.play，共享
 * flixel 库不动），而 NMV 引擎的动画控制器是统一面。语料脚本直接读该面——danger.hx /
 * bf-running.hx 每帧 `animation.curAnim.curFrame = ... / numFrames`、bf-running 还读
 * `.looped` / 调 `.pause()`——port 上每帧炸 "Invalid access to field numFrames"
 * （2026-10-31 bread.log 实测各 ×573，onUpdate 整段中断 = 腿部帧同步全失效）。
 *
 * 面 = 语料实测用到的字段子集，全部委托给 flxanimate 4.0.0 的 FlxAnim 控制器：
 * name→curInstance.symbol.name、numFrames→length（=curSymbol timeline.totalFrames）、
 * curFrame→curFrame（get/set，Loop 语义在控制器内做取模）、looped→loopType==Loop、
 * finished→finished、paused→!isPlaying；pause()/resume() 直转。
 * 每次访问现建一个（无状态、只包引用），不做实例缓存。
 */
class NmvAtlasCurAnimShim
{
	public var anim:flxanimate.animate.FlxAnim;

	public function new(anim:flxanimate.animate.FlxAnim)
	{
		this.anim = anim;
	}

	inline function nullAnim():Bool
		return anim == null || anim.curInstance == null || anim.curSymbol == null;

	public var name(get, never):String;

	inline function get_name():String
		return nullAnim() ? '' : anim.curInstance.symbol.name;

	public var numFrames(get, never):Int;

	inline function get_numFrames():Int
		return nullAnim() ? 0 : anim.length;

	public var curFrame(get, set):Int;

	inline function get_curFrame():Int
		return nullAnim() ? 0 : anim.curFrame;

	inline function set_curFrame(v:Int):Int
	{
		if (nullAnim()) return 0;
		anim.curFrame = v;
		return anim.curFrame;
	}

	/** 当前动画是否循环（`enum Loop { Loop; }` 与构造器同名，按批次 8 教训用字符串比较）。 */
	public var looped(get, never):Bool;

	inline function get_looped():Bool
		return anim != null && Std.string(anim.loopType) == 'Loop';

	public var finished(get, never):Bool;

	inline function get_finished():Bool
		return nullAnim() ? false : anim.finished;

	public var paused(get, never):Bool;

	inline function get_paused():Bool
		return anim == null ? true : !anim.isPlaying;

	public function pause():Void
		if (anim != null) anim.pause();

	public function resume():Void
		if (anim != null) anim.resume();
}
