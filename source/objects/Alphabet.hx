package objects;

import haxe.Json;
import openfl.utils.Assets;
import openfl.text.TextField;
import openfl.text.TextFormat;
import flixel.text.FlxText;

enum Alignment
{
	LEFT;
	CENTERED;
	RIGHT;
}

class Alphabet extends FlxSpriteGroup
{
	public var text(default, set):String;

	public var bold:Bool = false;
	public var letters:Array<AlphaCharacter> = [];

	public var isMenuItem:Bool = false;
	public var targetY:Int = 0;
	public var changeX:Bool = true;
	public var changeY:Bool = true;

	public var alignment(default, set):Alignment = LEFT;
	public var scaleX(default, set):Float = 1;
	public var scaleY(default, set):Float = 1;
	public var rows:Int = 0;
	
	// 用于外部识别ID
	//public var ID:Int = -1;

	public var distancePerItem:FlxPoint = new FlxPoint(20, 120);
	public var startPosition:FlxPoint = new FlxPoint(0, 0); //for the calculations
	
	// ============================================
	// 中文回退显示参数 (可随意修改调试)
	// ============================================
	// 回退文本的字体大小
	public static var fallbackFontSize:Int = 56;
	// 回退文本的Y轴偏移量 (正值向下移动)
	public static var fallbackYOffset:Float = 8;
	// 回退文本的X轴偏移量 (正值向右移动)
	public static var fallbackXOffset:Float = 0;
	// 回退文本是否加粗
	public static var fallbackBold:Bool = false;
	// 回退文本的描边大小
	public static var fallbackBorderSize:Int = 5;
	// ============================================
	
	// 回退文本字段（用于中文等不支持的字形）
	private var fallbackText:FlxText;
	private var useFallback:Bool = false;

	public function new(x:Float, y:Float, text:String = "", ?bold:Bool = true)
	{
		super(x, y);

		this.startPosition.x = x;
		this.startPosition.y = y;
		this.bold = bold;
		this.text = text;
	}
	
	/**
	 * 检查文本是否需要使用回退系统（包含非拉丁字符）
	 * 增强版：支持中文、日文、韩文、表情符号等
	 */
	private static function needsFallback(text:String):Bool
	{
		if (text == null || text.length == 0) return false;
		
		for (i in 0...text.length)
		{
			var c = text.charAt(i);
			if (c == '\n' || c == ' ' || c == '\t') continue;
			
			// 检查是否是拉丁字母（A-Z, a-z）
			var code = c.charCodeAt(0);
			var isLatin = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
			
			// 检查是否是扩展拉丁字符（带重音符号的字母）
			var isExtendedLatin = (code >= 192 && code <= 255);
			
			// 检查是否是数字 (0-9)
			var isNumber = (code >= 48 && code <= 57);
			
			// 检查是否是常见标点符号
			var isCommonPunctuation = (code >= 33 && code <= 47) || (code >= 58 && code <= 64) || 
									   (code >= 91 && code <= 96) || (code >= 123 && code <= 126);
			
			// 检查是否是字母表中的字符（通过AlphaCharacter判断）
			var isInAlphabet = false;
			if (AlphaCharacter.allLetters != null)
			{
				var lower = c.toLowerCase();
				isInAlphabet = AlphaCharacter.allLetters.exists(lower);
			}
			
			// 如果不是拉丁字母、扩展拉丁字母、数字、常见标点，也不在字母表中，需要回退
			if (!isLatin && !isExtendedLatin && !isNumber && !isCommonPunctuation && !isInAlphabet)
			{
				return true;
			}
		}
		return false;
	}

	public function setAlignmentFromString(align:String)
	{
		switch(align.toLowerCase().trim())
		{
			case 'right':
				alignment = RIGHT;
			case 'center' | 'centered':
				alignment = CENTERED;
			default:
				alignment = LEFT;
		}
	}

	private function set_alignment(align:Alignment)
	{
		alignment = align;
		if (useFallback)
			updateFallbackAlignment();
		else
			updateAlignment();
		return align;
	}

	private function updateAlignment()
	{
		if (useFallback) return;
		
		for (letter in letters)
		{
			var newOffset:Float = 0;
			switch(alignment)
			{
				case CENTERED:
					newOffset = letter.rowWidth / 2;
				case RIGHT:
					newOffset = letter.rowWidth;
				default:
					newOffset = 0;
			}
	
			letter.offset.x -= letter.alignOffset;
			letter.alignOffset = newOffset * scale.x;
			letter.offset.x += letter.alignOffset;
		}
	}
	
	private function updateFallbackAlignment()
	{
		if (fallbackText == null) return;
		
		switch(alignment)
		{
			case CENTERED:
				fallbackText.alignment = CENTER;
			case RIGHT:
				fallbackText.alignment = RIGHT;
			default:
				fallbackText.alignment = LEFT;
		}
	}

