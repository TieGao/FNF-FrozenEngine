package states.editors.content;

import flash.net.FileFilter;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

/**
 * 分步向导式音频导入底座（Open Chart / Import Chart / New Song 共用）。
 *
 * 只负责：弹「Inst → Player Vocals → Opponent Vocals」三步文件选择框，
 * 把用户选到的音频复制成目标目录里的 inst.<ext> / voices-player.<ext> / voices-opponent.<ext>，
 * 然后通过 onDone 回报落地结果。
 *
 * 【重要】本类不写任何 Paths.current* 全局字段，也不碰调用方的 FileDialogHandler。
 * 调用方须在 onDone 里自行登记目录（setChartDirectoryFromPath / Paths.setChartContext）
 * 再 loadChart / prepareReload，才不会覆盖调用方自己的 category/variant 上下文。
 *
 * 自带一个私有 FileDialogHandler 实例，与 ChartingState.fileDialog 隔离。
 * onDone 保证恰好回调一次（含全跳过 / 复制失败 / 非 sys 平台降级）。
 */
typedef ChartAudioImportResult = {
	/** 规范化后的落地目录（结尾带 '/'） */
	var targetDir:String;
	/** 落地后的 inst 文件绝对路径；未导入为 null */
	var instPath:Null<String>;
	/** 落地后的 player vocals 文件；未导入为 null */
	var playerVocalPath:Null<String>;
	/** 落地后的 opponent vocals 文件；未导入为 null */
	var opponentVocalPath:Null<String>;
	/** 三者至少一个成功 */
	var anyImported:Bool;
	/** 目标目录里最终是否有可用 Inst（含 osz 已自动落地的情况）；false 时调用方应拦截打开 */
	var hasInst:Bool;
}

class ChartAudioImportWizard
{
	/** 谱面 needsVoices=false 时设 false，只弹 Inst 一步。默认 true。 */
	public var importVocals:Bool = true;
	/** 目标文件已存在时是否覆盖。默认 false（保护已有音频 / osz 解包结果）。 */
	public var overwrite:Bool = false;
	/** 人声落地文件名 postfix，须与 characterData.vocalsP1/vocalsP2 对齐。默认 Player/Opponent。 */
	public var playerPostfix:String = 'Player';
	public var opponentPostfix:String = 'Opponent';
	/**
	 * 谱面自己声明的音轨文件绝对路径（如 .osu 的 AudioFilename 解析结果）。
	 * 设了之后只认这一条，不按通用文件名在目标目录里找 —— 谱面散落在下载目录时，
	 * 通用名会命中上一次导入留下的无关音轨。声明文件缺失时返回 null，由调用方弹选择框。
	 */
	public var declaredAudioPath:Null<String> = null;
	/**
	 * 是否允许按通用名（inst.ogg / audio.mp3 等）扫描目标目录里已有的音频。
	 * 外部导入的谱面设为 false：一律要求手动导入，不自动认目录里的残留文件；
	 * 新建谱面等目标目录干净的场景保持默认 true。
	 */
	public var allowFolderScan:Bool = true;

	var _dlg:FileDialogHandler;
	var _dir:String;
	var _result:ChartAudioImportResult;
	var _onDone:ChartAudioImportResult->Void;
	var _steps:Array<String>;
	var _idx:Int = 0;
	var _finished:Bool = true;

	public function new() {}

