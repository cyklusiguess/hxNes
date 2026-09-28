package;

import Canvas.*;
import haxe.ds.Vector;

@:access(Nes)
class DebugView {
	public static inline var PANE_W = 512;
	public static inline var PANE_H = 420;
	public static inline var TR_X = 520;
	public static inline var TR_Y = 4;
	public static inline var TR_W = 504;
	public static inline var BL_X = 4;
	public static inline var BL_Y = 424;
	public static inline var BL_W = 504;
	public static inline var LIVE_X = 516;
	public static inline var LIVE_Y = 424;
	public static inline var LIVE_W = 508;
	public static inline var LIVE_H = 316;
	public static inline var SCOPE_H = 168;
	public static inline var EV_X = 520;
	public static inline var EV_Y = 742;
	public static inline var EV_W = 504;
	public static inline var EV_H = 98;
	public static inline var HUD_W = 320;
	public static inline var HUD_H = 26;
	public static inline var LINE_H = 10;
	public static inline var CPU_ROWS = 7;
	public static inline var PPU_ROWS = 9;
	public static inline var VIEW_ROWS = 17;
	public static inline var APU_ROWS = 14;
	public static inline var MENU_ROWS = 14;
	public static inline var MAX_BOXES = 64;
	static final IMPL:Map<Int, String> = [
		0x00 => "BRK", 0x40 => "RTI", 0x60 => "RTS", 0x08 => "PHP", 0x28 => "PLP", 0x48 => "PHA", 0x68 => "PLA", 0x88 => "DEY", 0xA8 => "TAY",
		0xC8 => "INY", 0xE8 => "INX", 0x18 => "CLC", 0x38 => "SEC", 0x58 => "CLI", 0x78 => "SEI", 0x98 => "TYA", 0xB8 => "CLV", 0xD8 => "CLD",
		0xF8 => "SED", 0x8A => "TXA", 0x9A => "TXS", 0xAA => "TAX", 0xBA => "TSX", 0xCA => "DEX", 0xEA => "NOP"
	];
	static final BRANCH = ["BPL", "BMI", "BVC", "BVS", "BCC", "BCS", "BNE", "BEQ"];
	static final NAMES1 = ["ORA", "AND", "EOR", "ADC", "STA", "LDA", "CMP", "SBC"];
	static final MODES1 = [7, 1, 0, 4, 8, 2, 6, 5];
	static final NAMES2 = ["ASL", "ROL", "LSR", "ROR", "STX", "LDX", "DEC", "INC"];
	static final NAMES0 = ["???", "BIT", "JMP", "JMP", "STY", "LDY", "CPY", "CPX"];
	static final MAPPERS:Map<Int, String> = [0 => "NROM", 1 => "MMC1", 2 => "UxROM", 3 => "CNROM", 4 => "MMC3", 7 => "AxROM"];
	static final MIRROR = ["single-screen A", "single-screen B", "vertical", "horizontal"];
	static final DUTY_PCT = ["12.5%", "25%", "50%", "75% (25% inv)"];
	static final BTN = ["A", "B", "Se", "St", "Up", "Dn", "Lf", "Rt"];
	public var nes:Nes;
	public var paused = false;
	public var termLive = true;
	public var boxes = true;
	public var bottomView = 0;
	public var ramPage = 0;
	public var fps = 60.0;
	public var emuMs = 0.0;
	public var uptime = 0.0;

	var cache:Array<Array<String>> = [null, null, null, null, null];
	var hudKey:String = null;
	public function new(nes:Nes) {
		this.nes = nes;
	}

	static inline function hx(v:Int, n:Int):String
		return StringTools.hex(v, n);
	static function rep(ch:String, n:Int):String {
		var b = new StringBuf();
		for (i in 0...(n < 0 ? 0 : n))
			b.add(ch);
		return b.toString();
	}
	static function pad(s:String, n:Int):String
		return s + rep(" ", n - Canvas.visLen(s));
	static function fx(f:Float, d:Int):String {
		var m = Math.pow(10, d);
		var neg = f < 0;
		if (neg)
			f = -f;
		var n = Math.round(f * m);
		var ip = Math.floor(n / m);
		var fp = Math.round(n - ip * m);
		var fs = Std.string(fp);
		while (fs.length < d)
			fs = "0" + fs;
		return (neg ? "-" : "") + ip + (d > 0 ? "." + fs : "");
	}
	static function big(f:Float):String {
		if (f < 1e9)
			return Std.string(Math.floor(f));
		if (f < 1e12)
			return fx(f / 1e6, 1) + "M";
		return fx(f / 1e9, 1) + "G";
	}
	static function yn(b:Bool):String
		return b ? G + "yes" : D + "no ";
	static function onoff(b:Bool):String
		return b ? G + "ON " : R + "off";

