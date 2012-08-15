###
    Collect all logs in this store
    Wraps around a list of log items in order to add
    - self-flushing to server
    - control over the amount of memory the logs use
    - control over the throughput of logs to server
###
define [], ->
    class LoggerStore
    
        ###
            flushed is set to true on every flush and set to false
            after (at most) FLUSH_INTERVAL seconds
            it enables server-side flushing of logs when time passes and no 
            other requests are made to the server
        ###
        flushed : false
    
        #forced flush interval
        FLUSH_INTERVAL : 50000
    
        ### flush chunk size (in KB)
            Apache 2.0, 2.2: 8K
            nginx: 4K - 8K
            IIS: varies by version, 8K - 16K
            Tomcat: varies by version, 8K - 48K (?!)
            these values are actually entire headers size
        ###
        FLUSH_SIZE : 4
    
        #log entry size in B, completely heuristical
        ENTRY_SIZE : 200
    
        LOG_MEGABYTES: 1
        
        #max numbers of log entries we want to store
        MAX_ENTRY_COUNT : 200
    
        #use this endpoint to force flushing of logs
        FLUSH_ENDPOINT : App.general.FRONTEND_URL + '/api/dump_logs'
    
        #the actual storage for logs
        _logger_store : []
    
        constructor: () ->
            
            #Set the max_entry_count to be aprox LOG_MEGABYTES
            @MAX_ENTRY_COUNT = (1024*1024/@ENTRY_SIZE) * @LOG_MEGABYTES
            
            #set the flush interval 
            #must pass anonymus function here to preserve closure
            setInterval ( => @flush_logs()), @FLUSH_INTERVAL

    
        get_available_logs: () =>
            ###
                Available logs are the ones we can send in one
                request without sending too much data over HTTP headers.
                We don't know the actual size our log store occupies
                we will use a heuristic and retrieve a certain number of entries
                the entries are return as one JSON string
            ###
            entries_count = Math.floor(@FLUSH_SIZE * 1024 / @ENTRY_SIZE)
            available = @_logger_store.slice(0, entries_count) 
        
            #clean up the store; we don't need these logs any longer
            @_logger_store = @_logger_store.slice(entries_count)
        
            return JSON.stringify(available)
        
        flush_logs: () =>
            ###
                Send available logs to server via a bogus XHR request
                which will fore piggyback of available stuff
                NOTE: This really shouldn't be required since we make constant auth requests
            ###
            if not @flushed
                if @_logger_store.length > 0
                    #make XHR request to a special, logging endpoint
                    options = 
                        url: @FLUSH_ENDPOINT
                    params = 
                        type: 'GET'    
                    $.ajax(_.extend(params, options))
                    @flushed = true
            else
                #logs already flushed, waiting for next cylce or XHR request
                @flushed = false       
        
        store: (level, msg) ->
            ###
                enque logs for transmission once an XHR request is done
                TODO: throw out oldest entry, make it configurable
                TODO: transform this into a hash
            ###
            if @_logger_store.length < @MAX_ENTRY_COUNT
                @_logger_store.push({l:level, m:msg})
        
