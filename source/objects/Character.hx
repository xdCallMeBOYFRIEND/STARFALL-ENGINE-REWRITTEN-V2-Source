package objects;

import backend.animation.PsychAnimationController;

import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;

import openfl.utils.AssetType;
import openfl.utils.Assets;
import haxe.Json;

import backend.Song;
import states.stages.objects.TankmenBG;

typedef CharacterFile = {
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
	var vocals_file:String;
	@:optional var _editor_isPlayer:Null<Bool>;
	@:optional var vSus:Null<Bool>;
	@:optional var freezeSus:Null<Bool>;
	@:optional var doubleGhosts:Null<Bool>;
}

typedef AnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
}

class Character extends FlxSprite
{
	/**
	 * In case a character is missing, it will use this on its place
	**/
	public static final DEFAULT_CHARACTER:String = 'bf';

	public var lastHitTime:Float = -1000;
	
	public var animOffsets:Map<String, Array<Float>>;
	public var debugMode:Bool = false;
	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var isCustom:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4; //Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; //Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public var vSliceSustains:Bool = false;

	public var frozenSustains:Bool = false;

	public var ghostDisplacement:Float = 40;
	public var ghostsEnabled:Bool = true;
	public var doubleGhosts:Array<FlxSprite> = [];
	public var ghostAlpha = 0.6;
	public var ghostTweenGrp:Array<FlxTween> = [];

	public var missingCharacter:Bool = false;
	public var missingText:FlxText;
	public var hasMissAnimations:Bool = false;
	public var vocalsFile:String = '';

	//Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var daGhosts:Bool = true;
	public var originalFlipX:Bool = false;
	public var editorIsPlayer:Null<Bool> = null;

	public var correctFlippedOffsets:Bool = true;
	public var scalableOffsets:Bool = true;

