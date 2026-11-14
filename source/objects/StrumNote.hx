package objects;

import backend.animation.PsychAnimationController;

import shaders.RGBPalette;
import shaders.RGBPalette.RGBShaderReference;
import shaders.NoteHSV;

import backend.NoteSkinStyle;

class StrumNote extends FlxSprite
{
	public var rgbShader:RGBShaderReference;
	public var resetAnim:Float = 0;
	private var noteData:Int = 0;
	public var direction:Float = 90;
	public var downScroll:Bool = false;
	public var sustainReduce:Bool = true;
	private var player:Int;
	
	public var texture(default, set):String = null;
	private function set_texture(value:String):String {
		if(texture != value) {
			texture = value;
			reloadNote();
		}
		return value;
	}

	public var useRGBShader:Bool = true;
	public var noteStyle:String = NoteSkinStyle.RGB;
	// legacy 体系的 HSV 只在生成时挂一次（0.6.x 行为），之后 playAnim 不再碰 shader 槽位
	var hsvAttached:Bool = false;
	// auto + 谱面 disableNoteRGB：RGB、HSV 都不挂
	var shaderDisabled:Bool = false;
	/** forceSkin：直接指定贴图（编辑器预览用，绕过谱面 arrowSkin / 玩家皮肤解析） */
	public function new(x:Float, y:Float, leData:Int, player:Int, ?forceSkin:String = null) {
		animation = new PsychAnimationController(this);

		rgbShader = new RGBShaderReference(this, Note.initializeGlobalRGBShader(leData));
		rgbShader.enabled = false;
		
		var colorSets:Array<Array<FlxColor>> = PlayState.isPixelStage ? ClientPrefs.data.arrowRGBPixel : ClientPrefs.data.arrowRGB;
		var arr:Array<FlxColor> = null;
		if(colorSets != null && colorSets.length > 0)
		{
			var colorIndex:Int = Note.getNoteColorIndex(Note.getColumnsPerPlayer(), leData);
			arr = colorSets[colorIndex];
		}
		
		if(arr != null && arr.length >= 3)
		{
			@:bypassAccessor
			{
				rgbShader.r = arr[0];
				rgbShader.g = arr[1];
				rgbShader.b = arr[2];
			}
		}

		noteData = leData;
		this.player = player;
		this.noteData = leData;
		this.ID = noteData;
		super(x, y);

		var skin:String = (forceSkin != null && forceSkin.length > 0) ? forceSkin : Note.getNoteSkinPath();
		var customSkin:String = skin + Note.getNoteSkinPostfix();
		if(Paths.fileExists('images/$customSkin.png', IMAGE)) skin = customSkin;

		texture = skin; //Load texture and anims
		scrollFactor.set();
		playAnim('static');
	}

