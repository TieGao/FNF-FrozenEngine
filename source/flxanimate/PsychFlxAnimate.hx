package flxanimate;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame.FlxFrameType;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxDestroyUtil;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flxanimate.frames.FlxAnimateFrames;
import flxanimate.data.AnimationData;
import flxanimate.animate.FlxSymbol;
import flxanimate.animate.FlxTimeline;
import flxanimate.animate.FlxKeyFrame;
import flxanimate.animate.FlxElement;
import flxanimate.animate.SymbolParameters;
import flixel.math.FlxMatrix;
import flixel.FlxG;
import flxanimate.FlxAnimate as OriginalFlxAnimate;

class PsychFlxAnimate extends OriginalFlxAnimate
{
	public function loadAtlasEx(img:FlxGraphicAsset, pathOrStr:String = null, myJson:Dynamic = null)
	{
		var animJson:AnimAtlas = null;
		if(myJson is String)
		{
			var trimmed:String = pathOrStr.trim();
			trimmed = trimmed.substr(trimmed.length - 5).toLowerCase();

			if(trimmed == '.json') myJson = File.getContent(myJson); //is a path
			animJson = cast haxe.Json.parse(_removeBOM(myJson));
		}
		else animJson = cast myJson;

		var isXml:Null<Bool> = null;
		var myData:Dynamic = pathOrStr;

		var trimmed:String = pathOrStr.trim();
		trimmed = trimmed.substr(trimmed.length - 5).toLowerCase();

		if(trimmed == '.json') //Path is json
		{
			myData = File.getContent(pathOrStr);
			isXml = false;
		}
		else if (trimmed.substr(1) == '.xml') //Path is xml
		{
			myData = File.getContent(pathOrStr);
			isXml = true;
		}
		myData = _removeBOM(myData);

		// Automatic if everything else fails
		switch(isXml)
		{
			case true:
				myData = Xml.parse(myData);
			case false:
				myData = haxe.Json.parse(myData);
			case null:
				try
				{
					myData = haxe.Json.parse(myData);
					isXml = false;
					//trace('JSON parsed successfully!');
				}
				catch(e)
				{
					myData = Xml.parse(myData);
					isXml = true;
					//trace('XML parsed successfully!');
				}
		}

		anim._loadAtlas(animJson);
		if(!isXml) frames = FlxAnimateFrames.fromSpriteMap(cast myData, img);
		else frames = FlxAnimateFrames.fromSparrow(cast myData, img);
		origin = anim.curInstance.symbol.transformationPoint;
	}

	/**
	 * 把另一份分尸图并进当前 sprite：帧集合追加、符号字典按名字补进去。
	 */
	public function addExtraAtlas(folderOrImg:String):Void
	{
		var spriteJson:String = null;
		var imgKey:String = folderOrImg;
		for (i in 0...10)
		{
			var st:String = '$i';
			if(i == 0) st = '';
			var sj:String = Paths.getTextFromFile('images/$folderOrImg/spritemap$st.json');
			if (sj != null)
			{
				spriteJson = sj;
				imgKey = '$folderOrImg/spritemap$st';
				break;
			}
		}

		var animText:String = Paths.getTextFromFile('images/$folderOrImg/Animation.json');
		if (animText == null)
		{
			// Sparrow 额外图集（VS 的 multisparrow 混合角色，如 pico-playable 的 censor 动画）：
			// images/<x>.xml + .png —— 帧并进 frames，并造一个"每帧 DU=1"的主符号注册进
			// symbolDictionary，json 动画用 name=<路径末段> + 绝对 indices 即可照常 addBySymbolIndices
			var xmlText:String = Paths.getTextFromFile('images/$folderOrImg.xml');
			if (xmlText != null && frames != null)
			{
				var graphic:FlxGraphic = Paths.image(folderOrImg);
				var spar:FlxAtlasFrames = (graphic == null) ? null : FlxAtlasFrames.fromSparrow(graphic, xmlText);
				if (spar != null)
				{
					var mainFrames:FlxAtlasFrames = cast frames;
					mainFrames.addAtlas(spar);
					frames = mainFrames;

					var sn:String = folderOrImg.split('/').pop();
					var contentFrames:Array<Dynamic> = [];
					for (i in 0...spar.frames.length)
					{
						var frameName:String = spar.frames[i].name;
						contentFrames.push({I: i, DU: 1, E: [{ASI: {MX: [1, 0, 0, 1, 0, 0], N: frameName}}]});
					}
					var tl:FlxTimeline = FlxTimeline.fromJSONEx({L: [{LN: 'content', FR: contentFrames}]});
					if (tl != null)
					{
						// 纯 sparrow 主图集时 symbolDictionary 还是 null（只有 _loadAtlas 初始化）
						if (anim.symbolDictionary == null) anim.symbolDictionary = [];
						anim.symbolDictionary.set(sn, new FlxSymbol(sn, tl));
					}
				}
				return;
			}
			FlxG.log.error('addExtraAtlas: 找不到 $folderOrImg/Animation.json');
			return;
		}

		if (spriteJson != null && frames != null)
		{
			var mainFrames:FlxAtlasFrames = cast frames;
			mainFrames.addAtlas(FlxAnimateFrames.fromSpriteMap(cast haxe.Json.parse(_removeBOM(spriteJson)), Paths.image(imgKey)));
			frames = mainFrames;
		}

		var extra:AnimAtlas = cast Paths.patchBtaVersion(animText);
		var renamed:Map<String, String> = namespaceExtraSymbols(extra, folderOrImg);

		// 子图集的主时间轴也要注册 —— 逐动画的 `name` 写的就是它的主符号名
		anim.symbolDictionary.set(extra.AN.SN, new FlxSymbol(haxe.io.Path.withoutDirectory(extra.AN.SN), FlxTimeline.fromJSONEx(extra.AN.TL)));
		if (extra.SD != null)
		{
			for (symbol in extra.SD.S)
			{
				var key:String = renamed.exists(symbol.SN) ? renamed.get(symbol.SN) : symbol.SN;
				anim.symbolDictionary.set(key, new FlxSymbol(haxe.io.Path.withoutDirectory(key), FlxTimeline.fromJSONEx(symbol.TL)));
			}
		}
	}

