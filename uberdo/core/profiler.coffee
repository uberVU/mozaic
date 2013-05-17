# This module is a direct port of YUI.Profiler utility.
# This version of the module removes dependency on YUI.Core,
# however it requires Underscore.js
# It was initially generated using http://js2coffee.org then modified to work.
#
# See this page for documentation http://yuilibrary.com/yui/docs/profiler/
#
# YUI 3.6.0 (build 5521)
# Copyright 2012 Yahoo! Inc. All rights reserved.
# Licensed under the BSD License.
# http://yuilibrary.com/license/

define [], () ->

    ###
        The YUI JavaScript profiler.
        @module profiler
    ###

    #-------------------------------------------------------------------------
    # Private Variables and Functions
    #-------------------------------------------------------------------------
    #Container object on which to put the original unprofiled methods.
    #Profiling information for functions
    #Additional stopwatch information


    #shortcuts
    container = {}
    report = {}
    stopwatches = {}
    WATCH_STARTED = 0
    WATCH_STOPPED = 1
    WATCH_PAUSED = 2


    createReport = (name) ->
        ###
            Creates a report object with the given name.
            @param {String} name The name to store for the report object.
            @return {Void}
            @method createReport
            @private
        ###
        report[name] =
            calls: 0
            max: 0
            min: 0
            avg: 0
            points: []

        report[name]



    saveDataPoint = (name, duration) ->
        ###
            (intentionally not documented)
            Called when a method ends execution. Marks the start and end time of the
            method so it can calculate how long the function took to execute. Also
            updates min/max/avg calculations for the function.
            @param {String} name The name of the function to mark as stopped.
            @param {int} duration The number of milliseconds it took the function to
                       execute.
            @return {Void}
            @method saveDataPoint
            @private
            @static
        ###

        #get the function data
        functionData = report[name] #:Object

        #just in case clear() was called
        functionData = createReport(name)    unless functionData

        #increment the calls
        functionData.calls++
        functionData.points.push duration

        #if it's already been called at least once, do more complex calculations
        if functionData.calls > 1
            functionData.avg = ((functionData.avg * (functionData.calls - 1)) + duration) / functionData.calls
            functionData.min = Math.min(functionData.min, duration)
            functionData.max = Math.max(functionData.max, duration)
        else
            functionData.avg = duration
            functionData.min = duration
            functionData.max = duration


    #-------------------------------------------------------------------------
    # Public Interface
    #-------------------------------------------------------------------------

    ###
        Profiles functions in JavaScript.
        @class Profiler
        @static
    ###
    class Profiler

        initialize: ->

        #-------------------------------------------------------------------------
        # Utility Methods
        #-------------------------------------------------------------------------

        clear: (name) ->
            ###
                Removes all report data from the profiler.
                @param {String} name (Optional) The name of the report to clear. If
                omitted, then all report data is cleared.
                @return {Void}
                @method clear
                @static
            ###
            if _.isString(name)
                delete report[name]

                delete stopwatches[name]
            else
                report = {}
                stopwatches = {}


        getOriginal: (name) ->
            ###
                Returns the uninstrumented version of a function/object.
                @param {String} name The name of the function/object to retrieve.
                @return {Function|Object} The uninstrumented version of a function/object.
                @method getOriginal
                @static
            ###
            container[name]



        instrument: (name, method) ->
            ###
                Instruments a method to have profiling calls.
                @param {String} name The name of the report for the function.
                @param {Function} method The function to instrument.
                @return {Function} An instrumented version of the function.
                @method instrument
                @static
            ###

            #create instrumented version of function
            newMethod = ->
                start = new Date()
                retval = method.apply(this, arguments_)
                stop = new Date()
                saveDataPoint name, stop - start
                retval


            #copy the function properties over
            _.extend newMethod, method

            #assign prototype and flag as being profiled
            newMethod.__yuiProfiled = true
            newMethod:: = method::

            #store original method
            container[name] = method
            container[name].__yuiFuncName = name

            #create the report
            createReport name

            #return the new method
            newMethod


        #-------------------------------------------------------------------------
        # Stopwatch Methods
        #-------------------------------------------------------------------------

        pause: (name) ->
            ###
                Pauses profiling information for a given name.
                @param {String} name The name of the data point.
                @return {Void}
                @method pause
                @static
            ###
            now = new Date()
            stopwatch = stopwatches[name]
            if stopwatch and stopwatch.state is WATCH_STARTED
                stopwatch.total += (now - stopwatch.start)
                stopwatch.start = 0
                stopwatch.state = WATCH_PAUSED


        start: (name) ->
            ###
                Start profiling information for a given name. The name cannot be the name
                of a registered function or object. This is used to start timing for a
                particular block of code rather than instrumenting the entire function.
                @param {String} name The name of the data point.
                @return {Void}
                @method start
                @static
            ###
            if container[name]
                throw new Error("Cannot use '" + name + "' for profiling through start(), name is already in use.")
            else

                #create report if necessary
                createReport name    unless report[name]

                #create stopwatch object if necessary
                unless stopwatches[name]
                    stopwatches[name] =
                        state: WATCH_STOPPED
                        start: 0
                        total: 0
                if stopwatches[name].state is WATCH_STOPPED
                    stopwatches[name].state = WATCH_STARTED
                    stopwatches[name].start = new Date()


        stop: (name) ->
            ###
                Stops profiling information for a given name.
                @param {String} name The name of the data point.
                @return {Void}
                @method stop
                @static
            ###
            now = new Date()
            stopwatch = stopwatches[name]
            if stopwatch
                if stopwatch.state is WATCH_STARTED
                    saveDataPoint name, stopwatch.total + (now - stopwatch.start)
                else saveDataPoint name, stopwatch.total    if stopwatch.state is WATCH_PAUSED

                #reset stopwatch information
                stopwatch.start = 0
                stopwatch.total = 0
                stopwatch.state = WATCH_STOPPED


        #-------------------------------------------------------------------------
        # Reporting Methods
        #-------------------------------------------------------------------------

        getAverage: (name) ->
            ###
                Returns the average amount of time (in milliseconds) that the function
                with the given name takes to execute.
                @param {String} name The name of the function whose data should be returned.
                If an object type method, it should be 'constructor.prototype.methodName';
                a normal object method would just be 'object.methodName'.
                @return {float} The average time it takes the function to execute.
                @method getAverage
                @static
            ###
            report[name].avg


        getCallCount: (name) ->
            ###
                Returns the number of times that the given function has been called.
                @param {String} name The name of the function whose data should be returned.
                @return {int} The number of times the function was called.
                @method getCallCount
                @static
            ###
            report[name].calls


        getMax: (name) ->
            ###
                Returns the maximum amount of time (in milliseconds) that the function
                with the given name takes to execute.
                @param {String} name The name of the function whose data should be returned.
                If an object type method, it should be 'constructor.prototype.methodName';
                a normal object method would just be 'object.methodName'.
                @return {float} The maximum time it takes the function to execute.
                @method getMax
                @static
            ###
            report[name].max


        getMin: (name) ->
            ###
                Returns the minimum amount of time (in milliseconds) that the function
                with the given name takes to execute.
                @param {String} name The name of the function whose data should be returned.
                If an object type method, it should be 'constructor.prototype.methodName';
                a normal object method would just be 'object.methodName'.
                @return {float} The minimum time it takes the function to execute.
                @method getMin
                @static
            ###
            report[name].min


        getFunctionReport: (name) ->
            ###
                Returns an object containing profiling data for a single function.
                The object has an entry for min, max, avg, calls, and points).
                @return {Object} An object containing profile data for a given function.
                @method getFunctionReport
                @static
                @deprecated Use getReport() instead.
            ###
            report[name]


        getReport: (name) ->
            ###
                Returns an object containing profiling data for a single function.
                The object has an entry for min, max, avg, calls, and points).
                @return {Object} An object containing profile data for a given function.
                @method getReport
                @static
            ###
            report[name]


        getFullReport: (filter) ->
            ###
                Returns an object containing profiling data for all of the functions
                that were profiled. The object has an entry for each function and
                returns all information (min, max, average, calls, etc.) for each
                function.
                @return {Object} An object containing all profile data.
                @method getFullReport
                @static
            ###
            filter = filter or ->
                true

            if _.isFunction(filter)
                fullReport = {}
                for name of report
                    fullReport[name] = report[name]    if filter(report[name])
                fullReport


        #-------------------------------------------------------------------------
        # Profiling Methods
        #-------------------------------------------------------------------------

        registerConstructor: (name, owner) ->
            ###
                Sets up a constructor for profiling, including all properties and methods on the prototype.
                @param {string} name The fully-qualified name of the function including namespace information.
                @param {Object} owner (Optional) The object that owns the function (namespace or containing object).
                @return {Void}
                @method registerConstructor
                @static
            ###
            @registerFunction name, owner, true


        registerFunction: (name, owner, registerPrototype) ->
            ###
                Sets up a function for profiling. It essentially overwrites the function with one
                that has instrumentation data. This method also creates an entry for the function
                in the profile report. The original function is stored on the container object.
                @param {String} name The full name of the function including namespacing. This
                is the name of the function that is stored in the report.
                @param {Object} owner (Optional) The object that owns the function. If the function
                isn't global then this argument is required. This could be the namespace that
                the function belongs to or the object on which it's
                a method.
                @param {Boolean} registerPrototype (Optional) Indicates that the prototype should
                also be instrumented. Setting to true has the same effect as calling
                registerConstructor().
                @return {Void}
                @method registerFunction
                @static
            ###

            #figure out the function name without namespacing
            funcName = ((if name.indexOf(".") > -1 then name.substring(name.lastIndexOf(".") + 1) else name))
            method = undefined
            prototype = undefined

            #if owner isn't an object, try to find it from the name
            owner = eval_(name.substring(0, name.lastIndexOf(".")))    unless _.isObject(owner)

            #get the method and prototype
            method = owner[funcName]
            prototype = method::

            #see if the method has already been registered
            if _.isFunction(method) and not method.__yuiProfiled

                #replace the function with the profiling one
                owner[funcName] = @instrument(name, method)

                # Store original function information. We store the actual
                # function as well as the owner and the name used to identify
                # the function so it can be restored later.
                container[name].__yuiOwner = owner
                container[name].__yuiFuncName = funcName #overwrite with less-specific name

                #register prototype if necessary
                @registerObject name + ".prototype", prototype    if registerPrototype


        registerObject: (name, object, recurse) ->
            ###
                Sets up an object for profiling. It takes the object and looks for functions.
                When a function is found, registerMethod() is called on it. If set to recrusive
                mode, it will also setup objects found inside of this object for profiling,
                using the same methodology.
                @param {String} name The name of the object to profile (shows up in report).
                @param {Object} owner (Optional) The object represented by the name.
                @param {Boolean} recurse (Optional) Determines if subobject methods are also profiled.
                @return {Void}
                @method registerObject
                @static
            ###

            #get the object
            object = ((if _.isObject(object) then object else eval_(name)))

            #save the object
            container[name] = object
            for prop of object
                if typeof object[prop] is "function"
                    #don't do constructor or superclass, it's recursive
                    @registerFunction name + "." + prop, object    if prop isnt "constructor" and prop isnt "superclass"
                else @registerObject name + "." + prop, object[prop], recurse    if typeof object[prop] is "object" and recurse


        unregisterConstructor: (name) ->
            ###
                Removes a constructor function from profiling. Reverses the registerConstructor() method.
                @param {String} name The full name of the function including namespacing. This
                is the name of the function that is stored in the report.
                @return {Void}
                @method unregisterFunction
                @static
            ###

            #see if the method has been registered
            @unregisterFunction name, true    if _.isFunction(container[name])


        unregisterFunction: (name, unregisterPrototype) ->
            ###
                Removes function from profiling. Reverses the registerFunction() method.
                @param {String} name The full name of the function including namespacing. This
                is the name of the function that is stored in the report.
                @return {Void}
                @method unregisterFunction
                @static
            ###

            #see if the method has been registered
            if _.isFunction(container[name])

                #check to see if you should unregister the prototype
                @unregisterObject name + ".prototype", container[name]::    if unregisterPrototype

                #get original data
                owner = container[name].__yuiOwner #:Object
                funcName = container[name].__yuiFuncName #:String

                #delete extra information
                delete container[name].__yuiOwner

                delete container[name].__yuiFuncName


                #replace instrumented function
                owner[funcName] = container[name]

                #delete supporting information
                delete container[name]


        unregisterObject: (name, recurse) ->
            ###
                Unregisters an object for profiling. It takes the object and looks for functions.
                When a function is found, unregisterMethod() is called on it. If set to recrusive
                mode, it will also unregister objects found inside of this object,
                using the same methodology.
                @param {String} name The name of the object to unregister.
                @param {Boolean} recurse (Optional) Determines if subobject methods should also be
                unregistered.
                @return {Void}
                @method unregisterObject
                @static
            ###
            if _.isObject(container[name])
                object = container[name]
                for prop of object
                    if typeof object[prop] is "function"
                        @unregisterFunction name + "." + prop
                    else @unregisterObject name + "." + prop, recurse    if typeof object[prop] is "object" and recurse
                delete container[name]


        topSlowestWidgets: (count) ->
            ###
                Method sorts the widgets by the slowest time to render
                @param {Number} count - if set it outputs only the first <count> slowest widgets
                @return {Array}
            ###

            top = _.chain(@getFullReport())
                .map (metrics, widgetName) ->
                    metrics.widgetName = widgetName
                    return metrics
                .sortBy (metrics, widgetName) ->
                    - metrics.max
                .value()

            count = count ? top.length
            top.slice 0, count


    return Profiler
