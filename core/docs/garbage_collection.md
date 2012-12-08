  GC
  ==
  There are 3 main purposes to garbage collecting a widget:

  1) mark it as "detached from DOM"

    When a widget is marked as "detached", via the loader.mark_as_detached(guid)
    call, an internal flag is set which is then checked by widget's
    _translateEventParams. This will cause data-related events (reset/add/etc.)
    to STOP BEING PUMPED to the widget immediately.

    Why do we need this? Because "detached" widgets responding to data
    events are really dangerous. 2 examples:

    1.1) detached mediators are usually subscribed to the single global filters
         collection. This means that when filters change, they might end up
         making bogus AJAX requests, although they aren't in the page anymore.
         This was the famous case of changing from one stream to another
         resulting in the thousands of {{keyword_id}} errors.

    1.2) usually widgets respond to data events with some processing and
         a renderLayout() call. Google maps widgets used to crash on us
         very frequently due to the fact that they were trying to access pieces
         of the DOM which were not there anymore.

    Note that a widget cannot respond to DOM events while it is detached
    because the end-user cannot interact with it (!). So, theoretically, after
    it is marked as 'detached' from DOM, it should be mostly silent.

  2) do correct reference counting of channels in datasource

    When a widget is GC'ed, the destroy() method from widget.coffee
    will send a '/destroy_widget' message through the pub-sub, intended
    to be caught by the datasource. For each channel, the datasource does a +1
    when a widget subscribes to it (there is a similar message, called
    /new_widget), and it does a -1 when a widget which used to reference it
    is dead.

    When this 'reference count' of a channel was 0 for a period of time
    (currently 10s), and there are no 'waiting fetches', the channel itself
    is destroyed. (A waiting fetch is a pending fetch from the server which
    hasn't returned).

    This is why it's CRUCIAL for your widgets to call super.destroy()
    if they happen to override destroy().

  3) free up all the references to it and to its internal objects

    This one is obvious, especially if the widget is a wrapper around
    some Raphael/Highcharts fancy graphics. This will __free the reference__
    held by the widget to the graphics objects themselves and also call
    any destroy methods on these.

    Note: if you override destroy() in your widget, you should first
          do clean-up specific to your widget and only afterwards call
          super.destroy()

  GC flow
  =======
  The flow for GC is very simple:

    a) widgets disappear from the DOM, either due to a controller change
      (which will do an @el.html('') on the whole controller div),
      or due to something else (for example, change of filters, which
      tells the list of mentions to reset its content with a new one)

    b) MutationObserver / Mutation events / polling catches this
       (sooner or later!). Currently the interval for polling is 200ms,
       so you can assume that it's instant in all cases.

    c) those guys which have disappeared from DOM are marked as 'detached'
       (see above) and put in a queue for GC (there are actually 2 queues,
       a priority one and a normal one).

    d) periodically, that queue is checked for widgets and a new __BATCH__
       is processed (more on batches later)

    e) when an item of a batch is processed, its destroy method is called
       and in the end this sends a /widget_destroyed message to the datasource

    f) datasource updates reference counts for the channels which had been
       used by the dead widget

    g) datasource does periodic checks for channels 'hanging around' with
       reference count 0 and it destroys them. There goes your in-memory data!

  GC Q&A
  ======
  Q: What is priority GC and why do we need it?
  A: When a controller is changed with another one, we don't want to wait for
     seconds to tens of seconds for some widgets to disappear. Mediators
     are the best example. Therefore, those widgets have the "urgent for gc"
     flag set, and they will be put in the priority queue. This queue is
     emptied before anything else in a GC round.

  Q: Why use batches instead of emptying the queue at each round?
  A: When changing filters or controllers, there will be hundreds of widgets
     waiting to be GC'ed. This will freeze the UI, so we take it slower,
     but with the price of endless complications (URGENT_FOR_GC flag,
     marking widgets as detached from DOM, etc.)
