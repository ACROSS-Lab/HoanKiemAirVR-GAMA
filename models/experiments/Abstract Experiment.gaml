 /***
* Name: Main
* Author: minhduc0711 & Alexis Drogoul
* Description: 
***/
model abstract_xp 

import "../UI.gaml"

import "../Traffic.gaml"

 
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
	rgb color_closed <- #red;
	rgb color_inner_building <- rgb(100, 100, 100);
	rgb color_outer_building <- rgb(60, 60, 60);
	rgb color_lake <- rgb(165, 199, 238, 255);

	// Initialization 
	string resources_dir <- "../data/";

	// Load shapefiles
	shape_file buildings_shape_file <- shape_file(resources_dir + "buildings.shp");
	geometry shape <- envelope(buildings_shape_file);

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
		
		create decoration_building from: shape_file(resources_dir + "admin.shp");
		create natural from: shape_file(resources_dir + "naturals.shp");
		
			
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

		
		// ######################################################################
		name_to_roads <- road group_by each.name;
		// Send roads geometries to Unity with a collider
		do add_background_data_with_names(road collect (each.shape buffer (each.num_lanes * lane_width)), road collect each.name, road collect "Road", 0.2, true);
		do add_background_data_with_names_3D((building where (each.type != "outArea" and each.shape.area > 0.1)) collect each.shape, (building where (each.type != "outArea" and each.shape.area > 0.1))  collect each.name, building collect "Building", building collect rnd(5.0,12.0), false);
		
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
		agents_to_send <- list(car) + list(motorbike);
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
		agents_to_send <- list(car) + list(motorbike);
		
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
	//filter the agents to send according to the player_agent_perception_radius - can be overrided 
	list<agent_to_send> filter_distance(list<agent_to_send> ags) {
		geometry geom <- (the_player.location buffer player_agent_perception_radius);
		list<vehicle> vs;
		loop r over: road overlapping geom {
			vs <- vs + list<vehicle>(r.all_agents where (vehicle(each).final_target != nil));  
		}
		return vs;
		
	}

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
	
	
	

experiment abstract_xp autorun: true parent: "Control" virtual: true{
	float maximum_cycle_duration <- 0.015;
	
	
	
	output {
	
	display Computer virtual: true type: 3d //fullscreen: 0
	
	 toolbar: true background: #black axes: false {
			event #mouse_down {
				if (simulation.select_button_on_device(DELL34)) {
					return;
				}

				move_player_event <- true;
			}  

			overlay position: {0 #px, 0 #px} size: {1 #px, 1 #px} rounded: false {
			//	draw rectangle(1000 #px, 4000 #px) color: #black at: {3500 #px, 0 #px};
				float x_start <- 1600 #px;
				draw "Hoan Kiem Air" color: rgb(102, 102, 102) font: title at: {x_start + 50 #px, 100 #px} anchor: #top_left;
				draw ird_logo at: {x_start + 225 #px, 200 #px} size: {350 #px, 82 #px};
				float width <- 40 #px;
				float y_start <- 450 #px;
				float x_shift <- 2 * width;
				float diameter <- 60 #px;
				float y <- y_start - diameter;
//				loop p over: legends.pairs {
//					draw square(40 #px) at: {x_start + x_shift, y} color: p.key;
//					draw p.value at: {x_start + x_shift + width, y} anchor: #left_center color: #white font: text;
//					y <- y + 40 #px;
//				}
//
//				y <- y + diameter * 2;
				y_start <- y;
				draw "Local Traffic Density" font: text color: #white anchor: #left_center at: {x_start + diameter, y - diameter};
				loop p over: reverse(traffic.pairs) {
					draw square(width) at: {x_start + x_shift, y} color: p.key;
					draw p.value at: {x_start + x_shift + width, y} anchor: #left_center color: #white font: text;
					y <- y + width;
				}
				//				
				//				rgb color_max <- pal[index_of_pollution_level_against_max(aqi_max)];
				//				rgb color_mean <- pal[index_of_pollution_level_against_mean(aqi_mean)];
				//				float height <- width * length(pollutions);
				//				float y_max <- (y_start + height - (height * (aqi_max / aqi_worst_max))) - width / 2;
				//				float y_mean <- (y_start + height - (height * (aqi_mean / aqi_worst_mean))) - width / 2;
				//				draw triangle(20 #px) rotated_by 90 at: {x_start + 50 #px, y_max} color: color_max;
				//				draw "MAX" font: small color: color_max anchor: #left_center at: {x_start + 10 #px, y_max};
				//				draw triangle(20 #px) rotated_by 90 at: {x_start + 50 #px, y_mean} color: color_mean;
				//				draw "AVG" font: small color: color_mean anchor: #left_center at: {x_start + 10 #px, y_mean};


				//				draw rectangle(1000 #px, 3000 #px) color: #black at: {0 #px, 0 #px};
				//				x_start <- 150 #px;
				//				y <- y_start;
				//				y <- y + diameter * 2 + diameter / 2;
				//				draw "Traffic Density" font: text color: #white anchor: #left_center at: {x_start + diameter * 2 - diameter / 2, y - diameter};
				//				draw show_traffic_selected ? show_on : show_off size: {diameter, diameter} at: {x_start + diameter * 2, y};
				//				draw show_traffic_selected ? "Hide" : "Show" font: text color: #grey anchor: #left_center at: {x_start + diameter * 3, y};

			}

			camera 'default' location: {1541.1984, 3450.3224, 1670.0932} target: {1711.2646, 1832.2508, 0.0};
			species decoration_building refresh: false {
				draw self.shape color: color_outer_building border: #darkgrey;
			}

			species natural refresh: false {
				draw self.shape color: color_lake;
			}

			species road {
				draw self.shape + 4 color: closed ? color_closed : color_road;
			}

			agents "Vehicles" value: (agents of_generic_species(vehicle)) where (each.current_road != nil) {
				draw rectangle(vehicle_length * 5, lane_width * num_lanes_occupied * 5) at: shift_pt color: type = CAR ? color_car : color_moto rotate: self.heading;
			}

			species building {
				draw self.shape color: type = OUT ? color_outer_building : (color_inner_building);
			}

			mesh cell triangulation: true transparency: 0.4 smooth: 3 above: 5 color: pal position: {0, 0, 0.01} visible: show_traffic_selected;
			
				species default_player position: {0,0,0.1}; 
		}

		display Table virtual: true parent: Controls  type: 3d  toolbar: false axes: false background: #black 
			{
			event #mouse_down {
				if (simulation.select_button_on_device(PROJECTOR)) {
					return;
				}

				move_player_event <- true;
			}

			camera 'default' location: {1009.9128, 1455.358, 3976.353} target: {1009.9128, 1455.2886, 0.0} locked: false;
			agents "Vehicles" value: (agents of_generic_species(vehicle)) where (each.current_road != nil) {
				draw rectangle(vehicle_length * 5, lane_width * num_lanes_occupied * 5) at: shift_pt color: type = CAR ? color_car : color_moto rotate: self.heading;
			}

			species building {
				draw self.shape color: type = OUT ? color_outer_building : (show_selected ? pal[pollution_index_scale] : color_inner_building);
			}
			species road {
				if closed {
					draw self.shape + 4 color: color_closed ;
				}
				
			}
			species default_player;

		}

	}

}
	
	