	static function hdr(name:String, extra:String = ""):String {
		var s = H + name + (extra != "" ? W + " " + extra : "");
		return s + " " + D + rep("-", 61 - Canvas.visLen(s));
	}

	public static function disasm(nes:Nes, pc:Int):{s:String, len:Int} {
		var op = nes.peek(pc);
		var b1 = nes.peek(pc + 1);
		var b2 = nes.peek(pc + 2);
		var abs = (b2 << 8) | b1;
		if (op == 0x20)
			return {s: "JSR $" + hx(abs, 4), len: 3};
		var im = IMPL.get(op);
		if (im != null)
			return {s: im, len: 1};
		if ((op & 0x1F) == 0x10) {
			var off = b1 >= 128 ? b1 - 256 : b1;
			return {s: BRANCH[op >> 5] + " $" + hx((pc + 2 + off) & 0xFFFF, 4), len: 2};
		}
		var aaa = op >> 5;
		var bbb = (op >> 2) & 7;
		var mode = -1;
		var name = "???";
		switch (op & 3) {
			case 1:
				name = NAMES1[aaa];
				mode = MODES1[bbb];
				if (aaa == 4 && bbb == 2)
					mode = -1;
			case 2:
				name = NAMES2[aaa];
				switch (bbb) {
					case 0:
						if (aaa == 5)
							mode = 0;
					case 1:
						mode = 1;
					case 2:
						if (aaa < 4)
							mode = 10;
					case 3:
						mode = 4;
					case 5:
						mode = (aaa == 4 || aaa == 5) ? 3 : 2;
					case 7:
						if (aaa == 5)
							mode = 6;
						else if (aaa != 4)
							mode = 5;
					default:
				}
			case 0:
				name = NAMES0[aaa];
				switch (bbb) {
					case 0:
						if (aaa >= 5)
							mode = 0;
					case 1:
						if (aaa == 1 || aaa >= 4)
							mode = 1;
					case 3:
						if (aaa >= 1)
							mode = aaa == 3 ? 9 : 4;
					case 5:
						if (aaa == 4 || aaa == 5)
							mode = 2;
					case 7:
						if (aaa == 5)
							mode = 5;
					default:
				}
			default:
		}
		if (mode < 0)
			return {s: "???", len: 1};
		var arg = switch (mode) {
			case 0: "#$" + hx(b1, 2);
			case 1: "$" + hx(b1, 2);
			case 2: "$" + hx(b1, 2) + ",X";
			case 3: "$" + hx(b1, 2) + ",Y";
			case 4: "$" + hx(abs, 4);
			case 5: "$" + hx(abs, 4) + ",X";
			case 6: "$" + hx(abs, 4) + ",Y";
			case 7: "($" + hx(b1, 2) + ",X)";
			case 8: "($" + hx(b1, 2) + "),Y";
			case 9: "($" + hx(abs, 4) + ")";
			default: "A";
		}
		var len = (mode == 10) ? 1 : (mode >= 4 && mode <= 6) || mode == 9 ? 3 : 2;
		return {s: name + " " + arg, len: len};
	}
	static function flagStr(p:Int):String {
		var names = "nv-bdizc";
		var b = new StringBuf();
		for (i in 0...8) {
			var bit = 7 - i;
			var c = names.charAt(i);
			if (bit == 5) {
				b.add(D + "-");
			} else if ((p & (1 << bit)) != 0)
				b.add(V + c.toUpperCase());
			else
				b.add(D + c);
		}
		return b.toString();
	}
	public function cart():Array<String> {
		var rb = nes.rombuf;
		var mapId = (rb[6] >> 4) | (rb[7] & 0xF0);
		var low = rb[6] >> 4;
		var name = MAPPERS.exists(mapId) ? MAPPERS.get(mapId) : "unsupported";
		var o = [hdr("CARTRIDGE")];
		o.push(W + "mapper " + V + mapId + W + " (" + (MAPPERS.exists(mapId) ? G : R) + name + W + ")"
			+ (mapId != low ? R + "  emulated as " + low : "") + W + "  region " + V + (nes.pal ? "PAL" : "NTSC") + W + "  " + V + fx(nes.cpuHz / 1e6, 3) + W + " MHz");
		o.push(W + "PRG " + V + (rb[4] * 16) + "K" + W + " (" + rb[4] + "x16K)  CHR " + V + (nes.chrIsRam ? "RAM 8K" : (rb[5] * 8) + "K ROM") + W + "  battery "
			+ yn((rb[6] & 2) != 0) + W + " trainer " + yn((rb[6] & 4) != 0));
		var pu = nes.prgbits == 14 ? 16 : 8;
		var slotsP = nes.prgbits == 14 ? 2 : 4;
		var ps = W + "PRG map (" + pu + "K): ";
		for (i in 0...slotsP)
			ps += D + "[" + V + hx(nes.prg[i], 2) + D + "]";
		var cu = nes.chrbits == 12 ? 4 : 1;
		var slotsC = nes.chrbits == 12 ? 2 : 8;
		ps += W + "  CHR (" + cu + "K): ";
		for (i in 0...slotsC)
			ps += D + "[" + V + hx(nes.chr[i], 2) + D + "]";
		o.push(ps);
		o.push(W + "mirroring " + V + MIRROR[nes.mirror & 3] + W + "  hdr flags " + V + hx(rb[6], 2) + " " + hx(rb[7], 2) + W
			+ ((rb[7] & 0x0C) == 8 ? "  NES2.0" : "  iNES"));
		switch (low) {
			case 1:
				o.push(W + "MMC1 ctrl " + V + "$" + hx(nes.mmc1_ctrl, 2) + W + " prg-mode " + V + ((nes.mmc1_ctrl >> 2) & 3) + W + " chr-mode "
					+ V + ((nes.mmc1_ctrl & 16) != 0 ? "4K" : "8K") + W + " shift " + V + (5 - nes.mmc1_bits) + "/5" + W + " chr " + V + nes.chrbank0 + "," + nes.chrbank1
					+ W + " prg " + V + nes.prgbank);
			case 4:
				var s = W + "MMC3 sel " + V + "$" + hx(nes.mmc3_bits, 2) + W + " R0-7:" + V;
				for (i in 0...8)
					s += " " + hx(nes.mmc3_chrprg[i], 2);
				o.push(s);
				o.push(W + "MMC3 irq counter " + V + nes.mmc3_latch + W + "  irq " + onoff(nes.mmc3_irq != 0));
			case 2:
				o.push(W + "UxROM switchable bank " + V + nes.prg[0]);
			case 3:
				o.push(W + "CNROM chr bank " + V + (nes.chr[0] >> 1));
			case 7:
				o.push(W + "AxROM prg 32K bank " + V + (nes.prg[0] >> 1) + W + " nametable " + V + (nes.mirror == 1 ? "B" : "A"));
			default:
				o.push(D + "no bank registers");
		}
		return o;
	}
	public function cpu():Array<String> {
		var pc = (nes.PCH << 8) | nes.PCL;
		var d = disasm(nes, pc);
		var bytes = "";
		for (i in 0...d.len)
			bytes += hx(nes.peek(pc + i), 2) + " ";
		var o = [hdr("CPU 6502")];
		o.push(W + "PC " + V + "$" + hx(pc, 4) + W + "  A " + V + "$" + hx(nes.A, 2) + W + "  X " + V + "$" + hx(nes.X, 2) + W + "  Y " + V + "$" + hx(nes.Y, 2)
			+ W + "  S " + V + "$" + hx(nes.S, 2) + W + "  P " + V + "$" + hx(nes.P, 2) + " " + flagStr(nes.P));
		o.push(W + "next: " + V + pad(bytes, 9) + G + d.s);
		var pend = nes.nmi_irq == 0 ? D + "none" : ((nes.nmi_irq & 4) != 0 ? M + "NMI" : M + "IRQ");
		o.push(W + "cycles " + V + big(nes.totalCycles) + W + "  instr " + V + big(nes.instrCount) + W + "  last frame " + V + nes.lastFrameCycles + W + " cyc");
		o.push(W + "NMI " + V + big(nes.nNmi) + W + "  IRQ " + V + big(nes.nIrq) + W + "  BRK " + V + big(nes.nBrk) + W + "  pending " + pend);
		var st = W + "stack $01" + V + hx((nes.S + 1) & 255, 2) + W + ":" + V;
		for (i in 0...8)
			st += " " + hx(nes.ram[0x100 | ((nes.S + 1 + i) & 255)], 2);
		o.push(st);
		var pd = W + "pad ";
		for (i in 0...8)
			pd += ((nes.pad & (1 << i)) != 0 ? G : D) + BTN[i] + " ";
		o.push(pd);
		return o;
	}
	public function ppu():Array<String> {
		var c = nes.ppuctrl;
		var m = nes.ppumask;
		var st = nes.ppustatus;
		var T = nes.T;
		var V_ = nes.V;
		var sc = nes.scany;
		var phase = sc == nes.preLine ? "pre-render" : (sc < 240 ? "visible" : (sc == 240 ? "post-render" : "vblank"));
		var rendering = (m & 24) != 0;
		var h = (c & 32) != 0 ? 16 : 8;
		var onScreen = 0;
		var onLine = 0;
		for (i in 0...64) {
			var y = nes.oam[i * 4];
			if (y < 0xEF)
				onScreen++;
			var sy = sc - y - 1;
			if (sy >= 0 && sy < h)
				onLine++;
		}
		var nt = (T >> 10) & 3;
		var scrollX = ((T & 31) << 3) | nes.fine_x | ((nt & 1) << 8);
		var scrollY = (((T >> 5) & 31) << 3) | ((T >> 12) & 7) | (((nt >> 1) & 1) << 8);
		var o = [hdr("PPU 2C02")];
		o.push(W + "scanline " + V + sc + W + " (" + D + phase + W + ")  dot " + V + nes.dot + W + "  frame " + V + nes.frameCount + W + "  rendering " + onoff(rendering));
		o.push(W + "CTRL " + V + "$" + hx(c, 2) + W + " NMI " + onoff((c & 128) != 0) + W + " spr " + V + h + "x" + h + W + " BG " + V + ((c & 16) != 0 ? "$1000" : "$0000")
			+ W + " SPR " + V + (h == 16 ? "tile-bit" : ((c & 8) != 0 ? "$1000" : "$0000")) + W + " inc " + V + ((c & 4) != 0 ? "+32" : "+1"));
		o.push(W + "MASK " + V + "$" + hx(m, 2) + W + " BG " + onoff((m & 8) != 0) + W + " SPR " + onoff((m & 16) != 0) + W + " left8 BG/SPR " + yn((m & 2) != 0) + "/"
			+ yn((m & 4) != 0) + W + " gray " + yn((m & 1) != 0));
		o.push(W + "STAT " + V + "$" + hx(st, 2) + W + " vblank " + ((st & 128) != 0 ? G + "1" : D + "0") + W + " sprite0-hit " + ((st & 64) != 0 ? G + "1" : D + "0") + W
			+ " overflow " + ((st & 32) != 0 ? G + "1" : D + "0"));
		o.push(W + "v " + V + "$" + hx(V_, 4) + W + " t " + V + "$" + hx(T, 4) + W + " fineX " + V + nes.fine_x + W + " w " + V + nes.W + W + " read-buf " + V + "$" + hx(nes.ppubuf, 2));
		o.push(W + "scroll(t) X=" + V + scrollX + W + " Y=" + V + scrollY + W + "  v: coarse " + V + (V_ & 31) + "," + ((V_ >> 5) & 31) + W + " fineY " + V + ((V_ >> 12) & 7)
			+ W + " nt " + V + ((V_ >> 10) & 3));
		o.push(W + "OAM sprites on-screen " + V + onScreen + W + "  on this scanline " + V + onLine + (onLine > 8 ? R + " (>8: overflow!)" : "") + W + "  spr0 hits " + V + big(nes.nS0));
		o.push(W + "bus/frame: PPU wr " + V + nes.lPpuWr + W + " rd " + V + nes.lPpuRd + W + "  APU wr " + V + nes.lApuWr + W + "  mapper wr " + V + nes.lMapWr + W + "  OAM-DMA "
			+ V + nes.lOam + W + "  DMC bytes " + V + nes.lDmc);
		return o;
	}
	static function chanState(nes:Nes, i:Int):String {
		var on = (nes.apuEn & (1 << i)) != 0;
		var tag = (nes.muteMask & (1 << i)) != 0 ? M + "MUTE" : (on ? G + "ON  " : R + "off");
		return tag;
	}

