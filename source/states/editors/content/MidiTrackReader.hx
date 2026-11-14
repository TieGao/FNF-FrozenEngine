package states.editors.content;

import haxe.io.Bytes;
import moonchart.backend.Util;
import moonchart.formats.BasicFormat.BasicBPMChange;

/**
 * 独立 SMF(.mid) 读取器：按「轨道 + 通道」拆声部，配对 note on/off，tick → 毫秒。
 *
 * 为什么不用 moonchart 的 Midi：它的 getNotes 拿完整 status 字节（含通道号）直接跟 0x90 比，
 * 只有 1 号通道的音符能读到，其余通道静默丢弃；且 lastTick 全局只有一个槽位，
 * 和弦会互相顶掉。这里自己解析 SMF，通道/音色/轨道名都保留下来供「选轨」使用。
 *
 * 纯数据，不引用引擎类型（除 BasicBPMChange，用于直接把速度表交给 buildSong）。
 */
class MidiTrackReader
{
	/** 每个四分音符的 tick 数（SMPTE 时令其为 ticksPerFrame * fps 的近似值，仅用于 hold 阈值） */
	public var division:Int = 96;
	/** 疑似 SMPTE 时长（ms/tick），非 0 时忽略速度表 */
	public var smpteMsPerTick:Float = 0;
	/** 速度表（按 tick 升序，同一 tick 只留最后一条） */
	public var tempos:Array<MidiTempo> = [];
	/** 所有声部（文件顺序，`sortedParts()` 之后带优先级字段） */
	public var parts:Array<MidiPart> = [];

	private var sorted:Array<MidiPart> = null;

	public static function fromFile(path:String):MidiTrackReader
	{
		var bytes:Bytes = Util.getBytes(path);
		if(bytes == null) throw 'Unable to read MIDI file: $path';
		return new MidiTrackReader(bytes);
	}

	public function new(bytes:Bytes)
	{
		if(bytes == null || bytes.length < 14) throw 'Invalid MIDI file';

		if(bytes.getString(0, 4) != 'MThd') throw 'Invalid MIDI header';
		var headerLength:Int = readInt32BE(bytes, 4);
		var trackCount:Int = readUInt16BE(bytes, 10);
		var rawDivision:Int = readUInt16BE(bytes, 12);

		if((rawDivision & 0x8000) != 0)
		{
			// SMPTE：高字节是负的帧率，低字节是每帧 tick 数
			var fps:Int = 256 - ((rawDivision >> 8) & 0xFF);
			var ticksPerFrame:Int = rawDivision & 0xFF;
			if(fps > 0 && ticksPerFrame > 0)
			{
				smpteMsPerTick = 1000.0 / (fps * ticksPerFrame);
				division = ticksPerFrame * fps;
			}
		}
		else if(rawDivision > 0) division = rawDivision;

		var pos:Int = 8 + headerLength;
		for(t in 0...trackCount)
		{
			if(pos + 8 > bytes.length) break;
			var chunk:String = bytes.getString(pos, 4);
			var length:Int = readInt32BE(bytes, pos + 4);
			pos += 8;
			if(chunk == 'MTrk' && length > 0 && pos + length <= bytes.length)
				parseTrack(bytes, pos, length, t);
			pos += length;
		}

		cleanTempos();
		for(part in parts)
			part.notes.sort(function(a:MidiNote, b:MidiNote) return a.startTick - b.startTick);
	}

	// ====================================================
	//  解析
	// ====================================================

	private var _pos:Int = 0;

