package objects;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var isPlayer:Bool = false;
	private var char:String = '';
	public var modFolder:String = null;

	public function new(char:String = 'face', isPlayer:Bool = false, ?allowGPU:Bool = true, ?modFolder:String = null)
	{
		super();
		this.isPlayer = isPlayer;
		this.modFolder = modFolder;
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	private var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String, ?allowGPU:Bool = true) {
		if(this.char != char) {
			// 保存当前模组目录
			var oldModDir = Mods.currentModDirectory;
			
			// 如果有模组信息，切换到该模组
			#if MODS_ALLOWED
			if (modFolder != null && modFolder.length > 0 && modFolder != "base")
			{
				Mods.currentModDirectory = modFolder;
			}
			#end
			
			// 路径查找逻辑（保持不变）
			var name:String = 'icons/' + char;
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) 
				name = 'icons/icon-' + char;
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) 
				name = 'icons/icon-face';
			
			var graphic = Paths.image(name, allowGPU);
			
			// 恢复模组目录
			#if MODS_ALLOWED
			Mods.currentModDirectory = oldModDir;
			#end
			
			if (graphic == null) return;
			
			var iSize:Float = Math.round(graphic.width / graphic.height);
			loadGraphic(graphic, true, Math.floor(graphic.width / iSize), Math.floor(graphic.height));
			iconOffsets[0] = (width - 150) / iSize;
			iconOffsets[1] = (height - 150) / iSize;
			updateHitbox();

			animation.add(char, [for(i in 0...frames.frames.length) i], 0, false, isPlayer);
			animation.play(char);
			this.char = char;

			if(char.endsWith('-pixel'))
				antialiasing = false;
			else
				antialiasing = ClientPrefs.data.antialiasing;
		}
	}

	public var autoAdjustOffset:Bool = true;
	override function updateHitbox()
	{
		super.updateHitbox();
		if(autoAdjustOffset)
		{
			offset.x = iconOffsets[0];
			offset.y = iconOffsets[1];
		}
	}

	public function getCharacter():String {
		return char;
	}
}