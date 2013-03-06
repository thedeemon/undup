module visual;
import dfl.all, fileops, std.range, std.algorithm, std.stdio, std.math, std.c.windows.windows, dfl.internal.winapi,
	std.string, rel;
immutable small_size = 4_000_000;

string sizeString(long sz)
{
	enum long MB = 1024*1024; 
	if (sz >= MB) return format("%s MB", sz / MB);
	return format("%s bytes", sz);
}

class Dummy : IFSObject {
	long sz;
	DirInfo parent;

	string fullName()  { return parent is null ? "..." : parent.fullName() ~ "/..."; }	
	long getSize() { return sz; }
	int getID() { return -1; }

	this(long _size, DirInfo _parent) { sz = _size; parent = _parent; }
	void tell(IAsker asker) {}
}

alias DrawFun = void delegate(double x, double y, double w, double h, Rel, Box);

class Box {
	IFSObject item;
	double x,y, w,h;
	Box[] subs;
	Box parent;
	SimilarBoxes similar;

	this(IFSObject fsobject, Box[] _subs)
	{
		item = fsobject; subs = _subs;
		foreach(bx; subs)
			bx.parent = this;
	}

	@property size() { return item.getSize(); }

	void place(double x0, double y0, double width, double height)
	{
		x = x0; y = y0; w = width; h = height;
		if (subs !is null) Layout(subs, x0, y0, width, height);
	}

	void draw(DrawFun drawrect, SimilarBoxes delegate(IFSObject) getsim)
	{
		SimilarBoxes sb = getsim(item);	
		Rel r = Rel.Unknown;
		if (sb !is null) {
			similar = sb;
			r = sb.status;
		}
		
		if (subs.length==0) 
			drawrect(x,y,w,h, r, this);
		else
			if (r == Rel.Unknown)
				foreach(bx; subs)
					bx.draw(drawrect, getsim);
			else
				foreach(bx; subs)
					bx.draw2(drawrect, sb);
	}

	void draw2(DrawFun drawrect, SimilarBoxes sb)
	{
		similar = sb;
		if (subs.length==0) 
			drawrect(x,y,w,h, sb.status, this);
		else
			foreach(bx; subs)
				bx.draw2(drawrect, sb);
	}

	Box findByPoint(int mx, int my, Box curParent, ref Box resultParent)
	{
		if (mx < x || my < y || mx >= (x+w) || my >= (y+h)) return null;
		if (subs is null || subs.length == 0) {
			resultParent = curParent;
			return this;
		}
		foreach(bx; subs) {
			auto p = bx.findByPoint(mx,my, this, resultParent);
			if (p !is null) return p;
		}
		return null;
	}

	Rect rect()
	{
		return Rect(cast(int)x, cast(int)y, cast(int)w, cast(int)h);
	}

	Rect[] pathRects()
	{
		Rect[] rcs;
		addAncestorsRects(rcs);
		return rcs;
	}

	private void addAncestorsRects(ref Rect[] rcs)
	{
		if (parent !is null)
			parent.addAncestorsRects(rcs);
		rcs ~= rect();
	}

	void addDirsToMap(ref Box[int] index)
	{
		int id = item.getID();
		if (id > -1) {
			index[id] = this;
			if (subs !is null)
				foreach(bx; subs)
					bx.addDirsToMap(index);
		}
	}

	void addFilesToMap(ref Box[string] index)
	{
		int id = item.getID();
		if (id == -1) {
			if (item.fullName == "...") return;
			index[item.fullName] = this;
		}
		if (subs !is null)
			foreach(bx; subs)
				bx.addFilesToMap(index);
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
			subs ~= new Box(new Dummy(smallsizes, di), null);
		sort!("a.size > b.size")(subs);
		return new Box(di, subs);
	} else {
		return new Box(di, null);
	}
}

