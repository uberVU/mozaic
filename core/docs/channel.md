# Life of a DataSource channel

## 0. Definition

Not much here for now. Just know that channels are created inside conf/datasource.js. Each have a name of format `/channel_name`, a type between `relational` and `api` and a set of config params (which can even be callbacks ran a a certain time in the lifecycle of the channel, by pre-defined actions). See https://github.com/uberVU/mozaic/blob/master/core/docs/datasource.md

Basically, _Relational_ channels are built around a Backbone Collection with _N_ Backbone Models inside it, and _Api_ channels are built around a RawData object, which is a custom single-instance primitive. Think of a dict with settings of variable value.

__TODO:__

- Bold move: but how about renaming these two so-hard to explain entities. "relational" should just be called "collection", as for "api", I can't think of something good now, but "api" is just too generic...
- Bolder move: Use a Backbone Model instead of the RawData primitive. Go consistency! (think about it)

## 1. Entry point: Creation

A channel is created using `Utils.newDataChannels(channels...)`. This is what the input data looks like:

```coffee
# Single channel w/out params
'/streams'

# Single channel w/ params
'/mentions':
    keyword_id: 3

# Multiple channels w/out params (more arguments, not a single list argument)
'/filters', '/users', '/streams', ...

# Multiple channels w/ params (still one single argument, an object with a key for each channel and params as corresponding values)
'/filters': {}
'/users': {}
'/streams':
    keyword_id: 3
```

This method receives one or a list of channels to create, parses their type and params, creating unique GUIDs for each, and then announces the DataSource that new channels are to be created, using the `/new_data_channels` pubsub event.

**_~pubsub async event handling, other channals or widgets can be picked up before these channels~_**

__TODO:__ Couldn't we skip this async step? Why not have something like `DataSource.createChannels` and drop the `Utils` crap. The `new_data_channels` event is useful for plugins to hook into it, but it could work just as well after the channels are fully initialized

The event is picked up in `DataSource.newDataChannels(channels)`, with a map object with a key for each channel as the only argument. This is what the input data looks like:

```coffee
# Single channel w/out params
'/streams-1719':
    params: {}
    type: '/streams'

# Single channel w/ params
'/mentions-1724':
    params:
        keyword_id: 3
    type: '/mentions'

# And so on...
```

This method receives a map of unique ID-ed channels with their corresponding channel type and params. Synchronous actions that take place here:

- The `DataSource.reference_data[channel_key]` entry is created, w/ nothing but an empty `widgets: {}` object
- The channels params support a _magic_ key called _channel_config_options._ If present, it is extracted and removed from the entire params object, and set in a new datasource channel-related object: `DataSource.channel_config_options[channel_key]`. This is used to extend settings from the global channel config setup at Step 0: Definition. More specifically in `DataSource._getConfig`
- The next method is called for each channel individually, based on the channel type (see 1.1.a Relational and 1.2.a Api)

__TODO:__

- The reference_data should have a more sane scheleton, including reference_count and time_of_reference_expiry. Remember, no `DataSource.meta_data[channel_key]` or `DataSource.data[channel_key` at this point.
- Bold move: unity the entire `DataSource.xxx_data[channel_key]` data sets so there's only one entry that exists from the beginning til after GC, preferably created sync.

### 1.1.a Relational channels

Picked up synchronously in `DataSource._initRelationalChannel(channel_guid, channel_type, channel_params)`, input data looks like this:

```coffee
'/mentions-1724', '/mentions', {keyword_id: 3}
```

- The first step is establishing what Backbone Collection subclass to use for this channel. The `"cs!collection/#{collection_name}"` require module will be used if the channel config has the .channel key, otherwise it will default to `"cs!base_collection"`

### 1.1.b Api channels

Picked up synchronously in `DataSource._initApiChannel(channel_guid, channel_type, channel_params)`, same input data as above.

- First step is the same as for Relation channels, except it will default to `"cs!collection/raw_data"` instead of the base_collection

__TODO:__

- `DataSource._getConfig` is not used in this method, so you couldn't use `channel_config_options` to override the channel collection for a specific instance (Actually this is a bit more complicated, _getConfig depends on a channel's meta data, which is not created at this point. We still need to unify configs somehow, maybe created the meta_data before selecting a collection to load. See a few TODOs above)

### 1.2 _~we asynchronously require the module for the established collection~_

This is where the `DataSource.data[channel_key]` and `DataSource.meta_data[channel_key]` objects are created, after the collection is required

A set of params are initiated in the meta_data channel reference, based on the nature of the channel:

- `type` - The name of the channel
- `params` - The initial user params__, stripped of *magic* params for configuration purposes (see below)__
- `collection_class` - JS object reference of the actual CoffeeScript Class (previously required)
- `model_class` - Same as collection class, for individual models (only for Relational channels)

The *magic* params that get transfered to meta_data or channel data:

