package funkin.editors.ui;

import openfl.display.BitmapData;
import flixel.util.FlxColor;

using funkin.backend.utils.BitmapUtil;

class UIIconColorPicker extends UISliceSprite {
	public var colorWheel:UIColorwheel;

	public var iconSprite:FlxSprite;
	public var iconTextBox:UITextBox;

	public var pickerButton:UIButton;
	public var pickerIcon:FlxSprite;
	
	public function new(x:Float, y:Float, icon:String, antialaising:Bool, colorWheel:UIColorwheel) {
		super(x, y, 12+125+12, 4+125+4+32+12, 'editors/ui/inputbox');

		this.colorWheel = colorWheel;

		iconTextBox = new UITextBox(x+12, y+4+125+4, icon, 125);
		iconTextBox.onChange = (newIcon:String) -> {updateIcon(newIcon);}
		members.push(iconTextBox);

		members.push(iconSprite = new FlxSprite());
		iconSprite.antialiasing = antialaising;

		pickerButton = new UIButton(x+12+125-26, y+12, null, colorPick, 26, 26);
		pickerButton.frames = Paths.getFrames('editors/ui/inputbox');
		members.push(pickerButton);

		pickerIcon = new FlxSprite(pickerButton.x+7, pickerButton.y+7).loadGraphic(Paths.image("editors/ui/picker"));
		members.push(pickerIcon);

		updateIcon(icon);
	}

	var __path:String = null;
	public function updateIcon(icon:String) {
		if (iconSprite.animation.exists(icon)) return;
		@:privateAccess iconSprite.animation.clearAnimations();

		var path:String = Paths.image('icons/$icon');
		if (!Assets.exists(path)) path = Paths.image('icons/face');

		iconSprite.loadGraphic(__path = path, true, 150, 150);
		iconSprite.animation.add(icon, [0], 0, false);
		iconSprite.animation.play(icon);

		iconSprite.scale.set(125/150, 125/150);
		iconSprite.updateHitbox();
		iconSprite.setPosition(x+12, y+4);

		__cachedColor = null;
	}

	var __cachedColor:Null<FlxColor> = null;
	public function colorPick() {
		if (__cachedColor == null) {
			var imageBitmap:BitmapData = Assets.getBitmapData(__path, true, false);
			__cachedColor = imageBitmap.getMostPresentColor();
			imageBitmap.dispose();
		}

		if (colorWheel != null) {
			colorWheel.hue = __cachedColor.hue; 
			colorWheel.saturation = __cachedColor.saturation; 
			colorWheel.brightness = __cachedColor.brightness;
			colorWheel.updateWheel();
		}
	}
}