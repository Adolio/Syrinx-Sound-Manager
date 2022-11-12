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
	import feathers.themes.AeonDesktopTheme;
	import starling.display.Sprite;
	import ch.adolio.sound.SoundManagerTest;
	import feathers.themes.MetalWorksDesktopTheme;
	import feathers.themes.MinimalDesktopTheme;

	public class StarlingMain extends Sprite
	{
		public function StarlingMain()
		{
			// Theme selection
			//new AeonDesktopTheme();
			//new MetalWorksDesktopTheme();
			new MinimalDesktopTheme();

			// Add sound test scene
			addChild(new SoundManagerTest());
		}
	}
}