void Layout(Box[] boxes, double x0, double y0, double width, double height)
{
	if (boxes is null) return;
	switch(boxes.length) {
		case 0: break;
		case 1: boxes[0].place(x0,y0, width, height); break;
		case 2:
			double k = (cast(double) boxes[0].size) / (boxes[0].size + boxes[1].size);
			if (width > height) {
				boxes[0].place(x0, y0,           width*k, height);
				boxes[1].place(x0 + width*k, y0, width*(1-k), height);
			} else {
				boxes[0].place(x0, y0,            width, height*k);
				boxes[1].place(x0, y0 + height*k, width, height*(1-k));
			}
			break;
		default:
			double total = boxes.map!(b => b.size).sum;
			int i = 0;
			double x = x0;
			while(i < boxes.length) {
				double w = width * (boxes[i].size / total);
				if (w > height / 2.0) { //fat enough
					boxes[i].place(x, y0, w, height);
					x += w;
					i++;
				} else { //only thin ones left
					if (boxes.length - i <= 2) // just 1 or 2 left
						Layout(boxes[i..$], x, y0, width - (x-x0), height);
					else {
						long ttl = boxes[i..$].map!(b => b.size).sum;
						long half =  ttl / 2;
						long s = 0, bestd = half * 2 + 100;
						int bestk = i;
						foreach(j; i..boxes.length) {
							long dist = abs(half - s);
							if (dist < bestd) {
								bestk = j;	bestd = dist;
							} else break;
							s += boxes[j].size;
						}
						auto left = boxes[i..bestk], right = boxes[bestk..$];
						double leftsz = left.map!(b => b.size).sum;
						double kh = leftsz / ttl;
						double wd = width - (x-x0);
						Layout(left,  x, y0,               wd, height * kh);
						Layout(right, x, y0 + height * kh, wd, height * (1-kh));
					}
					break;
				}//if fat or thing
			} //while i < length
	}//switch boxes.length
}

struct Set(T)
{
	bool[T] data;

	void add(T x) { data[x] = true; }
	void addMany(R)(R rng) { foreach(x; rng) data[x] = true; }
	auto elems() { return data.byKey(); }
}

class Similar(C)
{
	Rel status;
	C newer, same, older;

	this(Rel stat) { status = stat; }

	Similar!D fmap(D)(D delegate(C) f)
	{
		auto s = new Similar!D(status);
		s.newer = f(newer);
		s.same = f(same);
		s.older = f(older);
		return s;
	}
}

alias SimilarDirs = Similar!(Set!int);
alias SimilarBoxes = Similar!(Box[]);
alias SimilarFiles = Similar!(Set!string);

SimilarBoxes simBoxesOfSets(T)(Similar!(Set!T) s, Box[T] boxIndex)
{
	return s.fmap!(Box[])(set => set.data.keys.map!(id => boxIndex.get(id,null)).filter!(p => p !is null).array);
}

class MyPictureBox : PictureBox {
	this() 
	{
		super();
		setStyle(ControlStyles.OPAQUE, true);
	}
}

int relColor(Rel r)
{
	final switch(r) {
		case Rel.Unknown:   return 0x010101;
		case Rel.ImNewer:   return 0x000100;
		case Rel.ImOlder:   return 0x010000;
		case Rel.Same:      return 0x010100;
		case Rel.Different: return 0x000000;
	}
}

class Coloring : IAsker {
	SimilarBoxes[int] simboxes;
	SimilarBoxes[string] fsimboxes;
	SimilarBoxes sb;

	this(SimilarBoxes[int] sbx, SimilarBoxes[string] fsbx) {
		simboxes = sbx;
		fsimboxes = fsbx;
	}

	void ImInt(int id) { if (id in simboxes) sb = simboxes[id]; }
	void ImString(string name) 
	{
		auto p = name in fsimboxes;
		if (p !is null) sb = *p;
	}
}

class Visual : dfl.form.Form
{
	Box[] top;
	MyPictureBox picBox;
	dfl.label.Label lblFile;
	Rect[] volumeRects;
	Rect[] pathRects;
	Coloring coloring;
	Box[] boxPixMap;
	int W,H;
	SimilarBoxes curSimBoxes;
	Box lastHoveredBox;

	this(Box[] _top, SimilarBoxes[int] sbx, SimilarBoxes[string] fsbx) {
		W = 1000; H = 700;
		top = _top;
		coloring = new Coloring(sbx, fsbx);

		initializeVisual();
	}

