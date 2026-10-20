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