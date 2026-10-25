package cutscenes;

import flixel.addons.text.FlxTypeText;

import cutscenes.DialogueBoxPsych.DialogueFile;
import cutscenes.DialogueBoxPsych.DialogueLine;

/**
 * Pixel (Week 6 style) dialogue box, used by the vanilla Pico Mix covers of `senpai` / `roses`.
 *
 * This is the pixel counterpart of `DialogueBoxPsych`:
 * - the box itself is `weeb/pixelUI/dialogueBox-new` (same atlas the vanilla game uses for roses)
 * - text is drawn with `pixel-latin.ttf` + a hard shadow, like `cutscenes.DialogueBox` does
 * - speakers are positioned with the vanilla `offsets` value (stored in each dialogue
 *   character json as `pixel_offsets`), relative to the screen center.
 *
 * WHY NOT REUSE `cutscenes.DialogueBox` (the PE native pixel box used by School)?
 * That class is hard-wired to the vanilla senpai/roses/thorns cutscenes:
 *   - box atlas is picked by songName (DialogueBox.hx:48), cannot be pointed at `dialogueBox-new`
 *   - exactly two speaker slots, both with hard-coded atlases (weeb/senpaiPortrait, weeb/bfPortrait)
 *   - speaker names are only matched against 'dad'/'bf' (DialogueBox.hx:234), everything else
 *     silently shows no portrait at all
 *   - reads flat "Name: text" txt lines (DialogueBox.hx:257) with a fixed typing speed, so there is
 *     no per-line expression / speed / portrait
 * Pico Mix needs 7 speakers (senpai, senpai-bwuh, senpai-angry, nene-pixel, nene-pixel-peeved,
 * pico-pixel, pico-pixel-peeved) with per-line expressions, so the layout below is copied from it
 * while the data model follows `DialogueFile` (same json the rest of the engine already uses).
 *
 * Triggered by adding `"pixel": true` to a dialogue json so `PlayState.startDialogue()`
 * picks this class instead of `DialogueBoxPsych`.
 */
class PixelDialogueBox extends FlxSpriteGroup
{
	// --- layout constants, all identical to cutscenes.DialogueBox (the PE native pixel box) ---
	public static var BOX_X:Float = -20;
	public static var BOX_Y:Float = 45;
	public static var BOX_ZOOM_MULT:Float = 0.9; // multiplied by PlayState.daPixelZoom
	public static var TEXT_X:Float = 240;
	public static var TEXT_Y:Float = 500;
	public static var TEXT_WIDTH_RATIO:Float = 0.6; // DialogueBox uses FlxG.width * 0.6
	public static var TEXT_SIZE:Int = 32;
	public static var LONG_TEXT_ADD:Int = 24;

	/**
	 * Screen X of each speaker's *visual centre*, measured from PE's own portraits after its 5.4x scale:
	 *   left  slot = weeb/senpaiPortrait, screenCenter(X) at 5.4x -> content spans 232..507  (centre 370)
	 *   right slot = weeb/bfPortrait,     x = 0            at 5.4x -> content spans 772..1085 (centre 928)
	 * PE aligns the big 249x145 atlas cells, we centre the tightly-cropped V-Slice portraits instead,
	 * which lands the artwork on exactly the same spot on screen.
	 */
	public static var LEFT_SPEAKER_CENTER_X:Float = 400;
	public static var RIGHT_SPEAKER_CENTER_X:Float = 1228;

	// Top edge of the box body inside the 248x144 atlas frame (the rose ornaments stick out a bit higher,
	// that part is intentionally allowed to overlap the speakers).
	public static var BOX_TOP_IN_FRAME:Int = 73;
	public static var BOX_FRAME_HEIGHT:Int = 144;
	// How many pixels the speaker sinks into the box. 0 = bottom edge exactly on the box top edge.
	public static var SPEAKER_SINK:Float = 2;

	var bgFade:FlxSprite;
	var box:FlxSprite;
	var txt:FlxTypeText;
	var skipText:FlxText;

	var dialogueList:DialogueFile;
	var characters:Array<DialogueCharacter> = [];
	var characterNames:Array<String> = [];

	var currentLine:Int = 0;
	var curCharacter:String = '';
	var textFinished:Bool = false;
	var ending:Bool = false;
	var boxOpened:Bool = false;

	public var finishThing:Void->Void;
	public var nextDialogueThing:Void->Void = null;
	public var skipDialogueThing:Void->Void = null;

	public function new(dialogueFile:DialogueFile, ?song:String = null)
	{
		super();

		dialogueList = dialogueFile;

		createBackdrop();
		createCharacters();
		createBox();
		createText();
		createSkipText();

		startLine(0);
	}

	// ------------------------------------------------------------------ creation

