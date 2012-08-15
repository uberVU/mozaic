define [], () ->
    ContextProcessors =
        processors: {}

        register: (name, callback) ->
            if not $.isFunction(callback)
                return
            ContextProcessors.processors[name] = callback

        process: (name, params...) ->
            if not (name of ContextProcessors.processors)
                return
            list = ContextProcessors.processors[name](params...)

    window.ContextProcessors = ContextProcessors
    return ContextProcessors