// =================================================================================================
//
//	Syrinx - Sound Manager
//	Copyright (c) 2019-2022 Aurelien Da Campo (Adolio), All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package ch.adolio
{
	import flash.display.Sprite;
	import starling.core.Starling;

	public class Main extends Sprite
	{
		public function Main()
		{
			// Setup targetted frame rate
			stage.frameRate = 60;

			// Setup Starling
			var starling:Starling = new Starling(StarlingMain, stage);
			starling.start();
		}
	}
}