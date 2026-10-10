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
	import ch.adolio.test.ITest;

	/**
	 * Values given to sound instances, managers & track configurations: volumes are clamped, while invalid pitches,
	 * positions & start times are rejected without changing the sound.
	 *
	 * Managers have a master volume of 0 unless the scenario checks it. Tracks last 1000 ms.
	 */
	public class ValidationTest implements ITest
	{
		private static const EPSILON:Number = 0.000001;

		public function execute():void
		{
			testInstanceVolumes();
			testTrackConfigurationBaseVolume();
			testInvalidTrimsRejected();
			testManagerVolume();
			testInvalidPitchesRejected();
			testInvalidPositionsRejected();
			testInvalidStartTimesRejected();
			testInvalidStartTimeThroughManager();
			testPositionRatioOfInfiniteLoop();
		}

		private function testInstanceVolumes():void
		{
			var si:SoundInstance = createInstance();

			si.volume = 0.4;
			si.volume = NaN;
			Assert.equalsNumber(si.volume, SoundInstance.VOLUME_MAX, EPSILON, "NaN volume considered as max");

			si.baseVolume = 0.4;
			si.baseVolume = NaN;
			Assert.equalsNumber(si.baseVolume, SoundInstance.VOLUME_MAX, EPSILON, "NaN base volume considered as max");
			Assert.equalsNumber(si.mixedVolume, 0, EPSILON, "Mixed volume still a number");
		}

		private function testTrackConfigurationBaseVolume():void
		{
			var config:TrackConfiguration = new TrackConfiguration(ProbeTrack.tone(1000), "tone");

			config.baseVolume = 0.4;
			Assert.equalsNumber(config.baseVolume, 0.4, EPSILON, "Base volume");
			config.baseVolume = 2;
			Assert.equalsNumber(config.baseVolume, SoundInstance.VOLUME_MAX, EPSILON, "Base volume clamped to max");
			config.baseVolume = -1;
			Assert.equalsNumber(config.baseVolume, SoundInstance.VOLUME_MIN, EPSILON, "Base volume clamped to min");
			config.baseVolume = NaN;
			Assert.equalsNumber(config.baseVolume, SoundInstance.VOLUME_MAX, EPSILON, "NaN base volume considered as max");
		}

		private function testInvalidTrimsRejected():void
		{
			var config:TrackConfiguration = new TrackConfiguration(ProbeTrack.tone(1000), "tone", 100, 200);

			assertRejected(function():void { config.trimStartDuration = NaN; }, "Start trim which is not a number");
			assertRejected(function():void { config.trimEndDuration = NaN; }, "End trim which is not a number");
			assertRejected(function():void { config.trimStartDuration = Number.POSITIVE_INFINITY; }, "Infinite start trim");
			assertRejected(function():void { config.trimEndDuration = Number.POSITIVE_INFINITY; }, "Infinite end trim");
			Assert.equalsNumber(config.trimStartDuration, 100, EPSILON, "Rejected start trims not applied");
			Assert.equalsNumber(config.trimEndDuration, 200, EPSILON, "Rejected end trims not applied");

			assertRejected(function():void
			{
				new TrackConfiguration(ProbeTrack.tone(1000), "tone", NaN);
			}, "Start trim which is not a number in constructor");
		}

		private function testManagerVolume():void
		{
			var manager:SoundManager = new SoundManager();
			var si:SoundInstance = new SoundInstance(manager.registerTrack("tone", ProbeTrack.tone(1000)), manager);

			manager.volume = 0.4;
			Assert.equalsNumber(manager.volume, 0.4, EPSILON, "Master volume");
			Assert.equalsNumber(si.mixedVolume, 0.4, EPSILON, "Mixed volume following the master volume");
			manager.volume = 2;
			Assert.equalsNumber(manager.volume, SoundInstance.VOLUME_MAX, EPSILON, "Master volume clamped to max");
			manager.volume = -1;
			Assert.equalsNumber(manager.volume, SoundInstance.VOLUME_MIN, EPSILON, "Master volume clamped to min");
			manager.volume = NaN;
			Assert.equalsNumber(manager.volume, SoundInstance.VOLUME_MAX, EPSILON, "NaN master volume considered as max");
			Assert.equalsNumber(si.mixedVolume, 1, EPSILON, "Mixed volume still a number");
		}

		private function testInvalidPitchesRejected():void
		{
			var si:SoundInstance = createInstance();
			si.pitch = 0.5;

			for each (var pitch:Number in [0, -1, NaN, Number.POSITIVE_INFINITY])
				assertRejected(function():void { si.pitch = pitch; }, "Pitch: " + pitch);

			Assert.equalsNumber(si.pitch, 0.5, EPSILON, "Rejected pitches not applied");
		}

		private function testInvalidPositionsRejected():void
		{
			var si:SoundInstance = createInstance();
			si.position = 300;

			for each (var position:Number in [-1, 1001, NaN, Number.POSITIVE_INFINITY])
				assertRejected(function():void { si.position = position; }, "Position: " + position);

			for each (var ratio:Number in [-0.5, 1.5, NaN])
				assertRejected(function():void { si.positionRatio = ratio; }, "Position ratio: " + ratio);

			Assert.equalsNumber(si.position, 300, EPSILON, "Rejected positions not applied");
		}

		private function testInvalidStartTimesRejected():void
		{
			var si:SoundInstance = createInstance();

			for each (var startTime:Number in [-1, NaN, Number.POSITIVE_INFINITY])
				assertRejected(function():void { si.play(1, startTime, -1); }, "Start time: " + startTime);

			// Beyond the total length
			assertRejected(function():void { si.play(1, 1001, 0); }, "Start time beyond the length");
			assertRejected(function():void { si.play(1, 3001, 2); }, "Start time beyond the total length with loops");

			Assert.isFalse(si.isStarted, "Not started by rejected start times");
			Assert.equalsInt(si.loops, 0, "Loops not changed by rejected start times");

			si.manager.destroyAllSoundInstances();
		}

		private function testInvalidStartTimeThroughManager():void
		{
			var manager:SoundManager = createManager();
			assertRejected(function():void { manager.play("tone", 1, -1); }, "Negative start time through the manager");
			Assert.equalsInt(manager.getSoundInstancesCount(), 0, "No instance left in the manager by a rejected start time");
		}

		private function testPositionRatioOfInfiniteLoop():void
		{
			var si:SoundInstance = createInstance();
			si.play(1, 2300, -1);
			Assert.isTrue(si.isPlaying, "Not playing, a sound output device is required.");
			si.pause();

			// The ratio applies within the loop being played
			si.positionRatio = 0.5;
			Assert.equalsNumber(si.position, 2500, EPSILON, "Position ratio within the third loop");
			si.positionRatio = 0;
			Assert.equalsNumber(si.position, 2000, EPSILON, "Position ratio at the start of the third loop");
			Assert.isTrue(si.isPaused, "Still paused");

			si.manager.destroyAllSoundInstances();
		}

		private function assertRejected(block:Function, context:String):void
		{
			Assert.throws(ArgumentError, block, context);
		}

		private function createManager():SoundManager
		{
			var manager:SoundManager = new SoundManager();
			manager.volume = 0;
			manager.registerTrack("tone", ProbeTrack.tone(1000));
			return manager;
		}

		private function createInstance():SoundInstance
		{
			var manager:SoundManager = createManager();
			return new SoundInstance(manager.findRegisteredTrack("tone"), manager);
		}
	}
}
