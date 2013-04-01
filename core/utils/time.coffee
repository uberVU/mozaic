define [], () ->
    time =
        now: () ->
            ###
                Returns now as unixtime/1000
            ###
            return Math.round(new Date().getTime() / 1000)

        today: () ->
            ###
                Returns today as Date object representing beginning of day
            ###
            now = new Date()
            return Utils.day(now)

        day: (date) ->
            ###
                Returns Date object representing beginning of day
            ###
            return new Date(date.getFullYear(), date.getMonth(), date.getDate())

        timeago: (elem, interval, callback) ->
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
                    # After timestamps were updated execute callback method if specified
                    callback() if callback?
                interval*1000
            )

        getUTCTimestampFromDate: (date, format = null) ->
            ###
                Get local timestamp (epoch time) from a date of the accepted formats
                for Date(). E.g. for utc_date = "2012-07-25 17:00", the utc_ts would be
                1343235600. Check out here http://www.epochconverter.com

                Returns number of milliseconds in Epoch Time.
            ###
            if $.isArray(format)
                format = format[0]
            moment.utc(date, format).unix() * 1000

        getUTCTimestamp: ->
            return new Date().getTime()

        getHourFromDate: (date) ->
            ###
                Get the hour formatted according to AM/PM modifiers from a
                0-24 clock. E.g. hour 23 is actually 11 PM
            ###
            hour = date.getHours()
            return hour - 12 if hour > 12
            # Special case for 0, which is 12 AM
            return 12 if hour is 0
            return hour

        getStandardHour: (hour, period) ->
            ###
                24-hour format from am/pm-based one
            ###
            hour = Number(hour)
            return (hour + 12) if period is 'pm' and hour isnt 12
            return 0 if period is 'am' and hour is 12
            return hour

        getPeriodFromDate: (date) ->
            ###
                Get an AM or PM period based on the hour
            ###
            return 'pm' if date.getHours() > 11
            return 'am'

        getHours: ->
            {value: nr, label: @padNumber(nr)} for nr in [1...13]

        getMinutes: ->
            {value: nr, label: @padNumber(nr)} for nr in [0...60]

        getTimestampFromDate: (date) ->
            return Math.round(new Date(date).getTime() / 1000)

        getDateFromTimestamp: (timestamp, format = 'MM/DD/YYYY') ->
            return moment(timestamp * 1000).format(format)

        getDateFromUTCTimestamp: (timestamp, format = 'MM/DD/YYYY') ->
            return moment.utc(timestamp * 1000).format(format)

        getDateFormat: (date, format = 'MM/DD/YYYY') ->
            return moment(date).format(format)

    return time

