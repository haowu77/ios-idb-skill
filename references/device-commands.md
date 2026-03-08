# idb Device Commands

## Target Management

```bash
idb list-targets                                 # List all simulators and devices
idb list-targets --json                          # JSON output
idb describe --udid UDID                         # Describe a specific target
idb connect UDID                                 # Connect to a target
idb disconnect UDID                              # Disconnect a target
idb focus --udid UDID                            # Focus simulator window
```

## App Management

```bash
idb list-apps                                    # List installed apps
idb install /path/to/MyApp.app                   # Install .app bundle
idb install /path/to/MyApp.ipa                   # Install .ipa file
idb launch com.example.myapp                     # Launch app
idb launch com.example.myapp -f                  # Foreground if already running
idb launch com.example.myapp -w                  # Wait mode (tail stdout/stderr)
idb terminate com.example.myapp                  # Terminate app
idb uninstall com.example.myapp                  # Uninstall app
```

## UI Interaction

```bash
idb ui tap X Y                                   # Tap at coordinates
idb ui tap X Y --duration 2.0                    # Long press
idb ui swipe X1 Y1 X2 Y2                        # Swipe gesture (NO duration arg!)
idb ui swipe X1 Y1 X2 Y2 --delta 20             # Swipe with step size (smaller = slower)
idb ui text "hello world"                        # Type text
idb ui button HOME                               # Home button
idb ui button LOCK                               # Lock button
idb ui button SIRI                               # Siri button
idb ui button SIDE_BUTTON                        # Side button
idb ui button APPLE_PAY                          # Apple Pay button
idb ui key 4                                     # Press key by keycode
idb ui key-sequence 4 5 6                        # Press key sequence
```

## UI Inspection (Accessibility)

```bash
idb ui describe-all                              # Full UI tree as JSON
idb ui describe-all | jq .                       # Pretty-print UI tree
idb ui describe-point X Y                        # Hit-test at coordinate
```

## Screenshot & Video

```bash
idb screenshot /path/to/output.png               # Capture screenshot
idb record video /path/to/output.mp4             # Record video
```

## Logs

```bash
idb log                                          # Stream system logs
idb log -- --predicate 'subsystem == "com.example.app"'  # Filter by subsystem
idb log -- --level error                         # Errors only
idb log -- --predicate 'eventMessage contains "keyword"'  # Filter by message
```

## Crash Logs

```bash
idb crash list                                   # List crash logs
idb crash list --bundle-id com.example.app       # Filter by app
idb crash show CRASH_NAME                        # Show crash details
idb crash delete CRASH_NAME                      # Delete crash log
idb crash delete --all                           # Delete all crash logs
```

## File Operations

```bash
idb file push --application com.foo.bar src.txt dest/  # Push file
idb file pull --application com.foo.bar/file.txt ./    # Pull file
idb file ls --application com.foo.bar/Documents        # List files
idb file mkdir --application com.foo.bar/Documents/new # Create directory
idb file rm --application com.foo.bar/Caches           # Remove file/dir
idb file mv --application com.foo.bar/old.txt new.txt  # Move/rename
```

## Testing

```bash
idb xctest install test.xctest                   # Install test bundle
idb xctest list                                  # List test bundles
idb xctest list-bundle com.example.tests         # List tests in bundle
idb xctest run [args]                            # Run tests
```

## Misc

```bash
idb open https://example.com                     # Open URL / deep link
idb set_location LAT LONG                        # Set simulated location (sim only)
idb add-media photo.jpg video.mov                # Add to media library
idb clear_keychain                               # Clear keychain (sim only)
idb approve com.example.app photos camera        # Pre-approve permissions (sim only)
idb debugserver start com.example.app            # Start debug server
```
