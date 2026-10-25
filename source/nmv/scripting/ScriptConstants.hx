package nmv.scripting;

import flixel.FlxState;
import states.PlayState;
import substates.GameOverSubstate;

/**
 * 脚本与 State 交互用的返回值常量。
 */
class ScriptConstants
{
	/** 脚本函数返回它时，正常行为中止。 */
	public static final STOP_FUNC:Int = 1;

	/** 常规返回，ScriptGroup 继续调用后续脚本。 */
	public static final CONTINUE_FUNC:Int = 0;

	/** ScriptGroup 收到它时，不再对剩余脚本调用该函数。 */
	public static final HALT_FUNC:Int = 2;

	/** 取当前 State；在 PlayState 且已死亡时返回 GameOverSubstate。 */
	public static inline function getInstance():FlxState
	{
		return PlayState.instance == null ? FlxG.state : PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
	}
}
