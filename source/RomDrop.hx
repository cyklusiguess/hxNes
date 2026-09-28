package;

import haxe.io.Bytes;

class RomDrop {
	public static var onRom:(data:Bytes, name:String) -> Void = null;

	static var ready = false;

	public static function init():Void {
		if (ready)
			return;
		ready = true;

		#if html5
		var doc = js.Browser.document;
		doc.addEventListener("dragover", function(e:js.html.Event) e.preventDefault());
		doc.addEventListener("drop", function(e:js.html.Event) {
			e.preventDefault();
			var files = cast(e, js.html.DragEvent).dataTransfer.files;
			if (files.length == 0)
				return;
			var f = files.item(0);
			var reader = new js.html.FileReader();
			reader.onload = function(_) {
				if (onRom != null)
					onRom(Bytes.ofData(reader.result), f.name);
			};
			reader.readAsArrayBuffer(f);
		});
		#elseif sys
		openfl.Lib.current.stage.window.onDropFile.add(function(path:String) {
			if (onRom == null)
				return;
			try {
				onRom(sys.io.File.getBytes(path), haxe.io.Path.withoutDirectory(path));
			} catch (e:Dynamic) {
				onRom(null, haxe.io.Path.withoutDirectory(path));
			}
		});
		#end
	}
}
