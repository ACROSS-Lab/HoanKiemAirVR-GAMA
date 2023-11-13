 /***
* Name: Main
* Author: minhduc0711 & Alexis Drogoul
* Description: 
***/
model main 

import "Pollution.gaml"


global {
	
	bool udpate_roads <- false;
	float step <- 1.0 #s;
	list<road> open_roads;
	float player_size_GAMA <- 20.0;

	//Colors and icons
	string images_dir <- "../images/";
	list<rgb> pal <- palette([#green, #yellow, #orange, #red]);
	map<rgb, string>
	legends <- [color_inner_building::"District Buildings", color_outer_building::"Outer Buildings", color_road::"Roads", color_closed::"Closed Roads", color_lake::"Rivers & lakes", color_car::"Cars", color_moto::"Motorbikes"];
	rgb color_car <- #lightblue;
	rgb color_moto <- #cyan;
	rgb color_road <- #lightgray;
	rgb color_closed <- #mediumpurple;
	rgb color_inner_building <- rgb(100, 100, 100);
	rgb color_outer_building <- rgb(60, 60, 60);
	rgb color_lake <- rgb(165, 199, 238, 255);
	map<string,list<road>> name_to_roads;
	// Initialization 
	string resources_dir <- "../data/";

	// Load shapefiles
	shape_file buildings_shape_file <- shape_file(resources_dir + "buildings.shp");

	geometry shape <- envelope(buildings_shape_file);


	list<string> previous_closed_roads;
	
	
	int cars <- 200;
	int motos <- 700;

	init {
		create road from: shape_file(resources_dir + "roads.shp");
		loop r over: road {
			if (!r.oneway) {
				create road with: (shape: polyline(reverse(r.shape.points)), name: r.name, type: r.type, s1_closed: r.s1_closed, s2_closed: r.s2_closed);
			} 
		}
		ask road {
			if  name = nil or  name = "" {
				name <- "road_" + int(self);
			}
		}
			
		// ######################################################################
//		create building from: shape_file(buildings_shape_file) {
//			if (shape.area < 0.1) {
//				do die;
//			}
//		}
		
		 create building from: shape_file(buildings_shape_file);
		// ######################################################################
			
		ask road {
			agent ag <- building closest_to self;
			float dist <- ag = nil ? 8.0 : max(min( ag distance_to self - 5.0, 8.0), 2.0);
			num_lanes <- int(dist / lane_width);
			 capacity <- 1 + (num_lanes * shape.perimeter/3);
		}
		

		do update_road_scenario(0); 
		
		name_to_roads <- road group_by each.name;

		
		// ######################################################################
		//name_to_roads <- road group_by each.name;
		// Send roads geometries to Unity with a collider
		
		// ######################################################################
	}
	
	// ######################################################################
	point new_player_location(point loc) {
		road r <- road closest_to loc;
		return (r closest_points_with loc)[0];
	}
	// ######################################################################

	action update_motorbike_population (int new_number) {
		int delta <- length(motorbike) - new_number;
		if (delta > 0) {
			ask delta among motorbike {
				do unregister;
				do die;
			}

		} else if (delta < 0) {
			create motorbike number: -delta ;
		}

	}
	action update_car_population (int new_number) {
		int delta <- length(car) - new_number;
		if (delta > 0) {
			ask delta among car {
				do unregister;
				do die;
			}

		} else if (delta < 0) {
			create car number: -delta ;
		}

	}
	
	
	//just here for debugging purpose.	
	reflex updating_traffic {
		do update_car_population(cars);
		do update_motorbike_population( motos);
		if (udpate_roads) {
			do update_road_closed;
			udpate_roads <- false;
		}
	}
	
	action update_road_closed {
		open_roads <- road where (not each.closed);
		
		ask agents of_generic_species vehicle {
			do unregister;
		}
		
		
		ask road where (each.closed)  {
			ask (car + motorbike) at_distance 10.0 {
				do die;	
			}
		}
		
		
		
		ask building {
			closest_intersection <- nil;
		}

		ask intersection {
			do die;
		}
		

		graph g <- as_edge_graph(open_roads);
		loop pt over: g.vertices {
			create intersection with: (shape: pt);
		}

		ask building {
			closest_intersection <- intersection closest_to self;
		}
		ask road {
			vehicle_ordering <- nil;
		}
		//build the graph from the roads and intersections
		road_network <- as_driving_graph(open_roads, intersection) with_shortest_path_algorithm #FloydWarshall;
		//geometry road_geometry <- union(open_roads accumulate (each.shape));
		ask agents of_generic_species vehicle {
			do select_target_path;
		} 
		
		do update_car_population(cars);
		do update_motorbike_population( motos);
		
	}
	
	action update_road_scenario (int scenario) {
		open_roads <- scenario = 1 ? road where !each.s1_closed : (scenario = 2 ? road where !each.s2_closed : list(road));
		// Change the display of roads
		list<road> closed_roads <- road - open_roads;
		ask open_roads {
			closed <- false;
		}

		ask closed_roads {
			closed <- true;
		}

		do update_road_closed;
	}
	
	// ######################################################################


	//filter the agents to send to avoid agents too close to each other - can be overrided 
//	list<agent_to_send> filter_overlapping(list<agent_to_send> ags) {
//		list<vehicle> vss <- list<vehicle>(ags);
//		list<agent_to_send> to_remove ;
//		ask vss {
//			if not(self in to_remove) {
//				to_remove <- to_remove + ((vss)  where overlapping_lane(each));
//			}  
//		}
//		return ags - to_remove;	
//	}
	// ######################################################################
	
	} 

experiment Runme autorun: true  {
	float maximum_cycle_duration <- 0.15;
	output {
		//monitor "nb cars" value: length(car);
		//monitor "nb motorbikes" value: length(motorbike);
		display Computer virtual: false type: 3d toolbar: true background: #black axes: false {
			
		
			species road {
				draw self.shape + 4 color: closed ? color_closed : color_road;
			}

			agents "Vehicles" value: (agents of_generic_species(vehicle)) where (each.current_road != nil) {
				draw rectangle(vehicle_length * 5, lane_width * num_lanes_occupied * 5) at: shift_pt color: type = CAR ? color_car : color_moto rotate: self.heading;
			}

			species building {
				draw self.shape color: type = OUT ? color_outer_building : (color_inner_building) border:#black;
			}

			mesh cell triangulation: true transparency: 0.4 smooth: 3 above: 5 color: pal position: {0, 0, 0.01} visible: true;
			
			
		}

	}

}

