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
	import flash.utils.getTimer;

	/**
	 * Position of custom sampled sounds while they play: it must follow what is heard, whatever the loop, the pitch &
	 * the sampling, which is fed ahead of the playback.
	 *
	 * Each scenario plays a synthetic track of 1000 ms at a master volume of 0 & compares the position with the
	 * elapsed time. Tolerances cover the steps of the playback position & the timers accuracy.
	 */
	public class PositionTestAsync extends ScenariosTestAsync
	{
		private static const PLAYING_DELAY:int = 400; // Time left to the sound to play between two checks, in milliseconds
		private static const TOLERANCE:Number = 120; // In milliseconds

		protected override function createScenarios():Array
		{
			return [
				testPositionFromLaterLoop,
				testPositionWithMaxSampling,
				testPositionOfPitchedSound,
				testPositionContinuousOnPitchChanges,
				testPauseKeepsLoopHeard];
		}

		private function testPositionFromLaterLoop(next:Function):void
		{
			var si:SoundInstance = createManager().play("tone", 1, 2300, 3);
			assertPlaying(si);
			Assert.equalsNumber(si.position, 2300, TOLERANCE, "Position when started from the third loop");

			var startTime:int = getTimer();
			defer(function():void
			{
				Assert.equalsNumber(si.position, 2300 + getTimer() - startTime, TOLERANCE, "Position after playing from the third loop");
				Assert.equalsNumber(si.remainingTime, si.totalLength - si.position, TOLERANCE, "Remaining time after playing from the third loop");

				si.manager.destroyAllSoundInstances();
				next();
			}, PLAYING_DELAY);
		}

		private function testPositionWithMaxSampling(next:Function):void
		{
			var si:SoundInstance = createManager(TrackConfiguration.SAMPLING_MAX_VALUE).play("tone", 1, 0, -1);
			assertPlaying(si);

			var startTime:int = getTimer();
			defer(function():void
			{
				Assert.equalsNumber(si.position, getTimer() - startTime, TOLERANCE, "Position with samples fed far ahead of the playback");

				si.manager.destroyAllSoundInstances();
				next();
			}, PLAYING_DELAY);
		}

		private function testPositionOfPitchedSound(next:Function):void
		{
			var manager:SoundManager = createManager();
			var si:SoundInstance = new SoundInstance(manager.findRegisteredTrack("tone"), manager);
			si.pitch = 1.5;
			si.play(1, 0, -1);
			assertPlaying(si);

			var startTime:int = getTimer();
			defer(function():void
			{
				Assert.equalsNumber(si.position, 1.5 * (getTimer() - startTime), 1.5 * TOLERANCE, "Position of a pitched sound");

				defer(function():void
				{
					Assert.equalsNumber(si.position, 1.5 * (getTimer() - startTime), 1.5 * TOLERANCE, "Position of a pitched sound after looping");

					manager.destroyAllSoundInstances();
					next();
				}, 2 * PLAYING_DELAY);
			}, PLAYING_DELAY);
		}

		private function testPositionContinuousOnPitchChanges(next:Function):void
		{
			var si:SoundInstance = createManager().play("tone", 1, 0, -1);
			assertPlaying(si);

			defer(function():void
			{
				var positionBeforePitch:Number = si.position;
				si.pitch = 1.5;
				Assert.equalsNumber(si.position, positionBeforePitch, TOLERANCE, "Position when the pitch is set on a looping sound");

				var pitchTime:int = getTimer();
				defer(function():void
				{
					Assert.equalsNumber(si.position, positionBeforePitch + 1.5 * (getTimer() - pitchTime), 1.5 * TOLERANCE, "Position after playing pitched");

					var positionBeforeReset:Number = si.position;
					si.pitch = SoundInstance.PITCH_DEFAULT;
					Assert.equalsNumber(si.position, positionBeforeReset, TOLERANCE, "Position when the pitch is reset");

					var resetTime:int = getTimer();
					defer(function():void
					{
						Assert.equalsNumber(si.position, positionBeforeReset + getTimer() - resetTime, 1.5 * TOLERANCE, "Position after the pitch reset");

						si.manager.destroyAllSoundInstances();
						next();
					}, PLAYING_DELAY);
				}, PLAYING_DELAY);
			}, PLAYING_DELAY);
		}

		private function testPauseKeepsLoopHeard(next:Function):void
		{
			// Samples of the second loop are already fed when the sound is paused in its first loop
			var si:SoundInstance = createManager(TrackConfiguration.SAMPLING_MAX_VALUE).play("tone", 1, 800, 3);
			assertPlaying(si);

			defer(function():void
			{
				si.pause();
				Assert.equalsNumber(si.position, 900, TOLERANCE, "Position when paused before the end of the first loop");
				Assert.equalsInt(si.currentLoop, Math.floor(si.position / si.length), "Current loop when paused");

				var pausePosition:Number = si.position;
				si.resume();
				assertPlaying(si);
				Assert.equalsNumber(si.position, pausePosition, TOLERANCE, "Position when resumed");

				si.manager.destroyAllSoundInstances();
				next();
			}, 100);
		}

		private function createManager(sampling:uint = TrackConfiguration.SAMPLING_MIN_VALUE):SoundManager
		{
			var manager:SoundManager = new SoundManager();
			manager.volume = 0;
			manager.registerTrack("tone", ProbeTrack.tone(1000), 0, 0, sampling);
			return manager;
		}

		private function assertPlaying(si:SoundInstance):void
		{
			Assert.isTrue(si.isPlaying, "Not playing, a sound output device is required.");
		}
	}
}