	private function parseTrack(bytes:Bytes, start:Int, length:Int, trackIndex:Int):Void
	{
		var end:Int = start + length;
		_pos = start;

		var tick:Int = 0;
		var status:Int = 0;
		var trackName:String = '';
		var programByCh:Map<Int, Int> = new Map();
		// 未闭合的 note on，按 (通道, 音高) 排队 —— 同音高重叠时先按先进先出配对
		var pending:Map<Int, Array<MidiNote>> = new Map();
		var partByCh:Map<Int, MidiPart> = new Map();

		while(_pos < end)
		{
			var delta:Int = readVLQ(bytes, end);
			tick += delta;
			if(_pos >= end) break;

			var flag:Int = bytes.get(_pos);
			var data:Int;

			if(flag >= 0xF0)
			{
				_pos++;
				if(flag == 0xFF)
				{
					if(_pos >= end) break;
					var metaType:Int = bytes.get(_pos++);
					var metaLength:Int = readVLQ(bytes, end);
					if(metaType == 0x2F) break; // end of track
					if(metaType == 0x51 && metaLength >= 3 && _pos + 3 <= end)
					{
						var us:Int = (bytes.get(_pos) << 16) | (bytes.get(_pos + 1) << 8) | bytes.get(_pos + 2);
						// 表情/装饰性速度（<=0）直接忽略，避免后面除零
						if(us > 0) tempos.push({tick: tick, usPerQuarter: us});
					}
					else if(metaType == 0x03 && trackName.length == 0 && metaLength > 0 && _pos + metaLength <= end)
						trackName = bytes.getString(_pos, metaLength);
					_pos += metaLength;
				}
				else
				{
					// sysex / escape
					var sysLength:Int = readVLQ(bytes, end);
					_pos += sysLength;
				}
				continue;
			}

			if(flag >= 0x80)
			{
				status = flag;
				_pos++;
				data = bytes.get(_pos);
			}
			else data = flag; // running status：沿用上一个 status，指针不回退

			var hi:Int = status & 0xF0;
			var ch:Int = status & 0x0F;

			switch(hi)
			{
				case 0x80, 0x90:
					if(_pos + 1 >= end) break;
					var pitch:Int = data;
					var velocity:Int = bytes.get(_pos + 1);
					_pos += 2;
					var key:Int = (ch << 8) | pitch;

					if(hi == 0x90 && velocity > 0)
					{
						var queue:Array<MidiNote> = pending.get(key);
						if(queue == null)
						{
							queue = [];
							pending.set(key, queue);
						}
						queue.push({startTick: tick, endTick: tick, pitch: pitch, velocity: velocity});
					}
					else
					{
						var queue:Array<MidiNote> = pending.get(key);
						if(queue != null && queue.length > 0)
						{
							var note:MidiNote = queue.shift();
							note.endTick = tick;
							var part:MidiPart = partByCh.get(ch);
							if(part == null)
							{
								part = new MidiPart(trackIndex, ch);
								partByCh.set(ch, part);
								parts.push(part);
							}
							part.addNote(note);
						}
					}
				case 0xA0, 0xB0, 0xE0:
					_pos += 2;
				case 0xC0:
					if(!programByCh.exists(ch)) programByCh.set(ch, data);
					_pos += 1;
				case 0xD0:
					_pos += 1;
				default:
					_pos += 1;
			}
		}

		for(ch => part in partByCh)
		{
			var program:Null<Int> = programByCh.get(ch);
			part.program = (program != null) ? program : -1;
			part.name = trackName;
			part.isPercussion = (ch == 9);
		}
	}

	/** 变长数量（MIDI 的 7 位小端编码）；越界时返回 0，由调用方的 `_pos < end` 兜住 */
	private function readVLQ(bytes:Bytes, end:Int):Int
	{
		var value:Int = 0;
		var b:Int = 0;
		var guard:Int = 0;
		do
		{
			if(_pos >= end) return value;
			b = bytes.get(_pos++);
			value = (value << 7) | (b & 0x7F);
			guard++;
		} while((b & 0x80) != 0 && guard < 4);
		return value;
	}

	private static function readUInt16BE(bytes:Bytes, pos:Int):Int
	{
		return (bytes.get(pos) << 8) | bytes.get(pos + 1);
	}

	private static function readInt32BE(bytes:Bytes, pos:Int):Int
	{
		return bytes.get(pos) * 16777216 + (bytes.get(pos + 1) << 16) + (bytes.get(pos + 2) << 8) + bytes.get(pos + 3);
	}

	/** 同一 tick 的多条速度只保留最后一条（导出软件常在 0 点重复写） */
	private function cleanTempos():Void
	{
		if(tempos.length == 0) return;
		tempos.sort(function(a:MidiTempo, b:MidiTempo) return a.tick - b.tick);
		var merged:Array<MidiTempo> = [tempos[0]];
		for(i in 1...tempos.length)
		{
			var cur:MidiTempo = tempos[i];
			if(cur.tick == merged[merged.length - 1].tick) merged[merged.length - 1] = cur;
			else merged.push(cur);
		}
		tempos = merged;
	}

