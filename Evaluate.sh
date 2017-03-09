#!/bin/bash

# Printing function that attaches a label and newline.
log() {
    echo "[DIGDOG] $1"
    echo
}

# Error message on incorrect flag usage.
usage() {
    log "Incorrect usage of evaluation script. Please check all arguments, ensuring values are passed as a comma-separated list."
}

# Initialize some default options before parsing the command line arguments
specified_experiments=("Randoop" "DigDog")
projects=("Time" "Chart" "Math" "Lang")

log "Running DigDog Evaluation Script"

# Read the flag options that were passed in when the script was run.
# Options include:
    # [-i|--init] (initialize): If set, will re-do all initialization work, including
    #       cloning the defects4j repository, initializing the defects4j projects,
    #       and creating the classlists and jarlists for each project.
    # [-b|--build]: If set, will re-build the DigDog using the gradle wrapper
    # [-o|--overwrite]: If set, will remove the existing datafile before beginning
    #       to write to the file for any given experiment/project combination.
    # [-t time1,time2,...|--time time1,time2,...]: If set, will set the time limits
    #       for experiments to the given values.
    # [-e exp1,exp2,...|--experiments exp1,exp2...]: If set, overwrites the 
    #       specified_experiments to run the given experiment conditions.
    # [-p proj1,proj2,...|--projects proj1,proj2,...]: If set, overwrites the projects
    #       to run the experiments over the given values.
    # [-c|--complete]: If set, runs the complete experiments instead of the individual experiments.
    #       Runs a different number of trials and multiplies each time limit by the number of
    #       of classes in each project.
    # [-f|--faults]: If set, runs the fault experiments instead of the individual or complete
    #       experiments. Fault detection experiments do not currently work.
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -i|--init)
            init=true
            log "Found command line option: -i"
            ;;
        -b|--build)
            build=true
            log "Found command line option: -b"
            ;;
        -o|--overwrite)
            overwrite=true
            log "Found command line option: -o"
            ;;
        -t|--time)
            time_arg=true
            shift
            oldIFS=$IFS
            IFS=","
            declare -a specified_times=(${1})
            IFS=$oldIFS
            log "Times set to: [${specified_times[*]}]"
            ;;
        -e|--experiments)
            shift
            oldIFS=$IFS
            IFS=","
            declare -a specified_experiments=(${1})
            IFS=$oldIFS
            log "Experiments set to [${specified_experiments[*]}]"
            ;;
        -p|--projects)
            projects_arg=true
            shift
            oldIFS=$IFS
            IFS=","
            declare -a projects=(${1})
            IFS=$oldIFS
            log "Projects set to [${projects[*]}]"
            ;;
        -c|--complete)
            run_complete_experiment=true
            log "Complete experiments set"
            ;;
        -f|--faults)
            run_fault_detection=true
            log "Setting fault detection to true"
            ;;
        *)
            log "Unknown flag: ${key}"
            usage
            exit 1
            ;;
    esac
    shift
done

if [ $overwrite ]; then
    log "Overwrite enabled, will remove data files before metrics are recorded."
fi

# Set paths that we will use later. Specifies both the path for the
# java 1.7 file (needed for compatiblity with defects4j) and the location
# of the randoop jar that has been saved in this repository.
randoop_path=`pwd`"/experiments/lib/randoop-baseline-3.0.9.jar"
java_path=`pwd`"/experiments/lib/jdk1.7.0/bin/java"
cd ..

# If we are running first-time setup, we remove any existing randoop/digdog
# repository.
if [ $init ]; then
    if [ -d "randoop" ]; then
        log "Init flag was set and randoop repository existed, removing..."
        rm -rf randoop
    fi
fi

# Check that the digdog repository exists alongside this repo, if not,
# clone it. Either way, we briefly step inside to build the .jar file,
# then step out to the parent directory of all 3 directories (randoop,
# defects4j, randoopEvaluation) to perform most of the work.
if [ ! -d "randoop" ] ; then
    log "DigDog repository was not found, cloning it now."
    git clone https://github.com/jkotalik/randoop
fi

cd randoop

# Set up some fixed values to be used throughout the script
work_dir=proj

# Location of the DigDog jar in the DigDog repository.
digdog_path=`pwd`"/build/libs/randoop-all-3.0.10.jar"

# Ensure that we can execute the java executable in this repository.
chmod u+x $java_path

