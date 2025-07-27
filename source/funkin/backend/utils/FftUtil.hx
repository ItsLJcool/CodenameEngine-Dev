package funkin.backend.utils;

import openfl.display.BitmapData;
import flixel.sound.FlxSound;
import lime.media.AudioBuffer;

import flixel.util.FlxColor;

import funkin.backend.utils.CoolUtil;

class FftUtil extends FlxBasic {

    public var sound:FlxSound;
	private var buffer:AudioBuffer;

    public var bitmap:BitmapData;

    public var bars(default, set):Int = -1;
	private function set_bars(value:Int):Int {
        if (bars == value) return bars;
		
        var height = (incluceWaveform) ? 2 : 1;
        var width = (downsampleToBars) ? value : fftSize;
        bitmap = new BitmapData(width, height, false, 0x00000000);
		this.bars = value;
		return value;
	}

	public var fftSize(get, default):Int = 8;
	private function get_fftSize():Int { return Std.int(Math.max(Math.pow(2, fftSize), nextPowerOfTwo(this.bars * 2))); }

    public var intensity(get, default):Float = 1;
	private function get_intensity():Float { return Math.abs(this.intensity); }
	
    private var stepMs:Float = 35; // steps used for caching

    private var draw_cache:Array<Dynamic> = [];
    private var draw_slices:Array<Dynamic> = [];

    private var ready:Bool = false;

    public var downsampleToBars:Bool = true;
    private var incluceWaveform:Bool = false; // unsued for now

    public function new(sound:FlxSound, newBars:Int, ?intensity:Float = 1) {
		super();
        this.sound = sound;
        this.intensity = intensity;
		this.bars = newBars;
		
		@:privateAccess this.buffer = sound._sound.__buffer;

		cacheAudio();
    }

	/*
		Rendering and updating the bitmap
	*/
	private var prev_songTime:Float = 0;
	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		if (!ready) {
			// to keep updating the info
			prev_songTime = sound.time;
			return;
		}
		
		if ((sound.time % stepMs) < (prev_songTime % stepMs)) {

			var info = draw_slices[Std.int(sound.time / stepMs)];
			var array = draw_cache.slice(info.start, info.end);

			// trace('info: ${info.start} - ${info.end} | ${array.length}');

			for (x=>data in array) {
				var fftVal:Int = Std.int((data * 255) * intensity);
				if (fftVal > 255) fftVal = 255;
				bitmap.setPixel(x, 0, FlxColor.fromRGB(fftVal, fftVal, fftVal));
			}
		}

