package objects;

#if funkin.vis
import funkin.vis.dsp.SpectralAnalyzer;
import funkin.vis.dsp.SpectralAnalyzer.Bar;
#end

class AudioDisplay extends FlxSpriteGroup
{
	#if funkin.vis
	var analyzer:SpectralAnalyzer;
	#end

	public var snd:FlxSound;
	
	public var inRelax:Bool = false;

	public var gain:Float = 1.5;

	var _height:Int;
	var line:Int;

	public var symmetry:Bool = false;

	public function new(snd:FlxSound = null, X:Float = 0, Y:Float = 0, Width:Int, Height:Int, line:Int, gap:Int, Color:FlxColor, symmetry:Bool = false)
	{
		super(X, Y);

		this.snd = snd;
		this.line = line;
		this.symmetry = symmetry;

		// 创建条形图
		for (i in 0...line)
		{
			var newLine = new FlxSprite().makeGraphic(Std.int(Width / line - gap), 1, Color);
			newLine.x = (Width / line) * i;
			add(newLine);
		}

		_height = Height;
		
		@:privateAccess
		if (snd != null)
		{
			#if funkin.vis
			var quality:Int = ClientPrefs.data.relaxAudioDisplayQuality;
			if (quality < 1) quality = 1;
			analyzer = new SpectralAnalyzer(snd._channel.__audioSource, line, 1, 5);
			analyzer.fftN = 256 * quality;
			#end
		}
	}

	public var stopUpdate:Bool = false;
	
	public var amplitude:Float = 0;

	var saveTime:Float = 0;
	#if funkin.vis
	var getValues:Array<Bar>;
	#end

	override function update(elapsed:Float)
	{
		if (stopUpdate)
			return;

		if (saveTime < ClientPrefs.data.audioDisplayUpdate)
		{
			saveTime += (elapsed * 1000);
			updateLine(elapsed);
			return;
		}
		else
		{
			saveTime = 0;
		}

		#if funkin.vis
		if (analyzer != null)
			getValues = analyzer.getLevels();
		else
			return;

		updateLine(elapsed);

		var Helpamplitude:Float = 0;

		if (getValues != null)
		{
			// ★★★ 修复：显式转换为 Int ★★★
			var count:Int = Std.int(Math.min(5, getValues.length));
			for (i in 0...count)
			{
				Helpamplitude += getValues[i].value;
			}
			amplitude = Helpamplitude / 5;
		}
		#end

		super.update(elapsed);
	}

	// 重写：重新创建 analyzer
	public function changeAnalyzer(snd:FlxSound)
	{
		this.snd = snd;
		@:privateAccess
		if (snd != null)
		{
			#if funkin.vis
			var quality:Int = ClientPrefs.data.relaxAudioDisplayQuality;
			if (quality < 1) quality = 1;
			analyzer = new SpectralAnalyzer(snd._channel.__audioSource, line, 1, 5);
			analyzer.fftN = 256 * quality;
			stopUpdate = false;
			#end
		}
		else
		{
			#if funkin.vis
			analyzer = null;
			#end
			stopUpdate = true;
		}
	}

	function addAnalyzer(snd:FlxSound)
	{
		#if funkin.vis
		@:privateAccess
		if (snd != null && analyzer == null)
		{
			var quality:Int = ClientPrefs.data.relaxAudioDisplayQuality;
			if (quality < 1) quality = 1;
			analyzer = new SpectralAnalyzer(snd._channel.__audioSource, line, 1, 5);
			analyzer.fftN = 256 * quality;
		}
		#end
	}

	var animFrame:Int = 0;

	function updateLine(elapsed:Float)
	{
		#if funkin.vis
		if (getValues == null || members == null)
			return;

		for (i in 0...members.length)
		{
			if (i >= members.length / 2 && symmetry)
			{
				animFrame = Math.round(getValues[members.length - 1 - i].value * _height * gain);
			}
			else
			{
				if (i < getValues.length)
					animFrame = Math.round(getValues[i].value * _height * gain);
				else
					animFrame = 0;
			}

			animFrame = Math.round(animFrame * FlxG.sound.volume);

			members[i].scale.y = FlxMath.lerp(animFrame, members[i].scale.y, Math.exp(-elapsed * 16));
			if (members[i].scale.y < _height / 40)
				members[i].scale.y = _height / 40;

			members[i].y = this.y - members[i].scale.y / 2;
		}
		#end
	}

	public function clearUpdate()
	{
		for (i in 0...members.length)
		{
			members[i].scale.y = _height / 40;
			members[i].y = this.y - members[i].scale.y / 2;
		}
	}

	override public function destroy():Void
	{
		#if funkin.vis
		if (analyzer != null)
		{
			analyzer = null;
		}
		#end
		super.destroy();
	}
}