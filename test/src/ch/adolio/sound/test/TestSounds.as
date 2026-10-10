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
	import flash.media.Sound;

	/**
	 * Sound files embedded for the tests which need a native sound: a synthetic track is always custom sampled.
	 */
	public class TestSounds
	{
		[Embed(source = "../../../../../../demo/media/sounds/piano_MP3_mono_44100.mp3")]
		private static const PianoMp3:Class;

		/**
		 * Creates an MP3 track of about 8 seconds, played as a standard sound when not trimmed nor pitched.
		 */
		public static function createMp3Track():Mp3Track
		{
			return new Mp3Track(new PianoMp3() as Sound);
		}
	}
}
