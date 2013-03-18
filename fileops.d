module fileops;
import rel, messages, std.stdio, std.file, std.string, std.container, std.datetime, core.stdc.time, std.outbuffer, std.typecons, 
	std.traits, std.stream, std.range, std.algorithm, std.concurrency, std.math : abs;

string justName(string pathname)
{
	return pathname[pathname.lastIndexOf('\\')+1 .. $];
}

void saveArray(T)(T[] arr, OutBuffer buf)
{
	int n = arr.length;
	buf.write(n);
	static if (isBasicType!T) 
		buf.write(cast(const(ubyte)[])arr);
	else 
		foreach(x; arr) save(x, buf);	
}

void save(T)(T x, OutBuffer buf)
{
	static if (isBasicType!T) buf.write(x);
	else
	static if (isArray!T) saveArray(x, buf);
	else			
	foreach(m; __traits(allMembers, T))
		static if ((m!="Monitor") && !isSomeFunction!(typeof(__traits(getMember, x, m))))
			save(__traits(getMember, x, m), buf);
}

void load(T)(ref T x, MemoryStream st)
{
	static if (isBasicType!T) st.read(x);
	else 
	static if (isArray!T) loadArray(x, st);
	else
	foreach(m; __traits(allMembers, T))
		static if ((m!="Monitor") && !isSomeFunction!(typeof(__traits(getMember, x, m)))) 
			load(__traits(getMember, x, m), st);		
}

void loadArray(T)(ref T[] arr, MemoryStream st)
{
	int n;
	st.read(n);
	assert(n >= 0 && n < 1000000);
	static if (isBasicType!T) {
		ubyte[] a = [];
		a.length = n * T.sizeof;
		st.read(a);
		arr = cast(T[]) a;
	} else {
		if (arr is null) arr = [];
		arr.length = n;
		foreach(ref x; arr) {
			static if (is(T==class)) x = new T;
			load(x, st);
		}
	}
}

interface IAsker {
	void ImInt(int id);
	void ImString(string name);
}

interface IFSObject {
	string fullName();
	long getSize();
	int getID();
	void tell(IAsker asker);
}

class Dummy : IFSObject {
	long sz;
	DirInfo parent;

	string fullName()  { return parent is null ? "..." : parent.fullName() ~ "..."; }	
	long getSize() { return sz; }
	int getID() { return -1; }

	this(long _size, DirInfo _parent) { sz = _size; parent = _parent; }
	void tell(IAsker asker) {}
}

class FileInfo {
	string name;
	ulong size;
	long modTime;

	this(string _name, ulong _size, long _modTime) {
		name = _name; size = _size; modTime = _modTime; 
	}

	this() {}

	override string toString()	{
		return format("%s (%s, %s)", name, size, modTime);
	}

	override int opCmp(Object o) {
		auto a = cast(FileInfo)o;
		return cmp(name, a.name);
	}
}

class PFileInfo : FileInfo, IFSObject {
	DirInfo parent;
	string cached_fullname;

	this(FileInfo fi, DirInfo _parent)
	{
		super(fi.name, fi.size, fi.modTime); 
		parent = _parent;
	}

	string fullName() 
	{
		if (parent is null) return name;
		if (cached_fullname is null) 
			cached_fullname = parent.fullName() ~ name;
		return cached_fullname;
	}

	long getSize() { return size; }
	int getID() { return -1; }
	void tell(IAsker asker) { asker.ImString(fullName()); }
}

class DirInfoBase {
	int ID;
	string name;
	FileInfo[] files;

	this(int _ID, string _name, FileInfo[] _files)
	{
		ID = _ID; name = _name; files = _files;
	}

	this() {}

	override int opCmp(Object o) const
	{
		auto a = cast(DirInfo) o;
		return cmp(name, a.name);
	}
}

class DirInfo0 : DirInfoBase {
	int[] subdirs;
	int parentID;

	this(int _ID, int _parentID, string _name, int[] _subdirs, FileInfo[] _files)
	{
		super(_ID, _name, _files);
		subdirs = _subdirs; parentID = _parentID;
	}

	this() {}

