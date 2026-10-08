// =================================================================================================
//
//	Syrinx - Sound Manager
//	Copyright (c) 2019-2026 Aurelien Da Campo (Adolio), All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package ch.adolio.sound.test
{
	import ch.adolio.sound.WavTrack;
	import ch.adolio.test.Assert;
	import ch.adolio.test.ITest;
	import flash.errors.IllegalOperationError;
	import flash.utils.ByteArray;

	/**
	 * Parsing of the supported WAVE formats, with & without pre-decoding, sample extraction & rejection of the
	 * unsupported formats.
	 *
	 * Files come from <code>WavBuilder</code>: the left channel is a saw tooth, the right channel its inverse halved.
	 */
	public class WavTrackTest implements ITest
	{
		private static const SAMPLES_COUNT:int = 3000;
		private static const PCM16_EPSILON:Number = 1.0 / WavBuilder.PCM16_SCALE;
		private static const FLOAT_EPSILON:Number = 0.000001;

		public function execute():void
		{
			testFormats(false);
			testFormats(true);
			testExtractionFromPosition();
			testExtractionFromFractionalPosition();
			testExtractionNearEnd();
			testUnknownChunkSkipped();
			testUnsupportedFormatsRejected();
		}

		private function testFormats(predecode:Boolean):void
		{
			var context:String = predecode ? " (pre-decoded)" : "";
			assertFormat(1, WavBuilder.FORMAT_PCM, 16, predecode, PCM16_EPSILON, "PCM 16 bits mono" + context);
			assertFormat(2, WavBuilder.FORMAT_PCM, 16, predecode, PCM16_EPSILON, "PCM 16 bits stereo" + context);
			assertFormat(1, WavBuilder.FORMAT_IEEE_FLOAT, 32, predecode, FLOAT_EPSILON, "IEEE float 32 bits mono" + context);
			assertFormat(2, WavBuilder.FORMAT_IEEE_FLOAT, 32, predecode, FLOAT_EPSILON, "IEEE float 32 bits stereo" + context);
		}

		private function testExtractionFromPosition():void
		{
			for each (var predecode:Boolean in [false, true])
			{
				var track:WavTrack = new WavTrack(buildFile(2, WavBuilder.FORMAT_IEEE_FLOAT, 32), predecode);
				var target:ByteArray = new ByteArray();
				Assert.equalsInt(track.extract(target, 500, 1000), 500, "Samples extracted from position 1000");
				assertExtractedSamples(target, 2, 1000, 500, FLOAT_EPSILON, "Extraction from position 1000, pre-decoding: " + predecode);
			}
		}

		private function testExtractionFromFractionalPosition():void
		{
			for each (var predecode:Boolean in [false, true])
			{
				for each (var position:Number in [1000.3, 1000.5])
				{
					var context:String = "Extraction from position " + position + ", pre-decoding: " + predecode;
					assertExtractionFromSample1000(1, WavBuilder.FORMAT_PCM, 16, predecode, position, PCM16_EPSILON, "PCM 16 bits mono. " + context);
					assertExtractionFromSample1000(2, WavBuilder.FORMAT_PCM, 16, predecode, position, PCM16_EPSILON, "PCM 16 bits stereo. " + context);
					assertExtractionFromSample1000(1, WavBuilder.FORMAT_IEEE_FLOAT, 32, predecode, position, FLOAT_EPSILON, "IEEE float 32 bits mono. " + context);
					assertExtractionFromSample1000(2, WavBuilder.FORMAT_IEEE_FLOAT, 32, predecode, position, FLOAT_EPSILON, "IEEE float 32 bits stereo. " + context);
				}
			}
		}

		private function testExtractionNearEnd():void
		{
			for each (var predecode:Boolean in [false, true])
			{
				var track:WavTrack = new WavTrack(buildFile(1, WavBuilder.FORMAT_PCM, 16), predecode);
				var target:ByteArray = new ByteArray();
				Assert.equalsInt(track.extract(target, 1000, SAMPLES_COUNT - 200), 200, "Samples extracted near the end, pre-decoding: " + predecode);
				Assert.equalsInt(target.length, 200 * 8, "Bytes written near the end, pre-decoding: " + predecode);
				assertExtractedSamples(target, 1, SAMPLES_COUNT - 200, 200, PCM16_EPSILON, "Extraction near the end, pre-decoding: " + predecode);
			}
		}

		private function testUnknownChunkSkipped():void
		{
			var file:ByteArray = WavBuilder.build(createSamples(2), 2, WavBuilder.FORMAT_PCM, 16, 44100, true);
			var track:WavTrack = new WavTrack(file);
			Assert.equalsNumber(track.length, SAMPLES_COUNT / ProbeTrack.SAMPLE_RATE_MS, FLOAT_EPSILON, "Length with an unknown chunk");

			var target:ByteArray = new ByteArray();
			track.extract(target, SAMPLES_COUNT, 0);
			assertExtractedSamples(target, 2, 0, SAMPLES_COUNT, PCM16_EPSILON, "Extraction with an unknown chunk");
		}

		private function testUnsupportedFormatsRejected():void
		{
			assertRejected(2, WavBuilder.FORMAT_PCM, 16, 48000, "48 kHz");
			assertRejected(2, WavBuilder.FORMAT_PCM, 16, 22050, "22.05 kHz");
			assertRejected(2, WavBuilder.FORMAT_PCM, 8, 44100, "PCM 8 bits");
			assertRejected(2, WavBuilder.FORMAT_PCM, 24, 44100, "PCM 24 bits");
			assertRejected(2, WavBuilder.FORMAT_IEEE_FLOAT, 64, 44100, "IEEE float 64 bits");
			assertRejected(3, WavBuilder.FORMAT_PCM, 16, 44100, "3 channels");
			assertRejected(2, WavBuilder.FORMAT_ADPCM, 4, 44100, "ADPCM");
			assertRejected(2, WavBuilder.FORMAT_EXTENSIBLE, 16, 44100, "Extensible format");
		}

		//---------------------------------------------------------------------
		//-- Helpers
		//---------------------------------------------------------------------

		private function assertFormat(channels:int, audioFormat:int, bitsPerSample:int, predecode:Boolean, epsilon:Number, context:String):void
		{
			var track:WavTrack = new WavTrack(buildFile(channels, audioFormat, bitsPerSample), predecode);
			Assert.equalsNumber(track.length, SAMPLES_COUNT / ProbeTrack.SAMPLE_RATE_MS, FLOAT_EPSILON, "Length. " + context);

			var target:ByteArray = new ByteArray();
			Assert.equalsInt(track.extract(target, SAMPLES_COUNT, 0), SAMPLES_COUNT, "Samples extracted. " + context);
			Assert.equalsInt(target.length, SAMPLES_COUNT * 8, "Bytes written. " + context);
			assertExtractedSamples(target, channels, 0, SAMPLES_COUNT, epsilon, context);

			track.destroy();
		}

		/**
		 * Checks that an extraction from a position between the samples 1000 & 1001 starts on the sample 1000.
		 */
		private function assertExtractionFromSample1000(channels:int, audioFormat:int, bitsPerSample:int, predecode:Boolean, position:Number, epsilon:Number, context:String):void
		{
			var track:WavTrack = new WavTrack(buildFile(channels, audioFormat, bitsPerSample), predecode);
			var target:ByteArray = new ByteArray();
			Assert.equalsInt(track.extract(target, 500, position), 500, "Samples extracted. " + context);
			assertExtractedSamples(target, channels, 1000, 500, epsilon, context);
		}

		private function assertRejected(channels:int, audioFormat:int, bitsPerSample:int, sampleRate:int, context:String):void
		{
			var file:ByteArray = WavBuilder.build(createSamples(channels), channels, audioFormat, bitsPerSample, sampleRate);
			Assert.throws(IllegalOperationError, function():void
			{
				new WavTrack(file);
			}, context);
		}

		/**
		 * Checks extracted stereo floats against the generated values: a mono file must give the same value on both sides.
		 */
		private function assertExtractedSamples(target:ByteArray, channels:int, firstSample:int, count:int, epsilon:Number, context:String):void
		{
			target.position = 0;
			for (var i:int = firstSample; i < firstSample + count; ++i)
			{
				var left:Number = target.readFloat();
				var right:Number = target.readFloat();
				Assert.equalsNumber(left, leftValue(i), epsilon, "Left sample " + i + ". " + context);
				Assert.equalsNumber(right, channels == 1 ? leftValue(i) : rightValue(i), epsilon, "Right sample " + i + ". " + context);
			}
		}

		private function buildFile(channels:int, audioFormat:int, bitsPerSample:int):ByteArray
		{
			return WavBuilder.build(createSamples(channels), channels, audioFormat, bitsPerSample);
		}

		private function createSamples(channels:int):Vector.<Number>
		{
			var samples:Vector.<Number> = new Vector.<Number>();
			for (var i:int = 0; i < SAMPLES_COUNT; ++i)
			{
				samples.push(leftValue(i));

				if (channels > 1)
					samples.push(rightValue(i));

				for (var c:int = 2; c < channels; ++c)
					samples.push(0);
			}

			return samples;
		}

		private static function leftValue(index:int):Number
		{
			return ((index % 200) - 100) / 128; // Multiples of 1/128: exact in 32-bit float
		}

		private static function rightValue(index:int):Number
		{
			return -leftValue(index) / 2;
		}
	}
}
