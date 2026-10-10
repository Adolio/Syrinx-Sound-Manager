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
	 * Builds WAVE files in memory, either at once (<code>build</code>) or chunk by chunk (<code>assemble</code>) to
	 * get unusual or invalid files.
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
		 * @param samples Interleaved channel values, between -1 and 1
		 * @param extraChunkBeforeData Adds an even-sized <code>LIST</code> chunk between the format & data chunks
		 */
		public static function build(samples:Vector.<Number>, channels:int, audioFormat:int = FORMAT_PCM, bitsPerSample:int = 16,
			sampleRate:int = 44100, extraChunkBeforeData:Boolean = false):ByteArray
		{
			var chunks:Array = [createFormatChunk(channels, audioFormat, bitsPerSample, sampleRate)];
			if (extraChunkBeforeData)
				chunks.push(createChunk("LIST", 4));

			chunks.push(createDataChunk(samples, audioFormat, bitsPerSample));
			return assemble(chunks);
		}

		/**
		 * Assembles chunks into a file.
		 *
		 * @param chunks Chunks (<code>ByteArray</code>) written one after the other
		 * @param riffId Identifier of the file, <code>RIFF</code> for a valid file
		 * @param riffType Type of the file, <code>WAVE</code> for a valid file
		 */
		public static function assemble(chunks:Array, riffId:String = "RIFF", riffType:String = "WAVE"):ByteArray
		{
			var content:ByteArray = new ByteArray();
			for each (var chunk:ByteArray in chunks)
				content.writeBytes(chunk);

			var file:ByteArray = new ByteArray();
			file.endian = Endian.LITTLE_ENDIAN;
			file.writeUTFBytes(riffId);
			file.writeUnsignedInt(4 + content.length);
			file.writeUTFBytes(riffType);
			file.writeBytes(content);

			file.position = 0;
			return file;
		}

		/**
		 * Creates a format chunk.
		 *
		 * @param size Size of the chunk content: bytes beyond the 16 bytes of the base format are zeros, & a size
		 *             below 16 truncates the base format
		 */
		public static function createFormatChunk(channels:int, audioFormat:int = FORMAT_PCM, bitsPerSample:int = 16, sampleRate:int = 44100, size:int = 16):ByteArray
		{
			var blockAlign:int = channels * Math.ceil(bitsPerSample / 8);
			var content:ByteArray = new ByteArray();
			content.endian = Endian.LITTLE_ENDIAN;
			content.writeShort(audioFormat);
			content.writeShort(channels);
			content.writeUnsignedInt(sampleRate);
			content.writeUnsignedInt(sampleRate * blockAlign);
			content.writeShort(blockAlign);
			content.writeShort(bitsPerSample);
			content.length = size;

			return createChunk("fmt ", size, content);
		}

		/**
		 * Creates a data chunk.
		 *
		 * <p>Sample values are only encoded for 16-bit PCM & 32-bit IEEE float: other formats get silent data of the
		 * right size, which is enough to test their rejection.</p>
		 *
		 * @param samples Interleaved channel values, between -1 and 1
		 * @param declaredSize Size written in the chunk header, the actual size of the data when negative
		 */
		public static function createDataChunk(samples:Vector.<Number>, audioFormat:int = FORMAT_PCM, bitsPerSample:int = 16, declaredSize:Number = -1):ByteArray
		{
			var content:ByteArray = new ByteArray();
			content.endian = Endian.LITTLE_ENDIAN;
			var sample:Number;
			if (audioFormat == FORMAT_PCM && bitsPerSample == 16)
			{
				for each (sample in samples)
					content.writeShort(Math.round(sample * PCM16_SCALE));
			}
			else if (audioFormat == FORMAT_IEEE_FLOAT && bitsPerSample == 32)
			{
				for each (sample in samples)
					content.writeFloat(sample);
			}
			else
			{
				content.length = samples.length * Math.ceil(bitsPerSample / 8);
			}

			return createChunk("data", declaredSize < 0 ? content.length : declaredSize, content);
		}

		/**
		 * Creates a chunk: identifier, declared size, content & the padding byte following a content of odd size.
		 *
		 * @param declaredSize Size written in the chunk header
		 * @param content Content of the chunk, zeros of the declared size when null
		 */
		public static function createChunk(id:String, declaredSize:Number, content:ByteArray = null):ByteArray
		{
			if (!content)
			{
				content = new ByteArray();
				content.length = declaredSize;
			}

			var chunk:ByteArray = new ByteArray();
			chunk.endian = Endian.LITTLE_ENDIAN;
			chunk.writeUTFBytes(id);
			chunk.writeUnsignedInt(declaredSize);
			chunk.writeBytes(content);

			if (content.length % 2 == 1)
				chunk.writeByte(0);

			return chunk;
		}
	}
}
