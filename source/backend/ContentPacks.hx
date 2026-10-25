package backend;

import backend.Mods;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * content/ 目录下的可管理条目（一个包 / 一个自定义谱面分类）。
 * path 是相对 content/ 的路径（如 VanillaSongs/Erect），也是 contentList.txt 里的键。
 */
typedef ContentPackInfo = {
	var path:String;
	var group:String;
	var name:String;
	/** 该包下扫到的曲目目录数；0 = 没扫到（自定义谱面分类常为空）。 */
	var songs:Int;
}

/**
 * Content 体系（content/<大类>/<包>）的启用状态管理 —— mods 那套的平行实现。
 *
 * 与 mods/ 的区别：
 *  - mods 靠 modsList.txt 的**顺序**决定覆盖优先级，改完必须重启游戏（资源已缓存进内存）；
 *  - content 包只影响「扫描发现」：Freeplay / Story 每次进入都会重新扫盘
 *    （WeekData.reloadWeekFiles / CustomChartData.load），所以开关**不需要重启**。
 *
 * 落盘文件 contentList.txt 与 modsList.txt 同级，格式同为 `路径|1(启用)/0(禁用)`；
 * 首次运行自动扫盘补全（新包默认启用），目录被删掉的条目自动剔除。
 */
class ContentPacks
{
	public static final LIST_FILE:String = 'contentList.txt';

	static var cachedDisabled:Map<String, Bool> = null;
	static var cachedPacks:Array<ContentPackInfo> = null;

	/** 清掉内存缓存（改完配置 / 外部改动过目录后调用）。 */
	public static function invalidate():Void
	{
		cachedDisabled = null;
		cachedPacks = null;
	}

	/** 扫盘列出所有 content/<大类>/<子目录>，顺序与磁盘一致。 */
	public static function listPacks():Array<ContentPackInfo>
	{
		if (cachedPacks != null) return cachedPacks;

		var result:Array<ContentPackInfo> = [];
		#if sys
		var root:String = Paths.CONTENT_ROOT;
		if (FileSystem.exists(root) && FileSystem.isDirectory(root))
		{
			for (group in FileSystem.readDirectory(root))
			{
				if (group.startsWith('.')) continue;
				var groupPath:String = '$root/$group';
				if (!FileSystem.isDirectory(groupPath)) continue;

				for (name in FileSystem.readDirectory(groupPath))
				{
					if (name.startsWith('.')) continue;
					var path:String = '$groupPath/$name';
					if (!FileSystem.isDirectory(path)) continue;
					if (!isPackDirectory(path)) continue;
					result.push({path: '$group/$name', group: group, name: name, songs: countSongs(path)});
				}
			}
		}
		#end
		cachedPacks = result;
		return result;
	}

	/** 取单个条目的扫描信息（找不到返回 null）。 */
	public static function getInfo(path:String):ContentPackInfo
	{
		if (path == null || path.length == 0) return null;
		for (info in listPacks())
			if (info.path == path) return info;
		return null;
	}

	/**
	 * 配置 + 磁盘合并后的列表（与 Mods.parseList() 同构，方便 Mods 菜单共用一套逻辑）。
	 * 发现新包时自动写回磁盘。
	 */
	public static function parseList():ModsList
	{
		var list:ModsList = {enabled: [], disabled: [], all: []};
		#if sys
		var discovered:Array<ContentPackInfo> = listPacks();
		var states:Map<String, Bool> = new Map<String, Bool>();
		var ordered:Array<String> = [];

		if (FileSystem.exists(LIST_FILE))
		{
			try
			{
				// 不用 CoolUtil.coolTextFile：它在非 MODS_ALLOWED 构建下走 Assets，读不到运行时写的文本
				var raw:String = File.getContent(LIST_FILE);
				for (line in raw.split('\n'))
				{
					if (line == null) continue;
					var trimmed:String = line.split('\r').join('').trim();
					if (trimmed.length < 1) continue;
					var dat:Array<String> = trimmed.split('|');
					var path:String = dat[0].trim();
					if (path.length < 1 || states.exists(path)) continue;
					states.set(path, dat.length > 1 && dat[1] == '1');
					ordered.push(path);
				}
			}
			catch (e:Dynamic) trace(e);
		}

		var dirty:Bool = false;

		// 1. 按配置顺序收拢还存在的条目
		for (path in ordered)
		{
			var exists:Bool = false;
			for (info in discovered)
			{
				if (info.path == path)
				{
					exists = true;
					break;
				}
			}
			if (!exists)
			{
				dirty = true; // 目录被删了
				continue;
			}

			list.all.push(path);
			if (states.get(path)) list.enabled.push(path);
			else list.disabled.push(path);
		}

		// 2. 新包默认启用
		for (info in discovered)
		{
			if (list.all.indexOf(info.path) != -1) continue;
			dirty = true;
			list.all.push(info.path);
			list.enabled.push(info.path);
		}

		if (dirty) save(list);
		#end
		return list;
	}

