/**
* Name: Buidling
* Based on the internal empty template. 
* Author: across
* Tags: 
*/



model Buidling

import "Intersection.gaml"

species building schedules: [] {
	intersection closest_intersection <- intersection closest_to self;
	string type;
	geometry pollution_perception <- shape+50;
	int pollution_index;
	int pollution_index_scale;
	map to_array {
		return map("b"::[int(self), pollution_index]);
	}
}


species natural schedules: [] {}



species decoration_building schedules: [] {}