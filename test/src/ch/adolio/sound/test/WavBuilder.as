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
	import flash.utils.ByteArray;
	import flash.utils.Endian;

	/**
	 * Builds WAVE files in memory.
	 */
	public class WavBuilder
	{
		public static const FORMAT_PCM:int = 0x0001;
		public static const FORMAT_ADPCM:int = 0x0002;
		public static const FORMAT_IEEE_FLOAT:int = 0x0003;
		public static const FORMAT_EXTENSIBLE:int = 0xFFFE;

		public static const PCM16_SCALE:Number = 32767; // Scale used to convert values to 16-bit integers & back

		/**
		 * Builds a WAVE file.
		 *
		 * <p>Sample values are only encoded for 16-bit PCM & 32-bit IEEE float: other formats get silent data of the
		 * right size, which is enough to test their rejection.</p>
		 *
		 * @param samples Interleaved channel values, between -1 and 1
		 * @param extraChunkBeforeData Adds an even-sized <code>LIST</code> chunk between the format & data chunks
		 */
		public static function build(samples:Vector.<Number>, channels:int, audioFormat:int = FORMAT_PCM, bitsPerSample:int = 16,
			sampleRate:int = 44100, extraChunkBeforeData:Boolean = false):ByteArray
		{
			// Data
			var data:ByteArray = new ByteArray();
			data.endian = Endian.LITTLE_ENDIAN;
			var sample:Number;
			if (audioFormat == FORMAT_PCM && bitsPerSample == 16)
			{
				for each (sample in samples)
					data.writeShort(Math.round(sample * PCM16_SCALE));
			}
			else if (audioFormat == FORMAT_IEEE_FLOAT && bitsPerSample == 32)
			{
				for each (sample in samples)
					data.writeFloat(sample);
			}
			else
			{
				data.length = samples.length * Math.ceil(bitsPerSample / 8);
			}

			// Header
			var blockAlign:int = channels * Math.ceil(bitsPerSample / 8);
			var extraChunkSize:int = extraChunkBeforeData ? 8 + 4 : 0;
			var file:ByteArray = new ByteArray();
			file.endian = Endian.LITTLE_ENDIAN;
			file.writeUTFBytes("RIFF");
			file.writeUnsignedInt(4 + (8 + 16) + extraChunkSize + (8 + data.length));
			file.writeUTFBytes("WAVE");

			// Format chunk
			file.writeUTFBytes("fmt ");
			file.writeUnsignedInt(16);
			file.writeShort(audioFormat);
			file.writeShort(channels);
			file.writeUnsignedInt(sampleRate);
			file.writeUnsignedInt(sampleRate * blockAlign);
			file.writeShort(blockAlign);
			file.writeShort(bitsPerSample);

			// Unknown chunk
			if (extraChunkBeforeData)
			{
				file.writeUTFBytes("LIST");
				file.writeUnsignedInt(4);
				file.writeUTFBytes("INFO");
			}

			// Data chunk
			file.writeUTFBytes("data");
			file.writeUnsignedInt(data.length);
			file.writeBytes(data);

			file.position = 0;
			return file;
		}
	}
}
