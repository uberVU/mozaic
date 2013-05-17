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

    truncateByWords: (originalString, length, suffix = false) ->
        ###
            Truncate a string while making sure words aren't split in any way,
            especially important when truncating texts that contain links, that
            are they going to be converted in html anchors.

            The length of the resulted string might be a few chars smaller than
            the proposed length (depending on the word found on that position),
            but never longer
        ###
        # Remove any spaces at extremities
        originalString = _.str.trim(originalString)
        words = originalString.split(' ')
        truncatedString = ''
        for word, index in words
            # Add another space char between the next and the previous word if
            # it isn't the first (this helps the accuracy of the truncating,
            # because we're taking the space in consideration when checking the
            # length of the new word, as well)
            word = " #{word}" if index > 0
            proposedLength = truncatedString.length + word.length
            # We must only account for the length of the suffix if one is
            # specified and this isn't the last word (cause otherwise no
            # truncating would take place and the suffix wouldn't be required)
            if _.isString(suffix) and index < words.length - 1
                proposedLength += suffix.length
            if proposedLength <= length
                truncatedString += word
            else
                # At least one word must have made it in order to add the
                # suffix, otherwise it would be the suffix alone
                if _.isString(suffix) and truncatedString.length
                    truncatedString += suffix
                break
        return truncatedString
