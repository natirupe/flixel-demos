package;

import flixel.effects.particles.FlxEmitter;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxTypedGroup;
import flixel.util.FlxAngle;
import flixel.util.FlxMath;
import flixel.util.FlxPoint;
import flixel.util.FlxSpriteUtil;

class Enemy extends FlxSprite
{
	/**
	 * The player object
	 */
	private var _player:Player;
	/**
	 * A group of enemy bullet objects (Enemies shoot these out)
	 */ 
	private var _bullets:FlxTypedGroup<EnemyBullet>;
	/**
	 * A group of bits and pieces that explode when the Enemy dies.
	 */
	private var _gibs:FlxEmitter;
	/**
	 * We use this number to figure out how fast the ship is flying
	 */
	private var _thrust:Float;
	/**
	 * A special effect - little poofs shoot out the back of the ship
	 */
	private var _jets:FlxEmitter;
	
	// These are "timers" - numbers that count down until we want something interesting to happen.
	
	/**
	 * Helps us decide when to fly and when to stop flying.
	 */
	private var _timer:Float;
	/**
	 * Helps us decide when to shoot.
	 */
	private var _shotClock:Float;	
	
	/**
	 * This object isn't strictly necessary, and is only used with getMidpoint().
	 * By passing this object, we can avoid a potentially costly allocation of
	 * a new FlxPoint() object by the getMidpoint() function.
	 */
	private var _playerMidpoint:FlxPoint;
	
	/**
	 * This is the constructor for the enemy class. Because we are recycling 
	 * enemies, we don't want our constructor to have any required parameters.
	 */
	public function new()
	{
		super();
		
		#if flash
		loadRotatedGraphic(Reg.BOT, 64, 0, false, false);
		#else
		loadGraphic(Reg.BOT);
		#end

		// We want the enemy's "hit box" or actual size to be
		// smaller than the enemy graphic itself, just by a few pixels.
		width = 12;
		height = 12;
		centerOffsets();
		
		// Here we are setting up the jet particles
		// that shoot out the back of the ship.
		_jets = new FlxEmitter();
		_jets.setRotation();
		_jets.makeParticles(Reg.JET, 15, 0, false, 0);
		
		// These parameters help control the ship's
		// speed and direction during the update() loop.
		maxAngular = 120;
		angularDrag = 400;
		drag.x = 35;
		_thrust = 0;
		_playerMidpoint = new FlxPoint();
	}
	/**
	 * Each time an Enemy is recycled (in this game, by the Spawner object)
	 * we call init() on it afterward.  That allows us to set critical parameters
	 * like references to the player object and the ship's new position.
	 */
	public function init(xPos:Int, yPos:Int, Bullets:FlxTypedGroup<EnemyBullet>, Gibs:FlxEmitter, ThePlayer:Player):Void
	{
		_player = ThePlayer;
		_bullets = Bullets;
		_gibs = Gibs;
		
		reset(xPos - width / 2, yPos - height / 2);
		angle = angleTowardPlayer();
		// Enemies take 2 shots to kill
		health = 2;	
		_timer = 0;
		_shotClock = 0;
	}
	
	/**
	 * Called by flixel to help clean up memory.
	 */
	override public function destroy():Void
	{
		super.destroy();
		
		_player = null;
		_bullets = null;
		_gibs = null;
		
		_jets.destroy();
		_jets = null;
		
		_playerMidpoint = null;
	}
	
