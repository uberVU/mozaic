define [], () ->
    class Module
        ###
            Base Mozaic module

            Wraps all of its methods
            into an anonymous function that catches all thrown
            exceptions. The caught execptions are handled in
            conformity with the application settings. @see #_wrapMethod

            Allows child classes to add mixins to their prototypes, using
            the `@includeMixin()` static method.

            Allows for easy inheritance of class properties using
            `@extendHash()` static method.

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
                    # Mark wrapper method
                    @[key].__wrapped__ = true

        _wrapMethod: (instance, method) =>
            ###
                Pass own instance reference instead of using the
                fat arrow to prevent from creating two new functions
                with every wrapped one.
            ###
            return () ->
                if App.general.PASS_THROUGH_EXCEPTIONS
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


        @extendProperty: (property, extensions) ->
            ###
                Defines a hash of values that will extend those of the
                prototype property with the same name. If the property is not
                defined, then this method will set it, so you can use it to
                set prototype properties as well.

                @param {String} property - the name of the prototype property
                        to create/extend. Ex: subscribed_channels, events, etc.
                @param {Object} extensions - the values to be appended to the
                        existing prototype property.

                Note! Currently only one-level deep extends are supported.
            ###
            @::[property] = _.extend {}, @::[property], extensions
