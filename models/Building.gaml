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
	int pollution_index <- 0;
	int pollution_index_scale <- 0;
	
	map to_array {
		return map("b"::[int(self), pollution_index]);
	}
}




species decoration_building schedules: [] {}

species natural schedules: [] {}