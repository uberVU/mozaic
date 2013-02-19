define ['cs!tests/base_test', 'cs!collection/raw_data'], (BaseTest, RawData) ->

    class RawDataTests extends BaseTest
        testName: '[Collections] RawData'

        test_default_data: ->
            ###
                Set the default data of a RawData after creating it and check
                if it is returned getting its data, but also if it is ignored
                when calling it with default values disabled.
            ###
            collection = new RawData()

            defaultValues =
                Jager: 'rock'
                Elvis: 'roll'
            collection.setDefaultValue(defaultValues)

            ok(_.isEqual(collection.getData(), defaultValues),
               'RawData data should be default data')

            ok(_.isEmpty(collection.getData(false)),
               'RawData data should be empty if called w/out default values')

        test_empty_data: ->
            ###
                Check if the data of a newly created RawData with not
                attributes set is empty.
            ###
            collection = new RawData()

            ok(_.isEmpty(collection.getData()), 'RawData data should be empty')

        test_key_value_set: ->
            ###
                Set attributes to RawData one by one, and check if each of them
                are returned the same as when they were set, and if the entire
                RawData data set is equal to the initial poll of attributes.
            ###
            collection = new RawData()

            values =
                Jager: 'rock'
                Elvis: 'roll'

            for k, v of values
                collection.set(k, v)

            test = 'Individual attribute should be returned as set'
            for k, v of values
                ok(collection.get(k) is v, test)

            ok(_.isEqual(collection.getData(), values),
               'The entire data set should be identic to the one set')

        test_mass_set: ->
            ###
                Set attributes to RawData at once, and check if each of them
                are returned the same as when they were set, and if the entire
                RawData data set is equal to the initial poll of attributes.
            ###
            collection = new RawData()

            values =
                Jager: 'rock'
                Elvis: 'roll'
            collection.set(values)

            test = 'Individual attribute should be returned as set'
            for k, v of values
                ok(collection.get(k) is v, test)

            ok(_.isEqual(collection.getData(), values),
               'The entire data set should be identic to the one set')

        test_changed_attributes: ->
            ###
                Test more scenarios regarding the changed attributes of RawData

                    - that collection is marked as changed and with all new
                      attributes marked as changed after set
                    - same as #1, but with both new and already existing
                      attributes
                    - same as #1, but when removing attributes using unset
            ###
            collection = new RawData()

            # Add new attributes
            collection.on('change', (instance, changed) ->
                ok(not _.isEmpty(changed),
                   'Collection should be marked as changed inside reset event')

                for k, v of values
                    ok(changed[k] is v,
                      'Initial attribute should\'ve changed inside reset event')
            )
            values =
                Jager: 'rock'
                Elvis: 'roll'
            collection.set(values)
            collection.off('change')

            # Add one new attribute and change an existing one
            newValues =
                Madonna: 'pop'
                Elvis: 'rocknroll'
            collection.on('change', (instance, changed) ->
                ok(not _.isEmpty(changed),
                   'Collection should be marked as changed inside change event')

                for k, v of newValues
                    ok(changed[k] is v,
                      'New attribute should\'ve changed inside change event')
            )
            collection.set(newValues)
            collection.off('change')

            # Unset some attributes
            removedValues =
                Madonna: null
                Elvis: null
            collection.on('change', (instance, changed) ->
                ok(not _.isEmpty(changed),
                   'Collection should be marked as changed inside change event')

                for k, v of removedValues
                    ok(changed.hasOwnProperty(k) and changed[k] is undefined,
                      'Removed attribute should\'ve changed inside change event')
            )
            collection.unset(removedValues)
            collection.off('change')
