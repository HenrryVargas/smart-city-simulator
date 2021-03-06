%Class that represents a simple Sensor
-module(class_Route).

% Determines what are the mother classes of this class (if any):
-define( wooper_superclasses, [ class_Actor ] ).

% parameters taken by the constructor ('construct').
-define( wooper_construct_parameters, ActorSettings, RouteName, Route).

% Declaring all variations of WOOPER-defined standard life-cycle operations:
% (template pasted, just two replacements performed to update arities)
-define( wooper_construct_export, new/3, new_link/3,
		 synchronous_new/3, synchronous_new_link/3,
		 synchronous_timed_new/3, synchronous_timed_new_link/3,
		 remote_new/4, remote_new_link/4, remote_synchronous_new/4,
		 remote_synchronous_new_link/4, remote_synchronisable_new_link/4,
		 remote_synchronous_timed_new/4, remote_synchronous_timed_new_link/4,
		 construct/4, destruct/1 ).

% Method declarations.
-define( wooper_method_export, actSpontaneous/1, onFirstDiasca/2, getPosition/3).


% Allows to define WOOPER base variables and methods for that class:
-include("smart_city_test_types.hrl").

% Allows to define WOOPER base variables and methods for that class:
-include("wooper.hrl").


% Must be included before class_TraceEmitter header:
-define(TraceEmitterCategorization,"Smart-City.Sensor").


% Allows to use macros for trace sending:
-include("class_TraceEmitter.hrl").


% Creates a new soda vending machine.
%
-spec construct( wooper:state(), class_Actor:actor_settings(),
				class_Actor:name(), route()) -> wooper:state().
construct( State, ?wooper_construct_parameters ) ->

	ActorState = class_Actor:construct( State, ActorSettings, RouteName ),

	%?send_info_fmt( ActorState,
	%	"Creating a new sensor, position [~B,~B], "
	%	"and it initial value is ~B.",
	%	[ SensorLat, SensorLong, InitialValue ] ),

	% Depending on the choice of the result manager, it will be either a PID (if
	% the corresponding result is wanted) or a 'non_wanted_probe' atom:

	setAttributes( ActorState, [
		{ route, Route },
		{ index, 1 }, 
		{ current_value, 0 },
		{ probe_pid, non_wanted_probe },
		{ trace_categorization,
		 text_utils:string_to_binary( ?TraceEmitterCategorization ) }
							] ).

% Overridden destructor.
%
-spec destruct( wooper:state() ) -> wooper:state().
destruct( State ) ->

	% Class-specific actions:
	%?info_fmt( "Deleting sensor, position [~B,~B], "
	%	, [ ?getAttr(sensor_lat), ?getAttr(sensor_long) ] ),

	% Then allow chaining:
	State.

% The core of the customer behaviour.
%
% (oneway)
%
-spec actSpontaneous( wooper:state() ) -> oneway_return().
actSpontaneous( State ) ->

	% Manages automatically the fact that the creation of this probe may have
	% been rejected by the result manager:

	% Manages automatically the fact that the creation of this probe may have
	% been rejected by the result manager:
%	class_Probe:send_data( ?getAttr(probe_pid), class_Actor:get_current_tick( State ), ?getAttr(index)  ),
%
	?wooper_return_state_only( State ).

% Simply schedules this just created actor at the next tick (diasca 0).
%V
% (actor oneway)
%
-spec onFirstDiasca( wooper:state(), pid() ) -> oneway_return().
onFirstDiasca( State, _SendingActorPid ) ->

	SimulationInitialTick = ?getAttr(initial_tick),

	% Checking:
	true = ( SimulationInitialTick =/= undefined ),

	case ?getAttr(probe_pid) of

		non_wanted_probe ->
			ok;

		ProbePid ->
			ProbePid ! { setTickOffset, SimulationInitialTick }

	end,

	ScheduledState = executeOneway( State, scheduleNextSpontaneousTick ),

	?wooper_return_state_only( ScheduledState ).


% Called by a customer wanting to purchase a can.
%
% (actor oneway)
%
-spec getPosition( wooper:state(), car_index(), pid() ) ->
					   class_Actor:actor_oneway_return().
getPosition( State, Index, CarPID ) ->

	% To test simulation stalls due to actors (here, thirsty customers) blocking
	% the simulation not because they are busy, but because they are blocked by
	% others (this machine):


	Route = getAttribute(State, route),

	if 
		Index < length( Route ) ->

			CurrentValue = list_utils:get_element_at( Route, Index ),

			case tuple_size( CurrentValue ) == 2 of

				true ->

					class_Actor:send_actor_message( CarPID,
						{ go, CurrentValue }, State ) ;

				false ->
					
					class_Actor:send_actor_message( CarPID,
						{ wait_semaphore, CurrentValue }, State )		

			end;
			
		true -> State
	end.



