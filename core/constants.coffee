define [], () ->
    # This file contains core Constants specific to the Mozaic Core.
    # To add project specific constants create a new constants file and extend window.Constants

    Constants =
        # Custom error message thrown when a 401 Unauthorized message is received from the server.
        UNAUTHORIZED_EXCEPTION: '__UNAUTHORIZED__'

    window.Constants = Constants
    return Constants