	function createBackdrop():Void
	{
		bgFade = new FlxSprite();
		bgFade.makeGraphic(1, 1, 0xFFB3DFD8);
		bgFade.setGraphicSize(Std.int(FlxG.width * 1.3), Std.int(FlxG.height * 1.3));
		bgFade.updateHitbox();
		bgFade.screenCenter();
		bgFade.scrollFactor.set();
		bgFade.alpha = 0;
		add(bgFade);
		FlxTween.tween(bgFade, {alpha: 0.7}, 0.6);
	}

	function createCharacters():Void
	{
		if (dialogueList == null || dialogueList.dialogue == null) return;

		var seen:Map<String, Bool> = new Map<String, Bool>();
		for (line in dialogueList.dialogue)
		{
			if (line == null || line.portrait == null) continue;
			var portrait:String = line.portrait;
			if (portrait.length < 1 || seen.exists(portrait)) continue;
			if (portrait == 'bf') portrait = DialogueCharacter.DEFAULT_CHARACTER; // keep parity with DialogueBoxPsych

			seen.set(portrait, true);

			var char:DialogueCharacter = new DialogueCharacter(0, 0, portrait);
			var scale:Float = char.jsonFile.scale;
			if (Math.isNaN(scale) || scale <= 0) scale = 1;
			char.setGraphicSize(Std.int(char.width * DialogueCharacter.DEFAULT_SCALE * scale));
			char.updateHitbox();
			char.scrollFactor.set();
			char.alpha = 0.00001;
			char.visible = false;

			characters.push(char);
			characterNames.push(portrait);
			add(char);
		}
	}

	function createBox():Void
	{
		box = new FlxSprite(BOX_X, BOX_Y);
		box.frames = Paths.getSparrowAtlas('weeb/pixelUI/dialogueBox-new');
		var newAtlas:Bool = box.frames != null;
		if (!newAtlas) box.frames = Paths.getSparrowAtlas('weeb/pixelUI/dialogueBox-pixel');

		box.antialiasing = false;
		if (newAtlas)
		{
			box.animation.addByPrefix('enter', 'Text Box Appear', 24, false);
			box.animation.addByPrefix('speaking', 'Text Box Speaking', 24, true);
			box.animation.addByPrefix('idle', 'Text Box wait to click', 24, true);
			box.animation.addByPrefix('exit', 'Text Box Appear', 24, false);
		}
		else // legacy PE atlas (2x2 appear frames only), there is no separate speaking/idle set
		{
			box.animation.addByPrefix('enter', 'Text Box Appear instance 1', 24, false);
			box.animation.addByPrefix('speaking', 'Text Box Appear instance 1', 24, true);
			box.animation.addByPrefix('idle', 'Text Box Appear instance 1', 24, true);
			box.animation.addByPrefix('exit', 'Text Box Appear instance 1', 24, false);
		}
		box.animation.play('enter');
		box.setGraphicSize(Std.int(box.width * PlayState.daPixelZoom * BOX_ZOOM_MULT));
		box.updateHitbox();
		box.screenCenter(X);
		box.scrollFactor.set();
		add(box);
	}

	function createText():Void
	{
		var width:Int = Std.int(FlxG.width * TEXT_WIDTH_RATIO);
		txt = new FlxTypeText(Std.int(TEXT_X), Std.int(TEXT_Y), width, '', TEXT_SIZE);
		txt.font = Paths.font('pixel-latin.ttf');
		txt.color = 0xFF3F2021;
		txt.borderStyle = SHADOW;
		txt.borderColor = 0xFFD89494;
		txt.setBorderStyle(SHADOW_XY(2, 2));
		txt.sounds = [FlxG.sound.load(Paths.sound('pixelText'), 0.6)];
		txt.scrollFactor.set();
		txt.completeCallback = onTextComplete;
		add(txt);
	}

