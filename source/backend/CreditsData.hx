package backend;

import haxe.Json;

import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef CreditPerson = {
	var name:String;
	var icon:String;
	var role:String;
	var desc:String;
	var link:String;
	var color:String;
	var video:String;
	var mod:String;
}

typedef CreditSubSection = {
	var name:String;
	var people:Array<CreditPerson>;
}

typedef CreditSection = {
	var name:String;
	var id:String;
	var kind:String; // 'engine' | 'psych' | 'mod'
	var mod:String; // 资源所属 mod 文件夹，'' = 本体
	var color:String; // 该段默认背景色
	/** 整组视频名（不含目录与扩展名），文件放 assets/videos/credits/<video>.mp4 */
	var video:String;
	var subsections:Array<CreditSubSection>;
}

/** 摊平后的一行。sub 为 -1 表示直接挂在 section 下。 */
typedef CreditRow = {
	var name:String;
	var icon:String;
	var role:String;
	var desc:String;
	var link:String;
	var color:String;
	var video:String;
	var mod:String;
	var section:Int;
	var sub:Int;
	var subName:String;
	var slot:Int;
	var isLabel:Bool;
}

typedef CreditsBundle = {
	var sections:Array<CreditSection>;
	var rows:Array<CreditRow>;
	var selectableRows:Array<Int>;
}

/**
 * Credits 数据层：把 JSON / 旧 credits.txt / 内置兜底统一摊平成"渲染行 + 虚拟 slot"。
 * 只依赖 Paths / Mods / ClientPrefs，不引用任何 Flixel 显示对象。
 */
class CreditsData
{
	public static inline var FILE_NAME:String = 'data/credits.json';

	// ---- 布局参数（实机可调） ----
	/** 组与组之间空出的 slot 数。1 slot = Alphabet 的 156px 行距。3 → 组间相隔 4 行，跨组时另一组完全出屏。 */
	public static var GAP_ROWS:Int = 3;
	/** 同一组内子分组之间空出的 slot 数。 */
	public static var SUB_GAP_ROWS:Int = 1;
	/** 是否在子分组留白里画小标签（默认关：列表保持纯人物）。 */
	public static var SHOW_SUBSECTION_LABELS:Bool = false;

	// ---- 顶部副标题来源 ----
	public static inline var SUBTITLE_ROLE:String = 'role';
	public static inline var SUBTITLE_SUBSECTION:String = 'subsection';
	public static inline var SUBTITLE_BOTH:String = 'both';
	public static var SUBTITLE_MODE:String = SUBTITLE_ROLE;

	public static inline var DEFAULT_COLOR:String = '3A3A3A';

	// ================================================================
	// 构建
	// ================================================================

	public static function load():CreditsBundle
	{
		var sections:Array<CreditSection> = loadBaseSections();

		#if MODS_ALLOWED
		for (folder in Mods.parseList().enabled)
		{
			var sec:CreditSection = loadModSection(folder);
			if (sec != null && countPeople(sec) > 0) sections.push(sec);
		}
		#end

		return flatten(sections);
	}

	static function countPeople(sec:CreditSection):Int
	{
		var n:Int = 0;
		for (sub in sec.subsections) n += sub.people.length;
		return n;
	}

	// ================================================================
	// 基底 JSON（assets/shared/data/credits.json）
	// ================================================================

	static function loadBaseSections():Array<CreditSection>
	{
		// modsAllowed = false：绝不能让"当前 mod"劫持基底文件
		var path:String = Paths.getPath(FILE_NAME, AssetType.TEXT, null, false);
		var raw:String = readText(path);

		if (raw != null)
		{
			var sections:Array<CreditSection> = parseSectionList(raw, '', 'mod', '');
			if (sections != null && sections.length > 0) return sections;
			trace('[CreditsData] $path parsed but empty, falling back to built-in list');
		}
		return defaultSections();
	}

	// ================================================================
	// mod：JSON 优先，旧 credits.txt 兼容
	// ================================================================

