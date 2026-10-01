package;

import haxe.ds.Vector;
import haxe.io.Bytes;

class Nes {
	static inline var ROM_MAX = 1024 * 1024;
	static inline var ANE_MAGIC = 0xFF;
	static inline var LXA_MAGIC = 0xFF;
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
	static function mk(n:Int):Vector<Int> {
		var v = new Vector<Int>(n);
		for (i in 0...n)
			v[i] = 0;
		return v;
	}

	static function mkf(n:Int):Vector<Float> {
		var v = new Vector<Float>(n);
		for (i in 0...n)
			v[i] = 0.0;
		return v;
	}

	public var pad = 0;
	public var zapper = false;
	public var zx = -1;
	public var zy = -1;
	public var zTrig = false;
	static inline var ZAP_R = 1;
	static inline var ZAP_LAG = 26;
	static inline var ZAP_LUM = 176;
	public var frameDone = false;
	public var frame:Vector<Int> = mk(256 * 240);
	var rombuf:Vector<Int> = mk(ROM_MAX);
	var chrBase = 0;
	var chrLen = 8192;
	var chrIsRam = true;
	var hasPrgRam = false;
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
	var oam2:Vector<Int> = mk(32);
	var palRGB:Vector<Int> = mk(64);

	var A = 0;
	var X = 0;
	var Y = 0;
	var P = 0x24;
	var S = 0xFD;
	var PC = 0;
	public var PCH(get, never):Int;
	public var PCL(get, never):Int;
	inline function get_PCH():Int
		return PC >> 8;
	inline function get_PCL():Int
		return PC & 255;
	var jammed = false;
	var openBus = 0;
	var cycleCount = 0;
	var masterClock = 0;
	var ppuClock = 0;
	var cpuDiv = 12;
	var ppuDiv = 4;
	var startClk = 6;
	var endClk = 6;
	public var ppuOffset = 1;
	public var cycleParity = 0;
	var needNmi = false;
	var prevNeedNmi = false;
	var nmiLine = false;
	var prevNmiLine = false;
	var runIrq = false;
	var prevRunIrq = false;
	var irqSources = 0;
	public var nmi_irq(get, never):Int;

	function get_nmi_irq():Int
		return (needNmi || prevNeedNmi) ? 4 : ((runIrq || prevRunIrq) ? 1 : 0);

	var needHalt = false;
	var dmcDmaRunning = false;
	var needDummyRead = false;
	var abortDmcDma = false;
	var oamDmaRunning = false;
	var oamDmaPage = 0;

	var ppuctrl = 0;
	var ppumask = 0;
	var ppustatus = 0;
	var ppubuf = 0;
	var ppuBus = 0;
	var ppuBusStamp:Vector<Int> = mk(8);
	var oamAddr = 0;
	var W = 0;
	var fine_x = 0;
	var T = 0;
	var V = 0;
	var scany = 0;
	var dot = 0;
	var lines = 262;
	var preLine = 261;
	var oddFrame = false;
	var renderOn = false;
	var renderNext = false;
	var preventVbl = false;
	var vramDelay = 0;
	var vramPending = 0;
	var ignoreVramRead = 0;
	var bgLo = 0;
	var bgHi = 0;
	var atLo = 0;
	var atHi = 0;
	var atLatchLo = 0;
	var atLatchHi = 0;
	var ntb = 0;
	var atb = 0;
	var ptbLo = 0;
	var ptbHi = 0;
	var oamBuf = 0;
	var oam2Addr = 0;
	var spAddrH = 0;
	var spAddrL = 0;
	var spInRange = false;
	var spCopyDone = false;
	var spOverflowBug = 0;
	var sp0Added = false;
	var sp0Visible = false;
	var spCount = 0;
	var spX:Vector<Int> = mk(8);
	var spLo:Vector<Int> = mk(8);
	var spHi:Vector<Int> = mk(8);
	var spAttr:Vector<Int> = mk(8);
	var spFetchIdx = 0;
	var spShown = false;
	var keys = 0;
	var keys2 = 0;
	var strobe = false;
	var strobeVis = false;
	var lastPortRead = -10;
	var lastPortAddr = 0;
	var lastPortBit = 0;
	var mirror = 0;
	var mmc1_bits = 0;
	var mmc1_data = 0;
	var mmc1_ctrl = 0;
	var mmc3_chrprg:Vector<Int> = mk(8);
	var mmc3_bits = 0;
	var mmc3_irq = 0;
	var mmc3_latch = 0;
	var mmc3_reload = 0;
	var mmc3_reloadFlag = false;
	var chrbank0 = 0;
	var chrbank1 = 0;
	var prgbank = 0;
	public var pal = false;

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
	public static inline var AUDIO_SIZE = 16384;
	static inline var AUDIO_MASK = AUDIO_SIZE - 1;
	public static inline var AUDIO_TARGET = 4096;
	public static inline var AUDIO_LOW = 3200;
	public static inline var AUDIO_HIGH = 6400;
	var audioBuf:Vector<Float> = mkf(AUDIO_SIZE);
	var aw = 0;
	var ar = 0;
	public var aCount(get, never):Int;

	inline function get_aCount():Int
		return aw - ar;

