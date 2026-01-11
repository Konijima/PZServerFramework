# ChatSystem Testing Checklist

Use this checklist when testing with another player on a multiplayer server.

---

## Setup Requirements
- [ ] Two players connected to the same server
- [ ] One player with Admin access level
- [ ] One player with Player access level (or use Observer to test restrictions)

**Notes:**
```

```

---

## 1. Chat Channels

### 1.1 Local Chat (Proximity)
- [ ] Send message in LOCAL - only nearby players see it
- [ ] Move far apart (>30 tiles) - verify message NOT received
- [ ] Move close (<30 tiles) - verify message IS received
- [ ] Test on different Z levels (floors) - adjacent floors should work

**Notes:**
```

```

### 1.2 Global Chat
- [ ] Send message in GLOBAL - all players see it regardless of distance
- [ ] Channel prefix `/g message` works
- [ ] Channel prefix `/global message` works
- [ ] Disable EnableGlobalChat in sandbox - channel should disappear

**Notes:**
```

```

### 1.3 Yelling
- [ ] Type message in ALL CAPS (>3 chars) in LOCAL - should have extended range (60 tiles)
- [ ] Type message with `!` prefix in LOCAL - should yell
- [ ] Verify yell reaches further than normal local chat

**Notes:**
```

```

### 1.4 Faction Chat
- [ ] Both players join same faction - Faction channel appears
- [ ] Send message in FACTION - only faction members see it
- [ ] Player not in faction - cannot see/access Faction channel
- [ ] Leave faction - channel should disappear

**Notes:**
```

```

### 1.5 Safehouse Chat
- [ ] Both players in same safehouse - Safehouse channel appears
- [ ] Send message in SAFEHOUSE - only safehouse members see it
- [ ] Player not in safehouse - cannot see/access Safehouse channel

**Notes:**
```

```

### 1.6 Staff Chat
- [ ] Admin/Moderator/GM can see Staff channel
- [ ] Observer CANNOT see Staff channel
- [ ] Regular Player CANNOT see Staff channel
- [ ] Messages only go to staff members

**Notes:**
```

```

### 1.7 Admin Chat
- [ ] Only Admin access level can see Admin channel
- [ ] Moderator CANNOT see Admin channel
- [ ] Observer CANNOT see Admin channel
- [ ] Messages only go to admins

**Notes:**
```

```

### 1.8 Private Messages
- [ ] Open PM conversation with another player
- [ ] Send PM - only target receives it
- [ ] Receive PM - notification/sound plays
- [ ] Unread counter shows on conversation tab
- [ ] Close conversation - clears messages
- [ ] Disable EnablePrivateMessages - PM functionality disabled

**Notes:**
```

```

---

## 2. Channel Switching

### 2.1 Channel Selection
- [ ] Click channel tabs to switch active channel
- [ ] Send message - goes to correct active channel
- [ ] Channel color coding is correct

**Notes:**
```

```

### 2.2 Channel Prefixes
- [ ] `/l message` - sends to LOCAL
- [ ] `/local message` - sends to LOCAL
- [ ] `/say message` - sends to LOCAL
- [ ] `/s message` - sends to LOCAL
- [ ] `/g message` - sends to GLOBAL
- [ ] `/global message` - sends to GLOBAL
- [ ] `/all message` - sends to GLOBAL
- [ ] `/f message` - sends to FACTION (if in faction)
- [ ] `/faction message` - sends to FACTION
- [ ] `/sh message` - sends to SAFEHOUSE (if has safehouse)
- [ ] `/safehouse message` - sends to SAFEHOUSE
- [ ] `/st message` - sends to STAFF (if staff)
- [ ] `/staff message` - sends to STAFF
- [ ] `/a message` - sends to ADMIN (if admin)
- [ ] `/admin message` - sends to ADMIN

**Notes:**
```

```

---

## 3. Commands

### 3.1 General Commands (All Players)