	public function apu():Array<String> {
		var n = nes;
		var o = [hdr("APU 2A03", "$4015=" + hx(n.apuStatus(), 2))];
		o.push(W + "frame counter " + V + (n.fcMode != 0 ? "5-step" : "4-step") + W + " pos " + V + n.fcCycle + "/" + n.fcSteps[n.fcMode != 0 ? 4 : 3] + W + "  enable bits " + V
			+ hx(n.apuEn, 2));
		for (i in 0...2) {
			var per = n.pPeriod[i];
			var f = n.cpuHz / (16.0 * (per + 1));
			var why = n.lenCnt[i] == 0 ? "len=0" : (per < 8 ? "period<8" : (n.sweepTarget(i) > 0x7FF ? "sweep-overflow" : ""));
			var vol = n.eConst[i] != 0 ? "const " + n.eVol[i] : "env " + n.eDecay[i] + "/" + n.eVol[i] + (n.lenHalt[i] != 0 ? " loop" : "");
			o.push(W + "PULSE" + (i + 1) + " " + chanState(n, i) + W + " len " + V + n.lenCnt[i] + W + " duty " + V + DUTY_PCT[n.pDuty[i]] + W + " vol " + V + vol);
			o.push(W + "   period " + V + "$" + hx(per, 3) + W + " " + V + fx(f, 1) + W + "Hz " + G + Nes.noteName(f) + W + " seq " + V + n.pSeq[i] + "/8" + W + " sweep "
				+ (n.pSwEn[i] != 0 ? G + "on" : D + "off") + W + " /" + n.pSwPeriod[i] + " " + (n.pNeg[i] != 0 ? "-" : "+") + n.pShift[i] + (why != "" ? R + " [" + why + "]" : ""));
		}
		var tf = n.cpuHz / (32.0 * (n.tPeriod + 1));
		var tact = n.lenCnt[2] > 0 && n.tLinear > 0;
		o.push(W + "TRI    " + chanState(n, 2) + W + " len " + V + n.lenCnt[2] + W + " linear " + V + n.tLinear + "/" + n.tLinearReload + W + " control " + yn(n.lenHalt[2] != 0)
			+ W + " running " + yn(tact));
		o.push(W + "   period " + V + "$" + hx(n.tPeriod, 3) + W + " " + V + fx(tf, 1) + W + "Hz " + G + Nes.noteName(tf) + W + " step " + V + n.tStep + "/32" + W + " out "
			+ V + fx(n.lvT, 2) + (n.tPeriod < 2 ? R + " [ultrasonic]" : ""));
		var np = n.noiseTab[n.nIdx];
		o.push(W + "NOISE  " + chanState(n, 3) + W + " len " + V + n.lenCnt[3] + W + " vol " + V + (n.eConst[3] != 0 ? "const " + n.eVol[3] : "env " + n.eDecay[3] + "/" + n.eVol[3])
			+ W + " mode " + V + (n.nMode != 0 ? "short(93)" : "long(32767)"));
		o.push(W + "   rate " + V + n.nIdx + W + " period " + V + np + W + " cyc = " + V + fx(n.cpuHz / np / 1000.0, 2) + W + " kHz  lfsr " + V + "$" + hx(n.nLfsr, 4));
		o.push(W + "DMC    " + chanState(n, 4) + W + " rate " + V + n.dRate + W + " (" + V + fx(n.cpuHz / n.dmcTab[n.dRate] / 1000.0, 1) + W + " kbit/s) loop " + yn(n.dLoop != 0) + W
			+ " out " + V + n.dOut);
		o.push(W + "   addr " + V + "$" + hx(n.dAddr, 4) + W + " len " + V + n.dLen + W + " remain " + V + n.dRemain + W + " cur " + V + "$" + hx(n.dCur, 4) + W + " buf-full "
			+ yn(n.dBufFull) + W + " silence " + yn(n.dSilence));
		var p = n.lvP0 + n.lvP1;
		o.push(W + "mixer (nesdev non-linear): pulse-sum " + V + fx(p, 2) + W + "  out " + V + fx(n.lvMix, 4));
		o.push(W + "audio mode " + (n.perfectAudio ? G + "PERFECT" : Canvas.V + "authentic") + W + "  ring buffer " + V + n.aCount + "/" + Nes.AUDIO_SIZE + W + "  underruns " + (n.underruns > 0 ? R : G)
			+ n.underruns + W + " overruns " + (n.overruns > 0 ? R : G) + n.overruns);
		return o;
	}
	public function menu():Array<String> {
		var n = nes;
		var chn = ["pulse 1", "pulse 2", "triangle", "noise", "DMC"];
		var o = [hdr("DEBUG MENU", "(F3 closes)")];
		o.push(V + "[1] " + W + pad("PERFECT SOUND CHIP", 24) + onoff(n.perfectAudio));
		o.push(D + "    linear triangle, 8x oversample + 256-tap FIR (20kHz),");
		o.push(D + "    declicked envelopes, drift-free resampler, no filter droop");
		for (i in 0...5)
			o.push(V + "[" + (i + 2) + "] " + W + pad("mute " + chn[i], 24) + ((n.muteMask & (1 << i)) != 0 ? M + "MUTED" : D + "audible"));
		o.push(V + "[7] " + W + pad("live terminal log", 24) + onoff(termLive));
		o.push(V + "[8] " + W + pad("sprite boxes on screen", 24) + onoff(boxes));
		o.push(V + "[9] " + W + pad("bottom-left view", 24) + V + (bottomView == 0 ? "CPU trace" : "RAM page " + ramPage));
		o.push(V + "[P] " + W + pad("pause emulation", 24) + onoff(paused) + V + "  [N]" + W + " step 1 frame");
		o.push(V + "[D] " + W + "dump full snapshot to terminal" + V + "  [PgUp/PgDn]" + W + " RAM page");
		return o;
	}
	public function traceLines(n:Int):Array<String> {
		var o = [hdr("CPU TRACE", "last " + n + " instructions, newest last")];
		var cnt = nes.trCount < n ? nes.trCount : n;
		for (k in 0...cnt) {
			var idx = (nes.trW - cnt + k + Nes.TRACE_N * 2) & (Nes.TRACE_N - 1);
			var pc = nes.trPC[idx];
			var reg = nes.trReg[idx];
			var d = disasm(nes, pc);
			var bytes = "";
			for (i in 0...d.len)
				bytes += hx(nes.peek(pc + i), 2) + " ";
			o.push(V + hx(pc, 4) + " " + D + pad(bytes, 9) + G + pad(d.s, 13) + W + "A:" + V + hx(reg & 255, 2) + W + " X:" + V + hx((reg >> 8) & 255, 2) + W + " Y:" + V
				+ hx((reg >> 16) & 255, 2) + W + " S:" + V + hx(nes.trS[idx], 2) + " " + flagStr((reg >> 24) & 255));
		}
		if (cnt == 0)
			o.push(D + "(nothing traced yet)");
		return o;
	}
	public function ram(page:Int):Array<String> {
		var o = [hdr("RAM $" + hx(page, 2) + "00-$" + hx(page, 2) + "FF", page == 0 ? "zero page" : (page == 1 ? "stack" : ""))];
		for (r in 0...16) {
			var s = V + hx((page << 8) | (r << 4), 4) + W + ":";
			for (c in 0...16) {
				var b = nes.ram[(page << 8) | (r << 4) | c];
				s += (b == 0 ? D : W) + " " + hx(b, 2);
			}
			o.push(s);
		}
		return o;
	}
	public function events(n:Int):Array<String> {
		var o = [hdr("EVENT LOG", "total " + nes.evSeq)];
		var cnt = nes.evSeq < n ? nes.evSeq : n;
		for (k in 0...cnt)
			o.push(W + nes.evBuf[(nes.evSeq - cnt + k) & (Nes.EV_N - 1)]);
		return o;
	}
	public function paletteLines():Array<String> {
		var o = [hdr("PALETTE RAM $3F00-$3F1F")];
		var s = W + "BG  ";
		for (i in 0...16)
			s += V + hx(nes.palette_ram[i] & 63, 2) + ((i & 3) == 3 ? "  " : " ");
		o.push(s);
		s = W + "SPR ";
		for (i in 16...32)
			s += V + hx(nes.palette_ram[i] & 63, 2) + ((i & 3) == 3 ? "  " : " ");
		o.push(s);
		return o;
	}
	public function oamLines(max:Int):Array<String> {
		var o = [hdr("OAM (sprites on screen)")];
		var h = (nes.ppuctrl & 32) != 0 ? 16 : 8;
		var shown = 0;
		for (i in 0...64) {
			var y = nes.oam[i * 4];
			if (y >= 0xEF)
				continue;
			if (shown++ >= max)
				break;
			var at = nes.oam[i * 4 + 2];
			o.push(V + "#" + pad("" + i, 2) + W + " x=" + V + pad("" + nes.oam[i * 4 + 3], 3) + W + " y=" + V + pad("" + (y + 1), 3) + W + " tile=" + V + hx(nes.oam[i * 4 + 1], 2) + W + " pal="
				+ V + (at & 3) + W + " " + D + ((at & 32) != 0 ? "behind " : "") + ((at & 64) != 0 ? "flipH " : "") + ((at & 128) != 0 ? "flipV" : ""));
		}
		return o;
	}
	public function statusLine():String {
		var n = nes;
		var ch = function(i:Int):String {
			var per = n.pPeriod[i];
			return (n.lenCnt[i] > 0 && per >= 8) ? Nes.noteName(n.cpuHz / (16.0 * (per + 1))) : "--";
		};
		var tri = (n.lenCnt[2] > 0 && n.tLinear > 0) ? Nes.noteName(n.cpuHz / (32.0 * (n.tPeriod + 1))) : "--";
		var pc = (n.PCH << 8) | n.PCL;
		return "[status t=" + fx(uptime, 1) + "s f=" + n.frameCount + "] fps=" + fx(fps, 1) + " emu=" + fx(emuMs, 2) + "ms PC=$" + hx(pc, 4) + " A=" + hx(n.A, 2) + " X=" + hx(n.X, 2) + " Y=" + hx(n.Y, 2) + " S="
			+ hx(n.S, 2) + " P=" + hx(n.P, 2) + " | ppu " + n.scany + ":" + n.dot + " ctrl=" + hx(n.ppuctrl, 2) + " mask=" + hx(n.ppumask, 2) + " | P1 " + ch(0) + " P2 " + ch(1) + " TRI " + tri + " NOI "
			+ (n.lenCnt[3] > 0 ? "r" + n.nIdx : "--") + " DMC " + (n.dRemain > 0 ? "on" : "--") + " | audio " + (n.perfectAudio ? "PERFECT" : "authentic") + " buf=" + n.aCount + " ur=" + n.underruns + " or="
			+ n.overruns + (paused ? " PAUSED" : "");
	}
	public function dumpAll():Array<String> {
		var o:Array<String> = [];
		o.push(D + rep("=", 62));
		o.push(H + "NES DEBUG SNAPSHOT" + W + "  frame " + V + nes.frameCount + W + "  t=" + V + fx(uptime, 2) + "s" + W + "  " + V + fx(fps, 1) + W + " fps  emu " + V + fx(emuMs, 2) + W + " ms/frame");
		o.push(D + rep("=", 62));
		return o.concat(cart()).concat(cpu()).concat(ppu()).concat(apu()).concat(paletteLines()).concat(oamLines(64)).concat(menu()).concat(traceLines(Nes.TRACE_N)).concat(ram(0))
			.concat(ram(1)).concat(events(Nes.EV_N));
	}
	static function drawLines(cv:Canvas, x:Int, y:Int, lines:Array<String>, maxCols:Int = 63):Int {
		for (l in lines) {
			if (Canvas.visLen(l) > maxCols) {
				var b = new StringBuf();
				var n = 0;
				for (i in 0...l.length) {
					var ch = l.charCodeAt(i);
					if (ch >= 1 && ch <= 7)
						b.addChar(ch);
					else if (n++ < maxCols)
						b.addChar(ch);
				}
				l = b.toString();
			}
			cv.text(x, y, l);
			y += LINE_H;
		}
		return y;
	}
	static function same(a:Array<String>, b:Array<String>):Bool {
		if (a == null || b == null || a.length != b.length)
			return false;
		for (i in 0...a.length)
			if (a[i] != b[i])
				return false;
		return true;
	}

