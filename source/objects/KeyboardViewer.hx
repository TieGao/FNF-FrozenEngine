//!!!! 本文件所有代码归属FNF NovaFlare Engine  ---> https://github.com/NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine
package objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;
import openfl.display.BitmapData;
import openfl.display.Bitmap;
import openfl.display.Shape;

import backend.InputFormatter;
import backend.Cache;

class KeyboardViewer extends FlxSpriteGroup
{
	public var noteArrays:Array<Array<TimeDis>> = [];
	public var keyAlphas:Array<KeyButtonAlpha> = [];
	public var keyTexts:Array<FlxText> = [];

	public var _x:Float;
	public var _y:Float;
	public var _width:Float;
	public var _height:Float;
	public var centerOffset:Float;
	public var kpsText:FlxText;
	public var totalText:FlxText;

	public var keys:Int = 4;

	var total:Int = 0;

	public static var instance:KeyboardViewer;

	public function new(X:Float, Y:Float, ?keys:Int = 4)
	{
		super();
		instance = this;

		_x = X;
		_y = Y;

		// 设置键位数量
		this.keys = keys;

		for(i in 0...keys) noteArrays.push([]);

		_width = (KeyButton.size + 4) * keys;
		_height = (KeyButton.size + 4) * 2;

		// 计算居中偏移
		centerOffset = -_width / 2;

		// 创建键位按钮
		for (i in 0...keys)
		{
			var buttonX:Float = getButtonX(i);
			var obj:KeyButton = new KeyButton(buttonX, Y, KeyButton.size, KeyButton.size);
			add(obj);
		}

		// 创建高亮按钮
		for (i in 0...keys)
		{
			var alphaX:Float = getButtonX(i);
			var obj:KeyButtonAlpha = new KeyButtonAlpha(alphaX, Y);
			keyAlphas.push(obj);
			add(obj);
		}

		// 创建键位文本
		var textArray:Array<String> = createArray();
		for (i in 0...keys)
		{
			var textX:Float = getButtonX(i);
			var obj:FlxText = new FlxText(textX, Y, KeyButton.size, textArray[i], 16);
			obj.setFormat("assets/fonts/vcr.ttf", 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			obj.x = textX + (KeyButton.size - obj.width) / 2;
			obj.y = Y + (KeyButton.size - obj.height) / 2;
			obj.color = ClientPrefs.data.keyboardTextColor;
			obj.alpha = ClientPrefs.data.keyboardAlpha;
			keyTexts.push(obj);
			add(obj);
		}

		// 计算大按钮宽度（根据键位数量调整）
		var bigButtonWidth:Int = keys * 25;
		var startX = X + (-_width / 2) + (_width - bigButtonWidth * 2 - 4) / 2;

		// 创建KPS和Total背景按钮
		for (i in 0...2)
		{
			var obj:KeyButton = new KeyButton(startX + (bigButtonWidth + 4) * i, Y + KeyButton.size + 4, bigButtonWidth, KeyButton.size);
			add(obj);
		}

		// 创建KPS和Total标签
		var textArray:Array<String> = ['KPS', 'total'];
		for (i in 0...2)
		{
			var obj:FlxText = new FlxText(startX + (bigButtonWidth + 4) * i, Y + KeyButton.size + 4, bigButtonWidth, textArray[i], 16);
			obj.setFormat("assets/fonts/vcr.ttf", 25, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			obj.x = startX + (bigButtonWidth + 4) * i + (bigButtonWidth - obj.width) / 2;
			obj.y = Y + KeyButton.size + 4 + (KeyButton.size - obj.height) / 4;
			obj.color = ClientPrefs.data.keyboardTextColor;
			obj.alpha = ClientPrefs.data.keyboardAlpha;
			obj.antialiasing = ClientPrefs.data.antialiasing;
			add(obj);
		}

		// 创建KPS数值文本
		kpsText = new FlxText(startX, Y + KeyButton.size + 4, bigButtonWidth, '0', 16);
		kpsText.setFormat("assets/fonts/vcr.ttf", 15, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		kpsText.x = startX + (bigButtonWidth - kpsText.width) / 2;
		kpsText.y = Y + KeyButton.size + 4 + KeyButton.size / 5 * 3;
		kpsText.color = ClientPrefs.data.keyboardTextColor;
		kpsText.alpha = ClientPrefs.data.keyboardAlpha;
		add(kpsText);

		// 创建Total数值文本
		if (FlxG.save.data.keyboardtotal != null)
			total = FlxG.save.data.keyboardtotal;
			
		totalText = new FlxText(startX + bigButtonWidth + 4, Y + KeyButton.size + 4, bigButtonWidth, Std.string(total), 16);
		totalText.setFormat("assets/fonts/vcr.ttf", 15, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		totalText.x = startX + bigButtonWidth + 4 + (bigButtonWidth - totalText.width) / 2;
		totalText.y = Y + KeyButton.size + 4 + KeyButton.size / 5 * 3;
		totalText.color = ClientPrefs.data.keyboardTextColor;
		totalText.alpha = ClientPrefs.data.keyboardAlpha;
		add(totalText);

		// 初始化时间显示缓存
		DisBitmap.addCache();
	}

	private function getButtonX(index:Int):Float
	{
		var mappedIndex:Int = index;
		var isCoop:Bool = PlayState.instance != null && (PlayState.instance.opponentMode == "coop" || PlayState.instance.opponentMode == "coop_split");
		if (isCoop && keys == 8)
		{
			mappedIndex = if (index < 4) index + 4 else index - 4;
		}
		return _x + centerOffset + (KeyButton.size + 4) * mappedIndex;
	}

	public function pressed(key:Int)
	{
		if(key < keyAlphas.length) {
			keyAlphas[key].alpha = 1 * ClientPrefs.data.keyboardAlpha;
			keyTexts[key].color = FlxColor.BLACK;
		}

		total++;
		totalText.text = Std.string(total);
		hitArray.unshift(Date.now());

		if (!ClientPrefs.data.keyboardTimeDisplay)
			return;

		var obj:TimeDis = new TimeDis(key, Conductor.songPosition, getButtonX(key), _y);
		add(obj);

		if(key < noteArrays.length) {
			var arr = noteArrays[key];
			if(arr.length > 0 && arr[arr.length - 1].endTime == -999999)
				arr[arr.length - 1].endTime = Conductor.songPosition;
			arr.push(obj);
		}
	}

	public function released(key:Int)
	{
		if(key < keyAlphas.length) {
			keyAlphas[key].alpha = 0;
			keyTexts[key].color = ClientPrefs.data.keyboardTextColor;
		}

		if(key < noteArrays.length) {
			var arr = noteArrays[key];
			if(arr.length > 0 && arr[arr.length - 1].endTime == -999999)
				arr[arr.length - 1].endTime = Conductor.songPosition;
		}
	}

	public function save()
	{
		FlxG.save.data.keyboardtotal = total;
		FlxG.save.flush();
	}

	public function createArray():Array<String>
	{
		var array:Array<String> = [];
		
		var keyNames = ['note_left', 'note_down', 'note_up', 'note_right'];
		var mode:String = PlayState.instance != null ? PlayState.instance.opponentMode : "player";
		
		for (i in 0...keys)
		{
			var keyIndex = i % 4;
			var bindIndex:Int = (mode == "coop" || mode == "coop_split") && i >= 4 ? 1 : 0;
			var keyList:Array<FlxKey> = Controls.instance.keyboardBinds[keyNames[keyIndex]];
			var keyCode:FlxKey = 0;
			if (keyList != null && keyList.length > 0)
			{
				var safeIndex:Int = bindIndex < keyList.length ? bindIndex : keyList.length - 1;
				keyCode = keyList[safeIndex];
			}
			array.push(InputFormatter.getKeyName(keyCode));
		}
		
		return array;
	}

	public function removeObj(obj:TimeDis)
	{
		if(obj.line < noteArrays.length) {
			noteArrays[obj.line].remove(obj);
		}
		remove(obj, true);
		obj.destroy();
	}

	public var kps:Int = 0;
	public var kpsCheck:Int = 0;
	public var hitArray:Array<Date> = [];

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		// 更新KPS计算
		var currentTime = Date.now().getTime();
		var i = hitArray.length - 1;
		while (i >= 0)
		{
			var time:Date = hitArray[i];
			if (time != null && time.getTime() + 1000 < currentTime)
				hitArray.remove(time);
			else
				break;
			i--;
		}
		kps = hitArray.length;

		if (kpsCheck != kps)
		{
			kpsCheck = kps;
			kpsText.text = Std.string(kps);
		}
	}
}

class KeyButton extends FlxSprite
{
	var bgAlpha = 0.3 * ClientPrefs.data.keyboardAlpha;
	var lineAlpha = 0.8 * ClientPrefs.data.keyboardAlpha;

	public static var size = 50;

	public function new(X:Float, Y:Float, Width:Int, Height:Int)
	{
		super(X, Y);

		var shape:Shape = new Shape();
		shape.graphics.lineStyle(2, 0xFFFFFF, lineAlpha);
		shape.graphics.drawRoundRect(0, 0, Width, Height, Std.int(size / 3), Std.int(size / 3));
		shape.graphics.lineStyle();
		shape.graphics.beginFill(0xFFFFFF, bgAlpha);
		shape.graphics.drawRoundRect(0, 0, Width, Height, Std.int(size / 3), Std.int(size / 3));
		shape.graphics.endFill();

		var bitmapData:BitmapData = new BitmapData(Width, Height, true, 0x00FFFFFF);
		bitmapData.draw(shape);

		makeGraphic(Width, Height, FlxColor.TRANSPARENT);
		pixels = bitmapData;
		antialiasing = ClientPrefs.data.antialiasing;
		color = ClientPrefs.data.keyboardBGColor;
	}
}

class KeyButtonAlpha extends FlxSprite
{
	var size = KeyButton.size;

	public var tween:FlxTween;

	public function new(X:Float, Y:Float)
	{
		super(X, Y);

		var shape:Shape = new Shape();
		shape.graphics.beginFill(0xFFFFFF, 1);
		shape.graphics.drawRoundRect(0, 0, size, size, Std.int(size / 3), Std.int(size / 3));
		shape.graphics.endFill();

		var bitmapData:BitmapData = new BitmapData(size, size, true, 0x00FFFFFF);
		bitmapData.draw(shape);

		makeGraphic(size, size, FlxColor.TRANSPARENT);
		pixels = bitmapData;
		antialiasing = ClientPrefs.data.antialiasing;
		alpha = 0;
	}
}

	class TimeDis extends FlxSprite
{
	public var startTime:Float;
	public var endTime:Float = -999999;
	public var line:Int;

	var durationTime:Float = ClientPrefs.data.keyboardTime;

	public function new(Line:Int, Time:Float, X:Float, Y:Float)
	{
		this.line = Line;
		super(X, Y - 4 - DisBitmap.Height);
		this.startTime = Time;
		frames = Cache.getFrame('keyboardViewer');
		_frame.frame.height = 1;
		color = ClientPrefs.data.keyboardBGColor;
		alpha = ClientPrefs.data.keyboardAlpha;
	}

	var saveTime:Float;

	override function update(elapsed:Float)
	{
		if (endTime == -999999)
		{
			_frame.frame.y = (1 - ((Conductor.songPosition - startTime) / durationTime)) * DisBitmap.Height;
			_frame.frame.height = ((Conductor.songPosition - startTime) / durationTime) * DisBitmap.Height;
			offset.y = -(1 - ((Conductor.songPosition - startTime) / durationTime)) * DisBitmap.Height;
			if (_frame.frame.y < 0)
				_frame.frame.y = 0;
			if (Conductor.songPosition - startTime > durationTime)
				offset.y = 0;
			saveTime = Conductor.songPosition;
		}
		else
		{
			if (endTime - startTime < durationTime)
				_frame.frame.y = (1 - ((Conductor.songPosition - startTime) / durationTime)) * DisBitmap.Height;
			else
				_frame.frame.y = (1 - ((Conductor.songPosition - (endTime - durationTime)) / durationTime)) * DisBitmap.Height;
			offset.y -= -((Conductor.songPosition - saveTime) / durationTime) * DisBitmap.Height;
			saveTime = Conductor.songPosition;
		}
		if (_frame.frame.height > DisBitmap.Height)
			_frame.frame.height = DisBitmap.Height;
		if (_frame.frame.height <= 0)
			_frame.frame.height = 1; // fix bug

		if (endTime != -999999 && Conductor.songPosition - endTime > durationTime)
			KeyboardViewer.instance.removeObj(this);
	}
}

class DisBitmap extends Bitmap
{
	static public var Width:Int = KeyButton.size;
	static public var Height:Int = Std.int(KeyButton.size * 3);

	static public var colorArray:Array<FlxColor> = [];

	static public function addCache() {
		var BitmapData:BitmapData = new BitmapData(Width, Height, true, 0);
		var shape:Shape = new Shape();

		for (i in 0...Std.int(Height / 10))
		{
			shape.graphics.beginFill(FlxColor.WHITE, i / Std.int(Height / 10));
			shape.graphics.drawRect(0, i, Width, 1);
			shape.graphics.endFill();
		}
		shape.graphics.beginFill(FlxColor.WHITE);
		shape.graphics.drawRect(0, Std.int(Height / 10), Width, Height - Std.int(Height / 10));
		shape.graphics.endFill();
		BitmapData.draw(shape);

		var spr:FlxSprite = new FlxSprite();
		var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(BitmapData);
		spr.loadGraphic(newGraphic);

		Cache.setFrame('keyboardViewer', {graphic:null, frame:spr.frames});
	}
}