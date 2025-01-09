# Calendar Sync for macOS

Sync events from one calendar to another.
Synchronize all events from today's start up-to 30 days from now, **including instances of recurring events**.

For `CalendarSync` to work, you must have your calendars enabled in System Settings/Internet Accounts.

Also, you can install `launchd` agents to synchronize your calendars automatically.

## Build the script

1. Open the `CalendarSync` project in XCode.
2. At the top, select the "Any Mac" run destination.
3. Select `Product -> Build For -> Running`.
4. Select `Product -> Archive`.
5. Right-click the archive, click "Show in Finder".
6. Right-click the `.xcarchive`, "Show Package Contents".
7. The `CalendarSync` binary is under `Products/usr/local/bin/`.
8. You can copy the `CalendarSync` executable file to your home directory for simplicity.

## `CalendarSync` usage

Follow the `account_name→calendar_name` format.
`CalendarSync` uses the `→` arrow character as a separator as it has a low probability of appearing in a calendar's name.

If you're unsure of what names to use, you can get them from `Calendar.app`.

```commandline
./CalendarSync "source_account_name→source_calendar_name" "target_account_name→target_calendar_name" [--dry-run]
```

Example:

```commandline
./CalendarSync "outlook→Calendar" "gmail→somename@gmail.com"
```

### Dry run

`--dry-run` is an optional argument you can use to see what events `CalendarSync` would create and delete, if any.

Example:

```commandline
./CalendarSync "outlook→Calendar" "gmail→somename@gmail.com" --dry-run
```

## Configure a sync agent

### Copy the `com.danyreyna.CalendarSync.plist` file

Give it a unique name.

```commandline
cp com.danyreyna.CalendarSync.plist com.danyreyna.calendarsync.some_sync_agent_name.plist
```

For example:

```commandline
cp com.danyreyna.CalendarSync.plist com.danyreyna.calendarsync.outlook_to_gmail.plist
```

### Edit your `plist` file

1. Edit the following keys to change `some_sync_agent_name` to your agent's name:
   - `Label`
   - `StandardOutPath`
   - `StandardErrorPath`
   - For example, `com.danyreyna.calendarsync.outlook_to_gmail`.
2. Configure the `ProgramArguments` key:
   1. Edit the path to `CalendarSync`. You can copy the `CalendarSync` executable file to your home directory for simplicity.
   2. Edit the source and target calendars.
      - Follow the `account_name→calendar_name` format.
      - `CalendarSync` uses the `→` arrow character as a separator as it has a low probability of appearing in a calendar's name.
      - If you're unsure of what names to use, you can get them from `Calendar.app`.
3. You can also uncomment the `--dry-run` `<string>` tag for testing and debugging purposes.
4. By default, the agent will run every hour from 8am to 5pm. Edit the `StartCalendarInterval` key to your liking.

## Install a sync agent

1. Move your `plist` file to your user's launch agents directory.

```commandline
mv com.danyreyna.calendarsync.some_sync_agent_name.plist ~/Library/LaunchAgents/com.danyreyna.calendarsync.some_sync_agent_name.plist
```

For example:

```commandline
mv com.danyreyna.calendarsync.outlook_to_gmail.plist ~/Library/LaunchAgents/com.danyreyna.calendarsync.outlook_to_gmail.plist
```

2. Load the `plist` into `launchd`.

```commandline
launchctl load ~/Library/LaunchAgents/com.danyreyna.calendarsync.some_sync_agent_name.plist
```

For example:

```commandline
launchctl load ~/Library/LaunchAgents/com.danyreyna.calendarsync.outlook_to_gmail.plist
```

3. Verify it loaded correctly.

```commandline
launchctl list | grep com.danyreyna.calendarsync.some_sync_agent_name
```

For example:

```commandline
launchctl list | grep com.danyreyna.calendarsync.outlook_to_gmail
```

## See a sync agent's logs

### Output log

```commandline
cat /tmp/com.danyreyna.CalendarSync.some_sync_agent_name.out | tail 
```

For example:

```commandline
cat /tmp/com.danyreyna.CalendarSync.outlook_to_gmail.out | tail 
```

### Error log

```commandline
cat /tmp/com.danyreyna.CalendarSync.some_sync_agent_name.err | tail 
```

For example:

```commandline
cat /tmp/com.danyreyna.CalendarSync.outlook_to_gmail.err | tail 
```

## Update a sync agent's configuration

1. Unload the `plist` from `launchd`.

```commandline
launchctl unload ~/Library/LaunchAgents/com.danyreyna.calendarsync.some_sync_agent_name.plist
```

For example:

```commandline
launchctl unload ~/Library/LaunchAgents/com.danyreyna.calendarsync.outlook_to_gmail.plist
```

2. Edit the `plist` file with your new configuration.
3. Load the `plist` into `launchd`.

```commandline
launchctl load ~/Library/LaunchAgents/com.danyreyna.calendarsync.some_sync_agent_name.plist
```

For example:

```commandline
launchctl load ~/Library/LaunchAgents/com.danyreyna.calendarsync.outlook_to_gmail.plist
```

4. Verify it loaded correctly.

```commandline
launchctl list | grep com.danyreyna.calendarsync.some_sync_agent_name
```

For example:

```commandline
launchctl list | grep com.danyreyna.calendarsync.outlook_to_gmail
```

## Uninstall a sync agent

1. Unload the `plist` from `launchd`.

```commandline
launchctl unload ~/Library/LaunchAgents/com.danyreyna.calendarsync.some_sync_agent_name.plist
```

For example:

```commandline
launchctl unload ~/Library/LaunchAgents/com.danyreyna.calendarsync.outlook_to_gmail.plist
```

2. Remove the `plist` file from your user's launch agents directory.

```commandline
rm ~/Library/LaunchAgents/com.danyreyna.calendarsync.some_sync_agent_name.plist
```

For example:

```commandline
rm ~/Library/LaunchAgents/com.danyreyna.calendarsync.outlook_to_gmail.plist
```

3. Remove the log files.

```commandline
rm /tmp/com.danyreyna.CalendarSync.some_sync_agent_name.out 
rm /tmp/com.danyreyna.CalendarSync.some_sync_agent_name.err 
```

For example:

```commandline
rm /tmp/com.danyreyna.CalendarSync.outlook_to_gmail.out 
rm /tmp/com.danyreyna.CalendarSync.outlook_to_gmail.err 
```
