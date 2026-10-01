package backend;



class Rating
{
	public var name:String = '';
	public var image:String = '';
	public var hitWindow:Null<Float> = 0.0; //ms
	public var ratingMod:Float = 1;
	public var score:Int = 350;
	public var noteSplash:Bool = true;
	public var hits:Int = 0;

	public function new(name:String)
	{
		this.name = name;
		this.image = name;
		this.hitWindow = 0;

		var window:String = name + 'Window';
		try
		{
			this.hitWindow = Reflect.field(ClientPrefs.data, window);
		}
		catch(e) FlxG.log.error(e);
	}

	public static function loadDefault():Array<Rating>
	{
		var ratingsData:Array<Rating> = [];
		
		var rating:Rating = new Rating('marvelous');
		rating.ratingMod = 1;
		rating.score = 350; // 比 sick 更高
		rating.noteSplash = true;
		// 关闭 Marvelous 开关时窗口置 -1：judgeNote 里 |diff| <= -1 恒不成立，这些命中落到 Sick
		if (!ClientPrefs.data.marvelousEnabled) rating.hitWindow = -1;
		ratingsData.push(rating);
		
		var rating:Rating = new Rating('sick');
		rating.ratingMod = 1;
		rating.score = 350;
		rating.noteSplash = true;
		ratingsData.push(rating);

		var rating:Rating = new Rating('good');
		rating.ratingMod = 0.67;
		rating.score = 200;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('bad');
		rating.ratingMod = 0.34;
		rating.score = 100;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('shit');
		rating.ratingMod = 0;
		rating.score = 50;
		rating.noteSplash = false;
		ratingsData.push(rating);
		
		return ratingsData;
	}
}