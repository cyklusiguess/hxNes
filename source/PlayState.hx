package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.io.Bytes;
import openfl.Vector;
import openfl.display.BitmapData;
import openfl.events.SampleDataEvent;
import openfl.geom.Rectangle;
import openfl.media.Sound;
import openfl.media.SoundChannel;

private class DebugLayer {
	public var cv:Canvas;
	public var sprite:FlxSprite;

	var every:Int;
	var phase:Int;
	var buf:Vector<UInt>;
	var rect:Rectangle;

	public function new(x:Int, y:Int, w:Int, h:Int, every:Int, phase:Int) {
		this.every = every;
		this.phase = phase;
		cv = new Canvas(w, h);
		buf = new Vector<UInt>(w * h, true);
		rect = new Rectangle(0, 0, w, h);
		sprite = new FlxSprite(x, y);
		sprite.makeGraphic(w, h, 0x00000000, true);
		sprite.antialiasing = false;
		sprite.origin.set(0, 0);
		sprite.active = false;
		sprite.visible = false;
	}

	public inline function due(tick:Int):Bool
		return tick % every == phase;

	public function push():Void {
		var src = cv.pix;
		for (i in 0...buf.length)
			buf[i] = src[i];
		sprite.pixels.setVector(rect, buf);
		sprite.dirty = true;
		sprite.visible = true;
	}
}

private class DebugBoxes {
	var border:Array<FlxSprite> = [];
	var edges:Array<FlxSprite> = [];
	var data = new haxe.ds.Vector<Int>(DebugView.MAX_BOXES * 5);
	var shown = 0;

	public function new(state:FlxState) {
		for (i in 0...4)
			border.push(make(state));
		for (i in 0...DebugView.MAX_BOXES * 4)
			edges.push(make(state));
		var w = DebugView.PANE_W;
		var h = DebugView.PANE_H;
		place(border[0], 0, 0, w, 1, 0xFF5CC8FF);
		place(border[1], 0, h - 1, w, 1, 0xFF5CC8FF);
		place(border[2], 0, 0, 1, h, 0xFF5CC8FF);
		place(border[3], w - 1, 0, 1, h, 0xFF5CC8FF);
		for (b in border)
			b.visible = false;
	}

	static function make(state:FlxState):FlxSprite {
		var s = new FlxSprite(0, 0);
		s.makeGraphic(1, 1, 0xFFFFFFFF);
		s.antialiasing = false;
		s.origin.set(0, 0);
		s.active = false;
		s.visible = false;
		state.add(s);
		return s;
	}

	static function place(s:FlxSprite, x:Int, y:Int, w:Int, h:Int, c:Int):Void {
		var x1 = x + w;
		var y1 = y + h;
		if (x < 0)
			x = 0;
		if (y < 0)
			y = 0;
		if (x1 > DebugView.PANE_W)
			x1 = DebugView.PANE_W;
		if (y1 > DebugView.PANE_H)
			y1 = DebugView.PANE_H;
		if (x1 <= x || y1 <= y) {
			s.visible = false;
			return;
		}
		s.x = x;
		s.y = y;
		s.scale.set(x1 - x, y1 - y);
		s.color = c;
		s.visible = true;
	}

	public function update(view:DebugView, on:Bool):Void {
		for (b in border)
			b.visible = on;
		var n = (on && view.boxes) ? view.collectBoxes(data) : 0;
		for (k in 0...n) {
			var o = k * 5;
			var x = data[o];
			var y = data[o + 1];
			var w = data[o + 2];
			var h = data[o + 3];
			var c = data[o + 4] != 0 ? 0xFFFF6B6B : 0xFFFFE066;
			var e = k * 4;
			place(edges[e], x, y, w, 1, c);
			place(edges[e + 1], x, y + h - 1, w, 1, c);
			place(edges[e + 2], x, y, 1, h, c);
			place(edges[e + 3], x + w - 1, y, 1, h, c);
		}
		for (k in n * 4...shown * 4)
			edges[k].visible = false;
		shown = n;
	}
}

@:access(Nes)
class PlayState extends FlxState {
	static final CHN = ["pulse 1", "pulse 2", "triangle", "noise", "DMC"];

	static var rom:Bytes = null;
	static var romMsg:String = "";