	function block(cv:Canvas, slot:Int, lines:Array<String>):Bool {
		if (same(lines, cache[slot]))
			return false;
		cache[slot] = lines;
		cv.clear(0);
		drawLines(cv, 0, 0, lines);
		return true;
	}

	public function invalidate():Void {
		for (i in 0...cache.length)
			cache[i] = null;
		hudKey = null;
	}

	public function cartRows():Int
		return cart().length;

	public function renderCart(cv:Canvas):Bool
		return block(cv, 0, cart());

	public function renderRight(cv:Canvas):Bool
		return block(cv, 1, cpu().concat(ppu()).concat(bottomView == 0 ? traceLines(16) : ram(ramPage)));

	public function renderApu(cv:Canvas):Bool
		return block(cv, 2, apu());

	public function renderMenu(cv:Canvas):Bool
		return block(cv, 3, menu());

	public function renderEvents(cv:Canvas):Bool
		return block(cv, 4, events(9));

	public function renderHud(cv:Canvas):Bool {
		var hud = fx(fps, 1) + " fps  emu " + fx(emuMs, 1) + " ms  frame " + nes.frameCount;
		var key = paused ? hud + "|P" : hud;
		if (key == hudKey)
			return false;
		hudKey = key;
		cv.clear(0);
		cv.text(5, 5, "\x06" + hud);
		cv.text(4, 4, "\x03" + hud);
		if (paused) {
			cv.text(5, 17, "\x06PAUSED  (N = step)");
			cv.text(4, 16, "\x05PAUSED  (N = step)");
		}
		return true;
	}

