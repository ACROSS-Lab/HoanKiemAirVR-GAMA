/***
* Name: traffic
* Author: minhduc0711
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model traffic 

import "UnityLink.gaml"
import "Building.gaml"

global {
	string CAR <- "car";
	string MOTO <- "motorbike";
	string OUT <- "outArea";	
	graph road_network;
	float lane_width <- 1.0;
}
 



//species road  skills: [road_skill]{
//	string type;
//	bool oneway;
//	bool s1_closed;
//	bool s2_closed;
//	int num_lanes <- 4;
//	bool closed;
//	float capacity ;
//	int nb_vehicles <- length(all_agents) update: length(all_agents);
//	float speed_coeff <- 1.0 min: 0.1 update: 1.0 - (nb_vehicles/ capacity);
//	init {
//		 capacity <- 1 + (num_lanes * shape.perimeter/3);
//	}
//}


species car parent: vehicle {
	string type <- CAR;
	float vehicle_length <- 4.5 #m;
	int num_lanes_occupied <-2;
	float max_speed <-rnd(50,70) #km / #h;
	int index_species <- 1;
	
		
}

species motorbike parent: vehicle {
	string type <- MOTO;
	float vehicle_length <- 2.8 #m;
	int num_lanes_occupied <-1;
	float max_speed <-rnd(40,50) #km / #h;
	int index_species <- 0;
	
}

species vehicle skills:[driving] parent: agent_to_send {
	string type;
	building target;
	point shift_pt <- location ;	
	bool at_home <- true;
	init {
		
		proba_respect_priorities <- 0.0;
		proba_respect_stops <- [0.0];
		proba_use_linked_road <- 0.0;

		lane_change_limit <- 5;
		linked_lane_limit <- 0; 
		location <- one_of(building).location;
	}

	action select_target_path {
		location <- (intersection closest_to self).location;
		target <- one_of(building);
		do compute_path graph: road_network target: target.closest_intersection; 
		if (current_path = nil) {
			do unregister;
			do die;
		}
	}
	
	reflex choose_path when: final_target = nil  {
		do select_target_path;
	}
	
	reflex move when: final_target != nil {
		do drive;
		if (final_target = nil) {
			do unregister;
			at_home <- true;
			location <- target.location;
		} else {
			shift_pt <- compute_position();
		}
		
	}
	
	
	point compute_position {
		// Shifts the position of the vehicle perpendicularly to the road,
		// in order to visualize different lanes
		if (current_road != nil) {
			float dist <- (road(current_road).num_lanes - current_lane -
				mean(range(num_lanes_occupied - 1)) - 0.5) * lane_width;
			if violating_oneway {
				dist <- -dist;
			}
		 	
			return location + {cos(heading + 90) * dist, sin(heading + 90) * dist};
		} else {
			return {0, 0};
		}
	}	
	
}