	string show(in DirInfo0[] index) 
	{		
		return format("ID: %s, parent: %s, Name: %s\n full: %s\n sub: %s\n files: %s", ID, parentID, name, fullName(index), subdirs, files);
	}

	string fullName(in DirInfo0[] index) const
	{
		if (parentID < 0) return name;
		return index[parentID].fullName(index) ~ "/" ~ name;
	}
}

class DirInfo : DirInfoBase, IFSObject {
	DirInfo parent;
	DirInfo[] subdirs;
	private long total_size;
	string cached_fullname;

	this(int _ID, DirInfo _parent, string _name, DirInfo[] _subdirs, FileInfo[] _files)
	{
		super(_ID, _name, _files);
		subdirs = _subdirs; parent = _parent; total_size = -1;
	}

	this() { total_size = -1; }

	override string toString() 
	{		
		return format("ID: %s, parent: %s, Name: %s\n full: %s\n sub: %s\n files: %s", ID, parent.name, name, fullName(), subdirs, files);
	}

	string fullName() 
	{
		if (parent is null) return name ~ "/";
		if (cached_fullname is null) 
			cached_fullname = parent.fullName() ~ name ~ "/";
		return cached_fullname;
	}

	long getSize()
	{
		if (total_size >= 0) return total_size;
		long fsz = files.map!(fi => fi.size).sum;
		long dsz = subdirs.map!(di => di.getSize()).sum;
		total_size = fsz + dsz;
		return total_size;
	}

	int getID() { return ID; }
	void tell(IAsker asker) { asker.ImInt(ID); }
}

struct DumpSignature {
	ushort marker; // 0xDDDD
	ushort ver;    // 1
}

struct DumpHeader {
	string path, name, volume;
	int volumeSize; // in GB
	long time;     // stdTime
}

shared bool cancelScan;

void makeScan(string fname, DumpHeader hdr, Tid gui_tid)
{
	alias Entry = Tuple!(string, "name", int, "id", int, "parentID", int, "depth");
	DList!(Entry) dirstack;
	OutBuffer all = new OutBuffer();
	int nfiles, ndirs, nextID;
	int totalbig = 0, visitedbig = 0;

	int addEntry(string dirname, int parentID, int depth)
	{
		int id = nextID++;
		Entry e = tuple(dirname, id, parentID, depth);
		if (depth <= 2)
			dirstack.insertBack(e);
		else
			dirstack.insertFront(e);
		if (depth==2) totalbig++;
		return id;
	}

	save(DumpSignature(0xDDDD, 1), all);
	save(hdr, all);

	addEntry(hdr.path, -1, 0);
	while(!dirstack.empty) {
		if (cancelScan) return;
		auto dir = dirstack.front;	dirstack.removeFront();
		if (dir.depth==2) {
			if (visitedbig==0) 	
				gui_tid.send(MsgNumOfDirs(totalbig));				
			visitedbig++;
			gui_tid.send(MsgScanning(dir.name, visitedbig));
		}
		try {			
			Tuple!(int,string)[] subdirs;
			FileInfo[] files;
			foreach(DirEntry e; dirEntries(dir.name, SpanMode.shallow, false)) {
				if (e.isSymlink) continue;				
				auto name = justName(e.name).toLower;
				if (e.isDir) {
					int id = addEntry(e.name, dir.id, dir.depth + 1);
					subdirs ~= tuple(id, e.name);
					ndirs++; 
				} else {
					nfiles++;					
					files ~= new FileInfo(name, e.size, e.timeLastModified.stdTime);
				}				
			}//foreach file in dir

			sort(files);
			sort!((a,b)=> a[1] < b[1])(subdirs);
			auto dname = dir.name == hdr.path ? hdr.name : justName(dir.name);
			auto di = new DirInfo0(dir.id, dir.parentID, dname, subdirs.map!(p => p[0]).array, files);
			save(di, all);
		} catch(FileException ex) {		}
	}//for each dir
	std.file.write(fname, all.toBytes());
	gui_tid.send(MsgDone(nfiles, ndirs));
}

bool readHeader(string fname, ref DumpHeader hdr)
{
	try {
		auto bytes = cast(ubyte[]) std.file.read(fname, 10000);
		auto ms = new MemoryStream(bytes);
		DumpSignature sgn;
		load(sgn, ms);
		if (sgn.marker != 0xDDDD || sgn.ver != 1) return false;
		load(hdr, ms);
		return true;
	} catch(Throwable ex) { return false; } 
}