	static function loadModSection(folder:String):CreditSection
	{
		var secName:String = modDisplayName(folder);

		#if TRANSLATIONS_ALLOWED
		var lang:String = ClientPrefs.data.language;
		#else
		var lang:String = '';
		#end

		var jsonPaths:Array<String> = [];
		if (lang.length > 0) jsonPaths.push('data/credits-$lang.json');
		jsonPaths.push('data/credits.json');

		for (rel in jsonPaths)
		{
			var raw:String = readText(Paths.mods(folder + '/' + rel));
			if (raw == null) continue;

			var sections:Array<CreditSection> = parseSectionList(raw, folder, 'mod', secName);
			if (sections != null && sections.length > 0)
			{
				var total:Int = 0;
				for (s in sections) total += countPeople(s);
				if (total > 0) return mergeSections(sections, secName, folder);
			}
		}

		var txtPaths:Array<String> = [];
		if (lang.length > 0) txtPaths.push('data/credits-$lang.txt');
		txtPaths.push('data/credits.txt');

		for (rel in txtPaths)
		{
			var raw:String = readText(Paths.mods(folder + '/' + rel));
			if (raw == null) continue;

			var sec:CreditSection = parseLegacyTxt(raw, folder, secName);
			if (sec != null && countPeople(sec) > 0) return sec;
		}

		return null;
	}

	/** mod 的 JSON 若声明了多个 section，全部并到该 mod 名下（大标题统一用 mod 名）。 */
	static function mergeSections(sections:Array<CreditSection>, secName:String, folder:String):CreditSection
	{
		if (sections.length == 1)
		{
			var s:CreditSection = sections[0];
			if (s.name.length == 0) s.name = secName;
			if (s.mod.length == 0) s.mod = folder;
			if (s.kind.length == 0) s.kind = 'mod';
			return s;
		}

		var out:CreditSection = {
			name: secName,
			id: '',
			kind: 'mod',
			mod: folder,
			color: DEFAULT_COLOR,
			video: '',
			subsections: []
		};
		for (s in sections)
		{
			if (out.video.length == 0 && s.video != null && s.video.length > 0) out.video = s.video;
			for (sub in s.subsections) out.subsections.push(sub);
		}
		return out;
	}

	public static function modDisplayName(folder:String):String
	{
		#if MODS_ALLOWED
		var pack:Dynamic = Mods.getPack(folder);
		if (pack != null)
		{
			var n:Dynamic = Reflect.field(pack, 'name');
			if (n != null && Std.string(n).length > 0) return Std.string(n);
		}
		#end
		return folder;
	}

	/** 旧格式：`#` 指令行；空行分段；单列行 = 子标题；其余 `Name::Icon::Desc::Link::Color`。 */
	public static function parseLegacyTxt(text:String, folder:String, sectionName:String):CreditSection
	{
		var sec:CreditSection = {
			name: sectionName,
			id: '',
			kind: 'mod',
			mod: folder,
			color: DEFAULT_COLOR,
			video: '',
			subsections: []
		};

		var cur:CreditSubSection = null;

		for (rawLine in text.split('\n'))
		{
			var line:String = StringTools.replace(rawLine, '\r', '');
			if (line.trim().length == 0)
			{
				cur = null;
				continue;
			}

			// `#` 指令行：必须放在"单列行 = 子标题"之前，否则 `#video X` 会被当成标题
			var trimmed:String = line.trim();
			if (trimmed.charAt(0) == '#')
			{
				var body:String = trimmed.substr(1).trim();
				var sp:Int = body.indexOf(' ');
				var cmd:String = (sp < 0) ? body : body.substr(0, sp);
				var arg:String = (sp < 0) ? '' : body.substr(sp + 1).trim();

				if (cmd == 'video') sec.video = arg;
				else trace('[CreditsData] unknown credits.txt directive: $trimmed');
				continue;
			}

			line = StringTools.replace(line, '\\n', '\n');
			var arr:Array<String> = line.split('::');

			if (arr.length <= 1)
			{
				cur = {name: arr[0].trim(), people: []};
				sec.subsections.push(cur);
				continue;
			}

			if (cur == null)
			{
				cur = {name: '', people: []};
				sec.subsections.push(cur);
			}

			cur.people.push({
				name: arr[0].trim(),
				icon: (arr.length > 1) ? arr[1].trim() : '',
				role: '',
				desc: (arr.length > 2) ? arr[2] : '',
				link: (arr.length > 3) ? arr[3].trim() : '',
				color: (arr.length > 4) ? arr[4].trim() : '',
				video: '',
				mod: folder
			});
		}

		return sec;
	}

