define [], () ->

    class WidgetStatesMixin
        ###
            This class contains all state-changing and loading-related
            code of the core widget functionality.

            #TODO(andrei): document the current state machine
        ###

        setupLoadingChannels: ->
            ###
                Setup an aggregate method to listen for events
                on loading_channels
            ###
            # Initialize a loadingStates list of length (loading_channels)
            # and create an aggregate method for loading channels
            if not @loadingStates?
                @loadingStates = []
                # For each loading channel set a state
                # equal to the specified initial @data_state of the widget
                for aggregated_channel of @loading_channels
                    @loadingStates.push(@data_state)
                # Setup an aggregate method to handle notifications
                # on the loading_channels only if this widget has
                # state management
                if @loadingStates.length > 0
                    channels = (@replaceTokensWithParams(channel) for channel in @loading_channels)
                    @aggregateChannels(@aggregateLoadingChannelsEvents, channels)


        aggregateLoadingChannelsEvents: (params...) ->
            ###
                Trigger a state change of a widget after processing
                events on loading channels.

                We support the following states (with the priority
                described by their order):
                  1. empty (collection has no data)
                  2. loading
                  3. available

                Toggle a state transition if the loadingStates have
                changed.
            ###
            previousStates = _.clone(@loadingStates)
            for event, i in params
                if event.type == 'no_data'
                    @loadingStates[i] = 'empty'
                if event.type == 'invalidate'
                    @loadingStates[i] = 'loading'
                if event.type in ['sync', 'change', 'reset', 'add', 'destroy']
                    # Check to see if the data on this specific channel is empty
                    if @isChannelDataEmpty(event, @loading_channels[i])
                        @loadingStates[i] = 'empty'
                    else
                        # Data has arrived on loading channels, the state should
                        # be available
                        @loadingStates[i] = 'available'
            @transitionState(@loadingStates, previousStates, params)

        transitionState: (currentStates, previousStates, params) ->
            ###
                Trigger a state transition only if there was
                a state change. Transition to the most important state
                of the loadingStates

                The order of states is important as we trigger the
                state based on their order (and return immediately):
                  1. empty
                  2. loading
                  3. available

                If any of the above states (the most important state)
                is present in the currentStates, transition to it
            ###
            for state in ['empty', 'loading', 'available']
                if state in currentStates
                    # If the state is empty employ a different transition
                    # strategy: all loading channels must be in an empty
                    # state to toggle empty. Do nothing if all channels
                    # are not empty.
                    if state is 'empty'
                        if @allStatesEmpty(currentStates)
                            newState = 'empty'
                            break
                    else
                        newState = state
                        break

            # Trigger a changeState() if there is a transition from an
            # old state to a new state
            if not _.isEqual(previousStates, currentStates)
                @changeState.apply(this, _.flatten([newState, params]))
            # Also trigger a changeState() when the new state is 'available',
            # regardless of the old state. This behavior can be disabled
            # through the STRICT_CHANGE_STATE flag
            else if not @STRICT_CHANGE_STATE and newState is 'available'
                @changeState.apply(this, _.flatten([newState, params]))

        allStatesEmpty: (states) ->
            ###
                The condition to transition in an empty
                state is for all states on the loading
                channels to be empty. Verify all values
                in the states list are empty.

                @param {Array} states: a list of the current states the
                                       widget is in. Ex: ['available', 'empty']
                @return {Boolean}: True if all values in the states
                                   list are empty
            ###
            for s in states
                if s != 'empty'
                    return false
            return true

        isChannelDataEmpty: (event, channel = null) ->
            ###
                This is the condition trigger for an empty loading state.
                Overwrite this in your widgets to let the state manager
                know when to toggle an empty state.
                By default it inspects the empty state for a collection
                type of event.
            ###
            return (event.collection? and event.collection.length == 0)

        changeState: (state, params...) ->
            ###
                Toggle data state.

                Possible states:
                  1. init - Used for rendering blank states at init
                  2. loading - Used for notifying the user that a request is in process
                  3. empty - Empty dataset
                  4. incompatible - Required data is conflicted with current filters
                  5. available - Available state, with proper data

                1 and 4 are to be triggered manually from subclasses, the other are
                triggered automatically, based on channel events.

                _available_ states with non-empty data should be ignored, because
                _get_items_ channel listeners handle those situations.

                Subclass extending and usage example:

                    initialize: ->
                        @changeState('init')

                    changeState: (state, params...) =>
                        # Always call super in order to have the internal
                        # data state up to date and the loading methods
                        # covered.
                        super(state, params...)
                        if state == 'available' && !@isChannelDataEmpty(params)
                            return
                        if state == 'init'
                            @renderLayout(@getStateTemplateVars())
                        # Other states could also be handled here...

                @see #isChannelDataEmpty
                @see #getStateTemplateVars
            ###
            if state != @data_state
                # Trigger loading start if current state is `loading`
                # and previous wasn't
                if state == 'loading'
                    @loadingStart()
                # Trigger loading end if previous state was `loading`
                # and current isn't
                else if @data_state == 'loading'
                    @loadingEnd()
                # Update data state if different
                @data_state = state

        getStateTemplateVars: (params...) ->
            ###
                Returns the template vars that the current
                state should be rendered with.

                Should be extended in subclasses to return different
                data structures depending on the state, otherwise
                it just returns an object with the current state
            ###
            return {state: @data_state}

        loadingStart: (loadingIndicatorEl) ->
            ###
                Callback triggered when widget is in a loading
                state.
                Extend this is subclasses at will.
            ###

        loadingEnd: () ->
            ###
                Callback triggered when widget leaves the loading
                state.
                Extend this is subclasses at will.
            ###
