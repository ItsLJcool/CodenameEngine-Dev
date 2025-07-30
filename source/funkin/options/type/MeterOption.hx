package funkin.options.type;

// TODO: RECODE ALL OF THISS!! ITS SO SHITTY

import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMatrix;
import flixel.math.FlxRect;

@:access(flixel.FlxSprite._frame)
class MeterOption extends OptionType {
	public var selectCallback:Float->Void;

	public var min:Float;
	public var max:Float;

	public var currentSelection:Float;
	public var changeVal:Float;

	public var parent:Dynamic;

	public var barWidth(default, set):Int;

	override function set_text(v:String) return __text.text = text = v;

	private var __text:Alphabet;
	var optionName:String;

	var barScale:Float = 0.75;
	var realBarWidth:Float;
	var cornerWidth:Float;
	var slider:FlxSprite;
	var cornerEmpty:FlxSprite;
	var barEmpty:FlxSprite;
	var cornerFill:FlxSprite;
	var barFill:FlxSprite;
	var valueWidth:Float;
	var cornerClipRect:FlxRect;

	public function new(text:String, desc:String, min:Float, max:Float, changeVal:Float, optionName:String, barWidth:Int = 520,
		?selectCallback:Float->Void = null, ?parent:Dynamic)
	{
		super(text, desc);

		this.selectCallback = selectCallback;
		this.min = min;
		this.max = max;
		if (parent == null) parent = Options;

		this.parent = parent;

		if (Reflect.field(parent, optionName) != null) this.currentSelection = Reflect.field(parent, optionName);
		this.changeVal = changeVal;
		this.optionName = optionName;

		add(__text = new Alphabet(20, 20, "", "bold"));
		rawText = text;

		var frames = Paths.getFrames('menus/options/meter');
		add(slider = new FlxSprite(0, 24));
		slider.frames = frames;
		slider.animation.addByPrefix('slider', 'meter slider', 24);
		slider.animation.play('slider');
		slider.antialiasing = true;
		slider.scale.set(barScale, barScale);
		slider.updateHitbox();

		(cornerEmpty = new FlxSprite()).frames = (barEmpty = new FlxSprite()).frames = frames;
		(cornerFill = new FlxSprite()).frames = (barFill = new FlxSprite()).frames = frames;
		cornerEmpty.animation.addByPrefix('corner', 'meter empty corner', 24);
		cornerEmpty.animation.play('corner');
		barEmpty.animation.addByPrefix('bar', 'meter empty piece', 24);
		barEmpty.animation.play('bar');
		cornerFill.animation.addByPrefix('corner', 'meter filled corner', 24);
		cornerFill.animation.play('corner');
		barFill.animation.addByPrefix('bar', 'meter filled piece', 24);
		barFill.animation.play('bar');

		cornerClipRect = new FlxRect();
		cornerEmpty.rawClipRect = cornerClipRect;
		cornerFill.rawClipRect = cornerClipRect;

		_matrix = new FlxMatrix();
		cornerWidth = Math.max(cornerFill.frameWidth, cornerEmpty.frameWidth);
		this.barWidth = barWidth;
	}

	function set_barWidth(value:Int):Int {
		if (value == barWidth) return value;
		realBarWidth = Math.max(cornerWidth + value / barScale, cornerWidth * 2);
		updateBar();

		__text.x = x + 20 + realBarWidth * barScale;

		return barWidth = value;
	}

	function updateBar() {
		var w = (currentSelection - min) / (max - min) * (realBarWidth - cornerWidth * 2) + cornerWidth;
		slider.x = x + w * barScale - slider.width * 0.5;
		valueWidth = w;
	}

	inline function drawObject(sprite:FlxSprite, camera:FlxCamera, x:Float, y:Float) {
		getScreenPosition(_point, camera).subtractPoint(offset);
		_matrix.translate(_point.x + x, _point.y + y);

		/*if (isPixelPerfectRender(camera)) {
			_matrix.tx = Math.floor(_matrix.tx);
			_matrix.ty = Math.floor(_matrix.ty);
		}*/

		if (layer != null) layer.drawPixels(sprite, camera, sprite._frame, sprite.framePixels, _matrix, colorTransform, blend, true);
		else camera.drawPixels(sprite._frame, sprite.framePixels, _matrix, colorTransform, blend, true);
	}

	var lastX:Float;
	var temp:Float;
	function drawCorner(width:Float, flip:Bool, camera:FlxCamera) {
		if ((temp = Math.max(Math.min(width, cornerFill.frameWidth), 0)) > 0) {
			cornerClipRect.set(0, 0, temp, cornerFill.frameHeight);
			cornerFill.frame = cornerFill.frames.frames[cornerFill.animation.frameIndex];
			cornerFill._frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, flip != camera.flipX, flipY != camera.flipY);
			_matrix.scale(barScale, barScale);
			drawObject(cornerFill, camera, 0, 37);
		}

		if (temp < cornerEmpty.frameWidth) {
			cornerClipRect.set(temp, 0, cornerEmpty.frameWidth - temp, cornerEmpty.frameHeight);
			cornerEmpty.frame = cornerEmpty.frames.frames[cornerEmpty.animation.frameIndex];
			cornerEmpty._frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, flip != camera.flipX, flipY != camera.flipY);
			_matrix.scale(barScale, barScale);
			drawObject(cornerEmpty, camera, temp * barScale, 37);
		}

		x += cornerWidth * barScale;
	}

	function drawBar(width:Float, camera:FlxCamera) {
		temp = realBarWidth - cornerWidth * 2;
		if (width > 0) {
			barFill._frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, camera.flipX, flipY != camera.flipY);
			_matrix.scale((Math.min(width, temp) + 2) / barFill.frameWidth * barScale, barScale);
			drawObject(barFill, camera, -1, 37);
		}

		if (width < temp) {
			barEmpty._frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, camera.flipX, flipY != camera.flipY);
			_matrix.scale((Math.max(temp - width, 0) + 1) / barEmpty.frameWidth * barScale, barScale);
			drawObject(barEmpty, camera, width * barScale, 37);
		}

		/*if (width < (temp = realBarWidth - cornerWidth * 2)) {
			barEmpty._frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, camera.flipX, flipY != camera.flipY);
			_matrix.scale((width - realBarWidth + cornerWidth + 1) / barFill.frameWidth, 1);
			drawObject(barEmpty, camera, realBarWidth - width, 37);
		}*/

		x += temp * barScale;
	}

	override function draw() {
		lastX = x;

		for (camera in cameras) {
			if (!camera.visible || !camera.exists) continue;

			drawCorner(currentSelection == min ? 0 : valueWidth, false, camera);
			drawBar(valueWidth - cornerWidth, camera);
			drawCorner(currentSelection == max ? cornerWidth : valueWidth - realBarWidth + cornerWidth, true, camera);

			x = lastX;
		}
		super.draw();
	}

	override function destroy() {
		super.destroy();
		cornerEmpty.destroy();
		barEmpty.destroy();
		cornerFill.destroy();
		barFill.destroy();
	}

	override function reloadStrings() {
		super.reloadStrings();
		this.rawText = rawText;
	}

	override function changeSelection(change:Float) {
		if (currentSelection <= min && change == -1 || currentSelection >= max && change == 1) return;
		currentSelection = FlxMath.roundDecimal(currentSelection + (change * changeVal), FlxMath.getDecimals(changeVal));

		updateBar();

		Reflect.setField(parent, optionName, currentSelection);
		if (selectCallback != null) selectCallback(currentSelection);
	}
}