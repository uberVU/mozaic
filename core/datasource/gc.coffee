define [], () ->

    class DataSourceGCMixin
        ###
            Includes a method for garbage collect channels when they
            are no longer used
        ###

        checkForUnusedCollections: ->
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
                reference = @reference_data[collection]

                # Eternal collections are never expired
                if meta.eternal
                    continue

                # If this collection still has references attached, so skip it.
                if reference['time_of_reference_expiry'] == null
                    continue

                # Channels with pending fetches should not be garbage collected
                if 'waiting_fetches' of meta and meta.waiting_fetches > 0
                    continue

                # Check if the current collection has had
                # 0 reference count for quite a while.
                expired_for = (new Date).getTime() - reference['time_of_reference_expiry']
                if expired_for > @checkIntervalForUnusedCollections
                    # Declare that channel has expired loudly and openly.
                    logger.warn("#{collection} collection expired in DataSource.")
                    # Stop periodic refresh if it was enabled
                    @_stopRefreshing(collection)
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
