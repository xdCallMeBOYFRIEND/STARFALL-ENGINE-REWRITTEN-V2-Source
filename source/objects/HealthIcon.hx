package objects;

class HealthIcon extends FlxSprite
{
	public static final DEFAULT_LERP_RATE:Float = 9;
	public var WINNING_RANGE:Float = 0.8;
	public var LOSING_RANGE:Float = 0.2;
	
	public var sprTracker:FlxSprite;
	public var isPlayer:Bool = false;
	public var hasWinning:Bool = true;
	public var char:String = '';

	public function new(char:String = 'face', isPlayer:Bool = false, ?allowGPU:Bool = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 10, sprTracker.y - 30);
	}

	public var updateFrames:Bool = true;

	private var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String, ?allowGPU:Bool = true) {
		if(this.char != char) {
			var curAnimation:Int = 0;
			var name:String = 'icons/' + char;
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-' + char; //Older versions of psych engine's support
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face'; //Prevents crash from missing icon
			
			var hasWin:Bool = false;
			var singleIcon:Bool = false;
			var graphic = Paths.image(name, allowGPU);
			if (graphic.width == 450) hasWin = true;
			else if (graphic.width == 150) singleIcon = true;
			var iSize:Float = Math.round(graphic.width / graphic.height);
			loadGraphic(graphic, true, Math.floor(graphic.width / iSize), Math.floor(graphic.height));
			iconOffsets[0] = (width - 150) / iSize;
			iconOffsets[1] = (height - 150) / iSize;
			updateHitbox();

			animation.add(char, [for(i in 0...frames.frames.length) i], 0, false, isPlayer);
			animation.play(char);
			this.animation.curAnim.curFrame = curAnimation;
			this.char = char;
			this.hasWinning = hasWin;

			if(char.endsWith('-pixel')) //To-Do Note: Figure out how to rescale the pixel icons at their base resolution while accounting for singular/winning icons without potentially breaking the system for it
				antialiasing = false;
			else
				antialiasing = ClientPrefs.data.antialiasing;
		}
	}

	public var autoAdjustOffset:Bool = false;
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

	public inline function updateIconAnim(health:Float):Void
	{
		if (!updateFrames) return;
		
		animation.frameIndex = health < LOSING_RANGE ? 1 : health > WINNING_RANGE && (hasWinning) ? 2 : 0;
	}
}