		prev_songTime = sound.time;
	}

	// start the cache
	public function cacheAudio() {
		ready = false;

		// clearing caches
		CoolUtil.clear(draw_cache);
        CoolUtil.clear(draw_slices);

		var t = 0.0;
		while (t < sound.length) {
			var info = computeBitmapBuffer(t);
			info.fftBins.push(-1);

			draw_cache = draw_cache.concat(info.fftBins);
			t += stepMs;
		}

		// get the instances of -1 in the buffer, and get their splits
        var start = 0;
        while (true) {
            var end = draw_cache.indexOf(-1, start);
            if (end == -1) break;
            draw_slices.push({start: start, end: end});
            start = end + 1;
        }

        ready = true;
	}

	// Compute the bitmap information
	private function computeBitmapBuffer(time:Float):{fftBins:Array<Float>, samples:Array<Float>} {
        var bytes = buffer.data.buffer;

        var sampleRate = buffer.sampleRate;
        var channels = buffer.channels;
        var bytesPerSample = buffer.bitsPerSample / 8;

        var currentSample = Std.int((time * 0.001) * sampleRate);
        var startSample = currentSample - Std.int(fftSize * 0.5);
        if (startSample < 0) startSample = 0;

        // Collect raw waveform samples
        var samples:Array<Float> = [];
		for (i in 0...fftSize) {
            var index = startSample + i;
            var byteIndex:Int = Std.int(index * bytesPerSample * channels);
            if (byteIndex + 1 >= bytes.length) break;

            // Read signed 16-bit
            var raw = bytes.getUInt16(byteIndex);
            if (raw > 32767) raw -= 65536;
            var normalized = raw / 32768.0;
            samples.push(normalized);
		}

        // Compute FFT
        var fftBins:Array<Float> = fft(samples);

        // if (downsampleToBars) fftBins = downsampleFFT(fftBins, bars);

        // if (downsampleToBars && incluceWaveform) samples = downsampleWaveform(samples, bars);

        return {fftBins: fftBins, samples: samples};
    }

	// FFT Functions
	public function fft(samples:Array<Float>):Array<Float> {
        var N = samples.length;
        if (N == 0 || (N & (N - 1)) != 0) {
            trace("FFT input size must be power of 2 and > 0");
            return [];
        }
        
        var bits = 0;
        while ((1 << bits) < N) bits++;
        
        var real:Array<Float> = [];
        var imag:Array<Float> = [];
        
        // Copy input with bit-reversed indexing
		for (i in 0...N) {
            var j = bitReverse(i, bits);
            real[j] = samples[i];
            imag[j] = 0;
		}
        
        // FFT iterative
        var size = 2;
        while (size <= N) {
            var halfSize = size >> 1;
            var tableStep = N / size;
            var k = 0;
            while (k < N) {
                var j = 0;
                while (j < halfSize) {
                    var angle = -2 * Math.PI * j / size;

					// we could use normal cos/sin, but I don't see a reasoning if the point of this FFT function is for being fast.
                    var wr = FlxMath.fastCos(angle);
                    var wi = FlxMath.fastSin(angle);
                    
                    var idx1 = k + j;
                    var idx2 = idx1 + halfSize;
                    
                    var treal = wr * real[idx2] - wi * imag[idx2];
                    var timag = wr * imag[idx2] + wi * real[idx2];
                    
                    real[idx2] = real[idx1] - treal;
                    imag[idx2] = imag[idx1] - timag;
                    
                    real[idx1] += treal;
                    imag[idx1] += timag;
                    
                    j++;
                }
                k += size;
            }
            size <<= 1;
        }
        
        // Compute magnitudes of first half (positive frequencies)
        var mags = [];
		var loop = N >> 1;
		for (i in 0...loop) {
            var mag = Math.sqrt(real[i] * real[i] + imag[i] * imag[i]);
            if (mag < 0.001) mag = 0;
            mags.push(mag);
		}

        return mags;
    }

	// This uses the DTF algorithm, so I believe log(O^N)?
	public function slowerFft(samples:Array<Float>):Array<Float> {
        var fftBins = [];
        var k = 0;
        while (k < (fftSize * 0.5)) {
            var real = 0.0;
            var imag = 0.0;
            var n = 0;
            while (n < fftSize) {
                var angle = 2 * Math.PI * k * n / fftSize;
				// still see a use in making it bareable to use
                real += samples[n] * FlxMath.fastCos(angle);
                imag -= samples[n] * FlxMath.fastSin(angle);
                n++;
            }
            var magnitude = Math.sqrt(real * real + imag * imag);
            fftBins.push(magnitude);
            k++;
        }
        return fftBins;
    }

	// downsampling functions
    private function downsampleFFT(samples:Array<Float>, barCount:Int):Array<Float> {
        var binsPerBar = samples.length / barCount;
        var downsampledFFT = [];
       	var i = 0;

        while (i < barCount) {
            var start = Std.int(i * binsPerBar);
            var end = Std.int((i + 1) * binsPerBar);
            if (end > samples.length) end = samples.length;

            var sum = 0.0;
            var count = 0;
            var j = start;
            while (j < end) {
                sum += samples[j];
                count++;
                j++;
            }
			var test = (count > 0) ? sum / count : 0;
            downsampledFFT.push(test);
            i++;
        }

        return downsampledFFT;
    }

    private function downsampleWaveform(samples:Array<Float>, barCount:Int):Array<Float> {
        var samplesPerBar = samples.length / barCount;
        var downsampledWaveform = [];
        var i = 0;
        while (i < barCount) {
            var start = Std.int(i * samplesPerBar);
            var end = Std.int((i + 1) * samplesPerBar);
            if (end > samples.length) end = samples.length;

            var sum = 0.0;
            var count = 0;
            var j = start;
            while (j < end) {
                sum += samples[j];
                count++;
                j++;
            }
            var avg = count > 0 ? sum / count : 0;
            downsampledWaveform.push((avg + 1.0) * 0.5); // to [0,1]
            i++;
        }
        return downsampledWaveform;
    }

	/*
		utils
	*/
    private function nextPowerOfTwo(x:Int):Int {
        var p = 1;
        while (p < x) p <<= 1;
        return p;
    }

	private function bitReverse(index:Int, bits:Int):Int {
        var rev = 0;
        var i = 0;
		for (i in 0...bits) {
            rev = (rev << 1) | (index & 1);
            index >>= 1;
		}
		
        return rev;
    }
}