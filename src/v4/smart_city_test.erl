% Author: Eduardo Santana (efzambom@ime.usp.br)

-module(smart_city_test).



% For all facilities common to all tests:
-include("test_constructs.hrl").


create_log( _Number = 0, _List ) ->
	_List ;

create_log( Number , List  ) ->

	LogName = io_lib:format( "Log~B", [ Number ] ),

	LogPID = class_Actor:create_initial_actor( class_Log,
		 [ LogName ] ),

	create_log( Number - 1 , List ++ [ LogPID ] ).

% for each vertex is necessary to save its out links
create_map_list([] , _Graph , List) ->
	List;

create_map_list([Element | MoreElements] , Graph , List) ->
	
	{_E, _V1, _V2, _Label} = digraph:edge( Graph , Element ),

	Id = element( 1 , _Label),
	Length = element( 1 , string:to_float(element( 2 , _Label))), % Link Length	
	Capacity = element( 1 , string:to_float(element( 3 , _Label))),
	Freespeed = element( 1 , string:to_float(element( 4 , _Label))), 	

	
	
	Vertices = list_to_atom(lists:concat( [ _V1 , _V2 ] )),

	NewElement = [{ Vertices , { list_to_atom( Id ) , Length , Capacity , Freespeed , 0 } }],  % The last 0 is the number of cars in the link

	create_map_list( MoreElements , Graph , List ++ NewElement ).


% Create the actors that represent the city vertex

create_street_list( Graph ) ->
	
	Vertices = digraph:vertices( Graph ),

	create_street_list( Vertices , [] , Graph ).

create_street_list([] , List , _Graph ) ->
	List;

create_street_list([Element | MoreElements] , List , Graph) ->

	Edges = digraph:out_edges( Graph , Element ),

	ListEdges = create_map_list( Edges , Graph , [] ),

	StreetPID = class_Actor:create_initial_actor( class_Street,
		  [ atom_to_list(Element) , ListEdges ] ),

	NewElement = [{ Element , StreetPID }], 

	create_street_list( MoreElements , List ++ NewElement , Graph ).


spaw_proccess([] , _ListVertex , _CityGraph , _LogList ) -> 

	ok;

spaw_proccess( [ List | MoreLists ] , ListVertex , CityGraph , LogList ) ->

	Name = element( 1 , List ),
	ListTrips = element( 2 , List ),

	spawn(create_cars, iterate_list , [ 1 , dict:from_list( ListVertex ) , ListTrips , CityGraph , LogList , Name , self() ]),
	spaw_proccess( MoreLists  , ListVertex , CityGraph , LogList ).
  

collectResults([]) -> ok;
collectResults(Trains) ->
  receive
    { Name } ->
      collectResults(Trains -- [Name]);
    _ ->
      collectResults(Trains)
  end.


% Runs the test.
%
-spec run() -> no_return().
run() ->	


	?test_start,

	% Use default simulation settings (50Hz, batch reproducible):
	SimulationSettings = #simulation_settings{

	  simulation_name = "Sim-Diasca Smart City Integration Test",

	  % Using 100Hz here:
	  tick_duration = 1

	  % We leave it to the default specification (all_outputs):
	  % result_specification =
	  %  [ { targeted_patterns, [ {".*",[data_and_plot]} ] },
	  %    { blacklisted_patterns, ["^Second" ] } ]

	  %result_specification = [ { targeted_patterns, [ {".*",data_only} ] } ]

	},


	DeploymentSettings = #deployment_settings{

		computing_hosts = { use_host_file_otherwise_local,
							"sim-diasca-host-candidates.txt" },

		%node_availability_tolerance = fail_on_unavailable_node,

		% We want to embed additionally this test and its specific
		% prerequisites, defined in the Mock Simulators:
		%
		additional_elements_to_deploy = [ { ".", code } ],

		% Note that the configuration file below has not to be declared above as
		% well:
		enable_data_exchanger = { true, [ "soda_parameters.cfg" ] },

		enable_performance_tracker = false

	},




	% Default load balancing settings (round-robin placement heuristic):
	LoadBalancingSettings = #load_balancing_settings{},

	% A deployment manager is created directly on the user node:
	DeploymentManagerPid = sim_diasca:init( SimulationSettings,
							   DeploymentSettings, LoadBalancingSettings ),

	Config = config_parser:show("/home/eduardo/entrada/hospital/config.xml"),

	ListCars = matrix_parser:show( element( 4 , Config ) ), % Read the cars from the trips.xml file

	CityGraph = matsim_to_digraph:show( element( 3 , Config ) , false ), % Read the map from the map.xml file

	
 

	% create the vertices actors
	ListVertex  = create_street_list( CityGraph ),

	LogList = create_log( 1 , [] ), % creelement( 4 , Config )ate the actor that saves the log file


	Names = [ "car1" , "car2" , "car3" , "car4" , "car5" , "car6" ],

	{List1, ListCars1 } = lists:split(round (length (ListCars) / 6), ListCars),

	{List2, ListCars2 } = lists:split(round (length (ListCars) / 6), ListCars1),

	{List3, ListCars3 } = lists:split(round (length (ListCars) / 6), ListCars2),

	{List4, ListCars4 } = lists:split(round (length (ListCars) / 6), ListCars3),

	{List5, List6 } = lists:split(round (length (ListCars) / 6), ListCars4),

	List = [ { "car1" , List1 } , { "car2" , List2 } , { "car3" , List3 } , { "car4" , List4 } , { "car5" , List5 } , { "car6" , List6 } ],    

	spaw_proccess( List , ListVertex , CityGraph , LogList  ),
  		
	ok = collectResults(Names),


	% create the cars
	% create the actors that represent the cars - Need to paralelize this function

	% We want this test to end once a specified virtual duration elapsed, in
	% seconds:
	SimulationDuration = element( 1 , string:to_integer(element( 2 , Config ) ) ),

	DeploymentManagerPid ! { getRootTimeManager, [], self() },
	RootTimeManagerPid = test_receive(),

	?test_info_fmt( "Starting simulation, for a stop after a duration "
					"in virtual time of ~Bms.", [ SimulationDuration ] ),

	RootTimeManagerPid ! { startFor, [ SimulationDuration, self() ] },

	?test_info( "Waiting for the simulation to end, "
				"since having been declared as a simulation listener." ),

	receive

		simulation_stopped ->

        		?test_info( "Simulation stopped spontaneously, "
						"specified stop tick must have been reached." )

	end,

	?test_info( "Browsing the report results, if in batch mode." ),
	class_ResultManager:browse_reports(),

	sim_diasca:shutdown(),

	?test_stop.