# If the build flag was set or if there is no DigDog jar,
# Build the jar from the files in that repository.
if [ $build ] || [ ! -f $digdog_path ]; then
    log "Building Randoop jar"
    ./gradlew clean
    ./gradlew assemble
fi

# Go up one level to the parent directory, so we can look for defects4j.
cd ..
log "Stepping up to the containing directory"

# If the init flag is set, we want to re-start the initial process, so
# we remove the defects 4j repository if it already exists. This is necessary
# since we will be re-cloning the repository.
if [ $init ]; then
    if [ -d "defects4j" ]; then
        log "Init flag was set and defects4j repository existed, removing..."
        rm -rf defects4j
    fi
fi

# If there is no defects4j repository sitting alongside our randoop repository, we need to perform initial set up.
if [ ! -d "defects4j" ] ; then
    log "No defects4j repository found, setting init to true."
    init=true
fi

# Perform initialization process, cloning the defects4j repository,
# initializing the repository, and installing the perl DBI used in the
# defects4j framework. This will take a while to run on the first execution.
if [ $init ]; then
    log "Preparing the defects4j repository..."
    # Clone the defects4j repository, and run the init script
    git clone https://github.com/rjust/defects4j
    cd defects4j
    ./init.sh

    # Install Perl DBI
    printf 'y\ny\n\n' | perl -MCPAN -e 'install Bundle::DBI'
    printf 'y\n\n' | perl -MCPAN -e 'install DBD::CSV'
else
    # If we already have the defects4j repository cloned, we just step inside
    log "Defects4j repository already exists, assuming that set up has already been successfully performed. If this is in error, re-run this script with the -i option"
    cd defects4j
fi

# Ensures that we can run defects4j command line tasks.
defects4j_task=`pwd`/framework/bin/defects4j

# Check out the defects4j project that is currently specified by the $project variable.
# $1: "f" or "b", indicating whether to check out the buggy (b) or fixed (f) version
checkoutProject() {
    curr_dir=$work_dir$project
    test_dir=${curr_dir}/gentests

    # If the project's working directory already exists, remove it so we can start fresh
    if [ -d "${curr_dir}" ]; then
        rm -rf $curr_dir
    fi

    # Initialize the working directory for the project
    log "Initializing working directory for ${project}${version}..."
    mkdir $curr_dir

    # Checkout and compile current project into the working directory
    # that was just created.
    $defects4j_task checkout -p $project -v ${version}${1} -w $curr_dir
    $defects4j_task compile -w $curr_dir
}

# Checkout and compile all 4 Defects4j projects, placing each into its own working directory.
# This is done during first time set up. If the evaluation script is stopped before
# this section is completed, the defects4j repository will not be initialized correctly,
# and the -i flag will need to be passed to the script to re-do the set-up.
all_projects=("Chart" "Lang" "Math" "Time")
if [ $init ]; then
    for project in ${all_projects[@]}; do
        # Set the directory of classes based on the structure of the project
        case $project in
            Chart)
                classes_dir="build"
                ;;
            *)
                classes_dir="target/classes"
                ;;
        esac

        # Create working directory and test directory for current project
        curr_dir=$work_dir$project
        test_dir=${curr_dir}/gentests
        log "Setting directories for new project: ${project}..."

        # Checkout and compile current project
        version=1
        checkoutProject "f"

        # Create the classlist and jar list for this project.
        # These are static files that will be created in the defects4j
        # directory. They are used when running Randoop/DigDog, passed as additions
        # to the classpath (<project>jars.txt) or as the list of classes to be tested
        # (<project>classlist.txt).
        log "Setting up class list for project ${project}"
        find ${curr_dir}/${classes_dir}/ -name \*.class >${project}classlist.txt
        sed -i 's/\//\./g' ${project}classlist.txt
        sed -i 's/\(^.*build\.\)//g' ${project}classlist.txt
        sed -i 's/\(^.*classes\.\)//g' ${project}classlist.txt
        sed -i 's/\.class$//g' ${project}classlist.txt
        sed -i '/\$/d' ${project}classlist.txt

        # Get a list of all .jar files in this project, to be added to the
        # classpath when running Randoop/Digdog.
        log "Setting up jar list for project ${project}"
        find $curr_dir -name \*.jar > ${project}jars.txt
    done
fi

