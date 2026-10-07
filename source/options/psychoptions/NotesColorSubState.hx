package options.psychoptions;

import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.display.shapes.FlxShapeCircle;
import flixel.input.keyboard.FlxKey;
import lime.system.Clipboard;
import flixel.util.FlxGradient;
import objects.StrumNote;
import objects.Note;

import shaders.RGBPalette.RGBShaderReference;

class NotesColorSubState extends MusicBeatSubstate
{
	var onModeColumn:Bool = true;
	var curSelectedMode:Int = 0;
	var curSelectedNote:Int = 0;   // ★ 全局索引 0..(dataArray.length-1)
	var onPixel:Bool = false;
	var dataArray:Array<Array<FlxColor>>;

	// ===== 分页相关 =====
	var notePage:Int = 0;
	final NOTES_PER_PAGE:Int = 4;
	var totalPages:Int = 1;
	var prevPageBtn:FlxSprite;
	var nextPageBtn:FlxSprite;
	var pageText:FlxText;

	var hexTypeLine:FlxSprite;
	var hexTypeNum:Int = -1;
	var hexTypeVisibleTimer:Float = 0;

	var copyButton:FlxSprite;
	var pasteButton:FlxSprite;

	var colorGradient:FlxSprite;
	var colorGradientSelector:FlxSprite;
	var colorPalette:FlxSprite;
	var colorWheel:FlxSprite;
	var colorWheelSelector:FlxSprite;

	var alphabetR:Alphabet;
	var alphabetG:Alphabet;
	var alphabetB:Alphabet;
	var alphabetHex:Alphabet;

	var modeBG:FlxSprite;
	var notesBG:FlxSprite;

	// controller support
	var controllerPointer:FlxSprite;
	var _lastControllerMode:Bool = false;
	var tipTxt:FlxText;

