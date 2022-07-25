// =================================================================================================
//
//	Syrinx - Sound Manager
//	Copyright (c) 2019 Aurelien Da Campo (Adolio), All Rights Reserved.
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
			_baseVolume = value;
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

		public function findStartTrimDuration(silentThreshold:Number = 0.01, startPosition:Number = 0):Number
		{
			// End of the track reached
			if (startPosition > _track.length)
				return _track.length;

			// Extract bytes
			var readBytes:ByteArray = new ByteArray();
			var samplesRead:Number = _track.extract(readBytes, _sampling, timeToSamples(startPosition));
			readBytes.position = 0;

			// Find first non-silent sample from begin to end
			var nonSilentSampleFound:Boolean = false;
			var samplesCount:int = 0;
			const sampleSize:int = 8; // 2*4 bytes
			while (readBytes.bytesAvailable >= sampleSize)
			{
				// Get left & right float values
				var l0:Number = readBytes.readFloat();
				var r0:Number = readBytes.readFloat();

				// Detect non-silence
				if (Math.abs(l0) > silentThreshold || Math.abs(r0) > silentThreshold)
					return startPosition + samplesToTime(samplesCount);

				// Next sample
				++samplesCount;
			}

			// Continue look-up...
			return findStartTrimDuration(silentThreshold, startPosition + samplesToTime(samplesRead));
		}

		public function findEndTrimDuration(silentThreshold:Number = 0.01, startPosition:Number = 0):Number
		{
			// Extract bytes from the end
			var readBytes:ByteArray = new ByteArray();
			var extractionPosition:Number = timeToSamples(startPosition) - _sampling;
			var sampleToRead:uint = _sampling;

			// Beginning of the track reached
			var beginReached:Boolean = false;
			if (extractionPosition < 0)
			{
				sampleToRead = _sampling - Math.abs(extractionPosition);
				extractionPosition = 0;
				beginReached = true;
			}

			// Read samples
			var samplesRead:uint = _track.extract(readBytes, sampleToRead, extractionPosition);

			// Find first non-silent sample from end to begin
			var nonSilentSampleFound:Boolean = false;
			var samplesCount:int = 0;
			var nextSamplePosition:int = samplesRead - SAMPLE_SIZE;
			while (nextSamplePosition >= 0)
			{
				// Move to the next sample position
				readBytes.position = nextSamplePosition;

				// Get left & right float values
				var l0:Number = readBytes.readFloat(); // 4 bytes
				var r0:Number = readBytes.readFloat(); // 4 bytes

				// Detect silence
				if (Math.abs(l0) > silentThreshold || Math.abs(r0) > silentThreshold)
					return _track.length - (startPosition - samplesToTime(samplesCount));

				// Next sample
				++samplesCount;
				nextSamplePosition = samplesRead - (samplesCount * SAMPLE_SIZE) - SAMPLE_SIZE;
			}

			// Continue look-up...
			if (!beginReached)
				return findEndTrimDuration(silentThreshold, startPosition - samplesToTime(samplesRead));

			// Nothing found
			return _track.length;
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