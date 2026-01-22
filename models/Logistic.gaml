model EVDeliveryDigitalTwin

global {
// --- SCENARIO PARAMETERS [cite: 88-100] ---
	int scenario_type <- 0;
	//	file my_csv_file <- csv_file("nodes.csv");
	// --- TIME & SPACE ---
	// Step = 10 seconds. This creates the "Smooth Animation" and "Continuous Physics"
	float step <- 10 #sec;
	geometry shape <- square(100 #m);
	graph road_network;

	// --- PHYSICS CONSTANTS ---
	float traffic_multiplier <- 1.0;
	float base_speed <- 0.6 #km / #h;

	// Energy: 0.2 kWh per km (Real-world average for delivery vans)
	float energy_per_meter <- 0.02;

	// --- DEMAND SETTINGS ---
	int initial_customers <- 48;
	int size <- 0;
	// Probability scaled to 10s steps (approx 1 order every few minutes)
	float new_order_probability <- 0.00;
	int num_stations <- 3;

	init {
	// 1. GENERATE ROADS (Connected Graph)
	// Tạo agent từ file
	//		create road_node from: my_csv_file with: [
	//		// Đọc cột "X_Coord" và "Y_Coord" để tạo vị trí (location)
	//		// Lưu ý: location là biến có sẵn của agent
	//		location::{float(read("x")), float(read("y"))},
	//		// Đọc các thuộc tính khác nếu có
	//		my_name::read("id")];
	//		create road_node number: 50 {
	//		}

	//		list<point> node_locations <- road_node collect each.location;
	//		list<geometry> triangles <- triangulate(node_locations);
	//		
	//		loop tri over: triangles {
	//			list<point> pts <- tri.points;
	//			loop i from: 0 to: length(pts) - 2 {
	//				create road {
	//					visited <- false;
	//					shape <- line([pts[i], pts[i + 1]]);
	//					// Baseline travel time [cite: 8]
	//					t_ij <- shape.perimeter / base_speed;
	//				}
	//
	//			}
	//
	//		}
		road_network <- generate_random_graph(10, 40, false, road_node, road);
		int n_customers <- min([initial_customers, length(road_node)]);
		road_network <- as_edge_graph(road);

		// 2. INFRASTRUCTURE [cite: 57-60]
		create depot number: 1 {
			location <- one_of(road_node).location;
		}

		create charging_station number: num_stations {
			location <- one_of(road_node).location;
			max_power <- 50.0; // 50 kW charging speed
			num_plugs <- 2;
		}

		// 3. INITIAL CUSTOMERS
		create customer number: n_customers {
			location <- road_node[self.index].location;
			demand <- rnd(10.0, 20.0);
			status <- "active";
			release_time <- 0.0;
		}

		// 4. EV AGENT [cite: 29-32]
		create ev_driver number: 1 {
			location <- first(depot).location;
			battery_capacity <- 100.0;
			current_battery <- 100.0;
			status <- "idle";
		}

	}

	// --- DYNAMIC ENVIRONMENT ---
	reflex generate_new_orders {
		if (flip(new_order_probability)) {
			create customer number: 10 {
				location <- one_of(road_node).location;
				demand <- rnd(10.0, 20.0);
				status <- "active";
				release_time <- time; // [cite: 12]
			}

		}

	}

	//	reflex cleanup_completed_orders {
	//		ask customer where (each.status = "served") {
	//			do die;
	//		}
	//
	//	}

	// S1: Peak Traffic Logic [cite: 14, 91]
	reflex update_traffic {
		if (scenario_type = 1 and (time > 60 #mn and time < 120 #mn)) {
			traffic_multiplier <- 2.0; // Traffic doubles energy cost & halves speed
		} else {
			traffic_multiplier <- 1.0;
		}

	}

}

// --- AGENTS ---
species road_node {
	string my_name;
	//
	//	reflex print {
	//		write my_name;
	//	}
	aspect default {
		draw circle(1 + size #m) color: #gray;
		//		draw my_name color: #black size: 10 at: location + {0, 0, 2};
	}

}

species road {
	float t_ij;
	bool visited;
	rgb color <- #lightgray;

	aspect default {
		draw shape color: color width: 3;
	}

}

species depot parent: road_node {

	aspect default {
		draw square(1 + size #m) color: #orange border: #black;
	}

}

species charging_station parent: road_node {
	int num_plugs;
	float max_power;
	list<ev_driver> charging_evs;

	reflex serve_vehicles {
		loop ev over: copy(charging_evs) {
		// Charging Physics: Power * Time [cite: 45]
			float energy_added <- (max_power * step) / 3600;
			ev.current_battery <- min(ev.battery_capacity, ev.current_battery + energy_added);
			if (ev.current_battery >= ev.battery_capacity) {
				remove ev from: charging_evs;
				ev.status <- "idle";
				ev.location <- location;
			}

		}

	}

	aspect default {
		draw triangle(3 + size #m) color: #green;
	}

}

species customer parent: road_node {
	float demand;
	float service_duration;
	float release_time;
	string status;

	aspect default {
		if (status = "active") {
			draw circle(1 #m) color: #cyan border: #blue;
		}

		if (status = "served") {
			draw circle(1 #m) color: #red border: #black;
		}

	}

}

species ev_driver skills: [moving] {
	float battery_capacity;
	float current_battery;
	string status;
	point target_loc;
	agent target_agent;
	float safety_threshold <- 30.0;

	// --- REAL STATE MOVEMENT LOGIC ---
	reflex move when: target_loc != nil and status = "traveling" {
	// 1. Stranding Check [cite: 25]
		if (current_battery <= 0) {
			status <- "stranded";
			write "CRITICAL: Battery Dead.";
			return;
		}

		// 2. Capture Start Position
		point previous_loc <- location;

		// 3. Move Step (Animation)
		do goto target: target_loc on: road_network speed: base_speed / traffic_multiplier;
		//		road r <- road(current_edge);
		//		if (r != nil) {
		//			r.visited <- true;
		//		}
		if (current_edge != nil) {
			list<road> rr <- road where (each covers current_edge); 
			ask rr {
				color <- #red; // Đổi màu thành đỏ
			}
			// Ép kiểu current_edge về my_edge và đổi màu
		}
		// 4. Calculate REAL Distance Traveled
		float distance_traveled <- previous_loc distance_to location;

		// 5. Consume Energy Immediately (Real State) [cite: 77]
		if (distance_traveled > 0) {
		// Formula: Distance * BaseRate * TrafficMultiplier
			float energy_consumed <- distance_traveled * energy_per_meter * traffic_multiplier;
			current_battery <- current_battery - energy_consumed;
		}

		// 6. Arrival Check
		if (location distance_to target_loc < 0.05 #m) {
			location <- target_loc;
			if (target_agent is customer) {
				status <- "serving";
			} else if (target_agent is charging_station) {
				ask charging_station(target_agent) {
					add myself to: charging_evs;
				}

				status <- "charging";
			}

		}

	}

	reflex serve when: status = "serving" {
		if (target_agent != nil and not dead(target_agent)) {
			customer cust <- customer(target_agent);
			cust.status <- "served";
			target_agent <- nil;
			target_loc <- nil;
			status <- "idle";
		} else {
			target_agent <- nil;
			status <- "idle";
		}

	}

	// DECISION: Myopic Greedy [cite: 80]
	reflex choose_next_action when: status = "idle" {
		if (current_battery < safety_threshold) {
			target_agent <- charging_station closest_to self;
			if (target_agent != nil) {
				target_loc <- target_agent.location;
				status <- "traveling";
			}

		} else {
			list<customer> active_customers <- customer where (each.status = "active");
			if not empty(active_customers) {
				target_agent <- active_customers closest_to self;
				target_loc <- target_agent.location;
				status <- "traveling";
			}

		}

	}

	aspect default {
		rgb agent_color <- (status = "stranded") ? #black : ((current_battery < safety_threshold) ? #red : #purple);
		draw circle(1 #m) color: agent_color;
		// Live Battery Display
		draw string(int(current_battery)) + "%" color: #black size: 12 at: location + {0, -2};
		draw status color: #black size: 15 at: location + {0, 5};
		if (target_loc != nil) {
		//			write "draw "+location;
		//			write "draw "+target_loc;
			draw line([location, target_loc]) color: #purple width: 2;
		}

	}

}

experiment DigitalTwin_GUI type: gui {
	parameter "Scenario Type" var: scenario_type;
	//	parameter "New Order Probability" var: new_order_probability min: 0.00 max: 0.1;
	output {
		display map_view background: #black {
			species road;
			species road_node;
			species depot;
			species charging_station;
			species customer;
			species ev_driver;
		}

		//		display dashboard type: 2d {
		//			chart "EV Battery Level (Real-time)" type: series {
		//				data "Battery %" value: first(ev_driver).current_battery color: #red;
		//				data "Safety Limit" value: 30.0 color: #black style: line;
		//			}
		//
		//		}

	}

}
