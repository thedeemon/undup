module visual;
import dfl.all, fileops, std.range, std.algorithm, std.stdio;
immutable small_size = 4_000_000;

class Dummy : IFSObject {
	long sz;

	string fullName() const { return "..."; }	
	long getSize() { return sz; }

	this(long _size) { sz = _size; }
}

class Box {
	IFSObject item;
	double x,y, w,h, share;
	Box[] subs;

	this(IFSObject fsobject, Box[] _subs)
	{
		item = fsobject; subs = _subs;
	}

}

Box boxOfDir(DirInfo di)
{
	long smallsizes = 0;
	Box[] subs;
	foreach(d; di.subdirs)
		if (d.getSize() > small_size) subs ~= boxOfDir(d);
		else smallsizes += d.getSize();
	foreach(f; di.files)
		if (f.size > small_size) subs ~= new Box(new PFileInfo(f, di), null);
		else smallsizes += f.size;

	if (subs.length > 0) {
		if (smallsizes > 0)
			subs ~= new Box(new Dummy(smallsizes), null);
		double total = cast(double) di.getSize();
		foreach(bx; subs)
			bx.share = bx.item.getSize() / total;
		sort!("a.share > b.share")(subs);
		return new Box(di, subs);
	} else {
		return new Box(di, null);
	}
}

class Visual : dfl.form.Form
{
	this() {
		initializeVisual();
	}

	void initializeVisual()
	{
		text = "Visual search";
		clientSize = dfl.all.Size(1040, 740);
	}
}

void vsearch(string fname)
{
	writeln("reading ", fname);
	DirInfo[] dirs = useIndex(readDump(fname));
	writeln("getting top");
	DirInfo[] topdirs = dirs.filter!(di => di.parent is null).array;
	writeln("making box tree");
	Box[] top = topdirs.map!(boxOfDir).array;


	try
	{
		Application.enableVisualStyles();
		//@  Other application initialization code here.
		Application.run(new Visual());
	}
	catch(Throwable o)
	{
		msgBox(o.toString(), "Fatal Error", MsgBoxButtons.OK, MsgBoxIcon.ERROR);		
	}
}