	/**
	 * 启动向导。targetDir = 谱面 JSON 所在目录（或将要保存到的目录），结尾斜杠有无均可。
	 * 异步：onDone 可能在多帧之后（等原生对话框）才触发。
	 */
	public function start(targetDir:String, onDone:ChartAudioImportResult->Void):Void
	{
		if (!_finished) return; // 上一轮未结束，忽略重复启动

		_dir = StringTools.replace(targetDir == null ? '' : targetDir, '\\', '/');
		if (_dir.length > 0 && !_dir.endsWith('/')) _dir += '/';

		_onDone = onDone;
		_idx = 0;
		_finished = false;
		_result = {
			targetDir: _dir,
			instPath: null,
			playerVocalPath: null,
			opponentVocalPath: null,
			anyImported: false,
			hasInst: false
		};

		#if sys
		// 外部谱面（osu / osz / FNF 目录）常自带音轨：先探测已存在的音频，只为「缺失」的步骤弹框。
		// 谱面声明了音轨时只认那一条；外部导入若关闭 allowFolderScan，则不认目录通用名、一律要求手动导入。
		var existingInst:Null<String> = findExistingAudio('inst');
		if (existingInst != null)
		{
			_result.instPath = existingInst;
			_result.hasInst = true;
			ensurePlayableInst(existingInst);
		}
		var existingP:Null<String> = importVocals ? findExistingAudio('player') : null;
		if (existingP != null) _result.playerVocalPath = existingP;
		var existingO:Null<String> = importVocals ? findExistingAudio('opponent') : null;
		if (existingO != null) _result.opponentVocalPath = existingO;

		_steps = [];
		if (existingInst == null) _steps.push('inst');
		if (importVocals)
		{
			if (existingP == null) _steps.push('player');
			if (existingO == null) _steps.push('opponent');
		}

		if (_steps.length > 0)
		{
			_dlg = new FileDialogHandler();
			nextStep();
		}
		else finish();
		#else
		// 非 sys 平台（HTML5）：FileDialogHandler.path 只有文件名、无 sys.io.File
		finish();
		#end
	}

	/** 外部中止（立即以当前已落地结果回调 onDone）。 */
	public function cancel():Void
	{
		finish();
	}

	function stepTitle(step:String):String
	{
		var n:Int = _idx + 1;
		var total:Int = _steps.length;
		return switch (step)
		{
			case 'inst': 'Step $n/$total: Open Instrumental (Inst) - Cancel to skip';
			case 'player': 'Step $n/$total: Open PLAYER Vocals - Cancel to skip';
			case 'opponent': 'Step $n/$total: Open OPPONENT Vocals - Cancel to skip';
			default: 'Step $n/$total: Open Audio - Cancel to skip';
		};
	}

	#if sys
	function nextStep():Void
	{
		if (_finished) return;
		if (_idx >= _steps.length)
		{
			finish();
			return;
		}

		var step:String = _steps[_idx];

		// FileDialogHandler.onCancelFn 的实现是 `if(onCancel != null) onError();`
		// （检查 onCancel 却调 onError），所以 onCancel 和 onError 必须都传非 null，
		// 取消 / IO 错误才会可靠地走到 skip。
		var skip:Void->Void = function()
		{
			_idx++;
			nextStep();
		};

		_dlg.open(null, stepTitle(step), [new FileFilter('Audio (ogg/mp3)', '*.ogg;*.mp3')],
			function()
			{
				try
				{
					var src:String = _dlg.path;
					if (src != null && src.length > 0)
						copyAudio(step, StringTools.replace(src, '\\', '/'));
				}
				catch (e:Dynamic)
				{
					trace('[ChartAudioImportWizard] read failed: $e');
				}
				_idx++;
				nextStep(); // 此刻 completed 已为 true，可安全开下一步
			},
			skip, // onCancel
			skip  // onError
		);
	}

	function copyAudio(step:String, src:String):Void
	{
		if (_dir.length < 1) return;

		var ext:String = '.ogg';
		var dot:Int = src.lastIndexOf('.');
		if (dot >= 0)
		{
			var raw:String = src.substr(dot + 1).toLowerCase();
			if (raw == 'mp3') ext = '.mp3';
		}

		var name:String = switch (step)
		{
			case 'inst': 'inst' + ext;
			case 'player': 'voices-' + playerPostfix.toLowerCase() + ext;
			case 'opponent': 'voices-' + opponentPostfix.toLowerCase() + ext;
			default: return;
		};

		var dst:String = _dir + name;
		if (FileSystem.exists(dst) && !overwrite) return;

		try
		{
			File.copy(src, dst);
			switch (step)
			{
				case 'inst': _result.instPath = dst;
				case 'player': _result.playerVocalPath = dst;
				case 'opponent': _result.opponentVocalPath = dst;
			}
			_result.anyImported = true;
		}
		catch (e:Dynamic)
		{
			trace('[ChartAudioImportWizard] copy failed $src -> $dst : $e');
		}
	}

