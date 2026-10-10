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
	import ch.adolio.sound.SoundManager;
	import ch.adolio.test.Assert;
	import ch.adolio.test.ITest;
	import flash.media.Sound;

	/**
	 * Playback controls (play, pause, resume, stop, position), loops setup & stopping all sounds, for custom sampled
	 * sounds (synthetic track) & standard sounds (MP3 track without trimming nor pitch).
	 *
	 * Sounds are played at a master volume of 0: the run is silent, but a sound output device is still required to
	 * acquire sound channels. Tracks last 1000 ms.
	 */
	public class PlaybackTest implements ITest
	{
		[Embed(source = "../../../../../../demo/media/sounds/piano_MP3_mono_44100.mp3")]
		private static const PianoMp3:Class;

		private static const EPSILON:Number = 0.000001;

		public function execute():void
		{
			testPlayPauseResumeStop();
			testLoopsSetup();
			testPositionChanges();
			testStopAll();
			testStopAllWithListenersFreeingInstances();
			testStandardSound();
			testSoundsWithoutLength();
			testCompletedListenersCalledBeforeFreeing();
			testFractionalTrims();
			testAutomaticTrimsReadExactly();
		}

		private function testPlayPauseResumeStop():void
		{
			var manager:SoundManager = createManager();
			manager.registerTrack("tone", ProbeTrack.tone(1000));
			var counts:Object = { started: 0, paused: 0, resumed: 0, stopped: 0 };

			var si:SoundInstance = manager.play("tone");
			si.started.add(function(instance:SoundInstance):void { counts.started++; });
			si.paused.add(function(instance:SoundInstance):void { counts.paused++; });
			si.resumed.add(function(instance:SoundInstance):void { counts.resumed++; });
			si.stopped.add(function(instance:SoundInstance):void { counts.stopped++; });
			assertPlaying(si, "Played");
			Assert.isTrue(si.isStarted, "Started");
			Assert.isFalse(si.isPaused, "Not paused");
			Assert.equalsNumber(si.volume, 1, EPSILON, "Volume");
			Assert.equalsNumber(si.mixedVolume, 0, EPSILON, "Silent mixed volume");
			Assert.equalsInt(manager.getPlayingSoundInstancesCount(), 1, "Playing instances count");

			si.pause();
			Assert.equalsInt(counts.paused, 1, "Paused signal");
			Assert.isTrue(si.isPaused, "Paused");
			Assert.isFalse(si.isPlaying, "Not playing while paused");
			Assert.isTrue(si.isStarted, "Still started while paused");
			Assert.equalsInt(manager.getPlayingSoundInstancesCount(), 0, "No playing instances while paused");

			si.pause();
			Assert.equalsInt(counts.paused, 1, "Second pause ignored");

			si.resume();
			Assert.equalsInt(counts.resumed, 1, "Resumed signal");
			assertPlaying(si, "Resumed");
			Assert.isFalse(si.isPaused, "Not paused after resume");

			si.resume();
			Assert.equalsInt(counts.resumed, 1, "Second resume ignored");

			si.stop();
			Assert.equalsInt(counts.stopped, 1, "Stopped signal");
			Assert.isFalse(si.isStarted, "Not started after stop");
			Assert.isFalse(si.isPlaying, "Not playing after stop");
			Assert.isFalse(si.isPaused, "Not paused after stop");
			Assert.equalsNumber(si.position, 0, EPSILON, "Position reset by stop");
			Assert.equalsInt(manager.getSoundInstancesCount(), 1, "Stopped instance kept by the manager");

			si.play();
			Assert.equalsInt(counts.started, 1, "Started signal when played again after stop");
			assertPlaying(si, "Played again after stop");

			si.isPaused = true;
			Assert.isTrue(si.isPaused, "Paused through the property");
			si.isPaused = false;
			assertPlaying(si, "Resumed through the property");

			manager.destroyAllSoundInstances();
		}

		private function testLoopsSetup():void
		{
			var manager:SoundManager = createManager();
			manager.registerTrack("tone", ProbeTrack.tone(1000));

			var si:SoundInstance = manager.play("tone", 1, 0, 2);
			assertPlaying(si, "Played with loops");
			Assert.equalsInt(si.loops, 2, "Loops");
			Assert.equalsInt(si.loopsRemaining, 2, "Loops remaining");
			Assert.equalsInt(si.currentLoop, 0, "Current loop");
			Assert.equalsNumber(si.totalLength, 3000, EPSILON, "Total length with loops");

			si.play(1, 2500, 3);
			assertPlaying(si, "Played from the third loop");
			Assert.equalsInt(si.currentLoop, 2, "Current loop from the start time");
			Assert.equalsInt(si.loopsRemaining, 1, "Loops remaining from the start time");
			Assert.equalsNumber(si.totalLength, 4000, EPSILON, "Total length with 3 loops");

			si.pause();
			si.position = 2500;
			Assert.equalsNumber(si.remainingTime, 1500, EPSILON, "Remaining time from the third loop");

			si.play(1, 0, -1);
			assertPlaying(si, "Played with infinite looping");
			Assert.equalsInt(si.loops, -1, "Infinite loops");
			Assert.equalsInt(si.loopsRemaining, -1, "Infinite loops remaining");
			Assert.equalsNumber(si.totalLength, Number.POSITIVE_INFINITY, 0, "Infinite total length");
			Assert.equalsNumber(si.remainingTime, Number.POSITIVE_INFINITY, 0, "Infinite remaining time");
			Assert.equalsNumber(si.positionRatio, 0, EPSILON, "Position ratio of an infinite loop");

			Assert.throws(ArgumentError, function():void { si.play(1, -1); }, "Negative start time");

			manager.destroyAllSoundInstances();
		}

		private function testPositionChanges():void
		{
			var manager:SoundManager = createManager();
			manager.registerTrack("tone", ProbeTrack.tone(1000));
			var si:SoundInstance = manager.play("tone");

			si.position = 300;
			assertPlaying(si, "Still playing after a position change");

			si.pause();
			si.position = 600;
			Assert.equalsNumber(si.position, 600, EPSILON, "Position changed while paused");
			Assert.isTrue(si.isPaused, "Still paused after a position change");
			Assert.isFalse(si.isPlaying, "Not playing after a position change while paused");

			si.resume();
			assertPlaying(si, "Resumed after a position change");

			manager.destroyAllSoundInstances();
		}

		private function testStopAll():void
		{
			var manager:SoundManager = createManager();
			manager.registerTrack("tone", ProbeTrack.tone(1000));
			var si1:SoundInstance = manager.play("tone");
			var si2:SoundInstance = manager.play("tone");
			Assert.equalsInt(manager.getPlayingSoundInstancesCount(), 2, "Two playing instances");

			manager.stopAll();
			Assert.equalsInt(manager.getPlayingSoundInstancesCount(), 0, "No playing instances after stop all");
			Assert.isFalse(si1.isStarted, "First instance stopped");
			Assert.isFalse(si2.isStarted, "Second instance stopped");
			Assert.equalsInt(manager.getSoundInstancesCount(), 2, "Stopped instances kept by the manager");

			manager.destroyAllSoundInstances();
		}

		private function testStandardSound():void
		{
			var track:Mp3Track = new Mp3Track(new PianoMp3() as Sound);
			Assert.isTrue(track.length > 1000, "MP3 track length");

			var manager:SoundManager = createManager();
			manager.registerTrack("piano", track);
			var si:SoundInstance = manager.play("piano");
			assertPlaying(si, "MP3 played");
			Assert.equalsNumber(si.length, track.length, EPSILON, "MP3 instance length");

			si.position = 1000;
			assertPlaying(si, "MP3 still playing after a position change");
			si.pause();
			Assert.equalsNumber(si.position, 1000, 50, "MP3 position kept when paused");

			si.resume();
			assertPlaying(si, "MP3 resumed");

			si.stop();
			Assert.isFalse(si.isPlaying, "MP3 stopped");

			manager.destroyAllSoundInstances();
		}

		private function testStopAllWithListenersFreeingInstances():void
		{
			var manager:SoundManager = createManager();
			manager.registerTrack("tone", ProbeTrack.tone(1000));
			var si1:SoundInstance = manager.play("tone");
			var si2:SoundInstance = manager.play("tone");
			var si3:SoundInstance = manager.play("tone");
			si1.stopped.add(function(instance:SoundInstance):void
			{
				si1.destroy();
				si2.destroy();
			});

			manager.stopAll();
			Assert.isTrue(si1.isDestroyed, "First instance destroyed by its listener");
			Assert.isTrue(si2.isDestroyed, "Second instance destroyed by the listener of the first one");
			Assert.isFalse(si3.isStarted, "Third instance stopped");
			Assert.equalsInt(manager.getSoundInstancesCount(), 1, "Third instance kept by the manager");

			manager.destroyAllSoundInstances();
		}

		private function testCompletedListenersCalledBeforeFreeing():void
		{
			// A sound without length completes as soon as it is played
			var manager:SoundManager = createManager();
			manager.registerTrack("empty", new ProbeTrack(new Vector.<Number>()));
			var si:SoundInstance = new SoundInstance(manager.findRegisteredTrack("empty"), manager);

			var wasDestroyed:Boolean = true;
			var listenerManager:SoundManager = null;
			si.completed.add(function(instance:SoundInstance):void
			{
				wasDestroyed = si.isDestroyed;
				listenerManager = si.manager;
			});

			si.play();
			Assert.isFalse(wasDestroyed, "Not destroyed yet for the completed listeners");
			Assert.isTrue(listenerManager == manager, "Still in its manager for the completed listeners");
			Assert.isTrue(si.isDestroyed, "Destroyed once the completed listeners are called");
			Assert.equalsInt(manager.getSoundInstancesCount(), 0, "Removed from the manager");
		}

		private function testSoundsWithoutLength():void
		{
			var manager:SoundManager = createManager();
			manager.registerTrack("trimmed", ProbeTrack.tone(1000), 400, 600);
			manager.registerTrack("empty", new ProbeTrack(new Vector.<Number>()));

			for each (var type:String in ["trimmed", "empty"])
			{
				for each (var loops:int in [0, 2, -1])
				{
					var context:String = "Type: " + type + ", loops: " + loops;
					var completedCount:int = 0;
					var si:SoundInstance = new SoundInstance(manager.findRegisteredTrack(type), manager);
					si.completed.add(function(instance:SoundInstance):void { completedCount++; });
					Assert.equalsNumber(si.length, 0, EPSILON, "No length. " + context);

					si.play(1, 0, loops);
					Assert.equalsInt(completedCount, 1, "Completed when played. " + context);
					Assert.isTrue(si.isDestroyed, "Destroyed when played. " + context);
					Assert.equalsInt(manager.getSoundInstancesCount(), 0, "Removed from the manager when played. " + context);
				}
			}
		}

		private function testFractionalTrims():void
		{
			// The first sampling request, made when played, starts from the start trim
			var manager:SoundManager = createManager();
			var track:ProbeTrack = ProbeTrack.tone(1000);
			manager.registerTrack("tone", track, 100.5, 200.25);

			var si:SoundInstance = manager.play("tone");
			assertPlaying(si, "Played with fractional trims");
			Assert.equalsNumber(si.length, 1000 - 100.5 - 200.25, EPSILON, "Length with fractional trims");
			Assert.equalsInt(track.lowestExtractedSample, Math.round(100.5 * ProbeTrack.SAMPLE_RATE_MS), "First sample read with a fractional start trim");

			manager.destroyAllSoundInstances();
		}

		private function testAutomaticTrimsReadExactly():void
		{
			// Silences which are not a whole number of milliseconds, & whose conversion back to samples falls just below a whole number
			var manager:SoundManager = createManager();
			var track:ProbeTrack = ProbeTrack.toneWithSilences(4001, 8000, 900);
			manager.registerTrack("tone", track, -1, -1);
			track.resetExtractionRecords(); // The trims detection reads the track

			// Played 10 ms before its end: the first sampling request reads up to the end trim
			var si:SoundInstance = new SoundInstance(manager.findRegisteredTrack("tone"), manager);
			Assert.equalsNumber(si.length, 8000 / ProbeTrack.SAMPLE_RATE_MS, EPSILON, "Length between the automatic trims");
			si.play(1, si.length - 10);
			assertPlaying(si, "Played near the end trim");
			Assert.equalsInt(track.highestExtractedSample, 4001 + 8000 - 1, "Last sample read is the last one of the tone");

			// Played from its start
			var first:ProbeTrack = ProbeTrack.toneWithSilences(4001, 8000, 900);
			manager.registerTrack("other", first, -1, -1);
			first.resetExtractionRecords();
			assertPlaying(manager.play("other"), "Played from the start trim");
			Assert.equalsInt(first.lowestExtractedSample, 4001, "First sample read is the first one of the tone");

			manager.destroyAllSoundInstances();
		}

		private function createManager():SoundManager
		{
			var manager:SoundManager = new SoundManager();
			manager.volume = 0;
			return manager;
		}

		private function assertPlaying(si:SoundInstance, context:String):void
		{
			Assert.isTrue(si.isPlaying, "Not playing, a sound output device is required. Context: " + context);
		}
	}
}
