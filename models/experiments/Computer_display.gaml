/**
* Name: Onecomputerdisplay
* Based on the internal empty template. 
* Author: m2l2
* Tags: 
*/


model Computerdisplay

import "Abstract Experiment.gaml"


experiment Computer_display autorun: true parent: abstract_xp{
	output {
	
		display Computer_ parent:Computer  type: 3d fullscreen: 0 {}
	
	}
	
}
