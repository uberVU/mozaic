define [], () ->
    # This file contains core Constants specific to the Mozaic Core.
    # To add project specific constants create a new constants file and extend window.Constants

    Constants =
        TODO_MOCKS: [
            id: 1
            name: "rob the bank",
            starred: true
        ,
            id: 2
            name: "grandma' needs a bath"
        ,
            id: 3
            name: "feed that damn dog"
        ,
            id: 4
            name: "finish the hackton"
        ,
            id: 5
            name: "do your homework"
        ,
            id: 6
            name: "remember the milk",
            checked: true
        ,
            id: 7
            name: "shake that ass",
            checked: true
        ]

        # Custom error message thrown when a 401 Unauthorized message is received from the server.
        UNAUTHORIZED_EXCEPTION: '__UNAUTHORIZED__'

        # Data attribute name used to tell WidgetStarter to delay the start of marked widget.
        DELAY_WIDGET: 'data-delayed'
        INITIALIZED_WIDGET: 'data-initialized'

        # Class name used for widgets between which page rendering can be broken.
        PAGE_BREAK_CLASS: 'mozaic-page-break'

    window.Constants = Constants
    return Constants