	// ====================================================
	//  时间换算
	// ====================================================

	public function msAt(tick:Float):Float
	{
		if(smpteMsPerTick > 0) return tick * smpteMsPerTick;
		if(tempos.length == 0) return tick * (60000.0 / 120.0) / division;

		var ms:Float = 0;
		var lastTick:Int = 0;
		var us:Int = 500000;
		for(t in tempos)
		{
			if(t.tick > tick) break;
			ms += (t.tick - lastTick) * (us / 1000.0) / division;
			lastTick = t.tick;
			us = t.usPerQuarter;
		}
		return ms + (tick - lastTick) * (us / 1000.0) / division;
	}

	/** 送给 buildSong 的速度表（毫秒时间轴，4/4） */
	public function bpmChanges():Array<BasicBPMChange>
	{
		var changes:Array<BasicBPMChange> = [];
		if(tempos.length == 0 || tempos[0].tick > 0)
			changes.push({time: 0, bpm: 120, beatsPerMeasure: 4, stepsPerBeat: 4});

		for(t in tempos)
		{
			var bpm:Float = 60000000.0 / t.usPerQuarter;
			if(bpm <= 0) continue;
			var time:Float = msAt(t.tick);
			// 同一时间点的变速交给 buildSong 去重，这里只过滤数值重复
			if(changes.length > 0)
			{
				var prev:BasicBPMChange = changes[changes.length - 1];
				if(Math.abs(prev.bpm - bpm) < 0.001 && Math.abs(prev.time - time) < 0.01) continue;
			}
			changes.push({time: time, bpm: bpm, beatsPerMeasure: 4, stepsPerBeat: 4});
		}
		return changes;
	}

	// ====================================================
	//  优先级排序
	// ====================================================

	/**
	 * 按「重要程度」排序后返回（结果缓存）：
	 *  - 组内顺序：常规乐器 → 疑似回声副本 → 音效 → 打击乐（鼓永远垫底）
	 *  - 常规组内按 `覆盖时长 × 音色权重` 降序，再按音符数降序
	 */
	public function sortedParts():Array<MidiPart>
	{
		if(sorted != null) return sorted;

		var list:Array<MidiPart> = [];
		for(part in parts)
			if(part.notes.length > 0) list.push(part);

		var totalMs:Float = 0;
		for(part in list)
		{
			part.startMs = msAt(part.startTick);
			part.endMs = msAt(part.endTick);
			if(part.endMs > totalMs) totalMs = part.endMs;
		}
		if(totalMs <= 0) totalMs = 1;

		for(part in list)
		{
			var coverage:Float = (part.endMs - part.startMs) / totalMs;
			if(coverage < 0) coverage = 0;
			if(coverage > 1) coverage = 1;
			var fam = familyInfo(part.program);
			// 打击乐通道（GM ch10）的音色号不可信，直接归到鼓组
			part.family = part.isPercussion ? 'Drums' : fam.name;
			// 音色权重比覆盖时长更能代表"这条该排前面"，覆盖率只用来在同族之间分先后
			part.score = coverage * (0.45 + 0.55 * fam.weight);
			part.group = part.isPercussion ? 3 : (fam.weight <= 0.21 ? 2 : 0);
		}

		// 回声 / 复制轨：音高序列一致、整体错开不到 500ms。不标出来会让人误选，
		// 选了两条就是整首歌每个音符打两遍。
		for(i in 0...list.length)
		{
			var cur:MidiPart = list[i];
			if(cur.group != 0) continue;
			for(j in 0...i)
			{
				var ref:MidiPart = list[j];
				if(ref.group != 0 || ref.echo) continue;
				if(isEchoOf(cur, ref))
				{
					cur.echo = true;
					cur.group = 1;
					break;
				}
			}
		}

		list.sort(function(a:MidiPart, b:MidiPart)
		{
			if(a.group != b.group) return a.group - b.group;
			if(Math.abs(a.score - b.score) > 0.0001) return (a.score > b.score) ? -1 : 1;
			if(a.notes.length != b.notes.length) return b.notes.length - a.notes.length;
			if(a.track != b.track) return a.track - b.track;
			return a.channel - b.channel;
		});

		sorted = list;
		return sorted;
	}

