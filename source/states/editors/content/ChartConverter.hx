package states.editors.content;

import backend.Song;
import states.editors.content.ChartConvertCore.ChartImportInfo;
import sys.io.File;

/**
 * FE 侧的统一谱面转换门面：其他游戏格式 → SwagSong，以及 SwagSong → StepMania。
 * 纯转换逻辑在 ChartConvertCore（只依赖 moonchart，可脱离引擎独立测试），
 * 这里只做引擎类型封装与文件 IO。解析失败直接抛错，由调用方（ChartingState） catch 后展示。
 */
class ChartConverter
{
	public static var FILE_FILTER(get, never):String;

	static inline function get_FILE_FILTER():String
	{
		return ChartConvertCore.FILE_FILTER;
	}

	/**
	 * 识别文件格式（sm/ssc/osu/osz/qua/qp/mid/mc），不认识返回 null
	 */
	public static function detectFormat(path:String):Null<String>
	{
		return ChartConvertCore.detectFormat(path);
	}

	/**
	 * 探测文件信息（格式/键数/难度列表/标题），供导入对话框使用
	 */
	public static function probe(path:String):ChartImportInfo
	{
		return ChartConvertCore.probe(path);
	}

	/**
	 * 导入为 SwagSong
	 * @param diff 源难度名（null = 第一个难度）
	 * @param targetKeys 目标键数；与源键数不同时按比例重排列
	 */
	public static function importChart(path:String, ?diff:String, targetKeys:Int = 4):SwagSong
	{
		return cast ChartConvertCore.importToSong(path, diff, targetKeys);
	}

	/**
	 * SwagSong → .sm/.ssc 文本
	 * @param diffName 写入文件的难度名（如 Challenge）
	 */
	public static function convertPsychToStepMania(song:SwagSong, format:String = 'sm', diffName:String = 'Challenge'):String
	{
		return ChartConvertCore.stepManiaFromSong(song, format, diffName);
	}

	public static function savePsychToStepMania(song:SwagSong, path:String, format:String = 'sm', diffName:String = 'Challenge'):Bool
	{
		var content:String = convertPsychToStepMania(song, format, diffName);
		if(content == null) return false;

		if(!path.endsWith('.' + format)) path += '.' + format;
		File.saveContent(path, content);
		return true;
	}
}
