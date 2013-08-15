define [
  'cs!scrollable_widget'
  'cs!widget/list/item_management'
  'cs!widget/list/item_params'
  'cs!widget/list/sorting'
  'cs!widget/list/post_process'
], (
  ScrollableWidget
  ListItemManagementMixin
  ListItemParamsMixin
  ListSortingMixin
  ListPostProcessMixin
) ->

    class List extends ScrollableWidget
        ###
            Widget which is able to render a list of items, by injecting
            one widget per each item. An item to be displayed will be named
            ListItem.

            Features:

                - not all widgets for all items must be the same. There is
                  a mappings parameter which specifies different parameters
                  and different channels for each type of widget. In order
                  to find out the correct param, the list takes into
                  account ListItem['object_class].

                - it's able to maintain a client-side sorted order for widgets,
                  depending on one or more criteria. For example, it can sort
                  by 'created_at' key descending as the primary key, and when
                  two items are tied, break the tie with the 'name' field.
                  It supports custom comparators for each field. Out of the box,
                  it supports ints, floats, strings and dates.

                - it keeps a CSS class on the first and last item of the
                  list, even when the list order changes. And the list order
                  might change because of a change in a field that's a sort key!
                  This is very useful for design issues.

                - it manages the lifecycle of the widgets corresponding to
                  ListItems, by removing them from the DOM when the item
                  is removed from the channel, or by adding new ones when
                  an item is added to a channel. It is also able to MOVE
                  around a widget, but by making a DELETE + INSERT (Mozaic
                  core doesn't yet support moving widgets around in DOM)

                - it can filter items from the collection and only display
                  those we're interested in. For example, say that I'm
                  fetching the list of all books from the server, and I want
                  to display only the books by a certain author.

                - while the list is built around an /items channel in the
                  default implementation, its interface allows having more than
                  one channel (using aggregated channels) for building the list
                  items. All channel events must be funneled into the
                  @handleChannelEvents method, and items are joined together
                  under the @getModelsFromChannelData method

            IMO lifecycle management of the widgets is the most important
            feature of this widget - if I want to display a list, I can
            concentrate on writing the widget for the list's item instead of
            repeating the same boilerplate code for removing the widget from
            DOM when it's removed from the channel, and so on.

        ###
        subscribed_channels: ['/items']

        template_name : 'templates/list.hjs'

        @extendProperty('params_defaults',
            enable_scroll: 'data-params'
            item: 'data-params'
            item_channels: 'data-params'
            item_params: 'data-params'
            item_class: 'data-params'
            # Used to specify what fields to dynamically extract
            # from model. Should look like {key1: new_key1, key2: new_key2, ..}
            # where key is the one in model, and new_key is the one will be used
            # as key.
            item_model_params: 'data-params'
            filter_by: 'data-params'
            sort_by: 'data-params'
            container: 'data-params'
            item_element: (value) -> value or 'li'
            prepend: 'data-params'
            # This mappings params is used to be able
            # to insert different widgets (with different
            # models).
            mappings: 'data-params'
            # Choose whether to insert page breaks between list elements
            # or not. These are elements which are of the same type of the
            # widgets but only serve there as placeholders for pagination
            # algorithms to insert spaces.
            insert_page_breaks: (data_params) -> data_params or false
            # Field used as a differentiator in order to inject heterogeneous
            # items in the list based on the mapping field.
            object_class_key: (object_class) -> object_class or 'object_class'
            id_field: (id_field) -> id_field or 'id'
            minimize_dom_nodes: (data_params) -> data_params or false
        )

        widget_params: {}

        initialize: =>
            # If the scroll is enabled in the params, then make
            # the items channel a scrollable one
            if @enable_scroll
                # Make all subscribed channels scrollable
                @scrollable_channels = _.clone(@subscribed_channels)

            @extendWidgetParamsFromItem()
            @_parseSortByParameter()

            # Internal sorted list of item IDs.
            #
            # Don't put references in here unless you want to run into
            # major trouble :) Not to models, not to DOM elements, not to
            # anything.
            @list_items = []
            super()

        onScroll: =>
            super(arguments...)
            @_updateListItemsVisibility()

        destroy: =>
            @list_items = null
            super(arguments...)

    List.includeMixin(ListItemManagementMixin)
    List.includeMixin(ListItemParamsMixin)
    List.includeMixin(ListSortingMixin)
    List.includeMixin(ListPostProcessMixin)