	var cpuHz = 1789773;
	var sampleAcc = 0;
	var hpIn = 0.0;
	var hpOut = 0.0;
	var lpOut = 0.0;
	var underruns = 0;
	var overruns = 0;
	var lastOut = 0.0;
	var rFrac = 0.0;
	var primed = false;
	public var audioLive = false;
	public var perfectAudio(default, set):Bool = false;
	public var muteMask = 0;
	static inline var OS_FACTOR = 8;
	static inline var OS_RATE = SAMPLE_RATE * OS_FACTOR;
	static inline var FIR_N = 256;
	static inline var FIR_CUTOFF = 20000.0;
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
	static final FC_NTSC:Array<Array<Int>> = [[7457, 14913, 22371, 29828, 29829, 29830], [7457, 14913, 22371, 29829, 37281, 37282]];
	static final FC_PAL:Array<Array<Int>> = [[8313, 16627, 24939, 33253, 33254, 33255], [8313, 16627, 24939, 33253, 41565, 41566]];
	static final FC_TYPE:Array<Int> = [1, 2, 1, 0, 2, 0];
	var apuEn = 0;
	var apuOdd = false;
	var fcMode = 0;
	var fcCycle = 0;
	var fcStep = 0;
	var fcNew = -1;
	var fcDelay = 0;
	var fcBlock = 0;
	var fcInhibit = false;
	var fcTab:Array<Array<Int>> = FC_NTSC;
	var fcSteps:Array<Int> = [7457, 14913, 22371, 29829, 37281];
	var noiseTab:Array<Int> = NOISE_NTSC;
	var dmcTab:Array<Int> = DMC_NTSC;
	var lenCnt:Vector<Int> = mk(4);
	var lenHalt:Vector<Int> = mk(4);
	var lenHaltNew:Vector<Int> = mk(4);
	var lenReload:Vector<Int> = mk(4);
	var lenPrev:Vector<Int> = mk(4);
	var eLoop:Vector<Int> = mk(4);
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
	var dIrqEn = 0;
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
	var dStartDelay = 0;

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
		cpuDiv = pal ? 16 : 12;
		ppuDiv = pal ? 5 : 4;
		startClk = pal ? 8 : 6;
		endClk = pal ? 8 : 6;
		fcTab = pal ? FC_PAL : FC_NTSC;
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
		var mapper = rombuf[6] >> 4;
		hasPrgRam = mapper != 0 || (rombuf[6] & 2) != 0;
		if (mapper == 1) {
			mmc1_ctrl = 12;
			mmc1_bits = 5;
		}
		if (mapper == 4) {
			prgbits--;
			chrbits -= 2;
			mapperWrite(0x8000, 0);
		}
		powerOn();
	}

	function powerOn():Void {
		A = 0;
		X = 0;
		Y = 0;
		S = 0xFD;
		P = 0x24;
		jammed = false;
		cycleCount = cycleParity;
		masterClock = 0;
		ppuClock = 0;
		scany = 0;
		dot = 0;
		for (i in 0...8) {
			cycleStart(true);
			cycleEnd(true);
		}
		PC = rd(0xFFFC);
		PC |= rd(0xFFFD) << 8;
	}

	public function runFrame():Void {
		frameDone = false;
		while (!frameDone)
			step();
	}

	inline function prgIdx(a:Int):Int
		return ((prg[((a >> 12) - 8) >> (prgbits - 12)] & ((rombuf[4] << (14 - prgbits)) - 1)) << prgbits) | (a & ((1 << prgbits) - 1));

	function prgRead(a:Int):Int {
		var p = prgIdx(a) + 16;
		return p < ROM_MAX ? rombuf[p] : 0;
	}

	public function peek(a:Int):Int {
		a &= 0xFFFF;
		if (a < 0x2000)
			return ram[a & 0x7FF];
		if (a < 0x6000)
			return 0xFF;
		if (a < 0x8000)
			return prgram[a & 8191];
		return prgRead(a);
	}

	function zapperLight():Bool {
		if (zx < 0 || zy < 0)
			return false;
		for (dy in -ZAP_R...ZAP_R + 1) {
			var y = zy + dy;
			if (y < 0 || y >= 240)
				continue;
			var age = scany - y;
			if (age < 0 || age > ZAP_LAG)
				continue;
			for (dx in -ZAP_R...ZAP_R + 1) {
				var x = zx + dx;
				if (x < 0 || x >= 256)
					continue;
				if (age == 0 && dot <= x)
					continue;
				var c = frame[y * 256 + x];
				var lum = ((((c >> 16) & 255) * 77) + (((c >> 8) & 255) * 151) + ((c & 255) * 28)) >> 8;
				if (lum >= ZAP_LUM)
					return true;
			}
		}
		return false;
	}

	function zapperBits():Int
		return (zTrig ? 16 : 0) | (zapperLight() ? 0 : 8);

	static inline function h2(v:Int):String
		return StringTools.hex(v & 255, 2);

	static inline function h4(v:Int):String
		return StringTools.hex(v & 0xFFFF, 4);

	function dbgEvent(msg:String):Void {
		evBuf[evSeq & (EV_N - 1)] = "f" + frameCount + " " + scany + ":" + dot + " " + msg;
		evSeq++;
	}

	function dbgTrace():Void {
		trPC[trW] = PC;
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

	function mapperWrite(addr:Int, val:Int):Void {
		cMapWr++;
		if (dbg)
			dbgEvent("MAPPER write $" + h4(addr) + " <- $" + h2(val));
		var hi = addr >> 12;
		switch (rombuf[6] >> 4) {
			case 7:
				mirror = (val >> 4) & 1;
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
							mmc3_reload = val;
						else {
							mmc3_latch = 0;
							mmc3_reloadFlag = true;
						}
					case 7:
						mmc3_irq = addr1;
						if (addr1 == 0)
							irqSources &= ~4;
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

	function mmc3Clock():Void {
		if (mmc3_latch == 0 || mmc3_reloadFlag) {
			mmc3_latch = mmc3_reload;
			mmc3_reloadFlag = false;
		} else
			mmc3_latch--;
		if (mmc3_latch == 0 && mmc3_irq != 0)
			irqSources |= 4;
	}

	function ioRead(a:Int):Int {
		switch (a) {
			case 0x4015:
				return apuStatus();
			case 0x4016, 0x4017:
				return portRead(a);
			default:
				return openBus;
		}
	}

	function portRead(a:Int):Int {
		var consecutive = lastPortRead == cycleCount - 1 && lastPortAddr == a;
		lastPortRead = cycleCount;
		lastPortAddr = a;
		if (a == 0x4017) {
			var z = zapper ? zapperBits() : 0;
			return (openBus & 0xE0) | z | (keys2 & 1);
		}
		if (strobe)
			keys = pad;
		var b = consecutive ? lastPortBit : (keys & 1);
		if (!strobe && !consecutive)
			keys = (keys >> 1) | 0x80;
		lastPortBit = b;
		return (openBus & 0xE0) | b;
	}

	function ioWrite(a:Int, v:Int):Void {
		if (a == 0x4014) {
			cOam++;
			if (dbg)
				dbgEvent("OAM DMA from $" + h2(v) + "00");
			oamDmaPage = v;
			oamDmaRunning = true;
			needHalt = true;
			return;
		}
		if (a == 0x4016) {
			strobe = (v & 1) != 0;
			return;
		}
		if (a < 0x4018) {
			if (a == 0x4017 || a < 0x4014 || a == 0x4015)
				apuWrite(a & 0x1F, v);
		}
	}

	function busRead(a:Int):Int {
		if (a < 0x2000)
			return ram[a & 0x7FF];
		if (a < 0x4000)
			return ppuRegRead(a & 7);
		if (a < 0x4020)
			return ioRead(a);
		if (a < 0x6000)
			return openBus;
		if (a < 0x8000)
			return hasPrgRam ? prgram[a & 8191] : openBus;
		return prgRead(a);
	}

	function busWrite(a:Int, v:Int):Void {
		if (a < 0x2000)
			ram[a & 0x7FF] = v;
		else if (a < 0x4000)
			ppuRegWrite(a & 7, v);
		else if (a < 0x4020)
			ioWrite(a, v);
		else if (a < 0x6000) {
		} else if (a < 0x8000) {
			if (hasPrgRam)
				prgram[a & 8191] = v;
		} else
			mapperWrite(a, v);
	}

	inline function ppuRun(to:Int):Void {
		while (ppuClock + ppuDiv <= to) {
			ppuStep();
			ppuClock += ppuDiv;
		}
	}

	inline function cycleStart(r:Bool):Void {
		cycleCount++;
		masterClock += r ? startClk - 1 : startClk + 1;
		ppuRun(masterClock - ppuOffset);
	}

	function cycleEnd(r:Bool):Void {
		masterClock += r ? endClk + 1 : endClk - 1;
		ppuRun(masterClock - ppuOffset);
		apuStep();
		if (strobeVis && (cycleCount & 1) == 0)
			keys = pad;
		strobeVis = strobe;
		prevNeedNmi = needNmi;
		if (!prevNmiLine && nmiLine)
			needNmi = true;
		prevNmiLine = nmiLine;
		prevRunIrq = runIrq;
		runIrq = irqSources != 0 && (P & 4) == 0;
		totalCycles++;
		frameCycles++;
		if (masterClock > 0x40000000) {
			masterClock -= 0x40000000;
			ppuClock -= 0x40000000;
		}
	}

	function rd(a:Int):Int {
		if (needHalt)
			dmaRun(a);
		cycleStart(true);
		var v = busRead(a);
		cycleEnd(true);
		if (a != 0x4015)
			openBus = v;
		return v;
	}

	function wr(a:Int, v:Int):Void {
		cycleStart(false);
		openBus = v;
		busWrite(a, v);
		cycleEnd(false);
	}

	function dmaRead(a:Int):Int {
		var v = busRead(a);
		if (a != 0x4015)
			openBus = v;
		return v;
	}

	function dmcDmaRequest():Void {
		if (dmcDmaRunning)
			return;
		dmcDmaRunning = true;
		needHalt = true;
		needDummyRead = true;
		abortDmcDma = false;
	}

	function dmcDmaStop():Void {
		if (!dmcDmaRunning)
			return;
		if (needHalt && !oamDmaRunning) {
			dmcDmaRunning = false;
			needHalt = false;
			needDummyRead = false;
		} else if (needDummyRead)
			abortDmcDma = true;
	}

	function dmcRead(addr:Int, readAddr:Int, internal:Bool):Int {
		var ext = busRead(addr);
		var v = ext;
		var reg = 0x4000 | (addr & 0x1F);
		if (internal) {
			if (reg == 0x4015)
				apuStatus();
			else if (reg == 0x4016 || reg == 0x4017)
				v = (ext & 0xE0) | (portRead(reg) & 0x1F);
		}
		openBus = v;
		return ext;
	}

	function oamDmaRead(oa:Int, internal:Bool):Int {
		if (!internal) {
			if (oa >= 0x4000 && oa < 0x4020)
				return openBus;
			return dmaRead(oa);
		}
		var low = oa & 0x1F;
		var ext = (oa >= 0x4000 && oa < 0x6000) ? openBus : busRead(oa);
		var v = ext;
		if (low == 0x15)
			v = (apuStatus() & 0xDF) | (ext & 0x20);
		else if (oa >= 0x4000 && oa < 0x6000 && (low == 0x16 || low == 0x17))
			v = (ext & 0xE0) | (portRead(0x4000 | low) & 0x1F);
		if (low != 0x15)
			openBus = v;
		return v;
	}

	function dmaRun(readAddr:Int):Void {
		var internal = (readAddr & 0xFFE0) == 0x4000;
		var oamCounter = 0;
		var oamReadAddr = 0;
		var readValue = 0;
		needHalt = false;
		cycleStart(true);
		dmaRead(readAddr);
		cycleEnd(true);
		while (dmcDmaRunning || oamDmaRunning) {
			var get = (cycleCount & 1) == 0;
			var notReady = needHalt || needDummyRead;
			if (needHalt)
				needHalt = false;
			else if (needDummyRead)
				needDummyRead = false;
			cycleStart(true);
			if (get) {
				if (dmcDmaRunning && !notReady) {
					if (abortDmcDma)
						dmaRead(readAddr);
					else {
						cDmc++;
						dmcDmaDone(dmcRead(dCur, readAddr, internal));
					}
					dmcDmaRunning = false;
					abortDmcDma = false;
				} else if (oamDmaRunning) {
					readValue = oamDmaRead((oamDmaPage << 8) | oamReadAddr, internal);
					oamReadAddr = (oamReadAddr + 1) & 255;
					oamCounter++;
				} else
					dmaRead(readAddr);
			} else {
				if (oamDmaRunning && (oamCounter & 1) != 0) {
					openBus = readValue;
					ppuRegWrite(4, readValue);
					oamCounter++;
					if (oamCounter == 512)
						oamDmaRunning = false;
				} else
					dmaRead(readAddr);
			}
			cycleEnd(true);
		}
	}

	inline function setNz(v:Int):Void
		P = (P & 0x7D) | (v & 0x80) | (v == 0 ? 2 : 0);

	inline function fetch():Int {
		var v = rd(PC);
		PC = (PC + 1) & 0xFFFF;
		return v;
	}

	inline function push(x:Int):Void {
		wr(0x100 | S, x);
		S = (S - 1) & 255;
	}

	inline function pull():Int {
		S = (S + 1) & 255;
		return rd(0x100 | S);
	}

	function zpIdx(i:Int):Int {
		var a = fetch();
		rd(a);
		return (a + i) & 255;
	}

	function absIdx(i:Int, w:Bool):Int {
		var lo = fetch();
		var hi = fetch();
		var base = lo | (hi << 8);
		var ea = (base + i) & 0xFFFF;
		if (w || (base & 0xFF00) != (ea & 0xFF00))
			rd((base & 0xFF00) | (ea & 0xFF));
		return ea;
	}

	function indX():Int {
		var zp = fetch();
		rd(zp);
		zp = (zp + X) & 255;
		var lo = rd(zp);
		return lo | (rd((zp + 1) & 255) << 8);
	}

	function indY(w:Bool):Int {
		var zp = fetch();
		var lo = rd(zp);
		var hi = rd((zp + 1) & 255);
		var base = lo | (hi << 8);
		var ea = (base + Y) & 0xFFFF;
		if (w || (base & 0xFF00) != (ea & 0xFF00))
			rd((base & 0xFF00) | (ea & 0xFF));
		return ea;
	}

	function shStore(base:Int, ea:Int, hi:Int, reg:Int):Void {
		var v = reg & ((hi + 1) & 255);
		if ((base & 0xFF00) != (ea & 0xFF00))
			ea = (v << 8) | (ea & 0xFF);
		wr(ea, v);
	}

	function shAbs(i:Int, reg:Int, ?sets:Bool = false):Void {
		var lo = fetch();
		var hi = fetch();
		var base = lo | (hi << 8);
		var ea = (base + i) & 0xFFFF;
		rd((base & 0xFF00) | (ea & 0xFF));
		if (sets)
			S = reg;
		shStore(base, ea, hi, reg);
	}

	function shIndY(reg:Int):Void {
		var zp = fetch();
		var lo = rd(zp);
		var hi = rd((zp + 1) & 255);
		var base = lo | (hi << 8);
		var ea = (base + Y) & 0xFFFF;
		rd((base & 0xFF00) | (ea & 0xFF));
		shStore(base, ea, hi, reg);
	}

	function adc(v:Int):Void {
		var sum = A + v + (P & 1);
		P = (P & ~65) | (sum > 255 ? 1 : 0) | (((A ^ sum) & (v ^ sum) & 128) >> 1);
		A = sum & 255;
		setNz(A);
	}

	function cmp(r:Int, v:Int):Void {
		P = (P & ~1) | (r >= v ? 1 : 0);
		setNz((r - v) & 255);
	}

	function bit(v:Int):Void
		P = (P & 0x3D) | (v & 0xC0) | ((A & v) == 0 ? 2 : 0);

	function asl(v:Int):Int {
		P = (P & ~1) | (v >> 7);
		return (v << 1) & 255;
	}

	function lsr(v:Int):Int {
		P = (P & ~1) | (v & 1);
		return v >> 1;
	}

	function rol(v:Int):Int {
		var r = ((v << 1) | (P & 1)) & 255;
		P = (P & ~1) | (v >> 7);
		return r;
	}

	function ror(v:Int):Int {
		var r = (v >> 1) | ((P & 1) << 7);
		P = (P & ~1) | (v & 1);
		return r;
	}

	function branch(cond:Bool):Void {
		var off = fetch();
		if (!cond)
			return;
		if (runIrq && !prevRunIrq)
			runIrq = false;
		rd(PC);
		var np = (PC + (off >= 128 ? off - 256 : off)) & 0xFFFF;
		if ((np & 0xFF00) != (PC & 0xFF00))
			rd((PC & 0xFF00) | (np & 0xFF));
		PC = np;
	}

	function jsr():Void {
		var lo = fetch();
		rd(0x100 | S);
		push(PC >> 8);
		push(PC & 255);
		PC = lo | (rd(PC) << 8);
	}

	function rts():Void {
		rd(PC);
		rd(0x100 | S);
		var lo = pull();
		PC = lo | (pull() << 8);
		rd(PC);
		PC = (PC + 1) & 0xFFFF;
	}

	function rti():Void {
		rd(PC);
		rd(0x100 | S);
		P = (pull() & 0xEF) | 0x20;
		var lo = pull();
		PC = lo | (pull() << 8);
	}

	function brk():Void {
		fetch();
		push(PC >> 8);
		push(PC & 255);
		push(P | 0x30);
		P |= 4;
		var vec = 0xFFFE;
		if (needNmi) {
			needNmi = false;
			vec = 0xFFFA;
		}
		nBrk++;
		var lo = rd(vec);
		PC = lo | (rd(vec + 1) << 8);
	}

	function interrupt():Void {
		rd(PC);
		rd(PC);
		push(PC >> 8);
		push(PC & 255);
		push((P | 0x20) & 0xEF);
		P |= 4;
		var vec = 0xFFFE;
		if (needNmi) {
			needNmi = false;
			vec = 0xFFFA;
			nNmi++;
		} else
			nIrq++;
		if (dbg)
			dbgEvent((vec == 0xFFFA ? "NMI" : "IRQ") + " taken at $" + h4(PC) + " S=$" + h2(S));
		var lo = rd(vec);
		PC = lo | (rd(vec + 1) << 8);
	}

	function step():Void {
		if (jammed) {
			rd(PC);
			return;
		}
		if (dbg)
			dbgTrace();
		instrCount++;
		var op = fetch();
		exec(op);
		if (prevRunIrq || prevNeedNmi)
			interrupt();
	}

	function exec(op:Int):Void {
		var ea = 0;
		var v = 0;
		var r = 0;
		switch (op) {
			case 0x00: brk();
			case 0x01: ea = indX(); v = rd(ea); A |= v; setNz(A);
			case 0x02: jammed = true;
			case 0x03: ea = indX(); v = rd(ea); wr(ea, v); r = asl(v); A |= r; setNz(A); wr(ea, r);
			case 0x04: ea = fetch(); v = rd(ea);
			case 0x05: ea = fetch(); v = rd(ea); A |= v; setNz(A);
			case 0x06: ea = fetch(); v = rd(ea); wr(ea, v); r = asl(v); setNz(r); wr(ea, r);
			case 0x07: ea = fetch(); v = rd(ea); wr(ea, v); r = asl(v); A |= r; setNz(A); wr(ea, r);
			case 0x08: rd(PC); push(P | 0x30);
			case 0x09: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); A |= v; setNz(A);
			case 0x0A: rd(PC); v = A; r = asl(v); A = r; setNz(A);
			case 0x0B: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); A &= v; setNz(A); P = (P & 0xFE) | (A >> 7);
			case 0x0C: ea = fetch(); ea |= fetch() << 8; v = rd(ea);
			case 0x0D: ea = fetch(); ea |= fetch() << 8; v = rd(ea); A |= v; setNz(A);
			case 0x0E: ea = fetch(); ea |= fetch() << 8; v = rd(ea); wr(ea, v); r = asl(v); setNz(r); wr(ea, r);
			case 0x0F: ea = fetch(); ea |= fetch() << 8; v = rd(ea); wr(ea, v); r = asl(v); A |= r; setNz(A); wr(ea, r);
			case 0x10: branch((P & 128) == 0);
			case 0x11: ea = indY(false); v = rd(ea); A |= v; setNz(A);
			case 0x12: jammed = true;
			case 0x13: ea = indY(true); v = rd(ea); wr(ea, v); r = asl(v); A |= r; setNz(A); wr(ea, r);
			case 0x14: ea = zpIdx(X); v = rd(ea);
			case 0x15: ea = zpIdx(X); v = rd(ea); A |= v; setNz(A);
			case 0x16: ea = zpIdx(X); v = rd(ea); wr(ea, v); r = asl(v); setNz(r); wr(ea, r);
			case 0x17: ea = zpIdx(X); v = rd(ea); wr(ea, v); r = asl(v); A |= r; setNz(A); wr(ea, r);
			case 0x18: rd(PC); P &= 0xFE;
			case 0x19: ea = absIdx(Y, false); v = rd(ea); A |= v; setNz(A);
			case 0x1A: rd(PC);
			case 0x1B: ea = absIdx(Y, true); v = rd(ea); wr(ea, v); r = asl(v); A |= r; setNz(A); wr(ea, r);
			case 0x1C: ea = absIdx(X, false); v = rd(ea);
			case 0x1D: ea = absIdx(X, false); v = rd(ea); A |= v; setNz(A);
			case 0x1E: ea = absIdx(X, true); v = rd(ea); wr(ea, v); r = asl(v); setNz(r); wr(ea, r);
			case 0x1F: ea = absIdx(X, true); v = rd(ea); wr(ea, v); r = asl(v); A |= r; setNz(A); wr(ea, r);
			case 0x20: jsr();
			case 0x21: ea = indX(); v = rd(ea); A &= v; setNz(A);
			case 0x22: jammed = true;
			case 0x23: ea = indX(); v = rd(ea); wr(ea, v); r = rol(v); A &= r; setNz(A); wr(ea, r);
			case 0x24: ea = fetch(); v = rd(ea); bit(v);
			case 0x25: ea = fetch(); v = rd(ea); A &= v; setNz(A);
			case 0x26: ea = fetch(); v = rd(ea); wr(ea, v); r = rol(v); setNz(r); wr(ea, r);
			case 0x27: ea = fetch(); v = rd(ea); wr(ea, v); r = rol(v); A &= r; setNz(A); wr(ea, r);
			case 0x28: rd(PC); rd(0x100 | S); P = (pull() & 0xEF) | 0x20;
			case 0x29: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); A &= v; setNz(A);
			case 0x2A: rd(PC); v = A; r = rol(v); A = r; setNz(A);
			case 0x2B: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); A &= v; setNz(A); P = (P & 0xFE) | (A >> 7);
			case 0x2C: ea = fetch(); ea |= fetch() << 8; v = rd(ea); bit(v);
			case 0x2D: ea = fetch(); ea |= fetch() << 8; v = rd(ea); A &= v; setNz(A);
			case 0x2E: ea = fetch(); ea |= fetch() << 8; v = rd(ea); wr(ea, v); r = rol(v); setNz(r); wr(ea, r);
			case 0x2F: ea = fetch(); ea |= fetch() << 8; v = rd(ea); wr(ea, v); r = rol(v); A &= r; setNz(A); wr(ea, r);
			case 0x30: branch((P & 128) != 0);
			case 0x31: ea = indY(false); v = rd(ea); A &= v; setNz(A);
			case 0x32: jammed = true;
			case 0x33: ea = indY(true); v = rd(ea); wr(ea, v); r = rol(v); A &= r; setNz(A); wr(ea, r);
			case 0x34: ea = zpIdx(X); v = rd(ea);
			case 0x35: ea = zpIdx(X); v = rd(ea); A &= v; setNz(A);
			case 0x36: ea = zpIdx(X); v = rd(ea); wr(ea, v); r = rol(v); setNz(r); wr(ea, r);
			case 0x37: ea = zpIdx(X); v = rd(ea); wr(ea, v); r = rol(v); A &= r; setNz(A); wr(ea, r);
			case 0x38: rd(PC); P |= 1;
			case 0x39: ea = absIdx(Y, false); v = rd(ea); A &= v; setNz(A);
			case 0x3A: rd(PC);
			case 0x3B: ea = absIdx(Y, true); v = rd(ea); wr(ea, v); r = rol(v); A &= r; setNz(A); wr(ea, r);
			case 0x3C: ea = absIdx(X, false); v = rd(ea);
			case 0x3D: ea = absIdx(X, false); v = rd(ea); A &= v; setNz(A);
			case 0x3E: ea = absIdx(X, true); v = rd(ea); wr(ea, v); r = rol(v); setNz(r); wr(ea, r);
			case 0x3F: ea = absIdx(X, true); v = rd(ea); wr(ea, v); r = rol(v); A &= r; setNz(A); wr(ea, r);
			case 0x40: rti();
			case 0x41: ea = indX(); v = rd(ea); A ^= v; setNz(A);
			case 0x42: jammed = true;
			case 0x43: ea = indX(); v = rd(ea); wr(ea, v); r = lsr(v); A ^= r; setNz(A); wr(ea, r);
			case 0x44: ea = fetch(); v = rd(ea);
			case 0x45: ea = fetch(); v = rd(ea); A ^= v; setNz(A);
			case 0x46: ea = fetch(); v = rd(ea); wr(ea, v); r = lsr(v); setNz(r); wr(ea, r);
			case 0x47: ea = fetch(); v = rd(ea); wr(ea, v); r = lsr(v); A ^= r; setNz(A); wr(ea, r);
			case 0x48: rd(PC); push(A);
			case 0x49: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); A ^= v; setNz(A);
			case 0x4A: rd(PC); v = A; r = lsr(v); A = r; setNz(A);
			case 0x4B: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); A &= v; P = (P & 0xFE) | (A & 1); A >>= 1; setNz(A);
			case 0x4C: ea = fetch(); ea |= fetch() << 8; PC = ea;
			case 0x4D: ea = fetch(); ea |= fetch() << 8; v = rd(ea); A ^= v; setNz(A);
			case 0x4E: ea = fetch(); ea |= fetch() << 8; v = rd(ea); wr(ea, v); r = lsr(v); setNz(r); wr(ea, r);
			case 0x4F: ea = fetch(); ea |= fetch() << 8; v = rd(ea); wr(ea, v); r = lsr(v); A ^= r; setNz(A); wr(ea, r);
			case 0x50: branch((P & 64) == 0);
			case 0x51: ea = indY(false); v = rd(ea); A ^= v; setNz(A);
			case 0x52: jammed = true;
			case 0x53: ea = indY(true); v = rd(ea); wr(ea, v); r = lsr(v); A ^= r; setNz(A); wr(ea, r);
			case 0x54: ea = zpIdx(X); v = rd(ea);
			case 0x55: ea = zpIdx(X); v = rd(ea); A ^= v; setNz(A);
			case 0x56: ea = zpIdx(X); v = rd(ea); wr(ea, v); r = lsr(v); setNz(r); wr(ea, r);
			case 0x57: ea = zpIdx(X); v = rd(ea); wr(ea, v); r = lsr(v); A ^= r; setNz(A); wr(ea, r);
			case 0x58: rd(PC); P &= 0xFB;
			case 0x59: ea = absIdx(Y, false); v = rd(ea); A ^= v; setNz(A);
			case 0x5A: rd(PC);
			case 0x5B: ea = absIdx(Y, true); v = rd(ea); wr(ea, v); r = lsr(v); A ^= r; setNz(A); wr(ea, r);
			case 0x5C: ea = absIdx(X, false); v = rd(ea);
			case 0x5D: ea = absIdx(X, false); v = rd(ea); A ^= v; setNz(A);
			case 0x5E: ea = absIdx(X, true); v = rd(ea); wr(ea, v); r = lsr(v); setNz(r); wr(ea, r);
			case 0x5F: ea = absIdx(X, true); v = rd(ea); wr(ea, v); r = lsr(v); A ^= r; setNz(A); wr(ea, r);
			case 0x60: rts();
			case 0x61: ea = indX(); v = rd(ea); adc(v);
			case 0x62: jammed = true;
			case 0x63: ea = indX(); v = rd(ea); wr(ea, v); r = ror(v); adc(r); wr(ea, r);
			case 0x64: ea = fetch(); v = rd(ea);
			case 0x65: ea = fetch(); v = rd(ea); adc(v);
			case 0x66: ea = fetch(); v = rd(ea); wr(ea, v); r = ror(v); setNz(r); wr(ea, r);
			case 0x67: ea = fetch(); v = rd(ea); wr(ea, v); r = ror(v); adc(r); wr(ea, r);
			case 0x68: rd(PC); rd(0x100 | S); A = pull(); setNz(A);
			case 0x69: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); adc(v);
			case 0x6A: rd(PC); v = A; r = ror(v); A = r; setNz(A);
			case 0x6B: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); A &= v; A = (A >> 1) | ((P & 1) << 7); setNz(A); P = (P & 0xBE) | ((A >> 6) & 1) | ((((A >> 6) ^ (A >> 5)) & 1) << 6);
			case 0x6C: ea = fetch(); ea |= fetch() << 8; v = rd(ea); r = rd((ea & 0xFF00) | ((ea + 1) & 0xFF)); PC = v | (r << 8);
			case 0x6D: ea = fetch(); ea |= fetch() << 8; v = rd(ea); adc(v);
			case 0x6E: ea = fetch(); ea |= fetch() << 8; v = rd(ea); wr(ea, v); r = ror(v); setNz(r); wr(ea, r);
			case 0x6F: ea = fetch(); ea |= fetch() << 8; v = rd(ea); wr(ea, v); r = ror(v); adc(r); wr(ea, r);
			case 0x70: branch((P & 64) != 0);
			case 0x71: ea = indY(false); v = rd(ea); adc(v);
			case 0x72: jammed = true;
			case 0x73: ea = indY(true); v = rd(ea); wr(ea, v); r = ror(v); adc(r); wr(ea, r);
			case 0x74: ea = zpIdx(X); v = rd(ea);
			case 0x75: ea = zpIdx(X); v = rd(ea); adc(v);
			case 0x76: ea = zpIdx(X); v = rd(ea); wr(ea, v); r = ror(v); setNz(r); wr(ea, r);
			case 0x77: ea = zpIdx(X); v = rd(ea); wr(ea, v); r = ror(v); adc(r); wr(ea, r);
			case 0x78: rd(PC); P |= 4;
			case 0x79: ea = absIdx(Y, false); v = rd(ea); adc(v);
			case 0x7A: rd(PC);
			case 0x7B: ea = absIdx(Y, true); v = rd(ea); wr(ea, v); r = ror(v); adc(r); wr(ea, r);
			case 0x7C: ea = absIdx(X, false); v = rd(ea);
			case 0x7D: ea = absIdx(X, false); v = rd(ea); adc(v);
			case 0x7E: ea = absIdx(X, true); v = rd(ea); wr(ea, v); r = ror(v); setNz(r); wr(ea, r);
			case 0x7F: ea = absIdx(X, true); v = rd(ea); wr(ea, v); r = ror(v); adc(r); wr(ea, r);
			case 0x80: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea);
			case 0x81: ea = indX(); wr(ea, A);
			case 0x82: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea);
			case 0x83: ea = indX(); wr(ea, A & X);
			case 0x84: ea = fetch(); wr(ea, Y);
			case 0x85: ea = fetch(); wr(ea, A);
			case 0x86: ea = fetch(); wr(ea, X);
			case 0x87: ea = fetch(); wr(ea, A & X);
			case 0x88: rd(PC); Y = (Y - 1) & 255; setNz(Y);
			case 0x89: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea);
			case 0x8A: rd(PC); A = X; setNz(A);
			case 0x8B: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); A = (A | ANE_MAGIC) & X & v; setNz(A);
			case 0x8C: ea = fetch(); ea |= fetch() << 8; wr(ea, Y);
			case 0x8D: ea = fetch(); ea |= fetch() << 8; wr(ea, A);
			case 0x8E: ea = fetch(); ea |= fetch() << 8; wr(ea, X);
			case 0x8F: ea = fetch(); ea |= fetch() << 8; wr(ea, A & X);
			case 0x90: branch((P & 1) == 0);
			case 0x91: ea = indY(true); wr(ea, A);
			case 0x92: jammed = true;
			case 0x93: shIndY(A & X);
			case 0x94: ea = zpIdx(X); wr(ea, Y);
			case 0x95: ea = zpIdx(X); wr(ea, A);
			case 0x96: ea = zpIdx(Y); wr(ea, X);
			case 0x97: ea = zpIdx(Y); wr(ea, A & X);
			case 0x98: rd(PC); A = Y; setNz(A);
			case 0x99: ea = absIdx(Y, true); wr(ea, A);
			case 0x9A: rd(PC); S = X;
			case 0x9B: shAbs(Y, A & X, true);
			case 0x9C: shAbs(X, Y);
			case 0x9D: ea = absIdx(X, true); wr(ea, A);
			case 0x9E: shAbs(Y, X);
			case 0x9F: shAbs(Y, A & X);
			case 0xA0: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); Y = v; setNz(Y);
			case 0xA1: ea = indX(); v = rd(ea); A = v; setNz(A);
			case 0xA2: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); X = v; setNz(X);
			case 0xA3: ea = indX(); v = rd(ea); A = v; X = v; setNz(v);
			case 0xA4: ea = fetch(); v = rd(ea); Y = v; setNz(Y);
			case 0xA5: ea = fetch(); v = rd(ea); A = v; setNz(A);
			case 0xA6: ea = fetch(); v = rd(ea); X = v; setNz(X);
			case 0xA7: ea = fetch(); v = rd(ea); A = v; X = v; setNz(v);
			case 0xA8: rd(PC); Y = A; setNz(Y);
			case 0xA9: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); A = v; setNz(A);
			case 0xAA: rd(PC); X = A; setNz(X);
			case 0xAB: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); A = (A | LXA_MAGIC) & v; X = A; setNz(A);
			case 0xAC: ea = fetch(); ea |= fetch() << 8; v = rd(ea); Y = v; setNz(Y);
			case 0xAD: ea = fetch(); ea |= fetch() << 8; v = rd(ea); A = v; setNz(A);
			case 0xAE: ea = fetch(); ea |= fetch() << 8; v = rd(ea); X = v; setNz(X);
			case 0xAF: ea = fetch(); ea |= fetch() << 8; v = rd(ea); A = v; X = v; setNz(v);
			case 0xB0: branch((P & 1) != 0);
			case 0xB1: ea = indY(false); v = rd(ea); A = v; setNz(A);
			case 0xB2: jammed = true;
			case 0xB3: ea = indY(false); v = rd(ea); A = v; X = v; setNz(v);
			case 0xB4: ea = zpIdx(X); v = rd(ea); Y = v; setNz(Y);
			case 0xB5: ea = zpIdx(X); v = rd(ea); A = v; setNz(A);
			case 0xB6: ea = zpIdx(Y); v = rd(ea); X = v; setNz(X);
			case 0xB7: ea = zpIdx(Y); v = rd(ea); A = v; X = v; setNz(v);
			case 0xB8: rd(PC); P &= 0xBF;
			case 0xB9: ea = absIdx(Y, false); v = rd(ea); A = v; setNz(A);
			case 0xBA: rd(PC); X = S; setNz(X);
			case 0xBB: ea = absIdx(Y, false); v = rd(ea); v &= S; A = v; X = v; S = v; setNz(v);
			case 0xBC: ea = absIdx(X, false); v = rd(ea); Y = v; setNz(Y);
			case 0xBD: ea = absIdx(X, false); v = rd(ea); A = v; setNz(A);
			case 0xBE: ea = absIdx(Y, false); v = rd(ea); X = v; setNz(X);
			case 0xBF: ea = absIdx(Y, false); v = rd(ea); A = v; X = v; setNz(v);
			case 0xC0: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); cmp(Y, v);
			case 0xC1: ea = indX(); v = rd(ea); cmp(A, v);
			case 0xC2: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea);
			case 0xC3: ea = indX(); v = rd(ea); wr(ea, v); r = (v - 1) & 255; cmp(A, r); wr(ea, r);
			case 0xC4: ea = fetch(); v = rd(ea); cmp(Y, v);
			case 0xC5: ea = fetch(); v = rd(ea); cmp(A, v);
			case 0xC6: ea = fetch(); v = rd(ea); wr(ea, v); r = (v - 1) & 255; setNz(r); wr(ea, r);
			case 0xC7: ea = fetch(); v = rd(ea); wr(ea, v); r = (v - 1) & 255; cmp(A, r); wr(ea, r);
			case 0xC8: rd(PC); Y = (Y + 1) & 255; setNz(Y);
			case 0xC9: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); cmp(A, v);
			case 0xCA: rd(PC); X = (X - 1) & 255; setNz(X);
			case 0xCB: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); var t = (A & X) - v; P = (P & 0xFE) | (t >= 0 ? 1 : 0); X = t & 255; setNz(X);
			case 0xCC: ea = fetch(); ea |= fetch() << 8; v = rd(ea); cmp(Y, v);
			case 0xCD: ea = fetch(); ea |= fetch() << 8; v = rd(ea); cmp(A, v);
			case 0xCE: ea = fetch(); ea |= fetch() << 8; v = rd(ea); wr(ea, v); r = (v - 1) & 255; setNz(r); wr(ea, r);
			case 0xCF: ea = fetch(); ea |= fetch() << 8; v = rd(ea); wr(ea, v); r = (v - 1) & 255; cmp(A, r); wr(ea, r);
			case 0xD0: branch((P & 2) == 0);
			case 0xD1: ea = indY(false); v = rd(ea); cmp(A, v);
			case 0xD2: jammed = true;
			case 0xD3: ea = indY(true); v = rd(ea); wr(ea, v); r = (v - 1) & 255; cmp(A, r); wr(ea, r);
			case 0xD4: ea = zpIdx(X); v = rd(ea);
			case 0xD5: ea = zpIdx(X); v = rd(ea); cmp(A, v);
			case 0xD6: ea = zpIdx(X); v = rd(ea); wr(ea, v); r = (v - 1) & 255; setNz(r); wr(ea, r);
			case 0xD7: ea = zpIdx(X); v = rd(ea); wr(ea, v); r = (v - 1) & 255; cmp(A, r); wr(ea, r);
			case 0xD8: rd(PC); P &= 0xF7;
			case 0xD9: ea = absIdx(Y, false); v = rd(ea); cmp(A, v);
			case 0xDA: rd(PC);
			case 0xDB: ea = absIdx(Y, true); v = rd(ea); wr(ea, v); r = (v - 1) & 255; cmp(A, r); wr(ea, r);
			case 0xDC: ea = absIdx(X, false); v = rd(ea);
			case 0xDD: ea = absIdx(X, false); v = rd(ea); cmp(A, v);
			case 0xDE: ea = absIdx(X, true); v = rd(ea); wr(ea, v); r = (v - 1) & 255; setNz(r); wr(ea, r);
			case 0xDF: ea = absIdx(X, true); v = rd(ea); wr(ea, v); r = (v - 1) & 255; cmp(A, r); wr(ea, r);
			case 0xE0: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); cmp(X, v);
			case 0xE1: ea = indX(); v = rd(ea); adc(v ^ 255);
			case 0xE2: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea);
			case 0xE3: ea = indX(); v = rd(ea); wr(ea, v); r = (v + 1) & 255; adc(r ^ 255); wr(ea, r);
			case 0xE4: ea = fetch(); v = rd(ea); cmp(X, v);
			case 0xE5: ea = fetch(); v = rd(ea); adc(v ^ 255);
			case 0xE6: ea = fetch(); v = rd(ea); wr(ea, v); r = (v + 1) & 255; setNz(r); wr(ea, r);
			case 0xE7: ea = fetch(); v = rd(ea); wr(ea, v); r = (v + 1) & 255; adc(r ^ 255); wr(ea, r);
			case 0xE8: rd(PC); X = (X + 1) & 255; setNz(X);
			case 0xE9: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); adc(v ^ 255);
			case 0xEA: rd(PC);
			case 0xEB: ea = PC; PC = (PC + 1) & 0xFFFF; v = rd(ea); adc(v ^ 255);
			case 0xEC: ea = fetch(); ea |= fetch() << 8; v = rd(ea); cmp(X, v);
			case 0xED: ea = fetch(); ea |= fetch() << 8; v = rd(ea); adc(v ^ 255);
			case 0xEE: ea = fetch(); ea |= fetch() << 8; v = rd(ea); wr(ea, v); r = (v + 1) & 255; setNz(r); wr(ea, r);
			case 0xEF: ea = fetch(); ea |= fetch() << 8; v = rd(ea); wr(ea, v); r = (v + 1) & 255; adc(r ^ 255); wr(ea, r);
			case 0xF0: branch((P & 2) != 0);
			case 0xF1: ea = indY(false); v = rd(ea); adc(v ^ 255);
			case 0xF2: jammed = true;
			case 0xF3: ea = indY(true); v = rd(ea); wr(ea, v); r = (v + 1) & 255; adc(r ^ 255); wr(ea, r);
			case 0xF4: ea = zpIdx(X); v = rd(ea);
			case 0xF5: ea = zpIdx(X); v = rd(ea); adc(v ^ 255);
			case 0xF6: ea = zpIdx(X); v = rd(ea); wr(ea, v); r = (v + 1) & 255; setNz(r); wr(ea, r);
			case 0xF7: ea = zpIdx(X); v = rd(ea); wr(ea, v); r = (v + 1) & 255; adc(r ^ 255); wr(ea, r);
			case 0xF8: rd(PC); P |= 8;
			case 0xF9: ea = absIdx(Y, false); v = rd(ea); adc(v ^ 255);
			case 0xFA: rd(PC);
			case 0xFB: ea = absIdx(Y, true); v = rd(ea); wr(ea, v); r = (v + 1) & 255; adc(r ^ 255); wr(ea, r);
			case 0xFC: ea = absIdx(X, false); v = rd(ea);
			case 0xFD: ea = absIdx(X, false); v = rd(ea); adc(v ^ 255);
			case 0xFE: ea = absIdx(X, true); v = rd(ea); wr(ea, v); r = (v + 1) & 255; setNz(r); wr(ea, r);
			case 0xFF: ea = absIdx(X, true); v = rd(ea); wr(ea, v); r = (v + 1) & 255; adc(r ^ 255); wr(ea, r);
			default:
		}
	}
	var maskEff = 0;
	var maskNext = 0;

	inline function updateNmi():Void
		nmiLine = (ppustatus & 0x80) != 0 && (ppuctrl & 0x80) != 0;

	function ppuBusRead():Int {
		var v = ppuBus;
		for (i in 0...8)
			if (frameCount - ppuBusStamp[i] > 36)
				v &= ~(1 << i);
		ppuBus = v;
		return v;
	}

	function ppuBusRefresh(v:Int, mask:Int):Void {
		ppuBus = (ppuBus & ~mask) | (v & mask);
		for (i in 0...8)
			if (((mask >> i) & 1) != 0)
				ppuBusStamp[i] = frameCount;
	}

	inline function palIdx(a:Int):Int
		return (((a & 19) == 16) ? (a ^ 16) : a) & 31;

	function vramRead(a:Int):Int {
		a &= 0x3FFF;
		if (a < 0x2000)
			return chrRead(a);
		if (a < 0x3F00)
			return vram[ntIndex(a & 0x2FFF)];
		return palette_ram[palIdx(a)] & ((ppumask & 1) != 0 ? 0x30 : 0x3F);
	}

	function incX():Void
		V = (V & 31) == 31 ? ((V & ~31) ^ 1024) : (V + 1);

	function incY():Void {
		V = (V & (7 << 12)) != (7 << 12) ? (V + 4096)
			: (V & 0x3e0) == 928 ? ((V & 0x8c1f) ^ 2048)
			: (V & 0x3e0) == 0x3e0 ? (V & 0x8c1f)
			: ((V & 0x8c1f) | ((V + 32) & 0x3e0));
	}

	function vramStep():Void {
		if (scany >= 240 && scany != preLine || (ppumask & 24) == 0)
			V = (V + ((ppuctrl & 4) != 0 ? 32 : 1)) & 0x7FFF;
		else {
			incX();
			incY();
		}
	}

	function oamRead():Int {
		if ((scany < 240 || scany == preLine) && (ppumask & 24) != 0) {
			if (dot >= 257 && dot <= 320) {
				var ph = (dot - 257) & 7;
				oam2Addr = ((dot - 257) >> 3) * 4 + (ph > 3 ? 3 : ph);
				oamBuf = oam2[oam2Addr & 31];
			}
			return oamBuf;
		}
		return oam[oamAddr];
	}

	function ppuRegRead(r:Int):Int {
		cPpuRd++;
		switch (r) {
			case 2:
				var v = (ppustatus & 0xE0) | (ppuBusRead() & 0x1F);
				ppustatus &= 0x7F;
				W = 0;
				if (scany == 241 && dot == 1)
					preventVbl = true;
				updateNmi();
				ppuBusRefresh(v, 0xE0);
				return v;
			case 4:
				var v = oamRead();
				ppuBusRefresh(v, 0xFF);
				return v;
			case 7:
				if (ignoreVramRead > 0)
					return ppubuf;
				var a = V & 0x3FFF;
				var v = 0;
				if (a >= 0x3F00) {
					v = (palette_ram[palIdx(a)] & ((ppumask & 1) != 0 ? 0x30 : 0x3F)) | (ppuBusRead() & 0xC0);
					ppuBusRefresh(v, 0x3F);
					ppubuf = vram[ntIndex(a & 0x2FFF)];
				} else {
					v = ppubuf;
					ppubuf = vramRead(a);
					ppuBusRefresh(v, 0xFF);
				}
				vramStep();
				ignoreVramRead = 6;
				return v;
			default:
				return ppuBusRead();
		}
	}

	function ppuRegWrite(r:Int, v:Int):Void {
		cPpuWr++;
		if (dbg)
			dbgPpuWrite(r, v);
		ppuBusRefresh(v, 0xFF);
		switch (r) {
			case 0:
				ppuctrl = v;
				T = (T & 0xf3ff) | ((v & 3) << 10);
				updateNmi();
			case 1:
				ppumask = v;
			case 3:
				oamAddr = v;
			case 4:
				if ((scany >= 240 && scany != preLine) || (ppumask & 24) == 0) {
					if ((oamAddr & 3) == 2)
						v &= 0xE3;
					oam[oamAddr] = v;
					oamAddr = (oamAddr + 1) & 255;
				} else
					oamAddr = (oamAddr + 4) & 255;
			case 5:
				W ^= 1;
				if (W != 0) {
					fine_x = v & 7;
					T = (T & 0xFFE0) | (v >> 3);
				} else
					T = (T & 0x8c1f) | ((v & 7) << 12) | ((v << 2) & 0x3e0);
			case 6:
				W ^= 1;
				if (W != 0)
					T = (T & 0xff) | ((v & 63) << 8);
				else {
					T = (T & 0xff00) | v;
					vramPending = T;
					vramDelay = 3;
				}
			case 7:
				var a = V & 0x3FFF;
				if (a >= 0x3F00)
					palette_ram[palIdx(a)] = v & 0x3F;
				else if (a < 0x2000) {
					if (chrIsRam)
						chrWrite(a, v);
				} else
					vram[ntIndex(a & 0x2FFF)] = v;
				vramStep();
			default:
		}
	}

	function spriteEval():Void {
		var d = dot;
		if (d < 65) {
			oamBuf = 0xFF;
			if (d >= 1)
				oam2[(d - 1) >> 1] = 0xFF;
			return;
		}
		if (d == 65) {
			sp0Added = false;
			spInRange = false;
			oam2Addr = 0;
			spOverflowBug = 0;
			spCopyDone = false;
			spAddrH = (oamAddr >> 2) & 0x3F;
			spAddrL = oamAddr & 3;
		} else if (d == 256) {
			sp0Visible = sp0Added;
			spCount = oam2Addr >> 2;
		}
		if ((d & 1) != 0) {
			oamBuf = oam[oamAddr];
			return;
		}
		if (spCopyDone) {
			spAddrH = (spAddrH + 1) & 0x3F;
			if (oam2Addr >= 0x20)
				oamBuf = oam2[oam2Addr & 0x1F];
		} else {
			var h = (ppuctrl & 32) != 0 ? 16 : 8;
			if (!spInRange && scany >= oamBuf && scany < oamBuf + h)
				spInRange = true;
			if (oam2Addr < 0x20) {
				oam2[oam2Addr] = oamBuf;
				if (spInRange) {
					spAddrL++;
					oam2Addr++;
					if (spAddrH == 0)
						sp0Added = true;
					if ((oam2Addr & 3) == 0) {
						spInRange = false;
						spAddrL = 0;
						spAddrH = (spAddrH + 1) & 0x3F;
						if (spAddrH == 0)
							spCopyDone = true;
					}
				} else {
					spAddrH = (spAddrH + 1) & 0x3F;
					if (spAddrH == 0)
						spCopyDone = true;
				}
			} else {
				oamBuf = oam2[oam2Addr & 0x1F];
				if (spInRange) {
					ppustatus |= 0x20;
					spAddrL++;
					if (spAddrL == 4) {
						spAddrH = (spAddrH + 1) & 0x3F;
						spAddrL = 0;
					}
					if (spOverflowBug == 0)
						spOverflowBug = 3;
					else if (spOverflowBug > 0) {
						spOverflowBug--;
						if (spOverflowBug == 0) {
							spCopyDone = true;
							spAddrL = 0;
						}
					}
				} else {
					spAddrH = (spAddrH + 1) & 0x3F;
					spAddrL = (spAddrL + 1) & 3;
					if (spAddrH == 0)
						spCopyDone = true;
				}
			}
		}
		oamAddr = (spAddrL & 3) | (spAddrH << 2);
	}

	function spriteFetch(k:Int):Void {
		var big = (ppuctrl & 32) != 0;
		var y = oam2[k * 4];
		var tile = oam2[k * 4 + 1];
		var attr = oam2[k * 4 + 2];
		var row = scany - y;
		if (k >= spCount || y >= 240 || row < 0 || row >= (big ? 16 : 8)) {
			var a = big ? 0x1FF0 : (((ppuctrl & 8) << 9) | 0x0FF0);
			chrRead(a);
			chrRead(a + 8);
			if (k < 8) {
				spX[k] = 0xFF;
				spLo[k] = 0;
				spHi[k] = 0;
				spAttr[k] = 0;
			}
			return;
		}
		if ((attr & 0x80) != 0)
			row = (big ? 15 : 7) - row;
		var addr = big ? (((tile & 1) << 12) | ((tile & 0xFE) << 4) | ((row & 8) << 1) | (row & 7)) : (((ppuctrl & 8) << 9) | (tile << 4) | row);
		spX[k] = oam2[k * 4 + 3];
		spAttr[k] = attr;
		spLo[k] = chrRead(addr);
		spHi[k] = chrRead(addr + 8);
	}

	function renderDot(vis:Bool):Void {
		var d = dot;
		if ((d >= 2 && d <= 257) || (d >= 322 && d <= 337)) {
			bgLo = (bgLo << 1) & 0xFFFF;
			bgHi = (bgHi << 1) & 0xFFFF;
			atLo = (atLo << 1) & 0xFFFF;
			atHi = (atHi << 1) & 0xFFFF;
		}
		if ((d & 7) == 1 && ((d >= 9 && d <= 257) || d == 329 || d == 337)) {
			bgLo = (bgLo & 0xFF00) | ptbLo;
			bgHi = (bgHi & 0xFF00) | ptbHi;
			atLo = (atLo & 0xFF00) | ((atb & 1) != 0 ? 0xFF : 0);
			atHi = (atHi & 0xFF00) | ((atb & 2) != 0 ? 0xFF : 0);
		}
		if ((d >= 1 && d <= 256) || (d >= 321 && d <= 336)) {
			switch (d & 7) {
				case 1:
					ntb = vramRead(0x2000 | (V & 0x0FFF));
				case 3:
					var at = vramRead(0x23C0 | (V & 0x0C00) | ((V >> 4) & 0x38) | ((V >> 2) & 7));
					atb = (at >> (((V >> 4) & 4) | (V & 2))) & 3;
				case 5:
					ptbLo = chrRead(((ppuctrl & 0x10) << 8) | (ntb << 4) | ((V >> 12) & 7));
				case 7:
					ptbHi = chrRead(((ppuctrl & 0x10) << 8) | (ntb << 4) | ((V >> 12) & 7) | 8);
				case 0:
					incX();
					if (d == 256)
						incY();
				default:
			}
		}
		if (d == 257)
			V = (V & ~0x41F) | (T & 0x41F);
		if (!vis && d >= 280 && d <= 304)
			V = (V & 0x841F) | (T & 0x7BE0);
		if (vis && d <= 256)
			spriteEval();
		if (d >= 257 && d <= 320) {
			oamAddr = 0;
			if (((d - 260) & 7) == 0) {
				if (d == 260 && (rombuf[6] >> 4) == 4)
					mmc3Clock();
				spriteFetch((d - 260) >> 3);
			}
		}
		if (d == 321)
			oamBuf = oam2[0];
		if (!vis && d == 1) {
			spCount = 0;
			sp0Visible = false;
		}
	}

	function drawPixel():Void {
		var x = dot - 1;
		var ci = 0;
		if ((maskEff & 24) != 0) {
			var bgPix = 0;
			var pl = 0;
			if ((maskEff & 8) != 0 && (x >= 8 || (maskEff & 2) != 0)) {
				var bit = 0x8000 >> fine_x;
				bgPix = ((bgLo & bit) != 0 ? 1 : 0) | ((bgHi & bit) != 0 ? 2 : 0);
				pl = ((atLo & bit) != 0 ? 1 : 0) | ((atHi & bit) != 0 ? 2 : 0);
			}
			var spPix = 0;
			var spPal = 0;
			var spBehind = false;
			var spZero = false;
			if ((maskEff & 16) != 0 && (x >= 8 || (maskEff & 4) != 0)) {
				for (k in 0...spCount) {
					var sx = x - spX[k];
					if (sx >= 0 && sx < 8) {
						var attr = spAttr[k];
						var b = (attr & 64) != 0 ? sx : 7 - sx;
						var c = ((spLo[k] >> b) & 1) | (((spHi[k] >> b) & 1) << 1);
						if (c != 0) {
							spPix = c;
							spPal = 16 | ((attr & 3) << 2);
							spBehind = (attr & 32) != 0;
							spZero = k == 0 && sp0Visible;
							break;
						}
					}
				}
			}
			if (spPix != 0) {
				if (spZero && bgPix != 0 && x != 255 && (ppustatus & 0x40) == 0) {
					ppustatus |= 0x40;
					nS0++;
					if (dbg)
						dbgEvent("SPRITE-0 HIT at x=" + x + " y=" + scany);
				}
				ci = (bgPix == 0 || !spBehind) ? (spPal | spPix) : ((pl << 2) | bgPix);
			} else if (bgPix != 0)
				ci = (pl << 2) | bgPix;
		} else if ((V & 0x3F00) == 0x3F00)
			ci = V & 0x1F;
		frame[scany * 256 + x] = palRGB[palette_ram[palIdx(ci)] & ((ppumask & 1) != 0 ? 0x30 : 0x3F)];
	}

	function ppuStep():Void {
		if (vramDelay > 0 && --vramDelay == 0)
			V = vramPending;
		if (ignoreVramRead > 0)
			ignoreVramRead--;
		maskEff = maskNext;
		maskNext = ppumask;
		renderOn = (maskEff & 24) != 0;
		var vis = scany < 240;
		if (vis || scany == preLine) {
			if (renderOn)
				renderDot(vis);
			if (vis && dot >= 1 && dot <= 256)
				drawPixel();
		}
		if (dot == 1) {
			if (scany == 241) {
				if (!preventVbl) {
					ppustatus |= 0x80;
					updateNmi();
				}
				preventVbl = false;
				frameDone = true;
				frameCount++;
				oddFrame = (frameCount & 1) != 0;
				lastFrameCycles = frameCycles;
				frameCycles = 0;
				lPpuWr = cPpuWr;
				lPpuRd = cPpuRd;
				lApuWr = cApuWr;
				lMapWr = cMapWr;
				lOam = cOam;
				lDmc = cDmc;
				cPpuWr = cPpuRd = cApuWr = cMapWr = cOam = cDmc = 0;
			} else if (scany == preLine) {
				ppustatus &= 0x1F;
				updateNmi();
			}
		}
		if (scany == preLine && dot == 339 && oddFrame && !pal && renderOn)
			dot = 340;
		if (++dot == 341) {
			dot = 0;
			if (++scany == lines)
				scany = 0;
		}
	}

	function apuStatus():Int {
		var s = 0;
		for (i in 0...4)
			if (lenCnt[i] > 0)
				s |= 1 << i;
		if (dRemain > 0)
			s |= 16;
		if ((irqSources & 1) != 0)
			s |= 0x40;
		if ((irqSources & 2) != 0)
			s |= 0x80;
		s |= openBus & 0x20;
		irqSources &= ~1;
		return s;
	}

	function loadLen(i:Int, idx:Int):Void {
		if ((apuEn & (1 << i)) != 0) {
			lenReload[i] = LENGTH[idx];
			lenPrev[i] = lenCnt[i];
		}
	}

	function apuWrite(r:Int, v:Int):Void {
		cApuWr++;
		switch (r) {
			case 0x00, 0x04:
				var i = r >> 2;
				pDuty[i] = v >> 6;
				lenHaltNew[i] = (v >> 5) & 1;
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
				loadLen(i, v >> 3);
				pSeq[i] = 0;
				eStart[i] = 1;
			case 0x08:
				lenHaltNew[2] = v >> 7;
				tLinearReload = v & 0x7F;
			case 0x0A:
				tPeriod = (tPeriod & 0x700) | v;
				tInc = 1.0 / (tPeriod + 1);
			case 0x0B:
				tPeriod = (tPeriod & 0xFF) | ((v & 7) << 8);
				tInc = 1.0 / (tPeriod + 1);
				loadLen(2, v >> 3);
				tReloadFlag = 1;
			case 0x0C:
				lenHaltNew[3] = (v >> 5) & 1;
				eConst[3] = (v >> 4) & 1;
				eVol[3] = v & 15;
			case 0x0E:
				nMode = v >> 7;
				nIdx = v & 15;
			case 0x0F:
				loadLen(3, v >> 3);
				eStart[3] = 1;
			case 0x10:
				dIrqEn = v >> 7;
				if (dIrqEn == 0)
					irqSources &= ~2;
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
				irqSources &= ~2;
				if ((v & 16) != 0) {
					if (dRemain == 0) {
						dCur = dAddr;
						dRemain = dLen;
						dStartDelay = (cycleCount & 1) == 0 ? 3 : 2;
					}
				} else {
					dRemain = 0;
					dStartDelay = 0;
					dmcDmaStop();
				}
			case 0x17:
				fcNew = v;
				fcDelay = (cycleCount & 1) == 0 ? 3 : 4;
				fcInhibit = (v & 0x40) != 0;
				if (fcInhibit)
					irqSources &= ~1;
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

	function dmcDmaDone(v:Int):Void {
		dBuf = v;
		dBufFull = true;
		dCur = ((dCur + 1) & 0xFFFF) | 0x8000;
		if (--dRemain == 0) {
			if (dLoop != 0) {
				dCur = dAddr;
				dRemain = dLen;
			} else if (dIrqEn != 0)
				irqSources |= 2;
		}
	}

	inline function dmcFill():Void {
		if (!dBufFull && dRemain > 0)
			dmcDmaRequest();
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
				dmcFill();
			} else
				dSilence = true;
		}
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

	function apuStep():Void {
		fcCycle++;
		if (fcCycle == fcTab[fcMode][fcStep]) {
			var ty = FC_TYPE[fcStep];
			if (fcMode == 0 && fcStep >= 3 && !fcInhibit)
				irqSources |= 1;
			if (ty >= 1) {
				clockQuarter();
				if (ty == 2)
					clockHalf();
			}
			if (++fcStep == 6) {
				fcStep = 0;
				fcCycle = 0;
			}
		}
		if (fcNew >= 0 && --fcDelay == 0) {
			fcMode = fcNew >> 7;
			fcNew = -1;
			fcCycle = 0;
			fcStep = 0;
			if (fcMode == 1) {
				clockQuarter();
				clockHalf();
			}
		}
		for (i in 0...4) {
			if (lenReload[i] != 0) {
				if (lenCnt[i] == lenPrev[i])
					lenCnt[i] = lenReload[i];
				lenReload[i] = 0;
			}
			lenHalt[i] = lenHaltNew[i];
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
		if (dStartDelay > 0 && --dStartDelay == 0)
			dmcFill();
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
		if (aw - ar >= AUDIO_SIZE) {
			overruns++;
			return;
		}
		audioBuf[aw & AUDIO_MASK] = v;
		aw++;
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

	public function audioAvailable():Int
		return aw - ar;

	public function needsFrame():Bool
		return aw - ar < AUDIO_LOW;

	public function canRunFrame():Bool
		return aw - ar < AUDIO_HIGH;

	public function popSample():Float {
		audioLive = true;
		var avail = aw - ar;
		if (!primed) {
			if (avail < AUDIO_TARGET)
				return 0.0;
			primed = true;
		}
		if (avail < 2) {
			underruns++;
			primed = false;
			rFrac = 0.0;
			lastOut *= 0.98;
			return lastOut;
		}
		var a = audioBuf[ar & AUDIO_MASK];
		var b = audioBuf[(ar + 1) & AUDIO_MASK];
		var out = a + (b - a) * rFrac;
		var err = (avail - AUDIO_TARGET) / AUDIO_TARGET;
		if (err > 1.0)
			err = 1.0;
		else if (err < -1.0)
			err = -1.0;
		rFrac += 1.0 + err * 0.005;
		var adv = Std.int(rFrac);
		if (adv > 0) {
			rFrac -= adv;
			ar += adv;
		}
		lastOut = out;
		return out;
	}
}