	// ================================================================
	// JSON 解析（宽容：缺字段 = 空串，坏数据不崩）
	// ================================================================

	static function parseSectionList(raw:String, modFolder:String, defaultKind:String, defaultName:String):Array<CreditSection>
	{
		var data:Dynamic = null;
		try
		{
			data = Json.parse(raw);
		}
		catch (e:Dynamic)
		{
			trace('[CreditsData] JSON parse error: $e');
			return null;
		}
		if (data == null) return null;

		var out:Array<CreditSection> = [];
		var list:Array<Dynamic> = asArray(Reflect.field(data, 'sections'));

		if (list != null && list.length > 0)
		{
			for (item in list)
			{
				var sec:CreditSection = parseSection(item, defaultName, defaultKind, modFolder);
				if (sec != null && countPeople(sec) > 0) out.push(sec);
			}
		}
		else
		{
			// 也接受"整个文件就是一个 section"的写法
			var single:CreditSection = parseSection(data, defaultName, defaultKind, modFolder);
			if (single != null && countPeople(single) > 0) out.push(single);
		}

		return out;
	}

	static function parseSection(src:Dynamic, defaultName:String, defaultKind:String, modFolder:String):CreditSection
	{
		if (src == null) return null;

		var name:String = str(src, 'name', defaultName);
		var kind:String = str(src, 'kind', defaultKind);
		var mod:String = str(src, 'mod', modFolder);
		var secColor:String = str(src, 'color', DEFAULT_COLOR);

		var sec:CreditSection = {
			name: name,
			id: str(src, 'id', ''),
			kind: kind,
			mod: mod,
			color: secColor,
			video: str(src, 'video', ''),
			subsections: []
		};

		var subs:Array<Dynamic> = asArray(Reflect.field(src, 'subsections'));
		if (subs != null)
		{
			for (subSrc in subs)
			{
				if (subSrc == null) continue;
				var subName:String = str(subSrc, 'name', '');
				var people:Array<CreditPerson> = parsePeople(Reflect.field(subSrc, 'people'), mod, secColor);
				if (people.length > 0) sec.subsections.push({name: subName, people: people});
			}
		}

		// 未分组的直接 people 也接受
		var flat:Array<CreditPerson> = parsePeople(Reflect.field(src, 'people'), mod, secColor);
		if (flat.length > 0) sec.subsections.push({name: '', people: flat});

		return sec;
	}

	static function parsePeople(list:Dynamic, modFolder:String, secColor:String):Array<CreditPerson>
	{
		var out:Array<CreditPerson> = [];
		var arr:Array<Dynamic> = asArray(list);
		if (arr == null) return out;

		for (item in arr)
		{
			if (item == null) continue;
			var pname:String = str(item, 'name', '');
			if (pname.length == 0) continue;

			out.push({
				name: pname,
				icon: str(item, 'icon', ''),
				role: str(item, 'role', ''),
				desc: str(item, 'desc', ''),
				link: str(item, 'link', ''),
				color: str(item, 'color', secColor),
				video: str(item, 'video', ''),
				mod: str(item, 'mod', modFolder)
			});
		}
		return out;
	}

	// ================================================================
	// 摊平 + 虚拟 slot
	// ================================================================

