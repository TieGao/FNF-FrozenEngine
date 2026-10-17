package flxanimate;

import flixel.graphics.frames.FlxAtlasFrames;
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
	 *
	 * 原版的多图集角色（`MultiAnimateAtlasCharacter`）走 `FlxAnimateFrames.combineAtlas(textureList)`，
	 * 效果一样，只是那边一次并好几份。角色 json 用逐动画的 `assetPath` 指定子图集。
	 *
	 * ⚠️ `FlxAtlasFrames.addAtlas` 内部是 `pushFrame(frame, overwriteHash=false)` ——
	 * 帧名冲突时**保留旧帧**。原版所有分尸图的 sprite 名都是 "0"/"1"/"2"…，必然全撞，
	 * 所以子图集在移植期就要把 sprite 名加前缀改掉（连同 `Animation.json` 里的 `ASI.N`）。
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
						anim.symbolDictionary.set(sn, new FlxSymbol(sn, tl));
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

		var extra:AnimAtlas = cast haxe.Json.parse(_removeBOM(animText));

		// 子图集的主时间轴也要注册 —— 逐动画的 `name` 写的就是它的主符号名
		anim.symbolDictionary.set(extra.AN.SN, new FlxSymbol(haxe.io.Path.withoutDirectory(extra.AN.SN), FlxTimeline.fromJSONEx(extra.AN.TL)));
		if (extra.SD != null)
		{
			for (symbol in extra.SD.S)
				anim.symbolDictionary.set(symbol.SN, new FlxSymbol(haxe.io.Path.withoutDirectory(symbol.SN), FlxTimeline.fromJSONEx(symbol.TL)));
		}
	}

	/**
	 * `FlxAnim.addBySymbolIndices` 的防环版本。
	 *
	 * 原版实现会把自定义时间轴以「动画名」写进 `symbolDictionary`。如果图集里恰好有
	 * 与动画名同名的子符号、且被主时间轴引用（实例：sserafim-kazuha 的 SD 里有 `idle`），
	 * 注册时就会顶掉原子符号 —— 渲染主时间轴 → `idle`(已被替换成引用主符号的自定义时间轴)
	 * → 主时间轴 → … 无限递归，hxcpp 直接栈溢出闪退（c00000fd，不走崩溃处理器所以无日志）。
	 *
	 * 这里把自定义时间轴注册到 `<符号名>#<动画名>` 的独立键（永不与图集符号撞名）；
	 * 播放路径 `animsMap[动画名]` 不变，原图集符号保持完整，环断掉。
	 */
	public function safeAddBySymbolIndices(name:String, symbolName:String, indices:Array<Int>, frameRate:Float, looped:Bool):Void
	{
		if (anim.symbolDictionary == null) return;
		if (!anim.symbolDictionary.exists(symbolName))
		{
			FlxG.log.error('$symbolName does not exist as a symbol! maybe you misspelled it?');
			return;
		}

		var regKey:String = symbolName + '#' + name;
		var outerParams = new FlxElement(new SymbolParameters((looped) ? Loop : PlayOnce), new FlxMatrix(1, 0, 0, 1, 0, 0));
		var timeline = new FlxTimeline();
		timeline.add("Layer 1");

		// keyframe 摆在 0..n-1（播放帧号），firstFrame 才是 indices 的值（符号内帧号）。
		// 之前把值同时当 keyframe 位置用：传 [108..120] 会造出 121 帧的 timeline，
		// 前 108 帧全是空白；非 0 起始的段（danceRight 的 15..29）也必然错位。
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
	}

	override function draw()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		super.draw();
	}

	override function destroy()
	{
		try
		{
			super.destroy();
		}
		catch(e:haxe.Exception)
		{
			anim.curInstance = FlxDestroyUtil.destroy(anim.curInstance);
			anim.stageInstance = FlxDestroyUtil.destroy(anim.stageInstance);
			//anim.metadata = FlxDestroyUtil.destroy(anim.metadata);
			anim.metadata.destroy();
			anim.symbolDictionary = null;
		}
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