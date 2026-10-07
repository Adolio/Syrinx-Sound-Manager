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
	import ch.adolio.sound.SoundInstancesPool;
	import ch.adolio.sound.SoundManager;
	import ch.adolio.test.Assert;
	import ch.adolio.test.ITestAsync;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;

	/**
	 * Sounds played until their completion: destruction, loops, instances kept alive & release to the pool.
	 *
	 * Scenarios run one after the other. Each one plays a 100 ms synthetic track at a master volume of 0 & calls
	 * <code>next</code> once its checks are done. Checks following a signal are deferred, so that they run once the
	 * signal dispatch is over.
	 */
	public class CompletionTestAsync implements ITestAsync
	{
		private static const TRACK_DURATION:Number = 100; // In milliseconds

		private var _onSuccess:Function;
		private var _onFail:Function;

		public function executeAsync(onSuccess:Function, onFail:Function):void
		{
			_onSuccess = onSuccess;
			_onFail = onFail;

			runScenarios([
				testCompletionDestroysInstance,
				testLoopsPlayedBeforeCompletion,
				testCompletedInstanceKeptAlive,
				testCompletionReleasesToPool]);
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

		private function testLoopsPlayedBeforeCompletion(next:Function):void
		{
			var manager:SoundManager = createManager(false);
			var startTime:int = getTimer();
			var si:SoundInstance = manager.play("short", 1, 0, 2);
			assertPlaying(si);
			si.destroyed.add(function(instance:SoundInstance):void
			{
				defer(function():void
				{
					var elapsedTime:int = getTimer() - startTime;
					Assert.isTrue(elapsedTime >= 2.5 * TRACK_DURATION, "Three repetitions played before completion. Elapsed time: " + elapsedTime + " ms");
					Assert.equalsInt(si.currentLoop, 2, "Last loop reached");
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

		//---------------------------------------------------------------------
		//-- Helpers
		//---------------------------------------------------------------------

		/**
		 * Runs the scenarios (<code>function(next:Function):void</code>) one after the other.
		 */
		private function runScenarios(scenarios:Array):void
		{
			if (scenarios.length == 0)
			{
				_onSuccess();
				return;
			}

			var scenario:Function = scenarios.shift();
			attempt(function():void
			{
				scenario(function():void { runScenarios(scenarios); });
			});
		}

		/**
		 * Runs a block & fails the test if it raises an error.
		 */
		private function attempt(block:Function):void
		{
			try
			{
				block();
			}
			catch (error:Error)
			{
				_onFail(error);
			}
		}

		/**
		 * Runs a block once the current call stack, including any signal dispatch in progress, is over.
		 */
		private function defer(block:Function):void
		{
			setTimeout(function():void { attempt(block); }, 0);
		}

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