# Determines the correct filename for the generated test handlers based
# on the current project, then changes the generated files to use that
# file naming scheme (either *Tests.java or *Test.java).
adjustTestNames() {
      case $project in 
        Lang|Math)
            mv $test_dir/RegressionTestDriver.java $test_dir/RegressionTest.java
            sed -i 's/RegressionTestDriver/RegressionTest/' $test_dir/RegressionTest.java
            mv $test_dir/ErrorTestDriver.java $test_dir/ErrorTest.java
            sed -i 's/ErrorTestDriver/ErrorTest/' $test_dir/ErrorTest.java
            ;;
        *)
            mv $test_dir/RegressionTestDriver.java $test_dir/RegressionTests.java
            sed -i 's/RegressionTestDriver/RegressionTests/' $test_dir/RegressionTests.java
            mv $test_dir/ErrorTestDriver.java $test_dir/ErrorTests.java
            sed -i 's/ErrorTestDriver/ErrorTests/' $test_dir/ErrorTests.java
            ;;
    esac
}

# Performs the necessary prep for a project before the test generation tool is run.
# This includes setting up the test directory (where tests will be output to), pointing the
# classpath toward the correct directory and jars, and setting variables accordingly.
prepProjectForGeneration() {
    case $project in
        Chart)
            classes_dir="build"
            ;;
        Closure)
            classes_dir="build/classes"
            ;;
        *)
            classes_dir="target/classes"
            ;;
    esac

    # Set up local directories and jars based on the project
    # that we are currently evaluating
    jars=`tr '\n' ':' < $1`

    # Set up the test directory
    if [ -d "${test_dir}" ]; then
        rm -rf $test_dir
    fi
    mkdir $test_dir
}

