package;

import haxe.ds.Vector;
import haxe.io.Bytes;

class Nes {
	static inline var ROM_MAX = 1024 * 1024;
	static final PAL16:Array<Int> = [
		25356, 34816, 39011, 30854, 24714, 4107, 106, 2311,
		2468, 2561, 4642, 6592, 20832, 0, 0, 0,
		44373, 49761, 55593, 51341, 43186, 18675, 434, 654,
		4939, 5058, 3074, 19362, 37667, 0, 0, 0,
		~0, ~819, 64497, 64342, 62331, 43932, 23612, 9465,
		1429, 1550, 20075, 36358, 52713, 16904, 0, 0,
		~0, ~328, ~422, ~452, ~482, 58911, 50814, 42620,
		40667, 40729, 48951, 53078, 61238, 44405, 0, 0
	];
	static final MASK:Array<Int> = [128, 64, 1, 2, 1, 0, 0, 1, 4, 0, 0, 4, 0, 0, 64, 0, 8, 0, 0, 8];
	static function mk(n:Int):Vector<Int> {
		var v = new Vector<Int>(n);
		for (i in 0...n)
			v[i] = 0;
		return v;
	}

	public var pad = 0;
	public var frameDone = false;
	public var frame:Vector<Int> = mk(256 * 240);
	var rombuf:Vector<Int> = mk(ROM_MAX);
	var chrBase = 0;
	var chrLen = 8192;
	var chrIsRam = true;
	var prg:Vector<Int> = mk(4);
	var chr:Vector<Int> = mk(8);
	var prgbits = 14;
	var chrbits = 12;
	var vram:Vector<Int> = mk(2048);
	var palette_ram:Vector<Int> = mk(64);
	var ram:Vector<Int> = mk(2048);
	var chrram:Vector<Int> = mk(8192);
	var prgram:Vector<Int> = mk(8192);
	var oam:Vector<Int> = mk(256);
	var palRGB:Vector<Int> = mk(64);
	var A = 0;
	var X = 0;
	var Y = 0;
	var P = 4;
	var S = 0xFD;
	var PCH = 0;
	var PCL = 0;
	var addr_lo = 0;
	var addr_hi = 0;
	var nomem = false;
	var val = 0;
	var opcode = 0;
	var cycles = 0;
	var nmi_irq = 0;
	var ppumask = 0;
	var ppuctrl = 0;
	var ppustatus = 0;
	var ppubuf = 0;
	var W = 0;
	var fine_x = 0;
	var ntb = 0;
	var ptb_lo = 0;
	var scany = 0;
	var T = 0;
	var V = 0;
	var dot = 0;
	var atb = 0;
	var shift_hi = 0;
	var shift_lo = 0;
	var shift_at = 0;
	var tmp = 0;
	var keys = 0;
	var mirror = 0;
	var mmc1_bits = 0;
	var mmc1_data = 0;
	var mmc1_ctrl = 0;
	var mmc3_chrprg:Vector<Int> = mk(8);
	var mmc3_bits = 0;
	var mmc3_irq = 0;
	var mmc3_latch = 0;
	var chrbank0 = 0;
	var chrbank1 = 0;
	var prgbank = 0;
	public var pal = false;
	var lines = 262;
	var preLine = 261;
	var dotAcc = 0;

