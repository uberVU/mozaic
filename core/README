*************************
* CHANNEL CONFIGURATION *
*************************

App.DataSourceConfig.channel_types is a dictionary mapping channel names to
channel config options. These options are explained below:

    type: 'relational' or 'api'
    url: where to fetch data from (via Backbone.Collection.fetch)
    collection: the Backbone collection to use for this channel

    refresh: 'periodic', 'backoff' or undefined
        Sets the refreshing policy:
         * periodic -> refresh channel every refresh_interval ms
         * backoff -> like periodic, but also applies an exponential backoff
           when no new items are discovered via refreshing (x2, x4, x8, etc)
    refresh_interval:
        Refresh frequency, in miliseconds (used only when refresh='periodic').
    max_refresh_interval:
        Maximum refresh interval, in miliseconds (used only when
        refresh='backoff'). Defaults to 10 x refresh_interval.
    refresh_type: 'refresh' (default), 'streampoll' or 'scroll'
        What should happen when the channel is refreshed (used only when
        refresh='periodic'):
         * refresh (default) -> the entire channel is refreshed
         * streampoll -> check for new items (see Streampoll section below)
         * scroll -> the channel is scrolled down (makes little sense to
           have this as a periodic refresh, but it works)

    buffer_size: undefined (default) or number (e.g.: 100)
        Used only when refresh_type='streampoll' - the buffer size (if number),
        or no buffer (if undefined).

    scroll_params:
        A (data, params) -> params function that returns the url params needed
        to "scroll" the channel down.

    streampoll_params:
        A (data, params) -> params function that returns the url params needed
        to "streampoll" the channel up (check for new items).
        IMPORTANT - returning null (or anything that evaluates to false)
        will stop the current streampoll event!

*** Streampoll ***

Most channels have items that are sorted by a time attribute (e.g.: published,
since_id, etc.) and their corresponding apicalls support time filtering by
those attributes (e.g.: ?since=1338301000). New items appear in these
datasources in increasing order, you could imagine these channels as "streams".

In those cases, it is possible to configure channels to periodically check
their datasources for new (fresh) items. This check is called a "streampoll"
event/request.

When new items are found via a "streampoll" event, two outcomes are possible:
 1) insert the new items directly in the channel's data (buffer_size=null)
 2) keep the new items in the channel's buffer (buffer_size=100);
    triggering a "/refresh" will cause the buffer to be flushed
    into the channel's data, iff it is NOT full (if it is full, a simple
    refresh will be performed)

WARNING! If you set buffer_size to null and the channel has a lot of new items,
a gap might appear in your data: because each streampoll event only fetches
a single apicall, if the new (fresh) items cannot fit into a single apicall,
then not all new items will be added to the channel data. In order to overcome
this, multiple apicalls would be needed and this was not implemented (nor is
it scheduled).
