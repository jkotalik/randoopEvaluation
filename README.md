## DigDog

### Getting Started
Welcome to the DigDog Repository! We'll assume you're running on a linux environment. To get started, clone this repository on your system. We recommend you make a fresh directory to clone this into, since our evaluation framework will be downloading some other repositories alongside it, and interacting with those:

`mkdir <myNewDirectory>`

`cd <myNewDirectory>`

`git clone https://github.com/jkotalik/randoopEvaluation.git`

Then, step into the newly cloned directory.

`cd randoopEvaluation`

Next, run the evaluation script with your desired configuration (explained in more detail below). This script runs the test generation tools with varying time limits across Defects4J projects. Here is an example configuration that will allow partial replication of the data for the "Time" project in Defects4j, using all 4 configurations of Randoop/DigDog:

`./Evaluate.sh -i -b -o -t 50,200,350 -p Time`

To execute the script, you may need to first run `chmod u+x ./Evaluate.sh`.

This command will allow partial replication of results for the Time project. Please note that it will take a number of hours to run. To make it finish more quickly, you can specify fewer time limits or experiment conditions using the command line options. You can also run it in the background by instead running:

`nohup ./Evaluate.sh -i -b -o -t 50,200,350 -p Time &>experiments/log &` (this will record its output in `experiments/log` so you can check up on the execution from time to time as it runs)

As the script runs, it will output coverage data in a line-separated format to the `experiments` directory. These data files can then be passed to the plotting script to produce graphs and csv files of the results. More information on the naming and formatting conventions of these intermediate data files can be found below.

The data can then be used to generate graphs comparing the various tools:

`cd experiments`

`python Plot.py filename1.txt filename2.txt ... filenameN.txt`

The graph will be saved in the `experiments/plots` directory, named `'Project' 'CoverageType' Coverage Percentage.png`.

To summarize this opening example, performing the following set of commands (waiting a number of hours for the evaluation script to finish before invoking the next command) will replicate some results for the Time project's individual experiment:
`./Evaluate.sh -i -b -o -t 50,200,350 -p Time`


`python experiments/Plot.py experiments/Time_Individual_Randoop_Line.txt experiments/Time_Orienteering_Line.txt  experiments/Time_Individual_ConstantMining_Line.txt  experiments/Time_Individual_DigDog_Line.txt`


`python experiments/Plot.py experiments/Time_Individual_Randoop_Branch.txt experiments/Time_Orienteering_Branch.txt  experiments/Time_Individual_ConstantMining_Branch.txt  experiments/Time_Individual_DigDog_Branch.txt`

This yields the following data files and plots:
`experiments/plots/Time Individual Branch Coverage Percentage.png`
`experiments/plots/Time Individual Line Coverage Percentage.png` 
`experiments/Time Individual Branch Coverage Percentage.csv`
`experiments/Time Individual Line Coverage Percentage.csv`

Read on for a complete description of options and configurations for the Evaluation script.

### Further documentation of Evaluate.sh
To run the script and gather data on the performance of DigDog: `./Evaluate.sh`. You may need to change the permissions with `chmod u+x ./Evaluate.sh` first.

Flags with values should have the values as a separate, comma-separated token (without spaces). Accepted flags:
- `[-i|--init]` Performs first-time set up of the defects4j repository, including cloning, checking out the projects, and setting up the Perl DBI. This behavior is default unless the defects4j repository exists alongside this repository. Please note that this will remove any existing folders alongside this project that are named "randoop" or "defects4j".
- `[-b|--build]` Builds the digdog .jar file based on the current state of your local files. This behavior is default if there isn't already a .jar file in the expected build path of this project (`build/libs/randoop-all-3.0.10.jar`).
- `[-o|--overwrite]` If set, removes the existing data files from the `experiments/` directory before writing to the file for the first time in a particular experiment condition/project. Default behavior is to append the new values to the existing data file.
- `[-c|--complete]` If set, performs the complete experiment. Otherwise, defaults to the individual experiment. The complete experiment runs over each project with the time limit multiplied by the number of classes in the project, and only accepts experiment conditions of `Randoop` or `DigDog`.
- `[-t|--time]` Time limit values to use for experiments, in seconds, as a comma separated list of time limits. Default value for the individual experiment is 50,100,150,200,250,300,350,400,450,500,550,600. Default value for the complete experiment is 2,10,30,60.
- `[-e|--exp|--experiments]` Which experiments should be performed. If not set, defaults to run Randoop and DigDog.
    * Accepted values for the complete experiment: Randoop, DigDog
    * Accepted values for the individual experiment: Randoo, DigDog, Orienteering, ConstantMining
- `[-p|--proj|--projects]` Which defects4j projects to run the experiments over. Defaults to all four projects.
    * Accepted values: Chart, Lang, Math, Time

