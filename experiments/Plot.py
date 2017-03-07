# If you get an error saying that there is no module matplotlib
# you will need to install it, run `pip install matplotlib`,
# if you don't have pip, run `sudo yum install python-pip python-wheel`
import matplotlib.pyplot as plt
import numpy, re, sys, os
import matplotlib.patches as mpatches

# Times that will be read from given experiment
times = []

# Colors for pyplot
colors = ['pink', 'lightblue', 'thistle', 'lightgreen', 'paleturquoise', 'lightcoral']

# Marker codes for pyplot
markers = ['o', 's', 'D', '^', 'p', '*']

# Linestyles for pyplot
linestyles = ['-', '--', ':', '-.']

# string	fileName 			name of file from which to read data
# Reads the coverage data stored in fileName.txt
# Returns 3-tuple storing (title of data, experiment condition {complete or individual}, data), the data in the
# return tuple is a list whose elements are lists of coverage percentages pertaining to the time limits in times
def readData(fileName):
	f = open(fileName, 'r')

	# Extract information from filename
	fileName = re.split('/', fileName)[-1]
	project, exp, condition, metric, ext = re.split('[_.]', fileName)

	
	# Store the data in the format timeLimit: [covered[], total]
	data = []

	lines = f.readlines()


	timeIndex = 0
	totalLines = 0
	i = 0
	while i < len(lines):
		line = lines[i].lstrip().rstrip()
		if "TIME" in line:

			# TODO: Generalize to work when different datasets have different upper time limits
			time = int(line.split(' ')[1])

			if not time in times:
				times.append(time)

			data.append([])

			# Set time to int in header 'TIME 5'
			timeIndex = times.index(time)

			i += 1
			line = lines[i].lstrip().rstrip()

		# Set totalLines for this time limit
		totalLines = int(lines[i + 1])

		# Add to lines covered
		data[timeIndex].append(float(line) * 100 / totalLines)

		i += 2

	title = '%s %s %s Coverage Percentage' % (project, exp, metric,)
	return (title, condition, data)


# list[list]	lst 			List of lists of any type
# Returns a 1 dimensional interspersion of the lists
# Ex: intersperse([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
# 	  returns [1, 4, 7, 2, 5, 8, 3, 6, 8]
def intersperse(lst):
	return [val for group in zip(*lst) for val in group]


# string		title 			Title to be used in the saving of the chart
# list[String]	seriesLabels	A list of the dataSeries' names
#								Ex: ['Randoop', 'Orienteering']
# list[list]	lst 			A list of lists, each inner list contains 10 lists
#								The innermost lists contain the information for one boxplot
# A plot is generated with boxplots comparing each of the datasets within lst
# This plot is saved to `title`.png
def boxplot(title, seriesLabels, lst):
	combined = intersperse(lst)
	positions=[i for i in range(len(times) * len(lst))]
	bplot = plt.boxplot(combined, positions=positions, patch_artist=True)

	# Set colors for dataset labels for the legend
	patches = []
	for i in range(len(lst)):
		color = color = colors[i % len(lst)]
		patches.append(mpatches.Patch(color=color, label=seriesLabels[i]))

	axes = plt.axes()
	axes.set_xticklabels(times)
	axes.set_xticks(getLabelPositions(positions, len(lst)))

	plt.legend(borderaxespad=1, handles=patches, fontsize=10)


	# Color the boxplots in colors corresponding to their dataset
	for i in range(len(bplot['boxes'])):
		patch = bplot['boxes'][i]
		color = colors[i % len(lst)]
		patch.set_facecolor(color)

# list[int]		dataPositions	A list containing the positions in which the data will be plotted
# int			numSeries 		The number of data series to be plotted
# Returns a list of positions indicating where the labels are to be placed
# this serves to place the label for related boxplots in the middle of them
def getLabelPositions(dataPositions, numSeries):
	labelPositions = []

	currSum = 0
	for i in range(len(dataPositions)):
		if i % numSeries == 0 and i != 0:
			labelPositions.append(currSum / float(numSeries))
			currSum = 0

		currSum += dataPositions[i]

	labelPositions.append(currSum / float(numSeries))
	return labelPositions

# string		title 			Title to be used in the saving of the chart
# lst[String]	seriesLabels	A list of the dataSeries' names
#								Ex: ['Randoop', 'Orienteering']
# list[list]	lst 			A list of lists, each inner list contains 10 elements
#								that are the median coverage values of that dataset
# A plot is generated with lineplots comparing each of the datasets within lst
# This plot is saved to `title`.png
def lineplot(title, seriesLabels, lst):
	# Set colors for dataset labels for the legend
	patches = []
	for i in range(len(lst)):
		color = color = colors[i % len(lst)]
		patches.append(mpatches.Patch(color=color, label=seriesLabels[i]))
	
	plt.legend(borderaxespad=1, handles=patches, fontsize=10)

	for i in range(len(lst)):
		series = lst[i]
		seriesIdx = i % len(lst)
		plt.plot(times, series, marker=markers[seriesIdx], linestyle=linestyles[seriesIdx], color=colors[seriesIdx])

