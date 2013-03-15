module messages;
import box, fileops;

struct MsgAnalyzing {
	string name;
	int sz;
	float progress;
}

struct MsgSearchComplete {
	shared SimilarDirs[int] sim;
	shared SimilarFiles[string] simf;
	shared IFSObject[int] id2dir;
	shared IFSObject[string] fname2file;
}

struct MsgCancel {}

class Cancelled : Throwable {
	this() { super(""); }
}

struct MsgNumOfDirs { int n; }

struct MsgScanning {
	string name;
	int i;
}

struct MsgDone {
	int files, dirs;
}