	private function set_text(newText:String)
	{
		newText = newText.replace('\\n', '\n');
		
		// 检查是否需要回退
		useFallback = needsFallback(newText);
		
		if (useFallback)
		{
			clearLetters();
			createFallbackText(newText);
		}
		else
		{
			clearFallbackText();
			clearLetters();
			createLetters(newText);
			updateAlignment();
		}
		
		this.text = newText;
		return newText;
	}
	
	private function createFallbackText(newText:String)
	{
		    if (fallbackText == null)
    {
        fallbackText = new FlxText(0, 0, 0, newText, fallbackFontSize);
        
        // 设置字体格式
        fallbackText.setFormat(Paths.font("vcr.ttf"), fallbackFontSize, FlxColor.WHITE, LEFT);
        
        // 设置描边
        fallbackText.borderStyle = OUTLINE;      // 启用描边
        fallbackText.borderColor = FlxColor.BLACK; // 黑色描边
        fallbackText.borderSize = fallbackBorderSize; // 使用可调参数
        fallbackText.borderQuality = 4;           // 描边质量
        
        fallbackText.antialiasing = ClientPrefs.data.antialiasing;
        add(fallbackText);
    }
    else
    {
        fallbackText.text = newText;
    }
		
		// 应用缩放
		fallbackText.scale.set(scaleX, scaleY);
		fallbackText.updateHitbox();
		
		// 应用位置（加上偏移量）
		var finalX:Float = x + fallbackXOffset;
		var finalY:Float = y + fallbackYOffset;
		fallbackText.setPosition(finalX, finalY);
		
		// 如果是菜单项，应用位置动画
		if (isMenuItem)
		{
			snapToPosition();
		}
	}
	
	private function clearFallbackText()
	{
		if (fallbackText != null)
		{
			remove(fallbackText);
			fallbackText.destroy();
			fallbackText = null;
		}
	}

	public function clearLetters()
	{
		var i:Int = letters.length;
		while (i > 0)
		{
			--i;
			var letter:AlphaCharacter = letters[i];
			if(letter != null)
			{
				letter.kill();
				letters.remove(letter);
				remove(letter);
			}
		}
		letters = [];
		rows = 0;
	}

	public function setScale(newX:Float, newY:Null<Float> = null)
	{
		var lastX:Float = scale.x;
		var lastY:Float = scale.y;
		if(newY == null) newY = newX;
		@:bypassAccessor
			scaleX = newX;
		@:bypassAccessor
			scaleY = newY;

		scale.x = newX;
		scale.y = newY;
		
		if (useFallback && fallbackText != null)
		{
			fallbackText.scale.set(newX, newY);
			fallbackText.updateHitbox();
		}
		else
		{
			softReloadLetters(newX / lastX, newY / lastY);
		}
	}

	private function set_scaleX(value:Float)
	{
		if (value == scaleX) return value;

		var ratio:Float = value / scale.x;
		scale.x = value;
		scaleX = value;
		
		if (useFallback && fallbackText != null)
		{
			fallbackText.scale.x = value;
			fallbackText.updateHitbox();
		}
		else
		{
			softReloadLetters(ratio, 1);
		}
		return value;
	}

	private function set_scaleY(value:Float)
	{
		if (value == scaleY) return value;

		var ratio:Float = value / scale.y;
		scale.y = value;
		scaleY = value;
		
		if (useFallback && fallbackText != null)
		{
			fallbackText.scale.y = value;
			fallbackText.updateHitbox();
		}
		else
		{
			softReloadLetters(1, ratio);
		}
		return value;
	}

	public function softReloadLetters(ratioX:Float = 1, ratioY:Null<Float> = null)
	{
		if (useFallback) return;
		if(ratioY == null) ratioY = ratioX;

		for (letter in letters)
		{
			if(letter != null)
			{
				letter.setupAlphaCharacter(
					(letter.x - x) * ratioX + x,
					(letter.y - y) * ratioY + y
				);
			}
		}
	}

	override function update(elapsed:Float)
	{
		if (isMenuItem)
		{
			var lerpVal:Float = Math.exp(-elapsed * 9.6);
			if(changeX)
				x = FlxMath.lerp((targetY * distancePerItem.x) + startPosition.x, x, lerpVal);
			if(changeY)
				y = FlxMath.lerp((targetY * 1.3 * distancePerItem.y) + startPosition.y, y, lerpVal);
			
			// 如果是回退模式，同步位置（加上偏移量）
			if (useFallback && fallbackText != null)
			{
				fallbackText.setPosition(x + fallbackXOffset, y + fallbackYOffset);
			}
		}
		super.update(elapsed);
	}
	