# Package the test suite generated by Randoop (in $test_dir) to be
# the correct format for the defects4j coverage task. This results
# in a .tar.bz2 archive in the working directory. Removes the test
# directory once the archive has been created.
packageTests() {
    log "Packaging generated test suite into .tar.bz2 format"
    if [ -f ${curr_dir}/randoop.tar ]; then
        rm -f ${curr_dir}/randoop.tar
    fi
    tar -cvf ${curr_dir}/randoop.tar $test_dir
    if [ -f ${curr_dir}/randoop.tar.bz2 ]; then
        rm -f ${curr_dir}/randoop.tar.bz2
    fi
    bzip2 ${curr_dir}/randoop.tar

    # Remove the existing tests.
    # If Randoop finishes early (ie, because it crashed during execution)
    # failing to delete the generated tests would cause them to
    # be mistakenly re-used on the next coverage evaluation.
    rm $test_dir/*
}

# Package the test suite generated by Randoop (in $test_dir) to be
# the correct format for the defects4j bug_detection task.
packageTestsForFaultDetection() {
    rm -f $test_dir/*Regression*
    # Remove the test driver before we attempt to fix the suite.
    # This allows the fix_test_suite task to work correctly.
    rm -f $test_dir/ErrorTest.java
    rm -f $test_dir/ErrorTests.java
    packageTests

    log "Renaming packaged tests for fault detection task"
    log "${project}-${version}f-${time}.tar.bz2"
    fault_suite_path=${curr_dir}/${project}-${version}f-${time}.tar.bz2
    mv ${curr_dir}/randoop.tar.bz2 $fault_suite_path
}

# Use the defects4j run_bug_detection task and the generated test suite to determine whether
# the test suite reveals the bug of the project version it was generated on.
countFaultDetection() {
    perl ./framework/util/fix_test_suite.pl -p $project -d $curr_dir
    log "finished fixing test suite"
    rm -rf ../randoop/experiments/fault_detection
    perl ./framework/bin/run_bug_detection.pl -p $project -d ${curr_dir} -o ../randoop/experiments/fault_detection -v ${version}f
    fault_data=`cat ../randoop/experiments/fault_detection/bug_detection`
    if echo "$fault_data" | grep -q "Fail"; then
        log "setting found_bug to true"
        found_bug=true;
    else
        log "setting found_bug to false"
        found_bug=false;
    fi
    echo "${fault_data}" >> $log_file
}

# Use the defects4j coverage task and the generated test suite to measure the line and
# branch coverage of the test suite. If the test suite was able to run, the numbers generated will
# be something other than 0, in which case they are added to the line_file and branch_file. Otherwise,
# throws out the current iteration so we can try again.
recordCoverage() {
    # Run the defects4j coverage task over the newly generated test suite.
    # Results are stored into results.txt, and the specific lines used to
    # generate coverage are put into numbers.txt
    $defects4j_task coverage -i ${project}classlist.txt -w $curr_dir -s ${curr_dir}/randoop.tar.bz2 > ${curr_dir}/results.txt
    grep 'Lines total' ${curr_dir}/results.txt > ${curr_dir}/numbers.txt
    grep 'Lines covered' ${curr_dir}/results.txt >> ${curr_dir}/numbers.txt
    grep 'Conditions total' ${curr_dir}/results.txt >> ${curr_dir}/numbers.txt
    grep 'Conditions covered' ${curr_dir}/results.txt >> ${curr_dir}/numbers.txt

    # Remove everything but the digits from the numbers.txt file. This leaves
    # a set of 4 lines, displaying:
        # Total number of lines
        # Number of lines covered
        # Total number of conditions
        # Number of conditions covered
    sed -i 's/[^0-9]//g' ${curr_dir}/numbers.txt
    cat ${curr_dir}/numbers.txt
    nums=()
    while read num; do
        log "num = $num"
        nums+=("${num}")
    done <${curr_dir}/numbers.txt
    # If the coverage number is 0, we did not successfully execute the test suite.
    # This happens when the test suite fails to compile. In this case,
    # we decrement our iteration counter and re-try this trial of test generation.
    if [ 0 -ne ${nums[1]} ]; then
        echo "${nums[1]}" >> ${line_file}
        echo "${nums[0]}" >> ${line_file}
        echo "${nums[3]}" >> ${branch_file}
        echo "${nums[2]}" >> ${branch_file}
    else
        # Record the project and time limit in a failure file so we can see what
        # has been failing if we are letting the script run for a long time.
        echo "${project}, ${time}" >> ${failure_file}
        log "i = $i"
        i=$((i-1))
    fi
}

# Runs the complete experiment (3 trials for each project/condition/time limit).
# Time limits for this experiment are multiplied by the number of classes under test
# in the project being tested.
doCompleteExperiment() {
    doCoverage $1 "Complete" 3
}

# Runs the individual experiment (5 trials for each project/condition/time limit).
doIndividualExperiment() {
    doCoverage $1 "Individual" 5
}

# Function that iterates through the various trials of each project/experiment condition/time limit,
# prepping the project, generating the test suite, packing the tests into the correct format,
# and recording the coverage of the test suite.
# $1: The experiment condition to perform (Randoop, Orienteering, ConstantMining, or DigDog)
# $2: Which experiment we should run (Individual or Complete)
# $3: The number of trials to perform for each condition/project/time limit combination
doCoverage() {
    # If the time argument was given, set those to be the time limits, otherwise
    # use the default values for the complete or individual experiments.
    if [ $time_arg ]; then
        time_limits=${specified_times[*]}
    elif [ $2 = "Complete" ]; then
        time_limits=(2 10 30 60)
    else
        time_limits=(50 100 150 200 250 300 350 400 450 500 550 600)
    fi

    
    log "Running ${2} Experiment with $1"
    log "Times are: [${time_limits[*]}]"
    exp_dir="../randoopEvaluation/experiments"
    failure_file="${exp_dir}/failure_counts.txt"

    # Remove the failure file if it already exists.
    # This file is used to log failures so we can see if issues are
    # arising while the process runs in the background.
    if [ -f ${failure_file} ]; then
        rm -f ${failure_file}
    fi

    # Make the experiment directory if it doesn't exist yet.
    if [ ! -d ${exp_dir} ]; then
        mkdir ${exp_dir}
    fi

    # Iterate through each of the defects4j projects specified, 
    # generating test suites and gathering data on the coverage of those suites.
    for project in ${projects[@]}; do
        # Set up the directories and file paths to be correct for this project.
        curr_dir=$work_dir$project
        test_dir=${curr_dir}/gentests
        line_file="${exp_dir}/${project}_${2}_${1}_Line.txt"
        log "Line file is: ${line_file}"
        branch_file="${exp_dir}/${project}_${2}_${1}_Branch.txt"
        log "Branch file is: ${branch_file}"

        # If we are overwriting, delete the existing files, otherwise we will
        # simply append to the existing file.
        if [ $overwrite ];then
            if [ -f $line_file ]; then
                rm $line_file
            fi
            if [ -f $branch_file ]; then
                rm $branch_file
            fi
        fi

        # Set the $classes_dir and $jars variables so we know where
        # to look for the jars and classes in this project.
        prepProjectForGeneration ${project}jars.txt
        for time in ${time_limits[@]}; do
            echo "TIME ${time}" >> ${line_file}
            echo "TIME ${time}" >> ${branch_file}
            # keeps track of the iterations for this combination of
            # project, condition, and time limit.
            i=1

            # If we are running the complete experiment, the time
            # limits need to be adjusted by multiplying by the number
            # of classes that the tool can generate tests for in the project.
            if [ $2 = "Complete" ]; then
                case $project in
                    Chart)
                        time=$((time*501))
                        ;;
                    Math)
                        time=$((time*520))
                        ;;
                    Time)
                        time=$((time*79))
                        ;;
                    Lang)
                        time=$((time*86))
                        ;;
                esac
            fi
    
            # Now that we have performed set up, iterated through each trial, running the test
            # generation tool, creating the test suites, and checking the coverage of the suite.
            # On each iteration, we write the coverage data to the data file.
            while [ $i -le $3 ]; do
                case $1 in
                    Randoop)
                        log "Running base Randoop with time limit=${time}, ${project} #${i}"
                        $java_path -ea -classpath ${jars}${curr_dir}/${classes_dir}:$randoop_path randoop.main.Main gentests --classlist=${project}classlist.txt --literals-level=CLASS --literals-file=CLASSES --timelimit=${time} --junit-reflection-allowed=false --junit-package-name=${curr_dir}.gentests --randomseed=$RANDOM --ignore-flaky-tests=true
                        ;;
                    Orienteering)
                        log "Running digDog with orienteering, time limit=${time}, ${project} #${i}"
                        $java_path -ea -classpath ${jars}${curr_dir}/${classes_dir}:$digdog_path randoop.main.Main gentests --classlist=${project}classlist.txt --literals-level=CLASS --literals-file=CLASSES --timelimit=${time} --junit-reflection-allowed=false --junit-package-name=${curr_dir}.gentests --randomseed=$RANDOM --weighted-sequences=true --ignore-flaky-tests=true
                        ;;
                    ConstantMining)
                        log "Running digDog with constant mining, time limit=${time}, ${project} #${i}"
                        $java_path -ea -classpath ${jars}${curr_dir}/${classes_dir}:$digdog_path randoop.main.Main gentests --classlist=${project}classlist.txt --literals-level=CLASS --literals-file=CLASSES --timelimit=${time} --junit-reflection-allowed=false --junit-package-name=${curr_dir}.gentests --randomseed=$RANDOM --weighted-constants=true --ignore-flaky-tests=true
                        ;;
                    DigDog)
                        log "Running digDog with both features, time limit=${time}, ${project} #${i}"
                        $java_path -ea -classpath ${jars}${curr_dir}/${classes_dir}:$digdog_path randoop.main.Main gentests --classlist=${project}classlist.txt --literals-level=CLASS --literals-file=CLASSES --timelimit=${time} --junit-reflection-allowed=false --junit-package-name=${curr_dir}.gentests --randomseed=$RANDOM --weighted-sequences=true --weighted-constants=true --ignore-flaky-tests=true
                        ;;
                    *)
                        log "Unkown experiment condition"
                        exit 1
                        ;;
                esac
                # Take the test suites and package them so they can be processed by
                # the defects4j coverage task, then run that to collect data on the
                # branch and line coverage for this iteration.
                adjustTestNames
                packageTests
                recordCoverage
                i=$((i+1))
            done
        done
    done
}

# Use the defects4j framework to get the list of classes that are relevant
# to a particular project and version's bug. That is, creates files that
# include the classlist and list of jars that are needed to run the test
# generation tool on the classes that touch all tests which trigger the bug
# in a specific defects4j project. These files are saved outside the project's
# working directory, in the defects4j repository, so they can be re-used when
# new project versions are checked out.
initFaultDetectionClasses() {
    # Create the classlist and jar list for this project.
    log "Setting up class list for project ${project}_${version}b"
    cd ${curr_dir}
    $defects4j_task export -p tests.trigger -o ${project}_${version}b_relevant_tests.txt
    log "exported tests"
    test_file=`cat ${project}_${version}b_relevant_tests.txt`
    class_list_file="${project}_${version}_classlist.txt"
    if [ -f $class_list_file ]; then
        rm -f $class_list_file
    fi
    for line in $test_file; do
        $defects4j_task monitor.test -t $line
        cat loaded_classes.src >> $class_list_file
    done
    cd ..
    log "Now displaying all relevant classes:"
    cat $curr_dir/$class_list_file
    if [ ! -d "classList" ]; then
        mkdir classList
    fi
    if [ ! -d "jarList" ]; then
        mkdir jarList
    fi
    mv $curr_dir/$class_list_file classList
    # Get a list of all .jar files in this project, to be added to the
    # classpath when running randoop/digdog.
    log "Setting up jar list for project ${project}_${version}"
    find $curr_dir -name \*.jar > jarList/${project}_${version}_jars.txt
}

# Performs the fault detection iteration for a given experiment condition
# across all specified projects. Does not currently work from end to end.
doFaultDetection() {
    if [ $time_arg ]; then
        time_limits=$specified_times
    else
        time_limits=(120 300 600)
    fi

    log "Running Fault Detection with $1"
    exp_dir="../randoopEvaluation/experiments"

    if [ ! -d ${exp_dir} ]; then
        mkdir ${exp_dir}
    fi

    for project in ${projects[@]}; do
        fault_file="${exp_dir}/${project}_Fault_${1}.txt"
        log_file="${exp_dir}/${project}_fault_log_${1}.txt"
        log "Fault file is: ${fault_file}"
        randoop_output_file="${exp_dir}/Randoop_output.txt"

        if [ $overwrite ];then
            if [ -f $fault_file ]; then
                rm $fault_file
            fi
        fi
        
        # Set $num_versions to the total number of versions
        # available for the current defects4j project.
        case $project in
            Chart)
                num_versions=26
                ;;
            Math)
                num_versions=106
                ;;
            Lang)
                num_versions=65
                ;;
            Time)
                num_versions=27
                ;;
            *)
                log "Unknown project"
                exit 1
                ;;
        esac
        # Iterate through each time limit, generating multiple test suites with the specified
        # tool for each version. If a bug is found, we can move on to the next version immediately.
        version=1
        for time in ${time_limits[@]}; do
            # Write the time limit and number of versions to the file once.
            echo "TIME ${time}" >> ${fault_file}
            echo $num_versions >> $fault_file

            while [ "$version" -le "$num_versions" ]; do
                # For each version, build the list of jars and the list of classes
                # based on the fixed version of a project, if we don't already have those
                # lists stored.
                jar_path="jarList/${project}_${version}_jars.txt"
                classlist_path="classList/${project}_${version}_classlist.txt"
                if [ ! -f $jar_path ] || [ ! -f $classlist_path ]; then
                    checkoutProject "f"
                    initFaultDetectionClasses
                fi
            
                # Generate tests on the buggy version of a project.
                checkoutProject "b"
                prepProjectForGeneration ${jar_path}
                i=1
                
                while [ $i -le 5 ]; do
                    case $1 in
                        Randoop)
                            log "Running Randoop (faults) with time limit=${time}, ${project} #${i}"
                            $java_path -ea -classpath ${jars}${curr_dir}/${classes_dir}:$randoop_path randoop.main.Main gentests --classlist=${classlist_path} --literals-level=CLASS --literals-file=CLASSES --timelimit=${time} --junit-reflection-allowed=false --junit-package-name=${curr_dir}.gentests --randomseed=$RANDOM --ignore-flaky-tests=true
                            ;;
                        DigDog)
                            log "Running DigDog (faults) with time limit=${time}, ${project} #${i}"
                            $java_path -ea -classpath ${jars}${curr_dir}/${classes_dir}:$digdog_path randoop.main.Main gentests --classlist=${classlist_path} --literals-level=CLASS --literals-file=CLASSES --timelimit=${time} --junit-reflection-allowed=false --junit-package-name=${curr_dir}.gentests --randomseed=$RANDOM --ignore-flaky-tests=true --weighted-sequences=true --weighted-constants=true
                            ;;
                        *)
                            log "Unknown condition in fault detection experiment"
                            exit 1
                            ;;
                    esac
                    adjustTestNames
                    packageTestsForFaultDetection
                    countFaultDetection
                    if [ "${found_bug}" = true ] ; then
                        echo $version >> $fault_file 
                        log "found failing test on ${project} ${version}"
                        i=5
                    fi
                    i=$((i+1))
                done
		version=$((version+1))
            done
        done
    done
}

# Perform the experiment specified by the given arguments.
if [ $run_fault_detection ]; then
    for exp in ${specified_experiments[@]}; do
        doFaultDetection $exp
    done
elif [ $run_complete_experiment ]; then
    for exp in ${specified_experiments[@]}; do
        doCompleteExperiment $exp
    done
else
    for exp in ${specified_experiments[@]}; do
        doIndividualExperiment $exp
    done
fi
