
model doanII

global {
//Shapefile of the buildings
	file building_shapefile <- file("../includes/buildings.shp");
	//Shapefile of the roads
	file road_shapefile <- file("../includes/roads.shp");
	file benxe_shapefile <- file("../includes/benxe.shp");
	file data_bus <- csv_file("../includes/BusData.csv");
	//Shape of the environment
	geometry shape <- envelope(building_shapefile) + envelope(road_shapefile);
	//Step value
	float step <- 60 #s;
	// Tạo xe theo thời điểm trong ngày
	reflex crt_car when: cycle mod 60 = 0 {
		int nb_car_by_hour <- round(nb_car * cars_pct_by_hour[current_hour_of_day]);
		create car number: nb_car_by_hour {
		//People agents are located anywhere in one of the building 
			location <- any_location_in(one_of(building));
			state <- flip(0.75) ? "ok" : "notok";
		}	
		
	}
	// Hệ số xe theo giờ
	reflex logging {
	}
	int current_hour_of_day <- 0;
	map<int, float> cars_pct_by_hour <- [
		0::0.1,
		1::0.1,
		2::0.1,
		3::0.1,
		4::0.2,
		5::0.4,
		6::0.6,
		7::0.8,
		8::1.0,
		9::0.8,
		10::0.7,
		11::0.7,
		12::0.5,
		13::0.4,
		14::0.5,
		15::0.5,
		16::0.5,
		17::0.06,
		18::0.7,
		19::0.9,
		20::0.6,
		21::0.4,
		22::0.3,
		23::0.2
	];
	
//	reflex save{
//		save [time,nb_car] to: "save_data2.csv" format: "csv";
//	}
	reflex update_hour {
		int seconds_of_day <- int(time) mod (3600 * 24);
		current_hour_of_day <- seconds_of_day div 3600;
		
		write "Time: " + seconds_of_day + " Hour: " + current_hour_of_day + " nb cars: " + length(car);
	}
//	reflex update_sec{
//		int seconds_of_day <- int(time) mod (3600 * 24);
//		current_hour_of_day <- seconds_of_day div 3600;
//	    int nb_cab_by_sec <-round(N_min + (N_max - N_min)/2 * (1 + sin(2 * 3.14 * seconds_of_day / 86400 - 3.14/2)));
//        write "Time: " + seconds_of_day + " Hour: " + current_hour_of_day + " nb cars: " + length(people);
//	}
//	
	
	
	field cell <- field(300,300);
	//Graph of the road network
	graph road_network;
	//Map containing all the weights for the road network graph
	map<road, float> road_weights;
	matrix data <- matrix(data_bus);
	list<list<int>> data_columns <- columns_list(data);
	
	list<int> nb_bus_arr <- data_columns[1];
	list<int> route_arr <- data_columns[0];
	int N_min<-10;
	int N_max <- 1000;
    int nb_bus<- data[1,0];
    int nb_bus_02<- data [1,1];
    int nb_bus_03<- data [1,2];
    int nb_bus_04<- data [1,3];
    int nb_bus_05<- data [1,4];
    int nb_vehicle<-1000;
    int nb_car<-nb_vehicle-nb_ev;
    float  emmission_sum;
//    reflex update_emmssion{
//    	  emmission_sum<- length(car)*7;  // nhân hệ số phát thải của xe
//    }
//    
    float percent_ev<-10;
    int nb_ev<-nb_vehicle*(percent_ev/100);
	init {
		
//		list<ev> all_evs = [];
		create ev number: nb_ev {
			location <- any_location_in(one_of(road));
		}
		
//		ev ag1 <- ev[1];
//		write ag1;
//		write ev at 1;
//		ev ag2 <- ev[2];
//		building bd1 <- building[1];
//		building bd2 <- building[2];
//		write ag1.location;
//		write ag2.location;
//		write distance_to (ag1,ag2);
//		write distance_to (ag1.location,ag2.location);
//		write path_to(bd1,bd2);
		
	//Initialization of the building using the shapefile of buildings
		create building from: building_shapefile;

		//Initialization of the road using the shapefile of roads
		create road from: road_shapefile; 
        create bus number: nb_bus {
        	is_ev<-flip(percent_ev);
        	location <- any_location_in(one_of(buspark));
        }
		//Creation of the people agents
		int nb_car_by_hour <- round(nb_car * cars_pct_by_hour[current_hour_of_day]);
		
		create car number: nb_car_by_hour {
		//Car agents are located anywhere in one of the building 
			location <- any_location_in(one_of(building));
			state <- flip(0.75) ? "ok" : "notok";
		}
//		loop i from: 1 to: 1 {
//			int nb_bus <- nb_bus_arr[i];
//			int route_index <- route_arr[i];
//			
//			buspark <- f(route_index, "benxe.shp");
//		}
		create buspark from: benxe_shapefile;
		//Weights of the road
		road_weights <- road as_map (each::each.shape.perimeter);
		road_network <- as_edge_graph(road);
	}
	
	
//	reflex update_number_car {
//		
//		loop t from: 1 to: 24 {
//			if (t < 6) { 
//    			nb_car <- nb_car * 0.1;     // 0h - 6h
//			} else if (t < 9) { 
//    			nb_car <- nb_car * 0.9;     // 6h - 9h (cao điểm sáng)
//			} else if (t < 12) { 
//   				nb_car <- nb_car * 0.6;     // 9h - 12h
//			} else if (t < 16) { 
//    			nb_car <- nb_car * 0.7;     // 12h - 16h
//			} else if (t < 18) { 
//   				nb_car <- nb_car * 1.0;     // 16h - 18h (cao điểm chiều)
//			} else if (t < 22) { 
//   				nb_car <- nb_car * 0.5;     // 18h - 22h
//			} else { 
//   				nb_car <- nb_car * 0.2;     // 22h - 24h
//			}
//       }
//       
//       }
	//Reflex to update the speed of the roads according to the weights
	
	reflex update_road_speed {
		road_weights <- road as_map (each::each.shape.perimeter / each.speed_coeff);
		road_network <- road_network with_weights road_weights;
	}

	//Reflex to decrease and diffuse the pollution of the environment
	reflex pollution_evolution {
		//ask all cells to decrease their level of pollution
		cell <- cell * 0.8;
	
		//diffuse the pollutions to neighbor cells
		diffuse var: pollution on: cell proportion: 0.9;
	}
}