	static function flatten(sections:Array<CreditSection>):CreditsBundle
	{
		var rows:Array<CreditRow> = [];
		var selectable:Array<Int> = [];
		var slot:Int = -1;

		for (si in 0...sections.length)
		{
			var sec:CreditSection = sections[si];

			slot += GAP_ROWS;
			var firstSub:Bool = true;

			for (subIndex in 0...sec.subsections.length)
			{
				var sub:CreditSubSection = sec.subsections[subIndex];
				if (!firstSub) slot += SUB_GAP_ROWS;
				firstSub = false;

				if (SHOW_SUBSECTION_LABELS && sub.name.length > 0)
				{
					rows.push({
						name: sub.name,
						icon: '',
						role: '',
						desc: '',
						link: '',
						color: sec.color,
						video: '',
						mod: sec.mod,
						section: si,
						sub: subIndex,
						subName: sub.name,
						slot: slot++,
						isLabel: true
					});
				}

				for (p in sub.people)
				{
					rows.push({
						name: p.name,
						icon: p.icon,
						role: p.role,
						desc: p.desc,
						link: p.link,
						color: (p.color.length > 0) ? p.color : sec.color,
						video: p.video,
						mod: p.mod,
						section: si,
						sub: subIndex,
						subName: sub.name,
						slot: slot++,
						isLabel: false
					});
					selectable.push(rows.length - 1);
				}
			}
		}

		return {sections: sections, rows: rows, selectableRows: selectable};
	}

	// ================================================================
	// 全量滚动名单
	// ================================================================

	/** 非 ASCII 行用的 CJK 字体（vcr.ttf 只有 75KB，没有任何 CJK 字形）。 */
	public static var CJK_FONT:String = 'HarmonyOS_Sans_SC_Medium.ttf';

	public static inline var ROLL_STYLE_HEADER:Int = 0;
	public static inline var ROLL_STYLE_SUB:Int = 1;
	public static inline var ROLL_STYLE_BODY:Int = 2;
	public static inline var ROLL_STYLE_GAP:Int = 3;

	/** 把整个 bundle 摊成滚动名单的行序列（组标题 → 子分组 → 人名 | 职责）。 */
	public static function collectRollLines(b:CreditsBundle):Array<RollLine>
	{
		var out:Array<RollLine> = [];
		if (b == null || b.sections == null) return out;

		for (sec in b.sections)
		{
			if (sec == null) continue;

			var secColor:String = (sec.color == null) ? '' : sec.color;

			out.push({
				text: (sec.name == null) ? '' : sec.name.toUpperCase(),
				second: '',
				style: ROLL_STYLE_HEADER,
				gapAfter: 10,
				color: secColor,
				font: pickFont(sec.name)
			});

			// 只有当这一组有多个非空子标题时才显示子标题，避免"一人一子段"的 mod 刷屏
			var namedSubs:Int = 0;
			for (sub in sec.subsections) if (sub.name != null && sub.name.length > 0) namedSubs++;
			var showSub:Bool = namedSubs > 1;

			for (sub in sec.subsections)
			{
				if (showSub && sub.name != null && sub.name.length > 0)
				{
					out.push({
						text: sub.name,
						second: '',
						style: ROLL_STYLE_SUB,
						gapAfter: 6,
						color: secColor,
						font: pickFont(sub.name)
					});
				}

				for (p in sub.people)
				{
					if (p.name == null || p.name.trim().length == 0) continue;

					var role:String = p.role;
					if (role == null || role.length == 0) role = firstLine(p.desc, 48);
					if (role == null) role = '';

					out.push({
						text: p.name,
						second: role,
						style: ROLL_STYLE_BODY,
						gapAfter: 2,
						color: secColor,
						font: pickFont(p.name + role)
					});
				}

				if (showSub)
				{
					out.push({text: '', second: '', style: ROLL_STYLE_GAP, gapAfter: 14, color: '', font: ''});
				}
			}

			// 组间大留白
			out.push({text: '', second: '', style: ROLL_STYLE_GAP, gapAfter: 52, color: '', font: ''});
		}

		return out;
	}

	/** 含非 ASCII（中文/日文/带音标的名字）就换 CJK 字体，纯 ASCII 仍用全界面统一的 vcr。 */
	public static function pickFont(s:String):String
	{
		if (s == null) return '';
		for (i in 0...s.length)
		{
			if (s.charCodeAt(i) > 0x7F) return CJK_FONT;
		}
		return '';
	}