	function createSkipText():Void
	{
		skipText = new FlxText(FlxG.width - 320, FlxG.height - 30, 300, Language.getPhrase('dialogue_skip', 'Press BACK to Skip'), 16);
		skipText.setFormat(null, 16, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
		skipText.borderSize = 2;
		skipText.scrollFactor.set();
		add(skipText);
	}

	// ------------------------------------------------------------------ lines

	function startLine(index:Int):Void
	{
		if (dialogueList == null || dialogueList.dialogue == null || index >= dialogueList.dialogue.length)
		{
			endDialogue();
			return;
		}

		var line:DialogueLine = dialogueList.dialogue[index];
		if (line == null)
		{
			startLine(index + 1);
			return;
		}

		currentLine = index + 1;

		if (!boxOpened)
		{
			boxOpened = true;
			box.animation.play('enter', true);
		}
		else
		{
			box.animation.play('speaking', true);
		}

		var lineText:String = (line.text == null || line.text.length < 1) ? ' ' : line.text;
		var speed:Float = (line.speed == null || Math.isNaN(line.speed) || line.speed <= 0) ? 0.05 : line.speed;

		txt.resetText(lineText);
		// measure rows before the typewriter starts (start() with forceRestart wipes it again)
		txt.text = lineText;
		txt.y = TEXT_Y;
		if (txt.textField.numLines > 2) txt.y -= LONG_TEXT_ADD;
		txt.alpha = 1;
		txt.start(speed, true);

		textFinished = false;

		showCharacter(line.portrait, line.expression);

		if (nextDialogueThing != null) nextDialogueThing();
	}

	function onTextComplete():Void
	{
		textFinished = true;
		box.animation.play('idle');

		var idx:Int = characterNames.indexOf(curCharacter);
		if (idx >= 0 && idx < characters.length)
		{
			var char:DialogueCharacter = characters[idx];
			if (char.animation.curAnim != null && char.animationIsLoop()) char.playAnim(char.animation.curAnim.name, true);
		}
	}

	function showCharacter(portrait:String, expression:String):Void
	{
		if (portrait == 'bf') portrait = DialogueCharacter.DEFAULT_CHARACTER;
		curCharacter = portrait;

		for (i in 0...characters.length)
		{
			var char:DialogueCharacter = characters[i];
			if (characterNames[i] == portrait)
			{
				char.visible = true;
				char.alpha = 1;
				char.x = getCharacterX(char);
				char.y = getCharacterY(char);
				char.playAnim(expression, false);
			}
			else
			{
				char.alpha = 0.00001;
				char.visible = false;
			}
		}
	}

	/**
	 * Which of PE's two speaker slots this character occupies. PE only ever had a left (senpai)
	 * and a right (bf) portrait, so the mapping is the same one the vanilla cutscenes use.
	 */
	inline function isRightSpeaker(char:DialogueCharacter):Bool
	{
		return char.jsonFile.dialogue_pos == 'right';
	}

	/** X position matching PE's portrait slot, but centring the tightly-cropped V-Slice artwork. */
	inline function getCharacterX(char:DialogueCharacter):Float
	{
		var centre:Float = isRightSpeaker(char) ? RIGHT_SPEAKER_CENTER_X : LEFT_SPEAKER_CENTER_X;
		return centre - char.width * 0.5;
	}

	/** Y position of the box body's top edge on screen. */
	inline function getBoxTop():Float
	{
		return BOX_Y + BOX_TOP_IN_FRAME * (box.height / BOX_FRAME_HEIGHT);
	}

	/**
	 * Speakers stand on top of the box: their bottom edge rests on the box body's top edge,
	 * instead of using the vanilla vertical offset (which leaves them floating mid-screen).
	 */
	inline function getCharacterY(char:DialogueCharacter):Float
	{
		return getBoxTop() - char.height + SPEAKER_SINK + 150;
	}

	// ------------------------------------------------------------------ input / ending

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (ending) return;

		// settle a finished "enter" animation onto its looping idle counterpart
		var idx:Int = characterNames.indexOf(curCharacter);
		if (idx >= 0 && idx < characters.length)
		{
			var char:DialogueCharacter = characters[idx];
			if (char.animation.curAnim != null && char.animation.finished) char.playAnim(char.animation.curAnim.name, true);
		}

		if (Controls.instance.BACK)
		{
			if (skipDialogueThing != null) skipDialogueThing();
			endDialogue();
			return;
		}

		if (Controls.instance.ACCEPT)
		{
			if (!textFinished)
			{
				txt.skip();
				FlxG.sound.play(Paths.sound('clickText'), 0.8);
			}
			else if (currentLine >= dialogueList.dialogue.length)
			{
				endDialogue();
			}
			else
			{
				startLine(currentLine);
				FlxG.sound.play(Paths.sound('clickText'), 0.8);
			}
		}
	}

	function endDialogue():Void
	{
		if (ending) return;
		ending = true;

		if (skipText != null) skipText.visible = false;

		if (box != null && box.animation.curAnim != null)
		{
			box.animation.play('exit', true);
			if (box.animation.curAnim != null && box.animation.curAnim.frames.length > 0)
			{
				box.animation.curAnim.curFrame = box.animation.curAnim.frames.length - 1;
				box.animation.curAnim.reverse();
			}
		}

		for (char in characters)
			FlxTween.tween(char, {alpha: 0}, 0.35);

		if (txt != null) FlxTween.tween(txt, {alpha: 0}, 0.35);
		if (box != null) FlxTween.tween(box, {alpha: 0}, 0.5);
		if (bgFade != null) FlxTween.tween(bgFade, {alpha: 0}, 0.55);

		new FlxTimer().start(0.65, function(_)
		{
			if (finishThing != null) finishThing();
			kill();
		});
	}
}