	/** 是否被禁用（缓存，未配置的包一律视为启用）。 */
	public static function isDisabled(path:String):Bool
	{
		if (path == null || path.length < 1) return false;
		if (cachedDisabled == null)
		{
			cachedDisabled = new Map<String, Bool>();
			for (disabled in parseList().disabled)
				cachedDisabled.set(disabled, true);
		}
		return cachedDisabled.exists(path);
	}

	/** 改单个条目的开关并落盘（不需要重启）。 */
	public static function setDisabled(path:String, on:Bool):Void
	{
		var list:ModsList = parseList();
		if (on)
		{
			list.enabled.remove(path);
			if (!list.disabled.contains(path)) list.disabled.push(path);
		}
		else
		{
			list.disabled.remove(path);
			if (!list.enabled.contains(path)) list.enabled.push(path);
		}
		save(list);
		invalidate();
	}

	/** 整表落盘。 */
	public static function save(list:ModsList):Void
	{
		#if sys
		var fileStr:String = '';
		for (path in list.all)
		{
			if (path == null || path.trim().length < 1) continue;
			if (fileStr.length > 0) fileStr += '\n';
			fileStr += '$path|' + (list.disabled.contains(path) ? '0' : '1');
		}
		try
		{
			File.saveContent(LIST_FILE, fileStr);
		}
		catch (e:Dynamic) trace('Failed to save $LIST_FILE: $e'); // 只读目录 / 权限问题别把游戏带崩
		#end
	}

	/**
	 * 一个 content 子目录算不算"包"：里面得有引擎认的东西（shared/ 或谱面/json），
	 * 免得把 readme 那种杂物目录也列进菜单。
	 */
	static function isPackDirectory(path:String):Bool
	{
		#if sys
		if (FileSystem.exists('$path/shared')) return true;
		for (item in FileSystem.readDirectory(path))
		{
			if (item.startsWith('.')) continue;
			if (FileSystem.isDirectory('$path/$item')) return true;
			var lower:String = item.toLowerCase();
			if (lower.endsWith('.json') || lower.endsWith('.txt') || lower.endsWith('.md')) continue;
			return true;
		}
		#end
		return false;
	}

	/** 粗略统计包内曲目数，只用于菜单描述（失败不报错）。 */
	static function countSongs(path:String):Int
	{
		#if sys
		var dataPath:String = '$path/shared/data';
		if (!FileSystem.exists(dataPath) || !FileSystem.isDirectory(dataPath)) dataPath = path;

		var count:Int = 0;
		try
		{
			for (item in FileSystem.readDirectory(dataPath))
			{
				if (item.startsWith('.')) continue;
				var sub:String = '$dataPath/$item';
				if (!FileSystem.isDirectory(sub)) continue;
				if (hasChartFile(sub)) count++;
			}
		}
		catch (e:Dynamic) {}
		return count;
		#else
		return 0;
		#end
	}

	static function hasChartFile(directory:String):Bool
	{
		#if sys
		try
		{
			for (item in FileSystem.readDirectory(directory))
			{
				var lower:String = item.toLowerCase();
				if (lower.endsWith('.json') || lower.endsWith('.osu')) return true;
			}
		}
		catch (e:Dynamic) {}
		#end
		return false;
	}
}
