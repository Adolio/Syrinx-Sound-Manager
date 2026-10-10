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
			testUnsupportedFormatReported();
			testFormatChunkSizes();
			testOddSizedChunksSkipped();
			testTruncatedDataUsed();
			testInvalidFilesRejected();
			testCorruptedChunkSizeRejected();
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

		private function testUnsupportedFormatReported():void
		{
			for each (var audioFormat:int in [WavBuilder.FORMAT_ADPCM, WavBuilder.FORMAT_EXTENSIBLE])
			{
				var message:String = "";
				try
				{
					new WavTrack(WavBuilder.build(createSamples(2), 2, audioFormat, 16));
				}
				catch (error:IllegalOperationError)
				{
					message = error.message;
				}

				Assert.isTrue(message.indexOf("Unsupported Wave Audio Format: " + audioFormat + ".") != -1, "Audio format given by the error. Message: " + message);
			}
		}

		private function testFormatChunkSizes():void
		{
			// Format chunks may hold an extension after their 16 base bytes
			for each (var size:int in [18, 40])
			{
				assertChunksParsed([
					WavBuilder.createFormatChunk(2, WavBuilder.FORMAT_PCM, 16, 44100, size),
					WavBuilder.createDataChunk(createSamples(2), WavBuilder.FORMAT_PCM, 16)],
					2, PCM16_EPSILON, "PCM 16 bits stereo with a format chunk of " + size + " bytes");

				assertChunksParsed([
					WavBuilder.createFormatChunk(1, WavBuilder.FORMAT_IEEE_FLOAT, 32, 44100, size),
					WavBuilder.createDataChunk(createSamples(1), WavBuilder.FORMAT_IEEE_FLOAT, 32)],
					1, FLOAT_EPSILON, "IEEE float 32 bits mono with a format chunk of " + size + " bytes");
			}
		}

		private function testOddSizedChunksSkipped():void
		{
			// A chunk of odd size is followed by a padding byte
			assertChunksParsed([
				WavBuilder.createFormatChunk(2),
				WavBuilder.createChunk("LIST", 5),
				WavBuilder.createDataChunk(createSamples(2)),
				WavBuilder.createChunk("id3 ", 3)],
				2, PCM16_EPSILON, "Chunks of odd size around the data");
		}

		private function testTruncatedDataUsed():void
		{
			// The data chunk declares more bytes than the file holds: the available samples are used
			for each (var declaredSize:Number in [SAMPLES_COUNT * 4 + 1000, 0xFFFFFFFF])
			{
				assertChunksParsed([
					WavBuilder.createFormatChunk(2),
					WavBuilder.createDataChunk(createSamples(2), WavBuilder.FORMAT_PCM, 16, declaredSize)],
					2, PCM16_EPSILON, "Data chunk declaring " + declaredSize + " bytes");
			}
		}

		private function testInvalidFilesRejected():void
		{
			var format:ByteArray = WavBuilder.createFormatChunk(2);
			var data:ByteArray = WavBuilder.createDataChunk(createSamples(2));

			assertFileRejected(new ByteArray(), "Empty file");
			assertFileRejected(WavBuilder.assemble([]), "File without chunk");
			assertFileRejected(WavBuilder.assemble([format, data], "RIFX"), "Not a RIFF file");
			assertFileRejected(WavBuilder.assemble([format, data], "RIFF", "AVI "), "Not a WAVE file");
			assertFileRejected(WavBuilder.assemble([data]), "No format chunk");
			assertFileRejected(WavBuilder.assemble([data, format]), "Data chunk before the format chunk");
			assertFileRejected(WavBuilder.assemble([format]), "No data chunk");
			assertFileRejected(WavBuilder.assemble([WavBuilder.createFormatChunk(2, WavBuilder.FORMAT_PCM, 16, 44100, 14), data]), "Format chunk too small");

			var header:ByteArray = WavBuilder.assemble([format, data]);
			header.length = 10;
			assertFileRejected(header, "File cut within its header");

			Assert.throws(ArgumentError, function():void { new WavTrack(null); }, "Null file");
		}

		private function testCorruptedChunkSizeRejected():void
		{
			// A size pointing far beyond the end of the file hides the data chunk
			assertFileRejected(WavBuilder.assemble([
				WavBuilder.createFormatChunk(2),
				WavBuilder.createChunk("JUNK", 0xFFFFFFF8, new ByteArray()),
				WavBuilder.createDataChunk(createSamples(2))]), "Chunk with a corrupted size");
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

		/**
		 * Checks that a file made of the given chunks gives the generated samples.
		 */
		private function assertChunksParsed(chunks:Array, channels:int, epsilon:Number, context:String):void
		{
			var track:WavTrack = new WavTrack(WavBuilder.assemble(chunks));
			Assert.equalsNumber(track.length, SAMPLES_COUNT / ProbeTrack.SAMPLE_RATE_MS, FLOAT_EPSILON, "Length. " + context);

			var target:ByteArray = new ByteArray();
			Assert.equalsInt(track.extract(target, SAMPLES_COUNT, 0), SAMPLES_COUNT, "Samples extracted. " + context);
			assertExtractedSamples(target, channels, 0, SAMPLES_COUNT, epsilon, context);
		}

		private function assertFileRejected(file:ByteArray, context:String):void
		{
			Assert.throws(IllegalOperationError, function():void
			{
				new WavTrack(file);
			}, context);
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