	/**
	 * This is the main flixel update function or loop function.
	 * Most of the enemy's logic or behavior is in this function here.
	 */
	override public function update():Void
	{
		// Then, rotate toward that angle.
		// We could rotate instantly toward the player by simply calling:
		// angle = angleTowardPlayer();
		// However, we want some less predictable, more wobbly behavior.
		var da:Float = angleTowardPlayer();
		
		if (da < angle)
		{
			angularAcceleration = -angularDrag;
		}
		else if (da > angle)
		{
			angularAcceleration = angularDrag;
		}
		else
		{
			angularAcceleration = 0;
		}

		// Figure out if we want the jets on or not.
		_timer += FlxG.elapsed;
		
		if (_timer > 8)
		{
			_timer = 0;
		}
		var jetsOn:Bool = _timer < 6;
		
		// Set the bot's movement speed and direction
		// based on angle and whether the jets are on.
		_thrust = FlxMath.computeVelocity(_thrust, (jetsOn ? 90 : 0), drag.x, 60);
		FlxAngle.rotatePoint(0, _thrust, 0, 0, angle, velocity);

		// Shooting - three shots every few seconds
		if (onScreen())
		{
			var shoot:Bool = false;
			var os:Float = _shotClock;
			_shotClock += FlxG.elapsed;
			
			if ((os < 4.0) && (_shotClock >= 4.0))
			{
				_shotClock = 0;
				shoot = true;
			}
			else if ((os < 3.5) && (_shotClock >= 3.5))
			{
				shoot = true;
			}
			else if ((os < 3.0) && (_shotClock >= 3.0))
			{
				shoot = true;
			}

			// If we rolled over one of those time thresholds,
			// shoot a bullet out along the angle we're currently facing.
			if (shoot)
			{
				// First, recycle a bullet from the bullet pile.
				// If there are none, recycle will automatically create one for us.
				var b:EnemyBullet = _bullets.recycle(EnemyBullet);
				// Then, shoot it from our midpoint out along our angle.
				b.shoot(getMidpoint(_point), angle);
			}
		}
		
		// Then call FlxSprite's update() function, to automate
		// our motion and animation and stuff.
		super.update();
		
		// Finally, update the jet particles shooting out the back of the ship.
		if (jetsOn)
		{
			if (!_jets.on)
			{
				// If they're supposed to be on and they're not,
				// turn em on and play a little sound.
				_jets.start(false, 0.5, 0.01);
				
				if (onScreen())
				{
					FlxG.sound.play("Jet");
				}
			}
			// Then, position the jets at the center of the Enemy,
			// and point the jets the opposite way from where we're moving.
			_jets.at(this);
			_jets.setXSpeed(-velocity.x-30,-velocity.x+30);
			_jets.setYSpeed(-velocity.y-30,-velocity.y+30);
		}
		// If jets are supposed to be off, just turn em off.
		else	
		{
			_jets.on = false;
		}
		
		// Finally, update the jet emitter and all its member sprites.
		_jets.update();
	}
	
	/**
	 * Even though we updated the jets after we updated the Enemy,
	 * we want to draw the jets below the Enemy, so we call _jets.draw() first.
	 */
	override public function draw():Void
	{
		_jets.draw();
		super.draw();
	}
	
	/**
	 * This function is called when player bullets hit the Enemy.
	 * The enemy is told to flicker, points are awarded to the player,
	 * and damage is dealt to the Enemy.
	 * 
	 * @param	Damage	The amount of damage to take
	 */
	override public function hurt(Damage:Float):Void
	{
		FlxG.sound.play("Hit");
		FlxSpriteUtil.flicker(this, 0.2, 0.02, true);
		Reg.score += 10;
		
		super.hurt(Damage);
	}
	
	/**
	 * Called to kill the enemy.  A cool sound is played, the jets 
	 * are turned off, bits are exploded, and points are rewarded.
	 */
	override public function kill():Void
	{
		if (!alive)
		{
			return;
		}
		
		FlxG.sound.play("Asplode");
		
		super.kill();
		
		FlxSpriteUtil.flicker(this, 0, 0.02, true);
		_jets.kill();
		_gibs.at(this);
		_gibs.start(true, 3, 0, 20);
		Reg.score += 200;
	}
	
	/**
	 * A helper function that returns the angle between
	 * the Enemy's midpoint and the player's midpoint.
	 */
	private function angleTowardPlayer():Float
	{
		return FlxAngle.getAngle(getMidpoint(_point), _player.getMidpoint(_playerMidpoint));
	}
}