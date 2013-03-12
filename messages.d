module messages;
import box;

struct MsgAnalyzing {
	string name;
	int sz;
	float progress;
}

struct MsgSearchComplete {
	shared SimilarDirs[int] sim;
	shared SimilarFiles[string] simf;
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

struct MsgDone {}