	var nes:Nes;
	var screen:FlxSprite;
	var rect = new Rectangle(0, 0, 256, 224);
	var buf = new Vector<UInt>(256 * 224, true);
	var stallTicks = 0;
	var sound:Sound;
	var channel:SoundChannel;

	var dbgOn = false;
	var dbgView:DebugView;
	var dbgBoxes:DebugBoxes;
	var dbgLayers:Array<DebugLayer> = [];
	var lyHud:DebugLayer;
	var lyCart:DebugLayer;
	var lyRight:DebugLayer;
	var lyApu:DebugLayer;
	var lyMenu:DebugLayer;
	var lyEv:DebugLayer;
	var lyScope:DebugLayer;
	var lyLower:DebugLayer;
	var dbgTick = 0;
	var dbgEvSeq = 0;
	var dbgTermAcc = 0.0;
	var dbgFrameMs = 0.0;
	var termBuf = new StringBuf();
	var termN = 0;
	var lastMx = 0;
	var lastMy = 0;

	override public function create():Void {
		super.create();
		bgColor = 0xFF000000;
		RomDrop.init();
		RomDrop.onRom = onDrop;

		if (rom == null) {
			showPrompt();
			return;
		}
		FlxG.mouse.load(crosshair(), 1, -8, -8);
		FlxG.mouse.visible = true;

		screen = new FlxSprite(0, 0);
		screen.makeGraphic(256, 224, 0xFF000000, true);
		screen.antialiasing = false;
		screen.origin.set(0, 0);
		screen.scale.set(FlxG.width / 256, FlxG.height / 224);
		add(screen);

		nes = new Nes();
		nes.load(rom);

		sound = new Sound();
		sound.addEventListener(SampleDataEvent.SAMPLE_DATA, onSamples);
		channel = sound.play();

		dbgView = new DebugView(nes);
		dbgBoxes = new DebugBoxes(this);

		var lh = DebugView.LINE_H;
		var cartRows = dbgView.cartRows();
		var rightY = DebugView.TR_Y + cartRows * lh;
		var menuY = DebugView.BL_Y + DebugView.APU_ROWS * lh + 4;
		var rightRows = DebugView.CPU_ROWS + DebugView.PPU_ROWS + DebugView.VIEW_ROWS;
		lyHud = layer(0, 0, DebugView.HUD_W, DebugView.HUD_H, 5, 0);
		lyCart = layer(DebugView.TR_X, DebugView.TR_Y, DebugView.TR_W, cartRows * lh, 5, 0);
		lyRight = layer(DebugView.TR_X, rightY, DebugView.TR_W, rightRows * lh, 5, 1);
		lyApu = layer(DebugView.BL_X, DebugView.BL_Y, DebugView.BL_W, DebugView.APU_ROWS * lh, 5, 2);
		lyEv = layer(DebugView.EV_X, DebugView.EV_Y, DebugView.EV_W, DebugView.EV_H, 5, 3);
		lyMenu = layer(DebugView.BL_X, menuY, DebugView.BL_W, DebugView.MENU_ROWS * lh, 5, 4);
		lyScope = layer(DebugView.LIVE_X, DebugView.LIVE_Y, DebugView.LIVE_W, DebugView.SCOPE_H, 3, 0);
		lyLower = layer(DebugView.LIVE_X, DebugView.LIVE_Y + DebugView.SCOPE_H, DebugView.LIVE_W, DebugView.LIVE_H - DebugView.SCOPE_H, 10, 9);

		haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos):Void {
			#if sys
			Sys.println(Std.string(v));
			#elseif js
			js.Syntax.code("console.log({0})", Std.string(v));
			#end
		}
	}

	static function crosshair():BitmapData {
		var b = new BitmapData(17, 17, true, 0x00000000);
		b.fillRect(new Rectangle(7, 0, 3, 17), 0xFF000000);
		b.fillRect(new Rectangle(0, 7, 17, 3), 0xFF000000);
		b.fillRect(new Rectangle(8, 1, 1, 15), 0xFFFFFFFF);
		b.fillRect(new Rectangle(1, 8, 15, 1), 0xFFFFFFFF);
		return b;
	}

	function updateZapper():Void {
		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;
		if (mx != lastMx || my != lastMy || FlxG.mouse.pressed)
			nes.zapper = true;
		lastMx = mx;
		lastMy = my;
		var nx = Math.floor(mx / screen.scale.x);
		var ny = Math.floor(my / screen.scale.y);
		if (nx < 0 || nx >= 256 || ny < 0 || ny >= 224) {
			nes.zx = -1;
			nes.zy = -1;
		} else {
			nes.zx = nx;
			nes.zy = ny + 8;
		}
		nes.zTrig = FlxG.mouse.pressed;
	}

	function showPrompt():Void {
		FlxG.mouse.visible = true;
		var t = new FlxText(0, FlxG.height / 2 - 24, FlxG.width, "drag and drop a rom into the window", 32);
		t.alignment = CENTER;
		t.color = FlxColor.WHITE;
		add(t);
		if (romMsg != "") {
			var e = new FlxText(0, FlxG.height / 2 + 30, FlxG.width, romMsg, 18);
			e.alignment = CENTER;
			e.color = 0xFFFF6B6B;
			add(e);
		}
	}

	static function onDrop(data:Bytes, name:String):Void {
		var ok = data != null && data.length >= 16 && data.get(0) == 0x4E && data.get(1) == 0x45 && data.get(2) == 0x53 && data.get(3) == 0x1A;
		if (!ok) {
			romMsg = name + " isn't a valid .nes rom";
			if (rom == null)
				FlxG.resetState();
			return;
		}
		rom = data;
		romMsg = "";
		FlxG.resetState();
	}

	function layer(x:Int, y:Int, w:Int, h:Int, every:Int, phase:Int):DebugLayer {
		var l = new DebugLayer(x, y, w, h, every, phase);
		dbgLayers.push(l);
		add(l.sprite);
		return l;
	}

	function onSamples(e:SampleDataEvent):Void {
		for (i in 0...2048) {
			var s = nes.popSample();
			e.data.writeFloat(s);
			e.data.writeFloat(s);
		}
	}

	function log(s:String):Void {
		if (termN++ > 0)
			termBuf.addChar(10);
		termBuf.add(s);
	}

	function flushLog():Void {
		if (termN == 0)
			return;
		var s = termBuf.toString();
		termBuf = new StringBuf();
		termN = 0;
		trace(s);
	}

	function toggleDebug():Void {
		dbgOn = !dbgOn;
		nes.dbg = dbgOn;
		if (dbgOn) {
			screen.scale.set(DebugView.PANE_W / 256, DebugView.PANE_H / 224);
			dbgEvSeq = nes.evSeq;
			dbgView.invalidate();
			log("");
			log("on");
			for (l in dbgView.cart())
				log(Canvas.plain(l));
			log("(all details on screen, press D any time for a full snapshot dump here)");
		} else {
			screen.scale.set(FlxG.width / 256, FlxG.height / 224);
			for (l in dbgLayers)
				l.sprite.visible = false;
			log("off");
		}
		dbgBoxes.update(dbgView, dbgOn);
	}

	function toggleMute(i:Int):Void {
		nes.muteMask ^= 1 << i;
		log(CHN[i] + (((nes.muteMask >> i) & 1) != 0 ? " muted" : " unmuted"));
	}

	function debugInput():Void {
		var k = FlxG.keys;
		if (k.justPressed.F3)
			toggleDebug();
		if (!dbgOn)
			return;

		if (k.justPressed.ONE) {
			nes.perfectAudio = !nes.perfectAudio;
			log((nes.perfectAudio ? "PERFECT SOUND CHIP mode ON" : "PERFECT SOUND CHIP mode off")
				+ " (smooth triangle, band-limited output, declicked envelopes, drift-free resampler)");
		}
		if (k.justPressed.TWO)
			toggleMute(0);
		if (k.justPressed.THREE)
			toggleMute(1);
		if (k.justPressed.FOUR)
			toggleMute(2);
		if (k.justPressed.FIVE)
			toggleMute(3);
		if (k.justPressed.SIX)
			toggleMute(4);
		if (k.justPressed.SEVEN) {
			dbgView.termLive = !dbgView.termLive;
			log("live terminal log " + (dbgView.termLive ? "ON" : "off"));
		}
		if (k.justPressed.EIGHT)
			dbgView.boxes = !dbgView.boxes;
		if (k.justPressed.NINE)
			dbgView.bottomView = dbgView.bottomView == 0 ? 1 : 0;
		if (k.justPressed.P) {
			dbgView.paused = !dbgView.paused;
			log(dbgView.paused ? "-- paused --" : "-- resumed --");
		}
		if (k.justPressed.N && dbgView.paused)
			runEmu();
		if (k.justPressed.D) {
			log("full debug snapshot:");
			for (l in dbgView.dumpAll())
				log(Canvas.plain(l));
		}
		if (k.justPressed.PAGEUP)
			dbgView.ramPage = (dbgView.ramPage - 1) & 7;
		if (k.justPressed.PAGEDOWN)
			dbgView.ramPage = (dbgView.ramPage + 1) & 7;
	}

	function debugStreamEvents():Void {
		if (!dbgView.termLive)
			return;
		var missed = nes.evSeq - dbgEvSeq;
		if (missed <= 0)
			return;
		if (missed > Nes.EV_N) {
			log("... (" + (missed - Nes.EV_N) + " events skipped) ...");
			dbgEvSeq = nes.evSeq - Nes.EV_N;
		}
		while (dbgEvSeq < nes.evSeq) {
			log(Canvas.plain(nes.evBuf[dbgEvSeq & (Nes.EV_N - 1)]));
			dbgEvSeq++;
		}
	}

	function runEmu():Void {
		var t0 = haxe.Timer.stamp();
		nes.runFrame();
		dbgFrameMs = (haxe.Timer.stamp() - t0) * 1000.0;
		debugStreamEvents();
		blitFrame();
	}

	function runPaced():Void {
		if (!nes.audioLive) {
			runEmu();
			return;
		}
		if (!nes.canRunFrame() && stallTicks < 8) {
			stallTicks++;
			return;
		}
		stallTicks = 0;
		runEmu();
		var extra = 0;
		while (extra < 2 && nes.needsFrame()) {
			nes.runFrame();
			extra++;
		}
		if (extra > 0) {
			debugStreamEvents();
			blitFrame();
		}
	}

	function blitFrame():Void {
		var f = nes.frame;
		for (i in 0...buf.length)
			buf[i] = f[2048 + i];
		screen.pixels.setVector(rect, buf);
		screen.dirty = true;
	}

	function renderDebug():Void {
		var t = dbgTick++;
		if (lyHud.due(t) && dbgView.renderHud(lyHud.cv))
			lyHud.push();
		if (lyCart.due(t) && dbgView.renderCart(lyCart.cv))
			lyCart.push();
		if (lyRight.due(t) && dbgView.renderRight(lyRight.cv))
			lyRight.push();
		if (lyApu.due(t) && dbgView.renderApu(lyApu.cv))
			lyApu.push();
		if (lyEv.due(t) && dbgView.renderEvents(lyEv.cv))
			lyEv.push();
		if (lyMenu.due(t) && dbgView.renderMenu(lyMenu.cv))
			lyMenu.push();
		if (lyScope.due(t)) {
			dbgView.renderScopes(lyScope.cv);
			lyScope.push();
		}
		if (lyLower.due(t)) {
			dbgView.renderLower(lyLower.cv);
			lyLower.push();
		}
		dbgBoxes.update(dbgView, true);
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		if (nes == null)
			return;

		var k = FlxG.keys.pressed;
		nes.pad = (k.X ? 1 : 0)
			| (k.Z ? 2 : 0)
			| (k.TAB ? 4 : 0)
			| (k.ENTER ? 8 : 0)
			| (k.UP ? 16 : 0)
			| (k.DOWN ? 32 : 0)
			| (k.LEFT ? 64 : 0)
			| (k.RIGHT ? 128 : 0);

		updateZapper();
		debugInput();

		if (!dbgOn || !dbgView.paused)
			runPaced();

		if (dbgOn) {
			dbgView.fps = elapsed > 0 ? 1.0 / elapsed : 0.0;
			dbgView.emuMs = dbgFrameMs;
			dbgView.uptime += elapsed;

			dbgTermAcc += elapsed;
			if (dbgView.termLive && dbgTermAcc >= 0.25) {
				dbgTermAcc = 0;
				log(dbgView.statusLine());
			}

			renderDebug();
		}

		flushLog();
	}

	override public function destroy():Void {
		if (RomDrop.onRom == onDrop)
			RomDrop.onRom = null;
		if (channel != null)
			channel.stop();
		if (sound != null)
			sound.removeEventListener(SampleDataEvent.SAMPLE_DATA, onSamples);
		super.destroy();
	}
}
