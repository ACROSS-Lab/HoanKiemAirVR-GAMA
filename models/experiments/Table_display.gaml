/**
* Name: Tabledisplay
* Based on the internal empty template. 
* Author: m2l2
* Tags: 
*/


model Tabledisplay

import "Abstract Experiment.gaml"


experiment Table_display autorun: true parent: abstract_xp{
	output {
	
		display Table_ parent:Table  type: 3d fullscreen: 0 {}
	
	}
	
}
