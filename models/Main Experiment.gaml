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
	rgb color_road <- #gray;
	rgb color_closed <- #mediumpurple;
	rgb color_inner_building <- rgb(100, 100, 100);
	rgb color_outer_building <- rgb(60, 60, 60);
	rgb color_lake <- rgb(165, 199, 238, 255);
	map<string,list<road>> name_to_roads;
	// Load shapefiles
//	shape_file buildings_shape_file <- shape_file(resources_dir + "buildings.shp");

//	geometry shape <- envelope(buildings_shape_file);


	list<string> previous_closed_roads;
	
	string BANGKOK <- "Bangkok" const: true;
	string HANOI <- "Hanoi" const: true;

	string dataset <- "Hanoi" among: ["Hanoi", "Bangkok"];
	
	int cars <- dataset = BANGKOK ? 1000 : 500;
	int motos <- dataset = BANGKOK ?  500 : 700;
	
	bool use_traffic_light <- false;
	int min_lanes <- 1;
	float vehicle_size_coeff <- 3.0;
	
	int nb_level_haut ;
	int nb_level_moyen ;
	int nb_level_bas ;
	float aqi_mean ;
	
		// Initialization 
	string resources_dir <- "../data/" + dataset + "/";
	
	list<string> roads_to_keep <-  ["motorway", "motorway_link", "primary", "primary_link", "residential", "secondary", "secondary_link", "service", "tertiary", "tertiary_link", "unclassified"];

	shape_file intersections_shape_file <- file_exists(resources_dir + "intersections.shp") ? shape_file(resources_dir + "intersections.shp") : nil;

	shape_file roads_shape_file <- shape_file(resources_dir +"roads.shp");
	shape_file buildings_shape_file <- shape_file(resources_dir + "buildings.shp");
	shape_file background_shape_file <-  file_exists(resources_dir + "sub_area.shp") ?  shape_file(resources_dir + "sub_area.shp") : nil;
	bool use_sub_area <- false;
	//shape_file buildings_shape_file <- shape_file(resources_dir + "buildings.shp");
	geometry shape <- envelope((background_shape_file != nil and use_sub_area) ?  background_shape_file : buildings_shape_file);

	


	init {
		
		
		if (background_shape_file = nil) {
			use_sub_area <- false;
		}
		if (intersections_shape_file != nil and use_traffic_light)  {
			create intersection from: intersections_shape_file with:[is_traffic_signal::(string(read("highway")) = "traffic_signals"), is_crossing :: (string(read("crossing")) = "traffic_signals")] {
				if (is_crossing) {is_traffic_signal <- true;}
				if not (is_traffic_signal) { do die;}
			}
		}
		
		//create intersection from: 
		create road from: roads_shape_file with:[ name::string(read("name")),type::string(get("highway")),junction::string(read("junction")),num_lanes::int(read("lanes")), maxspeed::float(read("maxspeed")) #h/#km, oneway_string::string(read("oneway")), lanes_forward ::int (get( "lanesforwa")), lanes_backward :: int (get("lanesbackw"))] {
			if maxspeed <= 0 {maxspeed <- 50 #km/#h;}
			oneway <- oneway_string != nil and oneway_string = "yes";
			if (lanes_forward > 0) {
				num_lanes <- lanes_forward;
			} 
			if not (oneway) {
				create road with:(shape: line(reverse(shape.points)), num_lanes: lanes_backward > 0 ? lanes_backward : num_lanes, linked_road: self,
					name: name, type: type, s1_closed: s1_closed, s2_closed: s2_closed
					
				) {
					myself.linked_road <- self;
				}
			}
				
		}	
		map<string,list<road>> roads <- road group_by each.name;
		ask road   {
			if (num_lanes = 0) and not empty(roads[name]) {
				road r <-  roads[name] first_with (not dead(each) and (each.num_lanes > 0));
				if (r != nil) {
					num_lanes <- r.num_lanes;
				}
			}
			num_lanes <- max(num_lanes, min_lanes) *2;
			if type != nil and not(type in roads_to_keep) {
				do die;
			} 
			
			if (use_sub_area and !(self overlaps first(background_shape_file))) {
				do die;
			}
		}
		
		graph g <- as_edge_graph(road);
		g <-  main_connected_component(g);
		ask road {
			if not(self in g.edges) {
				do die;
			}
		}
		
		list<point> pts <- list<point>(g.vertices where empty(intersection overlapping each));
		loop pt over: pts {
			create intersection with: (location:pt);
		}
				
			
		ask road {
			if  name = nil or  name = "" {
				name <- "road_" + int(self);
			}
		}
		
	//create decoration_building from: shape_file(resources_dir + "admin.shp");
		create natural from: shape_file(resources_dir + "naturals.shp") {
			if (use_sub_area and !(self overlaps first(background_shape_file))) {
				do die;
			} 
		}
		//create natural from: shape_file(resources_dir + "naturals.shp");
		
			
		// ######################################################################
//		create building from: shape_file(buildings_shape_file) {
//			if (shape.area < 0.1) {
//				do die;
//			}
//		}
		
		 create building from: shape_file(buildings_shape_file) {
		 	if (use_sub_area and !(self overlaps first(background_shape_file))) {
				do die;
			}
		 }
		// ######################################################################
			
		ask road {
			
			agent ag <- building closest_to self;
			
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
		road_network <- as_driving_graph(open_roads, intersection);// with_shortest_path_algorithm #FloydWarshall;
		//geometry road_geometry <- union(open_roads accumulate (each.shape));
		ask agents of_generic_species vehicle {
			do select_target_path;
		} 
		
		do update_car_population(cars);
		do update_motorbike_population( motos);
		
	}
	
	list<map> message_buildings(list<building> buildings_input) {
			list<map> buildings;
			ask buildings_input {
				buildings <+ to_array();
			}
			return buildings;
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
		
		
		reflex cell_area when: every(10 #cycle) {
			nb_level_haut <- cell count (each >= 700);
			nb_level_moyen <- cell count (each >= 500 and each < 700);
			nb_level_bas <- cell count (each >= 200) - (nb_level_moyen + nb_level_haut);
			aqi_mean <- (nb_level_haut^3 + nb_level_moyen^1.5 + nb_level_bas^0.2) / grid_size;
		}
		
	} 

experiment RunmeComputer autorun: true  {
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


experiment RunmeTable autorun: true  {
	float maximum_cycle_duration <- 0.15;
	output {
		
		display Table virtual: false  fullscreen: 0 type: 3d  toolbar: false background: #black axes: false 
		keystone: [{-0.03014, -0.02732, 0.0}, {-0.02260, 1.01663, 0.0}, {1.0, 1.0, 0.0}, {1.015070, -0.01306, 0.0}] 
		{
			
			species natural refresh: false {
				draw self.shape color: color_lake;
			}

			species road {
				draw self.shape + (num_lanes) color: closed ? color_closed : color_road;
			}
			species intersection;
			
			//camera 'default' location: {1009.9128, 1455.358, 3976.353} target: {1009.9128, 1455.2886, 0.0} locked: false;
			agents "Vehicles" value: (agents of_generic_species(vehicle)) where (each.current_road != nil) {
			
					draw rectangle(vehicle_length * vehicle_size_coeff , lane_width * num_lanes_occupied * vehicle_size_coeff ) depth: 1.0 at: shift_pt color: type = CAR ? color_car : color_moto rotate: self.heading;
		//	draw rectangle(vehicle_length * 5, lane_width * num_lanes_occupied * 5) at: shift_pt color: type = CAR ? color_car : color_moto rotate: self.heading;
			}

			species building {
				draw self.shape depth: 10 color: type = OUT ? color_outer_building : pal[pollution_index_scale] ;
			}
		

		}


	}

}



