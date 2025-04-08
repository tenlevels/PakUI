## PakUI
A collection of paks/tools for MinUI ONLY - PakUI is a full set and most paks talk to one another. You will need the full release on a fresh card and new install. Fresh format card ONLY. Sorry PakUI is not compatible with other MinUI variants or forks.

## Compatibility
- **MinUI ONLY**  
- **TrimUI Brick**  
- **TrimUI Smart Pro** (note: RetroArch coming soon for TSP) 
- More devices coming soon!

## Installation

To get started with PakUI, follow these easy steps:

1. **Prepare Your SD Card:**  
   Format a fresh SD card to fat32. Must use fresh format card and fat32 only.

2. **Extract & Install:**  
   Unzip the entire release package—**do not unzip individual folders inside**. Make sure that all folders and hidden files are preserved. The release includes both MinUI and TrimUI_EX (NOTE: this changes your device and upgrades some internal files needed. A fresh format card is required and ALL files in the release for this reason) along with everything you need for a complete installation. Copy all the files and folders directly onto your formatted SD card. Paks are not compatible with other MinUI variations/forks and the full package needs to stay together for everything to work.

- **Your SD card should look like this**
  
   ![PakUI_install_files](https://github.com/user-attachments/assets/307a4bef-f774-49c3-b3e9-171e175d4359)


4. **Add Your Own Files:**  
   Once the file transfer to your SD card is complete, simply add your games and BIOS files to the appropriate folders.

5. **Boot Up:**  
   Insert the SD card into your TrimUI Brick or TrimUI Smart Pro, then power on your device and let the magic happen!

It's that simple—enjoy and happy gaming!


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
- Some users report success by replacing the included Portmaster folder in Apps with the TrimUI release found at: https://github.com/PortsMaster/PortMaster-GUI/releases

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

- **kloptops**  
  Developer of TrimUI_EX, which PakUI comes bundled with. His crucial system upgrades form the backbone that enables many of PakUI's features to work seamlessly. Many thanks!

- **Nevrdid**  
  Provided the FBN core, enhanced Media Player functionality, added screenshot capabilities, and contributed to RetroArch integration.

- **Karim**  
  Developed the NDS pak, adding valuable functionality to the project.

- **Froist**
  For hosting and maintaining the Sleep Mode Fork files that make this feature possible.

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







UPDATES




# PakUI v1.2

# HOW TO UPDATE:
This is a feature and bug fix update. There are two ways to update:

**Option 1: Fresh Install (Recommended)**
* Format a fresh SD card to fat32
* Extract the entire PakUI v1.2 package to your card
* Follow the standard installation instructions

**Option 2: Keep Your Files**
* Back up your SD card
* You can keep your Roms, Bios, Saves, and userdata folders
* **Important:** BitPal is updated and located in the Roms folder - allow these files to be overwritten or merged when prompted
* **Warning for Emulator Sort users:** If you've used Emulator Sort or renamed your ROM folders, you'll need to rename the new version of BitPal's folders to match your custom folder structure
* Extract the PakUI v1.2 package and replace all other files

**Note:** OTA updates are still in development and not yet supported

## NEW FEATURES

### PSP Support (New!)
* **PSP Emulation:** Added support for PlayStation Portable games
* **TrimUI Smart Pro Users:** PSP works on TSP but the menu and system scaling needs improvement - games are playable but the interface may look off
* **Special Thanks to Eronauta** for adding PSP support to PakUI!

### New Tools (New!)
* **Boxart Renamer Tool:** Automatically rename your boxart images to match your ROMs
  * Import boxart from Miyoo or other devices by placing them in the `.res` folder
  * Process all systems at once or select specific systems to rename
  * Shows detailed statistics about renamed files
  * Ensures proper naming format for MinUI compatibility (filename.extension.png)

* **Thanos Tool:** A perfectly balanced tool for your gaming collection
  * Snap your fingers and watch the magic happen
  * Brings balance to your universe (of games)
  * Don't worry - the Avengers can always undo what's been done
  * A fun surprise for Marvel fans

### PortMaster Improvements
* **Better Installation:** Updated to install version directly from website
* **Runtime Support:** Install runtime files for better compatibility
  1. Launch PortMaster
  2. Go to Options
  3. Select Runtime Manager
  4. Choose Download All
* **Integration Improvements:** 
  * PortMaster now supported by BitPal for challenges and missions
  * Game Time Tracker now records time spent in PortMaster games

### BitPal Improvements
* **Friendlier Companion:** BitPal no longer downgrades mood or guilt-trips if you complete a mission within 5 minutes before exiting
* **Better Port Support:** Full integration with PortMaster games for tracking and missions

## FIXES
* **PICO-8 Time Tracking:** Fixed time tracking in BitPal for both PICO-8 games and Splore
* **Game Switcher:** Fixed glitch when exiting back to the game list from a game
  * When using shortcuts to access Game Switcher, simply wait for MinUI to fully load before pressing d-pad buttons
  * This prevents list jumping issues
* **Game Switcher Controls:** Removed menu as shortcut option and replaced with select and start
* **Emulator Sort:** Fixed issue where sorting emulators would break BitPal and Custom Collections game paths




# PakUI v1.1

# HOW TO UPDATE:
This update requires either a fresh install or you can keep your Roms, Bios and Saves folder. This is a BIG update! And prepares us for OTA PakUI updates moving forward!


## Sleep Mode Support (New!)
* **Community-Requested Feature:** Added in response to overwhelming community requests to sidestep the notorious "limbo bug"
* **Special Thanks to Froist** for hosting and maintaining the Sleep Mode Fork files that make this feature possible! Currently you must download his MinUI fork using the OTA Update tool found in Pak Manager.
* **Install Sleep Mode Fork:** 
  1. Launch the OTA Updater
  2. Select "Install SleepModeFork"
  3. Follow the on-screen prompts

* **How Sleep Mode Works:**
  * Screen turns off immediately when sleep is activated
  * LED lights will stay on for 2 minutes, then turn off when deep sleep begins
  * Simply press the power button to wake your device
  * Sleep mode works in the MinUI menu and with minarch games
  * Not yet compatible with Paks or RetroArch
  * You can always revert to stock MinUI through the OTA Updater


## PortMaster Support (New!)
* **Play Hundreds of Games:** Now includes PortMaster with two types of games:
  * **Ready To Run Ports:** Many free games you can download and play immediately
  * **All Ports:** Ports that may require additional game files from the original game
* **Getting Started:** 
  1. Launch Pak Manager
  2. Go to the Gaming section
  3. Select "PortMaster" to install
  4. Open PortMaster from your Tools menu
  5. Browse, download, and enjoy!
* **Troubleshooting Tips:**
  * If Ports or PortMaster has trouble working, go to Options → Runtime Manager → Download All. This combined with the latest update should resolve most issues.
  * The first time you launch a game with PortMaster, it may take a little longer to start. Please be patient.
  * Ports not found in the "Ready To Run Ports" section will require additional files from the original game. Check the Port's information page or visit the PortMaster website for details on required files.
* **NOTE:** Please do NOT rename your PORTS rom folder. It must stay PORTS for now. We will try to resolve this soon.
* **Thank You** to Kloptops and the entire PortMaster team for creating such an amazing tool that we're excited to include in PakUI!


## Save System Improvements
* **Save Options Tool:** Renamed from Save Converter
* **SRM Save Toggle:** Switch between SAV and SRM file formats right from the menu
  * Use "Use SRM saves" to enable SRM files (requires Sleep Mode Fork)
  * Use "Use SAV saves" to switch back to the default format

## How to Install and Use Save Options
1. Launch Pak Manager
2. Go to the Install section
3. Select "Save Options" to install the tool
4. Once installed, go to Tools
5. Select "Save Options" from the menu

## Where to Place Your Save Files for Conversion
* For RetroArch to MinUI: Place your .srm files in `/mnt/SDCARD/Saves/RETROARCH/`
* For MinUI to RetroArch: Your .sav files are already in the correct location (typically in subfolders of `/mnt/SDCARD/Saves/`)




## SwtichOS disabled
  * Currently disabled this feature out of box. The purpose was mainly to support spruce so we will wait for that release to bring it back

## New RetroArch hotkeys
  * Thanks to GrimWTF for the config file! Will post what they are soon




# PakUI v1.0.1

**Fresh install** use PakUI_v1.0.1 - **_IMPORTANT_** You **MUST** start with a fresh formatted fat32 card. With nothing installed on it.
**Update** use update_to_v1.0.1 for latest files for Emus and Scraper

## Save System Improvements - Thank you Ry for helping me understand saves!
- **Fixed Saves**: Fixed save file issues that were causing problems.
- **Auto Convert SRM Files**: Drop your SRM files into `/mnt/SDCARD/Saves/RETROARCH` and they'll automatically convert to MinUI save files.
- **Better Save Converter**: Improved the standalone save converter tool if you prefer using that instead.

## System Improvements
- **Smarter Game Launching**: Universal launcher now tries different cores if your first choice doesn't work. Set minarch or RetroArch as your launcher and it'll cycle through cores from your core.txt file.
- **Organized Core Location**: MinUI cores now live in `/mnt/SDCARD/Emus/tg5040/minui_cores`. You can delete RetroArch completely if you don't use it.
- **RetroArch Save Button**: Changed RetroArch QuickSave from a tap to a 2-second hold, getting ready for sleep mode.

## Scraper Updates
- **Start Fresh Option**: You can now delete all images for a system when scraping to change styles.
- **Better Image Finding**: Improved name matching (but still working on it). Tip: Boxart usually gives better results than snaps.

## Sleep Mode (Work in Progress)
- **Not Included Yet**: Sleep mode is NOT included in this release, just preparing for future support.
- **Current Compatibility**: If you added the sleep files now, sleep would work when in the MinUI menu and when launching games through MinUI, but not yet with RetroArch or paks.
- **Testing Phase**: I've been testing sleep mode files provided by Murtazza - they work well in test environments.
- **Distribution Policy**: I won't include these files with PakUI unless Shaun (creator of MinUI) officially adds them. This is my personal decision to respect the original developer's choices.
- **Alternative Access**: If Murtazza or someone else hosts these files, I'll provide links and installation instructions once everything is ready.
- **Development Status**: Still working on sleep mode compatibility for RetroArch and paks.