DirInfo0[] readDump(string fname)
{
	DirInfo0[] a = [];
	auto bytes = cast(ubyte[]) std.file.read(fname);
	auto ms = new MemoryStream(bytes);
	DumpSignature sgn;
	load(sgn, ms);
	if (sgn.marker != 0xDDDD || sgn.ver != 1) return null;
	DumpHeader hdr;
	load(hdr, ms);

	while(ms.position < ms.size) {
		DirInfo0 di = new DirInfo0;
		load(di, ms);
		a ~= di;
	}
	return a;
}

int getMaxID(D)(D[] dirs) 
{
	return dirs.map!(d => d.ID).reduce!max;
}

void liftIDs(ref DirInfo0 di, int delta)
{
	di.ID += delta;
	if (di.parentID >= 0) di.parentID += delta;
	foreach(ref x; di.subdirs) x += delta;
}

DirInfo0[] joinDumps(string[] fnames)
{
	auto dirs = readDump(fnames[0]);
	int maxID = getMaxID(dirs) + 1;
	foreach(fnm; fnames[1..$]) {
		auto ds = readDump(fnm);
		foreach(ref di; ds) liftIDs(di, maxID);
		maxID = getMaxID(ds) + 1;
		dirs ~= ds;
	}
	return dirs;
}

D[] makeIndex(D)(D[] ds)
{
	D[] idx = [];
	int maxid = getMaxID(ds);
	idx.length = maxid + 1;
	foreach(di; ds) { 
		assert(di !is null);
		idx[di.ID] = di; 
	}
	return idx;
}

DirInfo[] useIndex(DirInfo0[] ds)
{
	DirInfo[] dirs =  ds.map!(di => new DirInfo(di.ID,  null, di.name, null, di.files)).array;
	DirInfo[] idx = makeIndex(dirs);
	foreach(i; 0..dirs.length) {
		dirs[i].parent = ds[i].parentID >= 0 ? idx[ds[i].parentID] : null;
		dirs[i].subdirs = ds[i].subdirs.map!(k => idx[k]).filter!(p => p !is null).array;
	}
	return dirs;
}

long truncTime(long t) pure
{
	return (t + 19_999_999) / 20_000_000 * 20_000_000;
}

bool sameTime(in FileInfo f1, in FileInfo f2) pure // t1,t2 in hnsecs, same if dt < 3 sec
{
	return truncTime(f1.modTime) == truncTime(f2.modTime);
}

Rel compareSeqs(T)(T[] left, T[] right, RelCache rc)
{
	if (left.length==0 && right.length==0) return Rel.Same;
	if (left.length==0) return Rel.ImOlder;
	if (right.length==0) return Rel.ImNewer;

	bool luniq = false, runiq = false, lnewer = false, rnewer = false;
	int li = 0, ri = 0;
	while(li < left.length && ri < right.length) {
		int nmcmp = cmp(left[li].name, right[ri].name);
		if (nmcmp < 0) {
			luniq = true;
			li++;
		} else
			if (nmcmp > 0) {
				runiq = true;
				ri++;
			} else { //same names
				final switch(relate(left[li], right[ri], rc)) {
					case Rel.ImOlder:   rnewer = true; break;
					case Rel.ImNewer:   lnewer = true; break;
					case Rel.Unknown:   assert(0, "Rel.Unknown returned by relate()"); break;
					case Rel.Same:      break;
					case Rel.Different: return Rel.Different;
				}
				li++; ri++;
			}
		if ((luniq && runiq) || (lnewer && rnewer)) return Rel.Different;
	}
	if (li < left.length) {
		luniq = true;
	}
	if (ri < right.length) {
		runiq = true;
	}

	if (!luniq && !runiq && !lnewer && !rnewer) return Rel.Same;
	if ((luniq && runiq) || (lnewer && rnewer)) return Rel.Different;
	if ((luniq || lnewer) && !runiq && !rnewer) return Rel.ImNewer;
	if (!luniq && !lnewer && (runiq || rnewer)) return Rel.ImOlder;
	//here one's got new files, other's got updated files
	return Rel.Different;
}