species ev skills: [moving] {
//Target point of the agent
	point target;
	//Probability of leaving the building
	float leaving_proba <- 0.05;
	//Speed of the agent
	float speed <- rnd(30) #km / #h + 1;
	// Random state
	string state;
	float phatthai_ev<-0;
    point previous_location;// vị trí trước đó
    float total_distance<-0;
    point now_location;
	//Reflex to leave the building to another building
	reflex leave when: (target = nil) and (flip(leaving_proba)) {
		total_distance<-0;
		target <- any_location_in(one_of(building));
	}
	//Reflex to move to the target building moving on the road network
	reflex move when: target != nil {
	//we use the return_path facet to return the path followed
		path path_followed <- goto(target: target, on: road_network, recompute_path: false, return_path: true, move_weights: road_weights);
        //
   		previous_location<-path_followed.vertices[1];
    	total_distance<- total_distance + distance_to(previous_location,location);
		//if the path followed is not nil (i.e. the agent moved this step), we use it to increase the pollution level of overlapping cell
//		write path_followed;
//		write length(path_followed);
//		point p1<-path_followed.vertices[1];
//		point p2<-path_followed.vertices[2];
//		write distance_to(p1,p2);
//		write "---------------";
       
	  
//        previous_location<-path_followed.vertices[i];
//		total_distance<- total_distance + distance_to(previous_distance,location);
        
	    
		if (location = target) {
			target <- nil;
		} 
	
//	
    write"----------------------";
	write"previous_ distance:"+ previous_location;
	write"total:"+ total_distance;
	write "distance"+ distance_to(previous_location,location);
	write"----------------------";
		
	}

	aspect default {
		draw rectangle(4,10) rotated_by (heading+90) color:( #green ) depth: 3;
		draw rectangle(4, 6) rotated_by (heading+90) color:( #lightgreen) depth:4;
	} }
species buspark {
	aspect default {
		draw (shape+5) color: #yellow depth: 3;
	}
}

species bus parent: car {
	bool is_ev;
	
	float emmission {
		float e <- speed * rnd(1,2);
		return e * (1 - int(is_ev));
	}
	
	reflex choose_target when: target=nil {
		target<- any_location_in(one_of(buspark));
	}
	
	reflex choose_another_target when: target=any_location_in(one_of(buspark)){
		target<- any_location_in(one_of(buspark));
	}
	reflex move when: target != nil {
	//we use the return_path facet to return the path followed
		path path_followed <- goto(target: target, on: road_network, recompute_path: false, return_path: true, move_weights: road_weights);

		//if the path followed is not nil (i.e. the agent moved this step), we use it to increase the pollution level of overlapping cell
		if (path_followed != nil and path_followed.shape != nil) {
			cell[path_followed.shape.location] <- cell[path_followed.shape.location] + 15;					
		}

		}
	
	aspect default {
		draw rectangle(4,10) rotated_by (heading+90) color:( #red) depth: 3;
		draw rectangle(4, 6) rotated_by (heading+90) color:( #red) depth: 4;
	} 
}

//Species to represent the people using the skill moving
species car skills: [moving] {
//Target point of the agent
	point target;
	//Probability of leaving the building
	float leaving_proba <- 0.05;
	//Speed of the agent
	float speed <- rnd(30,40) #km / #h ;
	// Random state
	string state;
//	 point start <-any_location_in(one_of(building));
//	float distance_had_drive <-  start distance_to target;
//	float congsuat <-10;
//	float luong_khi_thai<- congsuat*distance_had_drive;
//	float phatthai_ev<-0;
//    reflex printed {
//    	save [name,distance_had_drive, speed, congsuat, luong_khi_thai] to: "Data_checl.csv" format:"csv";
//   }
	//Reflex to leave the building to another building
	reflex leave when: (target = nil) and (flip(leaving_proba)) {
		target <- any_location_in(one_of(building));
	}
	//Reflex to move to the target building moving on the road network
	reflex move when: target != nil {
	//we use the return_path facet to return the path followed
		path path_followed <- goto(target: target, on: road_network, recompute_path: false, return_path: true, move_weights: road_weights);

		//if the path followed is not nil (i.e. the agent moved this step), we use it to increase the pollution level of overlapping cell
		if (path_followed != nil and path_followed.shape != nil) {
			cell[path_followed.shape.location] <- cell[path_followed.shape.location] + 10;					
		}

		if (location = target) {
			target <- nil;
			do die;
		} 
	}

	aspect default {
		draw rectangle(4,10) rotated_by (heading+90) color:( #dodgerblue) depth: 3;
		draw rectangle(4, 6) rotated_by (heading+90) color:( #dodgerblue) depth: 4;
	} }
	//Species to represent the buildings
species building {

	aspect default {
		draw shape color: darker(#darkgray).darker depth: rnd(10) + 2;
	}

}
//Species to represent the roads
species road {
//Capacity of the road considering its perimeter
	float capacity <- 1 + shape.perimeter / 30;
	//Number of people on the road
	int nb_people <- 0 update: length(car at_distance 1);
	//Speed coefficient computed using the number of people on the road and the capicity of the road
	float speed_coeff <- 1.0 update: exp(-nb_people / capacity) min: 0.1;
	int buffer <- 10;

	aspect default {
		draw (shape + 5) color: #white;
	}

}

experiment traffic type: gui autorun: true{
	float minimum_cycle_duration <- 0.01;
	list<rgb> pal <- palette([ #black, #green, #yellow, #orange, #orange, #red, #red, #red]);
	map<rgb,string> pollutions <- [#green::"Good",#yellow::"Average",#orange::"Bad",#red::"Hazardous"];
	map<rgb,string> legends <- [rgb(darker(#darkgray).darker)::"Buildings",rgb(#dodgerblue)::"Cars",rgb(#white)::"Roads"];
	font text <- font("Arial", 14, #bold);
	font title <- font("Arial", 18, #bold);
//	parameter "Number of Car" category: "Update vehicle" var: nb_car min: 0 max: 10000;
	parameter "Percent of EV " slider: true category: "Update EV" var: percent_ev min: 0 max: 100;
//	parameter "Bus on Route 2" slider: true category: "Update Bus" var: nb_bus_02 min: 0 max: 100;
//	parameter "Bus on Route 3" slider: true category: "Update Bus" var: nb_bus_03 min: 0 max: 100;
//	parameter "Bus on Route 4" slider: true category: "Update Bus" var: nb_bus_04 min: 0 max: 100;
//	reflex end_of_runs
//	{
//		save [MSE, first(bacteria).mu, first(bacteria).Kb*10^3, first(bacteria).m, first(bacteria).r, first(bacteria).pr, first(bacteria).gamma] format: "csv" rewrite: false to: output_file;
//	}
   
	output synchronized: true{
		
		display carte type: 3d axes: false background: rgb(50,50,50) fullscreen: false toolbar: false{
			
			 overlay position: { 50#px,50#px} size: { 1 #px, 1 #px } background: # black border: #black rounded: false 
            	{
            	//for each possible type, we draw a square with the corresponding color and we write the name of the type
                
                draw "Pollution" at: {0, 0} anchor: #top_left  color: #white font: title;
                float y <- 50#px;
                draw rectangle(40#px, 160#px) at: {20#px, y + 60#px} wireframe: true color: #white;
             
                loop p over: reverse(pollutions.pairs)
                {
                    draw square(40#px) at: { 20#px, y } color: rgb(p.key, 0.6) ;
                    draw p.value at: { 60#px, y} anchor: #left_center color: # white font: text;
                    y <- y + 40#px;
                }
                
                y <- y + 40#px;
                draw "Legend" at: {0, y} anchor: #top_left  color: #white font: title;
                y <- y + 50#px;
                draw rectangle(40#px, 120#px) at: {20#px, y + 40#px} wireframe: true color: #white;
                loop p over: legends.pairs
                {
                    draw square(40#px) at: { 20#px, y } color: rgb(p.key, 0.8) ;
                    draw p.value at: { 60#px, y} anchor: #left_center color: # white font: text;
                    y <- y + 40#px;
                }
            }
			
			
			light #ambient intensity: 128;
			camera 'default'; // location: {1254.041,2938.6921,1792.4286}  ;
			species road refresh: false;
			species building refresh: false;
			species car;
			species buspark;
			species bus;
			
			species ev;
			//display the pollution grid in 3D using triangulation.
			mesh cell scale: 9 triangulation: true transparency: 0.4 smooth: 3 above: 0.8 color: pal;
		}
////		display map {
////			chart "Number Bus" type: pie {
////				datalist ["Bus Routes 01","Bus Routes 02","Bus Routes 03","Bus Routes 04","Bus Routes 05"] value:  [nb_bus,nb_bus_02,nb_bus_03,nb_bus_04,nb_bus_05] color: [#red,#blue,#green,#orange,#yellow] ;
////   			 }
////		}
//    	display "my_display" {
//		chart "Number Vehicel" type: series {
//			data "CO2" value: emmission_sum color: #red;
//			data "Number Vehicle" value: length(people) color: #blue;
//	}
//}

	}
	

}
