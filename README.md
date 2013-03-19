## Undup

Storage space visualization and duplicate files/directories search utility.

![screenshot][1]

### Usage:
Scan one or more drives by pressing "New Scan", choosing path to your drive
and giving a name to each scan. Then select one or more scans to visualize their
contents and search for duplicates.

Your selected drive scans are shown as collection of boxes, each box representing a file or a bunch of small files & folders (denoted as ...). Hover your mouse over a box and you'll see the pathname of it below. Each folder in the path to current object will be shown as a colored rectangle, and size of that folder will be given in the same color. 

### Colored boxes:

After you press "Search" the program will search for similar files and folders, and after it's done similar objects will be colored in three colors:

Red - this is an old file or folder, somewhere there is a newer version of it.

Yellow - this is a redundant copy, somewhere an equal copy of this object exists.

Green - this is a newest copy, somewhere an older version of it exists.

Hover a colored box and other copies of it will be highlighted. 

Double click a colored box and you'll see a window showing exactly what is found for this object.


### Principles of duplicates search:

When comparing two objects (files or directories) there are 4 possible outcomes:

1) they are equal, i.e. direct copies of each other.

2) One is an older version of the other.

3) One is a newer version of the other.

4) They are just different.

Two files of same name considered equal if they have the same size and same modification time (rounded up to 2 seconds). File contents are not being compared, just metadata: name, modification time and size. If two files of same name and same modification time have different sizes they are considered different (outcome 4). Files with same name and different modification times are related by time: one is considered a newer version of the other.

When comparing two directories following rules applied:

If they have same number of objects (files & folders), and for each object in one folder there is an equal copy of it in another folder, then two folders are considered equal.

If all objects of one non empty folder have equal or newer versions in the second folder, then the second folder is considered a newer version of the first one.

If two folders contain files considered different (same name & time but different sizes) or both folders contain files not present in the other folder, then these two folders are considered different.

### Which objects get compared:

Directories and big files are grouped by name similarity, and comparison is performed between all objects inside each group. A few objects form a group if one of them has a name which serves as a prefix for names of all the others. E.g. "cats", "cat01", "cat", "cat2" and "cats3" will get into one group but "more cats" will not land into this group.

### Technical details
Written in D language. Built using DMD 2.062. Uses DFL for GUI, take it from https://github.com/Rayerd/dfl (only needed for compiling, the binary does not need any additional dlls). 

DFL (C) 2004-2010 Christopher E. Miller

License: MIT (see license.txt).

[1]: https://bitbucket.org/infognition/undup/downloads/undup500.jpg