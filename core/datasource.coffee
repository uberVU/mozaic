define ['cs!channels_utils', 'cs!fixtures'], (channels_utils, Fixtures) ->
    class DataSource

        checkIntervalForUnusedCollections: 10000

        constructor: ->
            @config = App.DataSourceConfig

            # Pre-process channel definitions in order to factor in
            # channel templates. This will allow us to write less
            # for very similar channels and group the common properties
            # together.
            #
            # Moreover, channel templates support the notion of parent,
            # so that there is actually a 3-level hierarchy:
            # parent of channel template - channel template - channel def
            for k, v of @config.channel_templates
                if v.parent
                    if not (v.parent of @config.channel_templates)
                        logger.error("Channel template #{k} has invalid parent #{v.parent}")
                        continue
                    parent = @config.channel_templates[v.parent]
                    @config.channel_templates[k] = _.extend({}, parent, v)

            for k, v of @config.channel_types
                if v.template
                    if not (v.template of @config.channel_templates)
                        logger.error("Channel type #{k} has invalid template #{v.template}")
                        continue
                    template = @config.channel_templates[v.template]
                    @config.channel_types[k] = _.extend({}, template, v)

        initialize: ->
            logger.info "Initializing data source"

            # Create a big collection hash which stores all the models,
            # collections and data which will be rendered
            @data = {}
            @meta_data = {}

            # Setting this to false will cause all fetches to perform
            # synchronous ajax requests (used only for testing).
            @_async_fetches = true

            # Subscribe DataSource to the new widget channel.
            # This will make it subscribe widgets to changes for the data they are monitoring.
            @pipe = loader.get_module('pubsub')

            # Requests for new data channels (coming from widgets / controllers).
            @pipe.subscribe('/new_data_channels', @newDataChannels)

            # Announcements that new widgets are available
            # This binds the widgets' methods to the proper channel events
            # (we need this because channels are private to the DataSource)
            @pipe.subscribe('/new_widget', (data) => @newWidget(data))

            # Announcements that widgets were removed
            # This binds the widgets' methods to the proper channel events
            # (we need this because channels are private to the DataSource)
            @pipe.subscribe('/destroy_widget', (data) => @destroyWidget(data))
            setInterval(@checkForUnusedCollections, @checkIntervalForUnusedCollections)

            # Requests for scrolling channels
            @pipe.subscribe('/scroll', @pushDataAfterScroll)

            # Requests for refreshing data of a given channel
            @pipe.subscribe('/refresh', @pushDataAfterRefresh)

            # Requests for modifying a given data channel
            @pipe.subscribe('/modify', @modifyDataChannel)

            # Requests for adding new data to a given channel
            @pipe.subscribe('/add', @addToDataChannel)

            # Requests for deleting data from a given channel
            @pipe.subscribe('/delete', @deleteFromDataChannel)

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

        _getDefaultParams: (channel) =>
            ###
                Returns the default HTTP params for a given channel.
                This feature is only supported by relational channels for now.

                For API channels, the default_value has a completely different
                meaning: the default value of the JSON data.

                TODO(andrei): refactor this to be less dumb
            ###

            type = @_getType(channel)
            # We only support HTTP params for channels of type relational
            if type != 'relational'
                return {}
            conf = @_getConfig(channel)
            conf.default_value or {}

        _fetchChannelDataFromServer: (channel, reason = 'refresh') =>
            ###
                Fetch the data for the channel given the params.

                channel: the given channel. The HTTP parameters for fetching
                        the channel data are taken from @meta_data[channel].params
                Returns: nothing
            ###
            # Sanity check - the only valid reasons for fetching data are
            # 'refresh', 'scroll' and 'streampoll'.
            if not (reason in ['refresh', 'scroll', 'streampoll'])
                throw "Invalid reason: #{reason}"
                return

            conf = @_getConfig(channel)
            channel_key = channels_utils.getChannelKey(channel)

            # Build the current parameters. For normal requests,
            # they are the current default values overlapped with
            # the current values (found in @meta_data[channel_key]).
            default_value = @_getDefaultParams(channel)
            params = _.extend({}, default_value, @meta_data[channel_key].params)

            # If we're fetching on behalf of a scroll / streampoll request,
            # make sure that we give the scroll/streampoll_params function
            # the opportunity to modify the current HTTP params.
            if reason in ['scroll', 'streampoll']
                fn_name = reason + '_params'
                if not (fn_name of conf)
                    logger.error("Configuration for channel #{channel_key} should have function #{fn_name}")
                    return
                # Retrieve the new parameters
                params = conf[fn_name](@data[channel_key], params)
                if not params
                    # Cancel the current streampoll/scroll request if params == null.
                    # Careful - emtpy dict { } evaluates to true in JavaScript!
                    return

            # See if this channel has an associated URL. If it doesn't,
            # just load it from fixtures.
            if not ('url' of conf)
                @_loadFixtures(channel_key, params)
                # Fixture channels are fetched synchronously, no need to
                # call _fillWaitingChannels
                return @meta_data[channel_key].last_fetch = Utils.now()

            # Channel has an associated URL. Fetch data from that URL.

            # Render the URL to which we're GET-ing or POST-ing.
            #
            # For POST requests, the URL should contain no extra GET params,
            # and those params should rather be sent through POST data.
            # This is because we might have large data to POST,
            # and as we all know, the GET URI has a pretty low length limit.

            fetch_params =
                async: @_async_fetches
                add: true
                type: if conf.fetch_through_POST then 'POST' else 'GET'
                data: if conf.fetch_through_POST then params else {}

            # Only set last_fetch and perform
            # _checkForNewlyArrivedAndAwaitedModels on refresh events
            # (skip for all others).
            fetch_params.success = (collection, response) =>
                @_checkForNewlyArrivedAndAwaitedModels(channel_key)
                # Only fill waiting channels the first time this
                # channel receives data.
                if not @meta_data[channel_key].last_fetch?
                    @_fillWaitingChannels(channel_key)
                @meta_data[channel_key].last_fetch = Utils.now()

            # Don't add models on refresh (reset entire collection).
            if reason == 'refresh'
                fetch_params.add = false

            # What channel should receive the data we're about to fetch -
            # the original channel, or that channel's buffer?
            # (The first fetch should always be into the real channel).
            if reason == 'streampoll' and @_getBufferSize(channel) and @meta_data[channel_key].last_fetch?
                receiving_channel = @data[channel_key].buffer
                # If the buffer is full, avoid doing any more fetches.
                if receiving_channel.length >= conf.buffer_size
                    return
            else
                receiving_channel = @data[channel_key]

            receiving_channel.url = Utils.render_url(conf.url, params, [], conf.fetch_through_POST)
            receiving_channel.fetch(fetch_params)

        _flushChannelBuffer: (channel_guid) =>
            ###
                Flush channel buffer by moving buffer data into channel data,
                then reset buffer.
            ###
            logger.info "Flushing channel #{channel_guid} buffer"
            channel = @data[channel_guid]

            # Get where to append the buffered items: 'begin' or 'end'
            conf = @_getConfig(channel_guid)
            add_to = conf.streampoll_add_to || 'end'

            # If we add to the beginning, we take the elements in reverse order
            # from the buffer and add each element to the beginning.
            if add_to == 'begin'
                while channel.buffer.length > 0
                    model = channel.buffer.shift()
                    channel.unshift(model)
            # Otherwise, just append the whole buffer to the end of the collection
            else if add_to == 'end'
                # Add all models from buffer into channel, without event silencing.
                channel.add(channel.buffer.models)
                # Reset buffer without triggering any events.
                channel.buffer.reset([])

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

        _getRefreshType: (channel) =>
            ###
                Returns the refesh type for a given channel:
                'refresh' (default), 'streampoll', or 'scroll'.
            ###
            return @_getConfig(channel).refresh_type or "refresh"

        _getBufferSize: (channel) =>
            ###
                Returns the buffer size for a given channel (0 for no buffer).
            ###
            conf = @_getConfig(channel)
            # Only streampoll channels may have buffers.
            if conf.refresh_type == 'streampoll' and conf.buffer_size?
                return conf.buffer_size
            else
                return 0

        _setupPeriodicRefresh: (channel) =>
            ###
                Sets up periodic refresh for a given channel.
            ###
            channel_key = channels_utils.getChannelKey(channel)

            # Make sure this channel needs a periodic refresh.
            refresh_interval = @_getRefreshInterval(channel_key)
            if not refresh_interval
                return

            # Make sure we don't do setInterval() more than once per channel.
            if @meta_data[channel_key].started_refresh
                return

            # Mark the fact that we're refreshing
            @meta_data[channel_key].started_refresh = true

            # Configure periodic refresh with reason="refresh" or "streampoll"
            # (or "scroll", but that makes very little sense).
            refresh_type = @_getRefreshType(channel)
            handle = setInterval((=> @_fetchChannelDataFromServer(channel, refresh_type)), refresh_interval)
            @meta_data[channel_key].periodic_refresh_handle = handle

        _stopPeriodicRefresh: (channel) =>
            ###
                Stops periodic refresh it was enabled for a given channel.
            ###

            # If this channel doesn't have periodic refresh, give up.
            if not @_getRefreshInterval(channel)
                return

            # If this channel has periodic refresh, but it hasn't started yet,
            # also nothing to do about it.
            if not @meta_data[channel].started_refresh
                return

            # If something went wrong and we don't have a handle pointing
            # to the result of the channel's setInterval(), give up.
            if not @meta_data[channel].periodic_refresh_handle
                return

            # Finally stop refreshing this channel
            clearInterval(@meta_data[channel].periodic_refresh_handle)

        _initRelationalChannel: (name, type, params) =>
            ###
                Initialize a relational channel.

                A relational channel is backed by a Backbone collection. This
                will dynamically load the collection class via require.js,
                create an instance of the collection class and perform
                final channel initialization logic.
            ###

            # Load the collection class via require.js
            collection_name = @config.channel_types[type].collection or type[1..]
            collection_module = "cs!collection/" + collection_name

            require [collection_module], (collection_class) =>
                @data[name] = new collection_class()
                conf = @config.channel_types[type]
                eternal = params['__eternal__']?
                delete params['__eternal__'] if eternal
                @meta_data[name] = {type: type, params: params, eternal: eternal}
                if conf.populate_on_init and params._initial_data_
                    @data[name].add(params._initial_data_)
                    delete params._initial_data_
                    # The url of a collection is set after fetching server
                    # data, but for collections with initial data the fetch
                    # branch is not executed. Set the url here.
                    default_value = @_getDefaultParams(name)
                    url_params = _.extend({}, default_value, params)
                    if conf.url?
                        @data[name].url = Utils.render_url(conf.url, url_params)
                # Initialize buffer.
                if conf.buffer_size? and conf.buffer_size
                    @data[name].buffer = new collection_class()
                    # Give access to the collection from the buffer
                    @data[name].buffer.collection = @data[name]
                @_finishChannelInitialization(name)

        _initApiChannel: (name, type, params) =>

            ###
                Initialize an API channel.

                This will only create a raw data object instantly and perform
                final channel initialization logic.
            ###
            # Load the collection class via require.js
            collection_name = @config.channel_types[type].collection or 'raw_data'
            collection_module = "cs!collection/" + collection_name

            require [collection_module], (collection_class) =>
                @data[name] = new collection_class()
                conf = @config.channel_types[type]
                eternal = params['__eternal__']?
                delete params['__eternal__'] if eternal
                @meta_data[name] = {type: type, params: params, eternal: eternal}
                # If there is a default value for this channel, set it.
                if 'default_value' of conf
                    @data[name].setDefaultValue(conf.default_value)
                # If the populate_on_init flag is set for this channel, then
                # the parameters sent when creating the channel serve as initial values.
                if conf.populate_on_init
                    @data[name].set(params)
                @_finishChannelInitialization(name)

        _getChannelDuplicates: (channel_guid) =>
            ###
                Determines all duplicates of some channel. Returns a list
                of channel_guids, or an empty list, if not duplicates are found.
            ###
            duplicates = [ ]
            channel_data = @meta_data[channel_guid]
            for other_channel_guid, other_channel_data of @meta_data
                if channel_guid != other_channel_guid and
                   channel_data.type == other_channel_data.type and
                   _.isEqual(channel_data.params, other_channel_data.params)
                    duplicates.push(other_channel_guid)
            return duplicates

        _cloneChannel: (channel_guid, source_channel_guid) =>
            ###
                Clones the source channel to channel_guid.
            ###
            logger.info "Cloning #{channel_guid} from #{source_channel_guid}"
            # Mark the new clone as having been recently fetched.
            @meta_data[channel_guid].last_fetch = @meta_data[source_channel_guid].last_fetch
            dest = @data[channel_guid]
            source = @data[source_channel_guid]
            channel_type = @_getType(channel_guid)
            if channel_type == 'relational'
                # Clone model without triggering any events.
                silence = { silent: true }
                for model in source.models
                    dest.add(model.clone(), silence)
                # Trigger the golden news
                dest.trigger('reset', dest)
                # Clone buffer
                if 'buffer' of source
                    for model in source.buffer.models
                        dest.buffer.add(model.clone(), silence)
                # Clone url property
                if 'url' of source
                    dest.url = source.url
            else if channel_type == 'api'
                dest.set(source.data)

        _fillWaitingChannels: (channel_guid) =>
            ###
                Try to fill each waiting channel that is a duplicate of
                this one.
            ###
            duplicates = @_getChannelDuplicates(channel_guid)
            for dest_channel_guid in duplicates
                if not @meta_data[dest_channel_guid].last_fetch?
                    # If dest_channel does not yet have data, clone into it
                    # by using this channel as clone source.
                    @_cloneChannel(dest_channel_guid, channel_guid)

        _finishChannelInitialization: (channel_guid) =>
            ###
                Channel initialization ends with one of the following outcomes,
                depending on existence of channel duplicates:
                    1) if no duplicates exist => fetch
                    2) if duplicates exist and some have data => clone
                    3) if duplicates exist but none have data => wait
                Waiting for data only happens when a duplicate exists that
                does not have data (yet). That channel is currently waiting
                for data (in fetching state), and when it receives data, it
                will fill this channel as well (via _fillWaitingChannels).
            ###

            # Cloning / fetching logic:
            duplicates = @_getChannelDuplicates(channel_guid)
            if duplicates.length == 0 or @_getConfig(channel_guid).disable_clone
                # 1) No channel duplicates exist, perform fetch.
                refresh_interval = @_getRefreshInterval(channel_guid)
                if refresh_interval > 0
                    if @_getConfig(channel_guid).start_immediately
                        # Fetch the initial data for the channel
                        @_fetchChannelDataFromServer(channel_guid)
                else
                    # Fetch the initial data for the channel
                    if not @_getConfig(channel_guid).populate_on_init
                        @_fetchChannelDataFromServer(channel_guid)
                    else
                        # If this channel was populated on init, mark it
                        # as having data.
                        @meta_data[channel_guid].last_fetch = Utils.now()
            else
                # If at least one duplicate was fetched (has data), use it
                # as a cloning source. Otherwise, this channel will wait
                # for data.
                duplicate_channel_guid = null
                for other_channel_guid in duplicates
                    if @meta_data[other_channel_guid].last_fetch?
                        duplicate_channel_guid = other_channel_guid
                        break
                if duplicate_channel_guid
                    @_cloneChannel(channel_guid, duplicate_channel_guid)
                else
                    logger.info "Channel #{channel_guid} is waiting for data"

            # Setup periodic refresh if needed.
            @_setupPeriodicRefresh(channel_guid)

            # Announce widget starter a new channel is available
            @pipe.publish('/initialized_channel', {name: channel_guid})

        newDataChannels: (channels) =>
            ###
                Create some new data channels on-demand.

                Controllers and widgets usually issue this kind of request,
                in order to decide which data sources to "glue" to their
                subordinated widgets on their page.
            ###

            logger.info "Initializing new channels in DataSource"
            for channel_guid, channel_data of channels
                do(channel_guid, channel_data) =>
                    # If the channel is already initialized, do nothing,
                    # otherwise initialize the associated collection.
                    if channel_guid of @data
                        return

                    logger.info("Initializing channel #{channel_guid}")

                    channel_type = channel_data.type
                    channel_params = _.clone(channel_data.params)

                    # Cannot use @_getType() because channel doesn't exist yet.
                    if channel_type of @config.channel_types
                        resource_type = @config.channel_types[channel_type].type
                        if resource_type == 'relational'
                            @_initRelationalChannel(channel_guid, channel_type, channel_params)
                        else if resource_type == 'api'
                            @_initApiChannel(channel_guid, channel_type, channel_params)
                    else
                        logger.error("Trying to initialize channel of unknown type: #{channel_type}")

        _findAndModifyRelationalChannelModel: (channel_guid, item, dict, update_mode, sync = true) ->
            ###
                Implementation of modifyDataChannel specific for relational channels.
                We want to update (append, reset or exclude) attributes of a
                model which is a part of a collection. We perform an implicit save
                after we update the attributes. Because the save might fail we don't
                want to trigger any change events on the collection/model before knowing
                the new attributes are valid. We clone the individual model and
                perform the update and then the save on the clone.
                After the save is successful (only if we have to sync with the server)
                in the success callback we set the new attributes again and
                we let the change events propagate on the collection
            ###
            # If it's a relational channel backed by a fixture
            if not ('url' of @_getConfig(channel_guid))
                individual_model = @data[channel_guid].get(item)
                if individual_model
                    individual_model.set(dict)
                return
            @_findAndModifyCollectionModel(@data[channel_guid], item, dict, update_mode, sync=sync)
            # Also look for item in buffer, and modify it if it exists.
            if @_getBufferSize(channel_guid)
                @_findAndModifyCollectionModel(@data[channel_guid].buffer, item, dict, update_mode, sync=false)

        _findAndModifyCollectionModel: (collection, item_id, dict, update_mode, sync=true) ->
            ###
                Looks for an item_id in some collection, and modifies it if
                it was found.
            ###

            # Perform find - return null if item_id is not found in collection.
            individual_model = collection.get(item_id)
            if not individual_model
                return

            # Clone the individual model and set it's urlRoot property
            # because the clone won't be part of the collection. This way
            # we have a proper model url
            cloned_model = individual_model.clone()
            cloned_model.urlRoot = collection.url
            cloned_model.collection = collection
            # Update clone without triggering any change events (won't matter
            # though because the clone is not part of a collection)

            # Q(Mihnea): What is this doing here? I think we should at least
            # move it inside the "if sync" branch.
            cloned_model = @_updateRelationModel(cloned_model, dict, update_mode)

            # Perform a save on the model and propagate any error events
            # received from the server on the model's channel. If the
            # save is successful update the collection's model (individual_model)
            # with the new values of the clone (this will trigger the change events
            # after the save is ok). Otherwise trigger the errors on the individual
            # model
            if sync
                # Trigger a custom invalidate event before the
                # model is saved to the server. Backbone.Model emits
                # a sync event if the save was successful
                individual_model.trigger('invalidate', individual_model)
                cloned_model.save(cloned_model.attributes, {
                    error: (model, response, options) =>
                        individual_model.trigger('error', model, response)
                    success: (model, response) =>
                        individual_model.set(model.attributes)
                })
            else
                # TODO: For consistency should we trigger invalidate here as well?
                # If we don't need to sync with the server we can just update
                # the model reference in the collection and now trigger
                # the change events
                @_updateRelationModel(individual_model, dict, update_mode, silent = false)

        _updateRelationModel: (model, dict, update_mode, silent = true) ->
            ###
                Update a provided model with the dict arguments bypassing
                events triggering using the silent argument.
            ###
            silence = { silent: silent }
            if update_mode == 'append'
                model.set(dict, silence)
            else if update_mode == 'reset'
                model.clear(silent)
                model.set(dict, silence)
            else if update_mode == 'exclude'
                for k of dict
                    model.unset(k, silence)
            return model

        _modifyApiDataChannel: (channel_guid, dict, update_mode) ->
            ###
                Implementation of modifyDataChannel specific for api channels.
            ###

            model = @data[channel_guid]
            if update_mode == 'append'
                model.set(dict)
            else if update_mode == 'reset'
                model.set(dict, null, {reset: true})
            else if update_mode == 'exclude'
                for k of dict
                    model.unset(k)

        modifyDataChannel: (channel, dict) =>
            ###
                Modifies the data found at channel by calling
                data.set(k, v) for each pair (k, v) of dict.
            ###
            logger.info "Modifying data from #{channel} in DataSource"
            resource_type = @_getType(channel)
            # HACK: determine the update mode for this item.
            # Possible values: 'append', 'reset', 'exclude'
            update_mode = dict['__update_mode__']
            delete dict['__update_mode__']
            # Determine whether we should sync the data with the
            # server
            sync = dict['__sync__']
            delete dict['__sync__']

            # Split the channel into its components and get the "id" part.
            item = channels_utils.splitChannel(channel)[1]
            channel_guid = channels_utils.getChannelKey(channel)

            if resource_type == 'relational'
                # Modifying the whole collection is not supported for Backbone collections
                if item == "all"
                    logger.error("Modifying the whole collection is not supported for
                                  relational collections")
                    return
                channel_type = @meta_data[channel_guid].type
                # Modify each channel that contains the given item. If we want to sync 
                # the given item with the server we should do this only once (no need 
                # for more than one request to be send out to the server) for a single 
                # channel
                item_synced = false
                for other_channel_guid, other_channel_data of @meta_data
                    if other_channel_data.type == channel_type
                        # If the item wasn't synced with the server and we have to sync it, 
                        # do it only once
                        if sync and not item_synced
                            @_findAndModifyRelationalChannelModel(other_channel_guid, item, dict, update_mode, sync)
                            item_synced = true
                        else
                            @_findAndModifyRelationalChannelModel(other_channel_guid, item, dict, update_mode, false)
                        
            else if resource_type == 'api'
                # For raw data channels, we don't support individual model modifications.
                if item != "all"
                    logger.error("Modifying individual items is not supported for
                                  raw collections")
                    return
                @_modifyApiDataChannel(channel_guid, dict, update_mode)

        addToDataChannel: (channel, dict) =>
            ###
                This gets called whenever a new widget publishes to '/add' channel

            ###
            logger.info "Adding new data to #{channel} in DataSource"
            # Get the collection associated with this channel
            collection = channels_utils.getChannelKey(channel)

            # HACK: determine the sync for this item. It is sent in the
            # dict updates ...
            sync = dict['__sync__']
            delete dict['__sync__']

            model = new @data[collection].model(dict)
            # Copy the url of the collection to the model, until the model
            # is appended to the collection. Check BaseModel.url()
            model.urlRoot = @data[collection].url
            # Based on the sync argument we decide whether we should
            # save the model on the server
            if sync
                # Trigger a custom invalidate event before the
                # model is saved to the server. Backbone.Model emits
                # a sync event if the save was successful
                model.trigger('invalidate', model)
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
            else
                # Just add the model in the collection
                @data[collection].add(model)

        _deleteFromRelationalDataChannel: (channel, sync = true) ->
            ###
                Delete a model from a Backbone collection. Calls
                destroy on the model if the change has to be synced with
                the server, otherwise removes the element from the
                collection
            ###
            # Split channel into it's components. Ignoring events
            [collection_name, item, events] = channels_utils.splitChannel(channel)

            # Deleting the whole collection is not supported for Backbone collections
            if item == "all"
                logger.error("Deleting whole collection is not supported for
                              relational collections")
                return

            collection = @data[channels_utils.formChannel(collection_name)]

            # Getting the individual model to destroy
            individual_model = collection.get(item)

            # If the destroy has to be synced with the server
            if sync
                # Destroy the object
                # http://documentcloud.github.com/backbone/#Model-destroy
                individual_model.destroy({ wait: true })
            else
                # Remove the object from it's collection
                collection.remove(individual_model)


        deleteFromDataChannel: (channel, sync = true) =>
            ###
                Delete an item from a channel. You can only delete
                from relational channels
            ###
            logger.info "Deleting data from #{channel} in DataSource"

            channel_type = @_getType(channels_utils.getChannelKey(channel))
            if channel_type == 'relational'
                @_deleteFromRelationalDataChannel(channel, sync)
            else if channel_type == 'api'
                logger.error("Deleting from api channels is not supported")



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
                    #add reference counter for determining if this channel
                    #is still in use or not
                    collection = channels_utils.getChannelKey(real_channel)
                    @meta_data[collection]['reference_count'] = (@meta_data[collection]['reference_count'] ? 0) + 1
                    #this timestamp allows us to see for how long the channel
                    #has been inactive
                    @meta_data[collection]['time_of_reference_expiry'] = null

        destroyWidget: (widget_data) =>

            logger.warn "Destroy #{widget_data.name} widget in DataSource"
            for fake_channel, channel of widget_data.widget.channel_mapping
                if not (channel of @meta_data)
                    logger.warn('Could not unbind widget from collection ' +
                                 collection + ' because it was already gone')
                    continue

                # Start unbinding the widget to the existing channel.
                widget_method = @_getWidgetMethod(fake_channel, widget_data.widget)
                [collection, item, events] = channels_utils.splitChannel(fake_channel)

                # For relational channel, we have item-level unbinding and
                # collection-level unbinding, depending on the type of widget
                # subscription.
                if @_getType(channel) == 'relational'
                    if item == "all"
                        @data[channel].off(events, widget_method, widget_data.widget)
                    else
                        individual_item = @data[channel].get(item)
                        # Here we might have a problem: when resetting a
                        # collection, there is no way to keep references to the
                        # old widgets so that we unbind events from them.
                        # TODO(andrei): investigate if we can do something in
                        # the BaseModel class.
                        if individual_item
                            individual_item.off(events, widget_method, widget_data.widget)
                else if @_getType(channel) == 'api'
                    @data[channel].off(events, widget_method, widget_data.widget)

                @meta_data[channel]['reference_count'] -= 1
                if @meta_data[channel]['reference_count'] == 0
                    @meta_data[channel]['time_of_reference_expiry'] = Date.now()

        checkForUnusedCollections: =>
            ###
                This function gets cleaned up periodically in order to
                inspect which channels still have a non-zero reference count
                and which don't.

                Those who have been inactive (e.g., 0 reference count) for
                quite a while (> checkIntervalForUnusedCollections) will be
                garbage colllected, unless they are eternal.

                Some collections might be eternal, and this is a per-channel
                flag (so not found in datasource.js, but passed to
                Utils.newDataChannels when creating channel instances) because
                for example they are created from the application controller
                and they should live for the whole navigation session regardless
                of whether what is found on the page actually references them
                or not.
            ###
            for collection of @meta_data
                meta = @meta_data[collection]

                # Eternal collections are never expired
                if meta.eternal
                    continue

                # If this collection still has references attached, so skip it.
                if meta['time_of_reference_expiry'] == null
                    continue

                # Check if the current collection has had
                # 0 reference count for quite a while.
                expired_for = Date.now() - meta['time_of_reference_expiry']
                if expired_for > @checkIntervalForUnusedCollections
                    # Declare that channel has expired loudly and openly.
                    logger.warn("#{collection} collection expired in DataSource.")
                    # Stop periodic refresh if it was enabled
                    @_stopPeriodicRefresh(collection)
                    # Throw away channel meta-data
                    delete @meta_data[collection]
                    # Delete cyclic reference from channel to its buffer
                    if @data[collection].buffer
                        delete @data[collection].buffer.collection
                        @data[collection].buffer.off()
                        delete @data[collection].buffer
                    # Unbind all remaining widgets (should be none!)
                    @data[collection].off()
                    # Throw away reference to the actual data
                    delete @data[collection]

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

            # Whole collection and also give the widget context
            if item == "all"
                @data[collection].on(events, widget_method, widget_data.widget)
                # If data is already there, just pretend it arrived just now.
                if @meta_data[collection].last_fetch
                    widget_method('reset', @data[collection])
            # Individual collection models
            else
                individual_model = @data[collection].get(item)
                # If model is already there, we just bind it and get over with it
                if individual_model
                    individual_model.on(events, widget_method, widget_data.widget)
                    widget_method('change', individual_model)
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

            # If data is already there, just pretend it arrived just now.
            if @meta_data[collection].last_fetch
                widget_method('change', @data[collection])

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
            # Otherwise, we're getting channel-specific params for refresh
            else if $.isPlainObject(channels)
                dict = channels
            else
                logger.warn("Unknown parameter type for pushDataAfterRefresh: #{channels}")
                return

            for channel, params of dict
                do (channel, params) =>
                    logger.info "Sends data to #{channel} in DataSource"
                    same_params = _.isEqual(@meta_data[channel].params, params)
                    @meta_data[channel].params = params

                    # If the current channel is buffered and its buffer
                    # is not full, flush buffer instead of refreshing.
                    if @_getBufferSize(channel) > 0 and
                       @data[channel].buffer.length < @_getBufferSize(channel) and
                       same_params
                        @_flushChannelBuffer(channel)
                    else
                        # If we have to do a fresh fetch from the server,
                        # empty the existing buffer first
                        if @_getBufferSize(channel) > 0
                            @data[channel].buffer.reset([])
                        @_fetchChannelDataFromServer(channel)
                        @_setupPeriodicRefresh(channel)

        _channelHasFixture: (name) ->
            ###
                Check if channel has a fixture
            ###
            base_type = @meta_data[name].type
            return base_type[1..] of Fixtures

        _fixtureMatchesParams: (item, params) ->
            ###
                Determines if a fixture item matches the given parameters:
                 * {gender: 'm'} => item.gender == 'm'
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

                resource_type = @_getType(name)
                if resource_type == 'relational'
                    added = 0
                    for fixture_item in model_fixtures
                        fixture_item.id += id_offset
                        # Check if the fixtured item matches the given parameters
                        if @_fixtureMatchesParams(fixture_item, params)
                            added = added + 1
                            model = new collection_instance.model(fixture_item)
                            if add_instead_of_push
                                collection_instance.add(model)
                            else
                                collection_instance.push(model)
                    logger.info("Added #{added} fixtured items to channel #{name}")
                else if resource_type == 'api'
                    collection_instance.data = model_fixtures
                    logger.info("Added fixtures to channel #{name}")

        destroy: ->
            logger.info "Destroying data source"

    return DataSource
