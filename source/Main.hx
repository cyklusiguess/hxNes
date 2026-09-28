package;

import flixel.FlxGame;
import openfl.display.Sprite;

class Main extends Sprite {
	public function new() {
		super();
		addChild(new FlxGame(1024, 840, PlayState, 60, 60, false));
	}
}
