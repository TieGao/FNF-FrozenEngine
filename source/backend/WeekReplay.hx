package backend;

import states.PlayState;
import states.StoryMenuState;
import states.LoadingState;

/**
 * 全周回放队列（纯 static 状态）。
 *
 * 流程：StoryMode 的 Replay 块 → WeekReplaySubState 选齐每首歌的回放 → start()
 *      → startFromMenu() 播第一首 → 每首结束由 PlayState.proceedToNextState() 调 advance()
 *      → 播完 finish() 回 StoryMode（**不写任何成绩**）。
 *
 * 关键约定：
 *  - 只写 PlayState.pendingReplay，绝不写 frameRep（旧 state 的 destroy() 会清掉）。
 *  - 回放播放期间 PlayState.isStoryMode = false，所以周目存档分支进不去。
 *  - 中途退出走 abort()：只清状态 + 还原玩家设置，不切 state。
 */
class WeekReplay
{
	public static var active:Bool = false;

	/** fullPath（assets/replays/...），按周内歌曲顺序 */
	public static var queue:Array<String> = [];
	/** 与 queue 对齐的歌名，显示用 */
	public static var songs:Array<String> = [];

	public static var index:Int = 0;
	public static var weekFile:String = null;
	public static var weekIndex:Int = -1;
	public static var difficulty:Int = 1;
	public static var contentRoot:String = null;
	public static var variant:String = null;

	static var prevDownScroll:Null<Bool> = null;

	public static function start(paths:Array<String>, songNames:Array<String>, weekFile:String, weekIndex:Int,
			difficulty:Int, ?contentRoot:String, ?variant:String):Void
	{
		clear();

		queue = paths.copy();
		songs = songNames.copy();
		index = 0;
		active = queue.length > 0;

		WeekReplay.weekFile = weekFile;
		WeekReplay.weekIndex = weekIndex;
		WeekReplay.difficulty = difficulty;
		WeekReplay.contentRoot = (contentRoot != null && contentRoot.length > 0) ? contentRoot : null;
		WeekReplay.variant = (variant != null && variant.length > 0) ? variant : null;

		prevDownScroll = ClientPrefs.data.downScroll;
	}

	public static function isActive():Bool
	{
		return active;
	}

	/** 第一首：走常规 LoadingState 过渡（和从菜单进歌一致）。 */
	public static function startFromMenu():Void
	{
		boot(false);
	}

	/** 每首回放结束由 PlayState.proceedToNextState() 调。 */
	public static function advance():Void
	{
		index++;
		boot(true);
	}

	static function boot(skipTransition:Bool):Void
	{
		// 坏档不炸整条链：跳过继续下一首
		while (index >= 0 && index < queue.length)
		{
			var err:Null<String> = ReplayLauncher.prepare(queue[index], {
				forcedDifficulty: difficulty,
				fallbackContentRoot: contentRoot,
				fallbackVariant: variant,
				weekIndex: weekIndex,
				storyMode: false,
				applyDownscroll: false // 不逐首改玩家的下滚设置
			});

			if (err == null) break;

			trace('[WeekReplay] skip broken replay: ' + queue[index] + ' -> ' + err);
			index++;
		}

		if (index >= queue.length)
		{
			finish();
			return;
		}

		if (skipTransition)
		{
			// 与 story 连播同款：跳过淡入淡出，直接进下一首
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			LoadingState.loadAndSwitchState(new PlayState(), false, false);
		}
		else
		{
			LoadingState.loadAndSwitchState(new PlayState());
		}
	}

	static function finish():Void
	{
		var restore:Null<Bool> = prevDownScroll;
		clear();
		if (restore != null) ClientPrefs.data.downScroll = restore;

		// 必须把回放静态复位：proceedToNextState 的清理块被我们 early-return 跳过了，
		// 不清的话下一首正常游玩会带着 inReplay=true，endSong 不写成绩。
		resetReplayStatics();

		if (PlayState.instance != null)
			PlayState.instance.canResync = false;
		PlayState.changedDifficulty = false;

		Mods.loadTopMod();
		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
		FlxG.sound.playMusic(Paths.music('freakyMenu'));
		MusicBeatState.switchState(new StoryMenuState());
	}

	/** 中途退出（暂停 → 退出到菜单）：只清状态 + 还原设置，不切 state。 */
	public static function abort():Void
	{
		var restore:Null<Bool> = prevDownScroll;
		clear();
		if (restore != null) ClientPrefs.data.downScroll = restore;
		resetReplayStatics();
	}

	static function resetReplayStatics():Void
	{
		PlayState.pendingReplay = null;
		PlayState.loadRep = false;
		PlayState.inReplay = false;
		PlayState.frameRep = null;
		PlayState.replayFileName = null;
	}

	static function clear():Void
	{
		active = false;
		queue = [];
		songs = [];
		index = 0;
		weekFile = null;
		weekIndex = -1;
		difficulty = 1;
		contentRoot = null;
		variant = null;
		prevDownScroll = null;
	}
}
