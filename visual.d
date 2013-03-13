module visual;
import dfl.all, fileops, messages, box, std.range, std.algorithm, std.stdio, std.math, std.c.windows.windows, 
	dfl.internal.winapi, std.string, rel, std.concurrency, std.typecons, core.time : dur;


string sizeString(long sz)
{
	enum long MB = 1024*1024; 
	if (sz >= MB) return format("%s MB", sz / MB);
	return format("%s bytes", sz);
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
	this() {}

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
	DirInfo[] dirs;
	MyPictureBox picBox;
	dfl.label.Label lblFile, lblStatus;
	dfl.button.Button btnSearch, btnCancel;
	dfl.progressbar.ProgressBar progressBar;

	Rect[] volumeRects;
	Rect[] pathRects;
	Coloring coloring;
	Box[] boxPixMap;
	int W,H;
	SimilarBoxes curSimBoxes;
	Box lastHoveredBox;
	Tid search_tid;
	Timer timer; // for receiving messages

	this(DirInfo[] _dirs) {
		W = 1000; H = 670;
		dirs = _dirs;
		writeln("making box tree");
		//DirInfo[] topdirs = dirs.filter!(di => di.parent is null).array;
		top = dirs.filter!(di => di.parent is null).map!(boxOfDir).array;
		coloring = new Coloring();
		initializeVisual();
	}

	void initializeVisual()
	{
		text = "Visual search";
		clientSize = dfl.all.Size(1040, 730);

		picBox = new MyPictureBox();
		picBox.name = "picBox";
		picBox.sizeMode = dfl.all.PictureBoxSizeMode.NORMAL;
		picBox.bounds = dfl.all.Rect(0, 24, W, H);
		picBox.parent = this;

		lblFile = new dfl.label.Label();
		lblFile.name = "lblFile";
		lblFile.text = "---";
		lblFile.textAlign = dfl.all.ContentAlignment.MIDDLE_LEFT;
		lblFile.bounds = dfl.all.Rect(0, H+24, 1000, 24);
		lblFile.parent = this;

		lblStatus = new dfl.label.Label();
		lblStatus.name = "lblStatus";
		lblStatus.bounds = dfl.all.Rect(0, 0, 384, 24);
		lblStatus.parent = this;
		//~DFL dfl.button.Button=btnSearch
		btnSearch = new dfl.button.Button();
		btnSearch.name = "btnSearch";
		btnSearch.text = "Search";
		btnSearch.bounds = dfl.all.Rect(392, 0, 72, 24);
		btnSearch.parent = this;
		//~DFL dfl.button.Button=btnCancel
		btnCancel = new dfl.button.Button();
		btnCancel.name = "btnCancel";
		btnCancel.text = "Cancel";
		btnCancel.bounds = dfl.all.Rect(704, 0, 56, 24);
		btnCancel.parent = this;
		btnCancel.visible = false;
		//~DFL dfl.progressbar.ProgressBar=progressBar
		progressBar = new dfl.progressbar.ProgressBar();
		progressBar.name = "progressBar";
		progressBar.bounds = dfl.all.Rect(472, 0, 224, 24);
		progressBar.parent = this;
		progressBar.minimum = 0;
		progressBar.maximum = 1000;
		progressBar.value = 0;

		picBox.mouseMove ~= &OnMouseMove;
		picBox.paint ~= &OnPicPaint;

		btnSearch.click ~= &StartSearch;
		btnCancel.click ~= &CancelSearch;

		timer = new Timer;
		timer.interval = 100;
		timer.tick ~= &OnTimer;
		timer.start();

		Layout(top, 0.0,0.0, W,H);
		volumeRects = top.map!(bx => bx.rect).array;
		displayBoxes();
	}

	void displayBoxes()
	{
		int w = W, h = H;		

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
		
		//if (picBox.image !is null) delete picBox.image;
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

	void OnTimer(Timer sender, EventArgs ea)
	{
		msgAnalyzing.nullify();

		bool again = false, terminated = false;
		do {
			try {
				again = receiveTimeout(dur!"msecs"(0), &RcvMsgAnalyzing, &RcvMsgSearchComplete, &RcvMsgCancel);
			} catch(LinkTerminated lt) {
				writeln("LinkTerminated");
				terminated = true;
			}
		} while(again);

		if (terminated) {			
			btnSearch.visible = true;
			btnCancel.visible = false;
			progressBar.value = 0;
			msgAnalyzing.nullify();
			if (!cancelSearch && !complete)
				lblStatus.text = "Error occured in analyzing thread.";
		} else
		if (!msgAnalyzing.isNull) {
			lblStatus.text = format("analyzing %s [%s]", msgAnalyzing.name, msgAnalyzing.sz);
			progressBar.value = cast(int) (msgAnalyzing.progress * 1000);
		}
	}

	void StartSearch(Control, EventArgs)
	{
		btnSearch.visible = false;
		btnCancel.visible = true;
		cancelSearch = false;
		complete = false;
		search_tid = spawnLinked(&searchDups, cast(shared)dirs, thisTid);
		//searchDups(cast(shared)dirs, thisTid);
	}

	void CancelSearch(Control, EventArgs)
	{
		//search_tid.send(MsgCancel());
		cancelSearch = true;
		lblStatus.text = "cancelling";
	}

	void RcvMsgCancel(MsgCancel m)
	{
		writeln("RcvMsgCancel");
		btnSearch.visible = true;
		btnCancel.visible = false;
		progressBar.value = 0;
		lblStatus.text = "search cancelled";
		msgAnalyzing.nullify();
	}

	Nullable!MsgAnalyzing msgAnalyzing;
	bool complete;

	void RcvMsgAnalyzing(MsgAnalyzing m)
	{
		msgAnalyzing = m;
	}

	void RcvMsgSearchComplete(MsgSearchComplete m)
	{
		writeln("RcvMsgSearchComplete");
		complete = true;
		msgAnalyzing.nullify();
		SimilarDirs[int] sim = cast(SimilarDirs[int]) m.sim;
		SimilarFiles[string] simf = cast(SimilarFiles[string]) m.simf;

		Box[int] boxIndex;
		Box[string] fboxIndex;
		foreach(bx; top) {
			bx.addDirsToMap(boxIndex);
			bx.addFilesToMap(fboxIndex);
		}

		SimilarBoxes[int] simboxes;
		foreach(id; sim.byKey)
			simboxes[id] = simBoxesOfSets(sim[id], boxIndex);

		SimilarBoxes[string] fsimboxes;
		foreach(id; simf.byKey)
			fsimboxes[id] = simBoxesOfSets(simf[id], fboxIndex);

		coloring = new Coloring(simboxes, fsimboxes);
		btnCancel.visible = false;
		progressBar.visible = false;
		lblStatus.text = "";
		displayBoxes();
		picBox.bounds = dfl.all.Rect(0, 0, W, H);
		picBox.invalidate();
		lblFile.bounds = dfl.all.Rect(0, H, 1000, 24);
		clientSize = dfl.all.Size(1040, 706);
		writeln("RcvMsgSearchComplete ok");
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

shared bool cancelSearch;

void searchDups(shared(DirInfo[]) _dirs, Tid gui_tid)
{
	DirInfo[] dirs = cast(DirInfo[]) _dirs;
	writeln("searchDups ", dirs.length);

	gui_tid.send(MsgAnalyzing("test", 123, 0.175));

	auto rc = new RelCache();
	ResultItem!DirInfo[] reslist = [];

	Rel comp(DirInfo a, DirInfo b) { return compDirsCaching(a, b, rc); }
	void ancd(DirInfo[] ds, float prg) 
	{
		//writeln("11");
		//while(receiveTimeout(dur!"msecs"(0), (MsgCancel m) { throw new Cancelled(); })) {}
		if (cancelSearch) throw new Cancelled();
		//writeln("12");
		gui_tid.send(MsgAnalyzing(ds[0].name, ds.length, prg * 0.75));
		//writeln("13");
		analyseCluster!(DirInfo, false)(ds, &comp, reslist);
	}
	writeln("10");
	try {
		if (dirs.length > 0)
			cluster!(DirInfo)(dirs, &ancd);
		writeln("20");

		bool[int] reported;
		foreach(r; reslist) reported[r.dir.ID] = true;
		writeln("22");
		reslist = reslist.filter!(r => r.dir.parent !is null ? (r.dir.parent.ID !in reported) : true).array;

		writeln("24");
		PFileInfo[] bigfiles = dirs.map!(
										 di => di.files.filter!(fi => fi.size > 50_000_000L).map!(fi => new PFileInfo(fi, di))									 
										 ).joiner.array;
		writeln("26");
		ResultItem!PFileInfo[] freslist = [];

		Rel compf(PFileInfo a, PFileInfo b) { return relate(a,b,rc); }
		void ancf(PFileInfo[] fs, float prg) 
		{ 
			//writeln("31");
			//while(receiveTimeout(dur!"msecs"(0), (MsgCancel m) { throw new Cancelled(); })) {}
			if (cancelSearch) throw new Cancelled();
			//writeln("32");
			send(gui_tid, MsgAnalyzing(fs[0].name, fs.length, 0.75 + prg * 0.25));
			//writeln("33");
			analyseCluster!(PFileInfo, false)(fs, &compf, freslist); 
		}
		writeln("30");
		if (bigfiles.length > 0)
			cluster!(PFileInfo)(bigfiles, &ancf);
		writeln("40");

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
		writeln("complete, sending MsgSearchComplete");
		gui_tid.send(MsgSearchComplete(cast(shared)sim, cast(shared)simf));
	} catch(Cancelled c) {
		writeln("cancelled");
		gui_tid.send(MsgCancel());
	} catch(MailboxFull mf) {
		writeln("mbox full");
	}
	writeln("search thread finishes");
}

/*void vsearch(string fname)
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
		Application.autoCollect = false;
		//@  Other application initialization code here.
		Application.run(new Visual(top, dirs));
	}
	catch(Throwable o)
	{
		msgBox(o.toString(), "Fatal Error", MsgBoxButtons.OK, MsgBoxIcon.ERROR);		
	}
}*/