	public function new() {
		super();
		
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Note Colors Menu", null);
		#end
		
		onPixel = PlayState.isPixelStage;
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFEA71FD;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		var grid:FlxBackdrop = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
		grid.velocity.set(40, 40);
		grid.alpha = 0;
		FlxTween.tween(grid, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
		add(grid);

		modeBG = new FlxSprite(215, 85).makeGraphic(315, 115, FlxColor.BLACK);
		modeBG.visible = false;
		modeBG.alpha = 0.4;
		add(modeBG);

		notesBG = new FlxSprite(140, 190).makeGraphic(480, 125, FlxColor.BLACK);
		notesBG.visible = false;
		notesBG.alpha = 0.4;
		add(notesBG);

		modeNotes = new FlxTypedGroup<FlxSprite>();
		add(modeNotes);

		myNotes = new FlxTypedGroup<StrumNote>();
		add(myNotes);

		var bg:FlxSprite = new FlxSprite(720).makeGraphic(FlxG.width - 720, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.25;
		add(bg);
		var bg:FlxSprite = new FlxSprite(750, 160).makeGraphic(FlxG.width - 780, 540, FlxColor.BLACK);
		bg.alpha = 0.25;
		add(bg);
		
		var text:Alphabet = new Alphabet(50, 86, 'CTRL', false);
		text.alignment = CENTERED;
		text.setScale(0.4);
		add(text);

		copyButton = new FlxSprite(760, 50).loadGraphic(Paths.image('noteColorMenu/copy'));
		copyButton.alpha = 0.6;
		add(copyButton);

		pasteButton = new FlxSprite(1180, 50).loadGraphic(Paths.image('noteColorMenu/paste'));
		pasteButton.alpha = 0.6;
		add(pasteButton);

		colorGradient = FlxGradient.createGradientFlxSprite(60, 360, [FlxColor.WHITE, FlxColor.BLACK]);
		colorGradient.setPosition(780, 200);
		add(colorGradient);

		colorGradientSelector = new FlxSprite(770, 200).makeGraphic(80, 10, FlxColor.WHITE);
		colorGradientSelector.offset.y = 5;
		add(colorGradientSelector);

		colorPalette = new FlxSprite(820, 580).loadGraphic(Paths.image('noteColorMenu/palette', false));
		colorPalette.scale.set(20, 20);
		colorPalette.updateHitbox();
		colorPalette.antialiasing = false;
		add(colorPalette);
		
		colorWheel = new FlxSprite(860, 200).loadGraphic(Paths.image('noteColorMenu/colorWheel'));
		colorWheel.setGraphicSize(360, 360);
		colorWheel.updateHitbox();
		add(colorWheel);

		colorWheelSelector = new FlxShapeCircle(0, 0, 8, {thickness: 0}, FlxColor.WHITE);
		colorWheelSelector.offset.set(8, 8);
		colorWheelSelector.alpha = 0.6;
		add(colorWheelSelector);

		var txtX = 980;
		var txtY = 90;
		alphabetR = makeColorAlphabet(txtX - 100, txtY);
		add(alphabetR);
		alphabetG = makeColorAlphabet(txtX, txtY);
		add(alphabetG);
		alphabetB = makeColorAlphabet(txtX + 100, txtY);
		add(alphabetB);
		alphabetHex = makeColorAlphabet(txtX, txtY - 55);
		add(alphabetHex);
		hexTypeLine = new FlxSprite(0, 20).makeGraphic(5, 62, FlxColor.WHITE);
		hexTypeLine.visible = false;
		add(hexTypeLine);

		// ===== 分页按钮 UI =====
		// 放在 4 个 strum 下方（strum 在 y=200 左右），避免挡到 bigNote（y=325）
		var btnY:Float = 130;
		var btnLeftX:Float = 140;
		var btnRightX:Float = 600;

		var prevTxt:FlxText = new FlxText(btnLeftX, btnY, 40, "<", 36);
		prevTxt.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		prevTxt.borderSize = 2;
		prevTxt.antialiasing = ClientPrefs.data.antialiasing;
		add(prevTxt);
		prevPageBtn = prevTxt; // 用 FlxText 本身当按钮

		var nextTxt:FlxText = new FlxText(btnRightX, btnY, 40, ">", 36);
		nextTxt.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		nextTxt.borderSize = 2;
		nextTxt.antialiasing = ClientPrefs.data.antialiasing;
		add(nextTxt);
		nextPageBtn = nextTxt;

		pageText = new FlxText(340, btnY + 4, 100, "", 20);
		pageText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		pageText.borderSize = 2;
		pageText.antialiasing = ClientPrefs.data.antialiasing;
		add(pageText);

		spawnNotes();
		updateNotes(true);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);

		var tipX = 20;
		var tipY = 660;
		var tip:FlxText = new FlxText(tipX, tipY, 0, Language.getPhrase('note_colors_tip', 'Press RESET to Reset the selected Note Part.'), 16);
		tip.antialiasing = ClientPrefs.data.antialiasing;
		tip.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		tip.borderSize = 2;
		add(tip);

		tipTxt = new FlxText(tipX, tipY + 24, 0, '', 16);
		tipTxt.antialiasing = ClientPrefs.data.antialiasing;
		tipTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		tipTxt.borderSize = 2;
		add(tipTxt);
		updateTip();

		controllerPointer = new FlxShapeCircle(0, 0, 20, {thickness: 0}, FlxColor.WHITE);
		controllerPointer.offset.set(20, 20);
		controllerPointer.screenCenter();
		controllerPointer.alpha = 0.6;
		add(controllerPointer);
		
		FlxG.mouse.visible = !controls.controllerMode;
		controllerPointer.visible = controls.controllerMode;
		_lastControllerMode = controls.controllerMode;
	}

	function updateTip()
	{
		var key:String = !controls.controllerMode ? Language.getPhrase('note_colors_shift', 'Shift') : Language.getPhrase('note_colors_lb', 'Left Shoulder Button');
		tipTxt.text = Language.getPhrase('note_colors_hold_tip', 'Hold {1} + Press RESET key to fully reset the selected Note.', [key]);
	}

	var _storedColor:FlxColor;
	var changingNote:Bool = false;
	var holdingOnObj:FlxSprite;
	var allowedTypeKeys:Map<FlxKey, String> = [
		ZERO => '0', ONE => '1', TWO => '2', THREE => '3', FOUR => '4', FIVE => '5', SIX => '6', SEVEN => '7', EIGHT => '8', NINE => '9',
		NUMPADZERO => '0', NUMPADONE => '1', NUMPADTWO => '2', NUMPADTHREE => '3', NUMPADFOUR => '4', NUMPADFIVE => '5', NUMPADSIX => '6',
		NUMPADSEVEN => '7', NUMPADEIGHT => '8', NUMPADNINE => '9', A => 'A', B => 'B', C => 'C', D => 'D', E => 'E', F => 'F'];

	override function update(elapsed:Float) {
		if (controls.BACK) {
			FlxG.mouse.visible = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
			return;
		}

		super.update(elapsed);

		#if !mobile
		if (FlxG.mouse.justPressedRight)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
			return;
		}
		#end

		// Early controller checking
		if(FlxG.gamepads.anyJustPressed(ANY)) controls.controllerMode = true;
		else if(FlxG.mouse.justPressed || FlxG.mouse.deltaViewX != 0 || FlxG.mouse.deltaViewY != 0) controls.controllerMode = false;
		//
		
		var changedToController:Bool = false;
		if(controls.controllerMode != _lastControllerMode)
		{
			FlxG.mouse.visible = !controls.controllerMode;
			controllerPointer.visible = controls.controllerMode;

			if(controls.controllerMode)
			{
				controllerPointer.x = FlxG.mouse.x;
				controllerPointer.y = FlxG.mouse.y;
				changedToController = true;
			}
			_lastControllerMode = controls.controllerMode;
			updateTip();
		}

		// controller things
		var analogX:Float = 0;
		var analogY:Float = 0;
		var analogMoved:Bool = false;
		if(controls.controllerMode && (changedToController || FlxG.gamepads.anyInput()))
		{
			for (gamepad in FlxG.gamepads.getActiveGamepads())
			{
				analogX = gamepad.getXAxis(LEFT_ANALOG_STICK);
				analogY = gamepad.getYAxis(LEFT_ANALOG_STICK);
				analogMoved = (analogX != 0 || analogY != 0);
				if(analogMoved) break;
			}
			controllerPointer.x = Math.max(0, Math.min(FlxG.width, controllerPointer.x + analogX * 1000 * elapsed));
			controllerPointer.y = Math.max(0, Math.min(FlxG.height, controllerPointer.y + analogY * 1000 * elapsed));
		}
		var controllerPressed:Bool = (controls.controllerMode && controls.ACCEPT);
		//

		if(FlxG.keys.justPressed.CONTROL)
		{
			onPixel = !onPixel;
			// 保持当前页
			notePage = Std.int(curSelectedNote / NOTES_PER_PAGE);
			spawnNotes();
			updateNotes(true);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		}

		// 手柄肩键翻页（键盘用 [ ] 或 Q/E 也行，这里走手柄）
		if (hexTypeNum < 0 && controls.controllerMode)
		{
			if (FlxG.gamepads.anyJustPressed(LEFT_SHOULDER))  changePage(-1);
			if (FlxG.gamepads.anyJustPressed(RIGHT_SHOULDER)) changePage(1);
		}

		if(hexTypeNum > -1)
		{
			var keyPressed:FlxKey = cast (FlxG.keys.firstJustPressed(), FlxKey);
			hexTypeVisibleTimer += elapsed;
			var changed:Bool = false;
			if(changed = FlxG.keys.justPressed.LEFT)
				hexTypeNum--;
			else if(changed = FlxG.keys.justPressed.RIGHT)
				hexTypeNum++;
			else if(allowedTypeKeys.exists(keyPressed))
			{
				var curColor:String = alphabetHex.text;
				var newColor:String = curColor.substring(0, hexTypeNum) + allowedTypeKeys.get(keyPressed) + curColor.substring(hexTypeNum + 1);

				var colorHex:FlxColor = FlxColor.fromString('#' + newColor);
				setShaderColor(colorHex);
				_storedColor = getShaderColor();
				updateColors();
				
				hexTypeNum++;
				changed = true;
			}
			else if(FlxG.keys.justPressed.ENTER)
				hexTypeNum = -1;
			
			var end:Bool = false;
			if(changed)
			{
				if (hexTypeNum > 5)
				{
					hexTypeNum = -1;
					end = true;
					hexTypeLine.visible = false;
				}
				else
				{
					if(hexTypeNum < 0) hexTypeNum = 0;
					else if(hexTypeNum > 5) hexTypeNum = 5;
					centerHexTypeLine();
					hexTypeLine.visible = true;
				}
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			}
			if(!end) hexTypeLine.visible = Math.floor(hexTypeVisibleTimer * 2) % 2 == 0;
		}
		else
		{
			var add:Int = 0;
			if(analogX == 0 && !changedToController)
			{
				if(controls.UI_LEFT_P) add = -1;
				else if(controls.UI_RIGHT_P) add = 1;
			}

			if(analogY == 0 && !changedToController && (controls.UI_UP_P || controls.UI_DOWN_P))
			{
				onModeColumn = !onModeColumn;
				modeBG.visible = onModeColumn;
				notesBG.visible = !onModeColumn;
			}
	
			if(add != 0)
			{
				if(onModeColumn) changeSelectionMode(add);
				else changeSelectionNote(add);
			}
			hexTypeLine.visible = false;
		}

		// Copy/Paste buttons
		var generalMoved:Bool = (FlxG.mouse.justMoved || analogMoved);
		var generalPressed:Bool = (FlxG.mouse.justPressed || controllerPressed);
		if(generalMoved)
		{
			copyButton.alpha = 0.6;
			pasteButton.alpha = 0.6;
		}

		if(pointerOverlaps(copyButton))
		{
			copyButton.alpha = 1;
			if(generalPressed)
			{
				Clipboard.text = getShaderColor().toHexString(false, false);
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
				trace('copied: ' + Clipboard.text);
			}
			hexTypeNum = -1;
		}
		else if (pointerOverlaps(pasteButton))
		{
			pasteButton.alpha = 1;
			if(generalPressed)
			{
				var formattedText = Clipboard.text.trim().toUpperCase().replace('#', '').replace('0x', '');
				var newColor:Null<FlxColor> = FlxColor.fromString('#' + formattedText);
				if(newColor != null && formattedText.length == 6)
				{
					setShaderColor(newColor);
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
					_storedColor = getShaderColor();
					updateColors();
				}
				else
					FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
			}
			hexTypeNum = -1;
		}

		// Click
		if(generalPressed)
		{
			hexTypeNum = -1;

			// ===== 翻页按钮优先 =====
			if (pointerOverlaps(prevPageBtn))
			{
				changePage(-1);
			}
			else if (pointerOverlaps(nextPageBtn))
			{
				changePage(1);
			}
			else if (pointerOverlaps(modeNotes))
			{
				modeNotes.forEachAlive(function(note:FlxSprite) {
					if (curSelectedMode != note.ID && pointerOverlaps(note))
					{
						modeBG.visible = notesBG.visible = false;
						curSelectedMode = note.ID;
						onModeColumn = true;
						updateNotes();
						FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
					}
				});
			}
			else if (pointerOverlaps(myNotes))
			{
				myNotes.forEachAlive(function(note:StrumNote) {
					if (curSelectedNote != note.ID && pointerOverlaps(note))
					{
						modeBG.visible = notesBG.visible = false;
						curSelectedNote = note.ID;   // ★ 全局 ID
						onModeColumn = false;
						bigNote.rgbShader.parent = Note.globalRgbShaders[note.ID];
						bigNote.shader = Note.globalRgbShaders[note.ID].shader;
						updateNotes();
						FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
					}
				});
			}
			else if (pointerOverlaps(colorWheel)) {
				_storedColor = getShaderColor();
				holdingOnObj = colorWheel;
			}
			else if (pointerOverlaps(colorGradient)) {
				_storedColor = getShaderColor();
				holdingOnObj = colorGradient;
			}
			else if (pointerOverlaps(colorPalette)) {
				setShaderColor(colorPalette.pixels.getPixel32(
					Std.int((pointerX() - colorPalette.x) / colorPalette.scale.x), 
					Std.int((pointerY() - colorPalette.y) / colorPalette.scale.y)));
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
				updateColors();
			}
			else if (pointerOverlaps(skinNote))
			{
				onPixel = !onPixel;
				notePage = Std.int(curSelectedNote / NOTES_PER_PAGE);
				spawnNotes();
				updateNotes(true);
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			}
			else if(pointerY() >= hexTypeLine.y && pointerY() < hexTypeLine.y + hexTypeLine.height &&
					Math.abs(pointerX() - 1000) <= 84)
			{
				hexTypeNum = 0;
				for (letter in alphabetHex.letters)
				{
					if(letter.x - letter.offset.x + letter.width <= pointerX()) hexTypeNum++;
					else break;
				}
				if(hexTypeNum > 5) hexTypeNum = 5;
				hexTypeLine.visible = true;
				centerHexTypeLine();
			}
			else holdingOnObj = null;
		}
		// holding
		if(holdingOnObj != null)
		{
			if (FlxG.mouse.justReleased || (controls.controllerMode && controls.justReleased('accept')))
			{
				holdingOnObj = null;
				_storedColor = getShaderColor();
				updateColors();
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			}
			else if (generalMoved || generalPressed)
			{
				if (holdingOnObj == colorGradient)
				{
					var newBrightness = 1 - FlxMath.bound((pointerY() - colorGradient.y) / colorGradient.height, 0, 1);
					_storedColor.alpha = 1;
					if(_storedColor.brightness == 0)
						setShaderColor(FlxColor.fromRGBFloat(newBrightness, newBrightness, newBrightness));
					else
						setShaderColor(FlxColor.fromHSB(_storedColor.hue, _storedColor.saturation, newBrightness));
					updateColors(_storedColor);
				}
				else if (holdingOnObj == colorWheel)
				{
					var center:FlxPoint = new FlxPoint(colorWheel.x + colorWheel.width/2, colorWheel.y + colorWheel.height/2);
					var mouse:FlxPoint = pointerFlxPoint();
					var hue:Float = FlxMath.wrap(FlxMath.wrap(Std.int(mouse.degreesTo(center)), 0, 360) - 90, 0, 360);
					var sat:Float = FlxMath.bound(mouse.dist(center) / colorWheel.width*2, 0, 1);
					if(sat != 0) setShaderColor(FlxColor.fromHSB(hue, sat, _storedColor.brightness));
					else setShaderColor(FlxColor.fromRGBFloat(_storedColor.brightness, _storedColor.brightness, _storedColor.brightness));
					updateColors();
				}
			} 
		}
		else if(controls.RESET && hexTypeNum < 0)
		{
			// ★ 用 ID 找 strum
			var targetStrum:StrumNote = getStrumById(curSelectedNote);

			if(FlxG.keys.pressed.SHIFT || FlxG.gamepads.anyPressed(LEFT_SHOULDER))
			{
				for (i in 0...3)
				{
					var strumRGB:RGBShaderReference = targetStrum.rgbShader;
					var color:FlxColor = !onPixel ? ClientPrefs.defaultData.arrowRGB[curSelectedNote][i] :
													ClientPrefs.defaultData.arrowRGBPixel[curSelectedNote][i];
					switch(i)
					{
						case 0:
							getShader().r = strumRGB.r = color;
						case 1:
							getShader().g = strumRGB.g = color;
						case 2:
							getShader().b = strumRGB.b = color;
					}
					dataArray[curSelectedNote][i] = color;
				}
			}
			setShaderColor(!onPixel ? ClientPrefs.defaultData.arrowRGB[curSelectedNote][curSelectedMode] : ClientPrefs.defaultData.arrowRGBPixel[curSelectedNote][curSelectedMode]);
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
			updateColors();
		}
	}