Rel relate(in FileInfo left, in FileInfo right, RelCache rc)
{
	if (sameTime(left,right)) {
		if (left.size == right.size) return Rel.Same;
		else return Rel.Different;
	}
	if (left.modTime < right.modTime) return Rel.ImOlder;
	else return Rel.ImNewer;
}

Rel relate(in DirInfo left, in DirInfo right, RelCache rc)
{
	return compDirsCaching(left, right, rc);
}

Rel compareDirs(in DirInfo left, in DirInfo right, RelCache rc)
{
	Rel fres = compareSeqs(left.files, right.files, rc);
	if (fres == Rel.Different) return Rel.Different;
	Rel dres = compareSeqs(left.subdirs, right.subdirs, rc);
	final switch(dres) {
		case Rel.Same: return fres;
		case Rel.Different: return Rel.Different;
		case Rel.ImNewer: if (fres==Rel.ImNewer || fres==Rel.Same) return Rel.ImNewer; else return Rel.Different;
		case Rel.ImOlder: if (fres==Rel.ImOlder || fres==Rel.Same) return Rel.ImOlder; else return Rel.Different;
		case Rel.Unknown: assert(0, "compareSeqs returned Unknown");
	}
}

Rel compDirsCaching(in DirInfo left, in DirInfo right, RelCache rc)
{
	Rel cached = rc.get(left.ID, right.ID);
	if (cached != Rel.Unknown) return cached;
	Rel res = compareDirs(left, right, rc);
	rc.add(left.ID, right.ID, res);
	return res;
}

long sum(R)(R data) { return reduce!"a+b"(0L, data); }

class Similar(C,S)
{
	Rel status;
	S subj;
	C newer, same, older;

	this(Rel stat, S subject) 	{ 
		status = stat; subj = subject; 
	}
	this(S _subj, C _same, C _older)	{
		subj = _subj; same = _same; older = _older;
		status = same.length == 0 ? Rel.ImNewer : Rel.Same;
	}

	Similar!(D,S2) fmap(D,S2)(D delegate(C) f)
	{
		auto s = new Similar!(D,S2)(status, subj);
		s.newer = f(newer);
		s.same = f(same);
		s.older = f(older);
		return s;
	}
}

void analyseCluster(T, bool talk)(T[] ds, Rel delegate(T,T) comp, ref Similar!(T[],T)[] reslist)
in 
{
	assert(ds.length > 1);
}
body
{
	immutable int n = ds.length;
	static if (talk)
		writefln("analyzing cluster of size %s with name %s", n, ds[0].name);
	if (n > 2000) { 
		static if (talk) writeln("skipped"); 
		return; 
	}
	auto mat = new RelMat(n);
	int i,j;
	while(mat.nextPair(i, j)) {
		auto r = comp(ds[i], ds[j]);
		mat.add(i,j, r);
	}
	foreach(z; 0..n) {
		auto row = mat.rel[z];		
		if (!row.find(Rel.ImOlder).empty) continue;
		auto select(Rel r) { return iota(0,n).filter!(k => k != z && row[k] == r).map!(k => ds[k]).filter!(d => d.getSize > 0).array; } 
		auto same = select(Rel.Same), older = select(Rel.ImNewer);
		if (same.length > 0 || older.length > 0) 
			reslist ~= new Similar!(T[],T)(ds[z], same, older);
	}
}

void cluster(T)(T[] items, void delegate(T[], float) f)
in 
{ assert(items.length > 0); }
body
{
	sort(items);
	int st = 0, en = 0;
	string smallest = items[st].name;
	float num = cast(float) items.length;
	foreach(i; 1 .. items.length) {
		auto ml = min(smallest.length, items[i].name.length);
		if ((ml >=3 && smallest[0..ml] == items[i].name[0..ml]) || (smallest==items[i].name)) {
			en = i;
			smallest = smallest[0..ml];
		} else {
			if (en > st) f(items[st..en+1], i / num);
			st = i; en = i; smallest = items[i].name;
		}		
	}
	if (en > st) f(items[st..en+1], 1.0);
}
