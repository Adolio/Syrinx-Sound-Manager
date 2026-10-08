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
			return [testWholeSamplePositionsAfterPitchReset];
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
	}
}
