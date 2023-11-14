/**
* Name: Road
* Based on the internal empty template. 
* Author: across
* Tags: 
*/


model Road



/* Insert your model definition here */
species road  skills: [road_skill]{
	string type;
	string oneway_string;
	string junction;
	int lanes_forward;
	int lanes_backward;
	bool oneway;
	bool s1_closed;
	bool s2_closed;
	int num_lanes ;
	bool closed;

}
