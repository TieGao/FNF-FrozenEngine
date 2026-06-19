package substates;

import backend.WeekData;
import backend.Highscore;

import objects.HealthIcon;

class ResetScoreSubState extends MusicBeatSubstate
{
	var bg:FlxSprite;
	var alphabetArray:Array<Alphabet> = [];
	var icon:HealthIcon;
	var onYes:Bool = false;
	var yesText:Alphabet;
	var noText:Alphabet;

	var song:String;
	var difficulty:Int;
	var week:Int;
	var modFolder:String;

	public function new(song:String, difficulty:Int, character:String, week:Int = -1, ?modFolder:String = null)
	{
		this.song = song;
		this.difficulty = difficulty;
		this.week = week;
		this.modFolder = modFolder;

		super();

		var name:String = song;
		if(week > -1) {
			name = WeekData.weeksLoaded.get(WeekData.weeksList[week]).weekName;
		}
		name += ' (' + Difficulty.getString(difficulty) + ')?';

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var tooLong:Float = (name.length > 18) ? 0.8 : 1;
		var text:Alphabet = new Alphabet(0, 180, Language.getPhrase('reset_score', 'Reset the score of'), true);
		text.screenCenter(X);
		alphabetArray.push(text);
		text.alpha = 0;
		add(text);
		var text:Alphabet = new Alphabet(0, text.y + 90, name, true);
		text.scaleX = tooLong;
		text.screenCenter(X);
		if(week == -1) text.x += 60 * tooLong;
		alphabetArray.push(text);
		text.alpha = 0;
		add(text);
		if(week == -1) {
			icon = new HealthIcon(character, false, true, modFolder);
			icon.setGraphicSize(Std.int(icon.width * tooLong));
			icon.updateHitbox();
			icon.setPosition(text.x - icon.width + (10 * tooLong), text.y - 30);
			icon.alpha = 0;
			add(icon);
		}

		yesText = new Alphabet(0, text.y + 150, Language.getPhrase('Yes'), true);
		yesText.screenCenter(X);
		yesText.x -= 200;
		yesText.ID = 0; // 用于识别
		add(yesText);
		noText = new Alphabet(0, text.y + 150, Language.getPhrase('No'), true);
		noText.screenCenter(X);
		noText.x += 200;
		noText.ID = 1; // 用于识别
		add(noText);
		
		for(letter in yesText.letters) letter.color = FlxColor.RED;
		updateOptions();
	}

	override function update(elapsed:Float)
	{
		bg.alpha += elapsed * 1.5;
		if(bg.alpha > 0.6) bg.alpha = 0.6;

		for (i in 0...alphabetArray.length) {
			var spr = alphabetArray[i];
			spr.alpha += elapsed * 2.5;
		}
		if(week == -1) icon.alpha += elapsed * 2.5;

		// ---- 鼠标控制 ----
		#if FLX_MOUSE
		var mouseX:Float = FlxG.mouse.x;
		var mouseY:Float = FlxG.mouse.y;

		// 检测鼠标悬停到 Yes/No 文本
		var hoveringYes:Bool = FlxG.mouse.overlaps(yesText, camera);
		var hoveringNo:Bool = FlxG.mouse.overlaps(noText, camera);

		if (hoveringYes && !onYes) {
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
			onYes = true;
			updateOptions();
		} else if (hoveringNo && onYes) {
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
			onYes = false;
			updateOptions();
		}

		// 点击确认
		if (FlxG.mouse.justPressed) {
			if (hoveringYes) {
				executeConfirm();
			} else if (hoveringNo) {
				FlxG.sound.play(Paths.sound('cancelMenu'), 1);
				close();
			}
		}
		#end

		// ---- 键盘控制 ----
		if(controls.UI_LEFT_P || controls.UI_RIGHT_P) {
			FlxG.sound.play(Paths.sound('scrollMenu'), 1);
			onYes = !onYes;
			updateOptions();
		}
		if(controls.BACK || FlxG.mouse.justPressedRight) {
			FlxG.sound.play(Paths.sound('cancelMenu'), 1);
			close();
		} else if(controls.ACCEPT) {
			executeConfirm();
		}
		super.update(elapsed);
	}

	function executeConfirm():Void
	{
		if(onYes) {
			if(week == -1) {
				Highscore.resetSong(song, difficulty, modFolder);
			} else {
				Highscore.resetWeek(WeekData.weeksList[week], difficulty, modFolder);
			}
		}
		FlxG.sound.play(Paths.sound('cancelMenu'), 1);
		close();
	}

	function updateOptions() {
		var scales:Array<Float> = [0.75, 1];
		var alphas:Array<Float> = [0.6, 1.25];
		var confirmInt:Int = onYes ? 1 : 0;

		yesText.alpha = alphas[confirmInt];
		yesText.scale.set(scales[confirmInt], scales[confirmInt]);
		noText.alpha = alphas[1 - confirmInt];
		noText.scale.set(scales[1 - confirmInt], scales[1 - confirmInt]);
		if(week == -1) icon.animation.curAnim.curFrame = confirmInt;
	}
}