#### /help
- [ ] `/help` - shows all available commands
- [ ] `/help kick` - shows help for specific command
- [ ] `/h` alias works
- [ ] `/?` alias works
- [ ] Response appears in ACTIVE channel

**Notes:**
```

```

#### /online
- [ ] `/online` - shows online players grouped by role
- [ ] `/players` alias works
- [ ] `/who` alias works
- [ ] Shows "(you)" next to own name
- [ ] Response appears in ACTIVE channel

**Notes:**
```

```

#### /roll
- [ ] `/roll` - rolls 1d6 (default)
- [ ] `/roll 2d6` - rolls 2 dice with 6 sides
- [ ] `/roll d20` - rolls 1d20
- [ ] `/dice` alias works
- [ ] Result broadcasts to ACTIVE channel (both players see it)
- [ ] With Roleplay Mode ON - shows character name
- [ ] With Roleplay Mode OFF - shows username

**Notes:**
```

```

#### /me
- [ ] `/me waves` - shows "* Name waves *"
- [ ] `/emote waves` alias works
- [ ] `/action waves` alias works
- [ ] Message broadcasts to ACTIVE channel
- [ ] In LOCAL - only nearby players see it
- [ ] In GLOBAL - all players see it
- [ ] In FACTION - only faction members see it
- [ ] With Roleplay Mode ON - shows character name
- [ ] With Roleplay Mode OFF - shows username
- [ ] Message appears in orange color

**Notes:**
```

```

### 3.2 Admin Commands (Moderator+)

#### /kick (Moderator+)
- [ ] `/kick playername` - kicks player with default reason
- [ ] `/kick playername reason here` - kicks with custom reason
- [ ] Kick announcement appears in GLOBAL for everyone
- [ ] Cannot kick yourself
- [ ] Cannot kick higher-ranked staff
- [ ] Moderator can kick players
- [ ] Player cannot use this command

**Notes:**
```

```

#### /announce (Admin+)
- [ ] `/announce message` - sends gold announcement to GLOBAL
- [ ] `/broadcast message` alias works
- [ ] `/bc message` alias works
- [ ] All players see the announcement
- [ ] Message shows "[ANNOUNCEMENT]" prefix

**Notes:**
```

```

#### /tp (Admin+)
- [ ] `/tp playername` - teleports to player
- [ ] `/tp 1000,1000` - teleports to coordinates
- [ ] `/tp 1000,1000,0` - teleports with Z level
- [ ] `/teleport` alias works
- [ ] `/goto` alias works
- [ ] Response appears in ACTIVE channel

**Notes:**
```

```

#### /bring (Admin+)
- [ ] `/bring playername` - teleports player to you
- [ ] `/summon` alias works
- [ ] `/tphere` alias works
- [ ] Admin sees success message
- [ ] Target player sees "You have been teleported to..." in LOCAL
- [ ] Cannot bring yourself

**Notes:**
```

```

#### /god (Admin+)
- [ ] `/god` - toggles god mode
- [ ] `/godmode` alias works
- [ ] Shows ENABLED/DISABLED status
- [ ] Response appears in ACTIVE channel

**Notes:**
```

```

#### /invisible (Admin+)
- [ ] `/invisible` - toggles invisibility
- [ ] `/invis` alias works
- [ ] `/vanish` alias works
- [ ] Shows ENABLED/DISABLED status
- [ ] Response appears in ACTIVE channel

**Notes:**
```

```

### 3.3 Server Commands (Owner)

#### /servermsg (Owner)
- [ ] `/servermsg message` - sends system message to GLOBAL
- [ ] `/sm message` alias works
- [ ] All players see it
- [ ] Non-owner cannot use this command

**Notes:**
```

```

---

## 4. Sandbox Settings

### 4.1 Message Settings
- [ ] Change MaxMessageLength - messages truncated at limit
- [ ] Change MaxMessagesStored - old messages removed

**Notes:**
```

```

### 4.2 Range Settings
- [ ] Change LocalChatRange - test proximity changes
- [ ] Change YellRange - test yell distance changes

**Notes:**
```

```

