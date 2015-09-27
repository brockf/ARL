ARL
===

Run a visual Abstract Rule Learning (ARL) study in Matlab with minimal configuration. This is useful for developmental psychologists who want to examine infants' ability to learn abstract rules from simultaneously-presented visual stimuli.

Infants are habituated to randomly-generated sequences matching a common rule (ABB, ABA, or AAB) and then, after habituating, tested on their ability to discriminate novel sequences of novel images that either match the habituated rule ("familiar trials") or matched a different rule ("novel trials.") Infants' looking times at test are compared between familiar and novel trials to see whether they discriminated them.

The sessions can be coded online using the keyboard, and all stimuli, timing options, and orders are easily configurable.

## How to use ARL

### Download ARL

* Download ARL.m and the example "rule-shapes*" and "rule-dogs*" study folders
* Create a folder in your Matlab directory and place these files inside of it
* Add this folder to your list of Matlab paths

### Create a new study

* Copy an example study folder into a subfolder of your main ARL directory
* Modify `config.txt` with the configuration options for the new study using Excel. Save as a tab-delimited text file.
* Modify the stimuli in the `stimuli` sub-folder.

### Run a session

* Load Matlab
* Type `ARL` in the command prompt
* Select your new study folder and click "Open"
* Follow on-screen prompts (e.g., enter the experimenter's name, infant's subject code, age, etc.)
* Code the infant's looking using the CenterArrow key. Press this key when the infant is looking and release the key when the infants stops looking.
* A log for the session will be created in the `logs` sub-folder
* A session file (with looking time results, participant details, and session metadata) will be created in the `sessions` sub-folder

## Author, Copyright, & Citation

All original code written by and copyright (2014), [Brock Ferguson](http://www.brockferguson.com). I am a researcher at Northwestern University study infant conceptual development and language acquisition.

You can cite this software using:

> Ferguson, B. (2015). Abstract Rule Learning (ARL) for Matlab. Retrieved from https://github.com/brockf/ARL.

This code is **completely dependent** on the [PsychToolbox library for Matlab](http://psychtoolbox.org/PsychtoolboxCredits). You should absolutely cite them if you use this library:

> Brainard, D. H. (1997) The Psychophysics Toolbox, Spatial Vision 10:433-436.

> Pelli, D. G. (1997) The VideoToolbox software for visual psychophysics: Transforming numbers into movies, Spatial Vision 10:437-442.

> Kleiner M, Brainard D, Pelli D, 2007, "What's new in Psychtoolbox-3?" Perception 36 ECVP Abstract Supplement.
