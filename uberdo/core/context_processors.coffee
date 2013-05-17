define [], () ->
    ContextProcessors =
        processors: {}

        register: (name, callback) ->
            if not $.isFunction(callback)
                return
            ContextProcessors.processors[name] = callback

        process: (name, params...) ->
            ###
            # This function executes a previously registered context processor.
            # Context processors can have any number of params and they will be applied accordingly,
            # however conditional processors expect an options param as second argument
            #
            # @param {String} name Registred name of the context processor.
            # @param {Object} params[0] jQuery Object representing the DOM element modified by the processor.
            # @param {Object} params[1] Options hash, usefull for conditional processors in which case it looks for a params[1].condition.
            ###

            # If no such context processor is registred, return.
            if not (name of ContextProcessors.processors)
                return

            # Evaluate context processor condition.
            value = params[1]?.condition
            if value? then execute = !! (if $.isFunction value then value() else value) # `!!` casts to Boolean.
            else execute = true # Defaults to true.

            if execute
                list = ContextProcessors.processors[name](params...)

    window.ContextProcessors = ContextProcessors
    return ContextProcessors