	private function isEchoOf(a:MidiPart, b:MidiPart):Bool
	{
		if(a.notes.length != b.notes.length || a.notes.length == 0) return false;
		if(a.pitchMin != b.pitchMin || a.pitchMax != b.pitchMax) return false;

		var step:Int = Std.int(Math.max(1, Math.floor(a.notes.length / 16)));
		var i:Int = 0;
		while(i < a.notes.length)
		{
			if(a.notes[i].pitch != b.notes[i].pitch) return false;
			i += step;
		}

		var offsetMs:Float = Math.abs(a.startMs - b.startMs);
		return offsetMs <= 500;
	}

	/** GM 音色族 → 组名 + 权重（权重只影响排序：旋律类靠前，音效类靠后） */
	public static function familyInfo(program:Int):{name:String, weight:Float}
	{
		if(program < 0) return {name: 'Unknown', weight: 0.10};
		if(program < 8) return {name: 'Piano', weight: 0.90};
		if(program < 16) return {name: 'Chromatic', weight: 0.60};
		if(program < 24) return {name: 'Organ', weight: 0.65};
		if(program < 32) return {name: 'Guitar', weight: 0.95};
		if(program < 40) return {name: 'Bass', weight: 0.50};
		if(program < 48) return {name: 'Strings', weight: 0.75};
		if(program < 56) return {name: 'Ensemble', weight: 0.70};
		if(program < 64) return {name: 'Brass', weight: 0.80};
		if(program < 80) return {name: 'Wind', weight: 0.85};
		if(program < 88) return {name: 'Lead', weight: 1.00};
		if(program < 96) return {name: 'Pad', weight: 0.45};
		if(program < 104) return {name: 'FX', weight: 0.20};
		if(program < 112) return {name: 'Ethnic', weight: 0.40};
		if(program < 120) return {name: 'Percussive', weight: 0.30};
		return {name: 'SFX', weight: 0.10};
	}
}

typedef MidiTempo =
{
	var tick:Int;
	var usPerQuarter:Int;
}

typedef MidiNote =
{
	var startTick:Int;
	var endTick:Int;
	var pitch:Int;
	var velocity:Int;
}

/** 一个声部 = 一条 MIDI 轨道里的一个通道（通道决定音色，轨道只是文件结构） */
class MidiPart
{
	/** 稳定标识（track * 16 + channel），导入时按它挑选 */
	public var id:Int = 0;
	public var track:Int = 0;
	public var channel:Int = 0;
	public var program:Int = -1;
	public var name:String = '';
	public var notes:Array<MidiNote> = [];
	public var pitchMin:Int = 0;
	public var pitchMax:Int = 0;
	public var startTick:Int = 0;
	public var endTick:Int = 0;
	public var startMs:Float = 0;
	public var endMs:Float = 0;
	public var family:String = 'Unknown';
	public var isPercussion:Bool = false;
	/** 与前面某条音高序列一致、只整体错开时间（导出软件的回声/复制轨） */
	public var echo:Bool = false;
	/** 排序分组：0 常规 / 1 回声 / 2 音效 / 3 打击乐 */
	public var group:Int = 0;
	public var score:Float = 0;

	public function new(track:Int, channel:Int)
	{
		this.track = track;
		this.channel = channel;
		this.id = track * 16 + channel;
	}

	public function addNote(note:MidiNote):Void
	{
		if(notes.length == 0)
		{
			pitchMin = note.pitch;
			pitchMax = note.pitch;
			startTick = note.startTick;
			endTick = note.endTick;
		}
		else
		{
			if(note.pitch < pitchMin) pitchMin = note.pitch;
			if(note.pitch > pitchMax) pitchMax = note.pitch;
			if(note.startTick < startTick) startTick = note.startTick;
			if(note.endTick > endTick) endTick = note.endTick;
		}
		notes.push(note);
	}
}