	/**
	 * 子图集里与已注册符号重名的，改名成 `<名字>@<图集名>`，子图集内部的引用一起改。
	 * 返回 旧名 → 新名 的映射，注册时按这个映射换 key。
	 *
	 * 两份 Animate 文档会用到同一批通用符号名（pico-dark 的 `Bitmap 3`、tankman-bloody 的十几个零件），
	 * 而 symbolDictionary 只有一个命名空间：直接 set 会让后注册的子图集符号盖掉主图集的，
	 * 主图集里引用同名符号的动画就画成子图集的帧（表现为只剩一个身体 / 某个零件）。
	 */
	function namespaceExtraSymbols(extra:AnimAtlas, folderOrImg:String):Map<String, String>
	{
		var renamed:Map<String, String> = [];
		if (extra == null || extra.SD == null || extra.SD.S == null || anim.symbolDictionary == null) return renamed;

		var suffix:String = haxe.io.Path.withoutDirectory(folderOrImg);
		for (symbol in extra.SD.S)
		{
			if (anim.symbolDictionary.exists(symbol.SN))
				renamed.set(symbol.SN, symbol.SN + '@' + suffix);
		}
		if (Lambda.count(renamed) < 1) return renamed;

		function renameRefs(tl:Dynamic):Void
		{
			if (tl == null || tl.L == null) return;
			for (layer in cast(tl.L, Array<Dynamic>))
			{
				if (layer == null || layer.FR == null) continue;
				for (frame in cast(layer.FR, Array<Dynamic>))
				{
					if (frame == null || frame.E == null) continue;
					for (element in cast(frame.E, Array<Dynamic>))
					{
						if (element == null || element.SI == null) continue;
						var ref:String = element.SI.SN;
						if (ref != null && renamed.exists(ref)) element.SI.SN = renamed.get(ref);
					}
				}
			}
		}

		renameRefs(extra.AN.TL);
		for (symbol in extra.SD.S)
			renameRefs(symbol.TL);

		return renamed;
	}

	/**
	 * `FlxAnim.addBySymbolIndices` 的防环版本。

	 */
	public function safeAddBySymbolIndices(name:String, symbolName:String, indices:Array<Int>, frameRate:Float, looped:Bool):Bool
	{
		if (anim.symbolDictionary == null) return false;
		if (!anim.symbolDictionary.exists(symbolName)) return false;

		// 包装符号的字典键**不能以源符号名开头**：Dot-Stuff 的 `FlxAnim.addBySymbol`
		// 是"遍历字典键做前缀匹配、取第一个"，键 `<源符号>#<动画>` 会被它当成源符号的
		// 候选，Map 顺序一变就抓到包装（只含别的动画选中的那几帧）→ 播放串台、
		// 零件（手/护目镜等）跟着混用。用 '@' 开头把包装挡在前缀匹配之外。
		var regKey:String = '@' + symbolName + '@' + name;
		var outerParams = new FlxElement(new SymbolParameters((looped) ? Loop : PlayOnce), new FlxMatrix(1, 0, 0, 1, 0, 0));
		var timeline = new FlxTimeline();
		timeline.add("Layer 1");

		var slot:Int = 0;
		for (frameIndex in indices)
		{
			var keyframe = new FlxKeyFrame(slot);
			var frameParams = new SymbolParameters(symbolName, outerParams.symbol.loop);
			frameParams.firstFrame = frameIndex;
			keyframe.add(new FlxElement(frameParams));
			timeline.get(0).add(keyframe);
			slot++;
		}
		var symbol = new FlxSymbol(regKey, timeline);
		outerParams.symbol.name = regKey;

		@:privateAccess
		{
			anim.symbolDictionary.set(regKey, symbol);
			anim.animsMap.set(name, {instance: outerParams, frameRate: frameRate});
		}
		return true;
	}

