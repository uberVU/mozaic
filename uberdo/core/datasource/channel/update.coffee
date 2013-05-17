define ['cs!channels_utils'], (channels_utils) ->

    class DataSourceChannelUpdateMixin
        ###
            Includes methods to update data for a datasource channel and
            sync it with the server
        ###

        modifyDataChannel: (channel, dict, options = {}) ->
            ###
                Modifies the data found at channel by calling
                data.set(k, v) for each pair (k, v) of dict.

                @param {String}     channel                 The channel on which to modify objects
                @param {Object}     dict                    The dictionary of changes to be made
                @param {Object}     options
                @param {String}     [options.update_mode]   The update mode for this item. Possible values: 'append', 'reset', 'exclude'
                @param {Boolean}    [options.sync]          Determine whether we should sync the data with the server
                @param {Boolean}    [options.silent]        Determine whether we should silently update the model or not
                @param {Object}     [options.filter]        Filter the objects to be modified
            ###
            logger.info "Modifying data from #{channel} in DataSource"

            # Split the channel into its components and get the "id" part.
            item = channels_utils.splitChannel(channel)[1]
            channel_guid = channels_utils.getChannelKey(channel)

            unless @reference_data[channel_guid]?
                logger.warn("Couldn't modify data from channel #{channel_guid} " +
                            "because it was already removed")
                return

            resource_type = @_getType(channel)
            if resource_type == 'relational'
                if item == "all"
                    # Modifying the whole collection is not supported for Backbone collections
                    # Exception is made when a filter is passed in options
                    unless options.filter? or _.isEmpty(options.filter)
                        logger.error("Modifying the whole collection is not supported for
                                  relational collections")
                        return

                # Modify the channel_guid that we received the /modify on, doing sync only
                # for this one, if sync = true...
                @_findAndModifyRelationalChannelModel(channel_guid, item, dict, options)

                # ... Then go through all other channels and update
                # those of the same type with channel_guid containing the item.
                channel_type = @meta_data[channel_guid].type
                for other_channel_guid, other_channel_data of @meta_data
                    # Skip the original channel, we've already modified this one.
                    continue if channel_guid == other_channel_guid
                    if other_channel_data.type == channel_type
                        # Don't sync with server, we already sync'ed above.
                        @_findAndModifyRelationalChannelModel(other_channel_guid, item, dict, _.extend(options, {sync: false}))

            else if resource_type == 'api'
                # For raw data channels, we don't support individual model modifications.
                if item != "all"
                    logger.error("Modifying individual items is not supported for
                                  raw collections")
                    return
                @_modifyApiDataChannel(channel_guid, dict, options.update_mode)

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
                model.unset(dict)

        _findAndModifyRelationalChannelModel: (channel_guid, item, dict, options = {}) ->
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

            _.defaults(options, {sync: true, silent: false, filter: {}})
            collection = @data[channel_guid]

            filtered_models = if item is 'all' then collection.filter_by(options.filter) else [collection.get(item)]

            for individual_model in filtered_models
                @_findAndModifyCollectionModel(collection, individual_model, dict, options) if individual_model
            # Also look for item in buffer, and modify it if it exists.
            if @_getBufferSize(channel_guid)
                filtered_models_in_buffer = if item is 'all' then collection.buffer.filter_by(options.filter) else [collection.buffer.get(item)]
                for individual_model in filtered_models_in_buffer
                    @_findAndModifyCollectionModel(collection.buffer, individual_model, dict, _.extend(options, {sync: false})) if individual_model

        _findAndModifyCollectionModel: (collection, individual_model, dict, options) ->
            ###
                Modifies the individual_model passed in arguments.
            ###

            [update_mode, sync, silent] = [options.update_mode, options.sync, options.silent]

            # Clone the individual model and set it's urlRoot property
            # because the clone won't be part of the collection. This way
            # we have a proper model url
            cloned_model = individual_model.clone()
            cloned_model.urlRoot = collection.url
            cloned_model.collection = collection

            # Perform a save on the model and propagate any error events
            # received from the server on the model's channel. If the
            # save is successful update the collection's model (individual_model)
            # with the new values of the clone (this will trigger the change events
            # after the save is ok). Otherwise trigger the errors on the individual
            # model
            if sync
                # Update clone without triggering any change events (won't matter
                # though because the clone is not part of a collection)
                cloned_model = @_updateRelationModel(cloned_model, dict, update_mode)
                # Trigger a custom invalidate event before the
                # model is saved to the server. Backbone.Model emits
                # a sync event if the save was successful. The invalidate
                # event has the following signature:
                # 'invalidate', model, collection
                individual_model.trigger('invalidate', individual_model, collection)
                options =
                    error: (model, response, options) =>
                        individual_model.trigger('error', model, response)
                    success: (model, response) =>
                        # Update model with attributes to sync from response.
                        @syncModelWithResponse(model, response)
                        options = {'silent': silent}
                        individual_model.set(model.attributes, options)

                # Note: passing silent = true to this will only cause
                # the cloned model to be updated silently, which doesn't
                # matter anyway, because no widget ever knows about it.
                cloned_model.save(cloned_model.attributes, options)
            else
                # TODO: For consistency should we trigger invalidate here as well?
                # If we don't need to sync with the server we can just update
                # the model reference in the collection and now trigger
                # the change events
                @_updateRelationModel(individual_model, dict, update_mode, silent)

        _updateRelationModel: (model, dict, update_mode, silent = true) ->
            ###
                Update a provided model with the dict arguments bypassing
                events triggering using the silent argument.
            ###
            silence = { silent: silent }
            if update_mode == 'append'
                for k, v of dict
                    currentValue = model.get(k)
                    # If the attribute of the model is an array and the value
                    # set not, push it into that array instead of overwritting
                    if _.isArray(currentValue) and not _.isArray(v)
                        # Get current value first
                        value = _.clone(currentValue)
                        value.push(v)
                    else
                        value = v
                    model.set(k, value, silence)
            else if update_mode == 'reset'
                model.clear(silent)
                model.set(dict, silence)
            else if update_mode == 'exclude'
                for k of dict
                    if $.isPlainObject(k)
                        logger.error("Trying to unset a dictionary instead of a key")
                    model.unset(k, silence)
            return model