	static function toRgb(nes:Nes, palIdx:Int):Int
		return nes.palRGB[nes.palette_ram[palIdx] & 63];
	function drawScope(cv:Canvas, row:Int, ch:Int, label:String, col:Int, lo:Float, hi:Float):Void {
		var y0 = row * 28;
		var pw = 464;
		var px0 = 40;
		cv.fillRect(0, y0, LIVE_W, 26, 0xFF14141C);
		cv.text(2, y0 + 9, label, 0xFF8C8C96);
		var N = Nes.SCOPE_N;
		var mask = N - 1;
		var base = ch * N;
		var mn = 1e30;
		var mx = -1e30;
		for (k in 0...N) {
			var v = nes.scope[base + ((nes.scopeW + k) & mask)];
			if (v < mn)
				mn = v;
			if (v > mx)
				mx = v;
		}
		var mid = (mn + mx) * 0.5;
		var start = 0;
		if (mx - mn > 1e-6)
			for (k in 1...(N - pw)) {
				var a = nes.scope[base + ((nes.scopeW + k - 1) & mask)];
				var b = nes.scope[base + ((nes.scopeW + k) & mask)];
				if (a < mid && b >= mid) {
					start = k;
					break;
				}
			}
		cv.line(px0, y0 + 13, px0 + pw - 1, y0 + 13, 0xFF2A2A36);
		var span = hi - lo;
		var prevY = -1;
		for (i in 0...pw) {
			var v = nes.scope[base + ((nes.scopeW + start + i) & mask)];
			var t = (v - lo) / span;
			if (t < 0)
				t = 0;
			if (t > 1)
				t = 1;
			var yy = y0 + 24 - Math.round(t * 22);
			if (prevY >= 0)
				cv.line(px0 + i - 1, prevY, px0 + i, yy, col);
			else
				cv.set(px0 + i, yy, col);
			prevY = yy;
		}
	}
	function drawPattern(cv:Canvas, ox:Int, oy:Int, base:Int, cols:Array<Int>):Void {
		for (t in 0...256) {
			var tx = ox + ((t & 15) << 3);
			var ty = oy + ((t >> 4) << 3);
			for (r in 0...8) {
				var lo = nes.chrRead(base + t * 16 + r);
				var hi = nes.chrRead(base + t * 16 + r + 8);
				for (c in 0...8) {
					var sh = 7 - c;
					cv.pix[(ty + r) * cv.w + tx + c] = cols[(((hi >> sh) & 1) << 1) | ((lo >> sh) & 1)];
				}
			}
		}
	}
	public function renderScopes(cv:Canvas):Void {
		drawScope(cv, 0, 0, "P1", 0xFFFFE066, 0, 15);
		drawScope(cv, 1, 1, "P2", 0xFFFFA050, 0, 15);
		drawScope(cv, 2, 2, "TRI", 0xFF5CC8FF, 0, 15);
		drawScope(cv, 3, 3, "NOI", 0xFFD0D0D0, 0, 15);
		drawScope(cv, 4, 4, "DMC", 0xFFFF8CF0, 0, 127);
		drawScope(cv, 5, 5, "MIX", 0xFF6BFF8A, -0.5, 0.5);
		cv.text(LIVE_W - 8 * 22, 2, "\x06scope " + (nes.perfectAudio ? "PERFECT" : "authentic"));
	}

