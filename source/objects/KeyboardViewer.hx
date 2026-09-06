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
	public var displayKeys:Int = 4; // 实际显示的键位数（coop模式下为8）

	var total:Int = 0;

	public static var instance:KeyboardViewer;
	
	// 用于追踪sustain状态
	public var heldKeys:Array<Bool> = [];
	public var keyPressTimes:Array<Float> = [];
	public var keyTimeDisObjects:Array<TimeDis> = [];

	public function new(X:Float, Y:Float, ?keys:Int = 4)
	{
		super();
		instance = this;
		_x = X;
		_y = Y;

		// 设置键位数量
		this.keys = keys;
		
		// 确定显示键位数：coop模式显示8个，否则显示歌曲键位数
		var isCoop:Bool = PlayState.instance != null && (PlayState.instance.opponentMode == "coop" || PlayState.instance.opponentMode == "coop_split");
		displayKeys = isCoop ? 8 : keys;
		
		// 初始化noteArrays
		for(i in 0...displayKeys) noteArrays.push([]);

		_width = (KeyButton.size + 4) * displayKeys;
		_height = (KeyButton.size + 4) * 2;

		// 计算居中偏移
		centerOffset = -_width / 2;

		// 创建键位按钮（使用 displayKeys）
		for (i in 0...displayKeys)
		{
			var buttonX:Float = getButtonX(i);
			var obj:KeyButton = new KeyButton(buttonX, Y, KeyButton.size, KeyButton.size);
			add(obj);
		}

		// 创建高亮按钮（使用 displayKeys）
		for (i in 0...displayKeys)
		{
			var alphaX:Float = getButtonX(i);
			var obj:KeyButtonAlpha = new KeyButtonAlpha(alphaX, Y);
			keyAlphas.push(obj);
			add(obj);
		}

		// 初始化heldKeys数组
		for (i in 0...displayKeys) {
			heldKeys.push(false);
			keyPressTimes.push(0);
			keyTimeDisObjects.push(null);
		}

		// 创建键位文本（使用 displayKeys）
		var textArray:Array<String> = createArray();
		for (i in 0...displayKeys)
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
		var bigButtonWidth:Int = Std.int(Math.max(displayKeys * 25, 50));
		var startX = X + (-_width / 2) + (_width - bigButtonWidth * 2 - 4) / 2;

		// 创建KPS和Total背景按钮
		for (i in 0...2)
		{
			var obj:KeyButton = new KeyButton(startX + (bigButtonWidth + 4) * i, Y + KeyButton.size + 4, bigButtonWidth, KeyButton.size);
			add(obj);
		}

		// 创建KPS和Total标签
		var textArray2:Array<String> = ['KPS', 'total'];
		for (i in 0...2)
		{
			var obj:FlxText = new FlxText(startX + (bigButtonWidth + 4) * i, Y + KeyButton.size + 4, bigButtonWidth, textArray2[i], 16);
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
		kpsText.setFormat("assets/fonts/vcr.ttf", 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		kpsText.borderSize = 1;
		kpsText.x = startX + (bigButtonWidth - kpsText.width) / 2;
		kpsText.y = Y + KeyButton.size + 4 + KeyButton.size / 5 * 3;
		kpsText.color = ClientPrefs.data.keyboardTextColor;
		kpsText.alpha = ClientPrefs.data.keyboardAlpha;
		kpsText.antialiasing = ClientPrefs.data.antialiasing;
		add(kpsText);

		// 创建Total数值文本
		if (FlxG.save.data.keyboardtotal != null)
			total = FlxG.save.data.keyboardtotal;
			
		totalText = new FlxText(startX + bigButtonWidth + 4, Y + KeyButton.size + 4, bigButtonWidth, Std.string(total), 16);
		totalText.setFormat("assets/fonts/vcr.ttf", 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		totalText.borderSize = 1;
		totalText.x = startX + bigButtonWidth + 4 + (bigButtonWidth - totalText.width) / 2;
		totalText.y = Y + KeyButton.size + 4 + KeyButton.size / 5 * 3;
		totalText.color = ClientPrefs.data.keyboardTextColor;
		totalText.alpha = ClientPrefs.data.keyboardAlpha;
		totalText.antialiasing = ClientPrefs.data.antialiasing;
		add(totalText);

		// 初始化时间显示缓存
		DisBitmap.addCache();
	}

	/**
	 * 获取按钮X位置
	 * coop模式：前4个键显示在左半区（对应player的4个键），后4个键显示在右半区（对应opponent的4个键）
	 * 非coop模式：按顺序显示所有键
	 */
	private function getButtonX(index:Int):Float
	{
		return _x + centerOffset + (KeyButton.size + 4) * index;
	}

	/**
	 * 获取键名 - 支持4K legacy键名
	 */
	private function getKeyName(keyIndex:Int, bindIndex:Int = 0):String
	{
		var totalKeys:Int = keys;
		
		// 4K 使用 legacy 键名
		if (totalKeys == 4)
		{
			var legacyKeys:Array<String> = ['note_left', 'note_down', 'note_up', 'note_right'];
			if (keyIndex >= 0 && keyIndex < legacyKeys.length)
				return legacyKeys[keyIndex];
		}
		
		// 5K+ 使用动态键名
		return 'note_${totalKeys}k_${keyIndex + 1}';
	}

	public function pressed(key:Int, ?keyBindIndex:Int = 0)
	{
		var isCoop:Bool = PlayState.instance != null && (PlayState.instance.opponentMode == "coop" || PlayState.instance.opponentMode == "coop_split");
		var displayIndex:Int = key;
		
		// coop模式下，player用左边4个，opponent用右边4个
		if (isCoop && displayKeys == 8)
		{
			if (keyBindIndex == 0)
				displayIndex = key; // player: 0-3
			else
				displayIndex = key + 4; // opponent: 4-7
		}
		
		// 确保数组大小足够
		while (heldKeys.length <= displayIndex) {
			heldKeys.push(false);
			keyPressTimes.push(0);
			keyTimeDisObjects.push(null);
		}
		
		if(displayIndex < keyAlphas.length && displayIndex >= 0) {
			// 如果键已经按住（sustain），不重复处理
			if (heldKeys[displayIndex]) {
				return;
			}
			
			heldKeys[displayIndex] = true;
			keyPressTimes[displayIndex] = Conductor.songPosition;
			
			keyAlphas[displayIndex].alpha = 1 * ClientPrefs.data.keyboardAlpha;
			keyTexts[displayIndex].color = FlxColor.BLACK;
		}

		if(!PlayState.inReplay)total++;
		totalText.text = Std.string(total);
		hitArray.unshift(Date.now());

		if (!ClientPrefs.data.keyboardTimeDisplay)
			return;

		var buttonX:Float = getButtonX(displayIndex);
		var obj:TimeDis = new TimeDis(displayIndex, Conductor.songPosition, buttonX, _y);
		add(obj);
		
		// 存储TimeDis引用
		if (keyTimeDisObjects.length <= displayIndex) {
			keyTimeDisObjects.resize(displayIndex + 1);
		}
		keyTimeDisObjects[displayIndex] = obj;

		if(displayIndex < noteArrays.length) {
			var arr = noteArrays[displayIndex];
			// 如果之前有未结束的 TimeDis，先结束它
			if(arr.length > 0 && arr[arr.length - 1].endTime == -999999) {
				arr[arr.length - 1].endTime = Conductor.songPosition;
			}
			arr.push(obj);
		}
	}

	public function released(key:Int, ?keyBindIndex:Int = 0)
	{
		var isCoop:Bool = PlayState.instance != null && (PlayState.instance.opponentMode == "coop" || PlayState.instance.opponentMode == "coop_split");
		var displayIndex:Int = key;
		
		// coop模式下，player用左边4个，opponent用右边4个
		if (isCoop && displayKeys == 8)
		{
			if (keyBindIndex == 0)
				displayIndex = key; // player: 0-3
			else
				displayIndex = key + 4; // opponent: 4-7
		}
		
		if(displayIndex < keyAlphas.length && displayIndex >= 0) {
			// 标记键已释放
			if (heldKeys.length > displayIndex) {
				heldKeys[displayIndex] = false;
			}
			
			keyAlphas[displayIndex].alpha = 0;
			keyTexts[displayIndex].color = ClientPrefs.data.keyboardTextColor;
		}

		if(displayIndex < noteArrays.length) {
			var arr = noteArrays[displayIndex];
			if(arr.length > 0 && arr[arr.length - 1].endTime == -999999) {
				arr[arr.length - 1].endTime = Conductor.songPosition;
			}
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
		
		var isCoop:Bool = PlayState.instance != null && (PlayState.instance.opponentMode == "coop" || PlayState.instance.opponentMode == "coop_split");
		var totalKeys:Int = keys;
		
		// 4K legacy 键名
		var legacyKeys:Array<String> = ['note_left', 'note_down', 'note_up', 'note_right'];
		
		// 如果是coop模式，我们需要显示8个键（4个player + 4个opponent）
		if (isCoop && displayKeys == 8)
		{
			if (totalKeys == 4)
			{
				// 4K coop - player侧 (bindIndex 0)
				for (i in 0...4)
				{
					var keyList:Array<FlxKey> = Controls.instance.keyboardBinds[legacyKeys[i]];
					var keyCode:FlxKey = 0;
					if (keyList != null && keyList.length > 0)
					{
						keyCode = keyList[0];
					}
					array.push(InputFormatter.getKeyName(keyCode));
				}
				
				// 4K coop - opponent侧 (bindIndex 1)
				for (i in 0...4)
				{
					var keyList:Array<FlxKey> = Controls.instance.keyboardBinds[legacyKeys[i]];
					var keyCode:FlxKey = 0;
					if (keyList != null && keyList.length > 1)
					{
						keyCode = keyList[1];
					}
					else if (keyList != null && keyList.length > 0)
					{
						keyCode = keyList[0];
					}
					array.push(InputFormatter.getKeyName(keyCode));
				}
			}
			else
			{
				// 5K+ coop
				// player侧 (bindIndex 0)
				for (i in 0...4)
				{
					var keyName = 'note_${totalKeys}k_${i+1}';
					var keyList:Array<FlxKey> = Controls.instance.keyboardBinds[keyName];
					var keyCode:FlxKey = 0;
					if (keyList != null && keyList.length > 0)
					{
						keyCode = keyList[0];
					}
					array.push(InputFormatter.getKeyName(keyCode));
				}
				
				// opponent侧 (bindIndex 1)
				for (i in 0...4)
				{
					var keyName = 'note_${totalKeys}k_${i+1}';
					var keyList:Array<FlxKey> = Controls.instance.keyboardBinds[keyName];
					var keyCode:FlxKey = 0;
					if (keyList != null && keyList.length > 1)
					{
						keyCode = keyList[1];
					}
					else if (keyList != null && keyList.length > 0)
					{
						keyCode = keyList[0];
					}
					array.push(InputFormatter.getKeyName(keyCode));
				}
			}
			return array;
		}
		
		// 非coop模式
		if (totalKeys == 4)
		{
			// 4K 非coop
			for (i in 0...4)
			{
				var keyList:Array<FlxKey> = Controls.instance.keyboardBinds[legacyKeys[i]];
				var keyCode:FlxKey = 0;
				if (keyList != null && keyList.length > 0)
				{
					keyCode = keyList[0];
				}
				array.push(InputFormatter.getKeyName(keyCode));
			}
		}
		else
		{
			// 5K+ 非coop
			for (i in 0...displayKeys)
			{
				var keyName = 'note_${totalKeys}k_${i+1}';
				var keyList:Array<FlxKey> = Controls.instance.keyboardBinds[keyName];
				var keyCode:FlxKey = 0;
				if (keyList != null && keyList.length > 0)
				{
					keyCode = keyList[0];
				}
				array.push(InputFormatter.getKeyName(keyCode));
			}
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