define [], () ->

    class ListSortingMixin

        # A list of comparators for list. You can also push to
        # this list and define your own comparator in your type
        # of list.
        _comparators_map:
            str: 'strComparator'
            int: 'intComparator'
            float: 'floatComparator'
            date: 'dateComparator'
            bool: 'boolComparator'

        registerComparator: (key, comparator) ->
            ###
                Adds a comparator to the current list instance.
                @param {String} key
                @param {string} comparator - name of the method to be used as comparator
            ###
            unless _.isString(key) and _.isString(comparator)
                throw new Error "params `key` and `comparator` must both be strings"
            unless _.isFunction @[comparator]
                throw new Error "this.#{comparator} is not a function"
            @_comparators_map[key] = comparator

        _parseSortByParameter: ->
            # Make sure that sort_by is actually a dict
            # with keys as filtering criteria and values as
            # comparator types ('str' and 'int' supported so far).
            # So, if I want to filter by folder_id first, which is an
            # int folder, and by name afterwards, I would give it
            # {folder_id: 'int', name: 'str'}
            if @sort_by?
                if $.isArray(@sort_by)
                    new_sort_by = {}
                    for field in @sort_by
                        new_sort_by[field] = 'str'
                    @sort_by = new_sort_by
                else if (not $.isPlainObject(@sort_by))
                    field = @sort_by
                    @sort_by = {}
                    @sort_by[field] = 'str'

        compare: (a, b) ->
            ###
                Goes through each @sort_by field until it finds difference
                between models. By default the order is ascending.

                One can give the following sort_by syntax:
                sort_by:
                    'pub_date desc': 'date'
                By default, sorting is 'asc'.

                The compare supports multiple fields of comparation, and
                in case of a tie, it goes comparint to the next field.
            ###
            for field, comparator of @sort_by
                # Set ascending as default order
                ascending = true

                # Search if order (asc/desc) is specified. Make sure field is
                # string.
                tokens = (""+field).split(' ')
                if tokens.length is 2
                    field = tokens[0]
                    switch tokens[1]
                        when 'asc' then ascending = true
                        when 'desc' then ascending = false
                        else ascending = true

                comparisonResult = @compareByField(a, b, field, comparator)
                # Return only if difference found, else continue
                # ordering by the next sort_by option.
                unless comparisonResult is 0
                    return if ascending then comparisonResult else -comparisonResult

            return 0

        compareByField: (a, b, field, comparator) ->
            ###
                Compares two models a and b with the criteria given by
                field. Follows the normal comparator convention and returns
                the equivalent of a - b, that is:
                -1, if a < b
                0, if a == b
                1, if a > b
            ###
            va = Utils.getAttributeFromModel(a, field)
            vb = Utils.getAttributeFromModel(b, field)
            # Get the comparison function, defined in COMPARATORS_MAP
            # constant above.
            f = @[ @_comparators_map[comparator] ]
            return f(va, vb)

        intComparator: (a, b) ->
            a = parseInt(a, 10)
            b = parseInt(b, 10)
            a - b

        floatComparator: (a, b) ->
            a = parseFloat(a, 10)
            b = parseFloat(b, 10)
            a - b

        strComparator: (a, b) ->
            a = _.str.trim (a).toLowerCase()
            b = _.str.trim (b).toLowerCase()
            return -1 if a < b
            return 1 if a > b
            return 0

        boolComparator: (a, b) ->
            a = Boolean(a)
            b = Boolean(b)
            return -1 if b and not a
            return 1 if a and not b
            return 0

        dateComparator: (a, b) ->
            ###
                If you are comparing two dates that
                momentjs does not support, you should
                override this comparator and define
                your own format.
            ###
            f = Utils.getUTCTimestampFromDate
            return f(a) - f(b)

        getSortByFields: ->
            fields = []
            for field, comparator of @sort_by
                # Make sure field is a string, and get the
                # field part of it (first part).
                field = (""+field).split(' ')[0]
                fields.push(field)
            fields