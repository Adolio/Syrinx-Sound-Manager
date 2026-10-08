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
	import ch.adolio.sound.Track;
	import flash.utils.ByteArray;

	/**
	 * Synthetic track holding generated stereo samples, which records the extractions.
	 *
	 * Sample values are written as 32-bit floats: use values exactly representable as such, like multiples of 1/128,
	 * when comparing them exactly.
	 */
	public class ProbeTrack extends Track
	{
		public static const SAMPLE_RATE_MS:Number = 44.1; // Samples per millisecond

		private var _left:Vector.<Number>;
		private var _right:Vector.<Number>;

		/** Number of calls to <code>extract</code>. */
		public var extractCount:int = 0;

		/** Number of calls to <code>extract</code> from a position which is not a whole number of samples. */
		public var fractionalExtractCount:int = 0;

		/** Indicates whether <code>destroy</code> was called. */
		public var isDestroyed:Boolean = false;

		public function ProbeTrack(left:Vector.<Number>, right:Vector.<Number> = null)
		{
			_left = left;
			_right = right ? right : left;

			if (_right.length != _left.length)
				throw new ArgumentError("Left & right channels must have the same number of samples.");
		}

		/**
		 * Creates a track of the given number of samples, with the same value on both channels.
		 *
		 * @param sampleFunc <code>function(index:int):Number</code>
		 */
		public static function fromFunction(samplesCount:int, sampleFunc:Function):ProbeTrack
		{
			var samples:Vector.<Number> = new Vector.<Number>(samplesCount, true);
			for (var i:int = 0; i < samplesCount; ++i)
				samples[i] = sampleFunc(i);

			return new ProbeTrack(samples);
		}

		/**
		 * Creates a tone (alternating <code>amplitude</code> & <code>-amplitude</code>) surrounded by silences.
		 */
		public static function toneWithSilences(leadingSilence:int, toneSamples:int, trailingSilence:int, amplitude:Number = 0.5):ProbeTrack
		{
			return fromFunction(leadingSilence + toneSamples + trailingSilence, function(i:int):Number
			{
				if (i < leadingSilence || i >= leadingSilence + toneSamples)
					return 0;

				return i % 2 == 0 ? amplitude : -amplitude;
			});
		}

		/**
		 * Creates a tone without silence lasting the given duration.
		 */
		public static function tone(durationMs:Number, amplitude:Number = 0.5):ProbeTrack
		{
			return toneWithSilences(0, Math.round(durationMs * SAMPLE_RATE_MS), 0, amplitude);
		}

		public function get samplesCount():int
		{
			return _left.length;
		}

		public override function get length():Number
		{
			return _left.length / SAMPLE_RATE_MS;
		}

		public override function extract(target:ByteArray, length:Number, startPosition:Number = -1):Number
		{
			++extractCount;

			if (startPosition != Math.floor(startPosition))
				++fractionalExtractCount;

			var start:int = startPosition < 0 ? 0 : int(startPosition);
			var count:int = Math.max(0, Math.min(int(length), _left.length - start));
			for (var i:int = 0; i < count; ++i)
			{
				target.writeFloat(_left[start + i]);
				target.writeFloat(_right[start + i]);
			}

			return count;
		}

		public override function destroy():void
		{
			isDestroyed = true;
		}
	}
}
