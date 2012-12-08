define [], () ->
    class FlagsCollection
        ###
            A collection of elements with flag behaviour
            Test cases are in tests/core/flags_collection_tests.coffee

            Typical use case:
                flags = new Flags(3,
                    deleted:
                        value: 1
                    admin:
                        value: 2
                    active:
                        value: 4
                )
                Because you initialized the collection with value 3 you have:
                    flags.deleted.is_set = true
                    flags.admin.is_set = true
                    flags.active.is_set = false

        ###
        constructor: (value, collection) ->
            @flags = collection
            _.extend(@, @flags)

            @setValue(value)

        setValue: (value) ->
            @value = value

            # Update each property is_set in the @flags collection
            _.each(@flags, (flag, key) =>
                flag.is_set = (value & flag.value) is flag.value
            )

        getValue: () ->
            value = 0
            # Re-evaluate the flags overall value after some sets/resets
            _.each(@flags, (flag, key) =>
                value += flag.value * (1 & flag.is_set)
            )
            return value

        setFlag: (flag_key, value) ->
            ###
                Set/reset a flag in the collection
            ###
            @[flag_key].is_set = value

    return FlagsCollection
