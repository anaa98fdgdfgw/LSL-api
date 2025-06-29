# OpenCollar Gender Control Plugin - Test Documentation

## Installation
1. Copy `oc_gender_control.lsl` to the `Apps` folder in your OpenCollar
2. The script will appear in the Apps menu as "Gender Control"

## Features Tested

### 1. Menu System
- Main menu shows: Monitoring toggle, Access Control, Auto Visibility toggle
- Access Control submenu shows: Allow Males, Allow Females, Custom Message
- Custom Message submenu allows setting/clearing rejection messages

### 2. Gender Detection
- **RLV Method**: Uses `@getattach:pelvis=2222` for wearer gender detection
- **Sensor Method**: Scans nearby objects for genital attachments
- **Caching**: Results cached for 5 minutes for performance

### 3. Access Monitoring
- Monitors all collar touch events
- Logs accessor name, profile link, and detected gender
- Sends private messages to collar wearer when enabled

### 4. Access Control
- Only applies to Public mode (CMD_EVERYONE)
- Owners and trustees always bypass restrictions
- Sends custom rejection messages to restricted users
- Creates awareness rather than hard blocking

### 5. Visibility Control
- Monitors leash state via CMD_PARTICLE messages
- Automatically shows collar when leashed if hidden
- Restores original visibility state when unleashed
- Tracks original state before leashing

### 6. Settings Persistence
- All settings stored using OpenCollar's LM_SETTING_SAVE system
- Settings survive script resets and collar updates
- Token: `genderctrl_` for all settings

## Usage Examples

1. **Basic Setup**:
   - Touch collar → Apps → Gender Control
   - Toggle Monitoring ON
   - Configure Access Control as desired
   - Set custom rejection message if wanted

2. **Leash Visibility**:
   - Hide collar (if allowed)
   - Get leashed - collar automatically becomes visible
   - Get unleashed - collar returns to hidden state

3. **Gender Detection**:
   - System automatically detects gender on first access
   - Results cached for 5 minutes
   - Works for RLV users (wearer only) and sensor detection (all users)

## Technical Notes

- Script uses standard OpenCollar messaging system
- Memory efficient with caching and cleanup
- Error handling for all detection methods
- Comprehensive event monitoring
- Non-intrusive design - doesn't break existing functionality

## Limitations

- RLV gender detection only works for the wearer
- Sensor detection relies on attachment naming conventions
- Access control is awareness-based, not hard blocking
- Requires standard OpenCollar messaging infrastructure