	/**
	 * 非 Animate 图集也照画的开关（FunkinSprite 的 sparrow/loadGraphic 路径用）：
	 * NMV 原版对这类 FunkinSprite 注册进标准 animation 控制器、就是普通 FlxSprite
	 * 渲染；移植端脚本也走 animation.play，anim.curInstance 恒 null，此前的 draw
	 * 门卫直接 return → reactor 的 coreGlow/coreRing/coreClaw 整体不可见。
	 */
	public var allowPlainDraw:Bool = false;

	@:access(flixel.FlxSprite)
	override function draw()
	{
		if (anim.curInstance == null || anim.curSymbol == null)
		{
			// FlxAnimate.draw（super）是纯 animate 帧绘制（drawLimb 链），不认
			// sprite.frames，没有标准渲染可回落——allowPlainDraw 时按 FlxSprite.draw
			// 的核心逻辑用标准 frames 画（sparrow 帧已同步注册进标准 animation 控制器）。
			if (allowPlainDraw)
			{
				checkClipRect();
				checkEmptyFrame();
				if (alpha == 0 || _frame.type == FlxFrameType.EMPTY) return;
				if (dirty) calcFrame(useFramePixels);
				for (camera in getCamerasLegacy())
				{
					if (!camera.visible || !camera.exists || !isOnScreen(camera)) continue;
					if (isSimpleRender(camera)) drawSimple(camera);
					else drawComplex(camera);
				}
			}
			return;
		}
		super.draw();
	}

	/**
	 * 两条播放头，各推各的：
	 *
	 * 1. `anim`（flxanimate 的 FlxAnim）：Animate 图集的实际播放头。**必须原样推进，
	 *    不能额外干预嵌套符号（零件）的帧。**
	 * 2. 标准 `animation`（FlxSprite 的 FlxAnimationController）：FlxAnimate 覆写了
	 *    `updateAnimation` 且只推 `anim`，标准控制器永不前进 —— sparrow/loadGraphic
	 *    走的精灵（reactor 的 coreGlow/coreRing、舞台道具）脚本 `animation.play()` 后
	 *    会停在第一帧，必须在这里补推。两个控制器互不干扰：谁在画由 draw 的门卫决定。
	 *
	 * 【2026-10-31 夜 事故回溯 · 不要再"修"一次】曾在此处调用 freezePartFrames，
	 * 把整棵符号树的嵌套元素帧钉回 firstFrame，结果**所有角色动画塌成 1 帧**
	 * （whitedk/maroon/pink/grey/chef… 全身静止）。错误前提是交接文档 59 号的
	 * "参考引擎 LF 缺省时 lastFrame=0 → 区间塌成一帧"：
	 *   NMV `FlxAnimateJson.hx:190-210`  `public var LF(get,never):Int;
	 *                                      get_LF() => this.LF ?? this.lastFrame ?? -1;`
	 *   NMV `SymbolInstance.hx:105`        `hasLastFrame = (lastFrame > -1);`
	 * 即缺省 LF 是 **-1**、`hasLastFrame` 为 **false**，走的是
	 * `FlxMath.wrap(firstFrame + 相对帧, 0, 符号总帧-1)`；Dot-Stuff 的
	 * `FlxElement.updateRender` 是 `(相对帧 + firstFrame) % symbol.length`，
	 * 而 `FlxSymbol.length == timeline.totalFrames` —— **两边数学完全等价**。
	 * 语料里 0 个元素带 LF 恰好说明"零件该跟着父时间线走"，钉死才是错的。
	 */
	override function updateAnimation(elapsed:Float):Void
	{
		if (anim != null && anim.curInstance != null && anim.curSymbol != null)
		{
			anim.update(elapsed);
			return;
		}

		// 标准帧渲染路径（sparrow / loadGraphic）：FlxAnimate 覆写了 updateAnimation
		// 且只推 `anim`，FlxSprite 的 `animation` 控制器永不前进 —— 不补推就停在第一帧。
		// 判据与 draw 的门卫完全一致（谁在画就推谁），避免两个控制器互相干扰。
		if (allowPlainDraw && animation != null) animation.update(elapsed);
	}

	/**
	 * 旧库 `FlxAnim.destroy()` 会先把 metadata / curInstance 置空再遍历符号表，
	 * 符号表被提前清空或某个 symbol 销毁失败时中途抛异常。原来在 catch 里继续
	 * 解引用 `anim.metadata`（已被置空）会二次抛 Null Object Reference，异常从
	 * `FlxGroup.destroy` 冒出去打断整局清理（退歌崩溃）。
	 *
	 * 这里先把 anim 摘下来单独兜住销毁，再走正常的 sprite 销毁路径。
	 */
	override function destroy()
	{
		final oldAnim = anim;
		anim = null;
		if (oldAnim != null)
		{
			try
			{
				oldAnim.destroy();
			}
			catch (e:Dynamic)
			{
				FlxG.log.warn('PsychFlxAnimate.destroy: anim teardown failed ($e)');
			}
		}
		super.destroy();
	}

	function _removeBOM(str:String) //Removes BOM byte order indicator
	{
		if (str.charCodeAt(0) == 0xFEFF) str = str.substr(1); //myData = myData.substr(2);
		return str;
	}

	public function pauseAnimation()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		anim.pause();
	}
	public function resumeAnimation()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		anim.play();
	}
}