	public var dbg = false;
	public var frameCount = 0;
	var totalCycles:Float = 0;
	var instrCount:Float = 0;
	var frameCycles = 0;
	var lastFrameCycles = 0;
	var cPpuWr = 0;
	var cPpuRd = 0;
	var cApuWr = 0;
	var cMapWr = 0;
	var cOam = 0;
	var cDmc = 0;
	var lPpuWr = 0;
	var lPpuRd = 0;
	var lApuWr = 0;
	var lMapWr = 0;
	var lOam = 0;
	var lDmc = 0;
	var nNmi:Float = 0;
	var nIrq:Float = 0;
	var nBrk:Float = 0;
	var nS0:Float = 0;
	static inline var TRACE_N = 32;
	var trPC:Vector<Int> = mk(TRACE_N);
	var trReg:Vector<Int> = mk(TRACE_N);
	var trS:Vector<Int> = mk(TRACE_N);
	var trW = 0;
	var trCount = 0;
	static inline var EV_N = 64;
	var evBuf:Array<String> = [for (i in 0...EV_N) ""];
	var evSeq = 0;
	public static inline var SAMPLE_RATE = 44100;
	static inline var AUDIO_SIZE = 8192;
	static inline var AUDIO_MASK = AUDIO_SIZE - 1;
	var audioBuf:Vector<Float> = mkf(AUDIO_SIZE);
	var aw = 0;
	var ar = 0;
	var aCount = 0;
	var cpuHz = 1789773;
	var sampleAcc = 0;
	var hpIn = 0.0;
	var hpOut = 0.0;
	var lpOut = 0.0;
	var underruns = 0;
	var overruns = 0;
	var lastOut = 0.0;
	var rFrac = 0.0;
	public var perfectAudio(default, set):Bool = false;
	public var muteMask = 0;
	static inline var OS_FACTOR = 8;
	static inline var OS_RATE = SAMPLE_RATE * OS_FACTOR;
	static inline var FIR_N = 256;
	static inline var FIR_CUTOFF = 20000.0;
	static inline var AUDIO_TARGET = 2560;
	static inline var SLEW = 15.0 / 450.0;
	var fir:Vector<Float> = null;
	var osBuf:Vector<Float> = mkf(FIR_N * 2);
	var osW = 0;
	var osDecim = 0;
	var osFill = 0;
	var osSum = 0.0;
	var pVolS:Vector<Float> = mkf(2);
	var nVolS = 0.0;
	var tPhase = 0.0;
	var tInc = 1.0;
	var lvP0 = 0.0;
	var lvP1 = 0.0;
	var lvT = 0.0;
	var lvN = 0.0;
	var lvD = 0.0;
	var lvMix = 0.0;
	static inline var SCOPE_N = 512;
	var scope:Vector<Float> = mkf(6 * SCOPE_N);
	var scopeW = 0;
	static final LENGTH:Array<Int> = [
		10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14,
		12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30
	];
	static final DUTY:Array<Int> = [
		0, 1, 0, 0, 0, 0, 0, 0,
		0, 1, 1, 0, 0, 0, 0, 0,
		0, 1, 1, 1, 1, 0, 0, 0,
		1, 0, 0, 1, 1, 1, 1, 1
	];
	static final TRI:Array<Int> = [
		15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
		0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
	];
	static final NOISE_NTSC:Array<Int> = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068];
	static final NOISE_PAL:Array<Int> = [4, 8, 14, 30, 60, 88, 118, 148, 188, 236, 354, 472, 708, 944, 1890, 3778];
	static final DMC_NTSC:Array<Int> = [428, 380, 340, 320, 286, 254, 226, 214, 190, 160, 142, 128, 106, 84, 72, 54];
	static final DMC_PAL:Array<Int> = [398, 354, 316, 298, 276, 236, 210, 198, 176, 148, 132, 118, 98, 78, 66, 50];
	var apuEn = 0;
	var apuOdd = false;
	var fcMode = 0;
	var fcCycle = 0;
	var fcSteps:Array<Int> = [7457, 14913, 22371, 29829, 37281];
	var noiseTab:Array<Int> = NOISE_NTSC;
	var dmcTab:Array<Int> = DMC_NTSC;
	var lenCnt:Vector<Int> = mk(4);
	var lenHalt:Vector<Int> = mk(4);
	var eConst:Vector<Int> = mk(4);
	var eVol:Vector<Int> = mk(4);
	var eStart:Vector<Int> = mk(4);
	var eDiv:Vector<Int> = mk(4);
	var eDecay:Vector<Int> = mk(4);
	var pDuty:Vector<Int> = mk(2);
	var pPeriod:Vector<Int> = mk(2);
	var pTimer:Vector<Int> = mk(2);
	var pSeq:Vector<Int> = mk(2);
	var pSwEn:Vector<Int> = mk(2);
	var pSwPeriod:Vector<Int> = mk(2);
	var pNeg:Vector<Int> = mk(2);
	var pShift:Vector<Int> = mk(2);
	var pSwDiv:Vector<Int> = mk(2);
	var pSwReload:Vector<Int> = mk(2);
	var tPeriod = 0;
	var tTimer = 0;
	var tStep = 0;
	var tLinear = 0;
	var tLinearReload = 0;
	var tReloadFlag = 0;
	var nMode = 0;
	var nIdx = 0;
	var nTimer = 0;
	var nLfsr = 1;
	var dLoop = 0;
	var dRate = 0;
	var dTimer = 0;
	var dOut = 0;
	var dAddr = 0xC000;
	var dLen = 1;
	var dCur = 0xC000;
	var dRemain = 0;
	var dShift = 0;
	var dBits = 8;
	var dBuf = 0;
	var dBufFull = false;
	var dSilence = true;
	static function mkf(n:Int):Vector<Float> {
		var v = new Vector<Float>(n);
		for (i in 0...n)
			v[i] = 0.0;
		return v;
	}

	public function new() {
		for (i in 0...64) {
			var v = PAL16[i] & 0xFFFF;
			var r = v & 31;
			var g = (v >> 5) & 63;
			var b = (v >> 11) & 31;
			palRGB[i] = 0xFF000000 | (((r << 3) | (r >> 2)) << 16) | (((g << 2) | (g >> 4)) << 8) | ((b << 3) | (b >> 2));
		}
	}
	public function load(data:Bytes):Void {
		lines = pal ? 312 : 262;
		preLine = lines - 1;
		cpuHz = pal ? 1662607 : 1789773;
		fcSteps = pal ? [8313, 16627, 24939, 33253, 41565] : [7457, 14913, 22371, 29829, 37281];
		noiseTab = pal ? NOISE_PAL : NOISE_NTSC;
		dmcTab = pal ? DMC_PAL : DMC_NTSC;
		var n = data.length < ROM_MAX ? data.length : ROM_MAX;
		for (i in 0...n)
			rombuf[i] = data.get(i);
		prg[1] = (rombuf[4] - 1) & 255;

		if (rombuf[5] != 0) {
			chrIsRam = false;
			chrLen = rombuf[5] * 8192;
			chrBase = 16 + (rombuf[4] << 14);
			chr[1] = (rombuf[5] * 2 - 1) & 255;
		} else {
			chrIsRam = true;
			chr[1] = 1;
		}
		mirror = 3 - (rombuf[6] & 1);
		if ((rombuf[6] >> 4) == 4) {
			mem(0, 128, 0, true);
			prgbits--;
			chrbits -= 2;
		}
		PCL = mem(0xFC, 0xFF, 0, false);
		PCH = mem(0xFD, 0xFF, 0, false);
	}
	public function runFrame():Void {
		frameDone = false;
		while (!frameDone)
			step();
	}

	public function peek(a:Int):Int {
		a &= 0xFFFF;
		var h = a >> 12;
		if (h < 2)
			return ram[a & 0x7FF];
		if (h < 6)
			return 0xFF;
		if (h < 8)
			return prgram[a & 8191];
		var idx = ((prg[(h - 8) >> (prgbits - 12)] & ((rombuf[4] << (14 - prgbits)) - 1)) << prgbits) | (a & ((1 << prgbits) - 1));
		var p = idx + 16;
		return p < ROM_MAX ? rombuf[p] : 0;
	}
	static inline function h2(v:Int):String
		return StringTools.hex(v & 255, 2);
	static inline function h4(v:Int):String
		return StringTools.hex(v & 0xFFFF, 4);

	function dbgEvent(msg:String):Void {
		evBuf[evSeq & (EV_N - 1)] = "f" + frameCount + " " + scany + ":" + dot + " " + msg;
		evSeq++;
	}
	function dbgTrace():Void {
		trPC[trW] = (PCH << 8) | PCL;
		trReg[trW] = A | (X << 8) | (Y << 16) | (P << 24);
		trS[trW] = S;
		trW = (trW + 1) & (TRACE_N - 1);
		if (trCount < TRACE_N)
			trCount++;
	}
	function dbgPpuWrite(reg:Int, v:Int):Void {
		switch (reg) {
			case 0:
				if (v != ppuctrl)
					dbgEvent("PPUCTRL $" + h2(v) + " NMI:" + ((v & 128) != 0 ? "on" : "off") + " BG:$" + ((v & 16) != 0 ? "1000" : "0000") + " SPR:"
						+ ((v & 32) != 0 ? "8x16" : ((v & 8) != 0 ? "$1000" : "$0000")) + " NT:" + (v & 3));
			case 1:
				if (v != ppumask)
					dbgEvent("PPUMASK $" + h2(v) + " BG:" + ((v & 8) != 0 ? "on" : "off") + " SPR:" + ((v & 16) != 0 ? "on" : "off"));
			default:
		}
	}
	function dbgApuWrite(r:Int, v:Int):Void {
		switch (r) {
			case 0x03, 0x07:
				var i = r >> 2;
				dbgEvent("P" + (i + 1) + " trigger period=$" + StringTools.hex(pPeriod[i], 3) + " " + noteName(cpuHz / (16.0 * (pPeriod[i] + 1))) + " duty="
					+ pDuty[i] + " vol=" + (eConst[i] != 0 ? "" + eVol[i] : "env" + eVol[i]));
			case 0x0B:
				dbgEvent("TRI trigger period=$" + StringTools.hex(tPeriod, 3) + " " + noteName(cpuHz / (32.0 * (tPeriod + 1))) + " linear=" + tLinearReload);
			case 0x0F:
				dbgEvent("NOISE trigger rate=" + nIdx + " mode=" + (nMode != 0 ? "short" : "long") + " vol=" + (eConst[3] != 0 ? "" + eVol[3] : "env" + eVol[3]));
			case 0x15:
				dbgEvent("$4015 <- $" + h2(v) + " [" + ((v & 1) != 0 ? "P1 " : "") + ((v & 2) != 0 ? "P2 " : "") + ((v & 4) != 0 ? "TRI " : "")
					+ ((v & 8) != 0 ? "NOI " : "") + ((v & 16) != 0 ? "DMC " : "") + "]");
			case 0x17:
				dbgEvent("$4017 <- $" + h2(v) + " frame counter " + (fcMode != 0 ? "5-step" : "4-step"));
			case 0x11:
				dbgEvent("DMC direct load $" + h2(v & 0x7F));
			default:
		}
	}
	static final NOTE_NAMES:Array<String> = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
	static final LN2 = Math.log(2.0);

	public static function noteName(f:Float):String {
		if (f < 8.0 || f > 30000.0)
			return "--";
		var m = 69.0 + 12.0 * Math.log(f / 440.0) / LN2;
		var n = Math.round(m);
		var cents = Math.round((m - n) * 100.0);
		var ni = ((n % 12) + 12) % 12;
		return NOTE_NAMES[ni] + (Math.floor(n / 12) - 1) + (cents >= 0 ? " +" : " ") + cents + "c";
	}
	function set_perfectAudio(v:Bool):Bool {
		if (v && fir == null)
			buildFir();
		if (v != perfectAudio) {
			hpIn = hpOut = lpOut = 0.0;
			osFill = 0;
			osSum = 0.0;
			osDecim = 0;
			for (i in 0...FIR_N * 2)
				osBuf[i] = 0.0;
			rFrac = 0.0;
			if (dbg)
				dbgEvent("AUDIO mode -> " + (v ? "PERFECT" : "authentic"));
		}
		return perfectAudio = v;
	}
	function buildFir():Void {
		fir = mkf(FIR_N);
		var fc = FIR_CUTOFF / OS_RATE;
		var m = (FIR_N - 1) * 0.5;
		var sum = 0.0;
		for (k in 0...FIR_N) {
			var x = k - m;
			var sinc = x == 0 ? 2.0 * fc : Math.sin(2.0 * Math.PI * fc * x) / (Math.PI * x);
			var w = 0.42 - 0.5 * Math.cos(2.0 * Math.PI * k / (FIR_N - 1)) + 0.08 * Math.cos(4.0 * Math.PI * k / (FIR_N - 1));
			fir[k] = sinc * w;
			sum += fir[k];
		}
		for (k in 0...FIR_N)
			fir[k] /= sum;
	}
	inline function chrIdx(a:Int):Int {
		return (chr[a >> chrbits] << chrbits) | (a & ((1 << chrbits) - 1));
	}
	function chrRead(a:Int):Int {
		var i = chrIdx(a);
		if (chrIsRam)
			return chrram[i & 8191];
		if (i >= chrLen)
			i %= chrLen;
		var p = chrBase + i;
		return p < ROM_MAX ? rombuf[p] : 0;
	}
	inline function chrWrite(a:Int, v:Int):Void {
		chrram[chrIdx(a) & 8191] = v & 255;
	}
	inline function ntIndex(a:Int):Int {
		return mirror == 0 ? (a & 1023) : mirror == 1 ? ((a & 1023) + 1024) : mirror == 2 ? (a & 2047) : (((a >> 1) & 1024) | (a & 1023));
	}
	function mem(lo:Int, hi:Int, val:Int, write:Bool):Int {
		lo &= 255;
		hi &= 255;
		val &= 255;
		var addr = (hi << 8) | lo;
		hi >>= 4;
		switch (hi) {
			case 0, 1:
				if (write) {
					ram[addr & 0x7FF] = val;
					return val;
				}
				return ram[addr & 0x7FF];
			case 2, 3:
				lo &= 7;
				if (write) {
					cPpuWr++;
					if (dbg)
						dbgPpuWrite(lo, val);
				} else
					cPpuRd++;
				if (lo == 7) {
					tmp = ppubuf;
					if (V < 8192) {
						if (write) {
							if (chrIsRam)
								chrWrite(V, val);
							else
								tmp = val;
						} else
							ppubuf = chrRead(V);
					} else if (V < 16128) {
						var p = ntIndex(V);
						if (write)
							vram[p] = val;
						else
							ppubuf = vram[p];
					} else {
						var p = (((V & 19) == 16) ? (V ^ 16) : V) & 31;
						if (write)
							palette_ram[p] = val;
						else
							ppubuf = palette_ram[p];
					}
					V += (ppuctrl & 4) != 0 ? 32 : 1;
					V %= 16384;
					return tmp;
				}
				if (write) {
					switch (lo) {
						case 0:
							ppuctrl = val;
							T = (T & 0xf3ff) | ((val & 3) << 10);
						case 1:
							ppumask = val;
						case 5:
							W ^= 1;
							if (W != 0) {
								fine_x = val & 7;
								T = (T & 0xFFE0) | (val >> 3);
							} else
								T = (T & 0x8c1f) | ((val & 7) << 12) | ((val << 2) & 0x3e0);
						case 6:
							W ^= 1;
							if (W != 0)
								T = (T & 0xff) | ((val & 63) << 8);
							else {
								T = (T & 0xff00) | val;
								V = T;
							}
						default:
					}
				}
				if (lo == 2) {
					tmp = ppustatus & 0xe0;
					ppustatus &= 0x7f;
					W = 0;
					return tmp;
				}
				return 0xFF;
			case 4:
				if (write && lo == 20) {
					cOam++;
					if (dbg)
						dbgEvent("OAM DMA from $" + h2(val) + "00");
					var i = 256;
					while (i-- > 0)
						oam[i] = mem(i, val, 0, false);
				}
				if (addr < 0x4018) {
					if (write && lo != 20 && lo != 22)
						apuWrite(lo, val);
					else if (!write && lo == 21)
						return apuStatus();
				}
				tmp = pad;
				if (lo == 22) {
					if (write)
						keys = tmp;
					else {
						tmp = keys & 1;
						keys >>= 1;
						return tmp;
					}
				}
				return 0;
			case 6, 7:
				addr &= 8191;
				if (write) {
					prgram[addr] = val;
					return val;
				}
				return prgram[addr];
			default:
				if (hi < 8)
					return 0xFF;
				if (write) {
					cMapWr++;
					if (dbg)
						dbgEvent("MAPPER write $" + h4(addr) + " <- $" + h2(val));
					switch (rombuf[6] >> 4) {
						case 7:
							mirror = (val >> 4) == 0 ? 1 : 0;
							prg[0] = ((val & 7) * 2) & 255;
							prg[1] = (prg[0] + 1) & 255;
						case 4:
							var addr1 = addr & 1;
							switch (hi >> 1) {
								case 4:
									if (addr1 != 0)
										mmc3_chrprg[mmc3_bits & 7] = val;
									else
										mmc3_bits = val;
									var t = (mmc3_bits >> 5) & 4;
									for (i in 0...4) {
										chr[i + t] = ((mmc3_chrprg[i >> 1] & ((i & 1) == 0 ? ~1 : ~0)) | (i & 1)) & 255;
										chr[4 + i - t] = mmc3_chrprg[2 + i];
									}
									t = (mmc3_bits >> 5) & 2;
									prg[t] = mmc3_chrprg[6];
									prg[1] = mmc3_chrprg[7];
									prg[3] = (rombuf[4] * 2 - 1) & 255;
									prg[2 - t] = (prg[3] - 1) & 255;
								case 5:
									if (addr1 == 0)
										mirror = 2 + (val & 1);
								case 6:
									if (addr1 == 0)
										mmc3_latch = val;
								case 7:
									mmc3_irq = addr1;
								default:
							}
						case 3:
							chr[0] = ((val & 3) * 2) & 255;
							chr[1] = (chr[0] + 1) & 255;
						case 2:
							prg[0] = val & 31;

						case 1:
							if ((val & 0x80) != 0) {
								mmc1_bits = 5;
								mmc1_data = 0;
								mmc1_ctrl |= 12;
							} else {
								mmc1_data = ((mmc1_data >> 1) | ((val << 4) & 16)) & 255;
								mmc1_bits = (mmc1_bits - 1) & 255;
								if (mmc1_bits == 0) {
									mmc1_bits = 5;
									var t = addr >> 13;
									if (t == 4) {
										mirror = mmc1_data & 3;
										mmc1_ctrl = mmc1_data;
									} else if (t == 5)
										chrbank0 = mmc1_data;
									else if (t == 6)
										chrbank1 = mmc1_data;
									else
										prgbank = mmc1_data;
									var fourK = (mmc1_ctrl & 16) != 0;
									chr[0] = fourK ? chrbank0 : (chrbank0 & ~1);
									chr[1] = fourK ? chrbank1 : (chrbank0 | 1);
									t = (((mmc1_ctrl >> 2) & 3) - 2) & 255;
									prg[0] = t == 0 ? 0 : t == 1 ? prgbank : (prgbank & ~1);
									prg[1] = t == 0 ? prgbank : t == 1 ? ((rombuf[4] - 1) & 255) : (prgbank | 1);
								}
							}
						default:
					}
				}
				var idx = ((prg[(hi - 8) >> (prgbits - 12)] & ((rombuf[4] << (14 - prgbits)) - 1)) << prgbits) | (addr & ((1 << prgbits) - 1));
				var p = idx + 16;
				return p < ROM_MAX ? rombuf[p] : 0;
		}
	}
	inline function push(x:Int):Void {
		mem(S, 1, x, true);
		S = (S - 1) & 255;
	}
	inline function pull():Int {
		S = (S + 1) & 255;
		return mem(S, 1, 0, false);
	}
	inline function incPc():Void {
		PCL = (PCL + 1) & 255;
		if (PCL == 0)
			PCH = (PCH + 1) & 255;
	}
	function readPc():Int {
		val = mem(PCL, PCH, 0, false);
		incPc();
		return val;
	}
	inline function setNz(v:Int):Void {
		v &= 255;
		P = (P & 125) | (v & 128) | (v == 0 ? 2 : 0);
	}

	function interrupt():Void {
		if ((nmi_irq & 4) != 0)
			nNmi++;
		else if (nmi_irq != 0)
			nIrq++;
		else
			nBrk++;
		if (dbg)
			dbgEvent(((nmi_irq & 4) != 0 ? "NMI" : nmi_irq != 0 ? "IRQ" : "BRK") + " taken at $" + h4((PCH << 8) | PCL) + " S=$" + h2(S));
		push(PCH);
		push(PCL);
		push(P | 32);
		var veclo = 0xFFFE - (nmi_irq & 4);
		PCL = mem(veclo & 255, 0xFF, 0, false);
		PCH = mem((veclo + 1) & 255, 0xFF, 0, false);
		nmi_irq = 0;
		cycles++;
	}
	function adc():Void {
		var sum = A + val + (P & 1);
		P = (P & ~65) | (sum > 255 ? 1 : 0) | (((A ^ sum) & (val ^ sum) & 128) >> 1);
		A = sum & 255;
		setNz(A);
	}

	function memop(res:Int):Void {
		res &= 255;
		setNz(res);
		if (nomem)
			A = res;
		else {
			cycles += 2;
			mem(addr_lo, addr_hi, res, true);
		}
	}
	function addXY(lo5:Int):Void {
		val = (lo5 < 28 || opcode == 190) ? Y : X;
		var c = (addr_lo + val > 255) ? 1 : 0;
		addr_hi = (addr_hi + c) & 255;
		addr_lo = (addr_lo + val) & 255;
		cycles += ((((opcode & 224) == 128) || ((opcode & 15) == 14 && opcode != 190)) ? 1 : 0) | c;
	}
	function accessAndExec():Void {
		cycles += 2;
		if (opcode != 76 && (opcode & 224) != 128)
			val = mem(addr_lo, addr_hi, 0, false);
		alu();
	}
	function alu():Void {
		switch (opcode & 227) {
			case 1:
				A |= val;
				setNz(A);
			case 33:
				A &= val;
				setNz(A);
			case 65:
				A ^= val;
				setNz(A);
			case 225:
				val = (~val) & 255;
				adc();
			case 97:
				adc();
			case 34:
				var r = (P & 1) | (val << 1);
				P = (P & ~1) | (val >> 7);
				memop(r);
			case 2:
				var r = val << 1;
				P = (P & ~1) | (val >> 7);
				memop(r);
			case 98:
				var r = ((P << 7) & 255) | (val >> 1);
				P = (P & ~1) | (val & 1);
				memop(r);
			case 66:
				var r = val >> 1;
				P = (P & ~1) | (val & 1);
				memop(r);
			case 194:
				memop(val - 1);
			case 226:
				memop(val + 1);
			case 32:
				P = (P & 61) | (val & 192) | ((A & val) == 0 ? 2 : 0);
			case 64:
				PCL = addr_lo;
				PCH = addr_hi;
				cycles--;
			case 96:
				PCL = val;
				PCH = mem((addr_lo + 1) & 255, addr_hi, 0, false);
				cycles++;
			default:
				var hi3 = opcode >> 5;
				var sel = ((opcode & 3) == 2 || hi3 == 7) ? 0 : ((opcode & 3) == 1 ? 1 : 2);
				var r = sel == 0 ? X : sel == 1 ? A : Y;
				if (hi3 == 4) {
					mem(addr_lo, addr_hi, r, true);
				} else if (hi3 != 5) {
					P = (P & ~1) | (r >= val ? 1 : 0);
					setNz(r - val);
				} else {
					if (sel == 0)
						X = val;
					else if (sel == 1)
						A = val;
					else
						Y = val;
					setNz(val);
				}
		}
	}
	function step():Void {
		cycles = 0;
		nomem = false;
		if (nmi_irq != 0) {
			interrupt();
			cycles += 4;
		} else {
			if (dbg)
				dbgTrace();
			opcode = readPc();
			var lo5 = opcode & 31;
			switch (lo5) {
				case 0:
					if ((opcode & 0x80) != 0) {
						readPc();
						nomem = true;
						alu();
					} else {
						switch (opcode >> 5) {
							case 0:
								incPc();
								interrupt();
							case 1:
								var r = readPc();
								push(PCH);
								push(PCL);
								PCH = readPc();
								PCL = r;
							case 2:
								P = pull() & ~32;
								PCL = pull();
								PCH = pull();
							case 3:
								PCL = pull();
								PCH = pull();
								incPc();
							default:
						}
						cycles += 4;
					}
				case 16:
					readPc();
					if ((((P & MASK[opcode >> 6]) == 0) ? 1 : 0) ^ ((opcode >> 5) & 1) != 0) {
						var sv = val >= 128 ? val - 256 : val;
						var c = (PCL + sv) >> 8;
						PCH = (PCH + c) & 255;
						PCL = (PCL + val) & 255;
						cycles += c != 0 ? 2 : 1;
					}
				case 8, 24:
					var op4 = opcode >> 4;
					switch (op4) {
						case 0:
							push(P | 48);
							cycles++;
						case 2:
							P = pull() & ~16;
							cycles += 2;
						case 4:
							push(A);
							cycles++;
						case 6:
							A = pull();
							setNz(A);
							cycles += 2;
						case 8:
							Y = (Y - 1) & 255;
							setNz(Y);
						case 9:
							A = Y;
							setNz(A);
						case 10:
							Y = A;
							setNz(Y);
						case 12:
							Y = (Y + 1) & 255;
							setNz(Y);
						case 14:
							X = (X + 1) & 255;
							setNz(X);
						default:
							P = (P & ~MASK[op4 + 3]) | MASK[op4 + 4];
					}
				case 10, 26:
					switch (opcode >> 4) {
						case 8:
							A = X;
							setNz(A);
						case 9:
							S = X;
						case 10:
							X = A;
							setNz(X);
						case 11:
							X = S;
							setNz(X);
						case 12:
							X = (X - 1) & 255;
							setNz(X);
						case 14:
						default:
							nomem = true;
							val = A;
							alu();
					}
				case 1:
					readPc();
					val = (val + X) & 255;
					addr_lo = mem(val, 0, 0, false);
					addr_hi = mem((val + 1) & 255, 0, 0, false);
					cycles += 4;
					accessAndExec();
				case 2, 9:
					readPc();
					nomem = true;
					alu();
				case 17:
					addr_lo = mem(readPc(), 0, 0, false);
					addr_hi = mem((val + 1) & 255, 0, 0, false);
					cycles++;
					addXY(lo5);
					accessAndExec();

				case 4, 5, 6, 20, 21, 22:
					addr_lo = readPc();
					var indexed = lo5 > 6;
					if (indexed)
						addr_lo = (addr_lo + (((opcode & 214) == 150) ? Y : X)) & 255;
					addr_hi = 0;
					if (!indexed)
						cycles--;
					accessAndExec();
				case 12, 13, 14, 25, 28, 29, 30:
					addr_lo = readPc();
					addr_hi = readPc();
					if (lo5 >= 25)
						addXY(lo5);
					accessAndExec();

				default:
			}
		}
		var cpuCycles = cycles + 2;
		totalCycles += cpuCycles;
		frameCycles += cpuCycles;
		instrCount++;
		apuRun(cpuCycles);
		var n:Int;
		if (pal) {
			dotAcc += cpuCycles * 16;
			n = Std.int(dotAcc / 5);
			dotAcc -= n * 5;
		} else
			n = cpuCycles * 3;
		while (n-- > 0)
			ppuTick();
	}
	public function popSample():Float {
		if (!perfectAudio) {
			if (aCount == 0) {
				underruns++;
				return 0.0;
			}
			var v = audioBuf[ar];
			ar = (ar + 1) & AUDIO_MASK;
			aCount--;
			lastOut = v;
			return v;
		}
		if (aCount < 2) {
			underruns++;
			rFrac = 0.0;
			lastOut *= 0.98;
			return lastOut;
		}
		var a = audioBuf[ar];
		var b = audioBuf[(ar + 1) & AUDIO_MASK];
		var out = a + (b - a) * rFrac;
		var err = (aCount - AUDIO_TARGET) / AUDIO_TARGET;
		if (err > 1.0)
			err = 1.0;
		else if (err < -1.0)
			err = -1.0;
		rFrac += 1.0 + err * 0.004;
		while (rFrac >= 1.0 && aCount > 1) {
			rFrac -= 1.0;
			ar = (ar + 1) & AUDIO_MASK;
			aCount--;
		}
		lastOut = out;
		return out;
	}
	public function audioAvailable():Int {
		return aCount;
	}
	function apuStatus():Int {
		var s = 0;
		for (i in 0...4)
			if (lenCnt[i] > 0)
				s |= 1 << i;
		if (dRemain > 0)
			s |= 16;
		return s;
	}
	function apuWrite(r:Int, v:Int):Void {
		cApuWr++;
		switch (r) {
			case 0x00, 0x04:
				var i = r >> 2;
				pDuty[i] = v >> 6;
				lenHalt[i] = (v >> 5) & 1;
				eConst[i] = (v >> 4) & 1;
				eVol[i] = v & 15;
			case 0x01, 0x05:
				var i = r >> 2;
				pSwEn[i] = v >> 7;
				pSwPeriod[i] = (v >> 4) & 7;
				pNeg[i] = (v >> 3) & 1;
				pShift[i] = v & 7;
				pSwReload[i] = 1;
			case 0x02, 0x06:
				var i = r >> 2;
				pPeriod[i] = (pPeriod[i] & 0x700) | v;
			case 0x03, 0x07:
				var i = r >> 2;
				pPeriod[i] = (pPeriod[i] & 0xFF) | ((v & 7) << 8);
				if ((apuEn & (1 << i)) != 0)
					lenCnt[i] = LENGTH[v >> 3];
				pSeq[i] = 0;
				eStart[i] = 1;
			case 0x08:
				lenHalt[2] = v >> 7;
				tLinearReload = v & 0x7F;
			case 0x0A:
				tPeriod = (tPeriod & 0x700) | v;
				tInc = 1.0 / (tPeriod + 1);
			case 0x0B:
				tPeriod = (tPeriod & 0xFF) | ((v & 7) << 8);
				tInc = 1.0 / (tPeriod + 1);
				if ((apuEn & 4) != 0)
					lenCnt[2] = LENGTH[v >> 3];
				tReloadFlag = 1;
			case 0x0C:
				lenHalt[3] = (v >> 5) & 1;
				eConst[3] = (v >> 4) & 1;
				eVol[3] = v & 15;
			case 0x0E:
				nMode = v >> 7;
				nIdx = v & 15;
			case 0x0F:
				if ((apuEn & 8) != 0)
					lenCnt[3] = LENGTH[v >> 3];
				eStart[3] = 1;
			case 0x10:
				dLoop = (v >> 6) & 1;
				dRate = v & 15;
			case 0x11:
				dOut = v & 0x7F;
			case 0x12:
				dAddr = 0xC000 | (v << 6);
			case 0x13:
				dLen = (v << 4) | 1;
			case 0x15:
				apuEn = v & 31;
				for (i in 0...4)
					if (((v >> i) & 1) == 0)
						lenCnt[i] = 0;
				if ((v & 16) != 0) {
					if (dRemain == 0) {
						dCur = dAddr;
						dRemain = dLen;
						dmcFill();
					}
				} else
					dRemain = 0;
			case 0x17:
				fcMode = v >> 7;
				fcCycle = 0;
				if (fcMode == 1) {
					clockQuarter();
					clockHalf();
				}
			default:
		}
		if (dbg)
			dbgApuWrite(r, v);
	}
	function envClock(i:Int):Void {
		if (eStart[i] != 0) {
			eStart[i] = 0;
			eDecay[i] = 15;
			eDiv[i] = eVol[i];
		} else if (eDiv[i] == 0) {
			eDiv[i] = eVol[i];
			if (eDecay[i] > 0)
				eDecay[i]--;
			else if (lenHalt[i] != 0)
				eDecay[i] = 15;
		} else
			eDiv[i]--;
	}
	function sweepTarget(i:Int):Int {
		var ch = pPeriod[i] >> pShift[i];
		return pNeg[i] != 0 ? (pPeriod[i] - ch - (i == 0 ? 1 : 0)) : (pPeriod[i] + ch);
	}
	function sweepClock(i:Int):Void {
		var t = sweepTarget(i);
		if (pSwDiv[i] == 0 && pSwEn[i] != 0 && pShift[i] != 0 && pPeriod[i] >= 8 && t >= 0 && t <= 0x7FF)
			pPeriod[i] = t;
		if (pSwDiv[i] == 0 || pSwReload[i] != 0) {
			pSwDiv[i] = pSwPeriod[i];
			pSwReload[i] = 0;
		} else
			pSwDiv[i]--;
	}
	function clockQuarter():Void {
		envClock(0);
		envClock(1);
		envClock(3);
		if (tReloadFlag != 0)
			tLinear = tLinearReload;
		else if (tLinear > 0)
			tLinear--;
		if (lenHalt[2] == 0)
			tReloadFlag = 0;
	}
	function clockHalf():Void {
		for (i in 0...4)
			if (lenHalt[i] == 0 && lenCnt[i] > 0)
				lenCnt[i]--;
		sweepClock(0);
		sweepClock(1);
	}
	function dmcFill():Void {
		if (!dBufFull && dRemain > 0) {
			dBuf = mem(dCur & 255, dCur >> 8, 0, false);
			cDmc++;
			dBufFull = true;
			dCur = ((dCur + 1) & 0xFFFF) | 0x8000;
			dRemain--;
			if (dRemain == 0 && dLoop != 0) {
				dCur = dAddr;
				dRemain = dLen;
			}
		}
	}
	function dmcClock():Void {
		if (!dSilence) {
			if ((dShift & 1) != 0) {
				if (dOut <= 125)
					dOut += 2;
			} else if (dOut >= 2)
				dOut -= 2;
			dShift >>= 1;
		}
		dBits--;
		if (dBits == 0) {
			dBits = 8;
			if (dBufFull) {
				dShift = dBuf;
				dBufFull = false;
				dSilence = false;
			} else
				dSilence = true;
		}
		dmcFill();
	}
	inline function pulseClock(i:Int):Void {
		if (pTimer[i] == 0) {
			pTimer[i] = pPeriod[i];
			pSeq[i] = (pSeq[i] + 1) & 7;
		} else
			pTimer[i]--;
	}
	function pulseOut(i:Int):Int {
		if (lenCnt[i] == 0 || pPeriod[i] < 8 || DUTY[(pDuty[i] << 3) | pSeq[i]] == 0)
			return 0;
		if (sweepTarget(i) > 0x7FF)
			return 0;
		return eConst[i] != 0 ? eVol[i] : eDecay[i];
	}
	function apuRun(n:Int):Void {
		while (n-- > 0) {
			fcCycle++;
			if (fcCycle == fcSteps[0])
				clockQuarter();
			else if (fcCycle == fcSteps[1]) {
				clockQuarter();
				clockHalf();
			} else if (fcCycle == fcSteps[2])
				clockQuarter();
			else if (fcCycle == fcSteps[3]) {
				if (fcMode == 0) {
					clockQuarter();
					clockHalf();
					fcCycle = 0;
				}
			} else if (fcCycle == fcSteps[4]) {
				clockQuarter();
				clockHalf();
				fcCycle = 0;
			}
			apuOdd = !apuOdd;
			if (apuOdd) {
				pulseClock(0);
				pulseClock(1);
			}

			if (tTimer == 0) {
				tTimer = tPeriod;
				if (lenCnt[2] > 0 && tLinear > 0)
					tStep = (tStep + 1) & 31;
			} else
				tTimer--;
			if (nTimer == 0) {
				nTimer = noiseTab[nIdx] - 1;
				var fb = (nLfsr & 1) ^ ((nLfsr >> (nMode != 0 ? 6 : 1)) & 1);
				nLfsr = (nLfsr >> 1) | (fb << 14);
			} else
				nTimer--;
			if (dTimer == 0) {
				dTimer = dmcTab[dRate] - 1;
				dmcClock();
			} else
				dTimer--;

			if (perfectAudio)
				perfectTick();
			else {
				sampleAcc += SAMPLE_RATE;
				if (sampleAcc >= cpuHz) {
					sampleAcc -= cpuHz;
					emitSample();
				}
			}
		}
	}
	function emitSample():Void {
		var p0 = (muteMask & 1) == 0 ? pulseOut(0) : 0;
		var p1 = (muteMask & 2) == 0 ? pulseOut(1) : 0;
		var p = p0 + p1;
		var tri = ((muteMask & 4) != 0 || tPeriod < 2) ? 0 : TRI[tStep];
		var noise = ((muteMask & 8) == 0 && lenCnt[3] > 0 && (nLfsr & 1) == 0) ? (eConst[3] != 0 ? eVol[3] : eDecay[3]) : 0;
		var dmc = (muteMask & 16) != 0 ? 0 : dOut;
		lvP0 = p0;
		lvP1 = p1;
		lvT = tri;
		lvN = noise;
		lvD = dmc;
		var pulse = p == 0 ? 0.0 : 95.88 / (8128.0 / p + 100.0);
		var tndIn = tri / 8227.0 + noise / 12241.0 + dmc / 22638.0;
		var tnd = tndIn == 0 ? 0.0 : 159.79 / (1.0 / tndIn + 100.0);
		var x = pulse + tnd;

		var y = x - hpIn + 0.996 * hpOut;
		hpIn = x;
		hpOut = y;
		lpOut += (y - lpOut) * 0.75;
		pushSample(lpOut);
	}
	function pushSample(v:Float):Void {
		lvMix = v;
		if (dbg) {
			scope[scopeW] = lvP0;
			scope[SCOPE_N + scopeW] = lvP1;
			scope[2 * SCOPE_N + scopeW] = lvT;
			scope[3 * SCOPE_N + scopeW] = lvN;
			scope[4 * SCOPE_N + scopeW] = lvD;
			scope[5 * SCOPE_N + scopeW] = v;
			scopeW = (scopeW + 1) & (SCOPE_N - 1);
		}
		audioBuf[aw] = v;
		aw = (aw + 1) & AUDIO_MASK;
		if (aCount < AUDIO_SIZE)
			aCount++;
		else {
			overruns++;
			ar = (ar + 1) & AUDIO_MASK;
		}
	}

	inline function pulseTarget(i:Int):Int {
		if (lenCnt[i] == 0 || pPeriod[i] < 8 || sweepTarget(i) > 0x7FF)
			return 0;
		return eConst[i] != 0 ? eVol[i] : eDecay[i];
	}
	function perfectTick():Void {
		var v0 = pVolS[0];
		var d = pulseTarget(0) - v0;
		v0 += d > SLEW ? SLEW : (d < -SLEW ? -SLEW : d);
		pVolS[0] = v0;
		var v1 = pVolS[1];
		d = pulseTarget(1) - v1;
		v1 += d > SLEW ? SLEW : (d < -SLEW ? -SLEW : d);
		pVolS[1] = v1;
		var o0 = (DUTY[(pDuty[0] << 3) | pSeq[0]] != 0 && (muteMask & 1) == 0) ? v0 : 0.0;
		var o1 = (DUTY[(pDuty[1] << 3) | pSeq[1]] != 0 && (muteMask & 2) == 0) ? v1 : 0.0;
		if (lenCnt[2] > 0 && tLinear > 0) {
			tPhase += tInc;
			if (tPhase >= 32.0)
				tPhase -= 32.0;
		}
		var tri = (muteMask & 4) != 0 ? 0.0 : (tPeriod < 2 ? 7.5 : 15.0 * Math.abs(tPhase - 16.0) * 0.0625);
		var nt = lenCnt[3] > 0 ? (eConst[3] != 0 ? eVol[3] : eDecay[3]) : 0;
		d = nt - nVolS;
		nVolS += d > SLEW ? SLEW : (d < -SLEW ? -SLEW : d);
		var no = ((nLfsr & 1) == 0 && (muteMask & 8) == 0) ? nVolS : 0.0;
		var dm = (muteMask & 16) != 0 ? 0.0 : dOut;
		var p = o0 + o1;
		var pulse = 95.88 * p / (8128.0 + 100.0 * p);
		var tndIn = tri * (1.0 / 8227.0) + no * (1.0 / 12241.0) + dm * (1.0 / 22638.0);
		var tnd = 159.79 * tndIn / (1.0 + 100.0 * tndIn);
		var level = pulse + tnd;
		lvP0 = o0;
		lvP1 = o1;
		lvT = tri;
		lvN = no;
		lvD = dm;
		var space = cpuHz - osFill;
		if (OS_RATE < space) {
			osSum += level * OS_RATE;
			osFill += OS_RATE;
		} else {
			osSum += level * space;
			osBin(osSum / cpuHz);
			var rest = OS_RATE - space;
			osSum = level * rest;
			osFill = rest;
		}
	}
	function osBin(v:Float):Void {
		osBuf[osW] = v;
		osBuf[osW + FIR_N] = v;
		osW = (osW + 1) & (FIR_N - 1);
		if (++osDecim < OS_FACTOR)
			return;
		osDecim = 0;
		var acc = 0.0;
		var idx = osW;
		for (k in 0...FIR_N)
			acc += fir[k] * osBuf[idx + k];
		var y = acc - hpIn + 0.9993 * hpOut;
		hpIn = acc;
		hpOut = y;
		pushSample(y);
	}
	function ppuTick():Void {
		if ((ppumask & 24) != 0) {
			if (scany < 240) {
				if (dot < 256 || dot >= 320) {
					if (dot < 256) {
						var color = ((shift_hi >> (14 - fine_x)) & 2) | ((shift_lo >> (15 - fine_x)) & 1);
						var palette = (shift_at >> (28 - fine_x * 2)) & 12;
						if ((ppumask & 16) != 0) {
							var h = (ppuctrl & 32) != 0 ? 16 : 8;
							var i = 0;
							while (i < 256) {
								var sx0 = dot - oam[i + 3];
								if (sx0 >= 0 && sx0 < 8) {
									var sy0 = scany - oam[i] - 1;
									if (sy0 >= 0 && sy0 < h) {
										var attr = oam[i + 2];
										var sx = sx0 ^ ((attr & 64) == 0 ? 7 : 0);
										var sy = sy0 ^ ((attr & 128) != 0 ? h - 1 : 0);
										var tile = oam[i + 1];
										var saddr = ((ppuctrl & 32) != 0
											? (((tile & 1) << 12) | ((tile << 4) & -32) | ((sy << 1) & 16))
											: (((ppuctrl & 8) << 9) | (tile << 4))) | (sy & 7);
										var scolor = (((chrRead(saddr + 8) >> sx) << 1) & 2) | ((chrRead(saddr) >> sx) & 1);
										if (scolor != 0) {
											if (!((attr & 32) != 0 && color != 0)) {
												color = scolor;
												palette = 16 | ((attr << 2) & 12);
											}
											if (i == 0 && color != 0) {
												if ((ppustatus & 64) == 0) {
													nS0++;
													if (dbg)
														dbgEvent("SPRITE-0 HIT at x=" + dot + " y=" + scany);
												}
												ppustatus |= 64;
											}
											break;
										}
									}
								}
								i += 4;
							}
						}
						frame[scany * 256 + dot] = palRGB[palette_ram[color != 0 ? (palette | color) : 0] & 63];
					}
					if (dot < 336) {
						shift_hi = (shift_hi << 1) & 0xFFFF;
						shift_lo = (shift_lo << 1) & 0xFFFF;
						shift_at <<= 2;
					}

					var temp = ((ppuctrl << 8) & 4096) | (ntb << 4) | (V >> 12);
					switch (dot & 7) {
						case 1:
							ntb = vram[ntIndex(V)];
						case 3:
							var ab = vram[ntIndex((V & 0xc00) | 0x3c0 | ((V >> 4) & 0x38) | ((V >> 2) & 7))];
							var sh = (((V >> 5) & 2) | ((V >> 1) & 1)) * 2;
							atb = ((ab >> sh) & 3) * 0x5555;
						case 5:
							ptb_lo = chrRead(temp);
						case 7:
							var ptb_hi = chrRead(temp | 8);
							V = (V & 31) == 31 ? ((V & ~31) ^ 1024) : (V + 1);
							shift_hi |= ptb_hi;
							shift_lo |= ptb_lo;
							shift_at |= atb;
						default:
					}
				}
				if (dot == 256) {
					var nv = (V & (7 << 12)) != (7 << 12) ? (V + 4096)
						: (V & 0x3e0) == 928 ? ((V & 0x8c1f) ^ 2048)
						: (V & 0x3e0) == 0x3e0 ? (V & 0x8c1f)
						: ((V & 0x8c1f) | ((V + 32) & 0x3e0));

					V = (nv & ~0x41f) | (T & 0x41f);
				}
			}
			if (((scany + 1) % lines) < 241 && dot == 261 && mmc3_irq != 0) {
				var wasZero = mmc3_latch == 0;
				mmc3_latch = (mmc3_latch - 1) & 255;
				if (wasZero)
					nmi_irq = 1;
			}
			if (scany == preLine && dot >= 280 && dot < 305)
				V = (V & 0x841f) | (T & 0x7be0);
		}
		if (dot == 1) {
			if (scany == 241) {
				if ((ppuctrl & 128) != 0)
					nmi_irq = 4;
				ppustatus |= 128;
				frameDone = true;
				frameCount++;
				lastFrameCycles = frameCycles;
				frameCycles = 0;
				lPpuWr = cPpuWr;
				lPpuRd = cPpuRd;
				lApuWr = cApuWr;
				lMapWr = cMapWr;
				lOam = cOam;
				lDmc = cDmc;
				cPpuWr = cPpuRd = cApuWr = cMapWr = cOam = cDmc = 0;
			}
			if (scany == preLine)
				ppustatus = 0;
		}
		if (++dot == 341) {
			dot = 0;
			scany++;
			if (scany == lines)
				scany = 0;
		}
	}
}
