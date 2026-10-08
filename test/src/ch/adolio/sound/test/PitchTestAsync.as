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
	import ch.adolio.sound.SoundInstance;
	import ch.adolio.sound.SoundManager;
	import ch.adolio.sound.TrackConfiguration;
	import ch.adolio.test.Assert;
	import ch.adolio.test.ScenariosTestAsync;

	/**
	 * Sounds whose pitch changes while they are sampled.
	 *
	 * Each scenario plays a looping synthetic track at a master volume of 0 & lets the sampling run between its steps.
	 */
	public class PitchTestAsync extends ScenariosTestAsync
	{
		private static const SAMPLING_DELAY:int = 300; // Time left to sample several blocks, in milliseconds

		// The reading position advances by the sampling multiplied by the pitch at each block: with this value, it
		// does not come back on a whole number of samples within the duration of a scenario
		private static const PITCH:Number = 1.234;

		protected override function createScenarios():Array
		{
			return [
				testWholeSamplePositionsAfterPitchReset,
				testHighPitchedSoundReadWithinTrims,
				testLowPitchedSoundReadWithinTrims];
		}

		private function testWholeSamplePositionsAfterPitchReset(next:Function):void
		{
			var track:ProbeTrack = ProbeTrack.tone(2000);
			var manager:SoundManager = new SoundManager();
			manager.volume = 0;
			manager.registerTrack("tone", track);

			var si:SoundInstance = manager.play("tone", 1, 0, -1);
			Assert.isTrue(si.isPlaying, "Not playing, a sound output device is required.");
			si.pitch = PITCH;

			defer(function():void
			{
				var extractCountWhilePitched:int = track.extractCount;
				Assert.isTrue(extractCountWhilePitched > 1, "Samples extracted while pitched");
				si.pitch = SoundInstance.PITCH_DEFAULT;

				defer(function():void
				{
					Assert.isTrue(track.extractCount > extractCountWhilePitched + 1, "Samples extracted after the pitch reset");
					Assert.equalsInt(track.fractionalExtractCount, 0, "Extractions from a position between two samples");

					manager.destroyAllSoundInstances();
					next();
				}, SAMPLING_DELAY);
			}, SAMPLING_DELAY);
		}

		private function testHighPitchedSoundReadWithinTrims(next:Function):void
		{
			assertPitchedSoundReadWithinTrims(PITCH, next);
		}

		private function testLowPitchedSoundReadWithinTrims(next:Function):void
		{
			assertPitchedSoundReadWithinTrims(PITCH / 2, next);
		}

		/**
		 * Plays a looping track of 1000 ms trimmed by 200 ms at its start & 300 ms at its end, long enough to loop at
		 * least once, & checks which samples were read.
		 */
		private function assertPitchedSoundReadWithinTrims(pitch:Number, next:Function):void
		{
			var track:ProbeTrack = ProbeTrack.tone(1000);
			var manager:SoundManager = new SoundManager();
			manager.volume = 0;
			var config:TrackConfiguration = manager.registerTrack("tone", track, 200, 300);
			var firstSample:int = config.timeToSamples(200);
			var lastSample:int = config.timeToSamples(700) - 1;

			var si:SoundInstance = new SoundInstance(config, manager);
			si.pitch = pitch;
			si.play(1, 0, -1);
			Assert.isTrue(si.isPlaying, "Not playing, a sound output device is required.");

			defer(function():void
			{
				Assert.isTrue(si.currentLoop > 0, "Looped at least once. Pitch: " + pitch);
				Assert.equalsInt(track.lowestExtractedSample, firstSample, "First sample read. Pitch: " + pitch);
				Assert.equalsInt(track.highestExtractedSample, lastSample, "Last sample read. Pitch: " + pitch);

				manager.destroyAllSoundInstances();
				next();
			}, si.length / pitch + SAMPLING_DELAY);
		}
	}
}