	override public function setPosition(X:Float = 0, Y:Float = 0):Void
	{
		super.setPosition(X, Y);
		if (useFallback && fallbackText != null)
		{
			fallbackText.setPosition(X + fallbackXOffset, Y + fallbackYOffset);
		}
	}

	public function snapToPosition()
	{
		if (isMenuItem)
		{
			if(changeX)
				x = (targetY * distancePerItem.x) + startPosition.x;
			if(changeY)
				y = (targetY * 1.3 * distancePerItem.y) + startPosition.y;
		}
		
		if (useFallback && fallbackText != null)
		{
			fallbackText.setPosition(x + fallbackXOffset, y + fallbackYOffset);
		}
	}
	
	override function destroy()
	{
		clearFallbackText();
		super.destroy();
	}

	private static var Y_PER_ROW:Float = 85;

	private function createLetters(newText:String)
	{
		var consecutiveSpaces:Int = 0;

		var xPos:Float = 0;
		var rowData:Array<Float> = [];
		rows = 0;
		for (i in 0...newText.length)
		{
			var character:String = newText.charAt(i);
			if(character != '\n')
			{
				var spaceChar:Bool = (character == " " || (bold && character == "_"));
				if (spaceChar) consecutiveSpaces++;

				var isAlphabet:Bool = AlphaCharacter.isTypeAlphabet(character.toLowerCase());
				if (AlphaCharacter.allLetters.exists(character.toLowerCase()) && (!bold || !spaceChar))
				{
					if (consecutiveSpaces > 0)
					{
						xPos += 28 * consecutiveSpaces * scaleX;
						rowData[rows] = xPos;
						if(!bold && xPos >= FlxG.width * 0.65)
						{
							xPos = 0;
							rows++;
						}
					}
					consecutiveSpaces = 0;

					var letter:AlphaCharacter = cast recycle(AlphaCharacter, true);
					letter.scale.x = scaleX;
					letter.scale.y = scaleY;
					letter.rowWidth = 0;

					letter.setupAlphaCharacter(xPos, rows * Y_PER_ROW * scale.y, character, bold);
					@:privateAccess letter.parent = this;

					letter.row = rows;
					var off:Float = 0;
					if(!bold) off = 2;
					xPos += letter.width + (letter.letterOffset[0] + off) * scale.x;
					rowData[rows] = xPos;

					add(letter);
					letters.push(letter);
				}
			}
			else
			{
				xPos = 0;
				rows++;
			}
		}

		for (letter in letters)
		{
			letter.rowWidth = rowData[letter.row] / scale.x;
		}

		if(letters.length > 0) rows++;
	}
	
	// 获取文本宽度（用于外部布局计算）
	public function getTextWidth():Float
	{
		if (useFallback && fallbackText != null)
			return fallbackText.width;
		
		if (letters.length > 0)
		{
			var maxRow:Float = 0;
			for (letter in letters)
			{
				if (letter.rowWidth > maxRow)
					maxRow = letter.rowWidth;
			}
			return maxRow;
		}
		return 0;
	}
	
	// 获取文本高度
	public function getTextHeight():Float
	{
		if (useFallback && fallbackText != null)
			return fallbackText.height;
		
		return rows * Y_PER_ROW * scale.y;
	}
}


///////////////////////////////////////////
// ALPHABET LETTERS, SYMBOLS AND NUMBERS //
///////////////////////////////////////////

/*enum LetterType
{
	ALPHABET;
	NUMBER_OR_SYMBOL;
}*/

typedef Letter = {
	?anim:Null<String>,
	?offsets:Array<Float>,
	?offsetsBold:Array<Float>
}

class AlphaCharacter extends FlxSprite
{
	//public static var alphabet:String = "abcdefghijklmnopqrstuvwxyz";
	//public static var numbers:String = "1234567890";
	//public static var symbols:String = "|~#$%()*+-:;<=>@[]^_.,'!?";

	public var image(default, set):String;

	public static var allLetters:Map<String, Null<Letter>>;

