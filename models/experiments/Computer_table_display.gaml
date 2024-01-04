/**
* Name: ComputerTabledisplay
* Based on the internal empty template. 
* Author: m2l2
* Tags: 
*/


model ComputerTabledisplay

import "Abstract Experiment.gaml"


experiment computer_table_display autorun: true parent: abstract_xp{
	output {
	
		display Table_ parent:Table  type: 3d fullscreen: 0 
		keystone: [{-0.11553694650521354,-0.04038172528678441,0.0},{-0.11135082525502471,1.1342098516884298,0.0},{1.0092094667504155,1.0,0.0},{1.0159072607507178,-0.03206784066891699,0.0}]
		{}
		display Computer_ parent:Computer  type: 3d fullscreen: 1 {}
	}
	
}
