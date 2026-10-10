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
	import flash.utils.ByteArray;

	/**
	 * Track configuration
	 *
	 * @author Aurelien Da Campo
	 */
	public class TrackConfiguration
	{
		// Core
		private var _track:Track;
		private var _type:String;

		// Volume
		private var _baseVolume:Number = 1.0;

		// Trimming
		public static var trimDefaultSilenceThreshold:Number = 0.01; // Default silence threshold for automatic trimming.
		private var _trimStartDuration:Number = 0; // In milliseconds
		private var _trimEndDuration:Number = 0; // In milliseconds

		// Format
		private static const SAMPLE_SIZE:uint = 8; // 2*4 bytes
		private static const SAMPLE_RATE_MS:Number = 44.1; // Sampling rate per millisecond

		// Sampling options
		public static const SAMPLING_MIN_VALUE:uint = 2048;
		public static const SAMPLING_MAX_VALUE:uint = 8192;
		private var _sampling:uint = SAMPLING_MIN_VALUE; // Samples returned per sampling data request (min: 2048, max: 8192)

		/**
		 * Track Configuration constructor.
		 *
		 * <p>
		 * If `trimStartDuration` is negative the system will automatically look for it by using the auto trimming feature.
		 * The `TrackConfiguration.trimDefaultSilenceThreshold` is then used for silence threshold.
		 * </p>
		 *
		 * <p>
		 * If `trimEndDuration` is negative the system will automatically look for it by using the auto trimming feature.
		 * The `TrackConfiguration.trimDefaultSilenceThreshold` is then used for silence threshold.
		 * </p>
		 */
		public function TrackConfiguration(track:Track, type:String, trimStartDuration:Number = 0, trimEndDuration:Number = 0, sampling:uint = SAMPLING_MIN_VALUE)
		{
			// Setup core variables
			_track = track;
			_type = type;

			// Update initial trimming durations
			this.trimStartDuration = trimStartDuration;
			this.trimEndDuration = trimEndDuration;

			// Update sampling
			this.sampling = sampling;
		}

		public function destroy():void
		{
			_track = null;
			_type = null;
		}

		public function clone():TrackConfiguration
		{
			var clone:TrackConfiguration = new TrackConfiguration(_track, _type, _trimStartDuration, _trimEndDuration);
			clone.sampling = _sampling;
			return clone;
		}

		public function get track():Track
		{
			return _track;
		}

		public function get type():String
		{
			return _type;
		}

		public function get baseVolume():Number
		{
			return _baseVolume;
		}

		public function set baseVolume(value:Number):void
		{
			_baseVolume = SoundInstance.clampVolume(value);
		}

		public function get trimStartDuration():Number
		{
			return _trimStartDuration;
		}

		public function set trimStartDuration(value:Number):void
		{
			// Automatic trimming
			if (value < 0)
				value = findStartTrimDuration(trimDefaultSilenceThreshold);

			// Check for invalid trimming values
			if (value + _trimEndDuration > _track.length)
				throw new ArgumentError("[Track Configuration] Invalid trimming. Start + end trimming cannot be greater than the sound length. Sound length: " + _track.length + ", Trimming length: " + (value + _trimEndDuration));

			// Update trimming
			_trimStartDuration = value;
		}

		public function get trimEndDuration():Number
		{
			return _trimEndDuration;
		}

		public function set trimEndDuration(value:Number):void
		{
			// Automatic trimming
			if (value < 0)
				value = findEndTrimDuration(trimDefaultSilenceThreshold, _track.length);

			// Check for invalid trimming values
			if (_trimStartDuration + value > _track.length)
				throw new ArgumentError("[Track Configuration] Invalid trimming duration. Start + end trimming durations cannot be greater than the sound length. Sound length: " + _track.length + ", Trimming length: " + (value + _trimEndDuration));

			// Update trimming
			_trimEndDuration = value;
		}

		public function samplesToTime(samples:Number):Number
		{
			return Math.round(samples) / SAMPLE_RATE_MS;
		}

		public function timeToSamples(time:Number):Number
		{
			return Math.round(time * SAMPLE_RATE_MS);
		}

		/**
		 * Finds the duration of the silence at the start of the track, by reading blocks of <code>sampling</code> samples.
		 *
		 * @param silentThreshold Amplitude at or below which a sample is silent, on both channels
		 * @param startPosition Position in milliseconds from which the silence is looked for
		 * @return The duration in milliseconds from the start of the track to the first non-silent sample, or the track length when the track is silent from the start position
		 */
		public function findStartTrimDuration(silentThreshold:Number = 0.01, startPosition:Number = 0):Number
		{
			var readBytes:ByteArray = new ByteArray();
			var blockStart:Number = Math.max(0, timeToSamples(startPosition)); // In samples
			while (true)
			{
				// Extract the next block
				readBytes.clear();
				var samplesRead:int = _track.extract(readBytes, _sampling, blockStart);
				if (samplesRead <= 0)
					break;

				// Look for the first non-silent sample of the block
				readBytes.position = 0;
				for (var i:int = 0; i < samplesRead; ++i)
				{
					if (!isNextSampleSilent(readBytes, silentThreshold))
						return samplesToTime(blockStart + i);
				}

				blockStart += samplesRead;
			}

			// Silent until the end
			return _track.length;
		}

		/**
		 * Finds the duration of the silence at the end of the track, by reading blocks of <code>sampling</code> samples backwards.
		 *
		 * @param silentThreshold Amplitude at or below which a sample is silent, on both channels
		 * @param startPosition Position in milliseconds from which the silence is looked for, backwards (the track length to scan the whole track)
		 * @return The duration in milliseconds from the end of the last non-silent sample to the end of the track, or the track length when the track is silent up to the start position
		 */
		public function findEndTrimDuration(silentThreshold:Number = 0.01, startPosition:Number = 0):Number
		{
			var readBytes:ByteArray = new ByteArray();
			var blockEnd:Number = timeToSamples(startPosition); // In samples, excluded
			while (blockEnd > 0)
			{
				// Extract the previous block
				var blockStart:Number = Math.max(0, blockEnd - _sampling);
				readBytes.clear();
				var samplesRead:int = _track.extract(readBytes, blockEnd - blockStart, blockStart);
				if (samplesRead <= 0)
					break;

				// Look for the last non-silent sample of the block
				for (var i:int = samplesRead - 1; i >= 0; --i)
				{
					readBytes.position = i * SAMPLE_SIZE;
					if (!isNextSampleSilent(readBytes, silentThreshold))
						return _track.length - samplesToTime(blockStart + i + 1);
				}

				blockEnd = blockStart;
			}

			// Silent from the start
			return _track.length;
		}

		/**
		 * Reads the stereo sample at the current position of the bytes & checks whether both its channels are silent.
		 */
		private static function isNextSampleSilent(bytes:ByteArray, silentThreshold:Number):Boolean
		{
			var left:Number = bytes.readFloat();
			var right:Number = bytes.readFloat();
			return Math.abs(left) <= silentThreshold && Math.abs(right) <= silentThreshold;
		}

		public function findTrim(silentThreshold:Number = 0.01):void
		{
			// Reset trimming
			trimStartDuration = 0;
			trimEndDuration = 0;

			// Find trimming durations
			var startTrimDuration:Number = findStartTrimDuration(silentThreshold);
			var endTrimDuration:Number = findEndTrimDuration(silentThreshold, _track.length);

			// Check trimming duration validity
			if (startTrimDuration + endTrimDuration > _track.length)
			{
				trace("[Track Configuration] Impossible to find correct trimming durations. Sound is fully silent with silent threshold of " + silentThreshold + ".");
				return;
			}

			// Update trimming durations
			trimStartDuration = startTrimDuration;
			trimEndDuration = endTrimDuration;
		}

		public function get sampling():uint
		{
			return _sampling;
		}

		public function set sampling(value:uint):void
		{
			// Check for unsupported values
			if (value < SAMPLING_MIN_VALUE || value > SAMPLING_MAX_VALUE)
			{
				throw new ArgumentError("[Track Configuration] Invalid sampling value. Sampling value must be between " + SAMPLING_MIN_VALUE + " and " + SAMPLING_MAX_VALUE + " (included).");
			}

			_sampling = value;
		}
	}
}