	public static function loadAlphabetData(request:String = 'alphabet')
	{
		var path:String = Paths.getPath('images/$request.json');
		#if MODS_ALLOWED
		if(!FileSystem.exists(path))
		#else
		if(!Assets.exists(path, TEXT))
		#end
			path = Paths.getPath('images/alphabet.json');

		allLetters = new Map<String, Null<Letter>>();
		try
		{
			#if MODS_ALLOWED
			var data:Dynamic = Json.parse(File.getContent(path));
			#else
			var data:Dynamic = Json.parse(Assets.getText(path));
			#end

			if(data.allowed != null && data.allowed.length > 0)
			{
				for (i in 0...data.allowed.length)
				{
					var char:String = data.allowed.charAt(i);
					if(char == ' ') continue;
					
					allLetters.set(char.toLowerCase(), null); //Allows character to be used in Alphabet
				}
			}

			if(data.characters != null)
			{
				for (char in Reflect.fields(data.characters))
				{
					var letterData = Reflect.field(data.characters, char);
					var character:String = char.toLowerCase().substr(0, 1);
					if((letterData.animation != null || letterData.normal != null || letterData.bold != null) && allLetters.exists(character))
						allLetters.set(character, {anim: letterData.animation, offsets: letterData.normal, offsetsBold: letterData.bold});
				}
			}
			trace('Reloaded letters successfully ($path)!');
		}
		catch(e:Dynamic)
		{
			FlxG.log.error('Error on loading alphabet data: $e');
			trace('Error on loading alphabet data: $e');
		}

		if(!allLetters.exists('?'))
			allLetters.set('?', {anim: 'question'});
	}

	var parent:Alphabet;
	public var alignOffset:Float = 0; //Don't change this
	public var letterOffset:Array<Float> = [0, 0];

	public var row:Int = 0;
	public var rowWidth:Float = 0;
	public var character:String = '?';
	public function new()
	{
		super(x, y);
		image = 'alphabet';
		antialiasing = ClientPrefs.data.antialiasing;
	}
	
	public var curLetter:Letter = null;
	public function setupAlphaCharacter(x:Float, y:Float, ?character:String = null, ?bold:Null<Bool> = null)
	{
		this.x = x;
		this.y = y;

		if(parent != null)
		{
			if(bold == null)
				bold = parent.bold;
			this.scale.x = parent.scaleX;
			this.scale.y = parent.scaleY;
		}
		
		if(character != null)
		{
			this.character = character;
			curLetter = null;
			var lowercase:String = this.character.toLowerCase();
			if(allLetters.exists(lowercase)) curLetter = allLetters.get(lowercase);
			else curLetter = allLetters.get('?');

			var postfix:String = '';
			if(!bold)
			{
				if(isTypeAlphabet(lowercase))
				{
					if(lowercase != this.character)
						postfix = ' uppercase';
					else
						postfix = ' lowercase';
				}
				else postfix = ' normal';
			}
			else postfix = ' bold';

			var alphaAnim:String = lowercase;
			if(curLetter != null && curLetter.anim != null) alphaAnim = curLetter.anim;

			var anim:String = alphaAnim + postfix;
			animation.addByPrefix(anim, anim, 24);
			animation.play(anim, true);
			if(animation.curAnim == null)
			{
				if(postfix != ' bold') postfix = ' normal';
				anim = 'question' + postfix;
				animation.addByPrefix(anim, anim, 24);
				animation.play(anim, true);
			}
		}
		updateHitbox();
	}

	public static function isTypeAlphabet(c:String) // thanks kade
	{
		var ascii = StringTools.fastCodeAt(c, 0);
		return (ascii >= 65 && ascii <= 90)
			|| (ascii >= 97 && ascii <= 122)
			|| (ascii >= 192 && ascii <= 214)
			|| (ascii >= 216 && ascii <= 246)
			|| (ascii >= 248 && ascii <= 255);
	}

	private function set_image(name:String)
	{
		if(frames == null) //first setup
		{
			image = name;
			frames = Paths.getSparrowAtlas(name);
			return name;
		}

		var lastAnim:String = null;
		if (animation != null)
		{
			lastAnim = animation.name;
		}
		image = name;
		frames = Paths.getSparrowAtlas(name);
		this.scale.x = parent.scaleX;
		this.scale.y = parent.scaleY;
		alignOffset = 0;
		
		if (lastAnim != null)
		{
			animation.addByPrefix(lastAnim, lastAnim, 24);
			animation.play(lastAnim, true);
			
			updateHitbox();
		}
		return name;
	}

	public function updateLetterOffset()
	{
		if (animation.curAnim == null)
		{
			trace(character);
			return;
		}

		var add:Float = 110;
		if(animation.curAnim.name.endsWith('bold'))
		{
			if(curLetter != null && curLetter.offsetsBold != null)
			{
				letterOffset[0] = curLetter.offsetsBold[0];
				letterOffset[1] = curLetter.offsetsBold[1];
			}
			add = 70;
		}
		else
		{
			if(curLetter != null && curLetter.offsets != null)
			{
				letterOffset[0] = curLetter.offsets[0];
				letterOffset[1] = curLetter.offsets[1];
			}
		}
		add *= scale.y;
		offset.x += letterOffset[0] * scale.x;
		offset.y += letterOffset[1] * scale.y - (add - height);
	}

	override public function updateHitbox()
	{
		super.updateHitbox();
		updateLetterOffset();
	}
}