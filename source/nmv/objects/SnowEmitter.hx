package nmv.objects;

import flixel.effects.particles.FlxParticle;
import flixel.FlxG;

import backend.ClientPrefs;
import backend.Paths;

/**
 * NMV funkin.objects.SnowEmitter 原样移植。
 */
class SnowEmitter extends CustomEmitter
{
	public var autoKill:Bool = true;

	public function new(x:Float = 0, y:Float = 0, width:Float = 0)
	{
		super(x, y);
		this.width = width;
		particleClass = Snow;
		launchAngle.set(100, 160);
		angularVelocity.set(-80, 100);
		lifespan.set(10); // fuck it

		speed.set(500, 700);

		alpha.set(1, null, 0, 1);
	}
}

class Snow extends FlxParticle
{
	public function new()
	{
		super();
		antialiasing = ClientPrefs.data.antialiasing;
		frames = Paths.getSparrowAtlas('stages/polus/snow_particles');
		animation.addByPrefix('snow', 'snow', 0, false);
		animation.frameIndex = FlxG.random.int(0, 7);
	}

	override function reset(X:Float, Y:Float)
	{
		super.reset(X, Y);
		animation.frameIndex = FlxG.random.int(0, 7);
	}
}