	public var baseFlipX:Bool = false;
	public var baseFlipY:Bool = false;

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false)
	{
		super(x, y);

		animation = new PsychAnimationController(this);

		animOffsets = new Map<String, Array<Float>>();
		this.isPlayer = isPlayer;
		changeCharacter(character);

		genGhosts();
		
		switch(curCharacter)
		{
			case 'pico-speaker':
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");
			case 'pico-blazin', 'darnell-blazin':
				skipDance = true;
		}
	}

	function genGhosts()
	{
		for (i in 0...4)
		{
			final ghost = new FlxSprite();
			ghost.visible = false;
			ghost.antialiasing = antialiasing;
			ghost.alpha = ghostAlpha;
			doubleGhosts.push(ghost);
		}
	}

	public function changeCharacter(character:String)
	{
		animationsArray = [];
		animOffsets = [];
		curCharacter = character;
		var characterPath:String = 'characters/$character.json';

		var path:String = Paths.getPath(characterPath, TEXT);
		#if MODS_ALLOWED
		if (!FileSystem.exists(path))
		#else
		if (!Assets.exists(path))
		#end
		{
			path = Paths.getSharedPath('characters/' + DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
			missingCharacter = true;
			missingText = new FlxText(0, 0, 300, 'ERROR:\n$character.json', 16);
			missingText.alignment = CENTER;
		}

		try
		{
			#if MODS_ALLOWED
			loadCharacterFile(Json.parse(File.getContent(path)));
			#else
			loadCharacterFile(Json.parse(Assets.getText(path)));
			#end
		}
		catch(e:Dynamic)
		{
			trace('Error loading character file of "$character": $e');
		}

		skipDance = false;
		hasMissAnimations = hasAnimation('singLEFTmiss') || hasAnimation('singDOWNmiss') || hasAnimation('singUPmiss') || hasAnimation('singRIGHTmiss');
		recalculateDanceIdle();
		dance();
		
	}

	public function loadCharacterFile(json:Dynamic)
	{
		isAnimateAtlas = false;

		var path:String = json.assetPath == null? json.image : StringTools.replace(json.assetPath, 'shared:', '');
		#if flxanimate
		var animToFind:String = Paths.getPath('images/' + path + '/Animation.json', TEXT);
		if (#if MODS_ALLOWED FileSystem.exists(animToFind) || #end Assets.exists(animToFind))
			isAnimateAtlas = true;
		#end

		scale.set(1, 1);
		updateHitbox();
		isCustom = true;

		if(!isAnimateAtlas)
		{
			if(json.assetPath != null)
			path = convertMultiSparrow(json.animations, path);
			frames = Paths.getMultiAtlas(path.split(','));
		}
		#if flxanimate
		else
		{
			atlas = new FlxAnimate();
			atlas.showPivot = false;
			try
			{
				Paths.loadAnimateAtlas(atlas, path);
			}
			catch(e:haxe.Exception)
			{
				FlxG.log.warn('Could not load atlas ${path}: $e');
				trace(e.stack);
			}
		}
		#end

		if(json.assetPath == null) {
			imageFile = json.image;
			jsonScale = jsonScale = json.scale > 0 ? json.scale : 1;
			if(json.scale != 1) {
				scale.set(jsonScale, jsonScale);
				updateHitbox();
			}

			// positioning
			positionArray = json.position;
			cameraPosition = json.camera_position;

			// data
			healthIcon = json.healthicon;
			singDuration = json.sing_duration;
			flipX = (json.flip_x != isPlayer);
			
			healthColorArray = (json.healthbar_colors != null && json.healthbar_colors.length > 2) ? json.healthbar_colors : [161, 161, 161];
			vocalsFile = json.vocals_file != null ? json.vocals_file : '';
			originalFlipX = (json.flip_x == true);
			editorIsPlayer = json._editor_isPlayer;

			if (json.vSus != null)
				vSliceSustains = false;

			if (json.freezeSus != null)
				frozenSustains = false;

			// Double ghosts toggle
			daGhosts = (json.doubleGhosts == true);
			ghostsEnabled = ClientPrefs.data.ghostsAllowed ? !daGhosts : false;

			// antialiasing
			noAntialiasing = (json.no_antialiasing == true);
			antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

			//Auto-correction for offsets
			if (json.correctFlippedOffsets != null)
				correctFlippedOffsets = (json.correctFlippedOffsets == true);
			if (json.scalableOffsets != null)
				scalableOffsets = (json.scalableOffsets == true);

			// animations
			animationsArray = json.animations;
		} else{
			imageFile = StringTools.replace(json.assetPath, 'shared:', '');
			imageFile = convertMultiSparrow(json.animations, imageFile);

			if(json.scale != null) {
				jsonScale = jsonScale = json.scale > 0 ? json.scale : 1;
				if(json.scale != 1) {
					scale.set(jsonScale, jsonScale);
					updateHitbox();
				}
			}

		if(json.singTime != null)
				singDuration = json.singTime;
			else
				singDuration = 8.0;

			if(json.flipX != null)
				flipX = (json.flipX != isPlayer);

			//place holder icon to grab the color.
			var icon:objects.HealthIcon = new objects.HealthIcon(healthIcon, false, false);
			var coolColor:FlxColor = FlxColor.fromInt(CoolUtil.dominantColor(icon));
			icon.destroy();
			icon = null;
			healthColorArray[0] = coolColor.red;
			healthColorArray[1] = coolColor.green;
			healthColorArray[2] = coolColor.blue;

			vocalsFile = '';
			originalFlipX = (json.flipX == true);

			// antialiasing
			noAntialiasing = json.isPixel != null ? json.isPixel : false;
			antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

			// animations
			// animations
			var base_animationsArray:Array<Dynamic> = []; 
			base_animationsArray = json.animations;
			if(base_animationsArray != null && base_animationsArray.length > 0) {
				for (anim in base_animationsArray) {
					var animFormat:AnimArray = {
						anim: anim.name,
						name: anim.prefix,
						fps: anim.fps != null ? anim.fps : 24,
						loop: anim.loop != null ? !!anim.loop : false,
						indices: anim.indices != null ? anim.indices : [],
						offsets: anim.offsets != null ? anim.offsets : [0,0]
					};
					animationsArray.push(animFormat);
				}
			}
		}

		if(animationsArray != null && animationsArray.length > 0) {
			for (anim in animationsArray) {
				var animAnim:String = '' + anim.anim;
				var animName:String = '' + anim.name;
				var animFps:Int = anim.fps;
				var animLoop:Bool = !!anim.loop; //Bruh
				var animIndices:Array<Int> = anim.indices;

				if(!isAnimateAtlas)
				{
					if(animIndices != null && animIndices.length > 0)
						animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
					else
						animation.addByPrefix(animAnim, animName, animFps, animLoop);
				}
				#if flxanimate
				else
				{
					var atlasFps:Null<Float> = (animFps > 0) ? cast animFps : null;
					if(animIndices != null && animIndices.length > 0)
						atlas.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
					else
						atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
				}
				#end

				if(anim.offsets != null && anim.offsets.length > 1) addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
				else addOffset(anim.anim, 0, 0);
			}
		}
		#if flxanimate
		if(isAnimateAtlas) copyAtlasValues();
		#end
		//trace('Loaded file to character ' + curCharacter);
	}
	

	function convertMultiSparrow(animations:Null<Array<Dynamic>>, str:String):String {
		if(animations != null && animations.length > 0) {
			for (anim in animations) {
				if(anim.assetPath != null && anim.assetPath != '')
					str += ',${StringTools.replace(anim.assetPath, 'shared:', '')}';
			}
		}
		return str;
	}

	override function update(elapsed:Float)
	{
		if(isAnimateAtlas) atlas.update(elapsed);

		if(debugMode || (!isAnimateAtlas && animation.curAnim == null) || (isAnimateAtlas && (atlas.anim.curInstance == null || atlas.anim.curSymbol == null)))
		{
			super.update(elapsed);
			return;
		}

		if(heyTimer > 0)
		{
			var rate:Float = (PlayState.instance != null ? PlayState.instance.playbackRate : 1.0);
			heyTimer -= elapsed * rate;
			if(heyTimer <= 0)
			{
				var anim:String = getAnimationName();
				if(specialAnim && (anim == 'hey' || anim == 'cheer'))
				{
					specialAnim = false;
					dance();
				}
				heyTimer = 0;
			}
		}
		else if(specialAnim && isAnimationFinished())
		{
			specialAnim = false;
			dance();
		}
		else if (getAnimationName().endsWith('miss') && isAnimationFinished())
		{
			dance();
			finishAnimation();
		}

		switch(curCharacter)
		{
			case 'pico-speaker':
				if(animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0])
				{
					var noteData:Int = 1;
					if(animationNotes[0][1] > 2) noteData = 3;

					noteData += FlxG.random.int(0, 1);
					playAnim('shoot' + noteData, true);
					animationNotes.shift();
				}
				if(isAnimationFinished()) playAnim(getAnimationName(), false, false, animation.curAnim.frames.length - 3);
		}

		if (getAnimationName().startsWith('sing')) holdTimer += elapsed;
		else if(isPlayer) holdTimer = 0;

		if (!isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
		{
			dance();
			holdTimer = 0;
		}

		var name:String = getAnimationName();
		if(isAnimationFinished() && hasAnimation('$name-loop'))
			playAnim('$name-loop');

		if (ghostsEnabled)
		{
			for (ghost in doubleGhosts)
				ghost.update(elapsed);
		}
		super.update(elapsed);
	}

	inline public function isAnimationNull():Bool
	{
		return !isAnimateAtlas ? (animation.curAnim == null) : (atlas.anim.curInstance == null || atlas.anim.curSymbol == null);
	}

	var _lastPlayedAnimation:String;
	inline public function getAnimationName():String
	{
		return _lastPlayedAnimation;
	}

	public function isAnimationFinished():Bool
	{
		if(isAnimationNull()) return false;
		return !isAnimateAtlas ? animation.curAnim.finished : atlas.anim.finished;
	}

	public function finishAnimation():Void
	{
		if(isAnimationNull()) return;

		if(!isAnimateAtlas) animation.curAnim.finish();
		else atlas.anim.curFrame = atlas.anim.length - 1;
	}

	public function hasAnimation(anim:String):Bool
	{
		return animOffsets.exists(anim);
	}

	public var animPaused(get, set):Bool;
	private function get_animPaused():Bool
	{
		if(isAnimationNull()) return false;
		return !isAnimateAtlas ? animation.curAnim.paused : atlas.anim.isPlaying;
	}
	private function set_animPaused(value:Bool):Bool
	{
		if(isAnimationNull()) return value;
		if(!isAnimateAtlas) animation.curAnim.paused = value;
		else
		{
			if(value) atlas.pauseAnimation();
			else atlas.resumeAnimation();
		}

		return value;
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance()
	{
		if (!debugMode && !skipDance && !specialAnim)
		{
			if(danceIdle)
			{
				danced = !danced;

				if (danced)
					playAnim('danceRight' + idleSuffix);
				else
					playAnim('danceLeft' + idleSuffix);
			}
			else if(hasAnimation('idle' + idleSuffix))
				playAnim('idle' + idleSuffix);
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		specialAnim = false;
		if(!isAnimateAtlas)
		{
			animation.play(AnimName, Force, Reversed, Frame);
		}
		else
		{
			atlas.anim.play(AnimName, Force, Reversed, Frame);
			atlas.update(0);
		}
		_lastPlayedAnimation = AnimName;

		if (hasAnimation(AnimName))
		{
			final daOffset = animOffsets.get(AnimName);
			applyAnimOffsets(daOffset[0], daOffset[1]);
		}
		//else offset.set(0, 0);

		if (curCharacter.startsWith('gf-') || curCharacter == 'gf')
		{
			if (AnimName == 'singLEFT')
				danced = true;

			else if (AnimName == 'singRIGHT')
				danced = false;

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
				danced = !danced;
		}
	}

	public function flipAnims()
	{
		//rewrote it
		for (anim in animationsArray){
			if (anim.anim.contains("singRIGHT")){
				var animSplit:Array<String> = anim.anim.split('singRIGHT');

				if (animation.getByName('singRIGHT' + animSplit[1]) != null && animation.getByName('singLEFT' + animSplit[1]) != null)
				{
					var oldRight = animation.getByName('singRIGHT' + animSplit[1]).frames;
					animation.getByName('singRIGHT' + animSplit[1]).frames = animation.getByName('singLEFT' + animSplit[1]).frames;
					animation.getByName('singLEFT' + animSplit[1]).frames = oldRight;
				}
			}
		}
	}

	function loadMappedAnims():Void
	{
		try
		{
			var songData:SwagSong = Song.getChart('picospeaker', Paths.formatToSongPath(Song.loadedSongName));
			if(songData != null)
				for (section in songData.notes)
					for (songNotes in section.sectionNotes)
						animationNotes.push(songNotes);

			TankmenBG.animationNotes = animationNotes;
			animationNotes.sort(sortAnims);
		}
		catch(e:Dynamic) {}
	}

	function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	public var danceEveryNumBeats:Int = 2;
	private var settingCharacterUp:Bool = true;
	public function recalculateDanceIdle() {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (hasAnimation('danceLeft' + idleSuffix) && hasAnimation('danceRight' + idleSuffix));

		if(settingCharacterUp)
		{
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		}
		else if(lastDanceIdle != danceIdle)
		{
			var calc:Float = danceEveryNumBeats;
			if(danceIdle)
				calc /= 2;
			else
				calc *= 2;

			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}

	public function applyAnimOffsets(rawX:Float, rawY:Float) {
		var ox:Float = rawX;
		var oy:Float = rawY;

		if (scalableOffsets) {
			var base:Float = (jsonScale > 0) ? jsonScale : 1;
			ox *= scale.x / base;
			oy *= scale.y / base;
		}

		if (correctFlippedOffsets && !isAnimateAtlas) {
			if (flipX != baseFlipX)
				ox = (frameWidth * scale.x - width) - ox;
			
			if (flipY != baseFlipY)
				oy = (frameHeight * scale.y - height) - oy;
		}
		offset.set(ox, oy);
	}

	public function getAuthoredOffset():Array<Float> {
		var ox:Float = offset.x;
		var oy:Float = offset.y;

		if (correctFlippedOffsets && !isAnimateAtlas) {
			if (flipX != baseFlipX)
				ox = (frameWidth * scale.x - width) - ox;
			if (flipY != baseFlipY)
				oy = (frameHeight * scale.y - height) - oy;
		}
		if (correctFlippedOffsets) {
			var base:Float = (jsonScale > 0) ? jsonScale : 1;
			ox /= scale.x / base;
			oy /= scale.y / base;
		}
		return [ox, oy];
	}

	public function quickAnimAdd(name:String, anim:String)
	{
		animation.addByPrefix(name, anim, 24, false);
	}

	public function playGhostAnim(ghostID = 0, animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0)
	{
		var ghost:FlxSprite = doubleGhosts[ghostID];
		ghost.scale.copyFrom(scale);
		ghost.frames = frames;
		ghost.animation.copyFrom(animation);
		ghost.antialiasing = antialiasing;
		ghost.shader = shader;
		ghost.x = x;
		ghost.y = y;
		ghost.flipX = flipX;
		ghost.flipY = flipY;
		ghost.alpha = alpha * ghostAlpha;
		ghost.visible = visible;
		ghost.color = FlxColor.fromRGB(healthColorArray[0], healthColorArray[1], healthColorArray[2]);
		ghost.animation.play(animName, force, reversed, frame);
		
		if (ghostTweenGrp[ghostID] != null)
			ghostTweenGrp[ghostID].cancel();
		
		final direction:String = animName.substring(4).split('-')[0];
		
		inline function resolveDir(xDir:Bool = false):Float
		{
			var output:Float = 0;
			switch (direction)
			{
				case 'UP':
					if (!xDir) output = -ghostDisplacement;
				case 'DOWN':
					if (!xDir) output = ghostDisplacement;
				case 'RIGHT':
					if (xDir) output = ghostDisplacement;
				case 'LEFT':
					if (xDir) output = -ghostDisplacement;
			}
			
			return output;
		}
		
		final moveX = x + resolveDir(true);
		final moveY = y + resolveDir(false);
		
		ghostTweenGrp[ghostID] = FlxTween.tween(ghost, {alpha: 0, x: moveX, y: moveY}, 0.75,
			{
				onComplete: (twn) -> {
					ghost.visible = false;
					ghostTweenGrp[ghostID] = null;
				}
			});
			
		if (animOffsets.exists(animName))
		{
			final daOffset = animOffsets.get(animName);
			applyAnimOffsets(daOffset[0], daOffset[1]);
		}
	}

	// Atlas support
	// special thanks ne_eo for the references, you're the goat!!
	@:allow(states.editors.CharacterEditorState)
	public var isAnimateAtlas(default, null):Bool = false;
	#if flxanimate
	public var atlas:FlxAnimate;
	public override function draw()
	{
		var lastAlpha:Float = alpha;
		var lastColor:FlxColor = color;
		if(missingCharacter)
		{
			alpha *= 0.6;
			color = FlxColor.BLACK;
		}

		if(isAnimateAtlas)
		{
			if(atlas.anim.curInstance != null)
			{
				copyAtlasValues();
				atlas.draw();
				alpha = lastAlpha;
				color = lastColor;
				if(missingCharacter && visible)
				{
					missingText.x = getMidpoint().x - 150;
					missingText.y = getMidpoint().y - 10;
					missingText.draw();
				}
			}
			alpha = lastAlpha;
			color = lastColor;
			return;
		}
		if (ghostsEnabled)
		{
			for (ghost in doubleGhosts)
			{
				if (ghost.visible) ghost.draw();
			}
		}
		super.draw();
		if(missingCharacter && visible)
		{
			alpha = lastAlpha;
			color = lastColor;
			missingText.x = getMidpoint().x - 150;
			missingText.y = getMidpoint().y - 10;
			missingText.draw();
		}
	}

	public function copyAtlasValues()
	{
		@:privateAccess
		{
			atlas.cameras = cameras;
			atlas.scrollFactor = scrollFactor;
			atlas.scale = scale;
			atlas.offset = offset;
			atlas.origin = origin;
			atlas.x = x;
			atlas.y = y;
			atlas.angle = angle;
			atlas.alpha = alpha;
			atlas.visible = visible;
			atlas.flipX = flipX;
			atlas.flipY = flipY;
			atlas.shader = shader;
			atlas.antialiasing = antialiasing;
			atlas.colorTransform = colorTransform;
			atlas.color = color;
		}
	}
	#end

	public override function destroy()
	{
		#if flxanimate
		atlas = FlxDestroyUtil.destroy(atlas);
		#end
		missingText = FlxDestroyUtil.destroy(missingText);

		if (ghostTweenGrp != null && ghostTweenGrp.length > 0)
		{
			for (i in ghostTweenGrp)
				i?.cancel();
		}
		
		ghostTweenGrp = FlxDestroyUtil.destroyArray(ghostTweenGrp);
		
		doubleGhosts = FlxDestroyUtil.destroyArray(doubleGhosts);

		super.destroy();
	}
}