	/**
	 * 声明的音轨文件名可能不是 Paths.inst() 认识的候选名（例如 osu 用 track.ogg），
	 * 此时复制成目标目录的 inst.<ext>，否则谱面能载入却只会播 beep。
	 */
	function ensurePlayableInst(src:String):Void
	{
		if (_dir.length < 1) return;
		var name:String = src.substring(src.lastIndexOf('/') + 1).toLowerCase();
		if (name == 'inst.ogg' || name == 'inst.mp3' || name == 'audio.ogg' || name == 'audio.mp3') return;

		var dot:Int = src.lastIndexOf('.');
		var ext:String = dot >= 0 ? src.substr(dot).toLowerCase() : '.ogg';
		var dst:String = _dir + 'inst' + ext;
		try
		{
			// 目标名已被别处音轨占用时保留声明的原始文件，交给调用方的显式音轨路径使用
			if (!FileSystem.exists(dst))
			{
				File.copy(src, dst);
				_result.instPath = dst;
			}
		}
		catch (e:Dynamic)
		{
			trace('[ChartAudioImportWizard] declared audio copy failed $src -> $dst : $e');
		}
	}

	/**
	 * 探测已有音轨。谱面声明了音轨就只认那一条文件；否则仅在 allowFolderScan 时
	 * 按 Paths.inst()/voices() 的候选口径找目标目录里的通用名。命中返回完整路径，否则 null。
	 */
	function findExistingAudio(step:String):Null<String>
	{
		if (declaredAudioPath != null && declaredAudioPath.length > 0)
		{
			if (step == 'inst') return FileSystem.exists(declaredAudioPath) ? declaredAudioPath : null;
			return null;
		}
		if (!allowFolderScan) return null;
		if (_dir.length < 1) return null;

		var names:Array<String> = [];
		switch (step)
		{
			case 'inst':
				names = [
					'inst.ogg', 'inst.mp3', 'Inst.ogg', 'Inst.mp3',
					'audio.ogg', 'audio.mp3', 'Audio.ogg', 'Audio.mp3',
					'song/inst.ogg', 'song/inst.mp3', 'song/Inst.ogg', 'song/Inst.mp3',
					'song/audio.ogg', 'song/audio.mp3'
				];
			case 'player':
				names = [
					'voices-' + playerPostfix.toLowerCase() + '.ogg',
					'voices-' + playerPostfix.toLowerCase() + '.mp3',
					'Voices-' + playerPostfix + '.ogg',
					'Voices-' + playerPostfix + '.mp3',
					'voices.ogg', 'voices.mp3', 'Voices.ogg', 'Voices.mp3',
					'vocals.ogg', 'vocals.mp3', 'Vocals.ogg', 'Vocals.mp3',
					'song/voices.ogg', 'song/voices.mp3', 'song/vocals.ogg', 'song/vocals.mp3',
					'song/Vocals.ogg', 'song/Vocals.mp3'
				];
			case 'opponent':
				names = [
					'voices-' + opponentPostfix.toLowerCase() + '.ogg',
					'voices-' + opponentPostfix.toLowerCase() + '.mp3',
					'Voices-' + opponentPostfix + '.ogg',
					'Voices-' + opponentPostfix + '.mp3',
					'voices.ogg', 'voices.mp3', 'Voices.ogg', 'Voices.mp3',
					'vocals.ogg', 'vocals.mp3', 'Vocals.ogg', 'Vocals.mp3',
					'song/voices.ogg', 'song/voices.mp3', 'song/vocals.ogg', 'song/vocals.mp3',
					'song/Vocals.ogg', 'song/Vocals.mp3'
				];
			default:
				return null;
		}

		for (name in names)
		{
			var p:String = _dir + name;
			if (FileSystem.exists(p)) return p;
		}
		return null;
	}
	#end

	function finish():Void
	{
		if (_finished) return;
		_finished = true;

		#if sys
		if (_dlg != null)
		{
			_dlg.destroy();
			_dlg = null;
		}
		// Inst 可用 = 本次复制成功，或目标目录本来就有（audio.mp3 / inst.ogg / osz 解包落地）
		if (!_result.hasInst && findExistingAudio('inst') != null)
			_result.hasInst = true;
		#end
		if (_result.instPath != null) _result.hasInst = true;

		if (_onDone != null)
		{
			var cb = _onDone;
			_onDone = null;
			try
			{
				cb(_result);
			}
			catch (e:Dynamic)
			{
				trace('[ChartAudioImportWizard] onDone error: $e');
			}
		}
	}
}