	void initializeVisual()
	{
		text = "Visual search";
		clientSize = dfl.all.Size(1040, 740);

		picBox = new MyPictureBox();
		picBox.name = "picBox";
		picBox.sizeMode = dfl.all.PictureBoxSizeMode.NORMAL;
		picBox.bounds = dfl.all.Rect(0, 0, W, H);
		picBox.parent = this;

		lblFile = new dfl.label.Label();
		lblFile.name = "lblFile";
		lblFile.text = "---";
		lblFile.textAlign = dfl.all.ContentAlignment.MIDDLE_LEFT;
		lblFile.bounds = dfl.all.Rect(0, H, 1000, 24);
		lblFile.parent = this;

		picBox.mouseMove ~= &OnMouseMove;
		picBox.paint ~= &OnPicPaint;

		displayBoxes();
	}

	void displayBoxes()
	{
		int w = W, h = H;
		Layout(top, 0.0,0.0,w,h);

		HBITMAP hbm = CreateCompatibleBitmap(Graphics.getScreen().handle, w, h);
		int[] data;
		data.length = w*h;
		boxPixMap.length = w*h;

		void drawBar(double x0, double y0, double dx, double dy, Rel r, Box bx)
		{
			int iy0 = cast(int)y0, ix0 = cast(int)x0, ix1 = cast(int) (x0 + dx), iy1 = cast(int) (y0+dy);
			if (ix1 >= w) ix1 = w;
			if (iy1 >= h) iy1 = h;
			int clr = relColor(r);
			foreach(iy; iy0 .. iy1) {
				real ky = sin(3 * cast(real)(iy - iy0) / dy);
				int di = iy * w + ix0;
				foreach(ix; ix0 .. ix1) {
					real kx = sin(3 * cast(real)(ix - ix0) / dx);
					int c = cast(int)(kx * ky * 200) + 50;
					data[di] = c * clr;
					boxPixMap[di] = bx;
					di++;
				}
			}
		}

		SimilarBoxes getsim(IFSObject item) 
		{ 
			coloring.sb = null;
			item.tell(coloring);
			return coloring.sb;
		}

		foreach(bx; top)
			bx.draw(&drawBar, &getsim);

		SetBitmapBits(hbm, data.length*4, data.ptr);
		delete data;		

		volumeRects = top.map!(bx => bx.rect).array;
		picBox.image = new Bitmap(hbm, true);
	}

	void OnMouseMove(Control c, MouseEventArgs ma)
	{
		if (ma.x < W && ma.y < H) {
			Box box = boxPixMap[ma.y * W + ma.x];
			//auto bxs = top.map!(b => b.findByPoint(ma.x, ma.y, null, resParent)).find!"a !is null";
			if (box !is null && box !is lastHoveredBox) {
				lastHoveredBox = box;
				Box resParent = box.parent;
				lblFile.text = format("%s (%s, parent: %s)", box.item.fullName(), box.item.getSize.sizeString,
									  resParent is null ? "-" : resParent.item.getSize.sizeString);
				
				pathRects = box.pathRects();				
				curSimBoxes = box.similar;
				picBox.invalidate();
			}
		}
	}

	void OnPicPaint(Control c, PaintEventArgs pa)
	{
		if (curSimBoxes !is null) {
			scope greenbr = new SolidBrush(Color.fromRgb(0x80FF80));
			scope yellowbr = new SolidBrush(Color.fromRgb(0x80FFFF));
			scope redbr = new SolidBrush(Color.fromRgb(0x8080FF));
			foreach(bx; curSimBoxes.newer)
				pa.graphics.fillRectangle(greenbr, bx.rect);
			foreach(bx; curSimBoxes.same)
				pa.graphics.fillRectangle(yellowbr, bx.rect);
			foreach(bx; curSimBoxes.older)
				pa.graphics.fillRectangle(redbr, bx.rect);
		}

		scope Pen redpen = new Pen(Color.fromRgb(0xFF));
		foreach(rc; volumeRects) 
			pa.graphics.drawRectangle(redpen, rc);

		int[8] colors = [0xFF, 0xFFFF, 0xFF00, 0xFF0000, 0xFF00FF, 0xFFFF00, 0xFFFFFF, 0x80FF];
		int i = 0;
		foreach(rc; pathRects) {
			scope Pen pn = new Pen(Color.fromRgb(colors[i % $]));
			pa.graphics.drawRectangle(pn, rc);
			i++;
		}
	}

}//class Visual

