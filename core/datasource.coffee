define ['cs!channels_utils', 'cs!fixtures'], (channels_utils, Fixtures) ->
    class DataSource
        constructor: ->
            @config = App.DataSourceConfig

        initialize: ->
            logger.info "Initializing data source"

            # Create a big collection hash which stores all the models,
            # collections and data which will be rendered
            @data = {}
            @meta_data = {}

            # Subscribe DataSource to the new widget channel.
            # This will make it subscribe widgets to changes for the data they are monitoring.
            @pipe = loader.get_module('pubsub')

            # Requests for new data channels (usually coming from controllers)
            @pipe.subscribe('/new_data_channels', @newDataChannels)

            # Announcements that new widgets are available
            # This binds the widgets' methods to the proper channel events
            # (we need this because channels are private to the DataSource)
            @pipe.subscribe('/new_widget', (data) => @newWidget(data))

            # Requests for scrolling channels
            @pipe.subscribe('/scroll', @pushDataAfterScroll)

            # Requests for refreshing data of a given channel
            @pipe.subscribe('/refresh', @pushDataAfterRefresh)

            # Requests for modifying a given data channel
            @pipe.subscribe('/modify', @modifyDataChannel)

            # Requests for adding new data to a given channel
            @pipe.subscribe('/add', @addToDataChannel)

        _getConfig: (channel) =>
            ###
                Returns the configuration for a given channel.
            ###

            # Get the channel key. This is where the actual data is in @data
            channel_key = channels_utils.getChannelKey(channel)

            # Use @meta_data to find out the actual type of this channel
            channel_type = @meta_data[channel_key].type

            # Finally, retrieve channel type configuration
            @config.channel_types[channel_type]

        _getType: (channel) =>
            ###
                Returns the channel type: relational / api / etc.
            ###
            @_getConfig(channel).type

        _getWidgetMethod: (fake_channel, widget) =>
            ###
                Gets the appropriate function from the widget to be called
                whenever events on channel occur.

                channel: the channel on which events occur
                widget: a widget instance
                Returns: an actual function from the widget instance
            ###

            # Get the channel key. This is where the actual data is in @data
            channel_key = channels_utils.getChannelKey(fake_channel)

            # Get the method name
            method_name = channels_utils.widgetMethodForChannel(widget, channel_key)

            # Return the actual method
            widget[method_name]

        _fetchChannelDataFromServer: (channel, reason = 'refresh') =>
            ###
                Fetch the data for the channel given the params.

                channel: the given channel. The HTTP parameters for fetching
                        the channel data are taken from @meta_data[channel].params
                Returns: nothing
            ###
            conf = @_getConfig(channel)
            channel_key = channels_utils.getChannelKey(channel)

            if reason == 'refresh'
                params = @meta_data[channel_key].params
            else if reason == 'scroll'
                params = conf.scroll_params(@data[channel_key], @meta_data[channel_key].params)

            # See if this channel has an associated URL.
            # If it has, we will fetch the data from that URL.
            # Otherwise, just load it from the fixtures.
            if 'url' of conf
                # Render the URL to which we're GET-ing or POST-ing.
                #
                # For POST requests, the URL should contain no extra GET params,
                # and those params should rather be sent through POST data.
                # This is because we might have large data to POST,
                # and as we all know, the GET URI has a pretty low length limit.
                @data[channel_key].url = Utils.render_url(conf.url, params, [], conf.fetch_through_POST)
                fetch_params =
                    add: (reason == 'scroll')
                    success: (collection, response) =>
                                @_checkForNewlyArrivedAndAwaitedModels(channel_key)
                    type: if conf.fetch_through_POST then 'POST' else 'GET'
                    data: if conf.fetch_through_POST then params else {}
                @data[channel_key].fetch(fetch_params)
            else
                @_loadFixtures(channel_key, params)

        _getRefreshInterval: (channel) =>
            ###
                Returns the periodic refresh interval for a given channel.

                channel: the channel to check
                Returns: the interval ifthe channel has periodic refresh
                         configured, 0 otherwise
            ###
            conf = @_getConfig(channel)
            if 'refresh' of conf and conf.refresh == 'periodic' and 'refresh_interval' of conf
                return conf.refresh_interval
            else
                return 0

        _setupPeriodicRefresh: (channel, interval) =>
            ###
                Sets up periodic refresh for a given channel.
            ###
            channel_key = channels_utils.getChannelKey(channel)

            # Make sure we don't do setInterval() more than once per channel.
            if @meta_data[channel_key].started_refresh
                return

            # Mark the fact that we're refreshing
            @meta_data[channel_key].started_refresh = true

            # Configure periodic refresh
            setInterval((=> @_fetchChannelDataFromServer(channel)), interval)

        _initRelationalChannel: (name, type, params, callback = null) =>
            ###
                Initialize a relational channel.

                A relational channel is backed by a Backbone collection. This
                will dynamically load the collection class via require.js, create
                an instance of the collection class and execute the callback if needed.
            ###

            # Load the collection class via require.js

            collection_name = @config.channel_types[type].collection or type[1..]
            collection_module = "cs!collection/" + collection_name

            require [collection_module], (collection_class) =>
                @data[name] = new collection_class()
                conf = @config.channel_types[type]
                if conf.populate_on_init and params._initial_data_
                    @data[name].add(params._initial_data_)
                    delete params._initial_data_
                @meta_data[name] = {type: type, params: params}
                callback(name, type, params) if callback

        _initApiChannel: (name, type, params, callback = null) =>
            ###
                Initialize an API channel.

                This will only create a raw data object instantly and perform
                the callback if needed.
            ###
            collection_name = @config.channel_types[type].collection or 'raw_data'
            collection_module = "cs!collection/" + collection_name

            require [collection_module], (collection_class) =>
                @data[name] = new collection_class()
                conf = @config.channel_types[type]
                # If there is a default value for this channel, set it.
                if 'default_value' of conf
                    @data[name].setDefaultValue(conf.default_value)
                # If the populate_on_init flag is set for this channel, then
                # the parameters sent when creating the channel serve as initial values.
                if conf.populate_on_init
                    @data[name].set(params)
                @meta_data[name] = {type: type, params: params}
                callback(name, type, params) if callback

        _initChannel: (name, type, params, callback=null) =>
            ###
                Initialize a channel. The datasource is just a big dict of these.
                name: the name of the channel (unique at the datasource level)
                type: the type of the channel ('/mentions', '/tags', etc.)
            ###

            logger.info("Initializing channel #{name}")
            # If the channel is already initialized, do nothing.
            if name of @data
                callback(name, type, params) if callback
                return

            # Cannot use @_getType() because channel doesn't exist yet.
            resource_type = @config.channel_types[type].type
            if resource_type == 'relational'
                @_initRelationalChannel(name, type, params, callback)
            else if resource_type == 'api'
                @_initApiChannel(name, type, params, callback)

        newDataChannels: (channels) =>
            ###
                Create some new data channels on-demand.

                Controllers usually issue this kind of request, in order to
                decide which data sources to "glue" to the widgets on their page.
            ###

            logger.info "Initializing new channels in DataSource"
            for channel_guid, channel_data of channels
                do(channel_guid, channel_data) =>
                    # Initialize the associated collection (if it's already initialized
                    # nothing will happen)
                    channel_type = channel_data.type
                    channel_params = channel_data.params
                    @_initChannel(channel_guid, channel_type, channel_params, (channel_guid, channel_type, channel_params) =>
                        # Setup periodic refresh if it's needed
                        refresh_interval = @_getRefreshInterval(channel_guid)
                        if refresh_interval > 0
                            if @_getConfig(channel_guid).start_immediately
                                # Fetch the initial data for the channel
                                @_fetchChannelDataFromServer(channel_guid)
                                @_setupPeriodicRefresh(channel_guid, refresh_interval)
                        else
                            # Fetch the initial data for the channel
                            if not @_getConfig(channel_guid).populate_on_init
                                @_fetchChannelDataFromServer(channel_guid)
                    )

        _modifyRelationalDataChannel: (channel, dict, update_mode) ->
            ###
                Implementation of modifyDataChannel specific for relational channels.
                We want to update (append, reset or exclude) attributes of a 
                model which is a part of a collection. We perform an implicit save 
                after we update the attributes. Because the save might fail we don't 
                want to trigger any change events on the collection/model before knowing 
                the new attributes are valid. We clone the individual model and 
                perform the update and then the save on the clone.
                After the save is successful in the success callback we set the 
                new attributes again and we let the change events propagate on 
                the collection.
            ###

            # Split the channel into its components. We ignore the "events" part.
            [collection, item, events] = channels_utils.splitChannel(channel)

            # Modifying the whole collection is not supported for Backbone collections
            if item == "all"
                logger.error("Modifying the whole collection is not supported for
                              relational collections")
                return
            
            individual_model = @data['/' + collection].get(item)
            # Clone the individual model and set it's urlRoot property 
            # because the clone won't be part of the collection. This way 
            # we have a proper model url
            cloned_model = individual_model.clone()
            cloned_model.urlRoot = @data['/' + collection].url
            # Update clone without triggering any change events (won't matter 
            # though because the clone is not part of a collection)
            silence = { silent: true }
            if update_mode == 'append'
                cloned_model.set(dict, silence)
            else if update_mode == 'reset'
                cloned_model.clear(silent)
                cloned_model.set(dict, silence)
            else if update_mode == 'exclude'
                for k of dict
                    cloned_model.unset(k, silence)
            # Perform a save on the model and propagate any error events 
            # received from the server on the model's channel. If the 
            # save is successful update the collection's model (individual_model) 
            # with the new values of the clone (this will trigger the change events 
            # after the save is ok). Otherwise trigger the errors on the 
            cloned_model.save(cloned_model.attributes, { 
                error: (model, response, options) =>
                    individual_model.trigger('error', model, response)
                success: (model, response) =>
                    individual_model.set(model.attributes)
            })

        _modifyApiDataChannel: (channel, dict, update_mode) ->
            ###
                Implementation of modifyDataChannel specific for api channels.
            ###

            # Split the channel into its components. We ignore the "events" part,
            [collection, item, events] = channels_utils.splitChannel(channel)

            # For raw data channels, we don't support individual model modifications.
            if item != "all"
                logger.error("Modifying individual items is not supported for " +
                             "raw collections")
                return

            model = @data['/' + collection]
            if update_mode == 'append'
                model.set(dict)
            else if update_mode == 'reset'
                model.setData(dict)
            else if update_mode == 'exclude'
                for k of dict
                    model.unset(k)

        modifyDataChannel: (channel, dict) =>
            ###
                Modifies the data found at channel by calling
                data.set(k, v) for each pair (k, v) of dict.
            ###
            resource_type = @_getType(channel)
            # HACK: determine the update mode for this item.
            # Possible values: 'append', 'reset', 'exclude'
            update_mode = dict['__update_mode__']
            delete dict['__update_mode__']

            if resource_type == 'relational'
                @_modifyRelationalDataChannel(channel, dict, update_mode)
            else if resource_type == 'api'
                @_modifyApiDataChannel(channel, dict, update_mode)

        addToDataChannel: (channel, dict, widget_data) =>
            ###
                This gets called whenever a new widget publishes to '/add' channel

            ###
            logger.info "Adding new data to #{channel} in DataSource"
            # Determine the method to be called on the widget
            collection = channels_utils.getChannelKey(channel)
            widget_method = @_getWidgetMethod(channel, widget_data.widget)

            model = new @data[collection].model(dict)
            # Bind all events of the model to the widget's method (get_tags, etc)
            model.on('all', widget_method, widget_data.widget)
            # Copy the url of the collection to the model, until the model 
            # is appended to the collection. Check BaseModel.url()
            model.urlRoot = @data[collection].url
            # Instead of adding the model to the collection via .create perform 
            # a manual save and if the operation is successful then append the 
            # model to the collection. By default collection.create appends 
            # the model to the collection even if the model wasn't saved 
            # successfully (and we don't want that)
            model.save(model.attributes, { 
                error: (model, response, options) =>
                    # Trigger an error event on the collection, even though the model 
                    # is not part of the collection yet. This is a CONVENTION to 
                    # ease the work with new models
                    @data[collection].trigger('error', model, @data[collection], response)
                success: (model, response) => 
                    @data[collection].add(model)
            })

        newWidget: (widget_data) =>
            ###
                This gets called whenever a new widget announces its existence.

                It determines which data from the data source is "interesting"
                for the widget and subscribes the widget to changes on that data.
            ###
            logger.info "Initializing #{widget_data.name} widget in DataSource"

            # For each of the data channels the widget is subscribed to
            for channel, real_channel of widget_data.subscribed_channels
                do (channel, real_channel) =>
                    # Subscribe the widget to the events of the channel
                    @_bindWidgetToChannel(channel, real_channel, widget_data)

        _checkForNewlyArrivedAndAwaitedModels: (channel) =>
            ###
                Checks if some new models which were awaited for have appeared
                into the given channel. If there are, bind the respective
                widgets to the individual models and drop the widget references.
            ###
            if not ('delayed_single_items' of @meta_data[channel])
                return
            remaining_delayed_items = []
            for delayed_item in @meta_data[channel].delayed_single_items
                single_item = @data[channel].get(delayed_item.id)

                # If the item still hasn't appeared, plan it for later re-use
                if not single_item
                    remaining_delayed_items.push(delayed_item)
                    continue
                # Otherwise, do the binding and drop the widget reference
                else
                    @_bindWidgetToRelationalChannel(delayed_item.fake_channel,
                                                    delayed_item.channel,
                                                    delayed_item.widget_data)

            # Check if there are still single items to wait for
            if remaining_delayed_items.length > 0
                @meta_data[channel].delayed_single_items = remaining_delayed_items
            else
                delete @meta_data[channel]['delayed_single_items']

        _bindWidgetToRelationalChannel: (fake_channel, channel, widget_data) =>
            ###
                Given a widget, bind it to the events of a backbone collection
                or of an individual item of the collection.
            ###

            # Determine the method to be called on the widget
            [collection, item, events] = channels_utils.splitChannel(channel)
            collection = '/' + collection
            widget_method = @_getWidgetMethod(fake_channel, widget_data.widget)
            if not widget_method
                return
            # Only send fake events when widget subscribes to collection
            # events if widget doesn't refuse them via skip_fake_events.
            skip_fake = widget_data.widget.skip_fake_events

            # Whole collection and also give the widget context
            if item == "all"
                @data[collection].on(events, widget_method, widget_data.widget)
                widget_method('reset', @data[collection]) unless skip_fake
            # Individual collection models
            else
                individual_model = @data[collection].get(item)
                # If model is already there, we just bind it and get over with it
                if individual_model
                    individual_model.on(events, widget_method, widget_data.widget)
                    widget_method('change', individual_model) unless skip_fake
                # Else, enqueue the (individual model ID, widget) pair and keep
                # checking for new items whenever data arrives into this channel.
                # When the model finally arrives, drop the reference to the widget.
                else
                    if not ('delayed_single_items' of @meta_data[collection])
                        @meta_data[collection]['delayed_single_items'] = []
                    @meta_data[collection]['delayed_single_items'].push(
                        fake_channel: fake_channel
                        channel: channel
                        widget_data: widget_data
                        id: item
                    )

        _bindWidgetToApiChannel: (fake_channel, channel, widget_data) =>
            ###
                Given a widget, bind it to the events of an api (raw data) channel.
            ###
            [collection, item, events] = channels_utils.splitChannel(channel)
            collection = '/' + collection
            widget_method = @_getWidgetMethod(fake_channel, widget_data.widget)
            if not widget_method
                return

            raw_channel = @data[collection]
            raw_channel.on(events, widget_method, widget_data.widget)

            # Only send fake events when widget subscribes to collection
            # events if widget doesn't refuse them via skip_fake_events.
            skip_fake = widget_data.widget.skip_fake_events
            widget_method('change', @data[collection]) unless skip_fake

        _bindWidgetToChannel: (fake_channel, channel, widget_data) =>
            ###
                Bind a widget to a given channel's events.

                This is the __only__ place in which the datalayer should use
                the widget reference. The reason for which we need the reference
                here is that it subscribes it to the events of the private data
                of the datasource.

                This will actually delegate to more specific types of bindings:
                    - bindings of widgets to backbone collections
                        (for relational channels)
                    - bindings of widgets to raw data
                        (for api channels)
            ###
            logger.info "Linking widget #{widget_data.name} to #{channel}"
            resource_type = @_getType(channel)
            if resource_type == 'relational'
                @_bindWidgetToRelationalChannel(fake_channel, channel, widget_data)
            else if resource_type == 'api'
                @_bindWidgetToApiChannel(fake_channel, channel, widget_data)

        pushDataAfterScroll: (channels) =>
            ###
                This gets called every time a widget publishes to "/scroll"

                Data sources receives the scrollable_channels, sets the new collection
                page based on the channels, which will trigger the widget to update
            ###

            # For each of the scrollable channels the widget is subscribed to
            for channel in channels
                do (channel) =>
                    logger.info "Scrolling #{channel} in DataSource"
                    @_fetchChannelDataFromServer(channel, 'scroll')

        pushDataAfterRefresh: (channels) =>
            ###
                This gets called every time a widget publishes to "/refresh"

                Data sources will update the data channel according to its
                configured policy.
            ###

            # If channels is an array, it means that we're not receiving any
            # parameters to the channels refresh.
            if $.isArray(channels)
                dict = {}
                for channel in channels
                    # Use existing params if no params were specified
                    dict[channel] = @meta_data[channel].params
                empty_params = true
            # Otherwise, we're getting channel-specific params for refresh
            else if $.isPlainObject(channels)
                dict = channels
                empty_params = false
            else
                logger.warn("Unknown parameter type for pushDataAfterRefresh: #{channels}")
                return

            for channel, params of dict
                do (channel, params) =>
                    logger.info "Sends data to #{channel} in DataSource"
                    @meta_data[channel].params = params
                    @_fetchChannelDataFromServer(channel)

                    refresh_interval = @_getRefreshInterval(channel)
                    if refresh_interval > 0 and (not @meta_data[channel].started_refresh)
                        @_setupPeriodicRefresh(channel, refresh_interval)

        _channelHasFixture: (name) ->
            ###
                Check if channel has a fixture
            ###
            base_type = @meta_data[name].type
            return @_getType(name) == 'relational' and base_type[1..] of Fixtures

        _fixtureMatchesParams: (item, params) ->
            ###
                Determines if a fixture item matches the given parameters.

                For example, if params = {gender: 'm'}, it checks whether
                item.gender exists and is equal to 'm'.
            ###
            for k, v of params
                if not k of item
                    return false
                if item[k] != v
                    return false

            return true

        _loadFixtures: (channel = null, params = {}, id_offset=0, add_instead_of_push=false) =>
            ###
                Loads fixtures from the fixtures.js file.

                This will initialize the proper collections and populate them with data.
            ###

            # Determine which collections to load - those found in the
            # configuration and also found in the Fixtures array.
            collections_to_load = []

            if channel
                if @_channelHasFixture(channel)
                    collections_to_load = [channel]
            else
                collections_to_load = [name for name of @data when @_chanelHasFixture(name)]

            for name in collections_to_load
                base_type = @meta_data[name].type
                model_fixtures = Fixtures[base_type[1..]].responseText
                collection_instance = @data[name]
                added = 0
                for fixture_item in model_fixtures
                    fixture_item.id += id_offset
                    # Check if the fixtured item matches the given parameters
                    if @_fixtureMatchesParams(fixture_item, params)
                        logger.info("Adding new model to #{name}")
                        added = added + 1
                        model = new collection_instance.model(fixture_item)
                        if add_instead_of_push
                            collection_instance.add(model)
                        else
                            collection_instance.push(model)
                logger.info("Added #{added} fixtured items to channel #{name}")

        destroy: ->
            logger.info "Destroying data source"

    return DataSource