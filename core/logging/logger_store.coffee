###
    A buffer for all your logs to-be-sent to server. Features:

    - control over the amount of memory the logs use (avoid filling up
      your client's memory in case of massive errors)

    - control over the throughput of logs to server (avoid filling up the
      bandwidth in case of a storm of errors)
###
define [], ->
    class LoggerStore
        ### flush chunk size (in KB)
            Apache 2.0, 2.2: 8K
            nginx: 4K - 8K
            IIS: varies by version, 8K - 16K
            Tomcat: varies by version, 8K - 48K (?!)
            these values are actually entire headers size
        ###
        MAX_LOGS_PER_REQUEST: 4 # kb

        # Don't occupy more than LOG_MEGABYTES memory on your client
        MAX_LOGS_CLIENT_SIDE: 1024 # kb

        constructor: () ->
            @_logger_store = []
             # Approximation of the logger store size, in bytes
            @_logger_store_size = 0

        _sizeof: (log_entry) ->
            # Attempt to estimate the size of log_entry after serialization. 
            # We cannot send requests larger than 8k to tasty so we must calculate how many logs we can send.
            # Because of the way django parses error logs, we need to send javascript objects json'ed twice. 
            # That's why, to estimate the size of a serialized log_entry we apply JSON.stringify twice.

            try
                # Provide a hard-coded log size for the weird times when
                # JSON.stringify fails. Be careful not to log these errors.
                stringified = JSON.stringify JSON.stringify log_entry
                if stringified? and _.isString stringified
                    return stringified.length
                else
                    return 200
            catch error
                return 200

        _push_item: (log_entry) =>
            ###
                Add a new item to the logger store
            ###
            @_logger_store.push(log_entry)
            @_logger_store_size += @_sizeof(log_entry)

        _retrieve_item: =>
            ###
                Retrieve an item from the logger store
            ###
            item = @_logger_store.shift()
            @logger_store_size -= @_sizeof(item)
            return item

        _evict_item: =>
            ###
                Evict an item from the logger store
            ###
            @_retrieve_item()

        items_left: =>
            ###
                How many items are there left in the logger store?
            ###
            return @_logger_store.length

        _occupied_memory: =>
            ###
                How much memory is occupied by the logger store?
            ###
            return @_logger_store_size

        retrieve_available_logs: (maxSize) =>
            ###
                Retrieve as many log entries that fit into MAX_LOGS_PER_REQUEST kilobytes.
                This limitation is due to header size having a cap in webservers.

                We use a rough approximation, the length of JSON.stringify
                for each log item. The sum of these guys should be more
                than the length of JSON.stringify of the whole array.

                @param {Number} maxSize Optional - number of kilobytes of logs to send to the server 
                                                   Defaults to @MAX_LOGS_PER_REQUESTS
                @return {String|undefined} - returns the serialized logs to be attached directly to the headers
                                             or undefined when no logs are stored.
            ###

            max_bytes = (if _.isNumber(maxSize) then maxSize else @MAX_LOGS_PER_REQUEST) * 1024
            current_bytes = 0
            retrieved_logs = []

            while true # simulate a do..while loop
                new_entry = @_retrieve_item()
                current_bytes += @_sizeof(new_entry)
                retrieved_logs.push(new_entry) if new_entry? # Could be undefined if the store is an empty array.
                break unless @items_left() > 0 and current_bytes < max_bytes

            return JSON.stringify(retrieved_logs) if retrieved_logs.length > 0

        store: (level, msg = '', stack_trace = '') =>
            ###
                Store a given log message, together with its log level
                (read: importance) and an optional stack trace.
            ###
            # If somehow due to a weird reason someone tries to send
            # an empty message, then drop it right here before storing it.
            if not msg or msg.length == 0
                return

            # Form the log entry for this message
            entry = {l: level, m: msg}
            if stack_trace.length > 0
                entry.t = stack_trace

            # Evict items if necessary until we make room for the new log entry.
            #
            # NOTE: we might need to evict more than 1 item in order to make,
            # as the size of the entry might be big (especially if it has
            # a stack-trace within).
            entry_size = @_sizeof(entry)
            max_size = @MAX_LOGS_CLIENT_SIDE * 1024
            while entry_size + @_occupied_memory() >= max_size
                @_evict_item()

            # Finally store the entry
            @_push_item(entry)