auto ids(DirInfo[] arr) { return arr.map!(di => di.ID); }
auto names(PFileInfo[] arr) { return arr.map!(fi => fi.fullName()); }

void addOlder(R,I,S)(R old_ids, I myid, ref S[I] sim)
{
	foreach(id; old_ids) {
		if (id in sim) {
			sim[id].newer.add(myid);
		} else {
			auto os = new S(Rel.ImOlder);
			os.newer.add(myid);
			sim[id] = os;
		}
	}
}

void vsearch(string fname)
{
	writeln("reading ", fname);
	DirInfo[] dirs = useIndex(readDump(fname));

	auto rc = new RelCache();
	ResultItem!DirInfo[] reslist = [];

	void on_inf_error2(DirInfo[] ds, InferenceError e)
	{
		foreach(k; e.abc)
			writeln(ds[k].fullName());
		foreach(ii; e.abc) {
			foreach(jj; e.abc)
				writef("%s ", rc.get(ds[ii].ID,ds[jj].ID));
			writeln();
		}
	}

	auto comp(DirInfo a, DirInfo b) { return compDirsCaching(a, b, rc); }

	cluster!(DirInfo, ds => analyseCluster!(DirInfo, comp, on_inf_error2)(ds, reslist))(dirs);

	bool[int] reported;
	foreach(r; reslist) reported[r.dir.ID] = true;
	reslist = reslist.filter!(r => r.dir.parent.ID !in reported).array;

	PFileInfo[] bigfiles = dirs.map!(
									 di => di.files.filter!(fi => fi.size > 50_000_000L).map!(fi => new PFileInfo(fi, di))									 
									 ).joiner.array;
	ResultItem!PFileInfo[] freslist = [];

	void on_inf_err3(PFileInfo[] fs, InferenceError e) {}

	auto compf(PFileInfo a, PFileInfo b) { return relate(a,b,rc); }
	auto anc(PFileInfo[] fs) { return analyseCluster!(PFileInfo, compf, on_inf_err3)(fs, freslist); }
	cluster!(PFileInfo, anc)(bigfiles);

	writeln("getting top");
	DirInfo[] topdirs = dirs.filter!(di => di.parent is null).array;
	writeln("making box tree");
	Box[] top = topdirs.map!(boxOfDir).array;

	SimilarDirs[int] sim;
	foreach(r; reslist) {
		r.calcProfit();
		SimilarDirs s;
		if (r.same.length==0) { //i'm green (newest)
			s = new SimilarDirs(Rel.ImNewer);
		} else { // i'm yellow (have exact copies)
			s = new SimilarDirs(Rel.Same);
			s.same.addMany(r.same.ids);
		}
		s.older.addMany(r.older.ids);
		sim[r.dir.ID] = s;
		addOlder(r.older.ids, r.dir.ID, sim);
	}

	Box[int] boxIndex;
	Box[string] fboxIndex;
	foreach(bx; top) {
		bx.addDirsToMap(boxIndex);
		bx.addFilesToMap(fboxIndex);
	}

	SimilarBoxes[int] simboxes;
	foreach(id; sim.byKey)
		simboxes[id] = simBoxesOfSets(sim[id], boxIndex);
	//showResults!(DirInfo, di => sizes[di.ID])(reslist);

	SimilarFiles[string] simf;
	foreach(r; freslist) {
		r.calcProfit();
		SimilarFiles s;
		if (r.same.length==0) { //i'm green (newest)
			s = new SimilarFiles(Rel.ImNewer);
		} else { // i'm yellow (have exact copies)
			s = new SimilarFiles(Rel.Same);
			s.same.addMany(r.same.names);
		}
		s.older.addMany(r.older.names);
		simf[r.dir.fullName] = s;
		addOlder(r.older.names, r.dir.fullName, simf);
	}

	SimilarBoxes[string] fsimboxes;
	foreach(id; simf.byKey)
		fsimboxes[id] = simBoxesOfSets(simf[id], fboxIndex);


	try
	{
		Application.enableVisualStyles();
		Application.autoCollect = false;
		//@  Other application initialization code here.
		Application.run(new Visual(top, simboxes, fsimboxes));
	}
	catch(Throwable o)
	{
		msgBox(o.toString(), "Fatal Error", MsgBoxButtons.OK, MsgBoxIcon.ERROR);		
	}
}