	public function reloadNote()
	{
		var lastAnim:String = null;
		if(animation.curAnim != null) lastAnim = animation.curAnim.name;

		// 贴图换了就重新判定着色体系（与 Note 同一套判据）
		noteStyle = Note.getNoteStyle(texture);
		useRGBShader = (noteStyle != NoteSkinStyle.LEGACY);
		// auto + 谱面 disableNoteRGB：谱面说啥就是啥，RGB、HSV 都不挂（与 Note.updateNoteShader 同一条规则）
		shaderDisabled = (NoteSkinStyle.noteMode() == NoteSkinStyle.AUTO
			&& PlayState.SONG != null && PlayState.SONG.disableNoteRGB);

		var dirIdx:Int = Note.getNoteDirectionIndex(Note.getColumnsPerPlayer(), noteData);


		var keys = Note.getColumnsPerPlayer();  // 获取当前键数
    	var scale = Note.getNoteScaleForKeys(keys); // 复用同一个函数
		var pixelScale = Note.getPixelNoteScaleForKeys(keys);
		if(PlayState.isPixelStage)
		{
			loadGraphic(Paths.image('pixelUI/' + texture));
			width = width / 4;
			height = height / 5;
			loadGraphic(Paths.image('pixelUI/' + texture), true, Math.floor(width), Math.floor(height));

			antialiasing = false;
			setGraphicSize(Std.int(width * PlayState.daPixelZoom * pixelScale));

			animation.add('green', [6]);
			animation.add('red', [7]);
			animation.add('blue', [5]);
			animation.add('purple', [4]);
			switch (dirIdx)
			{
				case 0:
					animation.add('static', [0]);
					animation.add('pressed', [4, 8], 12, false);
					animation.add('confirm', [12, 16], 24, false);
				case 1:
					animation.add('static', [1]);
					animation.add('pressed', [5, 9], 12, false);
					animation.add('confirm', [13, 17], 24, false);
				case 2:
					animation.add('static', [2]);
					animation.add('pressed', [6, 10], 12, false);
					animation.add('confirm', [14, 18], 12, false);
				case 3:
					animation.add('static', [3]);
					animation.add('pressed', [7, 11], 12, false);
					animation.add('confirm', [15, 19], 24, false);
			}
		}
		else
		{
			frames = Paths.getSparrowAtlas(texture);
			animation.addByPrefix('green', 'arrowUP');
			animation.addByPrefix('blue', 'arrowDOWN');
			animation.addByPrefix('purple', 'arrowLEFT');
			animation.addByPrefix('red', 'arrowRIGHT');

			antialiasing = ClientPrefs.data.antialiasing;
			setGraphicSize(Std.int(width * scale));

			switch (dirIdx)
			{
				case 0:
					animation.addByPrefix('static', 'arrowLEFT');
					animation.addByPrefix('pressed', 'left press', 24, false);
					animation.addByPrefix('confirm', 'left confirm', 24, false);
				case 1:
					animation.addByPrefix('static', 'arrowDOWN');
					animation.addByPrefix('pressed', 'down press', 24, false);
					animation.addByPrefix('confirm', 'down confirm', 24, false);
				case 2:
					animation.addByPrefix('static', 'arrowUP');
					animation.addByPrefix('pressed', 'up press', 24, false);
					animation.addByPrefix('confirm', 'up confirm', 24, false);
				case 3:
					animation.addByPrefix('static', 'arrowRIGHT');
					animation.addByPrefix('pressed', 'right press', 24, false);
					animation.addByPrefix('confirm', 'right confirm', 24, false);
			}
		}
		updateHitbox();

		if(lastAnim != null)
		{
			playAnim(lastAnim, true);
		}
	}

	public function playerPosition() {
		var keys = Note.getColumnsPerPlayer();
		var spacing = Note.getNoteSpacing(keys);
		x += spacing * noteData;
		x += 50;
		x += ((FlxG.width / 2) * player);
	}

	override function update(elapsed:Float) {
		if(resetAnim > 0) {
			resetAnim -= elapsed;
			if(resetAnim <= 0) {
				playAnim('static');
				resetAnim = 0;
			}
		}
		super.update(elapsed);
	}

	public function playAnim(anim:String, ?force:Bool = false) {
		animation.play(anim, force);
		if(animation.curAnim != null)
		{
			centerOffsets();
			centerOrigin();
		}

		if (shaderDisabled) return;

		if (useRGBShader)
		{
			// RGB 体系保持 0.7+ 行为：静态箭头是灰色占位不染色，按下/确认帧才挂 RGB。
			// 模组中途把 sprite.shader 换成自己的（Pibby 的 strum glitch 之类）是模组自己的事，
			// confirm 时 set_enabled 会把槽位要回来 —— 那是 0.7 的固有语义，模组自己兼容。
			rgbShader.enabled = (animation.curAnim != null && animation.curAnim.name != 'static');
		}
		else if (!hsvAttached)
		{
			// legacy 体系保持 0.6.x 行为：HSV 只在生成时挂这一次（static 也挂），全 0 不挂；
			// 之后 playAnim 不再碰槽位，模组换 shader 引擎不抢。
			hsvAttached = true;
			NoteHSV.apply(this, noteData);
		}
	}
}
