define [], () ->
    time =
        now: () ->
            return Math.round(new Date().getTime() / 1000)

        timeago: (elem, interval) ->
            ###
                Can receive any element which has a timestamp in
                `data-timestamp` attribute and updates the element
                text every `interval` seconds
                Used for mentions list
            ###
            return setInterval( ->
                    $(elem).each (idx, el) ->
                        $el = $(el)
                        published = $el.data('timestamp') * 1000
                        $(el).text(moment.timeago(published))
                interval*1000
            )

        # The timezone is a string like so 'America/New_York'
        #
        # Check if user has set a timezone in settings. Else,
        # detect the timezone in his browser with jstz.
        getUserTimezone: ->
            return window.user.timezone or jstz.determine().name()

        # This offset represents the seconds away from UTC.
        #
        # Return the server-side returned offset if a specific
        # location is set in settings. Else if (Automatically
        # detected) is set, get the current geo-location from browser.
        getUserTimezoneOffset: ->
            if window.user.timezone
                -window.user.timezone_offset
            else
                new Date().getTimezoneOffset() * 60

        # Get local timestamp (epoch time) from a date of the accepted formats
        # for Date(). E.g. for utc_date = "2012-07-25 17:00", the utc_ts would be
        # 1343235600. Check out here http://www.epochconverter.com
        #
        # Returns number of milliseconds in Epoch Time.
        getTimestampFromUTCDate: (date) ->
            return unless date
            # Append GMT to date string to tell Date this is GMT.
            date += ' GMT' if date.indexOf('GMT') == -1

            d = new Date(date)
            unless d.toString() == 'Invalid date'
                return d.getTime()

        getUTCTimestamp: ->
            return new Date().getTime()

        # The idea here is that Date() gets GMT +3 for romania, but I may be
        # in New_York so $date = $local + (- 3) - Utils.offset (-04 for NY) and thus
        # $date = $local - 3 - (- (-4)) // here window.user.tz_offset = -4
        #       = $local - 3 - 4 = NY local time
        # (The add/substract are actually done in seconds, not hours as above)
        #
        # Get the local time date. Do this by going to GMT from
        # browser timezone, and then go to the user's timezone.
        getLocalDate: ->
            if window.user.timezone
                d = new Date
                utc_ts = d.getTime() / 1000.0 + d.getTimezoneOffset() * 60
                user_ts = utc_ts - Utils.getUserTimezoneOffset()
                new Date(user_ts * 1000)
            else
                # We automatically detect the timezone. Date() already
                # does this for us.
                new Date()

    return time