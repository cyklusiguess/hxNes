package;

import haxe.ds.Vector;

class Canvas {
	public static inline var W = "\x01";
	public static inline var H = "\x02";
	public static inline var V = "\x03";
	public static inline var G = "\x04";
	public static inline var R = "\x05";
	public static inline var D = "\x06";
	public static inline var M = "\x07";
	public static final PAL:Array<Int> = [
		0xFFE6E6E6, 0xFFE6E6E6, 0xFF5CC8FF, 0xFFFFE066, 0xFF6BFF8A, 0xFFFF6B6B, 0xFF8C8C96, 0xFFFF8CF0
	];
	static final FONT_HEX = "0000000000000000183C3C1818001800363600000000000036367F367F3636000C3E031E301F0C00006333180C6663001C361C6E3B336E000606030000000000"
		+ "180C0606060C1800060C1818180C060000663CFF3C660000000C0C3F0C0C000000000000000C0C060000003F0000000000000000000C0C006030180C06030100"
		+ "3E63737B6F673E000C0E0C0C0C0C3F001E33301C06333F001E33301C30331E00383C36337F3078003F031F3030331E001C06031F33331E003F3330180C0C0C00"
		+ "1E33331E33331E001E33333E30180E00000C0C00000C0C00000C0C00000C0C06180C0603060C180000003F00003F0000060C1830180C06001E3330180C000C00"
		+ "3E637B7B7B031E000C1E33333F3333003F66663E66663F003C66030303663C001F36666666361F007F46161E16467F007F46161E16060F003C66030373667C00"
		+ "3333333F333333001E0C0C0C0C0C1E007830303033331E006766361E366667000F06060646667F0063777F7F6B63630063676F7B736363001C36636363361C00"
		+ "3F66663E06060F001E3333333B1E38003F66663E366667001E33070E38331E003F2D0C0C0C0C1E003333333333333F0033333333331E0C006363636B7F776300"
		+ "6363361C1C3663003333331E0C0C1E007F6331184C667F001E06060606061E0003060C18306040001E18181818181E00081C36630000000000000000000000FF"
		+ "0C0C18000000000000001E303E336E000706063E66663B0000001E3303331E003830303E33336E0000001E333F031E001C36060F06060F0000006E33333E301F"
		+ "0706366E666667000C000E0C0C0C1E00300030303033331E070666361E3667000E0C0C0C0C0C1E000000337F7F6B630000001F333333330000001E3333331E00"
		+ "00003B66663E060F00006E33333E307800003B6E66060F0000003E031E301F00080C3E0C0C2C18000000333333336E0000003333331E0C000000636B7F7F3600"
		+ "000063361C36630000003333333E301F00003F190C263F00380C0C070C0C38001818180018181800070C0C380C0C07006E3B000000000000";
	static var glyphs:Vector<Int> = null;
	public var w:Int;
	public var h:Int;
	public var pix:Vector<Int>;
	public function new(w:Int, h:Int) {
		this.w = w;
		this.h = h;
		pix = new Vector<Int>(w * h);
		clear(0);
		if (glyphs == null) {
			glyphs = new Vector<Int>(95 * 8);
			for (i in 0...95 * 8)
				glyphs[i] = Std.parseInt("0x" + FONT_HEX.substr(i * 2, 2));
		}
	}
	public function clear(c:Int):Void {
		var n = pix.length;
		if (n == 0)
			return;
		pix[0] = c;
		var f = 1;
		while (f < n) {
			var len = f < n - f ? f : n - f;
			Vector.blit(pix, 0, pix, f, len);
			f += len;
		}
	}
	public inline function set(x:Int, y:Int, c:Int):Void {
		if (x >= 0 && y >= 0 && x < w && y < h)
			pix[y * w + x] = c;
	}
	public function fillRect(x:Int, y:Int, rw:Int, rh:Int, c:Int):Void {
		var x0 = x < 0 ? 0 : x;
		var y0 = y < 0 ? 0 : y;
		var x1 = x + rw > w ? w : x + rw;
		var y1 = y + rh > h ? h : y + rh;
		if (x1 <= x0 || y1 <= y0)
			return;
		var len = x1 - x0;
		var o = y0 * w + x0;
		for (i in 0...len)
			pix[o + i] = c;
		if (len < 16) {
			for (yy in y0 + 1...y1) {
				var oo = yy * w + x0;
				for (i in 0...len)
					pix[oo + i] = c;
			}
		} else
			for (yy in y0 + 1...y1)
				Vector.blit(pix, o, pix, yy * w + x0, len);
	}
	public function rect(x:Int, y:Int, rw:Int, rh:Int, c:Int):Void {
		fillRect(x, y, rw, 1, c);
		fillRect(x, y + rh - 1, rw, 1, c);
		fillRect(x, y, 1, rh, c);
		fillRect(x + rw - 1, y, 1, rh, c);
	}
	public function line(x0:Int, y0:Int, x1:Int, y1:Int, c:Int):Void {
		var dx = x1 > x0 ? x1 - x0 : x0 - x1;
		var dy = y1 > y0 ? y0 - y1 : y1 - y0;
		var sx = x0 < x1 ? 1 : -1;
		var sy = y0 < y1 ? 1 : -1;
		var err = dx + dy;
		while (true) {
			set(x0, y0, c);
			if (x0 == x1 && y0 == y1)
				break;
			var e2 = 2 * err;
			if (e2 >= dy) {
				err += dy;
				x0 += sx;
			}
			if (e2 <= dx) {
				err += dx;
				y0 += sy;
			}
		}
	}
	public function text(x:Int, y:Int, s:String, col:Int = 0xFFE6E6E6):Int {
		var cx = x;
		for (i in 0...s.length) {
			var ch = s.charCodeAt(i);
			if (ch >= 1 && ch <= 7) {
				col = PAL[ch];
				continue;
			}
			if (ch < 32 || ch > 126)
				ch = 63;
			if (cx > -8 && cx < w) {
				var g = (ch - 32) * 8;
				var inside = cx >= 0 && cx + 8 <= w;
				for (r in 0...8) {
					var bits = glyphs[g + r];
					if (bits == 0)
						continue;
					var yy = y + r;
					if (yy < 0 || yy >= h)
						continue;
					if (inside) {
						var o = yy * w + cx;
						for (c in 0...8)
							if ((bits & (1 << c)) != 0)
								pix[o + c] = col;
					} else {
						for (c in 0...8)
							if ((bits & (1 << c)) != 0)
								set(cx + c, yy, col);
					}
				}
			}
			cx += 8;
		}
		return cx - x;
	}

	public static function visLen(s:String):Int {
		var n = 0;
		for (i in 0...s.length) {
			var ch = s.charCodeAt(i);
			if (ch < 1 || ch > 7)
				n++;
		}
		return n;
	}
	public static function plain(s:String):String {
		var found = false;
		for (i in 0...s.length) {
			var ch = s.charCodeAt(i);
			if (ch >= 1 && ch <= 7) {
				found = true;
				break;
			}
		}
		if (!found)
			return s;
		var b = new StringBuf();
		for (i in 0...s.length) {
			var ch = s.charCodeAt(i);
			if (ch < 1 || ch > 7)
				b.addChar(ch);
		}
		return b.toString();
	}
}
