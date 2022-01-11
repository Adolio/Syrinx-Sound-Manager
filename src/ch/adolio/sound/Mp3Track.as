// =================================================================================================
//
//	Syrinx - Sound Manager
//	Copyright (c) 2019 Aurelien Da Campo (Adolio), All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package ch.adolio.sound
{
	import flash.media.Sound;
	import flash.utils.ByteArray;

	/**
	 * Native sound track (MP3) wrapper.
	 *
	 * @author Aurelien Da Campo
	 */
	public class Mp3Track extends ch.adolio.sound.Track
	{
		private var _nativeSound:flash.media.Sound;

		public function get sound():flash.media.Sound
		{
			return _nativeSound;
		}

		public function Mp3Track(nativeSound:flash.media.Sound)
		{
			_nativeSound = nativeSound;
		}

		public override function get length():Number
		{
			return _nativeSound.length;
		}

		public override function extract(target:ByteArray, length:Number, startPosition:Number = -1):Number
		{
			return _nativeSound.extract(target, length, startPosition);
		}

		public override function destroy():void
		{
			// Nullify references
			_nativeSound = null;
		}
	}
}