# list[list]	lst 			List of lists, the inner lists contain coverage percentages
# Returns a list of the median coverage percentage of the inner lists
def getMedians(lst):
	lst = [sorted(x) for x in lst]
	return [(((x[len(x) / 2] + x[len(x) / 2 + 1]) / 2.0) if len(x) % 2 == 0 else x[len(x) / 2]) for x in lst]

# list[list or elem]	lst 			List of lists or elements to be flattened
# Returns a flattened list in which inner lists have simply been flattened to the component elements
# Ex: flatten([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
# 	  returns [1, 2, 3, 4, 5, 6, 7, 8, 9]
def flatten(lst):
  out = []
  for item in lst:
    if isinstance(item, (list, tuple)):
      out.extend(flatten(item))
    else:
      out.append(item)
  return out

# list[list or elem]	lst 			List of lists or elements
# Returns the maximum value stored in the list, including
# elements that may have been contained in inner lists
def getMaxPoint(lst):
	return sorted(flatten(lst), reverse=True)[0]

# list[float]			lst 			List of floats
# Returns the average value of lst as a float rounded to 2 decimal places
def avg(lst):
	return int(100 * sum(lst) / len(lst)) / 100.0

# boolean				isLinePlot		Whether or not a line plot is to
#										be drawn, if false, box plot is drawn
# string 				title 			Title of plot
# list[string] 			seriesLabels	The names of the dataseries
# list[list]			data 			The dataseries to be plotted
# boolean 				isSmallTest		Whether or not Randoop's small tests are being compared against
# Outputs a plot of data to file `title`.png
def plot(isLinePlot, title, seriesLabels, data, isSmallTest):
	plt.figure()
	
	if isSmallTest:
		seriesLabels[0] = seriesLabels[0] + '+small-tests'

	if isLinePlot:
		data = [[avg(y) for y in x] for x in data]
		lineplot(title, seriesLabels, data)
	else:
		boxplot(title, seriesLabels, data)

	plt.xlabel('Global Time Limit (s)')
	plt.ylabel('Coverage (%)')
	plt.ylim(0, getMaxPoint(data) * 1.1)

	# Save plot
	if isSmallTest:
		plt.savefig('smalltestData/plots/%s' % title, format='png')
	else:
		plt.savefig('plots/%s' % title, format='png')

# int					numFiles		Number of files from which the data was read
# string 				title 			Title of output file
# list[string] 			seriesLabels	The names of the dataseries
# list[list]			data 			The dataseries to be plotted
# boolean 				isSmallTest		Whether or not Randoop's small tests are being compared against
# Outputs the data to file in csv format to `title`.csv
def outputCsv(numFiles, title, seriesLabels, data, isSmallTest):
	try:
		os.remove('smalltestData/csv/%s.csv' % (title,))
	except OSError:
		pass

	f = open('smalltestData/csv/%s.csv' % (title,), 'w+')

	avgs = [[avg(y) for y in x] for x in data]

	print >> f, 'Time,',
	for i in range(numFiles):
		print >> f, '%s,' % seriesLabels[i],

	print >> f

	for i in range(len(times)):
		print >> f, '%s,' % times[i],

		for j in range(numFiles):
			print >> f, '%s,' % avgs[j][i],

		print >> f

def main():
	# Set line plot option
	isLinePlot = False
	isSmallTest = False
	for i in range(2):
		if '-l' in sys.argv:
			isLinePlot = True
			sys.argv.remove('-l')
		elif '--line' in sys.argv:
			isLinePlot = True
			sys.argv.remove('--line')
		elif '-s' in sys.argv:
			isSmallTest = True
			sys.argv.remove('-s')
	
	# Get the numbre of files to containing data
	numFiles = len(sys.argv) - 1

	titles, seriesLabels, data = ([0 for i in range(numFiles)] for j in range(3))
	# Extract info for plot from the filename arguments
	for i in range(numFiles):
		fileName = sys.argv[i + 1]

		titles[i], seriesLabels[i], data[i] = readData(fileName)

	# Cut down all datasets to the size of the smallest dataset
	minLength = len(data[0])
	for i in range(len(data)):
		minLength = min(minLength, len(data[i]))

	for i in range(len(data)):
		global times
		times = times[:minLength]
		data[i] = data[i][:minLength]


	# Plot the data
	plot(isLinePlot, titles[0], seriesLabels, data, isSmallTest)

	# Save csv of data
	outputCsv(numFiles, titles[0], seriesLabels, data, isSmallTest)

if __name__ == '__main__':
    main()