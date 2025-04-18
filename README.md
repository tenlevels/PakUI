![pakui](https://github.com/user-attachments/assets/06bb87f6-6daa-419c-b5d7-9ec5bb53a45e)


## PakUI
A collection of paks/tools for MinUI ONLY - PakUI is a full set and most paks talk to one another. You will need the full release on a fresh card and new install. Fresh format card ONLY. Sorry PakUI is not compatible with other MinUI variants or forks.

## Compatibility
- **MinUI ONLY**  
- **TrimUI Brick**  
- **TrimUI Smart Pro** (note: RetroArch coming soon for TSP) 
- More devices coming soon!

## Installation

# PakUI Installation Guide

## Who Should Read Which Section

### First-Time Users
- You have never installed PakUI before
- You need to follow the **First-Time Installation** section
- You **MUST** place the firmware file on the root of your SD card
- You **MUST** use the special button combination (Volume Down + Power)

### Existing Users
- You have successfully installed PakUI before
- Skip to the **Updating Existing Installation** section
- You do **NOT** need the firmware file
- You do **NOT** need the special button combination

## First-Time Installation

### Prerequisites
- SD card freshly formatted to FAT32
- PakUI release package downloaded from GitHub

### Step 1: Prepare Your SD Card
- Format your SD card to FAT32 (fresh format is required)
- Extract the **entire** PakUI release package to your SD card
- **IMPORTANT**: 
  - Ensure all files including hidden folders from the PakUI release are copied
  - Your SD card should contain ONLY the PakUI release files and the firmware file
  - Do not add any other files or folders before completing the installation
 
  ![PakUI_install_files](https://github.com/user-attachments/assets/fe2247d1-36c7-4990-a37b-a05c8e09aef1)

### Step 2: Add Firmware File (REQUIRED FOR FIRST-TIME INSTALLATION)
- ⚠️ **THIS STEP IS MANDATORY FOR FIRST-TIME USERS**
- Locate the Firmware folder in the release package
- For **TrimUI Brick**: Copy `trimui_tg3040.awimg` from the Brick folder to the **root** of your SD card
- For **TrimUI Smart Pro**: Copy `trimui_tg5040.awimg` from the Smart Pro folder to the **root** of your SD card
- If this file is not on the root of your SD card, first-time installation WILL FAIL

### Step 3: Install to Your Device (FIRST-TIME INSTALLATION PROCEDURE)
- ⚠️ **THIS SPECIAL BUTTON SEQUENCE IS ONLY FOR FIRST-TIME INSTALLATION**
- Insert the SD card into your TrimUI device
- Press and hold the **Volume Down** button
- While holding Volume Down, press and hold the **Power** button
- Continue holding **both** buttons until you see the green status bar
- Release both buttons once you see the green status bar
- Wait for the installation to complete (approximately 5-10 minutes)
- **Important**: Do not interrupt the installation process
- Be patient during installation - interrupting can cause install to fail and brick device
  
This special button sequence is required to install the firmware onto your device and prepare the environment for TrimUI_EX and PakUI. Without this process and the firmware file, first-time installation cannot succeed.

### What Happens During Installation
The installation process will:
- Flash your device firmware
- Install TrimUI_EX files
- Install MinUI and PakUI

## ⚠️ IMPORTANT: The "Limbo Bug" & Deep Sleep Solution ⚠️

**New users should be aware of an important device issue:**

The TrimUI devices have a notorious "limbo bug" that affects power management. When you power off the device normally, it may enter a "limbo state" where:
- The device appears to be off but continues consuming battery
- Battery may drain completely while in storage
- Device may become unresponsive until recharged

**Solution: Sleep Mode Fork**
We highly recommend installing the Sleep Mode Fork after completing your initial PakUI setup:

1. Launch the OTA Updater from your Tools menu
2. Select "Install SleepModeFork"
3. Follow the on-screen prompts

**Benefits of Sleep Mode:**
- Puts your device into a true sleep mode, preserving battery life
- Screen turns off immediately when sleep is activated
- LED lights stay on for 2 minutes, then turn off when deep sleep begins
- Simply press the power button to wake your device
- Compatible with the MinUI menu and minarch games

**Note:** Sleep mode is currently not compatible with Paks or RetroArch. You can always revert to stock MinUI through the OTA Updater if needed.

**Special Thanks:** to Froist for hosting and maintaining the Sleep Mode Fork files that make this feature possible!

## Updating Existing Installation

If you've successfully installed PakUI before:

- You do **NOT** need to add the firmware file to your SD card
- You do **NOT** need to use the special Volume Down + Power button sequence
- Your device already has the necessary firmware installed from your previous installation

### ⚠️ UPDATE INSTALLATION INSTRUCTIONS ⚠️
**IMPORTANT: FOLLOW THESE STEPS FOR UPDATING**

1. **REMOVE EXISTING FOLDERS** 
   - Delete the "Emus" and "Tools" folders from your SD card as these typically contain updated components
   - Always check the specific release notes for any additional folders that may need to be removed

2. **KEEP YOUR PERSONAL DATA** 
   - You can keep your Roms (including BitPal), Bios, Saves, Data and userdata folders
   - These contain your personal content and settings that should be preserved

3. **INSTALL THE UPDATE** 
   - Extract the PakUI package and replace all other files on your SD card
   - Make sure to follow any specific instructions in the current release notes

4. **VERIFY INSTALLATION** 
   - Restart your device and verify all features are working correctly

### Special Note About BitPal

BitPal lives in the Roms folder on your SD card. When updating:

- Check the release notes to see if BitPal has been updated
- You generally have two options for handling BitPal:
  1. **Keep your existing BitPal**: This preserves all your mission data and progress
  2. **Use new BitPal files**: If a new BitPal version is included in an update, you can copy the contents of the new BitPal and replace existing files in your current BitPal
  3. **Transfer your progress**: To keep your mission data while using a new BitPal version, transfer your `bitpal_data` folder from your older version to the new BitPal folder

**Note:** OTA (Over-The-Air) updates are a feature in development. Until then, manual installation is required for all updates.

For specific update procedures, please refer to the detailed update instructions included in the release notes.

## Troubleshooting

### Common Issues for First-Time Installation

**Screen Flashing Between Installing and Stock Firmware**
- Format your SD card to FAT32 again (completely fresh format)
- Ensure the firmware file is correctly placed on the root of your SD card
- Make sure your SD card contains ONLY the PakUI release files and the firmware file
- Check that all hidden folders were properly copied
- Restart the installation process

**Installation Taking Longer Than 20 Minutes**
- This may indicate an issue with the installation
- Try the process again with a freshly formatted SD card

**Failed Installation or Device Not Turning On**

If your device doesn't turn on or installation repeatedly fails, use the recovery process:

1. Download the recovery image from GitHub:
   - For TrimUI Brick: https://github.com/trimui/firmware_brick
   - For TrimUI Smart Pro: https://github.com/trimui/firmware_smartpro

2. Flash the recovery image to an SD card using Rufus or similar software
   - Make sure to use the correct recovery image for your device model
   - The recovery image may not be in the most recent release, so check all releases and assets

3. Insert the SD card into your device and hold the power button until you see the status bar

4. Release the button and let the recovery process complete
   - **Note**: The device will NOT boot after recovery is complete

5. After recovery, perform a fresh installation again with the firmware file on the root of your SD card

## Contact & Support
Need help? Want to share feedback? You can find the PakUI team on Discord only.
- Join the Retro Handhelds server - TrimUI Brick thread
- Join the Retro Game Handhelds server - TrimUI Brick thread


## Table of Contents

1. [Pak Manager](#pak-manager)  
2. [BitPal](#bitpal)  
3. [Deep Sleep Support](#deep-sleep-support)  
4. [Universal Launcher](#universal-launcher)  
5. [Game Switcher](#game-switcher)  
6. [PortMaster](#portmaster)  
7. [LEDs](#leds)  
8. [Artwork](#artwork)  
9. [Random Game](#random-game)  
10. [USB Storage Mode](#usb-storage-mode)  
11. [WiFi](#wifi)  
12. [PICO-8 Native](#pico-8-native)  
13. [Boxart Scraper](#boxart-scraper)  
14. [Custom Collection Maker](#custom-collection-maker)  
15. [Emulator Options](#emulator-options)  
16. [Emulator Sorter](#emulator-sorter)  
17. [Recents Manager](#recents-manager)  
18. [Game Time Tracker](#game-time-tracker)  
19. [OTA Updater](#ota-updater)  
20. [Boot To](#boot-to)  
21. [Screen Capture](#screen-capture)  
22. [YouTube Downloader](#youtube-downloader)  
23. [Moonlight](#moonlight)  
24. [Game Name Mapper](#game-name-mapper)  
25. [PSX Multi Disc](#psx-multi-disc)  
26. [Save Options](#save-options)  
27. [System Stats](#system-stats)  
28. [Syncthing](#syncthing)

---

## Pak Manager

A tool for installing and managing additional paks on your device.

**Features:**
- Install new paks from a catalog
- Uninstall paks you no longer need
- View descriptions of available paks
- Track installed vs. available paks
- Update existing paks to newer versions
- Organize paks by category

---

## BitPal

A friendly gaming companion that offers missions and tracks your progress as you play through your game library.

**Features:**
- Missions and challenges based on your gaming history
- Game session tracking
- Experience points and level progression
- Gaming recommendations
- Retro-styled interface with changing moods

---

## Deep Sleep Support

A solution to the notorious "limbo bug" that improves battery life and device usability.

**Features:**
- Puts your device into a true sleep mode, preserving battery life
- Screen turns off immediately when sleep is activated
- LED lights stay on for 2 minutes, then turn off when deep sleep begins
- Simply press the power button to wake your device
- Compatible with the MinUI menu and minarch games

**How to Enable Sleep Mode:**
1. Launch the OTA Updater from your Tools menu
2. Select "Install SleepModeFork"
3. Follow the on-screen prompts to complete installation

**Note:** Sleep mode is currently not compatible with Paks or RetroArch. You can always revert to stock MinUI through the OTA Updater if needed.

**Special Thanks:** to Froist for hosting and maintaining the Sleep Mode Fork files that make this feature possible!

---

## Universal Launcher

A smart game launcher that plays your games with your preferred settings.

**Features:**
- Works with both RetroArch and minarch emulators
- Uses your preferred cores based on your configuration
- Follows your launcher priority list for each system
- Supports custom settings and emulator options for individual games
- Creates quicksaves when you power off mid-game in RetroArch
- Tracks your play time for each game with Game Time Tracker
- Integrates with Game Switcher for easy game changing
- Works across all supported platforms

---

## Game Switcher

A tool that lets you switch between games without returning to the main menu, making gaming sessions more convenient.

**Features:**
- Switch games with visual previews
- Auto-saves screenshots of your games
- Remembers recently played games
- Works with save states
- Simple options menu
- Customizable hotkey shortcuts (L2, R2, F1, F2, or Menu button) for instant access from MinUI
- Option to disable shortcuts when not needed

---

## PortMaster

A powerful tool that brings hundreds of ports and games to your TrimUI device.

**Features:**
- Access to hundreds of ports and games, with two main categories:
  - **Ready To Run Ports:** Many free games you can download and play immediately
  - **All Ports:** Ports that may require additional game files from the original game
- Easy interface to browse, download, and manage ports
- Automatic dependency management
- Regular updates with new ports

**Getting Started:**
1. Launch Pak Manager
2. Go to the Gaming section
3. Select "PortMaster" to install
4. Open PortMaster from your Tools menu
5. Browse, download, and enjoy!

**Troubleshooting Tips:**
- If Ports or PortMaster has trouble working, go to Options → Runtime Manager → Download All
- The first time you launch a game with PortMaster, it may take a little longer to start. Please be patient
- Ports not found in the "Ready To Run Ports" section will require additional files from the original game
- Do NOT rename your PORTS rom folder. It must stay PORTS for now

**Alternative Solutions If Not Working:**
- Try a fresh flash of the TrimUI Brick FW (available at: https://github.com/trimui/firmware_brick/releases/tag/v1.0.6-20241215) followed by a complete fresh install of PakUI

**Thank You:** to Kloptops and the entire PortMaster team for creating such an amazing tool!

---

## LEDs

A tool for controlling the LED lights on your TrimUI device.

**Features:**
- Customize LED colors and patterns
- Create animation effects
- Set standby color
- Configure battery level indicators
- Adjust brightness levels
- Set different effects for different situations

---

## Artwork

A tool for customizing the visual appearance of your TrimUI device.

**Features:**
- Enable/disable themes
- Create custom themes
- Toggle box art visibility
- Change boot logos with visual previews
- Mix and match logos with different backgrounds

---

## Random Game

A tool that selects and launches a random game from your collection when you're not sure what to play.

**Features:**
- Picks a random game from your library
- Avoids recently played games
- Works across all your emulated systems

---

## USB Storage Mode

A tool that lets you connect your device to a computer for file transfers.

**Features:**
- Mount your device as a USB storage drive
- Transfer files to and from your computer
- Safe connection and disconnection handling
- Check for active transfers before disconnecting

---

## WiFi

A tool for managing wireless network connections.

**Features:**
- Connect to WiFi networks
- Save network credentials
- View connection status
- Enable/disable WiFi
- Manage saved networks

---

## PICO-8 Native

Play PICO-8 games with a native app and Splore.

**Features:**
- Runs PICO-8 cartridges (`.p8` and `.p8.png`) at native speed
- Launch the Splore browser directly (works with any file containing "splore" in the name)
- Browse, download, and play online games through Splore
- In-game menu system with useful options:
  - Switch between square and widescreen display modes while playing
  - Quick access to the Splore browser from within any game
  - Restart the current game without exiting
  - Exit to MinUI when finished
- Power button monitoring with auto-save when powering off
- Tracks your play time with Game Time Tracker integration
- WiFi connectivity check for the Splore browser

---

## Boxart Scraper

A tool that downloads game cover art for your ROM collection from online databases.

**Features:**
- Scrape artwork for games, systems, or your entire collection
- Resume scraping sessions if interrupted
- Set region priorities (USA, Europe, Japan, World)
- Customize image sizes
- New "Start Fresh" option to delete all images for a system when scraping to change styles
- Improved name matching for better results

---

## Custom Collection Maker

A tool for creating personalized game collections organized however you want.

**Features:**
- Create multiple custom collections
- Add any game from your library
- Launch games directly from collections
- Resume from save states
- Integrates with MinUI's recent games tracking

---

## Emulator Options

A tool for configuring emulator settings across your system.

**Features:**
- Switch between RetroArch and minarch launchers
- Select cores for each emulator
- Enable/disable Game Switcher support by system
- Apply settings to all emulators at once

---

## Emulator Sorter

A tool for organizing and renaming your emulators and ROM folders.

**Features:**
- Sort emulators alphabetically
- Manually reorder emulators
- Rename emulator folders
- Remove sorting prefixes
- Save changes across all related tools

---

## Recents Manager

A tool for controlling your recently played games list.

**Features:**
- Clear all recently played games
- Remove only the most recent entry
- Enable or disable recents tracking
- Per-emulator control of recents tracking

---

## Game Time Tracker

A tool that records how long you play each game and provides statistics about your gaming habits.

**Features:**
- Tracks play time for every game
- Shows play counts and session lengths
- Displays top games by play time
- Categorizes gaming stats by system
- Tracks daily gaming streaks
- Keeps a list of games you've finished with completion dates
- Allows exporting statistics to a text file
- Sorts games by most played

---

## OTA Updater

A tool for updating your system software without needing a computer.

**Features:**
- Check for MinUI updates
- Download and install updates directly
- Reinstall the current version if needed
- Check for PakUI updates
- Install Sleep Mode Fork directly from the updater

---

## Boot To

A tool that lets you select what launches automatically when you power on your device.

**Features:**
- Boot directly to MinUI (default)
- Boot to Game Switcher
- Boot to a custom collection
- Boot to a specific game
- Boot to a random game
- Boot to another tool

---

## Screen Capture

A tool for taking screenshots and recording videos of your gameplay.

**Features:**
- Take screenshots with L2+R2 button combo
- Record gameplay videos
- View and manage your captures
- Choose recording quality settings
- Rename or delete your captures

---

## YouTube Downloader

A tool for downloading videos from YouTube channels.

**Features:**
- Add and manage YouTube channels
- Download the latest videos
- Get the most recent five videos
- Channel validation
- Easy interface for video selection

---

## Moonlight

A tool that enables game streaming from a PC to your TrimUI device.

**Features:**
- Stream PC games to your handheld
- Connect to Nvidia GameStream-compatible computers
- Visual connection status indicators
- Automatic connectivity checks
- Prevents the device from sleeping during streaming

---

## Game Name Mapper

A tool that converts XML gamelists to `map.txt` files for displaying clean game names in MinUI.

**Features:**
- Extracts clean game names from XML gamelists
- Creates `map.txt` files used by MinUI for display names
- Particularly useful for arcade and Neo Geo games
- Processes all ROM directories automatically
- Hides XML files after processing

---

## PSX Multi Disc

A tool for organizing PlayStation game files and setting up multi-disc games.

**Features:**
- Create folders for multi-disc games
- Generate M3U playlists for disc switching
- Create missing CUE files for BIN files
- Support for both CHD and BIN/CUE formats
- Auto-detection of disc numbering patterns

---

## Save Options

A tool for managing and converting save files between different formats.

**Features:**
- Convert RetroArch `.srm` files to MinUI `.sav` format
- Convert MinUI saves to RetroArch format
- Toggle between SAV and SRM file formats right from the menu
- Batch convert all saves at once
- Select individual saves to convert
- View conversion results
- Automatically match saves with ROMs

**How to Install and Use Save Options:**
1. Launch Pak Manager
2. Go to the Install section
3. Select "Save Options" to install the tool
4. Once installed, go to Tools
5. Select "Save Options" from the menu

**Where to Place Your Save Files for Conversion:**
- For RetroArch to MinUI: Place your .srm files in `/mnt/SDCARD/Saves/RETROARCH/`
- For MinUI to RetroArch: Your .sav files are already in the correct location (typically in subfolders of `/mnt/SDCARD/Saves/`)

---

## System Stats

A tool that shows key system information at a glance.

**Features:**
- View current battery percentage
- Check CPU frequency
- See SD card storage usage
- Quick one-screen overview

---

## Syncthing

A tool for synchronizing files between your device and other computers.

**Features:**
- Wirelessly sync files with other devices
- Sync save files and game states
- Configure startup options
- Access via web interface
- WiFi connection monitoring
- Easy enable/disable toggle
  
  **LOGIN** - minui
  **PASS** - minuipassword

---

## RetroArch Hotkeys

New RetroArch hotkeys are available for improved usability:
- Menu+Select - Open RetroArch Menu
- Menu+L1/R1 - Load State/Save State
- Menu+R2 - Toggle Fast Forward
- Menu+Left/Right - Previous/Next Save Slot

*Thanks to GrimWTF for the config file!*

---




## Credits & Acknowledgements
PakUI stands on the shoulders of many talented individuals whose contributions, expertise, and support have made this project possible. We are deeply grateful to:

### Core Contributors
- **JackMayHoffman**  
  Developed the picker, game picker, keyboard, and game switcher binary files, along with essential tools like LEDs, WiFi, Display, and Syncthing. His mentorship and support were instrumental in launching PakUI.
- **Shaun Inman**  
  Creator of MinUI, the foundation for PakUI paks. His unparalleled knowledge and community contributions set the gold standard for custom firmware.
- **Froist**  
  For hosting and maintaining the Sleep Mode Fork files that make this feature possible.
- **kloptops**  
  Developer of TrimUI_EX, which PakUI comes bundled with. His crucial system upgrades form the backbone that enables many of PakUI's features to work seamlessly. Many thanks!
- **Nevrdid**  
  Provided the FBN core, enhanced Media Player functionality, added screenshot capabilities, and contributed to RetroArch integration.
- **Karim**  
  Developed the NDS pak, adding valuable functionality to the project.
- **Savant** (https://github.com/josegonzalez)  
  Developed the N64 and Dreamcast paks, significantly expanding PakUI's emulation capabilities. His expertise and generosity in allowing inclusion of these paks has been invaluable to the project.
- **Eronauta**  
  Added PSP support to PakUI, enabling PlayStation Portable game emulation across TrimUI devices.
- **Dandon**  
  Customized and compiled the Files.pak for PakUI, providing essential functionality to the file management system.

### Testing & Feedback
- **Ry, Lonko, and Sun**  
  Offered thorough testing and invaluable feedback that greatly refined the user experience. Thanks Sun for uploading the files!

### Visual Elements
- **Ant**  
  Designed the themes, including icons and background images.
- **Clintonium**  
  Created the Lens theme, adding a unique visual touch.
- **Jeltron and Oclain**  
  Crafted the overlays used in RetroArch.

### Community Support
- **Spruce Team**  
  Provided unwavering support and assistance and being great friends!
- **GrimWTF**  
  Provided RetroArch hotkey configuration files.
- **PortMaster Team**  
  Created the amazing PortMaster that brings hundreds of games to PakUI.
- **Russ (RetroGameCorps)**  
  Inspired our passion for retro gaming and ensured we never forgot the importance of snacks and drinks during long sessions.

### Personal Thanks
We extend our heartfelt appreciation to our families, whose support and encouragement enable us to pursue our passions and share what we love with this amazing community.
