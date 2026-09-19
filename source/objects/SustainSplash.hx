package objects;

class SustainSplash extends FlxSprite
{
	public static var startCrochet:Float;
	public static var frameRate:Int;

	public var strumNote:StrumNote;
	public var skin:String = 'holdSplash-Vanilla';

	var timer:FlxTimer;

	public function new():Void
	{
		super();

		x = -50000;

		if (PlayState.SONG != null
			&& PlayState.SONG.holdSplashSkin != null
			&& PlayState.SONG.holdSplashSkin.length > 0
			&& Paths.getSparrowAtlas('holdSplashes/' + PlayState.SONG.holdSplashSkin) != null)
			skin = PlayState.SONG.holdSplashSkin;
		frames = Paths.getSparrowAtlas('holdSplashes/$skin');

		animation.addByPrefix('start', 'start', 24, true);
		animation.addByPrefix('hold', 'hold', 24, true);
		animation.addByPrefix('end', 'end', 24, false);
	}

	override function update(elapsed)
	{
		super.update(elapsed);

		if (strumNote != null)
		{
			repositionSplash();
			visible = strumNote.visible;
			alpha = ClientPrefs.data.holdSplashAlpha - (1 - strumNote.alpha);

			if (animation.curAnim.name == "hold" && strumNote.animation.curAnim.name == "static")
			{
				x = -50000;
				kill();
			}
		}
	}

	function repositionSplash()
	{
		setPosition(strumNote.x, strumNote.y);
		offset.set(PlayState.isPixelStage ? 112.5 : 106.25, 100);
	}

	public function setupSusSplash(strum:StrumNote, daNote:Note, ?playbackRate:Float = 1):Void
	{
		final lengthToGet:Int = !daNote.isSustainNote ? daNote.tail.length : daNote.parent.tail.length;
		final timeToGet:Float = !daNote.isSustainNote ? daNote.strumTime : daNote.parent.strumTime;
		final timeThingy:Float = (startCrochet * lengthToGet + (timeToGet - Conductor.songPosition + ClientPrefs.data.ratingOffset)) / playbackRate * .001;

		var tailEnd:Note = !daNote.isSustainNote ? daNote.tail[daNote.tail.length - 1] : daNote.parent.tail[daNote.parent.tail.length - 1];

		animation.play('start');
		animation.curAnim.looped = false;

		animation.finishCallback = (animationName:String) ->
		{
			if (animationName == "start")
			{
				animation.play('hold', true, false, 0);
				animation.curAnim.looped = true;
			}
		}

		clipRect = new flixel.math.FlxRect(0, !PlayState.isPixelStage ? 0 : -210, frameWidth, frameHeight);

		if (daNote.shader != null)
		{
			shader = new objects.NoteSplash.PixelSplashShaderRef().shader;
			shader.data.r.value = daNote.shader.data.r.value;
			shader.data.g.value = daNote.shader.data.g.value;
			shader.data.b.value = daNote.shader.data.b.value;
			shader.data.mult.value = daNote.shader.data.mult.value;
		}

		strumNote = strum;
		alpha = ClientPrefs.data.holdSplashAlpha - (1 - strumNote.alpha);
		repositionSplash();

		if (timer != null)
			timer.cancel();

		if (!daNote.hitByOpponent && ClientPrefs.data.holdSplashAlpha != 0)
			timer = new FlxTimer().start(timeThingy, (idk:FlxTimer) ->
			{
				if (!(daNote.isSustainNote ? daNote.parent.noteSplashData.disabled : daNote.noteSplashData.disabled) && animation != null)
				{
					alpha = ClientPrefs.data.holdSplashAlpha - (1 - strumNote.alpha);
					animation.play('end', true, false, 0);
					animation.curAnim.looped = false;
					animation.curAnim.frameRate = 24;
					clipRect = null;
					animation.finishCallback = (idkEither:Dynamic) -> {
						kill();
					}
					return;
				}
				kill();
			});
	}
}
