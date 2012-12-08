define ['cs!widget/item_count'], (ItemCountWidget) ->

    class UserItemCountWidget extends ItemCountWidget
        ###
            An item count based on the current user's data.

            This is a little simpler than the ItemCount widget
            because it doesn't need the loaders concept, as
            current user data is __ALWAYS__ available.

            You can use it with a plain value, but it doesn't
            make any sense to do so, so please refrain from
            doing that.
        ###
        initialize: =>
            # Initial render
            @render(@extractCountFromParams())

        get_current_user: =>
            # Re-render every time the user updates
            @render(@extractCountFromParams())

        extractCountFromParams: (params) =>
            return window.user.get(@path)

    return UserItemCountWidget