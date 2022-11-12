// =================================================================================================
//
//	Syrinx - Sound Manager
//	Copyright (c) 2019-2022 Aurelien Da Campo (Adolio), All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package ch.adolio.sound
{
	import feathers.controls.Label;
	import feathers.controls.LayoutGroup;
	import feathers.layout.HorizontalLayout;
	import starling.display.Quad;
	import starling.display.Sprite;
	import starling.core.Starling;

	public class SoundInstanceEntryHeader extends Sprite
	{
		private var _soundNameLabel:Label;
		private var _pauseResumeLabel:Label;
		private var _stopLabel:Label;
		private var _positionLabel:Label;
		private var _muteLabel:Label;

		public function SoundInstanceEntryHeader()
		{
			// background
			var quad:Quad = new Quad(Starling.current.stage.stageWidth, 30, 0xffffff);
			quad.alpha = 0.8;
			addChild(quad);

			// horizontal layout
			var layout:HorizontalLayout = new HorizontalLayout();
			layout.padding = 5;
			layout.gap = 5;
			var container:LayoutGroup = new LayoutGroup();
			container.layout = layout;
			container.width = quad.width;
			container.height = quad.height;
			this.addChild(container);

			// sound label
			_soundNameLabel = new Label();
			_soundNameLabel.width = 160;
			_soundNameLabel.text = "Id (Type)";
			container.addChild(_soundNameLabel);

			// position slider
			_positionLabel = new Label();
			_positionLabel.text = "Position";
			_positionLabel.width = 200;
			container.addChild(_positionLabel);

			// loops label
			var loopsLabel:Label = new Label();
			loopsLabel.text = "Loops";
			loopsLabel.width = 40;
			container.addChild(loopsLabel);

			// volume label
			var volumeLabel:Label = new Label();
			volumeLabel.text = "Volume";
			volumeLabel.width = 100;
			container.addChild(volumeLabel);

			// Mute
			_muteLabel = new Label();
			_muteLabel.text = "Mute";
			_muteLabel.width = 30;
			container.addChild(_muteLabel);

			// Pan label
			var panLabel:Label = new Label();
			panLabel.text = "Pan";
			panLabel.width = 100;
			container.addChild(panLabel);

			// Pitch label
			var pitchLabel:Label = new Label();
			pitchLabel.text = "Pitch";
			pitchLabel.width = 100;
			container.addChild(pitchLabel);

			// Pause / resume label
			_pauseResumeLabel = new Label();
			_pauseResumeLabel.width = 60;
			container.addChild(_pauseResumeLabel);

			// Stop button
			_stopLabel = new Label();
			_stopLabel.width = 60;
			container.addChild(_stopLabel);
		}
	}
}