	// ================================================================
	// 副标题 / 工具
	// ================================================================

	public static function subtitleOf(row:CreditRow):String
	{
		if (row == null || row.isLabel) return '';

		var role:String = row.role;
		if (role.length == 0) role = firstLine(row.desc, 56);
		if (role.length == 0) role = row.subName;

		switch (SUBTITLE_MODE)
		{
			case SUBTITLE_SUBSECTION:
				return (row.subName.length > 0) ? row.subName : role;
			case SUBTITLE_BOTH:
				if (row.subName.length > 0 && role.length > 0 && row.subName != role)
					return row.subName + ' - ' + role;
				return (role.length > 0) ? role : row.subName;
			default:
				return role;
		}
	}

	static function firstLine(s:String, max:Int):String
	{
		if (s == null) return '';
		var n:Int = s.indexOf('\n');
		if (n >= 0) s = s.substr(0, n);
		s = s.trim();
		if (s.length > max) s = s.substr(0, max - 3) + '...';
		return s;
	}

	/** 临时切 Mods.currentModDirectory 读资源，结束后恢复原值（不要硬置 ''）。 */
	public static inline function withMod<T>(folder:String, fn:Void->T):T
	{
		#if MODS_ALLOWED
		var prev:String = Mods.currentModDirectory;
		Mods.currentModDirectory = (folder == null) ? '' : folder;
		var out:T = fn();
		Mods.currentModDirectory = prev;
		return out;
		#else
		return fn();
		#end
	}

	static inline function str(o:Dynamic, key:String, def:String):String
	{
		if (o == null) return def;
		var v:Dynamic = Reflect.field(o, key);
		if (v == null) return def;
		return Std.string(v);
	}

	static inline function asArray(v:Dynamic):Array<Dynamic>
	{
		if (v == null) return null;
		if (!Std.isOfType(v, Array)) return null;
		return cast v;
	}

	static function readText(path:String):String
	{
		#if sys
		if (path == null || path.length == 0) return null;
		if (FileSystem.exists(path) && !FileSystem.isDirectory(path))
		{
			try
			{
				return File.getContent(path);
			}
			catch (e:Dynamic)
			{
				trace('[CreditsData] cannot read $path: $e');
			}
		}
		// 磁盘上没有时回退到打包资源（embed 的资源不出现在 bin 目录里）
		if (OpenFlAssets.exists(path, AssetType.TEXT)) return OpenFlAssets.getText(path);
		return null;
		#else
		if (path == null || path.length == 0) return null;
		if (!OpenFlAssets.exists(path, AssetType.TEXT)) return null;
		return OpenFlAssets.getText(path);
		#end
	}

	// ================================================================
	// 兜底：assets 丢了也别白屏
	// ================================================================

	static function defaultSections():Array<CreditSection>
	{
		return [
			{
				name: 'Frozen Engine Contributors',
				id: 'frozen',
				kind: 'engine',
				mod: '',
				color: '87CEEB',
				video: '',
				subsections: [
					{
						name: 'Creator',
						people: [
							{
								name: 'Ice_Axe',
								icon: 'iceaxe',
								role: 'Developer',
								desc: 'Creator of Frozen Engine',
								link: 'https://github.com/TieGao',
								color: '87CEEB',
								video: '',
								mod: ''
							}
						]
					}
				]
			},
			{
				name: 'Psych Engine Contributors',
				id: 'psych',
				kind: 'psych',
				mod: '',
				color: '444444',
				video: '',
				subsections: [
					{
						name: 'Psych Engine Team',
						people: [
							{
								name: 'Shadow Mario',
								icon: 'shadowmario',
								role: 'Lead Programmer',
								desc: 'Main Programmer and Head of Psych Engine',
								link: 'https://ko-fi.com/shadowmario',
								color: '444444',
								video: '',
								mod: ''
							}
						]
					}
				]
			}
		];
	}
}