- `__eternal__` - This will set the `eternal` meta_data key to _true_. Having this set on a channel will simply prevent it from every being GC-ed, using the basic check in `DataSource.channelCanBeGarbageCollected`. This property is common for global channels that are initiated inside the application controller and are used throught most of the controllers, thus not needing to be realeased sooner than when leaving the app.
- `populate_on_init` - This gets transfered directly into the meta_data and removed from the original user params and it basically means "This channel is created with initial data, so no need do to an initial server data request upon creation." This works hand-in-hand with `_initial_data_` for Relational channels, but not for Api ones. __With them the entire user `params` object is poured into that channel's collection when this param is set to true.__ After removing the _initial_data_ key from the object, of course.
- `_initial_data_` - Following the comments above, this is used to provide initial data for a Relation channels, be it one model or a list of them. Its value is simply passed on to the channel's Backbone Collection through its `.add` method

There are also a few channel config params (set in datasource.js) that take part in the initialization of a channel, and act as follows:

- `default_value` - __This means two completely different things between Relation and Api channels.__
  - For Relation channel it is a default set of params that play a role in building that channel's endpoint url (see below.) `Utils.render_url` is used to embed them inside the channel's url, as query string arguments. __The rest of the user params sent for a particular channel instance are also embeded into the url arguments, having priority over this config default_value.__
  - For Api channels, it means the default data set for that type of channel. It is set using the `.setDefaultValue` method of whatever RawData subclass that channel uses.
- `url` - This is supposed to set the `url` property on a collection, as the server endpoint location for this data channel. What happens next, though, is batshit weird. __It is only set for Relational channels and ONLY if `populate_on_init` is specified (probably indented under this `if` by mistake).__ But don't worry, it is set again at `DataSource._fetchChannelDataFromServer` before EACH server fetch, just to be sure; so the original value set here doesn't really matter. Right.
- `buffer` - Relational channels support a feature called Buffer, and is enabled if `buffer_size` is set under the channel configuration. It basically creates an alternative Collection to store continuously new-fetched data that doesn't make it into the master Collection until a certain user action is made. Think Twitter's "_X_ new tweets" feature from a timeline. We'll see how this behaves later on.

__Conclusion about channel params: In hindsight, besides the *magic* params that are extracted, the channel params are URL query string arguments for Relation channels, and initial data for Api channels.__

__TODO:__

- These *magic* params should no longer be root level along with the regular channel params, it's confusing and hard to follow. We should have a *magic* sub-key for config-related params. We already have `channel_config_options`, but all these already maintained properties (all in their own custom fashion) need to be ported using it.
- A lot of the code in Relational and Api channel initialization is duplicated in two different methods, they could easily be merged and would make our lives better
- Fix the _populate_on_init_ Relational/Api inconsistency, it's confusing
- Fix the _default_value_ Relation/Api inconsistency, it's confusing
- Set the channel _url_ at init for both channel types, and stop setting it on Read, re-generating it before each fetch is kinda of a weak move and makes it hard to understand the state of a channel at a given point in its life

### 1.3 Finish initialization

The last step from the channel creation is `DataSource._finishChannelInitialization(name)` and here the Relational/Api fork merges into a single flow again.

Three things happen here:

- Channel cloning comes into place. Other channels with the same configurations are searched for inside the current DataSource. If found, and the current channel configuration allows channel cloning (doesn't have the `disable_clone` key) their entire entire data set will be duplicated and poured into the newly created channel. Otherwise, depending on the config/user params of the channel, data might or might not be instantly fetched for it
- `/initialized_channel` pubsub event is triggered for this channel. This marks the complete initialization of a channel and is used by the widget_starter to notify pending widgets hooked to this channel (because widgets only complete their own initialization after all of their channels did)

__TODO:__

- Figure out the diference between `populate_on_init` and `start_immediately` and merge them into a single conf variable.
- Bolder move that follows the previous TODO: all config vars should be able to be overriden by user params for a channel, this would end a lot of confusions

`DataSource._getChannelDuplicates` is used to establish that two channels are duplicates and thus one can be cloned from the other. It simply compares the user params received for them and of course if they are of the same type.

There's a tricky logic in cloning channels. __One or more duplicates might be found, but they will be ignored for now if they don't have any data.__ The way this is handled is that these channels will be left hanging, and when the supposed duplicate will eventually receive data, it will go through a method called `DataSource._fillWaitingChannels`, which once again will look through all DataSource channels, establish duplicates and pour the data inside all those that match.

__TODO:__ This is buggy and hard to follow. There are two entry points for establishing duplicates: at init and when data is received. Also a channel that is waiting for a duplicate's data is in kind of a needy state w/out having any promises made. I say that cloning should be made in one place, at init, even if it just means marking a channel with `clone_of` and then when the cloned channel receives data just populates its already asigned _clonees_

There's also a channel config param called `start_immediately` that control whether a cannel starts fetching data immediately. It seems like the same as `populate_on_init` but on a config level (instead of per-instance user level)
