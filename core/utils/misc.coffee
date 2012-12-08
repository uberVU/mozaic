define [], () ->
    misc =
        padNumber: (nr, length = 2) ->
            ###
                Prepend number with zeros.
                Example:

                    Utils.padNumber(15, 4) # returns "0015"
            ###
            nr = String(nr)
            return if nr.length < length then @padNumber("0#{nr}", length) else nr

    return misc
