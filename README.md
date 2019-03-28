MonkeyTrack
===========

Monkey oculomotor task control program for [CED Spike2 and Power1401 system](http://ced.co.uk/indexu.shtml) that is currently in use in the laboratory of [Pablo Blazquez](http://vor.wustl.edu/) at Washington University School of Medicine. This is a very mature program that is used for all experiments performed in the lab. It is currently maintained by Dr. Blazquez. 

IMPORTANT: Please note that the requirements to use the software as-is are very specific so it is unlikely that you will be able to run the code out-of-the-box. Therefore the code is mostly provided for reference if you wish to develop your own oculomotor task control system with CED hardware. If the code helps you please consider acknowledging the Blazquez Lab or citing [my dissertation](http://openscholarship.wustl.edu/etd/144/), which contains a section about the software in Chapter 2. 

Copyright &copy; 2003 Shane Heiney

Requirements
------------

* Windows XP/7/8/10. 
* Cambridge Electronic Design (CED) data acquisition system, including Spike2 version 6 or greater and a Power1401.
* Mirror galvo system (+/- 5 V) with laser and laser driver to control brightness with digital inputs. 
* Two Kollmorgen servo motors (for optokinetic drum and vestibular table). 
* Eye position measurement system capable of outputting analog signals proportional to horizontal and vertical eye position. 
* Reward delivery system such as liquid reservoir and solenoid/pump. 

Overview
--------

#### Components ####

* `userInterface.s2s`: The Spike2 script that controls user interaction, configuration, and display.
* `taskSequencer.pls`: The Power1401 sequencer file that provides low-level timing and sequencing of the task, including checking for the eye to be on target. 
* `include\uservars.s2s`: User-specific configuration file that defines certain constants and variables for a particular user/rig combination.
* `analysisEnvironment.s2s`: Spike2 script that provides a pipeline for post-processing, analyzing, and exporting data acquired using MonkeyTrack. 

The software shares features with other programs used in behaving monkey research but was written to work with the equipment used in the Blazquez Lab. Briefly, the program generates all of the digital and analog signals required to control a mirror galvo system for moving a laser target that is projected in front of the monkey and two servomotors for rotating the monkey and an optokinetic drum. It operates by monitoring the monkey’s eye position relative to the laser target and rewarding the monkey for looking at the target as it moves around the screen according to the particular task being performed. The criterion for accepting that the monkey is correctly following the target is that the monkey’s eye position remains within an invisible "window", specified in degrees, that surrounds the target.

#### Architecture of program ####

The task control program was written for the Spike2 recording system, a data acquisition solution sold by Cambridge Electronic Design (CED) that offers excellent data acquisition performance for electrophysiological experiments. Acquisition is handled by a dedicated device (1401) that connects to a PC running the Microsoft Windows operating system and running a software package called Spike2. The base system provides 8 channels of waveform input via analog to digital converters, 8 TTL inputs for event-based data (timestamps), 4 channels of waveform output via digital to analog converters, and 8 TTL outputs. CED offers access to the instruction set of the 1401 using a programming interface with a low level language resembling assembly language (referred to as the "sequencer"). Additionally, the Spike2 software running on Windows has a higher level scripting language (referred to as the "script") that can be used to customize data display, analysis, and communication with the 1401.

The task control program was designed to make use of the distributed processing capabilities offered by the CED 1401 and Spike2 system. The bulk of the intensive processing takes place on the CPU of the 1401, which is much more robust than MS Windows and is optimized for high performance during data acquisition. The 1401 has limited multithreading capabilities so the task control program running on the sequencer mostly consists of a main loop that handles the timing of the sequence of events in the task, and several side loops that control the individual tasks, monitor the monkey’s performance (i.e., checking that the monkey is looking at the target), and perform auxiliary functions. Once initialized these loops run on the 1401 completely independently from the Spike2 script running on the PC, which allows the task to continue to run without interruption even if the PC crashes. This provides a much needed failsafe when performing tasks that require interaction with servo-controlled motors, such as for a vestibular table.

The script running on the PC primarily serves as a user interface (UI) for the sequencer, allowing the investigator to set task parameters, calibrate the monkey’s eye position, and manipulate how the data are displayed during sampling. In addition, the script performs some basic online detection routines to, e.g. display the monkey’s eye position in 2- dimensional space, detect the occurrence of saccades, and detect spikes in the extracellular waveform using a manually set amplitude window.

#### Oculomotor tasks controlled by the program ####

The program was designed to be flexible, so new tasks can be added with relative ease. Each task consists of a side loop in the sequencer that is conditionally called by the main loop if the user selects that task. Depending on the task, the program outputs analog signals via up to 4 DACs to control the position of the laser, optokinetic drum, and/or primate chair. Any mirror galvo laser system with control voltages within +/-5 Volts is supported. The program is written to work with Kollmorgen servomotors for drum and chair movement, but could be relatively easily modified to provide analog control of any servomotor. In addition to the analog signals, the program also outputs three digital (TTL) signals for switching the laser, optokinetic drum light, and reward solenoid on and off. The current version of the program implements nine different tasks, with most having many variations available. The following tasks are supported.

1. Fixation of laser at up to 9 different locations (center, right, up-right, up, up-left, left, down-left, down, down-right).
2. Saccades starting at the center and going to peripheral locations in 8 different directions (right, up-right, up, up-left, left, down-left, down, down-right). The task can also be configured for saccades starting at peripheral locations and going to the center or for "out-and-back" saccades, where the monkey makes a saccade to a peripheral location and then back to the center. In addition, any arbitrary horizontal or vertical offset can be added to the saccade start point, allowing the user the ability to program saccades to or from any location within the range of the laser.
3. Sequential saccades starting at any arbitrary location and moving along a straight horizontal or vertical line, in steps specified by the user, to a final location. The user has the option of rewarding the monkey on each step or only at the completion of an entire sequence.
4. Ramp or step-ramp pursuit in 8 directions. The task can be configured for centrifugal, centripetal, or "full-length" (from one side to the other) pursuit from any arbitrary start point.
5. Sinusoidal pursuit at any displacement and frequency. Both horizontal and vertical pursuit can be performed at any positional offset.
6. Sinusoidal VOR with or without target at any displacement and frequency supported by the servomotor.
7. Sinusoidal VOR suppression at any displacement and frequency supported by the servomotor.
8. Sinusoidal optokinetic stimulation (OKS) and fixation during whole field stimulation (F-WFS) at any displacement and frequency supported by the servomotor.
9. A predictive target interception task, wherein the monkey must make a saccade to a location predicted by the motion of a pursuit target and optionally pursue the target after acquiring it.

Fixation and hold times of any duration can be specified by the user, with the option of randomizing the times. The sinusoidal tasks are generally run continuously, though a single trial option is available, and the monkey is rewarded for keeping its eye on the target for a period of time specified by the user. All other tasks are run on a trial-by-trial basis, with the option of pseudo-randomizing the target direction on each trial or having the monkey perform blocks of identical trials.

#### Layout of UI ####

The user interface consists of a toolbar and three windows. The main window occupies 70% of the screen and displays a time view of the different data channels being acquired. A second window displays an XY plot of the horizontal and vertical positions of the target, target window, and monkey’s eye. This display updates every 20 ms and displays the last 10 samples from the eye position data, giving a 200 ms "snake" of the eye trajectory, like the tail on a comet. The user can toggle between this "short snake" and a custom "long snake" length, which can be helpful for monitoring the history of eye positions during the spontaneous (i.e., outside the context of a task) eye movements that were used extensively in [Heine et al. J Neurosci 2010](http://www.ncbi.nlm.nih.gov/pubmed/21159970). This allows the user to ensure that the fixation points for spontaneous eye movements cover the entire oculomotor range of the monkey. The third window displays a log containing both the overall and task- specific performance of the monkey.

The user interacts with the program by clicking buttons on a toolbar above the windows. Keyboard shortcuts are extensively used and most buttons can be "clicked" by pressing the key corresponding to the underlined letter in the button name. There are buttons to start and pause the currently running task, calibrate the eye, toggle acquisition of the raw extracellular neuronal signal (to save disk space if no neuron is isolated), set general parameters, and select individual tasks to run. Clicking some buttons, such as the "Eye Params" or individual task buttons (e.g. "Saccade"), brings up a dialog box with fields to update parameters. Most of the parameters pertain to the calibration of the eye signal, such as scale, offset, and crosstalk. These values are automatically set during the calibration routine but can be modified as needed from this dialog. In addition, each animal has a configuration file that stores calibration values from day to day and is loaded when the user selects the animal’s name from the dropdown list in this dialog. Miscellaneous parameters for the reward system and eye display ("snake length") are also set from this dialog.

Tasks are started by clicking the button corresponding to the task the user wishes to run, modifying task parameters as desired, and clicking the `RUN` button. If the user only wishes to modify the task parameters and save them for later execution, the `Save` button can be pressed. If the user presses `Cancel` all changes are forgotten and the task is not executed. Each task has its own configuration values for general task parameters such as intertrial interval (ITI), fixation and hold times, and reward size, which are saved in separate variables than the general task parameters for other tasks. This allows the user to, e.g., specify different reward sizes for saccades than for ramp pursuit without needing to modify the values each time a different task type is run. 

In addition to the task control interface, all functionality provided by Spike2 is available while the task control program is running.

#### Additional features ####

Throughout the development of the program a number of improvements were made to the reward system in order to facilitate training. The first is an option to automatically increment the reward size on each successful trial, up to a maximum of 10 consecutive good trials. After 10 successful trials the reward size resets to its base level. This addition was instrumental in increasing the perseverance of the squirrel monkeys. Another addition was inspired by the success of jackpot lotteries. The user specifies two reward sizes, one large one small, and a value indicating the number of trials out of 100 in which the large reward will be delivered. This encourages the monkey to keep working for small rewards in anticipation of the large reward and can extend the number of trials that a monkey performs before becoming satiated. Lastly, as part of the system for monitoring overall monkey performance, the program has the ability to monitor the cumulative volume of reward dispensed in an experimental session, allowing the investigator to adjust the reward size as needed to maximize the number of trials performed.

Another improvement that was made throughout the program development was the addition of a second "task window" that can be set to a different size than the initial "fixation window". This allows the user to specify a strict requirement for the monkey to fixate the initial target position while giving some leniency in how closely the eye tracks the target during the performance of the task, e.g. so the monkey is still rewarded despite natural variability in the precision of the movement, and neurological problems such as hypometric or hypermetric eye movements can be studied while still rewarding the animal’s effort to perform the task.

Further Reading
---------------

1. Heiney, Shane, "Roles Of Inhibitory Interneurons In Cerebellar Cortical Processing For Oculomotor Control" (2010). All Theses and Dissertations (ETDs). Paper 144.
http://openscholarship.wustl.edu/etd/144
2. Heine SA, Highstein SM, Blazquez PM (2010) Golgi Cells Operate as State-Specific Temporal Filters at the Input Stage of the Cerebellar Cortex. J Neurosci 30:17004–17014. 
[[Pubmed]](http://www.ncbi.nlm.nih.gov/pubmed/21159970)
3. Heiney SA, Blazquez PM (2011) Behavioral responses of trained squirrel and rhesus monkeys during oculomotor tasks. Exp brain Res 212:409–416. 
[[Pubmed]](http://www.ncbi.nlm.nih.gov/pubmed/21656216)

