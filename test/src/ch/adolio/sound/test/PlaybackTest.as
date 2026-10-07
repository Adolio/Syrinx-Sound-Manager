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
			testStandardSound();
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
