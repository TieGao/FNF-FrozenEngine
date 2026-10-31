package nmv.objects;

/**
 * NMV PlayState.audio（PlayableSong, SyncedFlxSoundGroup）的 FE 映射。
 * 语料用面（2026-10-31 全包扫描）：
 *  - audio.songLength（读，defeat/airship/turbulence）→ PlayState.songLength（= inst 长度，ms）
 *  - audio.inst（读对象，tween .volume defeat）→ FlxG.sound.music
 *  - audio.playerVolume / audio.opponentVolume（写，defeat/airship 终局静音）→ 对应 vocals 轨音量
 * 此前无映射，turbulence 的 onUpdatePost 每帧 resolve('audio') 抛 EUnknownVariable（刷屏根源之一）。
 */
class NmvAudioShim
{
	public function new() {}

	public var songLength(get, never):Float;

	function get_songLength():Float
	{
		return PlayState.instance == null ? 0 : PlayState.instance.songLength;
	}

	public var inst(get, never):Dynamic;

	function get_inst():Dynamic
	{
		return flixel.FlxG.sound.music;
	}

	public var playerVolume(get, set):Float;

	function get_playerVolume():Float
	{
		return PlayState.instance?.vocals?.volume ?? 0;
	}

	function set_playerVolume(v:Float):Float
	{
		if (PlayState.instance?.vocals != null) PlayState.instance.vocals.volume = v;
		return v;
	}

	public var opponentVolume(get, set):Float;

	function get_opponentVolume():Float
	{
		return PlayState.instance?.opponentVocals?.volume ?? 0;
	}

	function set_opponentVolume(v:Float):Float
	{
		if (PlayState.instance?.opponentVocals != null) PlayState.instance.opponentVocals.volume = v;
		return v;
	}
}
