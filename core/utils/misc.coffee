define [], () ->
    padNumber: (nr, length = 2) ->
        ###
            Prepend number with zeros.
            Example:

                Utils.padNumber(15, 4) # returns "0015"
        ###
        nr = String(nr)
        return if nr.length < length then @padNumber("0#{nr}", length) else nr

    human_count: (count) ->
        # Sanity check
        if not count
            return '0'

        # Over 10M
        if count >= 10000000
            return Math.round(count / 1000000) + 'M'

        # Between 1M and 10M
        if count >= 1000000 and count < 10000000
            return Math.round(count / 100000) / 10 + 'M'

        # Between 10K and 999K
        if count >= 10000 and count < 1000000
            return Math.round(count / 1000) + 'K'

        # Between 1K and 10K
        if count >= 1000 and count < 10000
            return Math.round(count / 100) / 10 + 'K'

        # Less than 1K
        if count < 1000
            return count

    wait: (timeout, callback) ->
        ###
            The setTimeout functionality exposed as a promise
            E.g. http://jsfiddle.net/uXTxC/
        ###
        deferred = $.Deferred()
        setTimeout ->
            callback()
            deferred.resolve()
        , timeout

        return deferred.promise()