	// ===== 分页工具 =====
	function changePage(change:Int)
	{
		if (totalPages <= 1) return;
		var newPage:Int = notePage + change;
		if (newPage < 0) newPage = totalPages - 1;
		if (newPage >= totalPages) newPage = 0;
		if (newPage == notePage) return;

		notePage = newPage;
		// 切页后选中该页第一个
		curSelectedNote = notePage * NOTES_PER_PAGE;
		spawnNotes();
		updateNotes(true);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function updatePageUI()
	{
		if (pageText != null)
			pageText.text = (notePage + 1) + " / " + totalPages;
		if (prevPageBtn != null) prevPageBtn.alpha = (notePage > 0) ? 1 : 0.3;
		if (nextPageBtn != null) nextPageBtn.alpha = (notePage < totalPages - 1) ? 1 : 0.3;
	}

	/** 按全局 ID 找当前页里对应的 strum */
	function getStrumById(id:Int):StrumNote
	{
		for (n in myNotes.members)
			if (n != null && n.ID == id) return n;
		// 兜底：返回第一个，避免空引用
		return myNotes.members[0];
	}

	function pointerOverlaps(obj:Dynamic)
	{
		if (!controls.controllerMode) return FlxG.mouse.overlaps(obj);
		return FlxG.overlap(controllerPointer, obj);
	}

	function pointerX():Float
	{
		if (!controls.controllerMode) return FlxG.mouse.x;
		return controllerPointer.x;
	}
	function pointerY():Float
	{
		if (!controls.controllerMode) return FlxG.mouse.y;
		return controllerPointer.y;
	}
	function pointerFlxPoint():FlxPoint
	{
		if (!controls.controllerMode) return FlxG.mouse.getViewPosition();
		return controllerPointer.getViewPosition();
	}

	function centerHexTypeLine()
	{
		if(hexTypeNum > 0)
		{
			var letter = alphabetHex.letters[hexTypeNum-1];
			hexTypeLine.x = letter.x - letter.offset.x + letter.width;
		}
		else
		{
			var letter = alphabetHex.letters[0];
			hexTypeLine.x = letter.x - letter.offset.x;
		}
		hexTypeLine.x += hexTypeLine.width;
		hexTypeVisibleTimer = 0;
	}

	function changeSelectionMode(change:Int = 0) {
		curSelectedMode += change;
		if (curSelectedMode < 0)
			curSelectedMode = 2;
		if (curSelectedMode >= 3)
			curSelectedMode = 0;

		modeBG.visible = true;
		notesBG.visible = false;
		updateNotes();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function changeSelectionNote(change:Int = 0) {
		// ★ 在整份 dataArray 范围内循环；跨页时自动翻页
		var newIdx:Int = curSelectedNote + change;
		if (newIdx < 0)
			newIdx = dataArray.length - 1;
		if (newIdx >= dataArray.length)
			newIdx = 0;

		// 跨页了才重建
		var newPage:Int = Std.int(newIdx / NOTES_PER_PAGE);
		if (newPage != notePage)
		{
			notePage = newPage;
			curSelectedNote = newIdx;
			spawnNotes();
			updateNotes(true);
			FlxG.sound.play(Paths.sound('scrollMenu'));
			return;
		}

		curSelectedNote = newIdx;
		modeBG.visible = false;
		notesBG.visible = true;
		bigNote.rgbShader.parent = Note.globalRgbShaders[curSelectedNote];
		bigNote.shader = Note.globalRgbShaders[curSelectedNote].shader;
		updateNotes();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	// alphabets
	function makeColorAlphabet(x:Float = 0, y:Float = 0):Alphabet
	{
		var text:Alphabet = new Alphabet(x, y, '', true);
		text.alignment = CENTERED;
		text.setScale(0.6);
		add(text);
		return text;
	}

	// notes sprites functions
	var skinNote:FlxSprite;
	var modeNotes:FlxTypedGroup<FlxSprite>;
	var myNotes:FlxTypedGroup<StrumNote>;
	var bigNote:Note;

	public function spawnNotes()
	{
		dataArray = !onPixel ? ClientPrefs.data.arrowRGB : ClientPrefs.data.arrowRGBPixel;
		if (onPixel) PlayState.stageUI = "pixel";

		// 计算总页数
		totalPages = Std.int(Math.ceil(dataArray.length / NOTES_PER_PAGE));
		if (totalPages < 1) totalPages = 1;
		if (notePage >= totalPages) notePage = totalPages - 1;
		if (notePage < 0) notePage = 0;

		var pageStart:Int = notePage * NOTES_PER_PAGE;
		var pageEnd:Int = Std.int(Math.min(pageStart + NOTES_PER_PAGE, dataArray.length)) - 1;

		// 保证 curSelectedNote 落在当前页
		if (curSelectedNote < pageStart || curSelectedNote > pageEnd)
			curSelectedNote = pageStart;

		// clear groups
		modeNotes.forEachAlive(function(note:FlxSprite) {
			note.kill();
			note.destroy();
		});
		myNotes.forEachAlive(function(note:StrumNote) {
			note.kill();
			note.destroy();
		});
		modeNotes.clear();
		myNotes.clear();

		if(skinNote != null)
		{
			remove(skinNote);
			skinNote.destroy();
		}
		if(bigNote != null)
		{
			remove(bigNote);
			bigNote.destroy();
		}

		// respawn stuff
		var res:Int = onPixel ? 160 : 17;
		skinNote = new FlxSprite(48, 24).loadGraphic(Paths.image('noteColorMenu/' + (onPixel ? 'note' : 'notePixel')), true, res, res);
		skinNote.antialiasing = ClientPrefs.data.antialiasing;
		skinNote.setGraphicSize(68);
		skinNote.updateHitbox();
		skinNote.animation.add('anim', [0], 24, true);
		skinNote.animation.play('anim', true);
		if(!onPixel) skinNote.antialiasing = false;
		add(skinNote);

		var res:Int = !onPixel ? 160 : 17;
		for (i in 0...3)
		{
			var newNote:FlxSprite = new FlxSprite(230 + (100 * i), 100).loadGraphic(Paths.image('noteColorMenu/' + (!onPixel ? 'note' : 'notePixel')), true, res, res);
			newNote.antialiasing = ClientPrefs.data.antialiasing;
			newNote.setGraphicSize(85);
			newNote.updateHitbox();
			newNote.animation.add('anim', [i], 24, true);
			newNote.animation.play('anim', true);
			newNote.ID = i;
			if(onPixel) newNote.antialiasing = false;
			modeNotes.add(newNote);
		}

		// ===== 只渲染当前页的 4 个 note =====
		Note.globalRgbShaders = [];
		for (i in 0...dataArray.length)
			Note.initializeGlobalRGBShader(i);

		var shownCount:Int = Std.int(Math.min(NOTES_PER_PAGE, dataArray.length - pageStart));
		for (i in 0...shownCount)
		{
			var globalIdx:Int = pageStart + i;
			var newNote:StrumNote = new StrumNote(150 + (480 / shownCount * i), 200, globalIdx, 0);
			newNote.useRGBShader = true;
			newNote.setGraphicSize(102);
			newNote.updateHitbox();
			newNote.ID = globalIdx;   // ★ 全局 ID
			myNotes.add(newNote);
		}

		bigNote = new Note(0, 0, false, true);
		bigNote.setPosition(250, 325);
		bigNote.setGraphicSize(250);
		bigNote.updateHitbox();
		bigNote.rgbShader.parent = Note.globalRgbShaders[curSelectedNote];
		bigNote.shader = Note.globalRgbShaders[curSelectedNote].shader;
		for (i in 0...Note.colArray.length)
		{
			if(!onPixel) bigNote.animation.addByPrefix('note$i', Note.colArray[i] + '0', 24, true);
			else bigNote.animation.add('note$i', [i + 4], 24, true);
		}
		insert(members.indexOf(myNotes) + 1, bigNote);
		_storedColor = getShaderColor();
		PlayState.stageUI = "normal";

		updatePageUI();
	}

	function updateNotes(?instant:Bool = false)
	{
		for (note in modeNotes)
			note.alpha = (curSelectedMode == note.ID) ? 1 : 0.6;

		for (note in myNotes)
		{
			var newAnim:String = curSelectedNote == note.ID ? 'confirm' : 'pressed';
			note.alpha = (curSelectedNote == note.ID) ? 1 : 0.6;
			if(note.animation.curAnim == null || note.animation.curAnim.name != newAnim) note.playAnim(newAnim, true);
			if(instant) note.animation.curAnim.finish();
		}
		// bigNote 只有 note0~note3 4 个方向动画，用方向索引
		bigNote.animation.play('note' + (curSelectedNote % 4), true);
		updateColors();
	}

	function updateColors(specific:Null<FlxColor> = null)
	{
		var color:FlxColor = getShaderColor();
		var wheelColor:FlxColor = specific == null ? getShaderColor() : specific;
		alphabetR.text = Std.string(color.red);
		alphabetG.text = Std.string(color.green);
		alphabetB.text = Std.string(color.blue);
		alphabetHex.text = color.toHexString(false, false);
		for (letter in alphabetHex.letters) letter.color = color;

		colorWheel.color = FlxColor.fromHSB(0, 0, color.brightness);
		colorWheelSelector.setPosition(colorWheel.x + colorWheel.width/2, colorWheel.y + colorWheel.height/2);
		if(wheelColor.brightness != 0)
		{
			var hueWrap:Float = wheelColor.hue * Math.PI / 180;
			colorWheelSelector.x += Math.sin(hueWrap) * colorWheel.width/2 * wheelColor.saturation;
			colorWheelSelector.y -= Math.cos(hueWrap) * colorWheel.height/2 * wheelColor.saturation;
		}
		colorGradientSelector.y = colorGradient.y + colorGradient.height * (1 - color.brightness);

		// ★ 用 ID 找 strum（当前页里才存在）
		var targetStrum:StrumNote = getStrumById(curSelectedNote);
		if (targetStrum != null)
		{
			var strumRGB:RGBShaderReference = targetStrum.rgbShader;
			switch(curSelectedMode)
			{
				case 0:
					getShader().r = strumRGB.r = color;
				case 1:
					getShader().g = strumRGB.g = color;
				case 2:
					getShader().b = strumRGB.b = color;
			}
		}
	}

	function setShaderColor(value:FlxColor) dataArray[curSelectedNote][curSelectedMode] = value;
	function getShaderColor() return dataArray[curSelectedNote][curSelectedMode];
	function getShader() return Note.globalRgbShaders[curSelectedNote];

	override function destroy()
	{
		Note.globalRgbShaders = [];
		super.destroy();
	}
}