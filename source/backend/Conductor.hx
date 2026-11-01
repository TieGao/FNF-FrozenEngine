package backend;

import backend.Song;
import objects.Note;

typedef BPMChangeEvent =
{
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
	@:optional var stepCrochet:Float;
}

class Conductor
{
	public static var bpm(default, set):Float = 100;
	public static var crochet:Float = ((60 / bpm) * 1000); // beats in milliseconds
	public static var stepCrochet:Float = crochet / 4; // steps in milliseconds
	/**
	 * NMV 拼写（多一个 t）：NMV 的 `funkin.backend.Conductor` 里就叫 `crotchet` / `stepCrotchet`，
	 * Psych/FE 才写成 `crochet`。语料脚本直接读这两个名字（`.hx` 里 31 + 7 处），
	 * 而 HScript 的字段读取是 `Reflect.getProperty` —— **缺字段静默返回 null，不报错**，
	 * 于是 `(Conductor.crotchet * 28) / 1000` 得到 0。
	 *
	 * 后果（2026-11-01 实测，Torture 全程黑屏的真因）：`FlxTween.start()`（flixel 6.2
	 * `FlxTween.hx:675`）对 `duration == 0` 是 `active = false; return this;` —— 补间
	 * **永不更新、onComplete 永不触发**。warehouse.hx:152 的黑幕 `startDark`
	 * （alpha 1 的 FlxBGSprite，zIndex 5 盖满全屏）就永远淡不出去也不会被 destroy，
	 * 而 ziffy 的开场动画 zIndex 同为 5 且后 add，所以正好"开局有动画、之后全黑"。
	 * 同一根因还让 attack/chef/greenhouse/polus/pretender/victory 的 `fakeStartTimer`
	 * 时长变成 0（假倒计时被瞬间跳过）、warehouse 的刀片/血条/razebud/bye 补间全部无效。
	 *
	 * 值只由 `set_bpm` 同步（那是 `crochet`/`stepCrochet` 的唯一赋值点）。
	 */
	public static var crotchet:Float = crochet;
	/** NMV 拼写，见 `crotchet`。 */
	public static var stepCrotchet:Float = stepCrochet;
	public static var songPosition:Float = 0;
	public static var offset:Float = 0;

	//public static var safeFrames:Int = 10;
	public static var safeZoneOffset:Float = 0; // is calculated in create(), is safeFrames in milliseconds

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];

	public static function judgeNote(arr:Array<Rating>, diff:Float=0):Rating // die
	{
		var data:Array<Rating> = arr;
		for(i in 0...data.length-1) //skips last window (Shit)
			if (diff <= data[i].hitWindow)
				return data[i];

		return data[data.length - 1];
	}

	public static function getCrotchetAtTime(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepCrochet*4;
	}

	public static function getBPMFromSeconds(time:Float){
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: stepCrochet
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (time >= Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
		}

		return lastChange;
	}

	public static function getBPMFromStep(step:Float){
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: stepCrochet
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (Conductor.bpmChangeMap[i].stepTime<=step)
				lastChange = Conductor.bpmChangeMap[i];
		}

		return lastChange;
	}

	public static function beatToSeconds(beat:Float): Float{
		var step = beat * 4;
		var lastChange = getBPMFromStep(step);
		return lastChange.songTime + ((step - lastChange.stepTime) / (lastChange.bpm / 60)/4) * 1000; // TODO: make less shit and take BPM into account PROPERLY
	}

	public static function getStep(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + (time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getStepRounded(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + Math.floor(time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getBeat(time:Float){
		return getStep(time)/4;
	}

	public static function getBeatRounded(time:Float):Int{
		return Math.floor(getStepRounded(time)/4);
	}

	public static function mapBPMChanges(song:SwagSong)
	{
		bpmChangeMap = [];

		var curBPM:Float = song.bpm;
		var totalSteps:Int = 0;
		var totalPos:Float = 0;
		for (i in 0...song.notes.length)
		{
			if(song.notes[i].changeBPM && song.notes[i].bpm != curBPM)
			{
				curBPM = song.notes[i].bpm;
				var event:BPMChangeEvent = {
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM,
					stepCrochet: calculateCrochet(curBPM)/4
				};
				bpmChangeMap.push(event);
			}

			var deltaSteps:Int = Math.round(getSectionBeats(song, i) * 4);
			totalSteps += deltaSteps;
			totalPos += ((60 / curBPM) * 1000 / 4) * deltaSteps;
		}
		trace("new BPM map BUDDY " + bpmChangeMap);
	}

	static function getSectionBeats(song:SwagSong, section:Int)
	{
		var val:Null<Float> = null;
		if(song.notes[section] != null) val = song.notes[section].sectionBeats;
		return val != null ? val : 4;
	}

	inline public static function calculateCrochet(bpm:Float){
		return (60/bpm)*1000;
	}

	public static function set_bpm(newBPM:Float):Float {
		bpm = newBPM;
		crochet = calculateCrochet(bpm);
		stepCrochet = crochet / 4;
		// NMV 拼写别名（唯一赋值点，见 `crotchet` 字段上的注释）
		crotchet = crochet;
		stepCrotchet = stepCrochet;

		return bpm = newBPM;
	}
}