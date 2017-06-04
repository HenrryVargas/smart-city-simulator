-module(create_cars).



% usage:
%
% l(osm_parser).
% osm_parser:show("map.osm").

-export([
         iterate_list/8
        ]).


% Init the XML processing

iterate_list( _ListCount, _ListVertex , [] , _Graph , _LogPID , Name , _MetroActor , Sup ) ->
	Sup ! { Name };

iterate_list( ListCount, ListVertex , [ Car | MoreCars] , Graph , LogPID , Name , MetroActor , Sup ) ->

	Count = element ( 3 , Car ),

	case size( Car ) == 7 of

		true ->
			create_person( ListCount , element (1 , string:to_integer(Count)) , ListVertex , Car , Graph , false , LogPID , Name );

		false ->			
			create_person_multi_trip( ListCount , element (1 , string:to_integer(Count)) , ListVertex , Car , Graph , LogPID , MetroActor ,  Name )

	end,
			

	iterate_list( ListCount + 1, ListVertex , MoreCars , Graph , LogPID , Name , MetroActor , Sup ).



create_person( _ListCount , _CarCount = 0 , _ListVertex ,  _Car , _Graph , _Path , _LogPID , _Name ) ->
	
	ok;


create_person( ListCount , CarCount , ListVertex ,  Car , Graph , Path , LogPID , Name ) ->

	CarName = io_lib:format( "~B~B~s",
		[ ListCount , CarCount, Name ] ),

	Origin = element ( 1 , Car ),
	Destination = element ( 2 , Car ),
	StartTime = element ( 4 , Car ),
	LinkOrigin = element ( 5 , Car ),
	Type = element ( 6 , Car ),
	Mode = element ( 7 , Car ),

	case Path of

		false ->

			NewPath = digraph:get_short_path( Graph , list_to_atom(Origin) , list_to_atom(Destination) ),

			ListVertexPath = get_path_nodes( NewPath , ListVertex , [] ),

			class_Actor:create_initial_actor( class_Person,
		  		[ CarName , ListVertexPath , Origin , NewPath , element( 1 , string:to_integer( StartTime )) , LinkOrigin , LogPID , Type , Mode ] ),

			create_person( ListCount , CarCount - 1 , ListVertex ,  Car , Graph , NewPath , LogPID , Name  );

		_ ->

			ListVertexPath = get_path_nodes( Path , ListVertex , [] ),

			class_Actor:create_initial_actor( class_Person,
		  		[ CarName , ListVertexPath , Origin , Path , element( 1 , string:to_integer( StartTime )) , LinkOrigin , LogPID , Type , Mode ] ),

			create_person( ListCount , CarCount - 1 , ListVertex ,  Car , Graph , Path , LogPID , Name  )

	end.

create_person_multi_trip( _ListCount , _CarCount = 0 , _ListVertex ,  _Car , _Graph , _LogPID , _MetroActor , _Name ) ->
	
	ok;

create_person_multi_trip( ListCount , CarCount , ListVertex ,  Car , Graph , LogPID  , MetroActor , Name ) ->

	CarName = io_lib:format( "~B~B~s",
		[ ListCount , CarCount, Name ] ),

	StartTime = element ( 1 , Car ),
	Type = element ( 2 , Car ),

	ListTrips = element ( 4 , Car ),
	
	{ ListTripsFinal , ListVertexPath } = create_single_trip( ListTrips , [] , Graph , [] , ListVertex ),

	class_Actor:create_initial_actor( class_PersonMultiTrip,
		[ CarName , ListVertexPath , ListTripsFinal , element( 1 , string:to_integer( StartTime )) , LogPID , Type , MetroActor ] ).

create_single_trip( [] , ListTripsFinal , _Graph , ListVertexPath , _ListVertex ) ->

	{ ListTripsFinal , ListVertexPath };

create_single_trip( [ Trip |  ListTrips ] , ListTripsFinal , Graph , ListVertexPath , ListVertex ) ->

	Origin = element ( 1 , Trip ),
	Destination = element ( 2 , Trip ),
	LinkOrigin = element ( 3 , Trip ),
	Mode = element ( 4 , Trip ),

	case Mode of

		"walk" ->

			Path = digraph:get_short_path( Graph , list_to_atom(Origin) , list_to_atom(Destination) ),

			NewListVertexPath = ListVertexPath ++ get_path_nodes( Path , ListVertex , [] ),

			TripCreated = [ { Mode , Origin , LinkOrigin , Destination , Path , Mode } ],
			
			create_single_trip( ListTrips , ListTripsFinal ++  TripCreated , Graph , NewListVertexPath , ListVertex );
	

		"car" ->

			Path = digraph:get_short_path( Graph , list_to_atom(Origin) , list_to_atom(Destination) ),

			TripCreated = [ { Mode , Origin , LinkOrigin , Destination , Path } ],

			NewListVertexPath = ListVertexPath ++ get_path_nodes( Path , ListVertex , [] ),
			
			create_single_trip( ListTrips ,  ListTripsFinal ++  TripCreated , Graph , NewListVertexPath , ListVertex );
	

		"metro" ->

			TripCreated = [ { Mode , Origin , Destination } ],
			
			create_single_trip( ListTrips , ListTripsFinal ++  TripCreated , Graph , ListVertexPath , ListVertex )
	

	end.



get_path_nodes( [] , _ListVertex , List ) ->
	
	List;

get_path_nodes( [ Node | MoreNodes] , ListVertex , List ) ->

	Element = dict:find( Node , ListVertex ),

	ElementList = [{ Node , element( 2 , Element) }],

	get_path_nodes( MoreNodes , ListVertex , List ++ ElementList ).	
