define [], () ->
    class Module
        ###
            Base Mozaic module

            Its only current function is to wrap all of its methods
            into an anonymous function that catches all thrown
            exceptions. The caught execptions are handled in
            conformity with the application settings. @see #_wrapMethod

            Note: it cannot be defined as `module` because
            require.js already has an internal module with that
            name.
        ###

        constructor: ->
            @_bindMethodsFromMixins()
            @_wrapInstance()

        initialize: ->

        destroy: ->

        _bindMethodsFromMixins: =>
            ###
                Binds methods coming in from mixins.
            ###
            for k, v of this
                if _.isFunction(v) and v.fromMixin? and v.fromMixin
                    @[k] = _.bind(v, this)

        _wrapInstance: =>
            ###
                Wrap instance object with an error handler that
                prevents the interpreter from stopping execution
                completely on uncaught errors.
            ###
            for key of this
                member = @[key]
                # Make sure member is a function that has not already
                # been wrapped
                if _.isFunction(member) and not member.__wrapped__
                    @[key] = @_wrapMethod(this, member)

        _wrapMethod: (instance, method) =>
            ###
                Pass own instance reference instead of using the
                fat arrow to prevent from creating two new functions
                with every wrapped one.
            ###
            # Mark method as wrapped
            method.__wrapped__ = true
            return () ->
                if App.general.THROW_UNCAUGHT_EXCEPTIONS
                    # Let any possible uncaught exception run its course
                    result = method.apply(instance, arguments)
                else
                    # Catch any thrown exceptions from within the wrapper
                    # method, but throw it back again if it happens to be
                    # an authentication exception (aka _unauthorized_)
                    try
                        result = method.apply(instance, arguments)
                    catch error
                        if error.message == '__UNAUTHORIZED__'
                            throw error
                        # Log all caught errors
                        logger.error error
                return result

        @includeMixin: (klass) ->
            ###
                Mix-in functionality right in your Mozaic core, mister!

                This is very useful when you want to break a large component
                into multiple smaller pieces.
            ###
            for key, value of klass::
                # Assign properties to the prototype
                @::[key] = value
                @::[key].fromMixin = true

            # This one is for Ovidiu, so that we don't do return MyClass
            # for classes with mixins enabled :)
            return this