#### Experiments/Output:

The output from the evaluation will be placed into intermediate result files to be processed by a graphing/tabling script. The files will be located in the `/experiments` directory at the root of this repository. The files will be named according to the specific experiment, the names will be of the form `project_experiment_condition_type.txt`.

**Complete (Aka benchmark)**

Measures coverage metrics across each of the defects4j projects. Compares the DigDog implementation with all enhancements to the base Randoop configuration. Time limit is number of seconds/class. Runs 3 trials for each project/experiment/time limit. The files are named according to the following grammar:
```
- Filename ::= proj_exp_condition_type.txt
- proj ::= 'Chart' | 'Math' | 'Time' | 'Lang'
- exp ::= 'Complete'
- condition ::= 'Randoop' | 'DigDog'
- type ::= 'Line' | 'Branch'
```

The file will have a section for each time limit (defaults to 2, 10, 30, and 60s/class). Each section will start with a line that contains `TIME x`, where x is the time limit for that section. Within each section, the coverage data will be stored as pairs of lines, each pair starting with # covered on the first line, and total # on the second line.

**Individual**

Measures the metrics across each of the 4 defects4j projects. Compares the base Randoop configuration with each individual enhancement of DigDog, as well as the full DigDog implementation. Averages the coverage metrics across 5 trials, using a global time limit.
```
- Filename ::= proj_exp_condition_type.txt
- proj ::= 'Chart' | 'Math' | 'Time' | 'Lang'
- exp ::= 'Individual'
- condition ::= 'Randoop' |  'Orienteering' | 'ConstantMining' | 'DigDog'
- type ::= 'Line' | 'Branch'
```

The file will have a section for each time limit (defaults to 50, 100, ..., 600 seconds). Each section will start with a line that contains `TIME x`, where x is the time limit for that section. Within each section, the data will be stored as pairs of lines, each pair starting with # covered on the first line, and total # on the second line.

### Replication of Results:

To replicate all data for the individual experiments:

`./Evaluate.sh -b -o` 
The command listed above will run what we refer to as the "Individual experiments." Please note that it can take a number of days to finish running all of them, because it will iterate through all conditions, time limits, and projects. Specifying fewer time limits, projects, or experiment conditions can be done through the use of command line arguments, and is encouraged when attempting to replicate particular results.

To replicate all data for the complete experiments:

`./Evaluate.sh -b -o -c`
The other primary use case of the Evaluate.sh script is to run the "complete/benchmark experiments". This can be done by using the `-c` command line flag. This defaults to running both experiment conditions (Randoop and DigDog) over all 4 projects, using a variety of time limits based on the number of classes in each project. Note that running all of the complete experiment (ie, running ./Evaluate.sh -b -o -c) without using additional options to specify the experiment condition, time limits, or projects, will take even longer than the individual experiments.

### Plot Script
To run the script and create graphs for the data generated by the evaluation script:

`cd experiments`

`python Plot.py filename1.txt. filename2.txt ... filenameN.txt`

By default, a boxplot graph will be generated comparing the various tools for which the data was passed in. This graph will be saved in the `experiments/plots/` directory, named `'Project' 'Experiment' 'CoverageType' Coverage Percentage.png`.

An additonal option `-l` can be supplied to generate a line plot instead.

Percentage data used in plotting will also be output in the `experiments/csv/` directory, named `'Project' 'Experiment' 'CoverageType' Coverage Percentage.csv`.

In order for the plots to be generated successfully you may need to install matplotlib, numpy, and python-tk for python, this can be done by calling `pip install matplotlib`, `pip install numpy`, and `apt-get install python-tk`(if on Ubuntu) or `yum install python-tk`(if on Fedora).

### Table Script
To run the script and generate a csv of the averages of data generated by the plot script over various projects:

`cd experiments`

`python Table.py fileprefix1 fileprefix2 ... fileprefixN`

Where filePrefix is the name of a csv file generated by Plot.py up to the `Experiment`, but not including the coverage type, as the generated average csv will include both line and branch coverage statistics. Ex: `csv/Math Individual`.

The resulting csv will be output to `csv/Average.csv`

## Randoop

DigDog is an extension of Randoop, a unit test generator for Java.
It automatically creates unit tests for your classes, in JUnit format.

More about Randoop:

* [Randoop homepage](https://randoop.github.io/randoop/).
* [Randoop manual](https://randoop.github.io/randoop/manual/index.html)
* [Randoop release](https://github.com/randoop/randoop/releases/latest)
* [Randoop developer's manual](https://randoop.github.io/randoop/manual/dev.html)
* [Randoop Javadoc](https://randoop.github.io/randoop/api/)
