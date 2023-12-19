model main_model_VR

import "/resource/HoanKiemAir/models/Main%20Experiment.gaml"

species unity_linker parent: abstract_unity_linker {
	int port <- 8000;
	string player_species <- string(unity_player);
	point location_init <- {50.0,50.0,0.0};
	int max_num_players  <- -1;
	int min_num_players  <- 1;
	bool use_physics_for_player <- false;
	
	
	
	init {
		do init_species_to_send([string(motorbike), string(car)]);		
		do add_background_data geoms: road collect  (each.shape buffer (each.num_lanes * lane_width)) names: road collect (each.name) tag:"Road" height: 0.2 collider: true is_3D: false;
		
		list<building> bds <- (building where (each.type != "outArea" and each.shape.area > 0.1));
		do add_background_data geoms: bds collect  (each.shape) names: bds collect (each.name) tag:"Building" height: 5.0 collider: false is_3D: true;
		
		//do add_background_data(road collect (each.shape buffer (each.num_lanes * lane_width)), road collect each.name, "Road", 0.2, true);
		//do add_background_data( collect each.shape, (building where (each.type != "outArea" and each.shape.area > 0.1))  collect each.name, "Building", 5.0, false);
	
	}
	
//	action add_to_send_world(map to_send) {
//		list message_bds <- [];
//		list<building> buildings <- (building where (each.type != "outArea"));
//		float total_closed_road <- 0.0;
//		
//		ask road where each.closed {
//			total_closed_road <- total_closed_road + shape.perimeter;
//		}
//		
//		message_bds <- world.message_buildings(buildings);
//		
//		to_send <+ "buildings"::message_bds;
//		to_send <+ "aqimean"::aqi_mean;
//		to_send <+ "aqistd"::aqi_std;
//		to_send <+ "roadClosedDist"::total_closed_road;
//		to_send <+ "pAreaHigh"::nb_level_haut;
//		to_send <+ "pAreaMid"::nb_level_moyen;
//		to_send <+ "pAreaLow"::nb_level_bas;
//	}
	
	action after_sending_world(map map_to_send) {
		list message_bds <- [];
		list<building> buildings <- (building where (each.type != "outArea"));
		float total_closed_road <- 0.0;
		
		ask road where each.closed {
			total_closed_road <- total_closed_road + shape.perimeter;
		}
		
		message_bds <- world.message_buildings(buildings);
		
		map_to_send <+ "buildings"::message_bds;
		map_to_send <+ "aqimean"::aqi_mean;
		map_to_send <+ "aqistd"::aqi_std;
		map_to_send <+ "roadClosedDist"::total_closed_road;
		map_to_send <+ "pAreaHigh"::nb_level_haut;
		map_to_send <+ "pAreaMid"::nb_level_moyen;
		map_to_send <+ "pAreaLow"::nb_level_bas;
	}
	
		//filter the agents to send according to the player_agent_perception_radius - can be overrided 
	/*list<agent> filter_distance(list<agent> ags) {
		geometry geom <- (the_player.location buffer player_agent_perception_radius);
		list<vehicle> vs;
		loop r over: road overlapping geom {
			vs <- vs + list<vehicle>(r.all_agents where (vehicle(each).final_target != nil));  
		}
		return vs;
		
	}*/
}

species unity_player parent: abstract_unity_player{
	float player_size <- 1.0;
	rgb color <- #red;
	float cone_distance <- 10.0 * player_size;
	float cone_amplitude <- 90.0;
	float player_rotation <- 90.0;
	bool to_display <- true;
	aspect default {
		if to_display {
			if selected {
				 draw circle(player_size) at: location + {0, 0, 4.9} color: rgb(#blue, 0.5);
			}
			draw circle(player_size/2.0) at: location + {0, 0, 5} color: color ;
			draw player_perception_cone() color: rgb(color, 0.5);
		}
	}
}



experiment vr_xp parent:RunmeTable autorun: false type: unity {
	float minimum_cycle_duration <- 0.05;
	string unity_linker_species <- string(unity_linker);
	list<string> displays_to_hide <- ["Computer"];
	
	action update_road_closed(string mes) {
		ask world {
			map answer <- map(mes);
			list<string> closedRoads <- answer["closedRoads"];
				
				if (closedRoads != nil and length(closedRoads) > 0) {
					closedRoads <- closedRoads sort_by each;
					if closedRoads != previous_closed_roads {
						previous_closed_roads <- closedRoads;
					
						ask road where (each.closed) {
							closed <- false;
						}
						loop rd over: closedRoads {
							ask name_to_roads[rd] {
								closed <- true;
							}
						}
						do update_road_closed;
					}
				}
		}
	}
	
	action create_player(string id) {
		ask unity_linker {
			do create_player(id);
		}
	}
	
	action init_player(string id) {
		ask unity_linker {
			do send_init_data(player_agents[id]); 
		}
	}
	
	action move_player_external(string id, int x, int y, int rotation) {
		ask unity_linker {
			do move_player_external(id, x, y, rotation);
		}
	}
		
	
	output {
		 display ComputerVR parent:Table {
			 species unity_player;
			 event #mouse_down{
				 ask unity_linker {
					 move_player_event <- true;
				 }
			 }
		 }
	}
}
