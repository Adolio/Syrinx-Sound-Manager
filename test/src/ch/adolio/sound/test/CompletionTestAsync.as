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
	import ch.adolio.sound.Mp3Track;
	import ch.adolio.sound.SoundInstance;
	import ch.adolio.sound.SoundInstancesPool;
	import ch.adolio.sound.SoundManager;
	import ch.adolio.sound.TrackConfiguration;
	import ch.adolio.test.Assert;
	import ch.adolio.test.ScenariosTestAsync;
	import flash.utils.getTimer;

	/**
	 * Sounds played until their completion: destruction, loops, instances kept alive & release to the pool.
	 *
	 * Each scenario plays a 100 ms synthetic track at a master volume of 0. Checks following a signal are deferred, so
	 * that they run once the signal dispatch is over.
	 */
	public class CompletionTestAsync extends ScenariosTestAsync
	{
		private static const TRACK_DURATION:Number = 100; // In milliseconds

		protected override function createScenarios():Array
		{
			return [
				testCompletionDestroysInstance,
				testListenersCalledBeforeDestruction,
				testListenersCalledBeforeReleaseToPool,
				testInstancePlayedAgainByListenerKept,
				testLoopsPlayedBeforeCompletion,
				testStandardSoundCompleted,
				testCompletedInstanceKeptAlive,
				testCompletionReleasesToPool,
				testTrackEndingOnSamplingBoundaryCompletes,
				testLoopingTrackWithoutSamplesCompletes];
		}

		private function testCompletionDestroysInstance(next:Function):void
		{
			var manager:SoundManager = createManager(false);
			var completedCount:int = 0;
			var si:SoundInstance = manager.play("short");
			assertPlaying(si);
			si.completed.add(function(instance:SoundInstance):void { completedCount++; });
			si.destroyed.add(function(instance:SoundInstance):void
			{
				defer(function():void
				{
					Assert.equalsInt(completedCount, 1, "Completed signal before destruction");
					Assert.isTrue(si.isDestroyed, "Destroyed on completion");
					Assert.equalsInt(manager.getSoundInstancesCount(), 0, "Removed from the manager on completion");
					next();
				});
			});
		}

		private function testListenersCalledBeforeDestruction(next:Function):void
		{
			var manager:SoundManager = createManager(false);
			var si:SoundInstance = manager.play("short");
			assertPlaying(si);
			si.completed.add(function(instance:SoundInstance):void
			{
				attempt(function():void
				{
					Assert.isFalse(si.isDestroyed, "Not destroyed yet for the completed listeners");
					Assert.isTrue(si.manager == manager, "Still in its manager for the completed listeners");
					Assert.isFalse(si.isPlaying, "Not playing for the completed listeners");
					Assert.equalsNumber(si.length, TRACK_DURATION, 0.01, "Length readable by the completed listeners");
				});

				defer(function():void
				{
					Assert.isTrue(si.isDestroyed, "Destroyed once the completed listeners are called");
					next();
				});
			});
		}

		private function testListenersCalledBeforeReleaseToPool(next:Function):void
		{
			var pool:SoundInstancesPool = SoundInstancesPool.instance;
			var manager:SoundManager = createManager(true);
			var si:SoundInstance = manager.play("short");
			assertPlaying(si);
			var availableCount:uint = pool.availableCount;
			si.completed.add(function(instance:SoundInstance):void
			{
				attempt(function():void
				{
					Assert.equalsInt(pool.availableCount, availableCount, "Not released yet for the completed listeners");
					Assert.isTrue(si.manager == manager, "Still in its manager for the completed listeners");
				});

				defer(function():void
				{
					Assert.equalsInt(pool.availableCount, availableCount + 1, "Released once the completed listeners are called");
					Assert.isNull(si.manager, "Removed from its manager once released");
					next();
				});
			});
		}

		private function testInstancePlayedAgainByListenerKept(next:Function):void
		{
			var manager:SoundManager = createManager(false);
			var si:SoundInstance = manager.play("short");
			assertPlaying(si);
			si.completed.addOnce(function(instance:SoundInstance):void
			{
				attempt(function():void
				{
					si.play();
				});

				defer(function():void
				{
					Assert.isFalse(si.isDestroyed, "Not destroyed when played again by a completed listener");
					Assert.isTrue(si.isPlaying, "Playing again");
					Assert.equalsInt(manager.getSoundInstancesCount(), 1, "Kept by its manager when played again");

					manager.destroyAllSoundInstances();
					next();
				});
			});
		}

		private function testLoopsPlayedBeforeCompletion(next:Function):void
		{
			var manager:SoundManager = createManager(false);
			var startTime:int = getTimer();
			var si:SoundInstance = manager.play("short", 1, 0, 2);
			assertPlaying(si);
			si.freeWhenCompleted = false;
			si.completed.add(function(instance:SoundInstance):void
			{
				defer(function():void
				{
					var elapsedTime:int = getTimer() - startTime;
					Assert.isTrue(elapsedTime >= 2.5 * TRACK_DURATION, "Three repetitions played before completion. Elapsed time: " + elapsedTime + " ms");
					Assert.equalsInt(si.currentLoop, 2, "Current loop once completed is the last one played");
					Assert.equalsInt(si.loopsRemaining, 0, "No loop remaining once completed");
					Assert.equalsNumber(si.remainingTime, 0, 0.01, "No remaining time once completed");

					si.destroy();
					next();
				});
			});
		}

		private function testStandardSoundCompleted(next:Function):void
		{
			// An MP3 track played without trimming nor pitch, 100 ms before its end
			var track:Mp3Track = TestSounds.createMp3Track();
			var manager:SoundManager = new SoundManager();
			manager.volume = 0;
			manager.registerTrack("piano", track);

			var si:SoundInstance = manager.play("piano", 1, track.length - 100);
			assertPlaying(si);
			si.freeWhenCompleted = false;
			si.completed.add(function(instance:SoundInstance):void
			{
				defer(function():void
				{
					Assert.isFalse(si.isPlaying, "Not playing once completed");
					Assert.equalsNumber(si.position, si.totalLength, 0.01, "Position at the end once completed");
					Assert.equalsInt(si.currentLoop, 0, "Current loop once completed is the last one played");
					Assert.equalsInt(si.loopsRemaining, 0, "No loop remaining once completed");

					si.destroy();
					next();
				});
			});
		}

		private function testCompletedInstanceKeptAlive(next:Function):void
		{
			var manager:SoundManager = createManager(false);
			var si:SoundInstance = manager.play("short");
			assertPlaying(si);
			si.freeWhenCompleted = false;
			si.completed.add(function(instance:SoundInstance):void
			{
				defer(function():void
				{
					Assert.isFalse(si.isDestroyed, "Kept alive on completion");
					Assert.isFalse(si.isPlaying, "Not playing once completed");
					Assert.isFalse(si.isStarted, "Not started once completed");
					Assert.isFalse(si.isPaused, "Not paused once completed");
					Assert.equalsNumber(si.position, si.totalLength, 0.01, "Position at the end once completed");
					Assert.isNull(si.manager, "Removed from the manager on completion");
					Assert.equalsInt(manager.getSoundInstancesCount(), 0, "Manager empty on completion");

					si.destroy();
					next();
				});
			});
		}

		private function testCompletionReleasesToPool(next:Function):void
		{
			var manager:SoundManager = createManager(true);
			var si:SoundInstance = manager.play("short");
			assertPlaying(si);
			Assert.isTrue(si.isFromPool, "Instance from pool");
			manager.soundInstanceReleasedToPool.add(function(instance:SoundInstance, pool:SoundInstancesPool):void
			{
				defer(function():void
				{
					Assert.isTrue(instance == si, "Completed instance released to the pool");
					Assert.isFalse(si.isDestroyed, "Released instance not destroyed");
					Assert.isNull(si.manager, "Released instance removed from the manager");
					Assert.equalsInt(manager.getSoundInstancesCount(), 0, "Manager empty after release");
					next();
				});
			});
		}

		private function testTrackEndingOnSamplingBoundaryCompletes(next:Function):void
		{
			// The last sampling request of such a track gets no sample
			var track:ProbeTrack = ProbeTrack.toneWithSilences(0, 2 * TrackConfiguration.SAMPLING_MIN_VALUE, 0);
			var manager:SoundManager = new SoundManager();
			manager.volume = 0;
			manager.registerTrack("two-blocks", track);

			var completedCount:int = 0;
			var si:SoundInstance = manager.play("two-blocks");
			assertPlaying(si);
			si.freeWhenCompleted = false;
			si.completed.add(function(instance:SoundInstance):void
			{
				completedCount++;

				// Leave the time for a second completion to occur
				defer(function():void
				{
					Assert.equalsInt(completedCount, 1, "Completed once");

					si.destroy();
					next();
				}, 200);
			});
		}

		private function testLoopingTrackWithoutSamplesCompletes(next:Function):void
		{
			var track:ProbeTrack = ProbeTrack.tone(1000);
			track.isExtractionEmpty = true;
			var manager:SoundManager = new SoundManager();
			manager.volume = 0;
			manager.registerTrack("no-samples", track);

			var si:SoundInstance = manager.play("no-samples", 1, 0, -1);
			si.destroyed.add(function(instance:SoundInstance):void
			{
				defer(function():void
				{
					Assert.isTrue(track.extractCount > 0, "Samples requested from the track");
					Assert.equalsInt(manager.getSoundInstancesCount(), 0, "Removed from the manager on completion");
					next();
				});
			});
		}

		//---------------------------------------------------------------------
		//-- Helpers
		//---------------------------------------------------------------------

		private function createManager(isPoolingEnabled:Boolean):SoundManager
		{
			var manager:SoundManager = new SoundManager();
			manager.volume = 0;
			manager.isPoolingEnabled = isPoolingEnabled;
			manager.registerTrack("short", ProbeTrack.tone(TRACK_DURATION));
			return manager;
		}

		private function assertPlaying(si:SoundInstance):void
		{
			Assert.isTrue(si.isPlaying, "Not playing, a sound output device is required.");
		}
	}
}
