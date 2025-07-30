package funkin.backend.utils;

import flixel.sound.FlxSound;
import lime.media.AudioBuffer;

#if lime_vorbis
import lime.media.vorbis.Vorbis;
import lime.media.vorbis.VorbisFile;
import lime.utils.ArrayBuffer;
#end

// ORIGINAL CODES FROM YOSH & LUNAR https://github.com/CodenameCrew/YoshiCrafterEngine/blob/main/source/WaveformSprite.hx
// REWRITTEN BY RALTYRO
class AudioAnalyzer {
	public var sound:FlxSound;
	public var buffer:AudioBuffer;
	var __toBits:Float;
	var __wordSize:Int;
	var __bitUnsignedSize:Int;
	var __bitSize:Int;

	#if lime_vorbis
	var __vorbis:VorbisFile;
	#end

	public function new(sound:FlxSound) {
		this.sound = sound;
		__check();
	}

	inline function __check() if (sound.buffer != buffer) {
		__bitSize = 1 << ((buffer = sound.buffer).bitsPerSample - 1);
		__bitUnsignedSize = 1 << buffer.bitsPerSample;
		__toBits = buffer.sampleRate / 1000 * buffer.channels * (__wordSize = buffer.bitsPerSample >> 3);
		__vorbis = null;
	}

	public function analyze(startPos:Float, endPos:Float, ?outSeperate:Array<Float>):Float {
		__check();
		if (buffer.data != null) return __analyze(startPos, endPos, outSeperate);
		#if lime_vorbis
		else if (__prepareVorbis()) return __analyzeVorbis(startPos, endPos, outSeperate);
		#end
		return 0;
	}

	inline function __analyze(startPos:Float, endPos:Float, ?outSeperate:Array<Float>):Float {
		var pos = Math.floor(startPos * __toBits), end = Math.floor(endPos * __toBits), buf = buffer.data #if !js .buffer #end;
		var max = 0, b = 0, w = 0, c = 0, useSeperate = outSeperate != null;
		if (useSeperate) {
			while (c < outSeperate.length) outSeperate[c++] *= __bitSize;
			while (c++ < buffer.channels) outSeperate.push(0);
			c = Math.floor((pos % (__wordSize * buffer.channels)) / __wordSize);
		}

		pos -= pos % __wordSize;
		end -= end % __wordSize;

		while (pos < end) {
			// 8-bit audio data is unsigned (0 is 128, 128 is 256, -128 is 0)
			if (__wordSize == 1) b = #if js buf[pos++] #else buf.get(pos++) #end - __bitSize;
			else {
				while (w < buffer.bitsPerSample) {
					b |= #if js buf[pos] #else buf.get(pos) #end << w;
					w += 8;
					pos++;
				}
				if (b > __bitSize) b -= __bitUnsignedSize;
			}
			if (max < b) max = b;
			if (useSeperate) {
				if (outSeperate[c] < b) outSeperate[c] = b;
				if (++c > buffer.channels) c = 0;
			}
			w = b = 0;
		}

		return max / __bitSize;
	}

	#if lime_vorbis // As far i know, only native supports vorbis
	var __buffer:ArrayBuffer;
	var __bufferSize:Int;
	function __prepareVorbis():Bool @:privateAccess {
		if (buffer.__srcVorbisFile == null) return __vorbis != null;
		if (__vorbis != null) return true;
		if ((__vorbis = buffer.__srcVorbisFile.clone()) != null) { // IM HOPING IT HAVE A GC CLOSURE.
			__buffer = new ArrayBuffer(__bufferSize = 0x400 * buffer.channels * (buffer.bitsPerSample >> 3));
			return true;
		}
		return false;
	}

	inline function __analyzeVorbis(startPos:Float, endPos:Float, ?outSeperate:Array<Float>):Float @:privateAccess {
		var n = Math.floor((endPos - startPos) * __toBits);
		if ((n -= n % __wordSize) < __wordSize) return 0;

		var pos = 0, max = 0, b = 0, w = 0, c = 0, useSeperate = outSeperate != null;
		if (useSeperate) {
			while (c < outSeperate.length) outSeperate[c++] *= __bitSize;
			while (c++ < buffer.channels) outSeperate.push(0);
		}

		// IT SHOULD BE ALWAYS BACKEND.STREAMED IF THIS GETS CALLED.
		var backend = sound._source != null ? sound._source.__backend : null;
		if (backend != null && backend.streamTimer != null) {
			var i = backend.bufferSizes.length - backend.queuedBuffers;
			var time = backend.bufferTimes[i] * 1000;

			if (startPos >= time && startPos < backend.bufferTimes[backend.bufferSizes.length - 1] * 1000) {
				var buf = backend.bufferDatas[i].buffer, size = backend.bufferSizes[i];
				pos = Math.floor((startPos - time) * __toBits);
				c = Math.floor((pos % (__wordSize * buffer.channels)) / __wordSize);
				pos -= pos % __wordSize;

				while (n > 0) {
					if (__wordSize == 1) {
						b = buf.get(pos++) - __bitSize;
						n--;
					}
					else {
						while (w < buffer.bitsPerSample) {
							b |= buf.get(pos) << w;
							w += 8;
							pos++;
							n--;
						}
						if (b > __bitSize) b -= __bitUnsignedSize;
					}
					if (max < b) max = b;
					if (useSeperate) {
						if (outSeperate[c] < b) outSeperate[c] = b;
						if (++c > buffer.channels) c = 0;
					}
					if (pos >= size) {
						if (++i >= backend.bufferDatas.length) break;
						size = backend.bufferSizes[i];
						buf = backend.bufferDatas[i].buffer;
						pos = 0;
					}
					w = b = 0;
				}

				startPos = pos / __toBits + time;
				// Cannot inline a not final return
			}
		}
		if (n == 0) return max / __bitSize;

		if (Math.abs(startPos - __vorbis.timeTell() * 1000) > 4) {
			if (startPos < 1) __vorbis.rawSeek(0);
			else __vorbis.timeSeek(startPos / 1000);
		}

		pos = c = 0;
		var isBigEndian = lime.system.System.endianness == lime.system.Endian.BIG_ENDIAN, result;
		while (n > 0) {
			n -= (result = __vorbis.read(__buffer, 0, n < __bufferSize ? n : __bufferSize, isBigEndian, __wordSize, true));

			if (result == Vorbis.HOLE) continue;
			else if (result <= 0) break;

			while (pos < result) {
				if (__wordSize == 1) b = __buffer.get(pos++) - __bitSize;
				else {
					while (w < buffer.bitsPerSample) {
						b |= __buffer.get(pos) << w;
						w += 8;
						pos++;
					}
					if (b > __bitSize) b -= __bitUnsignedSize;
				}
				if (max < b) max = b;
				if (useSeperate) {
					if (outSeperate[c] < b) outSeperate[c] = b;
					if (++c > buffer.channels) c = 0;
				}
				w = b = 0;
			}
			pos = 0;
		}

		return max / __bitSize;
	}
	#end
}