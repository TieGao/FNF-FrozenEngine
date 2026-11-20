package states.editors.content;

import flixel.util.FlxSave;

enum abstract EditorAudioTheme(String)
{
	var PSYCH = 'psych';
	var FUNKIN = 'funkin';
}

/**
 * 谱面编辑器音频状态：六路音量、静音记忆、音频主题。
 * 索引固定为 INST=0 / PLAYER_VOC=1 / OPP_VOC=2 / METRONOME=3 / HIT_PLAYER=4 / HIT_OPP=5。
 * 音量与静音在切换静音时互相配合：静音记下最后一个非 0 值，取消静音恢复它。
 */
class EditorAudioState
{
	public static inline var CH_INST:Int = 0;
	public static inline var CH_PLAYER:Int = 1;
	public static inline var CH_OPPONENT:Int = 2;
	public static inline var CH_METRONOME:Int = 3;
	public static inline var CH_HIT_PLAYER:Int = 4;
	public static inline var CH_HIT_OPPONENT:Int = 5;
	public static inline var CHANNEL_COUNT:Int = 6;

	static var defaults:Array<Float> = [0.6, 1, 1, 0.2, 0.2, 0.2];
	static var volumes:Array<Float> = [0.6, 1, 1, 0.2, 0.2, 0.2];
	static var prevVolumes:Array<Float> = [0.6, 1, 1, 0.2, 0.2, 0.2];
	static var muted:Array<Bool> = [false, false, false, false, false, false];

	public static var theme:EditorAudioTheme = PSYCH;

	public static function load(save:FlxSave):Void
	{
		if (save == null || save.data == null) return;

		theme = save.data.audioTheme == FUNKIN ? FUNKIN : PSYCH;

		var savedVol:Array<Dynamic> = save.data.editorVolumes;
		var savedPrev:Array<Dynamic> = save.data.editorPrevVolumes;
		var savedMute:Array<Dynamic> = save.data.editorMuted;

		for (i in 0...CHANNEL_COUNT)
		{
			var v:Float = savedVol != null && i < savedVol.length ? savedVol[i] : defaults[i];
			volumes[i] = clamp(v);
			prevVolumes[i] = clamp(savedPrev != null && i < savedPrev.length && savedPrev[i] > 0 ? savedPrev[i] : (v > 0 ? v : defaults[i]));
			muted[i] = savedMute != null && i < savedMute.length ? savedMute[i] : false;
		}
	}

	public static function save(save:FlxSave):Void
	{
		if (save == null || save.data == null) return;
		save.data.audioTheme = theme;
		save.data.editorVolumes = volumes.copy();
		save.data.editorPrevVolumes = prevVolumes.copy();
		save.data.editorMuted = muted.copy();
	}

	static function clamp(v:Float):Float
	{
		return v < 0 ? 0 : (v > 1 ? 1 : v);
	}

	public static function getVolume(index:Int):Float
	{
		return volumes[index];
	}

	public static function effectiveVolume(index:Int):Float
	{
		return muted[index] ? 0 : volumes[index];
	}

	public static function setVolume(index:Int, value:Float):Void
	{
		var v:Float = clamp(value);
		volumes[index] = v;
		if (v > 0) prevVolumes[index] = v;
	}

	public static function isMuted(index:Int):Bool
	{
		return muted[index];
	}

	public static function setMuted(index:Int, value:Bool):Void
	{
		if (muted[index] == value) return;
		muted[index] = value;
		if (value)
			volumes[index] = 0;
		else
			volumes[index] = prevVolumes[index] > 0 ? prevVolumes[index] : defaults[index];
	}

	public static function toggleMute(index:Int):Bool
	{
		setMuted(index, !muted[index]);
		return muted[index];
	}

	public static function setTheme(value:EditorAudioTheme):Void
	{
		theme = value;
	}

	public static function isFunkin():Bool
	{
		return theme == FUNKIN;
	}

	/** 返回当前主题下的节拍器音色 key；accent=重拍 */
	public static function metronomeSound(accent:Bool):String
	{
		return theme == FUNKIN ? (accent ? 'metronome-1' : 'metronome-2') : 'Metronome_Tick';
	}

	/** 返回当前主题下的打击声 key；player=玩家轨 */
	public static function hitSound(player:Bool):String
	{
		return theme == FUNKIN ? (player ? 'hitsound-player' : 'hitsound-opponent') : ClientPrefs.data.hitsound;
	}
}