	public function renderLower(cv:Canvas):Void {
		cv.clear(0);
		var y = 172 - SCOPE_H;
		cv.text(0, y, "\x02PALETTE RAM");
		for (i in 0...32) {
			var sx = (i & 15) * 15;
			var sy = y + 11 + (i >> 4) * 14;
			var c = toRgb(nes, i);
			cv.fillRect(sx, sy, 14, 12, c);
			if ((i & 3) == 0)
				cv.fillRect(sx, sy, 1, 12, 0xFF000000);
		}
		cv.text(0, y + 11 + 30, "\x06BG (top) / SPRITE (bottom)");
		drawLines(cv, 0, y + 54, oamLines(7), 30);
		var bg = [toRgb(nes, 0), toRgb(nes, 1), toRgb(nes, 2), toRgb(nes, 3)];
		var sp = [toRgb(nes, 0), toRgb(nes, 17), toRgb(nes, 18), toRgb(nes, 19)];
		var gray = [0xFF000000, 0xFF555555, 0xFFAAAAAA, 0xFFFFFFFF];
		if ((nes.palette_ram[1] & 63) == (nes.palette_ram[0] & 63) && (nes.palette_ram[2] & 63) == (nes.palette_ram[0] & 63))
			bg = gray;
		if ((nes.palette_ram[17] & 63) == (nes.palette_ram[0] & 63) && (nes.palette_ram[18] & 63) == (nes.palette_ram[0] & 63))
			sp = gray;
		cv.text(252, y, "\x02CHR $0000 (BG pal0)     CHR $1000 (SPR pal0)");
		drawPattern(cv, 252, y + 10, 0x0000, bg);
		drawPattern(cv, 380, y + 10, 0x1000, sp);
	}

	public function collectBoxes(out:Vector<Int>):Int {
		var h = (nes.ppuctrl & 32) != 0 ? 16 : 8;
		var sx = PANE_W / 256.0;
		var sy = PANE_H / 224.0;
		var n = 0;
		for (i in 0...64) {
			var y = nes.oam[i * 4];
			if (y >= 0xEF)
				continue;
			var top = y + 1 - 8;
			var o = n * 5;
			out[o] = Math.round(nes.oam[i * 4 + 3] * sx);
			out[o + 1] = Math.round(top * sy);
			out[o + 2] = Math.round(8 * sx);
			out[o + 3] = Math.round(h * sy);
			out[o + 4] = i == 0 ? 1 : 0;
			n++;
		}
		return n;
	}
}
