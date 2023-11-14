/**
* Name: Intersection
* Based on the internal empty template. 
* Author: across
* Tags: 
*/


model Intersection

import "Road.gaml"

global {
	list<intersection> open_intersections ;
	
}
species intersection  skills: [intersection_skill] {
	bool is_traffic_signal;
	int counter <- 60 ;
	rgb color_centr; 
	rgb color_fire;
	float centrality;	
	bool is_blocked <- false;
	bool is_crossing;
	list<road> ways1;
	list<road> ways2;
	bool is_green;
	int time_to_change <- 60;
	list<road> neighbours_tj;
	int pb_start <- 0;
	int pb_end <- 0;
	int id;
	bool existing <- false;
	
	action compute_crossing{
		if (empty(stop)) {
			stop << [];
		}
		ways1 <- [];
		ways2 <- [];
		if (is_crossing and not(empty(roads_in))) or (length(roads_in) >= 2) {
			road rd0 <- road(roads_in[0]);
			list<point> pts <- rd0.shape.points;						
			float ref_angle <-  float( last(pts) direction_to rd0.location);
			loop rd over: roads_in {
				list<point> pts2 <- road(rd).shape.points;						
				float angle_dest <-  float( last(pts2) direction_to rd.location);
				float ang <- abs(angle_dest - ref_angle);
				if (ang > 45 and ang < 135) or  (ang > 225 and ang < 315) {
					add road(rd) to: ways2;
				}
			}
		} else {
			ways1 <- list<road> (roads_in);
		}
		
	}
	
	action to_green {					
		stop[0] <-  ways2 ;
		color_fire <- rgb("green");
		is_green <- true;
	}
	
	action to_red {							
		stop[0] <- ways1;
		color_fire <- rgb("red");
		is_green <- false; 
	} 
	reflex dynamic_node when: is_traffic_signal {
		counter <- counter + 1;
		if (counter >= time_to_change) { 	/// A REMETTRE SI ON VEUT DES FEUX
			counter <- 0;
			if is_green {do to_red;}
			else {do to_green;}
		}  	
	}
	
	aspect default {  
		if existing {
			if (is_traffic_signal) {	
				draw sphere(5) color: color_fire;
			} 
		}  
		
	} 
	
	
}