### 4.3 Channel Toggles
- [ ] Disable EnableGlobalChat - channel disappears, can't send
- [ ] Disable EnableFactionChat - channel disappears
- [ ] Disable EnableSafehouseChat - channel disappears
- [ ] Disable EnableStaffChat - channel disappears for staff
- [ ] Disable EnableAdminChat - channel disappears for admins
- [ ] Disable EnablePrivateMessages - PMs disabled

**Notes:**
```

```

### 4.4 Moderation
- [ ] Set ChatSlowMode to 5 - wait 5 seconds between messages
- [ ] Verify cooldown message shows remaining time
- [ ] Admins bypass slow mode

**Notes:**
```

```

### 4.5 Roleplay Mode
- [ ] Enable RoleplayMode - chat shows "Firstname Lastname"
- [ ] Disable RoleplayMode - chat shows username
- [ ] /me command respects roleplay mode
- [ ] /roll command respects roleplay mode

**Notes:**
```

```

---

## 5. Access Level Restrictions

### 5.1 Observer Role
- [ ] Observer CANNOT see Admin channel
- [ ] Observer CANNOT see Staff channel
- [ ] Observer CAN use general commands (/help, /online, /roll, /me)
- [ ] Observer CANNOT use admin commands

**Notes:**
```

```

### 5.2 Moderator Role
- [ ] Moderator CAN see Staff channel
- [ ] Moderator CANNOT see Admin channel
- [ ] Moderator CAN use /kick
- [ ] Moderator CANNOT use /announce, /tp, /bring, /god, /invisible

**Notes:**
```

```

### 5.3 Admin Role
- [ ] Admin CAN see Admin channel
- [ ] Admin CAN see Staff channel
- [ ] Admin CAN use all admin commands
- [ ] Admin CANNOT use owner commands (/servermsg)

**Notes:**
```

```

---

## 6. Edge Cases

### 6.1 Message Handling
- [ ] Send very long message (near max length) - handled correctly
- [ ] Send empty message - ignored
- [ ] Send message with special characters - displayed correctly
- [ ] Rapid message sending - slow mode kicks in (if enabled)

**Notes:**
```

```

### 6.2 Player Lookup
- [ ] `/kick partial` - finds player with partial name match
- [ ] `/kick ambiguous` - shows error if multiple matches
- [ ] `/kick nonexistent` - shows "Player not found"

**Notes:**
```

```

### 6.3 Typing Indicators
- [ ] Start typing - other players see typing indicator
- [ ] Stop typing - indicator disappears
- [ ] Switch channels while typing - indicator updates

**Notes:**
```

```

### 6.4 Connection/Disconnection
- [ ] Player disconnects - removed from online list
- [ ] Player reconnects - added back to online list
- [ ] Chat history persists during session

**Notes:**
```

```

### 6.5 Channel Access Changes
- [ ] Join faction mid-session - Faction channel appears
- [ ] Leave faction mid-session - Faction channel disappears
- [ ] Claim safehouse - Safehouse channel appears
- [ ] Lose safehouse - Safehouse channel disappears

**Notes:**
```

```

---

## 7. UI Features

### 7.1 Chat Window
- [ ] Open/close chat window
- [ ] Resize chat window
- [ ] Scroll through message history
- [ ] Clear chat history

**Notes:**
```

```

### 7.2 Channel Tabs
- [ ] Tabs show available channels
- [ ] Clicking tab switches channel
- [ ] Active tab highlighted
- [ ] PM conversations appear as separate tabs

**Notes:**
```

```

### 7.3 Message Display
- [ ] Messages show correct author
- [ ] Messages show correct timestamp (if enabled)
- [ ] Messages show correct channel color
- [ ] System messages have distinct styling
- [ ] Emotes (/me) have orange color

**Notes:**
```

```

---

## Summary

**Total Tests:** ___
**Passed:** ___
**Failed:** ___
**Skipped:** ___

**Critical Issues Found:**
```

```

**Minor Issues Found:**
```

```

**Suggestions:**
```

```
