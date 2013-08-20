define [], () ->
    class PubSub
        ###
            Communication backbone between the Mozaic components.

            Basically, the main Mozaic components such as datasource,
            widgets and controllers are completely decoupled and communicate
            through a pub-sub model.

            This contains a breakage of a component to a part of the system.

            Since we no longer wanted to have two event emitters in Mozaic,
            pubsub runs now on Backbone.Event, merely mentaining its previous
            publish/subscribe interface
        ###
        initialize: ->
            logger.info "Initializing PubSub"

        destroy: ->
            logger.info "Destroying PubSub"

        subscribe: ->
            ###
                Alias for BackboneEvents.on
            ###
            @on(arguments...)

        publish: ->
            ###
                Alias for BackboneEvents.trigger
            ###
            @trigger(arguments...)

        unsubscribe: ->
            ###
                Alias for BackboneEvents.off
            ###
            @off(arguments...)

    # PubSub is 100% powered by the Backbone.Events mixin
    _.extend(PubSub.prototype, Backbone.Events)

    # Make sure to return the PubSub Class
    return PubSub
