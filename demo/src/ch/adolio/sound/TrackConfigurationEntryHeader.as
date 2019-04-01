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
	import feathers.controls.Label;
	import feathers.controls.LayoutGroup;
	import feathers.layout.HorizontalLayout;
	import starling.display.Quad;
	import starling.display.Sprite;
	import starling.core.Starling;
	
	public class TrackConfigurationEntryHeader extends Sprite
	{
		public function TrackConfigurationEntryHeader()
		{
			// background
			var quad:Quad = new Quad(Starling.current.stage.stageWidth, 25, 0xffffff);
			quad.alpha = 0.8;
			addChild(quad);
			
			// horizontal layout
			var layout:HorizontalLayout = new HorizontalLayout();
			layout.padding = 2;
			layout.gap = 4;
			var container:LayoutGroup = new LayoutGroup();
			container.layout = layout;
			container.width = quad.width;
			container.height = quad.height;
			this.addChild(container);
			
			// sound label
			var soundTypeLabel:Label = new Label();
			soundTypeLabel.width = 160;
			soundTypeLabel.text = "Type";
			container.addChild(soundTypeLabel);
			
			// sound length in ms
			var soundLength:Label = new Label();
			soundLength.width = 80;
			soundLength.text = "Duration (ms)";
			container.addChild(soundLength);
			
			// Trim start label
			var trimStart:Label = new Label();
			trimStart.width = 80;
			trimStart.text = "Trim start (ms)";
			container.addChild(trimStart);
			
			// Trim end label
			var trimEnd:Label = new Label();
			trimEnd.width = 80;
			trimEnd.text = "Trim end (ms)";
			container.addChild(trimEnd);
			
			// Auto button
			var autoSeparator:Quad = new Quad(60, 1);
			autoSeparator.alpha = 0;
			container.addChild(autoSeparator);
			
			//-----------------------------------------------------------------
			//-- Controls
			//-----------------------------------------------------------------
			
			// Separator
			var separator:Quad = new Quad(20, 1);
			separator.alpha = 0;
			container.addChild(separator);
			
			// Loop label
			var loopLabel:Label = new Label();
			loopLabel.text = "Loops";
			loopLabel.width = 80;
			container.addChild(loopLabel);
			
			// Start position label
			var startPositionLabel:Label = new Label();
			startPositionLabel.text = "Start pos (ms)";
			startPositionLabel.width = 80;
			container.addChild(startPositionLabel);
		}
	}
}