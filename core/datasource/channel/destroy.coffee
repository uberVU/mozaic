define ['cs!channels_utils'], (channels_utils) ->

    class DataSourceChannelDestroyMixin
        ###
            Includes methods to delete data from a datasource channel
        ###

        deleteFromDataChannel: (channel, options = {sync: true}) ->
            ###
                Delete an item from a channel. You can only delete
                from relational channels

                @param {String}         channel             The channel where objects should be removed
                @param {Object}         options
                @param {Boolean}        [options.sync]      Determine if the deletion should be sent to server
                @param {Object}         [options.filter]    Filter the objects to be deleted
            ###
            logger.info "Deleting data from #{channel} in DataSource"

            channel_type = @_getType(channels_utils.getChannelKey(channel))
            if channel_type == 'relational'
                @_deleteFromRelationalDataChannel(channel, options)
            else if channel_type == 'api'
                logger.error("Deleting from api channels is not supported")

        _deleteFromRelationalDataChannel: (channel, options) ->
            ###
                Delete a model from a Backbone collection. Calls
                destroy on the model if the change has to be synced with
                the server, otherwise removes the element from the
                collection
            ###
            # Split channel into it's components. Ignoring events
            [collection_name, item, events] = channels_utils.splitChannel(channel)

            collection = @data[channels_utils.formChannel(collection_name)]

            if item is "all"
                # This case will handle the situation when you want
                # to delete from collection by a filter
                unless options.filter? or _.isEmpty(options.filter)
                    logger.error("Deleting whole collection is not supported for
                                  relational collections")
                # All collections should extend base_collection (where filter_by is defined)
                filtered_models = collection.filter_by(options.filter)
            else
                filtered_models = [collection.get(item)]

            for model in filtered_models
                # If the destroy has to be synced with the server
                if options.sync
                    # Destroy the object
                    # http://documentcloud.github.com/backbone/#Model-destroy
                    model?.destroy({ wait: true })
                else
                    # Remove the object from it's collection
                    collection.remove(model)
