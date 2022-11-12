// =================================================================================================
//
//	Syrinx - Sound Manager
//	Copyright (c) 2019-2022 Aurelien Da Campo (Adolio), All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package ch.adolio.sound
{
	import flash.errors.IllegalOperationError;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.getTimer;

	/**
	 * Wav sound data wrapper.
	 *
	 * Wave Format supported:
	 * - PCM 16 bits, 1 channel, 44100 Hz
	 * - PCM 16 bits, 2 channels, 44100 Hz
	 * - IEEE Float 32 bits, 1 channel, 44100 Hz
	 * - IEEE Float 32 bits, 2 channels, 44100 Hz
	 *
	 * @author Aurelien Da Campo
	 */
	public class WavTrack extends Track
	{
		// Descriptor
		private var _format:String;

		// Format
		private const WAVE_FORMAT_PCM:uint = 0x0001;
		private const WAVE_FORMAT_IEEE_FLOAT:uint = 0x0003;
		private var _fmtAudioFormat:uint;
		private var _fmtChannels:uint;
		private var _fmtSampleRate:int;
		private var _fmtByteRate:int;
		private var _fmtBlockAlign:int;
		private var _fmtBitsPerSample:int;

		// Data
		private var _dataSize:uint; // In bytes
		private var _dataSource:ByteArray; // Original data
		private var _dataStartPosition:uint; // Bytes position where data starts
		private var _length:Number; // In milliseconds
		private var _sampleGroupSize:uint; // Size of a sample in bytes (all channels included)
		private var _samplesGroupCount:uint; // Number of samples in data (all channels included)
		private var _predecoding:Boolean; // Allow to pre-convert bytes to IEEE float, two channels, 44'100 Hz for faster data extraction
		private var _decodedData:ByteArray; // In standard flash format: IEEE float, two channels, 44'100 Hz

		// Fact
		private var _samplePerChannel:int;

		// Extraction method
		private var _extractFunc:Function;

		// Debug
		private static const LOG_PREFIX:String = "[Wave Track]";
		private var _verbose:Boolean = false;

		/**
		 * Wav Track Constructor.
		 *
		 * @param	data Wav raw data
		 * @param	predecode Convert data into native format (IEEE float, two channels, 44'100 Hz).
		 *          This improves preformance when extracting data during sampling.
		 *          Down sides: - Conversion may take a while...
		 *                      - It takes more memory (the converted sound is stored in RAM)
		 */
		public function WavTrack(data:ByteArray, predecodeData:Boolean = false)
		{
			_predecoding = predecodeData;

			parseRawData(data);
		}

		//---------------------------------------------------------------------
		//-- WAVE Format Parsing
		//---------------------------------------------------------------------

		private function parseRawData(data:ByteArray):void
		{
			// Make sure data is treated as little endian
			data.endian = Endian.LITTLE_ENDIAN;

			// Browse chunks
			while (data.bytesAvailable)
			{
				// Read chunk id & size
				var chunkId:String = data.readUTFBytes(4);
				var chunkSize:uint = data.readInt();

				// Debug
				if (_verbose)
					trace(chunkId + " (" + chunkSize + " bytes)");

				// Parse chunk data
				switch (chunkId)
				{
					case "RIFF": parseRIFFChunk(data, chunkSize); break;
					case "fmt ": parseFmtSubChunk(data, chunkSize); break;
					case "data": parseDataSubChunk(data, chunkSize); break;
					default:
						// Ignored chunks
						data.position += chunkSize; // Jump to next chunk
						break;
				}
			}
		}

		private function parseRIFFChunk(data:ByteArray, size:uint):void
		{
			_format = data.readUTFBytes(4);

			if (_verbose)
				trace("	Format: " + _format);
		}

		private function parseFmtSubChunk(data:ByteArray, size:uint):void
		{
			// Fmt sub-chunk
			_fmtAudioFormat = data.readShort();
			_fmtChannels = data.readShort();
			_fmtSampleRate = data.readInt();
			_fmtByteRate = data.readInt();
			_fmtBlockAlign = data.readShort();
			_fmtBitsPerSample = data.readShort();

			// Format type validity check
			if (!(_fmtAudioFormat == WAVE_FORMAT_PCM || _fmtAudioFormat == WAVE_FORMAT_IEEE_FLOAT))
			{
				throw new IllegalOperationError(LOG_PREFIX + " Unsupported Wave Audio Format: " + _format);
			}

			// PCM 16 bits format check
			if (_fmtAudioFormat == WAVE_FORMAT_PCM)
			{
				if (_fmtBitsPerSample != 16)
					throw new IllegalOperationError(LOG_PREFIX + " Unsupported Wave Audio Format: PCM Format must have 16 bits per sample.");
			}

			// IEEE Float 32 bits format check
			if (_fmtAudioFormat == WAVE_FORMAT_IEEE_FLOAT)
			{
				if (_fmtBitsPerSample != 32)
					throw new IllegalOperationError(LOG_PREFIX + " Unsupported Wave Audio Format: IEEE Format must have 32 bits per sample.");
			}

			// Sample rate check
			if (_fmtSampleRate != 44100)
				throw new IllegalOperationError(LOG_PREFIX + " Unsupported Wave Audio Format: Sample rate must be 44100 Hz.");

			// Min channel format check
			if (_fmtChannels < 1)
				throw new IllegalOperationError(LOG_PREFIX + " Unsupported Wave Audio Format: No channel found.");

			// Max channel format check
			if (_fmtChannels > 2)
				throw new IllegalOperationError(LOG_PREFIX + " Unsupported Wave Audio Format: Max 2 channels are supported.");

			// Debug
			if (_verbose)
			{
				trace(" Audio Format: " + _fmtAudioFormat +
				    "\n Channels: " + _fmtChannels +
				    "\n Sample Rate: " + _fmtSampleRate +
				    "\n Byte Rate: " + _fmtByteRate +
				    "\n Block Align: " + _fmtBlockAlign +
				    "\n Bits Per Sample: " + _fmtBitsPerSample);
			}
		}

		private function parseDataSubChunk(data:ByteArray, size:uint):void
		{
			// Pre-Decoding
			if (_predecoding)
			{
				// Setup start time to record predecoding time
				var startTime:int = getTimer();

				// Convert sound to IEEE 32bits two channels
				if (_fmtAudioFormat == WAVE_FORMAT_PCM)
					_fmtChannels == 1 ? decodePCM_Mono(data, size) : decodePCM_Stereo(data, size);
				else
					_fmtChannels == 1 ? decodeIEEE_Mono(data, size) : decodeIEEE_Stereo(data, size);

				// Print predecoding time
				if (_verbose)
					trace(LOG_PREFIX + " Pre-decoding time: " + (getTimer() - startTime) + " ms");

				// Compute length
				_sampleGroupSize = (32 / 8) * 2; // IEEE 32bits two channels
				_samplesGroupCount = size / ((_fmtBitsPerSample / 8) * _fmtChannels);
				_length = (_samplesGroupCount / _fmtSampleRate) * 1000;

				// Setup extraction method
				_extractFunc = extractPreDecoded;
			}
			else
			{
				// Setup data info
				_dataSource = data;
				_dataStartPosition = data.position;
				_dataSize = size;

				// For further chunks
				data.position += size;

				// Compute length
				_sampleGroupSize = (_fmtBitsPerSample / 8) * _fmtChannels;
				_samplesGroupCount = size / _sampleGroupSize;
				_length = (_samplesGroupCount / _fmtSampleRate) * 1000;

				// Setup the sample extraction method
				if (_fmtAudioFormat == WAVE_FORMAT_PCM)
					_extractFunc = _fmtChannels == 1 ? extractPCM_Mono : extractPCM_Stereo;
				else
					_extractFunc = _fmtChannels == 1 ? extractIEEE_Mono : extractIEEE_Stereo;
			}
		}

		//---------------------------------------------------------------------
		//-- Data Decoding
		//---------------------------------------------------------------------

		private function decodePCM_Mono(data:ByteArray, size:uint):void
		{
			_decodedData = new ByteArray();

			// Read all required samples
			var length:int = size / ((_fmtBitsPerSample / 8) * _fmtChannels);
			for (var i:int = 0; i < length; ++i)
			{
				var sample:Number = data.readShort() / 32767.0; // Normalize (MAX_SHORT - 1)
				_decodedData.writeFloat(sample); // Left
				_decodedData.writeFloat(sample); // Right
			}
		}

		private function decodePCM_Stereo(data:ByteArray, size:uint):void
		{
			_decodedData = new ByteArray();

			// Read all required samples
			var length:int = size / ((_fmtBitsPerSample / 8) * _fmtChannels);
			for (var i:int = 0; i < length; ++i)
			{
				_decodedData.writeFloat(data.readShort() / 32767.0); // Left
				_decodedData.writeFloat(data.readShort() / 32767.0); // Right
			}
		}

		private function decodeIEEE_Mono(data:ByteArray, size:uint):void
		{
			_decodedData = new ByteArray();

			// Read all required samples
			var length:int = size / ((_fmtBitsPerSample / 8) * _fmtChannels);
			for (var i:int = 0; i < length; ++i)
			{
				var sample:Number = data.readFloat();
				_decodedData.writeFloat(sample); // Left
				_decodedData.writeFloat(sample); // Right
			}
		}

		private function decodeIEEE_Stereo(data:ByteArray, size:uint):void
		{
			_decodedData = new ByteArray();

			// Read all required samples
			var length:int = size / ((_fmtBitsPerSample / 8) * _fmtChannels);
			for (var i:int = 0; i < length; ++i)
			{
				_decodedData.writeFloat(data.readFloat()); // Left
				_decodedData.writeFloat(data.readFloat()); // Right
			}

			// Bytes copy without read / write operations (doesn't work ;/ probably due to endianness)
			//_decodedData.writeBytes(data, data.position, size);
		}

		//---------------------------------------------------------------------
		//-- Sound Interface
		//---------------------------------------------------------------------

		public override function get length():Number
		{
			return _length;
		}

		public override function extract(target:ByteArray, samplesToRead:Number, startPosition:Number = -1):Number
		{
			return _extractFunc(target, samplesToRead, startPosition);
		}

		public function extractPreDecoded(target:ByteArray, samplesToRead:Number, startPosition:Number = -1):Number
		{
			// Read IEEE 32 bits, two channels data
			_decodedData.position = startPosition * 8;
			var availableSamples:int = _samplesGroupCount - startPosition;
			var samplesRead:int = Math.min(availableSamples, samplesToRead);
			target.writeBytes(_decodedData, _decodedData.position, samplesRead * 8);
			return samplesRead;
		}

		public override function destroy():void
		{
			// Clear data
			if (_decodedData)
				_decodedData.clear();

			// Nullify references
			_dataSource = null;
			_decodedData = null;
			_extractFunc = null;
		}

		//---------------------------------------------------------------------
		//-- PCM 16-bits extraction
		//---------------------------------------------------------------------

		private function extractPCM_Mono(target:ByteArray, samplesToRead:Number, startPosition:Number = -1):Number
		{
			// Set reading position
			_dataSource.position = _dataStartPosition + startPosition * _sampleGroupSize;

			// Find required samples to read
			var availableSamples:int = _samplesGroupCount - startPosition;
			var samplesRead:int = Math.min(availableSamples, samplesToRead);

			// Read all required samples
			for (var i:int = 0; i < samplesRead; ++i)
			{
				var sample:Number = _dataSource.readShort() / 32767.0; // Normalize (MAX_SHORT - 1)
				target.writeFloat(sample); // Left
				target.writeFloat(sample); // Right
			}

			// Returns the read sample
			return samplesRead;
		}

		private function extractPCM_Stereo(target:ByteArray, samplesToRead:Number, startPosition:Number = -1):Number
		{
			// Set reading position
			_dataSource.position = _dataStartPosition + startPosition * _sampleGroupSize;

			// Find required samples to read
			var availableSamples:int = _samplesGroupCount - startPosition;
			var samplesRead:int = Math.min(availableSamples, samplesToRead);

			// Read all required samples
			for (var i:int = 0; i < samplesRead; ++i)
			{
				target.writeFloat(_dataSource.readShort() / 32767.0); // Left
				target.writeFloat(_dataSource.readShort() / 32767.0); // Right
			}

			// Returns the read sample
			return samplesRead;
		}

		//---------------------------------------------------------------------
		//-- IEEE Float 32-bits extraction
		//---------------------------------------------------------------------

		private function extractIEEE_Mono(target:ByteArray, samplesToRead:Number, startPosition:Number = -1):Number
		{
			// Set reading position
			_dataSource.position = _dataStartPosition + startPosition * _sampleGroupSize;

			// Find required samples to read
			var availableSamples:int = _samplesGroupCount - startPosition;
			var samplesRead:int = Math.min(availableSamples, samplesToRead);

			// Read all required samples
			for (var i:int = 0; i < samplesRead; ++i)
			{
				var sample:Number = _dataSource.readFloat();
				target.writeFloat(sample); // Left
				target.writeFloat(sample); // Right
			}

			// Returns the read sample
			return samplesRead;
		}

		private function extractIEEE_Stereo(target:ByteArray, samplesToRead:Number, startPosition:Number = -1):Number
		{
			// Set reading position
			_dataSource.position = _dataStartPosition + startPosition * _sampleGroupSize;

			// Find required samples to read
			var availableSamples:int = _samplesGroupCount - startPosition;
			var samplesRead:int = Math.min(availableSamples, samplesToRead);

			// Read all required samples
			for (var i:int = 0; i < samplesRead; ++i)
			{
				target.writeFloat(_dataSource.readFloat()); // Left
				target.writeFloat(_dataSource.readFloat()); // Right
			}

			// Returns the read sample
			return samplesRead;
		}
	}
}